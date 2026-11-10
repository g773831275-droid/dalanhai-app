import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../data/seed_data.dart';
import '../data/data_store_provider.dart';

/// 群聊页 — 对应 H5 renderGroup
/// 接收 groupId，从种子数据中查 Group；消息列表 + 输入栏（种子 + 用户发送）
class GroupPage extends StatefulWidget {
  final String groupId;
  const GroupPage({super.key, required this.groupId});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final Group _group = groups.firstWhere((g) => g.id == widget.groupId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    DataStoreProvider.of(context).sendGroupMsg(widget.groupId, text);
    _inputCtrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = DataStoreProvider.of(context);
    final msgs = store.groupMessages(widget.groupId);
    final captainName = store.captain?.name ?? '航海家';
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: Column(
        children: [
          // 顶栏：返回 + 群名 + CREW 副标题（不用 SafeArea，手动处理状态栏 padding）
          Container(
            padding: EdgeInsets.fromLTRB(8, topPad + 6, 8, 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.gold),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEAF2FF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'CREW · ${_group.count} 名船员',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              children: [
                // .grp-chat-info 居中信息条
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '👥 ${_group.count} 名船员 · ${_group.desc}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.sub,
                    ),
                  ),
                ),
                ...msgs.map((m) => _MsgBubble(msg: m, captainName: captainName)),
              ],
            ),
          ),
          // .gc-input-bar 底部 sticky 输入栏（180deg transparent→abyss 30%）
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x0004101F), AppColors.abyss],
                stops: [0, 0.3],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    // .gc-input flex:1 圆角18 半透黑底
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x59000000), // rgba(0,0,0,.35)
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0x337DC4FF), // rgba(125,196,255,.2)
                          ),
                        ),
                        child: TextField(
                          controller: _inputCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: '说点什么...',
                            hintStyle: TextStyle(color: AppColors.placeholder),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // .gc-send 金色渐变按钮
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          gradient: AppColors.btnGoldGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          '发送',
                          style: TextStyle(
                            color: AppColors.goldBtnText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// H5 .gc-ava — 34×34 圆形金色渐变，深色加粗文字
class _Avatar extends StatelessWidget {
  final String text;
  const _Avatar({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.btnGoldGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.goldBtnText,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// H5 .gc-list 内的消息气泡 — sys / mine / other 三态
class _MsgBubble extends StatelessWidget {
  final GroupMessage msg;
  final String captainName;
  const _MsgBubble({required this.msg, required this.captainName});

  @override
  Widget build(BuildContext context) {
    if (msg.sys) {
      // .gc-sys 居中 11px sub 卡片
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                msg.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.sub,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // .gc-bubble max-width:72%
        final maxBubbleWidth = constraints.maxWidth * 0.72;

        if (msg.mine) {
          // .gc-msg.mine flex-direction:row-reverse → bubble 在左，avatar 在右
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: AppColors.mineBubbleGradient,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0x4D7DC4FF), // rgba(125,196,255,.3)
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFFEAF2FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Avatar(text: captainName.isNotEmpty ? captainName[0] : '航'),
              ],
            ),
          );
        }

        // .gc-msg 默认 avatar 在左，bubble 在右
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(text: msg.avatar ?? '船'),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.name != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          msg.name!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.cardSolid,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        msg.text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFFEAF2FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
