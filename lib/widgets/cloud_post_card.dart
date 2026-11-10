import 'package:flutter/material.dart';

import '../pages/cloud_post_detail_page.dart';
import '../services/cloud_feed.dart';
import '../services/cloud_models.dart';
import '../theme/colors.dart';
import 'image_viewer.dart';
import 'user_avatar.dart';

/// 云端日志卡片（v2.9.6 公共组件）—— 样式与港口流 _CloudCard 完全一致。
///
/// 供他人主页 / 船长页「我的日志 / 点赞的日志」复用；
/// [onAvatarTap] 非空时作者头像可点击（跳对应他人主页）；
/// [loader] 港口流场景传入（详情页点赞/评论数同步回列表），其他页面可空。
///
/// v2.9.8 船长页长按菜单/批量删除：
/// - [onLongPress] 仅船长页「我的日志」传入（长按 500ms 默认时长唤起菜单）；
///   点赞的日志 Tab / 他人主页不传 → 无菜单
/// - 长按排除区：图片网格（保留点图放大预览）、头像、点赞、评论、话题标签
/// - [selectMode] 批量选择模式：点卡片切换勾选、长按失效，左上角出现勾选框
/// - 置顶标识 [showPinBadge]：post.isTop 时左上角金色【置顶】标签（本人/访客可见）
class CloudPostCard extends StatelessWidget {
  const CloudPostCard({
    super.key,
    required this.post,
    this.loader,
    this.isHot = false,
    this.onAvatarTap,
    this.onLongPress,
    this.selectMode = false,
    this.checked = false,
    this.onToggleSelect,
    this.showPinBadge = true,
  });

  final CloudPost post;
  final CloudFeedLoader? loader;
  final bool isHot;
  final void Function(CloudAuthor author)? onAvatarTap;

  /// 长按唤起操作菜单（船长页我的日志专用；500ms 为 GestureDetector 默认时长）
  final VoidCallback? onLongPress;

  /// 批量选择模式：点卡片 = 勾选/取消勾选，长按菜单失效
  final bool selectMode;
  final bool checked;
  final VoidCallback? onToggleSelect;

  /// 置顶金色标签开关（默认开；他人主页/船长页均可见）
  final bool showPinBadge;

  @override
  Widget build(BuildContext context) {
    final isImage = post.coverKeys.isNotEmpty;

    void openDetail() {
      Navigator.of(context).push(
        MaterialPageRoute(
          // loader 可空：他人主页/点赞列表无 loader，详情页内部已做 null 安全
          builder: (_) => CloudPostDetailPage(post: post, loader: loader),
        ),
      );
    }

    // 批量模式：点卡片 = 勾选切换；正常模式：点卡片 = 进详情
    final onTapCard = selectMode
        ? (onToggleSelect == null ? null : () => onToggleSelect!())
        : openDetail;
    // 批量模式下长按不唤起菜单（需求：批量模式点击卡片触发勾选）
    final onLongPressCard = selectMode ? null : onLongPress;

    return GestureDetector(
      onTap: onTapCard,
      onLongPress: onLongPressCard,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x8C123A6B), Color(0xBF0A1F3D)],
          ),
          border: Border.all(
            color: checked
                ? AppColors.gold.withValues(alpha: 0.8)
                : AppColors.sky.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 多图网格（1 全宽 / 2 并排 / 3 一行三张 / 4 田字格，>4 截前 4）。
                // 图片区域用空 onLongPress 吸收长按：保留点图放大预览，
                // 长按图片不唤起卡片菜单（需求：带图帖仅卡片空白区可长按）
                if (isImage)
                  GestureDetector(
                    onLongPress: () {},
                    child: PostImageGrid(
                      postId: post.postId,
                      keys: post.coverKeys,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14, isImage ? 12 : 16, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.content.isNotEmpty)
                        Text(
                          _cardBody(post.content),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFEAF2FF), height: 1.5),
                        ),
                      // 话题标签：长按吸收（不触发卡片菜单），点击行为不变
                      if (post.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onLongPress: () {},
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ...post.tags.map((t) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('#$t', style: const TextStyle(fontSize: 10, color: AppColors.gold)),
                                    )),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // 作者行 + 点赞/评论
                      Row(
                        children: [
                          // 作者头像（可点击 → 他人主页；长按吸收不触发菜单）
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onAvatarTap == null ? null : () => onAvatarTap!(post.author),
                            onLongPress: () {},
                            child: Container(
                              width: 24, height: 24,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.streakPillGradient,
                              ),
                              alignment: Alignment.center,
                              child: UserAvatar(
                                avatar: post.author.avatar,
                                fallbackText: post.author.displayName,
                                size: 24,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 昵称区域：长按吸收（不触发卡片菜单）
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () {},
                              child: Text(post.author.displayName, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                            ),
                          ),
                          GestureDetector(
                            onTap: openDetail,
                            onLongPress: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    post.liked ? Icons.favorite : Icons.favorite_border,
                                    color: post.liked ? AppColors.coral : AppColors.foam,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${post.likeCount}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: post.liked ? AppColors.coral : AppColors.foam,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: openDetail,
                            onLongPress: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                '💬 ${post.commentCount}',
                                style: const TextStyle(fontSize: 12, color: AppColors.sub),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
            // 置顶标识：左上角金色【置顶】（批量模式下让位于勾选框，右移避让）
            if (post.isTop && showPinBadge && !selectMode)
              Positioned(
                top: 10,
                left: 10,
                child: _pinBadge(),
              ),
            // 批量模式：左上角圆形勾选框
            if (selectMode)
              Positioned(
                top: 10,
                left: 10,
                child: _checkBox(),
              ),
            // 批量模式下置顶帖保留标识（勾选框右侧）
            if (post.isTop && showPinBadge && selectMode)
              Positioned(
                top: 10,
                left: 54,
                child: _pinBadge(),
              ),
            // 热门流：右上角 🔥 标识
            if (isHot)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('🔥 热门', style: TextStyle(fontSize: 10, color: AppColors.goldLight)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pinBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.8)),
      ),
      child: const Text('📌 置顶',
          style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w700)),
    );
  }

  Widget _checkBox() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? AppColors.gold : Colors.black.withValues(alpha: 0.55),
        border: Border.all(
          color: checked ? AppColors.gold : AppColors.parchment.withValues(alpha: 0.6),
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: AppColors.goldBtnText)
          : const SizedBox.shrink(),
    );
  }

  /// 港口卡片正文截断（与 _CloudCard 同口径）：
  /// ≤140 字符完整展示；>140 截前 140 字符 + 「…」；
  /// 截断点落在 #话题标签中间时向前微调到标签起始处。
  String _cardBody(String text) {
    const maxChars = 140;
    final chars = text.characters.toList();
    if (chars.length <= maxChars) return text;
    var cut = maxChars;
    final prefix = chars.take(cut).join();
    final hashIdx = prefix.lastIndexOf('#');
    if (hashIdx >= 0) {
      final after = prefix.substring(hashIdx + 1);
      if (!after.contains(' ') && !after.contains('\n')) {
        cut = hashIdx;
      }
    }
    return '${chars.take(cut).join().trimRight()}…';
  }
}
