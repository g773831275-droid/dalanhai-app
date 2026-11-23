import 'package:flutter/material.dart';

import '../services/session_store.dart';
import '../theme/colors.dart';
import '../widgets/reward_sheet.dart';
import 'auth_page.dart';

/// 开服公告二级页（islands Banner reward 卡片点击进入，AGENTS.md §13）
/// 正文固定文案 + 「支持开发者」按钮唤起金额面板（AGENTS.md §13.12 术语规范）
/// 登录闸门：未登录先弹「需要登船」提示 →「好的」进登录页 → 登录成功
/// 回到本页后自动唤起金额面板；已登录直接唤起（auth_page returnTo:'island'）
class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key});

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
        title: const Text('大蓝海・开服公告',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 公告头图风格 banner 条
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: AppColors.islandCardGradient,
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  const Text('📢', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.goldBright, AppColors.gold],
                      ).createShader(b),
                      child: const Text(
                        '大蓝海・开服公告',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _AnnouncementParagraph(
              '兄弟们，大蓝海是属于自律成长、一起往前走的散帅们的社区。',
            ),
            const _AnnouncementParagraph(
              '目前项目由一人公司（OPC）独立开发，服务器、存储、内容审核全部都需要持续投入资金，压力很大。',
            ),
            const _AnnouncementParagraph(
              '如果认可这个社区、愿意帮我分担一部分开发与服务器成本，可以选择支持开发者。',
            ),
            const _AnnouncementParagraph(
              '购买完全自愿，将获得一枚电子纪念徽章，暂无任何特权、回报，纯粹是兄弟们帮这个项目活下去。感谢每一份支持。',
            ),
            const SizedBox(height: 28),
            // 支持开发者按钮（金渐变大按钮，恢复原尺寸与间距）
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppColors.btnGoldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.copper.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => _onRewardTap(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '支持开发者',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldBtnText,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '所有核心功能永久免费 · 支持行为完全自愿',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「支持开发者」入口逻辑：
/// 已登录 → 直接唤起金额面板；
/// 未登录 → 先弹「需要登船」提示 →「好的」进登录页（returnTo:'island'，
/// 登录成功自动 pop 回本页且不跳转其他 Tab）→ 回来后已登录则自动唤起档位弹窗。
Future<void> _onRewardTap(BuildContext context) async {
  // 已登录：不弹登船提示，直接打开档位弹窗
  if (SessionStore.instance.hasToken) {
    await showRewardSheet(context);
    return;
  }
  // 未登录：「需要登船」提示弹窗
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.cardSolid,
      title: const Text('需要登船',
          style: TextStyle(color: AppColors.goldBright, fontSize: 17, fontWeight: FontWeight.w800)),
      content: const Text('登录后即可支持开发者，支持大蓝海继续航行',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('好的', style: TextStyle(color: AppColors.gold)),
        ),
      ],
    ),
  );
  // 弹窗关闭后仍在本页（页面未销毁，context 仍有效）
  if (!context.mounted) return;
  // 「好的」→ 跳登录页；登录成功 auth_page pop 回本页（returnTo:'island'）
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AuthPage(returnTo: 'island')),
  );
  if (!context.mounted) return;
  // 登录成功回到公告页 → 自动唤起金额面板；用户未登录直接返回则不打扰
  if (SessionStore.instance.hasToken) {
    await showRewardSheet(context);
  }
}

/// 公告正文段（统一行高/颜色）
class _AnnouncementParagraph extends StatelessWidget {
  final String text;
  const _AnnouncementParagraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.7,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
