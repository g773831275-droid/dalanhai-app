import 'dart:async';

import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../services/social_state.dart';
import '../pages/user_profile_page.dart';
import '../theme/colors.dart';
import '../widgets/alert_toast.dart';
import '../widgets/user_avatar.dart';

/// 群聊页 — 对应 H5 renderGroup（v2.9.10 后端接入第一版）
/// 数据源：GET /api/group/:groupId/info + /msg（分页历史）+ POST /msg（发送，风控审核）
/// 已读：进群/收到新消息自动 markGroupRead；未读角标由闹市列表动态刷新
/// 交互：乐观发送（本地即时渲染气泡，回执成功才算发送完成，失败 toast 回填）；
/// 上拉加载更早历史消息；空输入发送置灰；气泡/输入框布局沿用现有 UI
class GroupPage extends StatefulWidget {
  final String groupId; // 云端固定群 id（g001-g006）
  const GroupPage({super.key, required this.groupId});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> with WidgetsBindingObserver {
  final CloudApi _api = CloudApi.instance;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<CloudGroupMessage> _msgs = [];
  CloudGroupInfo? _info;
  int _myUid = 0;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _reachedEnd = false;
  bool _sending = false;
  bool _canSend = false;
  int _pollSeq = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _scrollCtrl.addListener(_onScroll);
    _startPoll();
  }

