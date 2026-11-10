import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cloud_api.dart';
import 'cloud_models.dart';
import 'media_sign_cache.dart';

/// 云端港口瀑布流 Loader（v2.7 P0，对接 GET /api/post/list）
///
/// 职责：分页累积 + 筛选切换 + 签名预热 + 点赞状态同步。
/// UI 层（PortTab）监听 notifyListeners 渲染；拉取失败抛 ApiException
/// 由 UI 决定回落本地种子数据（游客/断网兜底）。
///
/// 典型用法（港口首页）：
/// ```dart
/// final loader = CloudFeedLoader();
/// await loader.refresh(islandKey: kCloudIslandKeys[filterId] ?? 'all');
/// // 列表渲染 loader.posts；触底调 loader.loadMore()；
/// // 下拉调 loader.refresh(islandKey: ...)；
/// // 点赞后同步列表：loader.applyLikeResult(post.postId, likeCount: r.likeCount, liked: r.liked)；
/// // 拉黑后调 loader.removeByAuthor(uid)（对方帖子立即消失）。
/// ```
/// 发帖成功后的全局刷新信号（ComposerPage 发帖成功 value++，
/// PortTab 监听后重拉第一页 —— 解耦：composer 无需持有 loader 引用）
final ValueNotifier<int> kCloudFeedRefreshSignal = ValueNotifier<int>(0);

/// 发帖成功后的定位信号（v2.9.3 → 改 Stream 广播流）：
/// ValueNotifier 依赖值变更触发，同值/快速连续发送存在漏触发问题；
/// broadcast Stream 每一次 add 都是独立事件，连续发多条帖每条都能收到。
/// PortTab 监听：等本次刷新完成 → 在已加载列表中查找 → 滚动定位 + 短暂高亮；
/// 未找到（审核拦截/未进流/不在当前页）静默忽略。防抖：只认最新一条。
final StreamController<int> kFeedLocatePostSignal = StreamController<int>.broadcast();

/// 发帖成功后的岛屿分类切换信号（v2.9.4）：
/// 岛屿详情页入口发帖成功 → ComposerPage 写入本次发帖的主岛 island key，
/// PortTab 监听后切换顶部岛屿分类标签（复用 _onFilterChanged）。
/// '' = 无操作；同值不通知（分类已在该岛时无需切换，列表刷新走 kCloudFeedRefreshSignal）。
final ValueNotifier<String> kPortIslandFilterSignal = ValueNotifier<String>('');

/// 底部发布入口的分类对齐信号（v2.9.4）：
/// 值 = 帖子主岛本地 Island.id（'' = 无岛标签）。PortTab 监听后：
/// 与当前 _filter 一致 → 不动（当前列表直接定位新帖）；
/// 不一致或无标签 → 切【全部】+【最新】，保证用户一定看得到新帖。
/// 用 broadcast Stream：连续发同标签帖每次都是独立事件（ValueNotifier 同值不通知会漏）。
final StreamController<String> kPortFeedAlignSignal = StreamController<String>.broadcast();

class CloudFeedLoader extends ChangeNotifier {
  CloudFeedLoader({this.pageSize = 10});

  final CloudApi _api = CloudApi.instance;
  final int pageSize;

  List<CloudPost> posts = <CloudPost>[];
  bool loading = false; // 首屏/刷新中
  bool loadingMore = false; // 触底加载中
  bool reachedEnd = false; // 已拉完全部
  String? error; // 最近一次错误消息（UI 顶部提示条用）
  String sort = 'latest'; // v2.9.2：latest 最新时序 | hot 热度

  int _page = 0;
  String _islandKey = 'all';
  String? _tag;
  int _gen = 0; // 刷新代际：并发/迟到的旧响应一律丢弃，只认最新一代

  String get islandKey => _islandKey;

