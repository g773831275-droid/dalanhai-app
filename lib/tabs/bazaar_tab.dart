import 'package:flutter/material.dart';

import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../services/session_store.dart';
import '../theme/colors.dart';
import '../data/seed_data.dart';
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
    if (!SessionStore.instance.hasToken) return; // 未登录不发请求
    try {
      final counts = await _api.fetchUnreadCounts();
      int dm = 0;
      try {
        final convs = await _api.fetchConversations();
        dm = convs.fold(0, (sum, c) => sum + c.unread);
      } on ApiException {
        // 私信未读失败不影响 4 类角标
      }
      if (!mounted) return;
      setState(() => _unread = counts);
      setState(() => _dmUnread = dm);
    } on ApiException {
      // 未读拉取失败静默（下次 store 通知再试）
    }
  }

  @override
  Widget build(BuildContext context) {
    final islandGroups = groups.where((g) => g.cat == 'island').toList();
    final clubGroups = groups.where((g) => g.cat == 'club').toList();
    final store = DataStoreProvider.of(context);

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
          const _SectionTitle('岛屿社群 · Island Crews'),
          ...islandGroups.map((g) => _GroupItem(group: g, onTap: () => _openGroup(context, g))),
          const _SectionTitle('同好酒馆 · Taverns'),
          ...clubGroups.map((g) => _GroupItem(group: g, onTap: () => _openGroup(context, g))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '点击群名进入社群 · 与船员们交流',
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

  void _openGroup(BuildContext context, Group g) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupPage(groupId: g.id)));
  }
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