  // v2.9.12：轮询生命周期感知 —— App 退后台暂停定时器，回前台恢复
  void _startPoll() {
    _poll ??= Timer.periodic(const Duration(seconds: 10), (_) => _pollNew());
  }

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) _pollNew();
      _startPoll();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _stopPoll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _myUid = await MeState.instance.uid();
    } on ApiException {
      _myUid = 0;
    }
    try {
      final info = await _api.fetchGroupInfo(widget.groupId);
      final msgs = await _api.fetchGroupMessages(widget.groupId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _msgs
          ..clear()
          ..addAll(msgs);
        _loading = false;
        _reachedEnd = msgs.length < 20;
      });
      _markRead();
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAlertToast(context, e.message);
    }
  }

  /// 进群/收到新消息 → 标记已读（未读角标由闹市返回时刷新）
  Future<void> _markRead() async {
    if (_msgs.isEmpty) return;
    try {
      await _api.markGroupRead(widget.groupId, _msgs.last.msgId);
    } on ApiException {
      // 已读失败静默
    }
  }

  void _onScroll() {
    if (_scrollCtrl.hasClients &&
        _scrollCtrl.position.pixels < 60 &&
        !_loadingOlder &&
        !_reachedEnd &&
        _msgs.isNotEmpty) {
      _loadOlder();
    }
  }

  /// 上拉（滚动到顶）加载更早历史消息；保持视口位置不跳
  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    final before = _msgs.first.msgId;
    try {
      final older = await _api.fetchGroupMessages(widget.groupId, lastMsgId: before);
      if (!mounted) return;
      setState(() {
        _msgs.insertAll(0, older);
        _reachedEnd = older.length < 20;
      });
      // 保持当前阅读位置：加载后向下补偿新增行高
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo((_scrollCtrl.position.maxScrollExtent - _scrollCtrl.position.pixels) < 0
              ? 0
              : _scrollCtrl.position.maxScrollExtent - _scrollCtrl.position.pixels + 80);
        }
      });
    } on ApiException {
      // 静默（可再次触发）
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  /// 10s 轮询：拉最新 20 条合并尾部新消息（无 WebSocket，第一版轮询）
  Future<void> _pollNew() async {
    _pollSeq++;
    final seq = _pollSeq;
    try {
      final latest = await _api.fetchGroupMessages(widget.groupId);
      if (!mounted || seq != _pollSeq) return;
      final known = _msgs.map((m) => m.msgId).toSet();
      final fresh = latest.where((m) => !known.contains(m.msgId)).toList();
      if (fresh.isNotEmpty) {
        setState(() => _msgs.addAll(fresh));
        _scrollToBottom();
        _markRead(); // 页面在前台打开即已读
      }
    } on ApiException {
      // 静默
    }
  }

  /// 乐观发送：本地即时渲染 → 回执成功替换临时条目并标记已读；失败 toast 回填
  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final temp = CloudGroupMessage(
      msgId: tempId,
      groupId: widget.groupId,
      senderUid: _myUid,
      senderName: '我',
      content: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _msgs.add(temp));
    _scrollToBottom();
    try {
      final sent = await _api.sendGroupMessage(widget.groupId, text);
      if (!mounted) return;
      final idx = _msgs.indexWhere((m) => m.msgId == tempId);
      if (idx >= 0) {
        setState(() => _msgs[idx] = sent); // 回执替换临时气泡
      }
      _markRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _msgs.removeWhere((m) => m.msgId == tempId));
      _inputCtrl.text = text; // 失败回填输入框
      showAlertToast(context, e.message); // 风控拦截等
    } catch (_) {
      if (!mounted) return;
      setState(() => _msgs.removeWhere((m) => m.msgId == tempId));
      _inputCtrl.text = text;
      showAlertToast(context, '发送失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _info?.groupName ?? '';
    final memberCount = _info?.memberCount ?? 0;
    final tags = _info?.tags ?? '';
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: Column(
        children: [
          // 顶栏：返回 + 群名 + 船员总数副标题（不用 SafeArea，手动处理状态栏 padding）
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'CREW · $memberCount 名船员',
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
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : ListView(
                    controller: _scrollCtrl,
                    reverse: false,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    children: [
                      // 顶部加载中指示（上拉历史）
                      if (_loadingOlder)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: AppColors.gold, strokeWidth: 2))),
                        ),
                      // .grp-chat-info 居中信息条（船员总数 + 标签）
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorder),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Text(
                          tags.isNotEmpty ? '👥 $memberCount 名船员 · $tags' : '👥 $memberCount 名船员',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      if (_msgs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text('还没有消息，来说第一句吧',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                          ),
                        ),
                      ..._msgs.map((m) => _MsgBubble(
                            msg: m,
                            mine: m.senderUid == _myUid,
                          )),
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
                          border: Border.all(color: AppColors.cardBorder),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: TextField(
                          controller: _inputCtrl,
                          onChanged: (t) => setState(() => _canSend = t.trim().isNotEmpty),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: '说点什么...',
                            hintStyle: TextStyle(color: AppColors.textHint),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // .gc-send 金色渐变按钮（空内容置灰不可点击）
                    GestureDetector(
                      onTap: (_canSend && !_sending) ? _send : null,
                      child: Opacity(
                        opacity: (_canSend && !_sending) ? 1.0 : 0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: AppColors.btnGoldGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _sending ? '发送中' : '发送',
                            style: const TextStyle(
                              color: AppColors.goldBtnText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
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

/// H5 .gc-ava — 34×34 圆形金色渐变，深色加粗文字（云端头像缺失时首字兜底）
/// 点击 → 发送者船长主页（自己头像=访客视角公开预览，与 @跳转规则一致）
class _Avatar extends StatelessWidget {
  final String? avatar;
  final String name;
  final int uid;
  final bool closed; // v2.9.11：已注销成员（点击无响应）
  const _Avatar({this.avatar, required this.name, required this.uid, this.closed = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // v2.9.11 账号注销：已注销成员点击无响应
        if (closed) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
        );
      },
      child: UserAvatar(
        avatar: avatar,
        fallbackText: name,
        size: 34,
        fontSize: 14,
      ),
    );
  }
}

/// H5 .gc-list 内的消息气泡 — mine / other 两态（布局沿用现有 UI）
class _MsgBubble extends StatelessWidget {
  final CloudGroupMessage msg;
  final bool mine;
  const _MsgBubble({required this.msg, required this.mine});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // .gc-bubble max-width:72%
        final maxBubbleWidth = constraints.maxWidth * 0.72;

        if (mine) {
          // .gc-msg.mine bubble 在左，avatar 在右
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
                      gradient: AppColors.btnGoldGradient, // 己方气泡金色（既定规范）
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0x40FFFFFF), // rgba(255,255,255,.25)
                      ),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Text(
                      msg.content,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.goldBtnText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Avatar(avatar: msg.senderAvatar, name: msg.senderName, uid: msg.senderUid, closed: msg.senderClosed),
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
              _Avatar(avatar: msg.senderAvatar, name: msg.senderName, uid: msg.senderUid, closed: msg.senderClosed),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        msg.senderName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.parchment, // 对方气泡浅米色（既定规范）
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Text(
                        msg.content,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.ink,
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
