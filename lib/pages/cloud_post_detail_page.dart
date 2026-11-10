import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_feed.dart';
import '../services/cloud_models.dart';
import '../services/session_store.dart';
import '../services/social_state.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/image_viewer.dart';
import '../widgets/social_dialogs.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_page.dart';

/// 云端帖子详情页（v2.7 P0，对接 GET /api/post/:postId 全套交互）
///
/// 与本地版 PostDetailPage 并存：本地种子数据走老页面，
/// 云端帖子（PortTab 云端模式）走本页 —— 互不影响，老链路零改动。
///
/// 基础交互：封面轮播（时效签名）· 点赞切换 · 评论分页 · 发评论 ·
/// 关注/取关（全局联动）· 「···」菜单（举报/拉黑收纳，拉黑标准二次确认）。
/// v2.9.6 改造：
///   - 本人日志：右上角不展示关注按钮（也不展示 ···）
///   - 非本人：作者行右侧金色【关注/已关注】主按钮 + 顶栏「···」菜单
///   - 拉黑/举报从原位置移除，收纳进「···」菜单；拉黑专属二次确认弹窗
///   - 作者/评论头像点击 → 对应他人主页（自己的头像 → 自身公开访客预览）
/// 异常口径与后端一致：401 引导登录 / 403 权限或风控 / 404 统一"帖子不存在"。
class CloudPostDetailPage extends StatefulWidget {
  const CloudPostDetailPage({super.key, required this.post, this.loader});

  /// 列表带入的帖子（先渲染再拉详情，秒开）
  final CloudPost post;

  /// 来源瀑布流 loader（点赞/评论数同步回列表；可空）
  final CloudFeedLoader? loader;

  @override
  State<CloudPostDetailPage> createState() => _CloudPostDetailPageState();
}

class _CloudPostDetailPageState extends State<CloudPostDetailPage> {
  final CloudApi _api = CloudApi.instance;
  final TextEditingController _commentCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late CloudPost _post;
  final List<CloudComment> _comments = <CloudComment>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _reachedEnd = false;
  bool _likeBusy = false;
  bool _followBusy = false;
  bool _isSelf = false; // 本人日志（右上角不展示关注按钮）
  bool _selfResolved = false; // 本人判定完成前不渲染关注按钮（防闪现）
  String? _fatal; // 404 等：整页占位

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _reload();
    _resolveSelf();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// 本人日志判定：MeState 缓存的云端 uid == 作者 uid（未登录/拉取失败按非本人，
  /// 后端对本人日志也会下发关注状态=false，关注按钮误展示时点击会被后端拒绝）
  Future<void> _resolveSelf() async {
    try {
      final uid = await MeState.instance.uid();
      if (!mounted) return;
      setState(() {
        _isSelf = uid == _post.author.uid;
        _selfResolved = true;
      });
    } on ApiException {
      // 未登录/401 → 非本人视角
      if (!mounted) return;
      setState(() => _selfResolved = true);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreComments();
    }
  }

