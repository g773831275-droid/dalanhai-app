import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// v2.9.4 头像裁剪页（1:1 正方形，自研零依赖）
///
/// 交互：图片以 cover 填满正方形取景框，单指拖动 / 双指捏合（1x~4x）选取区域；
/// 变换范围钳制保证取景框始终被图片覆盖（不会拖出空白）。
/// 确认后按当前可视区域反算源图像素矩形，Canvas 裁剪输出 PNG 字节，
/// 交由上层 compressAvatarBytes 压缩（长边 1024 / 0.8 / jpg）。
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final TransformationController _transform = TransformationController();
  ui.Image? _img;
  int _imgW = 0;
  int _imgH = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _transform.dispose();
    _img?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _img = frame.image;
        _imgW = frame.image.width;
        _imgH = frame.image.height;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: SafeArea(
        child: Column(children: [
          // 顶栏
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.sub),
              ),
              const Expanded(
                child: Center(
                  child: Text('裁剪头像',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 48),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('拖动或双指缩放，选取 1:1 头像区域',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 12),
          // 取景区
          Expanded(child: Center(child: _viewport())),
          const SizedBox(height: 16),
          // 确认按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: (_img == null || _failed) ? null : _confirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: (_img == null || _failed)
                        ? null
                        : AppColors.btnGoldGradient,
                    color: (_img == null || _failed)
                        ? AppColors.cardSolid
                        : null,
                  ),
                  child: Text(
                    _failed ? '图片读取失败，请返回重选' : '确认裁剪',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: (_img == null || _failed)
                          ? AppColors.sub
                          : AppColors.goldBtnText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _viewport() {
    final double side = _viewportSide(context);
    if (_failed) {
      return SizedBox(
        width: side,
        height: side,
        child: const Center(child: Icon(Icons.broken_image, color: AppColors.sub, size: 48)),
      );
    }
    if (_img == null) {
      return SizedBox(
        width: side,
        height: side,
        child: const Center(
            child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: side,
        height: side,
        child: Stack(children: [
          // 图片变换层
          Positioned.fill(
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                maxScale: 4,
                minScale: 1,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionEnd: (_) => _clampTransform(side),
                child: SizedBox(
                  width: side,
                  height: side,
                  child: RawImage(
                    image: _img,
                    fit: BoxFit.cover,
                    width: side,
                    height: side,
                  ),
                ),
              ),
            ),
          ),
          // 1:1 取景遮罩（圆形参考线；实际裁剪区域即整个取景框）
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _CropMaskPainter()),
            ),
          ),
        ]),
      ),
    );
  }

  double _viewportSide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width.clamp(0, size.height * 0.62);
  }

  /// 钳制变换：缩放后子方框必须始终覆盖取景框（平移 ∈ [S - S*k, 0]）
  void _clampTransform(double side) {
    final Matrix4 m = _transform.value;
    final double k = m.getMaxScaleOnAxis();
    double tx = m.getTranslation().x;
    double ty = m.getTranslation().y;
    final double lo = side - side * k;
    tx = tx.clamp(lo, 0.0);
    ty = ty.clamp(lo, 0.0);
    if (tx != m.getTranslation().x || ty != m.getTranslation().y) {
      _transform.value = Matrix4.identity()
        ..translateByDouble(tx, ty, 0, 1)
        ..scaleByDouble(k, k, 1, 1);
    }
  }

  /// 确认裁剪：可视区域 → 子坐标 → 源图像素矩形 → Canvas 输出
  Future<void> _confirm() async {
    final img = _img;
    if (img == null) return;
    final side = _viewportSide(context);
    final Matrix4 m = _transform.value;
    final double k = m.getMaxScaleOnAxis();
    final double tx = m.getTranslation().x;
    final double ty = m.getTranslation().y;

    // 取景框在子坐标中的矩形（取景框原点即屏幕 (px0, py0)，子坐标 = 屏幕/k - t/k）
    // 子方框与取景框同尺寸同原点：可视子坐标矩形 = [-tx/k, -ty/k, S/k, S/k]
    final Rect cropInChild = Rect.fromLTWH(-tx / k, -ty / k, side / k, side / k);

    // cover：显示缩放 d = max(S/iw, S/ih)，绘制区域在子坐标中居中
    final double d = (side / _imgW > side / _imgH) ? side / _imgW : side / _imgH;
    final double drawW = _imgW * d;
    final double drawH = _imgH * d;
    final double offX = (side - drawW) / 2;
    final double offY = (side - drawH) / 2;

    // 子坐标 → 源像素，并钳制到图像边界
    double sx = ((cropInChild.left - offX) / d).clamp(0.0, _imgW.toDouble());
    double sy = ((cropInChild.top - offY) / d).clamp(0.0, _imgH.toDouble());
    double ex = ((cropInChild.right - offX) / d).clamp(0.0, _imgW.toDouble());
    double ey = ((cropInChild.bottom - offY) / d).clamp(0.0, _imgH.toDouble());
    if (ex - sx < 8 || ey - sy < 8) {
      // 极端情况（图片被拖出取景框）：回退为整图居中方裁
      final int s = _imgW < _imgH ? _imgW : _imgH;
      sx = (_imgW - s) / 2;
      sy = (_imgH - s) / 2;
      ex = sx + s;
      ey = sy + s;
    }
    final Rect srcRect = Rect.fromLTWH(sx, sy, ex - sx, ey - sy);

    // Canvas 裁剪输出（PNG，后续统一压缩为 jpg 1024/0.8）
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      img,
      srcRect,
      Rect.fromLTWH(0, 0, srcRect.width, srcRect.height),
      Paint(),
    );
    final picture = recorder.endRecording();
    final int outW = srcRect.width.round().clamp(1, 4096);
    final int outH = srcRect.height.round().clamp(1, 4096);
    final ui.Image out = await picture.toImage(outW, outH);
    final ByteData? data =
        await out.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('裁剪失败，请重试',
              style: TextStyle(color: AppColors.textPrimary)),
          backgroundColor: AppColors.cardSolid,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(context, data.buffer.asUint8List());
  }
}

/// 取景遮罩：四角压暗 + 中央圆形参考线（裁剪结果为正方形，展示时圆形呈现）
class _CropMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
        full.deflate(0), const Radius.circular(12));
    // 压暗四周（中央挖出圆形参考区域以外的部分不处理 —— 取景框本身就是裁剪区）
    canvas.drawDRRect(
      rrect,
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: full.center,
              width: size.shortestSide - 48,
              height: size.shortestSide - 48),
          Radius.circular(size.shortestSide)),
      Paint()..color = const Color(0x66000000),
    );
    // 圆形参考线
    canvas.drawCircle(
      full.center,
      size.shortestSide / 2 - 24,
      Paint()
        ..color = const Color(0x88E8B84A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
