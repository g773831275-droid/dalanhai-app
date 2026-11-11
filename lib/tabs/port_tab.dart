import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/colors.dart';
import '../data/models.dart';
import '../data/data_store_provider.dart';
import '../pages/cloud_post_detail_page.dart';
import '../pages/post_detail_page.dart';
import '../pages/user_profile_page.dart';
import '../services/cloud_api.dart';
import '../services/cloud_feed.dart';
import '../services/cloud_models.dart';
import '../widgets/image_viewer.dart';
import '../widgets/user_avatar.dart';

/// 港口 Tab — 瀑布流 UGC 社区
/// 1:1 复刻 H5 renderPort（2 列 masonry + 筛选标签）
///
/// v2.7 数据源策略：云端优先（GET /api/post/list，游客可拉公开流），
/// 断网/接口异常自动回落本地种子数据 —— 登录链路未通也不影响开发调试。
class PortTab extends StatefulWidget {
  const PortTab({super.key});

  @override
  State<PortTab> createState() => _PortTabState();
}

class _PortTabState extends State<PortTab> {
  String _filter = 'all';
  String _sort = 'latest'; // v2.9.2：latest 最新 | hot 热门
  CloudFeedLoader? _cloud; // null = 云端未就绪（未配置/首次加载中）
  bool _cloudEverFailed = false; // 云端彻底失败过（release 下展示错误态而非种子数据）
  String? _cloudErrorMsg;

  // ── v2.9.3 发布后定位 ──
  final ScrollController _feedCtrl = ScrollController();
  final Map<int, GlobalKey> _locateKeys = {}; // postId → 卡片 key（滚动定位用）
  int? _pendingLocatePostId; // 待定位帖子（防抖：只认最新一条信号）
  int? _highlightPostId; // 定位成功后的短暂高亮
  bool _locating = false; // 定位流程防重入
  int _locateRetries = 0; // 未匹配重试计数（并发刷新响应乱序时补偿）

  @override
  void initState() {
    super.initState();
    _initCloud();
    // 发帖成功（ComposerPage 发信号）→ 重拉第一页，新帖立即可见
    kCloudFeedRefreshSignal.addListener(_onExternalRefresh);
    // 发帖成功（携带新帖 postId）→ 刷新完成后滚动定位到该帖
    // v2.9.3：广播 Stream —— 每次 add 都是独立事件，连续发帖每条都能收到
    _locateSub = kFeedLocatePostSignal.stream.listen(_onLocateSignal);
    // 岛屿页入口发帖成功（ComposerPage 写入岛 key）→ 切顶部岛屿分类
    kPortIslandFilterSignal.addListener(_onExternalFilter);
    // 底部发布入口（ComposerPage 发帖子主岛 id，''=无岛标签）→ 分类对齐
    _alignSub = kPortFeedAlignSignal.stream.listen(_onFeedAlign);
  }

  StreamSubscription<String>? _alignSub;

  /// 底部发布入口的分类对齐（v2.9.4）：
  /// 帖子主岛与当前筛选一致 → 不动（刷新后当前列表直接定位新帖）；
  /// 不一致或帖子无岛标签 → 切【全部】+【最新】，保证新帖一定可见。
  /// 只影响筛选/排序状态，不动 kPortIslandFilterSignal 那套岛屿入口逻辑。
  void _onFeedAlign(String postIsland) {
    if (postIsland.isNotEmpty && postIsland == _filter) return;
    debugPrint('[port-align] postIsland=${postIsland.isEmpty ? '(none)' : postIsland}, '
        '_filter=$_filter, _sort=$_sort → all+latest');
    if (_sort != 'latest') _onSortChanged('latest'); // 先切排序，随后的分类刷新即用 latest
    if (_filter != 'all') _onFilterChanged('all');
  }

  /// 外部岛屿分类切换（v2.9.4）：复用 _onFilterChanged（setState + 按岛刷新），
  /// '' 或同值（ValueNotifier 不通知）均无操作，定位/高亮逻辑不受影响
  void _onExternalFilter() {
    final key = kPortIslandFilterSignal.value;
    if (key.isEmpty || key == _filter) return;
    debugPrint('[port-filter] external switch to $key');
    _onFilterChanged(key);
  }

