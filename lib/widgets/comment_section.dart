import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/user_profile_page.dart';
import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../services/session_store.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'user_avatar.dart';

/// 航海日志评论区（v2.9.7 评论系统 v2，交互对齐抖音）：
/// - 一级评论：头像/昵称 → 他人主页；长按 500ms → 复制/删除（权限）菜单；
///   💬 回复 / ❤️ 点赞；【作者】轻标识；日期展示
/// - 子评论：缩进树；▶@昵称 三角标识（回复子评论场景）；同款点赞/回复/长按
/// - 展开/收起：默认前 2 条 → 【查看全部 N 条回复】→ 转圈 loading → 收起
/// - @昵称正文蓝色高亮可点击（点击插入输入框）；atUserIds 仅预埋不触发通知
class CommentSection extends StatefulWidget {
  const CommentSection({
    super.key,
    required this.postId,
    required this.postAuthorUid,
    required this.myUid,
    required this.onReplyTap,
    required this.onNicknameTap,
    required this.onCountChanged,
  });

  final int postId;
  final int postAuthorUid;

  /// 当前登录用户 uid（未登录为 null → 不显示删除项/不能点赞提示登录）
  final int? myUid;

  /// 点 💬：回调目标评论（详情页唤起回复输入框）
  final void Function(CloudComment target) onReplyTap;

  /// 点昵称：插入 @昵称 到输入框（uid 供 atUserIds 预埋，正文 span 点击可能为 null）
  final void Function(String nickname, int? uid) onNicknameTap;

  /// 帖子评论总数变化（删除评论后同步顶部计数）
  final void Function(int commentCount) onCountChanged;

  @override
  State<CommentSection> createState() => CommentSectionState();
}

/// 子评论线程（一条一级评论的回复集合 + 分页/展开状态）
class _ReplyThread {
  final List<CloudComment> list = <CloudComment>[];
  int total = 0;
  int page = 0;
  bool expanded = false;
  bool loading = false;

  bool get loadedAll => list.length >= total;

  /// 收起状态展示前 2 条
  List<CloudComment> visible() => expanded ? list : list.take(2).toList();
}

