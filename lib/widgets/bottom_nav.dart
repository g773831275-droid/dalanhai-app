import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 底栏导航 — 4 Tab + 居中凸起金色「+」发布按钮
/// 对应 H5 的 .tabbar + .tab-pub 布局
///
/// 1:1 复刻 H5：
/// - emoji 图标（🏝️ ⚓ 🧭）+ SVG 房屋图标（闹市）
/// - 未选中：去饱和度 40% + 透明度 0.75（H5 filter:grayscale(.4);opacity:.75）
/// - 选中：金色阴影发光 + active 顶部金线
/// - 发布按钮虚线外圈 + CustomPaint 绘制的 + 号（更粗更明显）
/// - 整个 Container 贴底（含 home indicator）
/// - 毛玻璃背景
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCompose;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCompose,
  });

  // H5 emoji 图标
  static const _tabEmojis = ['🏝️', '⚓', '🧭']; // 岛屿/港口/船长
  static const _tabLabels = ['岛屿', '港口', '闹市', '船长'];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // 整体高度 = tab 行 72 + 凸出空间 22 + home indicator inset
    // 把发布按钮放在 ClipRect 外面，这样按钮上半部分不会被裁剪
    return SizedBox(
      height: 72 + 22 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 背景层 + 4 个 tab（含毛玻璃和 ClipRect，只裁剪这部分）
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 72 + bottomInset,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.tabbarGradient,
                    border: Border(
                      top: BorderSide(color: AppColors.gold.withValues(alpha: 0.2), width: 1),
                    ),
                  ),
                  child: SizedBox(
                    height: 72,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // 4 个 Tab（中间留空给 + 按钮）
                        Row(
                          children: [
                            Expanded(child: _buildTab(context, 0)),
                            Expanded(child: _buildTab(context, 1)),
                            const Expanded(child: SizedBox()), // + 按钮占位
                            Expanded(child: _buildTab(context, 2)),
                            Expanded(child: _buildTab(context, 3)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 发布按钮（独立放在 ClipRect 外面，可以凸出不被裁剪）
          Positioned(
            top: 0,
            left: 0, right: 0,
            child: Center(
              child: _ComposeButton(onTap: onCompose),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final active = index == currentIndex;
    final labelColor = active ? AppColors.gold : AppColors.sub;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTabSelected(index),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标：岛屿/港口/船长用 emoji，闹市用 SVG 房屋图标
              if (index == 2)
                _HouseIcon(size: 22, color: labelColor, active: active)
              else
                _EmojiIcon(
                  emoji: _tabEmojis[index == 3 ? 2 : index],
                  active: active,
                ),
              const SizedBox(height: 3),
              Text(
                _tabLabels[index],
                style: TextStyle(
                  fontSize: 10,
                  color: labelColor,
                  letterSpacing: 2,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
          // active 顶部金线装饰（::before）
          if (active)
            const Positioned(
              top: -3,
              child: _ActiveLine(),
            ),
        ],
      ),
    );
  }
}

/// Emoji 图标 — 去饱和度矩阵 + opacity 模拟 H5 未选中灰度效果
class _EmojiIcon extends StatelessWidget {
  final String emoji;
  final bool active;

  const _EmojiIcon({required this.emoji, required this.active});

  @override
  Widget build(BuildContext context) {
    Widget text = Text(emoji, style: const TextStyle(fontSize: 22, height: 1));
    if (active) {
      // 选中：金色阴影发光
      return Text(
        emoji,
        style: TextStyle(
          fontSize: 22,
          height: 1,
          shadows: [
            Shadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 12),
          ],
        ),
      );
    }
    // 未选中：去饱和度 40% + opacity 0.75（H5 效果）
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.7874, 0.1072, 0.0722, 0, 0,
        0.1072, 0.7874, 0.0722, 0, 0,
        0.1072, 0.1072, 0.7874, 0, 0,
        0,      0,      0,      1, 0,
      ]),
      child: Opacity(opacity: 0.75, child: text),
    );
  }
}

