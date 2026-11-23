// 截图图片区域判定工具：采样首帖图片区域，输出色彩方差与主色
// 用法: dart run tools/analyze_shots.dart <img1.png> [img2.png ...]
// 判定: 区域 std 低 + 主色=深蓝系(~16,33,58) => 失败占位; std 高/彩色 => 成功
// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  for (final path in args) {
    final bytes = File(path).readAsBytesSync();
    final im = img.decodeImage(bytes);
    if (im == null) {
      print('${path.split('/').last}: DECODE FAIL');
      continue;
    }
    final w = im.width, h = im.height;
    final x0 = (w * 0.25).toInt(), x1 = (w * 0.75).toInt();
    final y0 = (h * 0.27).toInt(), y1 = (h * 0.42).toInt();
    var sumR = 0.0, sumG = 0.0, sumB = 0.0;
    var n = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final p = im.getPixel(x, y);
        sumR += p.r; sumG += p.g; sumB += p.b;
        n++;
      }
    }
    final mR = sumR / n, mG = sumG / n, mB = sumB / n;
    var v = 0.0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final p = im.getPixel(x, y);
        v += (p.r - mR) * (p.r - mR) + (p.g - mG) * (p.g - mG) + (p.b - mB) * (p.b - mB);
      }
    }
    final std = (v / (n * 3));
    final name = path.split(Platform.pathSeparator).last;
    // std 是方差：占位图（均匀深蓝+小图标）方差~225；真实截图内容方差~645
    final verdict = std < 400 ? 'FAIL(占位)' : 'OK(图片)';
    print('$name: 区域RGB均值=(${mR.toStringAsFixed(0)},${mG.toStringAsFixed(0)},${mB.toStringAsFixed(0)}) 方差=${std.toStringAsFixed(0)} => $verdict');
  }
}
