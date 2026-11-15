import 'package:flutter/material.dart';

import '../app.dart' show appTabIndex;
import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';
import '../services/session_store.dart';
import '../services/social_state.dart';
import '../theme/colors.dart';
import '../widgets/service_dialog.dart';
import 'blacklist_page.dart';

/// 账号设置页（v2.9.6 入口收拢版；入口：船长 Tab 资料卡片【账号设置】按钮）。
///
/// 分组结构（条目样式沿用船员服务菜单原生 UI，右侧 › 箭头）：
/// 【账号ID】当前登录 uid 静态展示（v2.9.9，只读无点击）
/// 【船员服务】联系船务长 · 打卡提醒
/// 【黑名单】黑名单管理（独立路由页）
/// 【其他】隐私政策 · 下船登出（确认弹窗沿用旧版样式/文案/逻辑，不改）
class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

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
        title: const Text('账号设置',
            style: TextStyle(color: AppColors.parchment, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
        children: [
          // ── 账号ID（静态展示，无点击）──
          _accountIdItem(),
          const SizedBox(height: 20),
          // ── 船员服务 ──
          _sectionLabel('船员服务 · SERVICES'),
          _settingsItem(
            icon: '💬',
            text: '联系船务长进官方船队 · 客服与帮助',
            onTap: () => showServiceDialog(context),
          ),
          _settingsItem(
            icon: '🔔',
            text: '打卡提醒',
            onTap: () => showInfoDialog(context, '打卡提醒', '每日 21:00 推送打卡提醒'),
          ),
          const SizedBox(height: 20),
          // ── 黑名单 ──
          _sectionLabel('黑名单 · BLOCKLIST'),
          _settingsItem(
            icon: '🚫',
            text: '黑名单管理',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlacklistPage()),
            ),
          ),
          const SizedBox(height: 20),
          // ── 其他 ──
          _sectionLabel('其他 · OTHERS'),
          _settingsItem(
            icon: '🔒',
            text: '隐私政策',
            onTap: () => _showPrivacy(context),
          ),
          _settingsItem(
            icon: '🚪',
            text: '下船登出',
            danger: true,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  /// 账号ID展示条目（v2.9.9）：容器样式与 _settingsItem 同款（圆角14/渐变/细边框），
  /// 仅静态展示当前登录 uid（MeState 缓存，登出已 clear），无 onTap、无 › 箭头。
  Widget _accountIdItem() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1A7DC4FF)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99123A6B), Color(0xB30A1F3D)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const SizedBox(width: 28, child: Text('🆔', style: TextStyle(fontSize: 20))),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('账号ID',
                    style: TextStyle(fontSize: 14, color: Color(0xFFE5EFFA))),
              ),
              FutureBuilder<int>(
                future: MeState.instance.uid(),
                builder: (context, snap) => Text(
                  snap.hasData ? '${snap.data}' : '—',
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );

  /// 分组标题（金色小字，与船员服务区块标题同款）
  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.gold, fontSize: 12, letterSpacing: 2)),
      );

  /// 服务菜单同款条目（ocean→deep 渐变 + 金色图标 + › 箭头）
  Widget _settingsItem({
    required String icon,
    required String text,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final color = danger ? AppColors.coral : const Color(0xFFE5EFFA);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A7DC4FF)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99123A6B), Color(0xB30A1F3D)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text(icon, style: const TextStyle(fontSize: 20))),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: color))),
                const Text('›', style: TextStyle(fontSize: 18, color: AppColors.sub)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 隐私政策弹窗（文案沿用旧版）
  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSolid,
        title: const Text('隐私政策',
            style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
          '我们仅收集运行为您提供服务所必需的信息（账号标识、打卡记录、您主动发布的日志内容）。'
          '所有内容存储于加密服务器，绝不向第三方出售您的个人信息。'
          '\n\n完整隐私政策请访问官网页面查看。',
          style: TextStyle(color: AppColors.sub, fontSize: 13, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  /// 下船登出（确认弹窗/文案/逻辑完全沿用旧版；登出后回岛屿首页）
  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSolid,
        title: const Text(
          '确认下船？',
          style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '登出后再次点击船长Tab需要重新登录',
          style: TextStyle(color: AppColors.sub, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppColors.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认下船', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await CloudApi.instance.logout();
    } on ApiException {
      // 网络失败/后端异常也继续清本地（本地状态为准）
    }
    await SessionStore.instance.clear(); // 清 token + 签名缓存
    MeState.instance.clear(); // 清本人 uid 缓存
    FollowState.instance.clear(); // 清关注状态缓存
    if (!context.mounted) return;
    final store = DataStoreProvider.of(context);
    store.logout();
    appTabIndex.value = 0; // 回到未登录首页（岛屿）
    // 关闭账号设置页（含中间路由）
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}
