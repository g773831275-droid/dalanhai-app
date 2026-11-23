import 'package:flutter/material.dart';

import '../app.dart' show appTabIndex;
import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';
import '../services/session_store.dart';
import '../services/social_state.dart';
import '../theme/colors.dart';
import '../widgets/alert_toast.dart';
import '../widgets/service_dialog.dart';
import 'password_settings_page.dart';
import 'blacklist_page.dart';

/// 账号设置页（v2.9.6 入口收拢版；入口：船长 Tab 资料卡片【账号设置】按钮）。
///
/// 分组结构（条目样式沿用船员服务菜单原生 UI，右侧 › 箭头）：
/// 【我的账号】账号ID（静态展示 uid）· 密码设置（v2.9.9，跳 PasswordSettingsPage）
/// 【船员服务】联系船务长 · 打卡提醒
/// 【黑名单】黑名单管理（独立路由页）
/// 【其他】隐私政策 · 退出登录（确认弹窗沿用旧版样式/逻辑，文案 v2.9.11 改定）
///      · 注销账号（v2.9.11 新增，⚠️ 红色警示 + 双层确认弹窗，AGENTS.md §12）
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
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
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
        children: [
          // ── 我的账号（v2.9.9：账号ID + 密码设置）──
          _sectionLabel('我的账号 · MY ACCOUNT'),
          _accountIdItem(),
          _settingsItem(
            icon: '🔑',
            text: '密码设置',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PasswordSettingsPage()),
            ),
          ),
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
            text: '退出登录',
            danger: true,
            onTap: () => _confirmLogout(context),
          ),
          _settingsItem(
            icon: '⚠️',
            text: '注销账号',
            danger: true,
            onTap: _confirmCloseAccount,
          ),
        ],
      ),
    );
  }

  /// 账号ID展示条目（v2.9.9）：容器样式与 _settingsItem 同款（圆角14/渐变/细边框），
  /// 仅静态展示当前登录 uid（MeState 缓存，登出已 clear），无 onTap、无 › 箭头。
  Widget _accountIdItem() => Container(
        margin: const EdgeInsets.only(bottom: 8), // 与密码设置卡片间距（同 _settingsItem）
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.cardShadow,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x8C123A6B), Color(0xB30A1F3D)],
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
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
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
    final color = danger ? AppColors.coral : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x8C123A6B), Color(0xB30A1F3D)],
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

  /// 隐私政策弹窗（2026-11-22 按 AGENTS.md §14 数据收集清单重写——
  /// 数据流变更时先更 §14 再同步此处，防止申报与实现脱节）
  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSolid,
        title: const Text('隐私政策',
            style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            '我们仅收集运行为您提供服务所必需的信息：\n'
            '· 账号信息：登录标识（手机号/邮箱）、昵称、头像\n'
            '· 使用数据：打卡记录、您主动发布的日志与互动内容\n'
            '· 订单信息：「支持开发者」的订单号、金额与支付交易号（仅用于发货与对账）\n'
            '· 安全信息：IP 地址与异常行为记录（仅用于防刷防攻击）\n\n'
            '所有内容存储于加密服务器。信息仅用于内容审核、风控与支付发货，'
            '对应功能由第三方完成：阿里云（文件存储/内容安全审核/短信验证码）、'
            '支付宝（安卓支付）、苹果（iOS 内购）。我们绝不向第三方出售您的个人信息，'
            '也不将其用于广告营销；您的累计支持金额仅您本人可见。\n\n'
            '您可随时注销账号（数据将匿名化处理），也可使用举报与拉黑功能保护自己。',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.7),
          ),
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

  /// 退出登录（确认弹窗/文案/逻辑完全沿用旧版；登出后回岛屿首页）
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
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
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
    if (!context.mounted) return;
    await _clearLocalSession(context);
  }

  /// 清本地登录态并回岛屿首页（退出登录/注销成功共用收尾）
  Future<void> _clearLocalSession(BuildContext context) async {
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

  // ════════════════════════════════════════════════════════════
  // v2.9.11 注销账号（AGENTS.md §12）：双层确认弹窗
  // 第一层：确认注销账号？（取消 / 继续注销）
  // 第二层：手动输入当前账号ID 匹配才可执行（取消 / 确认注销）
  // 后端匿名化：昵称→【已注销用户】、头像简介清空、关注粉丝双向清空、
  // 会话全部吊销；帖子/评论/私信保留不删
  // ════════════════════════════════════════════════════════════

  Future<void> _confirmCloseAccount() async {
    final uid = await MeState.instance.uid();
    if (!mounted) return;
    final goSecond = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSolid,
        title: const Text(
          '确认注销账号？',
          style: TextStyle(color: AppColors.coral, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '注销后你的帖子、评论、个人数据会按规则清除，账号无法恢复，请谨慎操作',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续注销', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (goSecond != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _CloseAccountVerifyDialog(accountId: uid),
    );
    if (confirmed != true || !mounted) return;

    try {
      await CloudApi.instance.closeAccount();
    } on ApiException catch (e) {
      if (mounted) showAlertToast(context, e.message); // 401 已注销/403 创始人等业务文案透传
      return;
    } catch (_) {
      if (mounted) showAlertToast(context, '注销失败，请检查网络后重试');
      return;
    }
    // 后端注销成功后旧 token 已被吊销，本地清态回首页
    if (!mounted) return;
    await _clearLocalSession(context);
  }
}

/// 第二层校验弹窗：手动输入当前账号ID（如 12），匹配才可执行注销
class _CloseAccountVerifyDialog extends StatefulWidget {
  const _CloseAccountVerifyDialog({required this.accountId});

  final int accountId;

  @override
  State<_CloseAccountVerifyDialog> createState() => _CloseAccountVerifyDialogState();
}

class _CloseAccountVerifyDialogState extends State<_CloseAccountVerifyDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final input = _ctrl.text.trim();
    if (input != '${widget.accountId}') {
      showAlertToast(context, '账号ID不匹配，请输入当前登录账号的ID（${widget.accountId}）');
      return;
    }
    setState(() => _busy = true);
    // 交给外层执行注销（这里只做校验闸门）；关闭弹窗返回 true
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardSolid,
      title: const Text(
        '身份校验',
        style: TextStyle(color: AppColors.coral, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '为防止误操作，请手动输入当前账号的账号ID以确认注销',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            enabled: !_busy,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '输入账号ID，如 ${widget.accountId}',
              hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0x59000000),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x1A7DC4FF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x1A7DC4FF)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _busy ? null : _onConfirm,
          child: const Text('确认注销', style: TextStyle(color: AppColors.coral)),
        ),
      ],
    );
  }
}