/// Active tab 顶部金线 — 对应 H5 .tab.active::before
class _ActiveLine extends StatelessWidget {
  const _ActiveLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: const LinearGradient(
          colors: [Colors.transparent, AppColors.gold, Colors.transparent],
        ),
      ),
    );
  }
}

/// 闹市 SVG 房屋图标 — 对应 H5 闹市 tab 的 SVG
class _HouseIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool active;

  const _HouseIcon({required this.size, required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size(size, size),
      painter: _HouseIconPainter(color: color),
    );
    if (active) {
      // 选中：金色阴影发光
      return Container(
        padding: const EdgeInsets.all(2),
        child: IconTheme(
          data: IconThemeData(
            shadows: [Shadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 12)],
          ),
          child: icon,
        ),
      );
    }
    // 未选中：去饱和度 + 透明
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.7874, 0.1072, 0.0722, 0, 0,
        0.1072, 0.7874, 0.0722, 0, 0,
        0.1072, 0.1072, 0.7874, 0, 0,
        0,      0,      0,      1, 0,
      ]),
      child: Opacity(opacity: 0.75, child: icon),
    );
  }
}

class _HouseIconPainter extends CustomPainter {
  final Color color;
  _HouseIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final s = size.width / 24;

    final roof = Path()
      ..moveTo(3 * s, 9 * s)
      ..lineTo(12 * s, 3 * s)
      ..lineTo(21 * s, 9 * s);
    canvas.drawPath(roof, paint);

    final body = Path()
      ..moveTo(5 * s, 9 * s)
      ..lineTo(5 * s, 20 * s)
      ..lineTo(19 * s, 20 * s)
      ..lineTo(19 * s, 9 * s);
    canvas.drawPath(body, paint);

    final door = Path()
      ..moveTo(9 * s, 20 * s)
      ..lineTo(9 * s, 14 * s)
      ..lineTo(15 * s, 14 * s)
      ..lineTo(15 * s, 20 * s);
    canvas.drawPath(door, paint);

    canvas.drawLine(Offset(5 * s, 13 * s), Offset(7 * s, 13 * s), paint);
    canvas.drawLine(Offset(17 * s, 13 * s), Offset(19 * s, 13 * s), paint);
  }

  @override
  bool shouldRepaint(covariant _HouseIconPainter oldDelegate) => color != oldDelegate.color;
}

/// 发布按钮 — 对应 H5 .pub-btn
/// 圆形金色渐变 + 虚线外圈 + CustomPaint 绘制的 + 号（更粗更明显）
class _ComposeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ComposeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,  // 确保整个按钮区域都能接收点击
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 圆形按钮 + 虚线外圈
          Stack(
            alignment: Alignment.center,
            children: [
              // 虚线外圈（::after border:1px dashed）
              CustomPaint(
                size: const Size(68, 68),
                painter: _DashedCirclePainter(),
              ),
              // 圆形按钮本体（54x54）+ CustomPaint + 号
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.btnGoldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.copper.withValues(alpha: 0.55),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                ),
                alignment: Alignment.center,
                // CustomPaint + 号（更粗更明显，匹配 H5 SVG stroke-width:2.6）
                child: CustomPaint(
                  size: const Size(28, 28),
                  painter: _PlusIconPainter(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // "发布" 文字
          const Text(
            '发布',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.gold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPaint + 号 — 对应 H5 pub-btn SVG (path d="M12 5v14M5 12h14")
/// stroke-width 2.6 比 Icon(Icons.add_rounded) 更粗更明显
class _PlusIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.goldBtnText
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.36; // 接近 H5 SVG 的 12±7=5-19 范围

    // 横线 M5 12h14
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), paint);
    // 竖线 M12 5v14
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 虚线圆圈绘制器 — 对应 H5 .pub-btn::after
class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 1;

    const dashCount = 40;
    const dashAngle = 3.14159 * 2 / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        dashAngle * 0.5,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}