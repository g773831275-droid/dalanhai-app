import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 航级身份标签（v2.9.6 UI 占位，金色小标签）。
///
/// 规则（需求六/五）：
/// - 仅 UI 占位，本期不做航级计算/晋升逻辑（文本由后端 sail_level 字段下发）
/// - 后台开关 enable_sail_level_tag 控制：关闭时 [show] = false，
///   组件完全不渲染 —— 无空白占位、无残留 UI
/// - 位置固定在昵称右侧，样式金色小胶囊，自适应文本宽度不挤压布局
class SailLevelTag extends StatelessWidget {
  const SailLevelTag({super.key, required this.text, this.compact = false});

  /// 航级文本（后端 sail_level）；空文本不渲染
  final String text;

  /// 紧凑模式（他人主页/卡片场景字号更小）
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1.5 : 2.5,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.btnGoldGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.copper.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text.trim(),
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w800,
          color: AppColors.goldBtnText,
          height: 1.2,
        ),
      ),
    );
  }
}
