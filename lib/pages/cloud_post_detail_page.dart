import 'dart:async';

import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_feed.dart';
import '../services/cloud_models.dart';
import '../services/session_store.dart';
import '../services/social_state.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/comment_section.dart';
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
  final GlobalKey<CommentSectionState> _sectionKey = GlobalKey();

  late CloudPost _post;
  bool _likeBusy = false;
  bool _followBusy = false;
  bool _isSelf = false; // 本人日志（右上角菜单切删除入口）
  bool _selfResolved = false; // 本人判定完成前不渲染关注按钮（防闪现）
  String? _fatal; // 404 等：整页占位

  // ── v2.9.7 评论输入状态 ──
  int? _myUid; // 本人云端 uid（atUserIds 预埋 / 权限判断）
  CloudComment? _replyTarget; // 回复目标（null = 发一级评论）
  bool _sending = false;
  bool _deletingPost = false;
  final Map<String, int> _atUidMap = {}; // 已知 @昵称 → uid（预埋用）
  bool _atPickerOpen = false; // @搜索弹窗是否打开
  VoidCallback? _closeAtPicker; // 打开中的弹窗关闭句柄（删字时自动收起）
  int _lastTextLength = 0; // 上次文本长度（识别删除动作）
  String _hintText = '说点什么…';
  final FocusNode _commentFocus = FocusNode();

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
    _commentFocus.dispose();
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
        _myUid = uid;
      });
      // 非本人：预拉关注状态初始化 FollowState 缓存（ensure 内部有缓存短路；
      // 否则按钮读 of(uid)??false 恒显示「关注」，已关注者被误展示）
      if (!_isSelf) {
        await FollowState.instance.ensure(_post.author.uid);
      }
    } on ApiException {
      // 未登录/401 → 非本人视角
      if (!mounted) return;
      setState(() => _selfResolved = true);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 200) {
      _sectionKey.currentState?.loadMore();
    }
  }

  Future<void> _reload() async {
    try {
      final CloudPost fresh = await _api.fetchPostDetail(_post.postId);
      if (!mounted) return;
      setState(() => _post = fresh);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // 后端口径：不存在/被拉黑/审核不通过统一 404，不区分原因
        _fatal = e.code == 404 ? '帖子不存在或已沉入深海' : e.message;
      });
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

  // ── ··· 菜单：本人 → 删除日志；非本人 → 举报/拉黑 ──
  Future<void> _showMoreMenu() async {
    if (_isSelf) {
      await _deletePost();
      return;
    }
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

  // ── v2.9.7 评论输入（回复/@用户/发送）────────────────────

  /// 💬 回复：唤起输入框（占位 回复@xxx；回复子评论时预填 @昵称 并记录 atUser）
  void _onReplyTap(CloudComment target) {
    setState(() {
      _replyTarget = target;
      _atUidMap[target.author.displayName] = target.author.uid;
      final hintPrefix = '回复@${target.author.displayName}';
      if (target.isReply) {
        // 回复子评论：预填 @昵称（抖音同款），光标在末尾
        _commentCtrl.text = '@${target.author.displayName} ';
      } else if (_commentCtrl.text.isEmpty) {
        _commentCtrl.text = '';
      }
      _commentCtrl.selection = TextSelection.collapsed(offset: _commentCtrl.text.length);
      _hintText = hintPrefix;
    });
    FocusScope.of(context).requestFocus(_commentFocus);
  }

  /// 点昵称 → 光标处插入 @昵称
  void _onNicknameTap(String nickname, int? uid) {
    if (uid != null) _atUidMap[nickname] = uid;
    final sel = _commentCtrl.selection;
    final pos = sel.baseOffset >= 0 && sel.baseOffset <= _commentCtrl.text.length
        ? sel.baseOffset
        : _commentCtrl.text.length;
    final insert = '@$nickname ';
    final text = _commentCtrl.text;
    _commentCtrl.text = text.substring(0, pos) + insert + text.substring(pos);
    _commentCtrl.selection = TextSelection.collapsed(offset: pos + insert.length);
    setState(() {});
    FocusScope.of(context).requestFocus(_commentFocus);
  }

  /// @ 触发检测（v2.9.7.1 对标 X 交互，修复删字反复弹窗 bug）：
  /// - 仅当【光标前紧邻单独 @（@ 后无任何字符）】才拉起搜索 —— 删 @后面文字
  ///   的过程中 before 是「@xxx」不满足条件，不会反复触发；
  /// - 删字（文本变短）时，打开中的搜索弹窗自动收起。
  void _onCommentChanged(String text) {
    // 需求④：删除文字过程中，打开中的 @搜索弹窗自动收起
    if (text.length < _lastTextLength && _atPickerOpen) {
      _closeAtPicker?.call();
    }
    _lastTextLength = text.length;

    // 需求②③：光标前紧邻单独 @ 才唤起（兼容中文 IME 的全角＠）
    final sel = _commentCtrl.selection;
    final bool beforeAt = sel.isValid &&
        sel.baseOffset > 0 &&
        sel.baseOffset <= text.length &&
        (text.substring(0, sel.baseOffset).endsWith('@') ||
            text.substring(0, sel.baseOffset).endsWith('＠'));
    final bool hitAt = !_atPickerOpen && beforeAt;
    if (hitAt) {
      _openAtPicker(sel.baseOffset - 1);
    }
    setState(() {}); // 刷新发送按钮可用态
  }

  /// @用户选择弹窗（头像 + 昵称，模糊搜索；选中插入 @昵称 并记录 uid）
  Future<void> _openAtPicker(int atStart) async {
    _atPickerOpen = true;
    final picked = await showModalBottomSheet<(String, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // 键盘避让：浮在输入法上方，否则被键盘完全遮挡
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _AtUserPicker(onClose: () => Navigator.pop(sheetCtx)),
      ),
    );
    _atPickerOpen = false;
    _closeAtPicker = null;
    if (!mounted || picked == null) return;
    final (nickname, uid) = picked;
    _atUidMap[nickname] = uid;
    final text = _commentCtrl.text;
    // 替换光标前的 @片段 为 @昵称␣
    final end = _commentCtrl.selection.baseOffset;
    final safeEnd = end >= atStart && end <= text.length ? end : text.length;
    _commentCtrl.text = '${text.substring(0, atStart)}@$nickname ${text.substring(safeEnd)}';
    _commentCtrl.selection = TextSelection.collapsed(offset: atStart + nickname.length + 2);
    _lastTextLength = _commentCtrl.text.length;
    setState(() {});
  }

  /// 从正文提取已选 @昵称 对应的 uid（按 _atUidMap 精确匹配）
  List<int> _collectAtUserIds(String content) {
    final ids = <int>[];
    for (final e in _atUidMap.entries) {
      if (content.contains('@${e.key}')) ids.add(e.value);
    }
    return ids;
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return; // 纯空格/换行禁止提交
    if (!_isLoggedInCheck()) return;
    setState(() => _sending = true);
    try {
      final target = _replyTarget;
      final r = await _api.createComment(
        _post.postId,
        text,
        replyToCommentId: target?.commentId,
        atUserIds: _collectAtUserIds(text),
      );
      if (!mounted) return;
      setState(() {
        _post = _copyWith(commentCount: r.commentCount);
        widget.loader?.applyCommentCount(_post.postId, r.commentCount);
        kCommentCountChangedSignal.value++; // 船长页等独立列表同步评论计数
        _commentCtrl.clear();
        _replyTarget = null;
        _hintText = '说点什么…';
      });
      if (r.comment.isReply) {
        _sectionKey.currentState?.insertReply(r.comment);
      } else {
        _sectionKey.currentState?.insertComment(r.comment);
      }
    } on ApiException catch (e) {
      _toast(e.code == 401 ? '登录已失效，请重新登录' : e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isLoggedInCheck() {
    if (SessionStore.instance.hasToken) return true;
    _toast('请先登录后再评论');
    return false;
  }

  /// 本人删除日志（「···」→ 二次确认 → 后端级联清理 → 回列表页）
  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deep,
        title: Text('删除日志', style: const TextStyle(color: AppColors.parchment, fontSize: 16)),
        content: Text('删除后该日志及其全部评论、点赞将一并移除，且不可恢复',
            style: const TextStyle(color: AppColors.sub, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true || _deletingPost || !mounted) return;
    _deletingPost = true;
    try {
      await _api.deletePost(_post.postId);
      widget.loader?.removePostById(_post.postId);
      kPostDeletedSignal.value++; // 船长页等列表页同步移除
      if (!mounted) return;
      _toast('日志已删除');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _toast(e.code == 401 ? '登录已失效，请重新登录' : e.message);
    } finally {
      _deletingPost = false;
    }
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
        // 右上角「···」：本人 → 删除日志（v2.9.7）；非本人 → 举报/拉黑（v2.9.6）
        SizedBox(
          width: 48,
          child: (!_selfResolved || _fatal != null)
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Text('···',
                      style: TextStyle(
                          color: AppColors.foam,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  onPressed: _showMoreMenu,
                ),
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
                    // 评论区（v2.9.7：CommentSection 全套承接，评论/子评论/展开收起/长按菜单）
                    Text('评论 · ${_post.commentCount}',
                        style: AppTypography.titleZh.copyWith(fontSize: 14)),
                    const SizedBox(height: 10),
                    CommentSection(
                      key: _sectionKey,
                      postId: _post.postId,
                      postAuthorUid: _post.author.uid,
                      myUid: _myUid,
                      onReplyTap: _onReplyTap,
                      onNicknameTap: _onNicknameTap,
                      onCountChanged: (int remain) {
                        setState(() => _post = _copyWith(commentCount: remain));
                        widget.loader?.applyCommentCount(_post.postId, remain);
                        kCommentCountChangedSignal.value++; // 船长页等独立列表同步评论计数
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // 评论输入栏（v2.9.7：回复状态占位 / 空内容置灰 / @检测）
      Container(
        color: AppColors.deep,
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom * 0),
        child: Row(children: [
          if (_replyTarget != null)
            GestureDetector(
              onTap: () => setState(() {
                _replyTarget = null;
                _hintText = '说点什么…';
              }),
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.close, size: 16, color: AppColors.sub),
              ),
            ),
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              focusNode: _commentFocus,
              style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 13),
              onChanged: _onCommentChanged,
              decoration: InputDecoration(
                hintText: _hintText,
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
            onTap: _commentCtrl.text.trim().isEmpty ? null : _sendComment,
            child: Opacity(
              opacity: _commentCtrl.text.trim().isEmpty ? 0.4 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: AppColors.btnGoldGradient,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(_sending ? '…' : '发送',
                    style: const TextStyle(
                        color: AppColors.goldBtnText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    ]);
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

/// @用户选择弹窗（v2.9.7）：搜索框 + 头像/昵称结果列表；
/// 选中返回 (nickname, uid)，头像走 OSS key 签名加载，失败回退首字占位。
/// [onClose] 供外部（删字自动收起）程序化关闭。
class _AtUserPicker extends StatefulWidget {
  const _AtUserPicker({this.onClose});

  final VoidCallback? onClose;

  @override
  State<_AtUserPicker> createState() => _AtUserPickerState();
}

class _AtUserPickerState extends State<_AtUserPicker> {
  final CloudApi _api = CloudApi.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  List<CloudUserSearchItem> _results = <CloudUserSearchItem>[];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => _onSearchChanged(_searchCtrl.text));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _doSearch);
  }

  Future<void> _doSearch() async {
    setState(() => _loading = true);
    try {
      final r = await _api.searchUsers(_searchCtrl.text);
      if (!mounted) return;
      setState(() => _results = r);
    } on ApiException {
      if (!mounted) return;
      setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.only(top: 14),
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: AppColors.deep,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          // 顶部：搜索框 + 关闭
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索昵称，选择要 @ 的船长',
                    hintStyle: const TextStyle(color: AppColors.sub, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.sub),
                    filled: true,
                    fillColor: AppColors.abyss,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.sub),
                onPressed: widget.onClose,
              ),
            ]),
          ),
          const Divider(color: AppColors.line, height: 1),
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold)))
                : _results.isEmpty
                    ? const Center(
                        child: Text('输入昵称关键词搜索',
                            style: TextStyle(color: AppColors.sub, fontSize: 12)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: AppColors.line, height: 1, indent: 16),
                        itemBuilder: (_, i) {
                          final u = _results[i];
                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: AppColors.ocean),
                              child: UserAvatar(
                                avatar: u.avatar,
                                fallbackText: u.displayName,
                                size: 36,
                                fontSize: 15,
                              ),
                            ),
                            title: Text(u.displayName,
                                style: const TextStyle(
                                    color: Color(0xFFEAF2FF), fontSize: 14)),
                            onTap: () =>
                                Navigator.pop(context, (u.displayName, u.userId)),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
