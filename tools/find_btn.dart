// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;
void main(List<String> args) {
  final im = img.decodeImage(File(args[0]).readAsBytesSync())!;
  print('尺寸: ${im.width}x${im.height}');
  int bx0 = im.width, bx1 = 0, by0 = im.height, by1 = 0;
  for (var y = 0; y < im.height; y += 2) {
    for (var x = 0; x < im.width; x += 2) {
      final p = im.getPixel(x, y);
      if (p.r > 200 && p.g > 130 && p.g < 190 && p.b < 110) {
        if (x < bx0) bx0 = x;
        if (x > bx1) bx1 = x;
        if (y < by0) by0 = y;
        if (y > by1) by1 = y;
      }
    }
  }
  if (bx1 == 0) { print('未找到金色大按钮'); return; }
  print('金色按钮包围盒: ($bx0,$by0)-($bx1,$by1) 中心=(${(bx0 + bx1) ~/ 2},${(by0 + by1) ~/ 2})');
}
