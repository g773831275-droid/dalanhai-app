import 'dart:async';

import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../theme/colors.dart';
import '../widgets/user_avatar.dart';

/// 私信会话页（v2.9.9）：消息气泡（我=右金色，对方=左深蓝）+ 底部输入条。
/// 打开即拉全量（后端同时置对方消息已读）；页内 10s 轮询 + 发送后重拉（无 WebSocket）。
class DmChatPage extends StatefulWidget {
  const DmChatPage({super.key, required this.peerId, required this.peerNickname});

  final int peerId;
  final String peerNickname;

  @override
  State<DmChatPage> createState() => _DmChatPageState();
}

class _DmChatPageState extends State<DmChatPage> {
  final CloudApi _api = CloudApi.instance;
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<CloudDmMessage> _msgs = [];
  String? _peerAvatar;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _reload();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _reload(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await _api.fetchDmMessages(widget.peerId);
      if (!mounted) return;
      setState(() {
        _msgs = msgs;
        _loading = false;
      });
      // 新消息到达 → 滚到底
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients && _msgs.isNotEmpty) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await _api.sendDm(toUid: widget.peerId, content: text);
      await _reload(silent: true);
    } on ApiException catch (e) {
      if (mounted) {
        _ctrl.text = text; // 失败回填
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message, style: const TextStyle(color: Colors.white, fontSize: 13)),
          backgroundColor: AppColors.coral,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) _ctrl.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
        title: Text(widget.peerNickname,
            style: const TextStyle(color: AppColors.parchment, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Column(
              children: [
                Expanded(
                  child: _msgs.isEmpty
                      ? const Center(
                          child: Text('暂无消息，等待船员互动',
                              style: TextStyle(color: AppColors.sub, fontSize: 13)))
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          itemCount: _msgs.length,
                          itemBuilder: (context, i) => _buildBubble(_msgs[i]),
                        ),
                ),
                // 输入条
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: const BoxDecoration(color: Color(0xB30A1F3D)),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            maxLines: null,
                            style: const TextStyle(color: Color(0xFFE5EFFA), fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '发消息…',
                              hintStyle: const TextStyle(color: AppColors.sub, fontSize: 13),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0x99123A6B),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Color(0x1A7DC4FF)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Color(0x1A7DC4FF)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _sending ? null : _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: const Color(0xFF0A1F3D),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('发送', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBubble(CloudDmMessage m) {
    final isMine = m.mine;
    final time = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: UserAvatar(
                  avatar: _peerAvatar, fallbackText: widget.peerNickname, size: 28, fontSize: 12),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: const BoxConstraints(maxWidth: 260),
                  decoration: BoxDecoration(
                    color: isMine ? const Color(0x998A6A1F) : const Color(0x99123A6B),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isMine ? 12 : 2),
                      bottomRight: Radius.circular(isMine ? 2 : 12),
                    ),
                    border: Border.all(color: const Color(0x1A7DC4FF)),
                  ),
                  child: Text(m.content,
                      style: const TextStyle(color: Color(0xFFE5EFFA), fontSize: 14, height: 1.4)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('$hh:$mm',
                      style: const TextStyle(color: AppColors.sub, fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
