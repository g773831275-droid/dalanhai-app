import 'package:flutter/material.dart';

import '../services/media_sign_cache.dart';
import '../theme/colors.dart';

/// attachKey 时效签名渲染组件（v2.6 防爬渲染链路）
///
/// 帖子接口只返回 attachKey（无永久直链）→ 本组件内部经 MediaSignCache
/// 换 900s 时效签名 URL → Image.network 渲染；
/// 过期（自动重取）/ 违规 / 无权限 / 网络失败 → 一律渲染占位图（防探测，
/// 不区分具体原因，与后端 missing 语义对齐）。
class SignedImage extends StatefulWidget {
  const SignedImage({
    super.key,
    required this.postId,
    this.index = 0,
    this.fit = BoxFit.cover,
  });

  /// 附件所属帖子 ID（media/sign 按 postId 签发）
  final int postId;

  /// 多图帖中的第几张（与 attachKeys 下标一致）
  final int index;

  final BoxFit fit;

  @override
  State<SignedImage> createState() => _SignedImageState();
}

class _SignedImageState extends State<SignedImage> {
  Future<String?> _future = Future<String?>.value(null);

  @override
  void initState() {
    super.initState();
    _future = MediaSignCache.instance
        .urlFor(widget.postId, index: widget.index);
  }

  @override
  void didUpdateWidget(SignedImage old) {
    super.didUpdateWidget(old);
    if (old.postId != widget.postId || old.index != widget.index) {
      _future = MediaSignCache.instance
          .urlFor(widget.postId, index: widget.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<String?> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Placeholder(icon: Icons.hourglass_empty);
        }
        final String? url = snap.data;
        if (url == null) {
          // 过期重取失败 / 违规 / 无权限 / 不存在 —— 统一占位图，不暴露原因
          return const _Placeholder(icon: Icons.hide_image_outlined);
        }
        return Image.network(
          url,
          fit: widget.fit,
          errorBuilder: (_, _, _) =>
              const _Placeholder(icon: Icons.hide_image_outlined),
        );
      },
    );
  }
}

/// 占位图：深海底色 + 半透明图标（与 App 深色主题一致）
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.deep,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.sub, size: 28),
    );
  }
}