  StreamSubscription<int>? _locateSub;

  void _onExternalRefresh() {
    if (_cloud == null) {
      _initCloud(); // 首次云端未就绪（如启动时断网）→ 重新初始化
      return;
    }
    _refreshCloud();
  }

  /// 定位信号入口（v2.9.3 修复 Bug1）：**无条件覆盖 pendingPostId**，
  /// _locating 不拦截流事件、不丢弃新帖 id —— 永远保存最新待定位帖子。
  /// 消费时机：composer 同时发的 kCloudFeedRefreshSignal 触发刷新，
  /// 刷新成功后 [_attemptLocate] 消费 pending（时序约束）。
  void _onLocateSignal(int pid) {
    debugPrint('[feed-locate] raw stream callback hit, pid=$pid, _locating=$_locating');
    if (pid <= 0) return;
    _pendingLocatePostId = pid;
    debugPrint('[feed-locate] pending updated to pid=$pid');
  }

  @override
  void dispose() {
    kCloudFeedRefreshSignal.removeListener(_onExternalRefresh);
    kPortIslandFilterSignal.removeListener(_onExternalFilter);
    _alignSub?.cancel();
    _locateSub?.cancel(); // 页面销毁取消订阅，防内存泄漏
    _feedCtrl.dispose();
    super.dispose();
  }

  /// 云端模式启动：CloudApi 已配置（main 里 SessionStore.restore 注入）即拉流
  Future<void> _initCloud() async {
    if (!CloudApi.instance.isConfigured) return;
    final loader = CloudFeedLoader();
    try {
      await loader.refresh(islandKey: kCloudIslandKeys[_filter] ?? 'all', sort: _sort);
      if (!mounted) return;
      setState(() => _cloud = loader);
    } on ApiException catch (e) {
      // 云端不可用（断网/服务异常）
      if (!mounted) return;
      setState(() {
        _cloudEverFailed = true;
        _cloudErrorMsg = e.message;
      });
    }
  }

  void _onFilterChanged(String id) {
    setState(() => _filter = id);
    final loader = _cloud;
    if (loader == null) {
      // 云端失败已回落种子（_cloud 为 null）→ 切筛选时自动重试云端，
      // 防止一次瞬时失败后死锁在种子数据、看起来像"回退 H5 旧版"
      _retryCloud();
      return;
    }
    loader
        .refresh(islandKey: kCloudIslandKeys[id] ?? 'all', sort: _sort)
        .catchError((_) {});
  }

  /// 最新/热门切换（在当前岛屿范围内重排）
  void _onSortChanged(String sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    final loader = _cloud;
    if (loader == null) {
      _retryCloud(); // 同 _onFilterChanged：失败态下切排序也自动重试云端
      return;
    }
    loader
        .refresh(islandKey: kCloudIslandKeys[_filter] ?? 'all', sort: _sort)
        .catchError((_) {});
  }

