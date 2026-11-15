import 'package:flutter/material.dart';

import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../services/session_store.dart';
import '../theme/colors.dart';
import '../data/seed_data.dart';
import '../pages/auth_page.dart';
import '../pages/dm_conversations_page.dart';
import '../pages/group_page.dart';
import '../pages/notification_list_page.dart';

/// 闹市 Tab — 消息中心横向快捷入口（v2.9.9）+ 岛屿社群 + 同好酒馆
/// 入口栏仅登录态渲染（未登录整体隐藏）；未读角标实时同步 4 类互动通知，
/// 私信角标 = 会话列表未读总和。岛屿社群/同好酒馆原有列表逻辑零改动。
class BazaarTab extends StatefulWidget {
  const BazaarTab({super.key});

  @override
  State<BazaarTab> createState() => _BazaarTabState();
}

class _BazaarTabState extends State<BazaarTab> {
  final CloudApi _api = CloudApi.instance;
  DataStore? _boundStore;
  CloudUnreadCounts _unread = const CloudUnreadCounts();
  int _dmUnread = 0;
  List<CloudGroupEntry>? _cloudGroups; // 登录态云端群列表（含未读/最新消息）；null=未登录降级 seed

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 登录/登出（DataStore notify）→ 重新加载未读（未登录时入口栏整体隐藏）
    final store = DataStoreProvider.of(context);
    if (_boundStore != store) {
      _boundStore?.removeListener(_onStoreChanged);
      _boundStore = store;
      store.addListener(_onStoreChanged);
      _refreshUnread();
    }
  }

  @override
  void dispose() {
    _boundStore?.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    if (!SessionStore.instance.hasToken) {
      if (mounted) setState(() => _cloudGroups = null);
      return; // 未登录不发请求（群列表降级 seed 渲染）
    }
    try {
      final counts = await _api.fetchUnreadCounts();
      int dm = 0;
      try {
        final convs = await _api.fetchConversations();
        dm = convs.fold(0, (sum, c) => sum + c.unread);
      } on ApiException {
        // 私信未读失败不影响 4 类角标
      }
      List<CloudGroupEntry>? groups;
      try {
        groups = await _api.fetchGroups(); // 群列表数据源（未读角标/最新消息）
      } on ApiException {
        // 群列表拉取失败降级 seed 渲染
      }
      if (!mounted) return;
      setState(() => _unread = counts);
      setState(() => _dmUnread = dm);
      if (mounted) setState(() => _cloudGroups = groups);
    } on ApiException {
      // 未读拉取失败静默（下次 store 通知再试）
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = DataStoreProvider.of(context);

    // v2.9.10 群列表数据源：登录 → 云端（未读角标/最新消息）；未登录 → seed 降级（UI 布局不变）
    final List<CloudGroupEntry>? cloud = store.isLoggedIn ? _cloudGroups : null;
    final List<CloudGroupEntry> islandCloud =
        cloud?.where((g) => g.groupType == 'island').toList() ?? const [];
    final List<CloudGroupEntry> tavernCloud =
        cloud?.where((g) => g.groupType == 'tavern').toList() ?? const [];
    final islandGroups = islandCloud.isNotEmpty
        ? null
        : groups.where((g) => g.cat == 'island').toList();
    final tavernGroups = tavernCloud.isNotEmpty
        ? null
        : groups.where((g) => g.cat == 'club').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── v2.9.9 消息中心横向快捷入口（未登录整体隐藏，不渲染）──
          if (store.isLoggedIn) ...[
            _buildMsgCenter(),
            const SizedBox(height: 6),
          ],
          // ── v2.9.10 岛屿社群（云端群聊数据源）──
          const _SectionTitle('岛屿社群 · Island Crews'),
          if (islandGroups != null)
            ...islandGroups.map((g) => _GroupItem(
                  group: g,
                  onTap: () => _openGroupEntry(context, seed: g),
                ))
          else
            ...islandCloud.map((g) => _CloudGroupItem(
                  group: g,
                  onTap: () => _openGroupEntry(context, cloud: g),
                )),
          // ── 同好酒馆 ──
          const _SectionTitle('同好酒馆 · Taverns'),
          if (tavernGroups != null)
            ...tavernGroups.map((g) => _GroupItem(
                  group: g,
                  onTap: () => _openGroupEntry(context, seed: g),
                ))
          else
            ...tavernCloud.map((g) => _CloudGroupItem(
                  group: g,
                  onTap: () => _openGroupEntry(context, cloud: g),
                )),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '点击群名进入群聊 · 与船员们交流',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.sub,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 进群入口：登录直接进群聊（免邀请/申请/审核）；未登录唤起登录引导
  Future<void> _openGroupEntry(BuildContext context, {CloudGroupEntry? cloud, Group? seed}) async {
    final store = DataStoreProvider.of(context);
    if (!store.isLoggedIn) {
      final BuildContext navCtx = Navigator.of(context).context;
      final go = await showDialog<bool>(
        context: navCtx,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.cardSolid,
          title: const Text(
            '需要登船',
            style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '登录后即可进入群聊，与船员们交流',
            style: TextStyle(color: AppColors.sub, fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(navCtx, false),
              child: const Text('取消', style: TextStyle(color: AppColors.sub)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(navCtx, true),
              child: const Text('去登录', style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      );
      if (go == true && navCtx.mounted) {
        await Navigator.of(navCtx).push(
          MaterialPageRoute(builder: (_) => const AuthPage()),
        );
        _refreshUnread();
      }
      return;
    }
    final groupId = cloud?.groupId ?? _seedToCloudId(seed!.id);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupPage(groupId: groupId)),
    );
    _refreshUnread(); // 群聊返回 → 刷新未读角标/最新消息
  }

  /// seed 群 id（g-qingxin 等）→ 云端固定群 id（g001-g006）
  String _seedToCloudId(String seedId) {
    const map = {
      'g-qingxin': 'g001',
      'g-jieyan': 'g002',
      'g-jianshen': 'g003',
      'g-zaoshui': 'g004',
      'g-emotion': 'g005',
      'g-ai': 'g006',
    };
    return map[seedId] ?? seedId;
  }

  // ── v2.9.9 消息中心横向快捷入口栏（5 个大圆角方形卡片，一行均分）──
  Widget _buildMsgCenter() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          _entry('日志获赞', _unread.likePost, _likeHeartIcon, onTap: () => _openList('like_post')),
          const SizedBox(width: 8),
          _entry('评论获赞', _unread.likeComment, _likeCommentIcon, onTap: () => _openList('like_comment')),
          const SizedBox(width: 8),
          _entry('评论回复', _unread.reply, _replyIcon, onTap: () => _openList('reply')),
          const SizedBox(width: 8),
          _entry('被@提及', _unread.mention, _mentionIcon, onTap: () => _openList('mention')),
          const SizedBox(width: 8),
          _entry('私信', _dmUnread, _dmIcon, onTap: _openDm),
        ],
      ),
    );
  }

  void _openList(String type) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => NotificationListPage(type: type, onChanged: _refreshUnread),
        ))
        .whenComplete(_refreshUnread);
  }

  void _openDm() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DmConversationsPage(onChanged: _refreshUnread),
        ))
        .whenComplete(_refreshUnread);
  }

  /// 单个入口卡片：图标在上（右上角未读角标）、文字在下
  Widget _entry(String label, int count, Widget icon, {required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    icon,
                    if (count > 0)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 9, height: 1.3),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFE5EFFA))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 5 类图标（统一线性风格，线条粗细一致）──────────────────
  Widget _iconWrap(Widget child) => SizedBox(
        width: 30,
        height: 30,
        child: Center(child: child),
      );

  /// 日志获赞：红心（线性）
  Widget get _likeHeartIcon => _iconWrap(
        const Icon(Icons.favorite_border, size: 24, color: AppColors.coral),
      );

  /// 评论获赞：对话气泡内嵌红心（独立矢量图标，不拼接符号）
  Widget get _likeCommentIcon => _iconWrap(
        SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 24, color: Color(0xFFE5EFFA)),
              Positioned(
                top: 7,
                child: Icon(Icons.favorite,
                    size: 10, color: AppColors.coral, shadows: [
                  Shadow(
                      color: AppColors.abyss.withValues(alpha: 0.9),
                      blurRadius: 2),
                ]),
              ),
            ],
          ),
        ),
      );

  /// 评论回复：对话框（线性）
  Widget get _replyIcon => _iconWrap(
        const Icon(Icons.chat_bubble_outline, size: 24, color: Color(0xFFE5EFFA)),
      );

  /// 被@提及：@ 符号（线性文字图标）
  Widget get _mentionIcon => _iconWrap(
        const Text('@',
            style: TextStyle(
                fontSize: 20, color: Color(0xFFE5EFFA), fontWeight: FontWeight.w600)),
      );

  /// 私信：纸飞机（线性）
  Widget get _dmIcon => _iconWrap(
        const Icon(Icons.send_outlined, size: 22, color: Color(0xFFE5EFFA)),
      );
}

