import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 玻璃拟态卡片 — 对应 H5 的 .glass-card 样式
/// 半透明深蓝底 + 毛玻璃模糊 + 细边框
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: onTap != null
                ? GestureDetector(onTap: onTap, child: child)
                : child,
          ),
        ),
      ),
    );
  }
}