  Future<void> _reload() async {
    try {
      final CloudPost fresh = await _api.fetchPostDetail(_post.postId);
      if (!mounted) return;
      setState(() {
        _post = fresh;
        _comments.clear();
        _reachedEnd = false;
      });
      await _loadCommentsPage(1);
      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // 后端口径：不存在/被拉黑/审核不通过统一 404，不区分原因
        _fatal = e.code == 404 ? '帖子不存在或已沉入深海' : e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadCommentsPage(int page) async {
    final PagedComments r =
        await _api.fetchComments(_post.postId, page: page, size: 10);
    if (!mounted) return;
    setState(() {
      final known = _comments.map((c) => c.commentId).toSet();
      _comments.addAll(r.list.where((c) => !known.contains(c.commentId)));
      _reachedEnd = !r.hasMore;
    });
  }

  Future<void> _loadMoreComments() async {
    if (_loadingMore || _reachedEnd || _loading) return;
    _loadingMore = true;
    try {
      await _loadCommentsPage((_comments.length / 10).floor() + 1);
    } on ApiException {
      // 评论追加失败静默（下次触底再试）
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    if (!SessionStore.instance.hasToken) {
      _toast('请先登录后再点亮航标');
      return;
    }
    _likeBusy = true;
    try {
      final LikeResult r = await _api.toggleLike(_post.postId);
      if (!mounted) return;
      setState(() => _post = _copyWith(likeCount: r.likeCount, liked: r.liked));
      // ⚠️ 只同步结果，不再调接口（loader.toggleLike 会二次 toggle 把点赞取消掉）
      widget.loader?.applyLikeResult(_post.postId, likeCount: r.likeCount, liked: r.liked);
    } on ApiException catch (e) {
      _toast(e.code == 401 ? '登录已失效，请重新登录' : e.message);
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    if (!SessionStore.instance.hasToken) {
      _toast('请先登录后再发言');
      return;
    }
    try {
      await _api.createComment(_post.postId, text);
      _commentCtrl.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => _post = _copyWith(commentCount: _post.commentCount + 1));
      widget.loader?.bumpCommentCount(_post.postId);
      await _loadCommentsPage(1); // 重拉第一页，新评论置顶可见
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  // ── 关注/取关（FollowState 全局联动：他人主页实时同步）──
  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    if (!SessionStore.instance.hasToken) {
      _toast('请先登录后再关注其他船长');
      return;
    }
    _followBusy = true;
    try {
      await FollowState.instance.toggle(_post.author.uid);
    } on ApiException catch (e) {
      _toast(e.code == 401 ? '登录已失效，请重新登录' : e.message);
    } finally {
      _followBusy = false;
    }
  }

  // ── ··· 菜单（举报/拉黑/取消；拉黑弹专属二次确认）──
  Future<void> _showMoreMenu() async {
    final action = await showMoreActionsSheet(
      context,
      nickname: _post.author.displayName,
    );
    if (!mounted || action == null) return;
    if (action == 'report') {
      await _report();
    } else if (action == 'block') {
      await _blockAuthor();
    }
  }

  Future<void> _report() async {
    final reason = await _askText('举报这条日志', '填写举报原因（≤200 字）', maxLength: 200);
    if (reason == null || reason.trim().isEmpty) return;
    try {
      final ReportResult r = await _api.submitReport(
        type: 'post',
        targetId: _post.postId,
        reason: reason.trim(),
      );
      if (!mounted) return;
      _toast(r.duplicated ? '您已提交过举报，正在人工审核中' : '举报已提交，等待人工审核');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  /// 拉黑（v2.9.6：统一标准二次确认弹窗，文案/按钮全站一致）
  Future<void> _blockAuthor() async {
    final ok = await showBlockConfirmDialog(context);
    if (ok != true) return;
    if (!SessionStore.instance.hasToken) {
      _toast('请先登录后再操作');
      return;
    }
    try {
      await _api.blockUser(_post.author.uid);
      widget.loader?.removeByAuthor(_post.author.uid);
      if (!mounted) return;
      _toast('已拉黑，对方内容将不再展示');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _openAuthorProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(uid: _post.author.uid),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _fatal != null ? _buildFatal() : _buildBody(),
      ),
    );
  }

  Widget _buildFatal() {
    return Column(children: [
      _buildTopBar(),
      Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌫️', style: TextStyle(fontSize: 44)),
              Text(_fatal!, style: AppTypography.bodySub),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
            child:
                Text('航海日志', style: AppTypography.titleZh, textAlign: TextAlign.center)),
        // v2.9.6：右上角「···」收纳举报/拉黑（本人日志不展示；宽 48 保持标题居中）
        SizedBox(
          width: 48,
          child: (!_isSelf && _fatal == null)
              ? IconButton(
                  icon: const Text('···',
                      style: TextStyle(
                          color: AppColors.foam,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  onPressed: _showMoreMenu,
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    final bool isImage = _post.coverKeys.isNotEmpty;
    return Column(children: [
      _buildTopBar(),
      Expanded(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 多图网格（v2.9.4：与列表卡片同一布局；点击进全屏预览器，
              // 左右滑动可浏览本帖全部图片）
              if (isImage)
                PostImageGrid(
                  postId: _post.postId,
                  keys: _post.coverKeys,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 作者行（v2.9.6：头像/昵称点击 → 他人主页；
                    // 非本人右侧展示金色【关注/已关注】主按钮）
                    Row(children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openAuthorProfile,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: AppColors.ocean),
                          alignment: Alignment.center,
                          child: UserAvatar(
                            avatar: _post.author.avatar,
                            fallbackText: _post.author.displayName,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openAuthorProfile,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_post.author.displayName,
                                style: AppTypography.titleZh.copyWith(fontSize: 15)),
                            Text(_post.createdAt, style: AppTypography.caption),
                          ],
                        ),
                      )),
                      // 关注/已关注（金色主按钮；本人日志不展示 —— 需求一.1；
                      // 本人判定完成前不渲染，防非本人日志按钮闪现）
                      if (!_isSelf && _selfResolved)
                        AnimatedBuilder(
                          animation: FollowState.instance,
                          builder: (context, _) {
                            final following =
                                FollowState.instance.of(_post.author.uid) ?? false;
                            final busy = _followBusy;
                            return GestureDetector(
                              onTap: busy ? null : _toggleFollow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: following ? null : AppColors.btnGoldGradient,
                                  borderRadius: BorderRadius.circular(999),
                                  border: following
                                      ? Border.all(color: AppColors.gold.withValues(alpha: 0.5))
                                      : null,
                                ),
                                child: Text(
                                  following ? '已关注' : '关注',
                                  style: TextStyle(
                                    color: following ? AppColors.gold : AppColors.goldBtnText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ]),
                    const SizedBox(height: 16),
                    if (_post.content.isNotEmpty)
                      Text(_post.content,
                          style: AppTypography.body.copyWith(fontSize: 15, height: 1.7)),
                    if (_post.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: _post.tags
                            .map((t) => Text('#$t',
                                style: const TextStyle(color: AppColors.sky, fontSize: 13)))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // 操作行（v2.9.6：仅保留点赞 —— 举报/拉黑已收纳进右上角「···」菜单）
                    Row(children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(children: [
                          Icon(
                            _post.liked ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: _post.liked ? AppColors.coral : AppColors.sub,
                          ),
                          const SizedBox(width: 4),
                          Text('${_post.likeCount}',
                              style: TextStyle(
                                  color: _post.liked ? AppColors.coral : AppColors.sub)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    // 评论区
                    Text('评论 · ${_post.commentCount}',
                        style: AppTypography.titleZh.copyWith(fontSize: 14)),
                    const SizedBox(height: 10),
                    if (_comments.isEmpty && !_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('还没有评论，来当第一个水手吧',
                            style: TextStyle(color: AppColors.sub, fontSize: 12)),
                      ),
                    ..._comments.map(_buildComment),
                    if (_loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // 评论输入栏
      Container(
        color: AppColors.deep,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 13),
              decoration: InputDecoration(
                hintText: '说点什么…',
                hintStyle: const TextStyle(color: AppColors.sub, fontSize: 13),
                filled: true,
                fillColor: AppColors.abyss,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendComment(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendComment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                gradient: AppColors.btnGoldGradient,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: const Text('发送',
                  style: TextStyle(
                      color: AppColors.goldBtnText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildComment(CloudComment c) {
    // 评论头像/昵称点击 → 该用户他人主页（自己的头像 → 自身公开访客预览）
    void openProfile() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfilePage(uid: c.author.uid)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: openProfile,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
            alignment: Alignment.center,
            child: UserAvatar(
              avatar: c.author.avatar,
              fallbackText: c.author.displayName,
              size: 28,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openProfile,
                child: Text(c.author.displayName,
                    style: const TextStyle(color: AppColors.foam, fontSize: 12)),
              ),
              const Spacer(),
              Text(c.createdAt, style: AppTypography.caption.copyWith(fontSize: 10)),
            ]),
            const SizedBox(height: 2),
            Text(c.content,
                style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 13, height: 1.4)),
          ],
        )),
      ]),
    );
  }

  // ── 工具 ───────────────────────────────────────────────
  CloudPost _copyWith({int? likeCount, bool? liked, int? commentCount}) => CloudPost(
        postId: _post.postId,
        type: _post.type,
        content: _post.content,
        author: _post.author,
        coverKey: _post.coverKey,
        coverKeys: _post.coverKeys,
        island: _post.island,
        tags: _post.tags,
        likeCount: likeCount ?? _post.likeCount,
        liked: liked ?? _post.liked,
        commentCount: commentCount ?? _post.commentCount,
        createdAt: _post.createdAt,
      );

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.ocean, behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _askText(String title, String hint, {int maxLength = 200}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deep,
        title: Text(title, style: const TextStyle(color: AppColors.parchment, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLength: maxLength,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFEAF2FF)),
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppColors.sub)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('提交', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}
