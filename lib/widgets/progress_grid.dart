import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../data/island_logic.dart' as logic;

/// 21 天打卡进度格 — 1:1 复刻 H5 .progress-grid
/// 7 列 × 3 行，done=金色渐变+glow，today=浪花色描边
///
/// v2.9.3 时间统一：[todayOverride] = 服务端"今天"（Asia/Shanghai，来自打卡接口
/// payload.today）→ 日历窗口与选中格以它为唯一时间来源；null（离线本地模式）
/// 才回退手机本地时间。修复：设备时区 ≠ +8 时，21 格窗口与服务端打卡日期错位
/// （服务端 11-09 的打卡落在窗口外 → 连续 2 天只亮 1 格、today 描边落在 8 号）。
class ProgressGrid extends StatelessWidget {
  final List<String> checkins;
  final int target;
  final String? todayOverride; // 服务端"今天"（YYYY-MM-DD）

  const ProgressGrid({
    super.key,
    required this.checkins,
    this.target = 21,
    this.todayOverride,
  });

  @override
  Widget build(BuildContext context) {
    // 服务端 today 优先（无时区修饰直接解析，dateStr(d) 与之同口径）
    final DateTime today = (todayOverride != null && todayOverride!.isNotEmpty)
        ? DateTime.parse(todayOverride!)
        : DateTime.now();
    final checkSet = checkins.toSet();
    final todayS = logic.dateStr(today);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: target,
      itemBuilder: (context, index) {
        final d = today.subtract(Duration(days: target - 1 - index));
        final ds = logic.dateStr(d);
        final has = checkSet.contains(ds);
        final isToday = ds == todayS;

        // today 格子外层加浪花色描边（对应 H5 .grid-cell.today outline）
        Widget cell = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: has ? AppColors.gridDoneGradient : null,
            color: has ? null : const Color(0x0DFFFFFF),
            border: has
                ? Border.all(color: AppColors.gold.withValues(alpha: 0.6))
                : Border.all(color: AppColors.line),
            boxShadow: has
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: has ? FontWeight.w700 : FontWeight.w400,
              color: has ? AppColors.goldBtnText : AppColors.sub,
            ),
          ),
        );

        if (isToday) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.foam, width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: cell,
          );
        }
        return cell;
      },
    );
  }
}