  /// 刷新云端流。返回是否成功（定位逻辑只在成功后执行）。
  Future<bool> _refreshCloud() async {
    final loader = _cloud;
    if (loader == null) {
      await _initCloud();
      return false;
    }
    try {
      await loader.refresh(islandKey: kCloudIslandKeys[_filter] ?? 'all', sort: _sort);
      if (mounted) {
        setState(() {
          _cloudEverFailed = false;
          _cloudErrorMsg = null;
        });
      }
      _attemptLocate(); // 刷新完成 → 若有待定位新帖则滚动定位
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _cloudEverFailed = true;
          _cloudErrorMsg = e.message;
        });
      }
      _pendingLocatePostId = null; // 网络异常：跳过定位（只切 tab，不报错）
      return false;
    }
  }

  /// 定位执行（刷新完成后来调用）：在**当前已加载**列表中查找新帖。
  /// idx==0（最新流必命中）→ animateTo(0) + 金框高亮，**不依赖 GlobalKey/ctx**
  /// （实测 GlobalKey currentContext 在刷新重建后拿不到，时序不可靠）；
  /// idx>0（热门流等）→ 保留 key/ensureVisible 路径，ctx 拿不到则静默。
  void _attemptLocate() {
    final int? pid = _pendingLocatePostId;
    if (pid == null || pid <= 0 || !mounted) return;
    final loader = _cloud;
    if (loader == null) return;
    final int idx = loader.posts.indexWhere((p) => p.postId == pid);
    debugPrint('[feed-locate] 收到 kFeedLocatePostSignal postId=$pid，'
        '${idx >= 0 ? "匹配下标=$idx" : "未匹配（静默忽略定位）"}');
    if (idx < 0) {
      // 刷新完成但列表还没包含新帖（分类切换时新旧两次刷新并发、响应乱序，
      // 旧响应可能先到把 pending 吃掉）：保留 pending 短暂重试 3 次，
      // 上限后仍无 → 静默放弃（不翻页、不报错，维持原「未进流静默」语义）
      if (_locateRetries < 3) {
        _locateRetries++;
        debugPrint('[feed-locate] postId=$pid 未匹配，重试$_locateRetries/3（700ms）');
        Timer(const Duration(milliseconds: 700), () {
          if (mounted) _attemptLocate();
        });
        return;
      }
      _locateRetries = 0;
      _pendingLocatePostId = null;
      debugPrint('[feed-locate] postId=$pid 重试后仍未进流，静默放弃');
      return;
    }
    _locateRetries = 0;
    if (_locating) {
      // Case3：上一轮高亮还在进行 —— 跳过本次动画，pending 保留，
      // 等 Timer 结束后的补消费执行最新帖定位
      debugPrint('[feed-locate] attemptLocate skip, busy, pending=$pid');
      return;
    }
    _pendingLocatePostId = null; // 取走，执行定位
    _locating = true;

    void startHighlight() {
      setState(() => _highlightPostId = pid);
      debugPrint('[feed-highlight] set highlightPostId=$pid');
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _highlightPostId = null);
          debugPrint('[feed-highlight] clear highlightPostId');
        }
        _locating = false;
        _attemptLocate(); // Case3：上一轮结束后，消费等待中的最新 pending
      });
    }

    if (idx == 0) {
      // 最新流：新帖必在顶部，直接滚回列表头（等价定位），随后金框高亮
      if (_feedCtrl.hasClients) {
        _feedCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
      startHighlight();
      return;
    }
    // 非首位（热门流等）：尝试 GlobalKey/ensureVisible，拿不到 ctx 静默放弃
    final key = _locateKeys[pid];
    if (key == null) {
      debugPrint('[feed-locate] postId=$pid 无卡片 key（未 build），跳过');
      _locating = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx == null) {
        debugPrint('[feed-locate] postId=$pid 卡片未挂载（ctx=null），跳过');
        _locating = false;
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
      startHighlight();
    });
  }

  void _retryCloud() {
    setState(() {
      _cloudEverFailed = false;
      _cloudErrorMsg = null;
    });
    _initCloud();
  }

  @override
  Widget build(BuildContext context) {
    final loader = _cloud;
    // 云端模式（有 loader 即走云端；刷新失败保留已有数据，下拉可重试）
    if (loader != null) {
      return RefreshIndicator(
        onRefresh: _refreshCloud,
        child: _CloudFeedView(
          loader: loader,
          filterId: _filter,
          onFilterChanged: _onFilterChanged,
          sortId: _sort,
          onSortChanged: _onSortChanged,
          feedCtrl: _feedCtrl,
          cardKeys: _locateKeys,
          highlightPostId: _highlightPostId,
        ),
      );
    }

    // release：云端失败 → 错误态 + 重试（绝不展示假种子数据，防"帖子消失"误解）
    if (!kDebugMode && _cloudEverFailed) {
      return _CloudErrorView(message: _cloudErrorMsg, onRetry: _retryCloud);
    }

    // 云端首次拉取中 → 骨架
    if (!_cloudEverFailed) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    // debug 回落：云端未配置/失败 → 本地种子数据（仅开发调试）
    final store = DataStoreProvider.of(context);
    final posts = store.filteredPosts(_filter);

    return CustomScrollView(
      slivers: [
        // 筛选标签
        SliverToBoxAdapter(child: _buildFilters()),
        // 瀑布流或空状态
        if (posts.isEmpty)
          const SliverFillRemaining(child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 100),
            sliver: _MasonrySliver(posts: posts),
          ),
      ],
    );
  }

  Widget _buildFilters() {
    final filters = [
      ('all', '全部'),
      ...Island.all.map((i) => (i.id, i.name)),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (id, name) = filters[i];
          final active = _filter == id;
          return GestureDetector(
            onTap: () => _onFilterChanged(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: active ? AppColors.btnGoldGradient : null,
                color: active ? null : AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: active ? null : Border.all(color: AppColors.line),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: active ? AppColors.goldBtnText : AppColors.foam,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MasonrySliver extends StatelessWidget {
  final List<Post> posts;
  const _MasonrySliver({required this.posts});

  @override
  Widget build(BuildContext context) {
    // 2 列 masonry：偶数索引左列，奇数索引右列
    final left = <Post>[];
    final right = <Post>[];
    for (var i = 0; i < posts.length; i++) {
      (i.isEven ? left : right).add(posts[i]);
    }

    return SliverToBoxAdapter(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: left.map((p) => _PostCard(post: p, index: left.indexOf(p) * 2)).toList())),
          const SizedBox(width: 10),
          Expanded(child: Column(children: right.map((p) => _PostCard(post: p, index: right.indexOf(p) * 2 + 1)).toList())),
        ],
      ),
    );
  }
}

