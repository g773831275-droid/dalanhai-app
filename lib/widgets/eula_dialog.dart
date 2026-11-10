import 'package:flutter/material.dart';
import '../app.dart' show appNavigatorKey;
import '../theme/colors.dart';

/// EULA 用户协议弹窗 — 1:1 还原 H5 #maskEULA
/// App Store 1.2 UGC 要求：发帖前需同意用户协议
///
/// 视觉结构（与 H5/线上版本一致，勿改文案与布局）：
///   金色居中标题「大蓝海 航海守则」
///   → 深色内嵌圆角块（rgba(0,0,0,.25)，max-height 46vh 可滚动）
///     内含欢迎语 + 5 条守则（条目名粗体）
///   → 金色渐变「同意并继续」大按钮
///   → 「不同意」ghost 文字按钮
class EulaDialog extends StatelessWidget {
  const EulaDialog({super.key});

  /// 弹出协议弹窗，返回是否同意。
  /// ⚠️ context 修复：调用方（根组件 _onCompose）的 context 位于
  /// MaterialApp 外层，showDialog 依赖的 Navigator/MaterialLocalizations
  /// 找不到 → 统一改用全局 navigatorKey 的 context（MaterialApp 内部）。
  /// 未挂载（极端时序）时安全返回 false，不崩溃不卡死。
  static Future<bool> show(BuildContext context) async {
    final BuildContext navCtx = appNavigatorKey.currentContext ?? context;
    if (navCtx == context && !context.mounted) return false;
    final result = await showDialog<bool>(
      context: navCtx,
      barrierDismissible: false,
      builder: (_) => const EulaDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cardSolid, AppColors.abyss],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题：大蓝海 航海守则（金色居中）
            const Text(
              '大蓝海 航海守则',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            // 守则内容块（rgba(0,0,0,.25) 圆角内嵌，46vh 内滚动）
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.46,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text.rich(
                    _eulaSpan,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.sub,
                      height: 1.8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // 同意并继续（金色渐变大按钮）
            GestureDetector(
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AppColors.btnGoldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.copper.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  '同意并继续',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppColors.goldBtnText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 不同意（ghost 文字按钮）
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                '不同意',
                style: TextStyle(color: AppColors.sub, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 守则全文（与 H5 #maskEULA 文案逐字一致，勿改动）
const TextSpan _eulaSpan = TextSpan(
  children: [
    TextSpan(text: '欢迎使用大蓝海。使用港口、发帖、评论等功能即表示你同意以下守则：'),
    TextSpan(text: '\n\n'),
    TextSpan(
      text: '1. 内容规范',
      style: TextStyle(color: AppColors.foam, fontWeight: FontWeight.w700),
    ),
    TextSpan(text: '：本应用对色情、暴力、歧视、骚扰及违法内容持零容忍态度。严禁发布此类信息及他人隐私。'),
    TextSpan(text: '\n\n'),
    TextSpan(
      text: '2. 用户行为',
      style: TextStyle(color: AppColors.foam, fontWeight: FontWeight.w700),
    ),
    TextSpan(text: '：尊重其他船员，禁止辱骂、人身攻击、刷屏骚扰。'),
    TextSpan(text: '\n\n'),
    TextSpan(
      text: '3. 内容管理与过滤',
      style: TextStyle(color: AppColors.foam, fontWeight: FontWeight.w700),
    ),
    TextSpan(text: '：为了维护社区环境，本 App 采用自动过滤技术与人工巡查相结合的方式对内容进行管理。'),
    TextSpan(text: '\n\n'),
    TextSpan(
      text: '4. 举报与拉黑',
      style: TextStyle(color: AppColors.foam, fontWeight: FontWeight.w700),
    ),
    TextSpan(text: '：遇到不良内容或用户，请使用举报或拉黑功能。我们承诺在 24 小时内响应举报，核实后移除违规内容并封禁违规账号。'),
    TextSpan(text: '\n\n'),
    TextSpan(
      text: '5. 违规处理',
      style: TextStyle(color: AppColors.foam, fontWeight: FontWeight.w700),
    ),
    TextSpan(text: '：违规用户将被立即拉黑、内容移除，严重者永久封禁。'),
  ],
);
