import 'package:flutter/material.dart';

/// 大蓝海配色体系 — 与 H5 :root CSS 变量一一对应
/// 设计语言：深海蓝底 + 帝国金点缀 + 羊皮纸文本
class AppColors {
  AppColors._();

  // ── 深海蓝系（背景层级）──
  static const Color abyss = Color(0xFF04101F);       // --abyss 最深底
  static const Color deep = Color(0xFF0A1F3D);         // --deep 深蓝
  static const Color ocean = Color(0xFF123A6B);        // --ocean 主蓝
  static const Color wave = Color(0xFF1E5C99);         // --wave 浪
  static const Color foam = Color(0xFFBFE3FF);         // --foam 浪花
  static const Color sky = Color(0xFF7DC4FF);          // --sky 天空

  // ── 帝国金系（强调 / 成就）──
  static const Color gold = Color(0xFFE8B84A);         // --gold 帝国金
  static const Color goldHalf = Color(0x80E8B84A);      // gold 50% 透明（渐变线用）
  static const Color goldLight = Color(0xFFF7D77A);    // --gold-2
  static const Color goldBright = Color(0xFFFFF3C4);   // 金色渐变最亮（streak-big / h1 文字渐变）
  static const Color copper = Color(0xFFB7702B);       // --copper 铜
  static const Color copperDark = Color(0xFF8A5B14);   // 金色渐变最暗（h1 文字渐变）
  static const Color coral = Color(0xFFE45B3A);        // --coral 旗帜红

  // ── 羊皮纸系（文本 / 卡片）──
  static const Color parchment = Color(0xFFF1E4C6);    // --parchment 羊皮纸
  static const Color parchmentDark = Color(0xFFE4CFA0); // --parchment-2
  static const Color parchmentDeep = Color(0xFFD9BE85); // 证书卡片渐变终止色
  static const Color ink = Color(0xFF1B1408);          // --ink 墨色
  static const Color inkLight = Color(0xFF3B2708);     // 证书卡片文字色
  static const Color inkSub = Color(0xFF6B4D18);       // 证书卡片副文字色
  static const Color certBorder = Color(0xFFB08640);   // 证书卡片边框色

  // ── 辅助色 ──
  static const Color sub = Color(0xFF8FA6C4);          // --sub 次要文本
  static const Color subDark = Color(0xFF3d5375);      // dot.off 色
  static const Color placeholder = Color(0xFF5a7099);  // input placeholder
  static const Color goldBtnText = Color(0xFF2A1A05);  // 金色按钮上的深色文字
  static const Color line = Color(0x17FFFFFF);         // --line rgba(255,255,255,.09)
  static const Color card = Color(0x0DFFFFFF);         // --card rgba(255,255,255,.05)
  static const Color cardSolid = Color(0xFF0E2547);    // --card-solid
  static const Color glass = Color(0x8C0A1F3D);        // --glass rgba(10,31,61,.55)

  // ── 背景渐变中间色 ──
  static const Color bgMid = Color(0xFF061a34);        // body linear-gradient 中间色
  static const Color bgGlow1 = Color(0xFF1a4c86);      // body radial-gradient 顶部光
  static const Color bgGlow2 = Color(0xFF0b2a52);      // body radial-gradient 底部光
  static const Color heroStart = Color(0xFF0B2A55);    // 航海报/详情页渐变起始色
  static const Color detailStart = Color(0xFF0d3163);  // 详情页/船长页渐变起始色

  // ── 渐变 ──
  // body 背景：线性渐变 abyss → bgMid → abyss
  static const LinearGradient bodyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [abyss, bgMid, abyss],
  );

  // 航海报渐变：160deg heroStart → deep → abyss
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment(-0.5, -0.5),
    end: Alignment(0.5, 0.5),
    colors: [heroStart, deep, abyss],
  );

  // 详情页/船长页渐变：180deg detailStart → abyss
  static const LinearGradient detailGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [detailStart, abyss],
  );

  // 岛屿卡片渐变：160deg ocean(.75) → deep(.85)
  static const LinearGradient islandCardGradient = LinearGradient(
    begin: Alignment(-0.5, -0.5),
    end: Alignment(0.5, 0.5),
    colors: [Color(0xBF123A6B), Color(0xD90A1F3D)],
  );

  // 金色文字渐变（streak-big）：180deg goldBright → gold → copper
  static const LinearGradient goldTextGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldBright, gold, copper],
  );

  // 标题金色渐变（h1/topbar）：180deg goldBright → gold → copperDark
  static const LinearGradient titleGoldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldBright, gold, copperDark],
  );

  // 按钮金色渐变：180deg goldLight → copper
  static const LinearGradient btnGoldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, copper],
  );

  // 连续天数胶囊渐变：180deg goldLight → copper
  static const LinearGradient streakPillGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, copper],
  );

  // 21天格子 done 渐变：180deg goldLight → gold
  static const LinearGradient gridDoneGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, gold],
  );

  // 证书卡片渐变：160deg parchment → parchmentDeep
  static const LinearGradient certGradient = LinearGradient(
    begin: Alignment(-0.5, -0.5),
    end: Alignment(0.5, 0.5),
    colors: [parchment, parchmentDeep],
  );

  // 底栏背景渐变：上 70% 半透明 → 下完全铺满深蓝（避免 home indicator 区域露出底层黑色）
  static const LinearGradient tabbarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xCC04101F), Color(0xFF04101F)],
  );

  // 海洋按钮渐变：180deg wave → ocean
  static const LinearGradient btnOceanGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2c74c2), ocean],
  );

  // 我的消息气泡渐变：135deg ocean → wave
  static const LinearGradient mineBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ocean, wave],
  );

  // ── 语义色 ──
  static const Color success = Color(0xFF3DAE5A);
  static const Color danger = coral;
  static const Color warning = gold;

  // ── 旧名称兼容（重写各文件时逐步替换为新名称）──
  static const LinearGradient seaGradient = bodyGradient;
  static const LinearGradient goldGradient = streakPillGradient;
}
