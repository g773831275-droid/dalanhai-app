import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// v2.9.6 统一社交操作弹窗（日志详情页 / 他人主页共用）。
///
/// 交互约定（需求一/二）：
/// - 「···」更多弹窗：选项 = 举报、拉黑、取消
/// - 举报：无需二次确认，点击直接触发对应流程
/// - 拉黑：专属二次确认弹窗，固定标准文案 + 「取消」「确认拉黑」
/// - 弹窗视觉：深蓝玻璃拟态 + 金色描边，与现有 App 风格统一

/// 「···」更多操作菜单（底部弹窗：举报 / 拉黑 / 取消）
/// 返回 'report' | 'block' | null（取消/点外部关闭）
Future<String?> showMoreActionsSheet(
  BuildContext context, {
  required String nickname,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cardSolid, AppColors.abyss],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '对「$nickname」的操作',
                  style: const TextStyle(
                      color: AppColors.sub, fontSize: 12, letterSpacing: 1),
                ),
              ),
            ),
            _sheetItem(
              sheetCtx,
              icon: '⚑',
              label: '举报',
              danger: false,
              onTap: () => Navigator.pop(sheetCtx, 'report'),
            ),
            _sheetItem(
              sheetCtx,
              icon: '🚫',
              label: '拉黑',
              danger: true,
              onTap: () => Navigator.pop(sheetCtx, 'block'),
            ),
            _sheetItem(
              sheetCtx,
              icon: '✕',
              label: '取消',
              danger: false,
              onTap: () => Navigator.pop(sheetCtx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Widget _sheetItem(
  BuildContext ctx, {
  required String icon,
  required String label,
  required bool danger,
  required VoidCallback onTap,
}) {
  final color = danger ? AppColors.coral : const Color(0xFFE5EFFA);
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
                width: 28,
                child: Text(icon,
                    style: TextStyle(fontSize: 18, color: color))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15, color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 拉黑专属二次确认弹窗（标准文案固定，日志详情页/他人主页完全统一）。
/// 返回 true = 确认拉黑。
Future<bool?> showBlockConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardSolid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      title: const Text(
        '确定要拉黑该用户吗？',
        style: TextStyle(
            color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        '拉黑后将无法查看对方内容、对方也无法查看和互动你的主页与日志，且会清空双方关注关系',
        style: TextStyle(
            color: AppColors.sub, fontSize: 13, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消', style: TextStyle(color: AppColors.sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('确认拉黑', style: TextStyle(color: AppColors.coral)),
        ),
      ],
    ),
  );
}
