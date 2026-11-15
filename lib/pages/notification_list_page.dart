import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../theme/colors.dart';
import '../widgets/alert_toast.dart';
import 'cloud_post_detail_page.dart';
import '../widgets/user_avatar.dart';

/// 消息列表页（v2.9.9 消息中心，4 类共用）：
/// 日志获赞 / 评论获赞 / 评论回复 / 被@提及
/// - like 类按 (postId/commentId) 聚合：「磐石、南十字等4人点赞了你的航海日志」
/// - reply/mention 逐条展示；条目只承载头像+昵称+动作文案，无日志预览图
/// - 点击条目 → 标记已读 → 跳日志详情（like_post 定位主体，其余定位评论）
/// - AppBar 支持一键标记该分类全部已读；空态「暂无消息，等待船员互动」
class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key, required this.type, this.onChanged});

  final String type; // like_post / like_comment / reply / mention

  /// 未读变化回调（闹市入口栏角标同步）
  final VoidCallback? onChanged;

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  final CloudApi _api = CloudApi.instance;
  final List<CloudNotification> _items = [];
  bool _loading = true;
  bool _marking = false;
  bool _busy = false; // 单条跳转防重复

  String get _typeTitle {
    switch (widget.type) {
      case 'like_post':
        return '日志获赞';
      case 'like_comment':
        return '评论获赞';
      case 'reply':
        return '评论回复';
      default:
        return '被@提及';
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final list = await _api.fetchNotifications(type: widget.type);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAlertToast(context, e.message);
    }
  }

  /// like 类聚合：按 postId（like_post）/ commentId（like_comment）分组，
  /// 新 → 旧排序；组内取最近 2 个昵称，其余「等N人」
  List<_Group> get _groups {
    if (widget.type != 'like_post' && widget.type != 'like_comment') {
      return _items.map((n) => _Group(ids: [n.id], actors: [n], postId: n.postId, commentId: n.commentId)).toList();
    }
    final map = <String, _Group>{};
    for (final n in _items) {
      final key = '${n.postId ?? 0}:${n.commentId ?? 0}';
      final g = map.putIfAbsent(key, () => _Group(ids: [], actors: [], postId: n.postId, commentId: n.commentId));
      g.ids.add(n.id);
      g.actors.add(n);
    }
    final list = map.values.toList();
    list.sort((a, b) => b.actors.first.createdAt.compareTo(a.actors.first.createdAt));
    return list;
  }

  /// 聚合文案：「磐石、南十字等4人点赞了你的航海日志」/「磐石点赞了你的评论」
  /// 返回 (金色昵称部分, 动作文案部分)
  (String, String) _entryParts(_Group g) {
    final actors = g.actors;
    final n = actors.length;
    switch (widget.type) {
      case 'like_post':
      case 'like_comment':
        final names = actors.take(2).map((x) => x.actorNickname ?? '船员${x.actorId}').toList();
        final head = n <= 2 ? names.join('、') : '${names.join('、')}等$n人';
        final action =
            widget.type == 'like_post' ? '点赞了你的航海日志' : '点赞了你的评论';
        return (head, action);
      case 'reply':
        return (actors.first.actorNickname ?? '船员', '回复了你的评论');
      default:
        return (actors.first.actorNickname ?? '船员', '在评论中提到了你');
    }
  }

  String _timeLabel(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${t.month}月${t.day}日';
  }

  Future<void> _markRead(List<int> ids) async {
    try {
      await _api.markNotificationsRead(ids);
      widget.onChanged?.call();
    } on ApiException {
      // 已读失败不影响跳转
    }
  }

  Future<void> _markAllRead() async {
    if (_marking) return;
    setState(() => _marking = true);
    try {
      await _api.markAllNotificationsRead(widget.type);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('已全部标记为已读', style: TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: AppColors.ocean,
        behavior: SnackBarBehavior.floating,
      ));
      widget.onChanged?.call();
      await _reload();
    } on ApiException catch (e) {
      if (mounted) showAlertToast(context, e.message);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _openTarget(_Group g) async {
    if (_busy) return;
    setState(() => _busy = true);
    final unreadIds = g.actors.where((n) => !n.read).map((n) => n.id).toList();
    await _markRead(unreadIds);
    try {
      final post = await _api.fetchPostDetail(g.postId ?? 0);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CloudPostDetailPage(
          post: post,
          // like_post 定位日志主体；其余定位到对应评论
          initialCommentId: widget.type == 'like_post' ? null : g.commentId,
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) showAlertToast(context, e.message);
    } catch (_) {
      if (mounted) showAlertToast(context, '日志不存在或已被删除');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload(); // 从详情返回后重拉（单条已读红点消失）
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      backgroundColor: AppColors.abyss,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.parchment),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_typeTitle,
            style: const TextStyle(color: AppColors.parchment, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _items.any((n) => !n.read) ? _markAllRead : null,
            child: Text('全部已读',
                style: TextStyle(
                    fontSize: 13,
                    color: _items.any((n) => !n.read) ? AppColors.gold : AppColors.sub)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : groups.isEmpty
              ? const Center(
                  child: Text('暂无消息，等待船员互动',
                      style: TextStyle(color: AppColors.sub, fontSize: 13)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
                  itemCount: groups.length,
                  separatorBuilder: (context, index) => const Divider(
                      height: 1, color: Color(0x1A7DC4FF)),
                  itemBuilder: (context, i) => _buildEntry(groups[i]),
                ),
    );
  }

  Widget _buildEntry(_Group g) {
    final first = g.actors.first;
    final hasUnread = g.actors.any((n) => !n.read);
    return InkWell(
      onTap: () => _openTarget(g),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
                  alignment: Alignment.center,
                  child: UserAvatar(
                    avatar: first.actorAvatar,
                    fallbackText: first.actorNickname ?? '船员',
                    size: 42,
                    fontSize: 16,
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.coral),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Builder(builder: (context) {
                          final (names, action) = _entryParts(g);
                          return Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: names,
                                  style: const TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                  text: action,
                                  style: const TextStyle(
                                      color: Color(0xFFE5EFFA), fontSize: 13),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(_timeLabel(first.createdAt),
                          style: const TextStyle(color: AppColors.sub, fontSize: 11)),
                    ],
                  ),
                  if (first.postExcerpt != null && first.postExcerpt!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(first.postExcerpt!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.sub, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Text('›', style: TextStyle(fontSize: 16, color: AppColors.sub)),
          ],
        ),
      ),
    );
  }
}

/// like 类聚合分组（ids=组内通知 id 集合，actors=组内通知按新→旧）
class _Group {
  final List<int> ids;
  final List<CloudNotification> actors;
  final int? postId;
  final int? commentId;
  _Group({required this.ids, required this.actors, this.postId, this.commentId});
}
