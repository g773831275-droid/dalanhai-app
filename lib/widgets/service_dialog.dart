import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 船员服务公共弹窗（v2.9.6 从船长页抽出，船长页/账号设置页共用）。

/// 联系船务长弹窗（金色标题 + 微信二维码 + 邮箱，视觉与 H5 原版一致）
void showServiceDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: const Color(0xBF040A14),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cardSolid, AppColors.abyss],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            ...AppColors.cardShadow,
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60, offset: const Offset(0, 20)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.goldBright, AppColors.gold],
              ).createShader(b),
              child: const Text(
                '联系船务长 · 登上官方船',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '长按识别二维码，添加船务长微信\n他会带你上对应岛屿的官方船',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // 微信二维码图片（H5 .qr-box 180x180 白底圆角）
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.all(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/wechat-qr.jpg',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(child: Icon(Icons.qr_code, size: 80, color: AppColors.abyss)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('船务长微信：abccba978', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 4),
            const Text('客服邮箱：gktvipyx@163.com', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 12),
            // 金色「我知道了」按钮
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AppColors.btnGoldGradient,
                    boxShadow: [BoxShadow(color: AppColors.copper.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  alignment: Alignment.center,
                  child: const Text('我知道了', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.goldBtnText)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 通用提示弹窗（标题 + 内容 + 金色「好的」按钮，H5 maskToast 同款）
void showInfoDialog(BuildContext context, String title, String text) {
  showDialog(
    context: context,
    barrierColor: const Color(0xBF040A14),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cardSolid, AppColors.abyss],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            ...AppColors.cardShadow,
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60, offset: const Offset(0, 20)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.goldBright, AppColors.gold],
              ).createShader(b),
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AppColors.btnGoldGradient,
                    boxShadow: [BoxShadow(color: AppColors.copper.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  alignment: Alignment.center,
                  child: const Text('好的', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.goldBtnText)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
