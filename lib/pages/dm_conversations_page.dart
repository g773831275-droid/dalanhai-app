import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../theme/colors.dart';
import '../widgets/alert_toast.dart';
import '../widgets/user_avatar.dart';
import 'dm_chat_page.dart';

/// 私信会话列表页（v2.9.9 消息中心-私信入口）
/// 会话条目：对方头像 + 昵称 + 最后一条消息 + 时间 + 未读角标
class DmConversationsPage extends StatefulWidget {
  const DmConversationsPage({super.key, this.onChanged});

  /// 未读变化回调（闹市入口栏角标同步）
  final VoidCallback? onChanged;

  @override
  State<DmConversationsPage> createState() => _DmConversationsPageState();
}

class _DmConversationsPageState extends State<DmConversationsPage> {
  final CloudApi _api = CloudApi.instance;
  List<CloudConversation> _list = [];
  bool _loading = true;
  int _totalUnread = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final list = await _api.fetchConversations();
      if (!mounted) return;
      setState(() {
        _list = list;
        _totalUnread = list.fold(0, (sum, c) => sum + c.unread);
        _loading = false;
      });
      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAlertToast(context, e.message);
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

  Future<void> _openChat(CloudConversation c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DmChatPage(peerId: c.peerId, peerNickname: c.peerNickname ?? '船员'),
    ));
    _reload(); // 回来刷新未读/最后一条
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.parchment),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('私信${_totalUnread > 0 ? ' · $_totalUnread 未读' : ''}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _list.isEmpty
              ? const Center(
                  child: Text('暂无消息，等待船员互动',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 13)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
                  itemCount: _list.length,
                  separatorBuilder: (context, index) => const Divider(
                      height: 1, color: Color(0x1A7DC4FF)),
                  itemBuilder: (context, i) => _buildEntry(_list[i]),
                ),
    );
  }

  Widget _buildEntry(CloudConversation c) {
    final name = c.peerNickname ?? '船员${c.peerId}';
    return InkWell(
      onTap: () => _openChat(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            UserAvatar(avatar: c.peerAvatar, fallbackText: name, size: 42, fontSize: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(c.lastContent.isEmpty ? '（无消息）' : c.lastContent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_timeLabel(c.lastAt),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                const SizedBox(height: 4),
                if (c.unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.coral, borderRadius: BorderRadius.circular(9)),
                    child: Text('${c.unread}',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
