import 'dart:math';

import 'package:flutter/material.dart';

import '../services/media_sign_cache.dart';
import '../theme/colors.dart';

/// v2.9.4 港口多图流式布局 + 全屏大图预览器（自研，零第三方依赖）
///
/// 布局规则（卡片与详情页共用 [PostImageGrid]）：
///   1 图 = 全宽 16:9；2/3 图 = 一行等分；4 图 = 2×2 田字格；>4 张卡片只展示前 4
/// 预览器能力：
///   PageView 左右切换同组全部图片（含卡片未展示的）；
///   InteractiveViewer 捏合缩放 + 双击放大/还原；
///   单指下滑跟手关闭（未放大时），缩放状态下正常平移图片；
///   加载复用 MediaSignCache 时效签名链路，失败统一占位图。

// ══════════════════════════════════════════════════════════
// 多图网格（卡片 / 详情页共用）
// ══════════════════════════════════════════════════════════

/// 帖子多图网格：1 图全宽 / 2 图并排 / 3 图一行三张 / 4 图田字格
/// [keys] 为全部附件 key（决定数量）；网格内最多渲染 4 张，预览器可看全部
class PostImageGrid extends StatelessWidget {
  const PostImageGrid({
    super.key,
    required this.postId,
    required this.keys,
    this.spacing = 4,
    this.padding = EdgeInsets.zero,
  });

  final int postId;
  final List<String> keys;
  final double spacing;
  final EdgeInsetsGeometry padding;

  void _open(BuildContext context, int index) {
    showImageViewer(context, postId: postId, count: keys.length, initialIndex: index);
  }

  Widget _cell(BuildContext context, int index, {double radius = 10}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SignedImageThumb(postId: postId, index: index, onTap: () => _open(context, index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int n = keys.length.clamp(0, 4);
    if (n == 0) return const SizedBox.shrink();

    Widget body;
    switch (n) {
      case 1:
        body = AspectRatio(aspectRatio: 16 / 9, child: _cell(context, 0, radius: 12));
        break;
      case 2:
        body = AspectRatio(
          aspectRatio: 2 / 0.85, // 两列等高，总高约屏宽 42%
          child: Row(children: [
            Expanded(child: _cell(context, 0)),
            SizedBox(width: spacing),
            Expanded(child: _cell(context, 1)),
          ]),
        );
        break;
      case 3:
        body = AspectRatio(
          aspectRatio: 3 / 0.85,
          child: Row(children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: _cell(context, i)),
            ],
          ]),
        );
        break;
      default: // 4 → 2×2
        body = Column(children: [
          Row(children: [
            Expanded(child: AspectRatio(aspectRatio: 4 / 3, child: _cell(context, 0))),
            SizedBox(width: spacing),
            Expanded(child: AspectRatio(aspectRatio: 4 / 3, child: _cell(context, 1))),
          ]),
          SizedBox(height: spacing),
          Row(children: [
            Expanded(child: AspectRatio(aspectRatio: 4 / 3, child: _cell(context, 2))),
            SizedBox(width: spacing),
            Expanded(child: AspectRatio(aspectRatio: 4 / 3, child: _cell(context, 3))),
          ]),
        ]);
    }
    return Padding(padding: padding, child: body);
  }
}

/// 缩略图（点击进预览器）：FutureBuilder 签名 URL + 失败占位 + 渐入
class SignedImageThumb extends StatelessWidget {
  const SignedImageThumb({
    super.key,
    required this.postId,
    required this.index,
    required this.onTap,
  });

  final int postId;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<String?>(
        future: MediaSignCache.instance.urlFor(postId, index: index),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _ViewerPlaceholder(icon: Icons.hourglass_empty);
          }
          final String? url = snap.data;
          if (url == null) {
            return const _ViewerPlaceholder(icon: Icons.hide_image_outlined);
          }
          return Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // 渐入：首帧未就绪时透明，避免白块闪烁
            frameBuilder: (c, child, frame, wasSync) =>
                wasSync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 250), child: child),
            errorBuilder: (_, _, _) => const _ViewerPlaceholder(icon: Icons.hide_image_outlined),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 全屏大图预览器