  /// 刷新（筛选切换/排序切换/下拉）。重置分页与数据。
  Future<void> refresh({String? islandKey, String? tag, String? sort}) async {
    final int gen = ++_gen;
    _islandKey = islandKey ?? _islandKey;
    _tag = tag;
    this.sort = sort ?? this.sort;
    _page = 1;
    reachedEnd = false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final PagedPosts r = await _api.fetchPostList(
        islandKey: _islandKey,
        tag: _tag,
        sort: this.sort,
        page: 1,
        size: pageSize,
      );
      // 过期响应（已被更新的刷新取代）：只更新 loading 态，绝不动 posts
      // （实测：慢请求迟到完成会用旧筛选数据覆盖新列表，导致新帖"消失"）
      if (gen != _gen) {
        debugPrint('[feed-refresh] stale response dropped (gen=$gen/$_gen)');
        return;
      }
      posts = r.list;
      reachedEnd = !r.hasMore;
      // 整页附件签名预热（一次批量换整页图片）
      unawaited(MediaSignCache.instance
          .prefetch(posts.map((p) => p.postId).toList()));
    } on ApiException catch (e) {
      error = e.message;
      rethrow; // UI 决定回落本地
    } finally {
      loading = false;
      debugPrint('[feed-refresh] island=$_islandKey sort=${this.sort} '
          'n=${posts.length} first=${posts.isEmpty ? -1 : posts.first.postId}');
      notifyListeners();
    }
  }

  /// 触底加载下一页（reachedEnd/loadingMore 时调用是安全的 no-op）
  Future<void> loadMore() async {
    if (loading || loadingMore || reachedEnd) return;
    final int gen = _gen; // 记住发起时的代际：期间发生 refresh 则响应作废
    loadingMore = true;
    notifyListeners();
    try {
      final PagedPosts r = await _api.fetchPostList(
        islandKey: _islandKey,
        tag: _tag,
        sort: sort,
        page: _page + 1,
        size: pageSize,
      );
      if (gen != _gen) return; // 期间发生过刷新：旧筛选的分页数据不追加
      _page += 1;
      // 按 postId 去重（防滑动期间刷新造成的重复项）
      final known = posts.map((p) => p.postId).toSet();
      posts.addAll(r.list.where((p) => !known.contains(p.postId)));
      reachedEnd = !r.hasMore;
      unawaited(MediaSignCache.instance
          .prefetch(r.list.map((p) => p.postId).toList()));
    } on ApiException catch (e) {
      error = e.message; // 追加失败不抛出，保留已有数据
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  /// 用已完成的点赞结果同步列表（⚠️ 不再重复调接口 —— 详情页已调用过 toggle，
  /// loader 再调一次会把点赞又取消掉，正是"详情 1 列表 0"的根因）
  void applyLikeResult(int postId, {required int likeCount, required bool liked}) {
    posts = posts
        .map((p) => p.postId == postId
            ? CloudPost(
                postId: p.postId,
                type: p.type,
                content: p.content,
                author: p.author,
                coverKey: p.coverKey,
                coverKeys: p.coverKeys,
                island: p.island,
                tags: p.tags,
                likeCount: likeCount,
                liked: liked,
                commentCount: p.commentCount,
                createdAt: p.createdAt,
              )
            : p)
        .toList();
    notifyListeners();
  }

  /// 拉黑后移除该作者的帖子（对方内容立即消失，与后端口径一致）
  void removeByAuthor(int uid) {
    posts = posts.where((p) => p.author.uid != uid).toList();
    notifyListeners();
  }

  /// 发评论成功后本地 +1（免多拉一次详情）
  void bumpCommentCount(int postId) {
    posts = posts
        .map((p) => p.postId == postId
            ? CloudPost(
                postId: p.postId,
                type: p.type,
                content: p.content,
                author: p.author,
                coverKey: p.coverKey,
                coverKeys: p.coverKeys,
                island: p.island,
                tags: p.tags,
                likeCount: p.likeCount,
                liked: p.liked,
                commentCount: p.commentCount + 1,
                createdAt: p.createdAt,
              )
            : p)
        .toList();
    notifyListeners();
  }
}
