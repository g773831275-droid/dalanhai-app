import 'package:flutter/material.dart';
import 'colors.dart';

/// 大蓝海字体体系
///
/// - Cinzel：拉丁装饰字体（标题 / 数字 / "GRAND BLUE" 等品牌元素），打包在 assets/fonts/
/// - 中文：使用系统字体（iOS=PingFang SC / Android=Noto Sans CJK SC），不打包以控制体积
///
/// Flutter 对 fontFamily 未覆盖的字符自动降级到系统字体，
/// 所以 Cinzel TextStyle 混排中英文时会自动用系统字体渲染中文。
class AppTypography {
  AppTypography._();

  static const String cinzel = 'Cinzel';

  // ── Cinzel 系（标题 / 数字 / 品牌）──
  static const TextStyle brand = TextStyle(
    fontFamily: cinzel,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 3,
    color: AppColors.goldLight,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: cinzel,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.parchment,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: cinzel,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: AppColors.parchment,
  );

  static const TextStyle statNumber = TextStyle(
    fontFamily: cinzel,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
  );

  // ── 中文标题（Noto Serif SC 风格 → 系统衬线 / 半粗体）──
  static const TextStyle titleZh = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.parchment,
    letterSpacing: 0.5,
  );

  // ── 正文 ──
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.6,
    color: AppColors.parchment,
  );

  static const TextStyle bodySub = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: AppColors.sub,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.sub,
    letterSpacing: 0.3,
  );

  // ── 按钮 ──
  static const TextStyle btnPrimary = TextStyle(
    fontFamily: cinzel,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.abyss,
  );

  static const TextStyle btnGhost = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.gold,
  );

  // ── 金色强调 ──
  static const TextStyle goldLabel = TextStyle(
    fontFamily: cinzel,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    color: AppColors.gold,
  );
}