/// 帖子卡片 — 1:1 复刻 H5 .post
class _PostCard extends StatelessWidget {
  final Post post;
  final int index;

  const _PostCard({required this.post, required this.index});

  @override
  Widget build(BuildContext context) {
    // 交替宽高比（对应 H5 ar 逻辑：i%3===0 → 3/4, i%3===1 → 1/1, i%3===2 → 4/5）
    final ar = index % 3 == 0 ? 3 / 4 : (index % 3 == 1 ? 1.0 : 4 / 5);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailPage(postId: post.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x8C123A6B), Color(0xBF0A1F3D)],
          ),
          border: Border.all(color: AppColors.sky.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            if (post.images.isNotEmpty)
              AspectRatio(
                aspectRatio: ar,
                child: Image.memory(
                  _decode(post.images.first),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _gradientCover(ar),
                ),
              )
            else
              _gradientCover(ar),
            // 正文
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.text.isNotEmpty)
                    Text(
                      post.text,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEAF2FF), height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  // 标签
                  if (post.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 4,
                        children: post.tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('#$t', style: const TextStyle(fontSize: 10, color: AppColors.gold)),
                        )).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // 作者 + 点赞
                  Row(
                    children: [
                      // 头像（金色渐变圆形）
                      Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.streakPillGradient,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          post.avatar ?? '航',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.goldBtnText),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(post.author, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                      ),
                      // 点赞
                      Text(
                        '♥ ${post.likes}',
                        style: TextStyle(
                          fontSize: 11,
                          color: post.liked ? AppColors.coral : AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 渐变封面 — 对应 H5 .cover.gradient
  Widget _gradientCover(double ar) {
    return AspectRatio(
      aspectRatio: ar,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(post.bgFrom), Color(post.bgTo)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          post.emoji ?? '⚓',
          style: const TextStyle(
            fontSize: 42,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
          ),
        ),
      ),
    );
  }

  Uint8List _decode(String src) {
    final clean = src.contains(',') ? src.split(',').last : src;
    return base64Decode(clean);
  }
}