// ══════════════════════════════════════════════════════════

/// 唤起全屏大图预览（透明路由，黑色渐入）
Future<void> showImageViewer(
  BuildContext context, {
  required int postId,
  required int count,
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (_, _, _) =>
        _ImageViewerPage(postId: postId, count: count, initialIndex: initialIndex),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({required this.postId, required this.count, required this.initialIndex});

  final int postId;
  final int count;
  final int initialIndex;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _pageCtrl = PageController(initialPage: widget.initialIndex);
  final TransformationController _transform = TransformationController();
  late int _index = widget.initialIndex;
  bool _zoomed = false; // 图片处于放大态（>1.05x）→ 下滑关闭禁用，交给缩放平移
  double _dragY = 0; // 下滑跟手位移
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _transform.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  void _onDoubleTap() {
    if (_scale > 1.05) {
      _transform.value = Matrix4.identity();
      _zoomed = false;
    } else {
      const double target = 2.5;
      final Offset? pos = _doubleTapDetails?.localPosition;
      if (pos == null) {
        _transform.value = Matrix4.identity()
          ..scaleByDouble(target, target, 1.0, 1);
      } else {
        // 以双击点为锚点放大：T(anchor) · S · T(-anchor)
        _transform.value = Matrix4.identity()
          ..translateByDouble(pos.dx, pos.dy, 0, 1)
          ..scaleByDouble(target, target, 1.0, 1)
          ..translateByDouble(-pos.dx, -pos.dy, 0, 1);
      }
      _zoomed = true;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_zoomed || _scale > 1.05) return;
    // 只跟手向下、且纵向占主导的位移（横向让给 PageView 切页）
    if (e.delta.dy > 0 && e.delta.dy > e.delta.dx.abs()) {
      setState(() => _dragY += e.delta.dy);
    }
  }

  void _onPointerUp() {
    if (_dragY > 130) {
      Navigator.of(context).pop();
    } else if (_dragY > 0) {
      setState(() => _dragY = 0); // 弹回
    }
  }

  @override
  Widget build(BuildContext context) {
    final double fade = (1 - min(_dragY, 300) / 300).clamp(0.3, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade.clamp(0.0, 1.0)),
      body: Listener(
        onPointerMove: _onPointerMove,
        onPointerUp: (_) => _onPointerUp(),
        onPointerCancel: (_) => _onPointerUp(),
        child: AnimatedContainer(
          duration: _dragY == 0 ? const Duration(milliseconds: 180) : Duration.zero,
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _dragY, 0),
          child: Stack(children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.count,
              onPageChanged: (i) => setState(() {
                _index = i;
                _transform.value = Matrix4.identity();
                _zoomed = false;
                _dragY = 0;
              }),
              itemBuilder: (_, i) => Center(
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1.0,
                  maxScale: 4.0,
                  onInteractionStart: (_) => _zoomed = _scale > 1.05,
                  child: GestureDetector(
                    onDoubleTapDown: (d) => _doubleTapDetails = d,
                    onDoubleTap: _onDoubleTap,
                    child: FutureBuilder<String?>(
                      future: MediaSignCache.instance.urlFor(widget.postId, index: i),
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const _ViewerPlaceholder(icon: Icons.hourglass_empty);
                        }
                        final String? url = snap.data;
                        if (url == null) {
                          return const _ViewerPlaceholder(icon: Icons.hide_image_outlined);
                        }
                        return Image.network(
                          url,
                          fit: BoxFit.contain,
                          frameBuilder: (c, child, frame, wasSync) => wasSync
                              ? child
                              : AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 250),
                                  child: child),
                          errorBuilder: (_, _, _) =>
                              const _ViewerPlaceholder(icon: Icons.hide_image_outlined),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // 顶部：页码 + 关闭
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      '${_index + 1} / ${widget.count}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 48),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 预览器内占位图（深海底色 + 图标，与 App 主题一致）
class _ViewerPlaceholder extends StatelessWidget {
  const _ViewerPlaceholder({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.deep,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.sub, size: 36),
    );
  }
}
