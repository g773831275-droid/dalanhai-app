import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../services/cloud_models.dart';
import '../theme/colors.dart';

/// 大蓝海支持者徽章 · 感谢信（独立二级页，iOS/Android 共用文案）
/// 徽章仅纯纪念装饰，不附带任何特权/流量倾斜/审核优待/额度加成
class SupporterLetterPage extends StatelessWidget {
  const SupporterLetterPage({super.key, required this.badge, this.isSelf = false});

  final CloudSupporterBadge badge;

  /// 视图归属：true=本人（展示累计支持）/ false=他人（隐藏累计金额——后端本就不下发，双保险）
  final bool isSelf;

  /// iOS 退款提示仅 iOS 渲染（安卓不显示）；IAP 未接入期同样按平台分支预留
  bool get isAndroid => Platform.isAndroid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.parchment),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('支持者徽章',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            // 徽章图（放大占满原圆环尺寸，无外圈描边；阴影保留；图内小字已裁除）
            Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x2ED4AF56),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/supporter_badge_round.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const SizedBox(height: 4),
            // 正文（信纸卡：羊皮纸虚线内框风格与征服证书统一）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.certBorder),
                gradient: const LinearGradient(
                  begin: Alignment(-0.5, -0.5),
                  end: Alignment(0.5, 0.5),
                  colors: [AppColors.parchment, AppColors.parchmentDeep],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LetterLine('致同行的船长：'),
                  SizedBox(height: 10),
                  _LetterLine('感谢您选择支持大蓝海社区。'),
                  SizedBox(height: 10),
                  _LetterLine('您的支持，会用来支付服务器、存储、内容审核和项目运营成本，让这片海继续存在。'),
                  SizedBox(height: 10),
                  _LetterLine('愿我们一起，稳步向前。'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 获取时间（动态回填发放时间）+ 累计支持（仅本人可见，徽章只发一次、后续支持仅累计）
            Text(
              '获取时间：${badge.awardedAt.isEmpty ? '—' : badge.awardedAt}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            // 累计支持金额：仅本人视图展示（他人视图后端不下发，此处 isSelf 双保险）
            if (isSelf && badge.totalSupported > 0) ...[
              const SizedBox(height: 6),
              Text(
                '您累计支持：${badge.totalSupported.toStringAsFixed(0)}元',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              '此徽章为纯纪念装饰，不附带任何特权或权益',
              style: TextStyle(color: AppColors.textHint, fontSize: 11),
            ),
            // iOS 专属：Apple 退款提示（安卓不渲染此行；IAP 接入后由系统弹窗兜底）
            if (!isAndroid) ...[
              const SizedBox(height: 6),
              const Text(
                'iOS 端购买经由 App Store 完成，退款事宜请通过 Apple 官方渠道申请',
                style: TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 信纸正文行（统一行高/墨色，对齐证书卡 inkLight）
class _LetterLine extends StatelessWidget {
  const _LetterLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        height: 1.7,
        color: AppColors.inkLight,
      ),
    );
  }
}