/// 空状态 — 对应 H5 .empty
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌊', style: TextStyle(fontSize: 44, height: 2)),
          const Text('这片海域还很安静', style: TextStyle(fontSize: 13, color: AppColors.sub, height: 2)),
          const Text('点底栏 ＋ 发出第一条日志', style: TextStyle(fontSize: 11, color: AppColors.sub, height: 2)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 云端错误态（v2.9.2：release 下云端不可用不再回落种子数据，
// 明确告知失败原因 + 重试，防"帖子消失"误解）
// ══════════════════════════════════════════════════════════

class _CloudErrorView extends StatelessWidget {
  const _CloudErrorView({this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌫️', style: TextStyle(fontSize: 44, height: 2)),
          const Text('海域信号不佳，日志加载失败',
              style: TextStyle(fontSize: 13, color: AppColors.sub, height: 2)),
          if (message != null && message!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.sub, height: 1.8)),
            ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 9),
              decoration: const BoxDecoration(
                gradient: AppColors.btnGoldGradient,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: const Text('重新起航',
                  style: TextStyle(
                      color: AppColors.goldBtnText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 云端瀑布流（v2.7 P0，对接 GET /api/post/list）
// ══════════════════════════════════════════════════════════

class _CloudFeedView extends StatelessWidget {
  const _CloudFeedView({
    required this.loader,
    required this.filterId,
    required this.onFilterChanged,
    required this.sortId,
    required this.onSortChanged,
    required this.feedCtrl,
    required this.cardKeys,
    this.highlightPostId,
  });

  final CloudFeedLoader loader;
  final String filterId;
  final ValueChanged<String> onFilterChanged;
  final String sortId; // latest | hot
  final ValueChanged<String> onSortChanged;
  final ScrollController feedCtrl; // 发布后定位滚动
  final Map<int, GlobalKey> cardKeys; // postId → 卡片 key（定位用）
  final int? highlightPostId; // 定位成功短暂高亮的帖子

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loader,
      builder: (context, _) {
        final filters = [
          ('all', '全部'),
          ...Island.all.map((i) => (i.id, i.name)),
        ];
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // 触底预加载（距底部 400px 开始拉下一页）
            if (n.metrics.extentAfter < 400 &&
                n is ScrollUpdateNotification &&
                !loader.loadingMore &&
                !loader.reachedEnd) {
              loader.loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            controller: feedCtrl, // v2.9.3：定位滚动用
            physics: const AlwaysScrollableScrollPhysics(), // 下拉刷新始终可用
            slivers: [
              SliverToBoxAdapter(
                child: Column(children: [
                  // 岛屿筛选行（切岛后在岛内按当前排序刷新）
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: filters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final (id, name) = filters[i];
                        final active = filterId == id;
                        return GestureDetector(
                          onTap: () => onFilterChanged(id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: active ? AppColors.btnGoldGradient : null,
                              color: active ? null : AppColors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: active ? null : Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                color: active ? AppColors.goldBtnText : AppColors.foam,
                                fontSize: 12,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // 最新/热门切换行（v2.9.2 单列时间线）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Row(children: [
                      _sortTab('latest', '🕐 最新'),
                      const SizedBox(width: 8),
                      _sortTab('hot', '🔥 热门'),
                    ]),
                  ),
                ]),
              ),
              if (loader.loading && loader.posts.isEmpty)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
              else if (loader.posts.isEmpty)
                const SliverFillRemaining(child: _EmptyState())
              else ...[
                // v2.9.2：单列纵向时间线（对标 X Feed，卡片全宽、高度自适应、不截断正文）
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  sliver: SliverList.builder(
                    itemCount: loader.posts.length,
                    itemBuilder: (_, i) {
                      final p = loader.posts[i];
                      final highlighted = p.postId == highlightPostId; // 同为 int，类型匹配
                      // 卡片 key 惰性创建（发布后定位滚动依赖它找到卡片位置）
                      final key = cardKeys.putIfAbsent(p.postId, () => GlobalKey());
                      return KeyedSubtree(
                        key: key,
                        child: Container(
                          // Bug2 修复：金框必须用 foregroundDecoration ——
                          // decoration 绘制在 child 之下，会被卡片自身的不透明
                          // 渐变背景完全盖住（高亮渲染了但不可见）；
                          // foregroundDecoration 绘制在 child 之上，且不影响布局
                          foregroundDecoration: highlighted
                              ? BoxDecoration(
                                  border: Border.all(color: AppColors.gold, width: 2.5),
                                  borderRadius: BorderRadius.circular(14),
                                )
                              : null,
                          child: _CloudCard(
                            post: p,
                            isHot: sortId == 'hot',
                            loader: loader,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 触底状态条
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        loader.loadingMore
                            ? '正在打捞更多日志…'
                            : loader.reachedEnd
                                ? '已经到底啦 · 共 ${loader.posts.length} 条'
                                : '',
                        style: const TextStyle(fontSize: 11, color: AppColors.sub),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sortTab(String id, String label) {
    final active = sortId == id;
    return GestureDetector(
      onTap: () => onSortChanged(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? AppColors.btnGoldGradient : null,
          color: active ? null : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.goldBtnText : AppColors.foam,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 云端单列时间线卡片（v2.9.2：全宽、高度自适应内容、不截断正文）
/// 结构：封面 → 标题正文 → 岛屿/标签 → 作者行（头像昵称 + 点赞/评论）→ 触达详情页
/// [isHot] 热门流时右上角显示 🔥 标识
class _CloudCard extends StatelessWidget {
  const _CloudCard({required this.post, required this.loader, this.isHot = false});

  final CloudPost post;
  final CloudFeedLoader loader;
  final bool isHot;

  @override
  Widget build(BuildContext context) {
    final isImage = post.coverKeys.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          // ⚠️ loader 必须传入：详情页点赞/发评论后经 loader 同步回列表卡片
          builder: (_) => CloudPostDetailPage(post: post, loader: loader),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x8C123A6B), Color(0xBF0A1F3D)],
          ),
          border: Border.all(color: AppColors.sky.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 多图网格（v2.9.4：1 全宽 / 2 并排 / 3 一行三张 / 4 田字格；
                // >4 张卡片展示前 4，点击任意一张进全屏预览器可看全部）
                if (isImage)
                  PostImageGrid(
                    postId: post.postId,
                    keys: post.coverKeys,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  ),
                // 正文（单列时间线：不截断，完整展示）
                Padding(
                  padding: EdgeInsets.fromLTRB(14, isImage ? 12 : 16, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.content.isNotEmpty)
                        Text(
                          _cardBody(post.content),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFEAF2FF), height: 1.5),
                        ),
                      // #话题标签（v2.9.4：移除岛屿主标签胶囊 —— 顶部岛屿 Tab 已做分类，
                      // 卡片内再展示主岛属于冗余；#话题标签原样保留）
                      if (post.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ...post.tags.map((t) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('#$t', style: const TextStyle(fontSize: 10, color: AppColors.gold)),
                                  )),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      // 作者行 + 点赞/评论
                      Row(
                        children: [
                          // 作者头像（v2.9.6：点击 → 对应他人主页；
                          // 自己的头像由页面内部判定 → 自身公开访客预览）
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => UserProfilePage(uid: post.author.uid)),
                            ),
                            child: Container(
                              width: 24, height: 24,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.streakPillGradient,
                              ),
                              alignment: Alignment.center,
                              child: UserAvatar(
                                avatar: post.author.avatar,
                                fallbackText: post.author.displayName,
                                size: 24,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(post.author.displayName, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => CloudPostDetailPage(post: post, loader: loader)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              // v2.9.2：♥ 字符在安卓渲染为 emoji 自带红色 → 改 Icon 组件保证颜色可控
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    post.liked ? Icons.favorite : Icons.favorite_border,
                                    color: post.liked ? AppColors.coral : AppColors.foam,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${post.likeCount}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: post.liked ? AppColors.coral : AppColors.foam,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => CloudPostDetailPage(post: post, loader: loader)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                '💬 ${post.commentCount}',
                                style: const TextStyle(fontSize: 12, color: AppColors.sub),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
            // 热门流：右上角 🔥 标识
            if (isHot)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('🔥 热门', style: TextStyle(fontSize: 10, color: AppColors.goldLight)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 港口卡片正文截断（v2.9.2，对标 X）：
  /// ≤140 字符完整展示；>140 截前 140 字符 + 「…」，详情页看全文。
  /// 截断保护：截断点落在 #话题标签 中间时向前微调到标签起始处，不切半个标签。
  String _cardBody(String text) {
    const maxChars = 140;
    final chars = text.characters.toList();
    if (chars.length <= maxChars) return text;
    var cut = maxChars;
    final prefix = chars.take(cut).join();
    final hashIdx = prefix.lastIndexOf('#');
    if (hashIdx >= 0) {
      final after = prefix.substring(hashIdx + 1);
      // # 后到截断点之间没有空白 → 标签未闭合，被切了一半 → 截到 # 之前
      if (!after.contains(' ') && !after.contains('\n')) {
        cut = hashIdx;
      }
    }
    return '${chars.take(cut).join().trimRight()}…';
  }
}
