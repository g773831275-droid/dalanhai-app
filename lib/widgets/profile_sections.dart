import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../pages/supporter_letter_page.dart';
import '../services/cloud_models.dart';
import '../theme/colors.dart';

/// 个人主页公共区块（v2.9.6）—— 他人主页与船长页共用，
/// 保证「数据统计栏 / 征服证书专区 / 区块标题」样式绝对一致。
///
/// 统计栏（需求二.3/三.2，两行排版）：
///   航海日志：N｜关注：N｜粉丝：N
///   累计打卡：N｜最长连续登岛：N
/// 关注/粉丝数字可点击弹出对应列表（其余仅展示）。

/// 区块标题（金色文字 + 两侧渐变线）
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Expanded(child: _GradientLine()),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, letterSpacing: 3, color: AppColors.gold, fontFamily: 'Cinzel')),
          const SizedBox(width: 10),
          Expanded(child: _GradientLine()),
        ],
      ),
    );
  }
}

class _GradientLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, AppColors.goldHalf, Colors.transparent],
        ),
      ),
    );
  }
}

/// 数据统计栏（两行五项；关注/粉丝数字可点弹底部列表）
class ProfileStatsGrid extends StatelessWidget {
  const ProfileStatsGrid({
    super.key,
    required this.stats,
    this.onFollowingTap,
    this.onFollowersTap,
  });

  final CloudProfileStats stats;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x40000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _stat('${s.posts}', '航海日志')),
            Expanded(child: _stat('${s.following}', '关注', onTap: onFollowingTap)),
            Expanded(child: _stat('${s.followers}', '粉丝', onTap: onFollowersTap)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _stat('${s.totalCheckins}', '累计打卡')),
            Expanded(child: _stat('${s.maxStreak}', '最长连续登岛')),
            const Expanded(child: SizedBox.shrink()),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String n, String l, {VoidCallback? onTap}) {
    final content = Column(
      children: [
        Text(n,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: AppColors.gold, fontFamily: 'Cinzel')),
        const SizedBox(height: 2),
        Text(l,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, letterSpacing: 1)),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

/// 征服证书专区（横向滚动卡片；无证书海盗旗占位 —— 复用现有文案）
class ProfileCertGallery extends StatelessWidget {
  const ProfileCertGallery({
    super.key,
    required this.certificates,
    this.badge,
    this.badgeIsSelf = true,
  });

  final List<CloudCertificate> certificates;

  /// 大蓝海支持者徽章（has==true 时在证书画廊展示徽章卡片；纯纪念装饰无特权）
  final CloudSupporterBadge? badge;

  /// 徽章视图归属：true=自己（详情页显示累计支持）/ false=他人（隐藏累计金额，隐私保护）
  final bool badgeIsSelf;

  @override
  Widget build(BuildContext context) {
    final hasBadge = badge != null && badge!.has;
    if (certificates.isEmpty && !hasBadge) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: const Center(
          child: Column(
            children: [
              Text('🏴‍☠️', style: TextStyle(fontSize: 36)),
              SizedBox(height: 6),
              Text('连续21天登岛即可获得证书',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // 徽章卡固定排在证书卡最前（支付纪念，优先展示）
        itemCount: certificates.length + (hasBadge ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (hasBadge && i == 0) return _SupporterBadgeCard(badge: badge!, isSelf: badgeIsSelf);
          final certIndex = hasBadge ? i - 1 : i;
          return _CertCard(cert: certificates[certIndex]);
        },
      ),
    );
  }
}

/// 大蓝海支持者徽章卡片 —— 与 21 天登岛证书视觉统一（同尺寸羊皮纸卡 + 虚线内框），
/// 船舵线条元素 + 暗金质感；点击跳转感谢信页。纯纪念装饰，无任何特权（§13.12 术语规范）。
class _SupporterBadgeCard extends StatelessWidget {
  const _SupporterBadgeCard({required this.badge, required this.isSelf});

  final CloudSupporterBadge badge;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SupporterLetterPage(badge: badge, isSelf: isSelf)),
      ),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.certBorder),
          gradient: const LinearGradient(
            begin: Alignment(-0.5, -0.5),
            end: Alignment(0.5, 0.5),
            colors: [AppColors.parchment, AppColors.parchmentDeep],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _DashedBorderPainter())),
              // 背景船舵线条（暗金半透明，右下角装饰）
              const Positioned(
                right: 6,
                bottom: 2,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size(52, 52),
                    painter: _ShipWheelPainter(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚓ 大蓝海支持者',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800,
                            color: Color(0xFF6B4A12), letterSpacing: 1,
                            fontFamily: 'Cinzel')),
                    const SizedBox(height: 4),
                    Text('支持开发者纪念 · ${badge.awardedAt}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xCC3B2708))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 船舵线条（简约轮辐：外圈 + 内圈 + 8 辐条 + 中心舵钮），暗金半透明
class _ShipWheelPainter extends CustomPainter {
  const _ShipWheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x4DB08640) // certBorder 暗金 @30%
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final c = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2 - 2;
    final rInner = rOuter - 6;
    canvas.drawCircle(c, rOuter, paint);
    canvas.drawCircle(c, rInner, paint);
    canvas.drawCircle(c, 3.5, paint..style = PaintingStyle.fill);
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        c + Offset(rInner * 0.6 * math.cos(a), rInner * 0.6 * math.sin(a)),
        c + Offset(rOuter * math.cos(a), rOuter * math.sin(a)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.cert});
  final CloudCertificate cert;

  @override
  Widget build(BuildContext context) {
    // 后端证书 island（sleep 等）→ 本地 Island.id → 岛名
    final localId = cloudCertIslandToLocal(cert.island);
    final name = (localId != null ? Island.byId(localId)?.name : null) ?? cert.island;
    return Container(
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.certBorder),
        gradient: const LinearGradient(
          begin: Alignment(-0.5, -0.5),
          end: Alignment(0.5, 0.5),
          colors: [AppColors.parchment, AppColors.parchmentDeep],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DashedBorderPainter())),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🏴‍☠️ 征服 $name',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800,
                          color: AppColors.inkLight, letterSpacing: 1,
                          fontFamily: 'Cinzel')),
                  const SizedBox(height: 4),
                  Text('连续打卡 21 天 · ${cert.date}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xCC3B2708))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 羊皮纸虚线内框（与船长页证书墙同款 painter）
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x663B2708)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 5, size.width - 10, size.height - 10),
      const Radius.circular(8),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 5.0;
    const dashGap = 3.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