class CommentSectionState extends State<CommentSection> {
  final CloudApi _api = CloudApi.instance;
  final List<CloudComment> _comments = <CloudComment>[]; // 一级评论（时间正序）
  final Map<int, _ReplyThread> _threads = <int, _ReplyThread>{};
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};

  bool _loading = true;
  bool _loadingMore = false;
  bool _reachedEnd = false;
  final Set<int> _likeBusy = <int>{}; // 评论点赞防抖
  bool _deleting = false;

  bool get _isLoggedIn => SessionStore.instance.hasToken;

  @override
  void initState() {
    super.initState();
    loadFirst();
  }

  GlobalKey _keyOf(int commentId) =>
      _itemKeys.putIfAbsent(commentId, () => GlobalKey());

  // ── 数据加载 ─────────────────────────────────────────────

  Future<void> loadFirst() async {
    try {
      final PagedComments r = await _api.fetchComments(widget.postId, page: 1, size: 10);
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(r.list);
        _reachedEnd = !r.hasMore;
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || _reachedEnd || _loading) return;
    _loadingMore = true;
    try {
      final PagedComments r =
          await _api.fetchComments(widget.postId, page: (_comments.length / 10).floor() + 1, size: 10);
      if (!mounted) return;
      setState(() {
        final known = _comments.map((c) => c.commentId).toSet();
        _comments.addAll(r.list.where((c) => !known.contains(c.commentId)));
        _reachedEnd = !r.hasMore;
      });
    } on ApiException {
      // 静默（下次触底再试）
    } finally {
      _loadingMore = false;
      if (mounted) setState(() {});
    }
  }

  /// 发送成功后插入一级评论（追加尾部，时间正序口径）
  void insertComment(CloudComment c) {
    setState(() => _comments.add(c));
    _scrollTo(c.commentId);
  }

  /// 发送成功后插入子评论（对齐抖音实时行为）：
  /// 收起状态：≤2 直接展示，>2 维持前 2、按钮 N+1；展开状态：直接追加
  void insertReply(CloudComment reply) {
    final rootId = reply.rootCommentId;
    if (rootId == null) return;
    final t = _threads.putIfAbsent(rootId, () {
      final parent = _comments.where((c) => c.commentId == rootId).firstOrNull;
      return _ReplyThread()..total = parent?.replyCount ?? 0;
    });
    setState(() {
      if (!t.list.any((x) => x.commentId == reply.commentId)) t.list.add(reply);
      t.total += 1;
      final parentIdx = _comments.indexWhere((c) => c.commentId == rootId);
      if (parentIdx >= 0) {
        _comments[parentIdx] = _comments[parentIdx].copyWith(replyCount: t.total);
      }
    });
    _scrollTo(reply.commentId);
  }

  /// 滚动定位到刚发布的评论/子评论
  void _scrollTo(int commentId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyOf(commentId).currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
    });
  }

  // ── 子评论展开/收起 ──────────────────────────────────────

  _ReplyThread _threadOf(int rootId) {
    return _threads.putIfAbsent(rootId, () {
      final parent = _comments.where((c) => c.commentId == rootId).firstOrNull;
      return _ReplyThread()..total = parent?.replyCount ?? 0;
    });
  }

  Future<void> _expandReplies(int rootId) async {
    final t = _threadOf(rootId);
    if (t.loading) return;
    t.loading = true;
    if (mounted) setState(() {}); // 按钮位置换转圈
    try {
      final PagedComments r =
          await _api.fetchReplies(rootId, page: t.page + 1, size: 10);
      if (!mounted) return;
      setState(() {
        final known = t.list.map((x) => x.commentId).toSet();
        t.list.addAll(r.list.where((x) => !known.contains(x.commentId)));
        t.total = r.total;
        t.page += 1;
        t.expanded = true;
      });
    } on ApiException {
      // 失败静默：按钮复原可重试（需求 15）
    } finally {
      t.loading = false;
      if (mounted) setState(() {});
    }
  }

  void _collapseReplies(int rootId) {
    setState(() => _threadOf(rootId).expanded = false);
  }

  // ── 点赞（防抖）─────────────────────────────────────────

  Future<void> _toggleCommentLike(CloudComment c) async {
    if (_likeBusy.contains(c.commentId)) return;
    if (!_isLoggedIn) {
      _toast('请先登录后再点亮航标');
      return;
    }
    _likeBusy.add(c.commentId);
    try {
      final LikeResult r = await _api.toggleCommentLike(c.commentId);
      if (!mounted) return;
      setState(() => _replace(c.copyWith(likeCount: r.likeCount, liked: r.liked)));
    } on ApiException catch (e) {
      _toast(e.code == 401 ? '登录已失效，请重新登录' : e.message);
    } finally {
      _likeBusy.remove(c.commentId);
    }
  }

  /// 按评论 id 在一级/子评论两层替换（乐观更新用）
  void _replace(CloudComment updated) {
    final i = _comments.indexWhere((x) => x.commentId == updated.commentId);
    if (i >= 0) {
      _comments[i] = updated;
      return;
    }
    final rootId = updated.rootCommentId;
    if (rootId == null) return;
    final t = _threads[rootId];
    if (t == null) return;
    final j = t.list.indexWhere((x) => x.commentId == updated.commentId);
    if (j >= 0) t.list[j] = updated;
  }

  // ── 删除（长按菜单入口，二次确认在详情页/本组件弹窗）────────

  Future<void> _confirmDelete(CloudComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deep,
        title: Text('删除评论', style: const TextStyle(color: AppColors.parchment, fontSize: 16)),
        content: Text(
          c.isReply ? '删除该回复？其下属回复将一并移除' : '删除该评论？其下属全部回复将一并移除',
          style: const TextStyle(color: AppColors.sub, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true || _deleting || !mounted) return;
    _deleting = true;
    try {
      final int remain = await _api.deleteComment(c.commentId);
      if (!mounted) return;
      setState(() {
        widget.onCountChanged(remain);
        if (c.isReply) {
          final t = _threads[c.rootCommentId];
          if (t != null) {
            t.list.removeWhere((x) => x.commentId == c.commentId);
            t.total = (t.total - 1).clamp(0, 1 << 31);
            // 剩余 ≤2 自动收起、去按钮（需求 13）
            if (t.total <= 2) t.expanded = false;
            final parentIdx = _comments.indexWhere((x) => x.commentId == c.rootCommentId);
            if (parentIdx >= 0) {
              _comments[parentIdx] = _comments[parentIdx].copyWith(replyCount: t.total);
            }
          }
        } else {
          _comments.removeWhere((x) => x.commentId == c.commentId);
          _threads.remove(c.commentId);
        }
      });
      _toast('已删除');
    } on ApiException catch (e) {
      _toast(e.code == 401 ? '登录已失效，请重新登录' : e.message);
    } finally {
      _deleting = false;
    }
  }

  // ── 长按菜单（复制 / 删除 / 取消）────────────────────────

  Future<void> _showActions(CloudComment c, {int? parentAuthorUid}) async {
    final me = widget.myUid;
    final canDelete = me != null &&
        (c.author.uid == me || widget.postAuthorUid == me || (parentAuthorUid != null && parentAuthorUid == me));
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.deep,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetItem('复制', () => Navigator.pop(context, 'copy')),
            if (canDelete)
              _sheetItem('删除评论', () => Navigator.pop(context, 'delete'),
                  color: AppColors.coral),
            _sheetItem('取消', () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: c.content));
      if (!mounted) return;
      _toast('已复制');
    } else if (action == 'delete') {
      await _confirmDelete(c);
    }
  }

  Widget _sheetItem(String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: color ?? const Color(0xFFEAF2FF),
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          backgroundColor: AppColors.ocean,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 800)),
    );
  }

  // ── UI ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('暂无评论，快来抢沙发',
                  style: TextStyle(color: AppColors.sub, fontSize: 12)),
            ),
          )
        else
          ..._comments.map((c) => _buildComment(c)),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ],
    );
  }

  /// 评论正文：@昵称 蓝色高亮可点击（点击 → 输入框插入 @昵称）
  List<InlineSpan> _buildContentSpans(String content) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'@[^@\s，。！？；、]+');
    var last = 0;
    for (final m in regex.allMatches(content)) {
      if (m.start > last) spans.add(_plainSpan(content.substring(last, m.start)));
      final tag = m.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onNicknameTap(tag, null),
          child: Text(tag,
              style: const TextStyle(
                  color: AppColors.sky, fontSize: 13, height: 1.4)),
        ),
      ));
      last = m.end;
    }
    if (last < content.length) spans.add(_plainSpan(content.substring(last)));
    return spans;
  }

  InlineSpan _plainSpan(String s) => TextSpan(
      text: s, style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 13, height: 1.4));

  /// 统一日期展示（需求：不做相对时间，只取日期部分）
  static String _fmtDate(String raw) {
    final s = raw.trim();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  void _openProfile(int uid) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
    );
  }

  /// 昵称行：昵称 +【作者】轻标识 + 日期
  Widget _nameRow(CloudComment c, {double fontSize = 12}) {
    return Row(children: [
      Flexible(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onNicknameTap(c.author.displayName, c.author.uid),
          onLongPress: null,
          child: Text(c.author.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.foam, fontSize: fontSize)),
        ),
      ),
      if (c.isPostAuthor) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('作者',
              style: const TextStyle(color: AppColors.gold, fontSize: 9)),
        ),
      ],
      const Spacer(),
      Text(_fmtDate(c.createdAt),
          style: AppTypography.caption.copyWith(fontSize: 10)),
    ]);
  }

  /// 💬回复 / ❤️点赞 操作行（emoji 图标 + 数字，间距加大防误触）
  Widget _actionRow(CloudComment c) {
    return Row(children: [
      const SizedBox(width: 24),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onReplyTap(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(children: [
            const Text('💬', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 3),
            Text('${c.isReply ? 0 : c.replyCount}',
                style: const TextStyle(color: AppColors.sub, fontSize: 11)),
          ]),
        ),
      ),
      const SizedBox(width: 24),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleCommentLike(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(children: [
            Text(c.liked ? '❤️' : '🤍', style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 3),
            Text('${c.likeCount}',
                style: TextStyle(
                    color: c.liked ? AppColors.coral : AppColors.sub, fontSize: 11)),
          ]),
        ),
      ),
    ]);
  }

  /// 一级评论（含子评论预览/展开）
  Widget _buildComment(CloudComment c) {
    final t = _threads[c.commentId];
    return Container(
      key: _keyOf(c.commentId),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _showActions(c),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openProfile(c.author.uid),
              child: Container(
                width: 28,
                height: 28,
                decoration:
                    const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
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
                _nameRow(c),
                const SizedBox(height: 2),
                Text.rich(TextSpan(children: _buildContentSpans(c.content))),
                const SizedBox(height: 4),
                _actionRow(c),
              ],
            )),
          ]),
        ),
        // 子评论（缩进树）
        if (t != null && t.list.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...t.visible().map((r) => _buildReply(r, parent: c)),
                if ((t.total > 2 && !t.expanded) || t.loading || (t.expanded && !t.loadedAll))
                  _buildExpandButton(c.commentId, t),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  /// 子评论条目（缩进 + 场景B ▶@昵称）
  Widget _buildReply(CloudComment r, {required CloudComment parent}) {
    return Container(
      key: _keyOf(r.commentId),
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _showActions(r, parentAuthorUid: parent.author.uid),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openProfile(r.author.uid),
            child: Container(
              width: 22,
              height: 22,
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
              alignment: Alignment.center,
              child: UserAvatar(
                avatar: r.author.avatar,
                fallbackText: r.author.displayName,
                size: 22,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _nameRow(r, fontSize: 11),
              const SizedBox(height: 2),
              // 场景A：回复一级评论 → 只缩进无三角；场景B：▶ @昵称：内容
              Text.rich(TextSpan(children: [
                if (r.replyToNickname != null) ...[
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onReplyTap(r), // ▶ 后 @昵称可点击 → 回复该用户
                      child: Text('▶ @${r.replyToNickname} ：',
                          style: const TextStyle(
                              color: AppColors.sub,
                              fontSize: 12.5,
                              height: 1.4)),
                    ),
                  ),
                ],
                ..._buildContentSpans(r.content),
              ])),
              const SizedBox(height: 4),
              _actionRow(r),
            ],
          )),
        ]),
      ),
    );
  }

  /// 展开/收起按钮（查看全部 N 条回复 / 转圈 / 收起回复）
  Widget _buildExpandButton(int rootId, _ReplyThread t) {
    Widget child;
    if (t.loading) {
      child = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky)),
      );
    } else if (t.expanded && t.loadedAll) {
      child = const Text('收起回复',
          style: TextStyle(color: AppColors.sky, fontSize: 12));
    } else {
      final n = t.expanded ? (t.total - t.list.length) : (t.total - 2);
      child = Text('查看全部 $n 条回复',
          style: const TextStyle(color: AppColors.sky, fontSize: 12));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (t.loading) return;
        if (t.expanded && t.loadedAll) {
          _collapseReplies(rootId);
        } else {
          _expandReplies(rootId);
        }
      },
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child),
    );
  }
}