/// H5 .section-title — flex 居中，两侧渐变线，金色 Cinzel 字体
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(child: _gradientLine()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 12,
                letterSpacing: 3,
                color: AppColors.gold,
              ),
            ),
          ),
          Expanded(child: _gradientLine()),
        ],
      ),
    );
  }

  Widget _gradientLine() => Container(
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0x00E8B84A),
              AppColors.goldHalf,
              Color(0x00E8B84A),
            ],
            stops: [0, 0.5, 1],
          ),
        ),
      );
}

/// H5 .grp-item — flex 行，avatar + body + badge
class _GroupItem extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _GroupItem({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                // .grp-avatar 46×46 圆角12 渐变 135deg ocean→#0F6E56
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF123A6B), Color(0xFF0F6E56)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(group.avatar, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                // .grp-body flex:1
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // .grp-head space-between
                      Row(
                        children: [
                          // .grp-name 14px 500 #EAF2FF ellipsis
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFEAF2FF),
                              ),
                            ),
                          ),
                          // .grp-time 11px sub margin-left:8
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              group.time,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.sub,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // .grp-last 12px sub ellipsis
                      Text(
                        group.last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                // .grp-badge coral 圆点
                if (group.badge > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group.badge > 99 ? '99+' : '${group.badge}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// v2.9.10 云端群条目（布局与 _GroupItem 一致；数据=接口：最新消息摘要+相对时间+
/// 未读数字角标在时间右侧；memberCount 由接口动态统计）
class _CloudGroupItem extends StatelessWidget {
  final CloudGroupEntry group;
  final VoidCallback onTap;
  const _CloudGroupItem({required this.group, required this.onTap});

  String _timeLabel(int? ms) {
    if (ms == null) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${t.month}-${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                // .grp-avatar 46×46 圆角12 渐变 135deg ocean→#0F6E56
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF123A6B), Color(0xFF0F6E56)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(group.avatar, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFEAF2FF),
                              ),
                            ),
                          ),
                          // 时间（右侧接未读角标，截图样式）
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              _timeLabel(group.lastAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.sub,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        group.lastContent.isEmpty
                            ? '${group.memberCount} 名船员 · 等待第一条消息'
                            : group.lastContent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                // 未读数字角标（时间右侧）
                if (group.unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group.unread > 99 ? '99+' : '${group.unread}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
