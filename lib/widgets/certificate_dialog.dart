import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../data/models.dart';
import '../data/island_logic.dart';

/// 征服证书弹窗 — 对应 H5 #maskCert
/// 21 天连续打卡达成时弹出
class CertificateDialog extends StatelessWidget {
  final Island island;

  const CertificateDialog({super.key, required this.island});

  static Future<void> show(BuildContext context, Island island) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CertificateDialog(island: island),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.deep, AppColors.ocean],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 证书标题
            Text('🏴‍☠️', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('征服 ${island.name}', style: AppTypography.h1.copyWith(fontSize: 24)),
            const SizedBox(height: 6),
            Text('CONQUERED', style: AppTypography.goldLabel),
            const SizedBox(height: 20),
            // 证书信息
            GlassInfoBox(
              children: [
                _InfoRow(label: '岛屿', value: island.name),
                _InfoRow(label: '连续', value: '${Island.target} 天'),
                _InfoRow(label: '日期', value: todayStr()),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '连续 21 天登岛达成\n可联系船务长登官方船',
              textAlign: TextAlign.center,
              style: AppTypography.bodySub.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 24),
            // 确认按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('收下证书'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassInfoBox extends StatelessWidget {
  final List<Widget> children;
  const GlassInfoBox({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption),
          Text(value, style: AppTypography.body.copyWith(
            fontFamily: AppTypography.cinzel,
            color: AppColors.goldLight,
          )),
        ],
      ),
    );
  }
}
