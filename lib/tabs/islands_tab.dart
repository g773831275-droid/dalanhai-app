import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../data/models.dart';
import '../data/data_store_provider.dart';
import '../pages/island_detail_page.dart';

/// 岛屿 Tab — 航海报 + 四岛卡片
/// 1:1 复刻 H5 renderIslands()
class IslandsTab extends StatelessWidget {
  const IslandsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = DataStoreProvider.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _VoyageHero(
          totalConquered: store.totalCheckins,
          maxStreak: store.maxStreak,
        )),
        SliverToBoxAdapter(child: _SectionTitle('你的岛屿 · Your Islands')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          sliver: SliverList.separated(
            itemCount: Island.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final island = Island.all[i];
              final s = store.streakOf(island.id);
              final done = store.isCheckedToday(island.id);
              final total = store.totalDaysOf(island.id);
              final certified = store.hasCert(island.id);

              return _IslandCard(
                island: island,
                streak: s,
                totalDays: total,
                doneToday: done,
                certified: certified,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IslandDetailPage(island: island),
                  ),
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: _CreateCard(
          onTap: () => _showToast(context, '开辟新航线', '自定义岛屿功能即将上线，关注后续版本'),
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _showToast(BuildContext context, String title, String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSolid,
        title: Text(title, style: const TextStyle(color: AppColors.goldBright, fontSize: 18, fontWeight: FontWeight.w800)),
        content: Text(text, style: const TextStyle(color: AppColors.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}

// ── 航海报 — 对应 H5 .voyage-hero ──
class _VoyageHero extends StatelessWidget {
  final int totalConquered;
  final int maxStreak;

  const _VoyageHero({required this.totalConquered, required this.maxStreak});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // 1. 主体：双层渐变背景（径向+线性）+ 边框 + 阴影
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment(-0.5, -0.5),
                    end: Alignment(0.5, 0.5),
                    colors: [AppColors.heroStart, AppColors.deep, AppColors.abyss],
                    stops: [0.0, 0.6, 1.0],
                  ),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
            // 2. 径向金色光晕叠层（顶部中心 → 透明 55%）
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.2),
                    radius: 0.9,
                    colors: [
                      AppColors.gold.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
            // 3. 内容（eyebrow + title + desc 左对齐）— non-positioned 决定 Stack 尺寸
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHAPTER · ${DateTime.now().year}',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 11,
                      letterSpacing: 3,
                      color: AppColors.gold.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 标题渐变文字 #fff → #BFE3FF
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, AppColors.foam],
                    ).createShader(b),
                    child: const Text(
                      '今日出海',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已征服 $totalConquered 次 · 最长连续 $maxStreak 天',
                    style: const TextStyle(fontSize: 12, color: AppColors.sub),
                  ),
                ],
              ),
            ),
            // 4. 帆船 emoji 右上角（H5 right:14px top:14px，相对 banner 容器）
            // 必须放在外层 Stack 才能相对整个 banner（不是 Padding 内容）
            Positioned(
              right: 14,
              top: 14,
              child: const Text(
                '⛵',
                style: TextStyle(
                  fontSize: 44,
                  height: 1,
                  shadows: [
                    Shadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
              ),
            ),
            // 5. 底部波浪 SVG（只在底部 44px 范围内，半透明融入 banner）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 44,
              child: CustomPaint(
                painter: _WavePainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部波浪 — 对应 H5 .waves SVG
/// 两条波浪 path，不同透明度
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 第一条波：opacity .25
    final paint1 = Paint()..color = AppColors.sky.withValues(alpha: 0.25);
    final path1 = Path();
    path1.moveTo(0, 20);
    // M0 20 Q 50 0 100 20 T 200 20 T 300 20 T 400 20 V44 H0 Z
    final w = size.width;
    final seg = w / 4;
    path1.quadraticBezierTo(seg * 0.5, 0, seg, 20);
    for (int i = 1; i < 4; i++) {
      path1.quadraticBezierTo(seg * (i + 0.5), 40, seg * (i + 1), 20);
    }
    path1.lineTo(w, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // 第二条波：opacity .4
    final paint2 = Paint()..color = AppColors.sky.withValues(alpha: 0.4);
    final path2 = Path();
    path2.moveTo(0, 28);
    path2.quadraticBezierTo(seg * 0.5, 12, seg, 28);
    for (int i = 1; i < 4; i++) {
      path2.quadraticBezierTo(seg * (i + 0.5), 44, seg * (i + 1), 28);
    }
    path2.lineTo(w, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 段落标题 — 对应 H5 .section-title ──
// 前后渐变线 + Cinzel 金色文字
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          Expanded(child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppColors.goldHalf],
              ),
            ),
          )),
          const SizedBox(width: 10),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 12,
              letterSpacing: 3,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.goldHalf, Colors.transparent],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ── 岛屿卡片 — 对应 H5 .island-card ──
class _IslandCard extends StatelessWidget {
  final Island island;
  final int streak;
  final int totalDays;
  final bool doneToday;
  final bool certified;
  final VoidCallback onTap;

  const _IslandCard({
    required this.island,
    required this.streak,
    required this.totalDays,
    required this.doneToday,
    required this.certified,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AppColors.islandCardGradient,
          border: Border.all(color: AppColors.sky.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 金色径向光晕（::before）
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: RadialGradient(
                      center: const Alignment(1, -1),
                      radius: 0.8,
                      colors: [
                        AppColors.gold.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 内容
            Row(
              children: [
                // 岛屿图标
                _IslandIcon(emoji: island.emoji, bgFrom: island.bgFrom, bgTo: island.bgTo),
                const SizedBox(width: 14),
                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(island.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF4FAFF), letterSpacing: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            island.en,
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              fontSize: 10,
                              color: Color(island.color),
                              letterSpacing: 2,
                            ),
                          ),
                          if (certified) ...[
                            const SizedBox(width: 4),
                            const Text('🏴‍☠️', style: TextStyle(fontSize: 12)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '"${island.slogan}"',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.foam.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // dot
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: doneToday ? AppColors.gold : AppColors.subDark,
                              boxShadow: doneToday
                                  ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.8), blurRadius: 8)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            doneToday ? '今日已打卡 · 累计 $totalDays 天' : '今日未打卡',
                            style: const TextStyle(fontSize: 11, color: AppColors.sub),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 连续天数金色胶囊
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: AppColors.streakPillGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.copper.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$streak',
                        style: const TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.goldBtnText,
                        ),
                      ),
                      const Text(
                        'D',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.goldBtnText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 岛屿图标 — 对应 H5 .island-icon
/// 渐变背景方块 + emoji + 金色 blur 光晕（::after）
class _IslandIcon extends StatelessWidget {
  final String emoji;
  final int bgFrom;
  final int bgTo;

  const _IslandIcon({required this.emoji, required this.bgFrom, required this.bgTo});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 金色 blur 光晕（::after）
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gold.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // 图标本体
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(bgFrom), Color(bgTo)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ],
    );
  }
}

// ── 创建卡片 — 对应 H5 .create-card ──
class _CreateCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5, style: BorderStyle.solid),
        ),
        alignment: Alignment.center,
        child: const Text(
          '＋ 开辟新航线（申请岛主）',
          style: TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 13,
            color: AppColors.gold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
