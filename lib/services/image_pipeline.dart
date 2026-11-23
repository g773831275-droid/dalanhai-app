import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'media_rules.dart';

/// 媒体校验异常 —— 消息可直接展示给用户（SnackBar / 弹窗）
class MediaValidationException implements Exception {
  const MediaValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// v2.6.1 图片压缩管线（flutter_image_compress，替代 image 包纯 Dart 编解码）
///
/// 规范：长边 2048px、画质 0.7~0.8、优先压缩到 5MB 以内；
/// 两档策略：先 78 档，仍 >5MB 再压 70 档；最终 >10MB 抛异常（后端硬上限兜底）。
/// 输出 JPEG（iOS/Android 双端稳定；webp 编码仅 Android 端支持，统一 jpg，
/// 后端白名单 jpg 在列）。
///
/// 注意：flutter_image_compress 的 minWidth/minHeight 语义是「等比缩放的上限」，
/// 即结果图片宽高都不会超过给定值，比例保持——正好对应「长边 ≤2048」。
///
/// v2.9.3 平台分支：flutter_image_compress 仅安卓/iOS 原生可用，Web/桌面端
/// compressWithFile 返回 null（此前 Web 选图必 toast「图片处理失败」）。
/// kIsWeb 时跳过压缩直接返回原图字节 —— **Web 只用于纯文字链路调试，
/// 图片上传联调（policy→直传→发帖）一律走安卓/iOS 真机/模拟器**。
Future<Uint8List> compressImage(XFile src) async {
  // ── Web：跳过原生压缩，直接用原图字节（10MB 上限仍校验）──
  if (kIsWeb) {
    final Uint8List raw = await src.readAsBytes();
    if (raw.length > MediaRules.imageMaxBytes) {
      throw const MediaValidationException('原图超过 10MB 上限（Web 端不做压缩）');
    }
    return raw;
  }

  // ── 安卓/iOS：原生压缩管线 ──
  Uint8List? out = await FlutterImageCompress.compressWithFile(
    src.path,
    minWidth: MediaRules.imageLongEdge,
    minHeight: MediaRules.imageLongEdge,
    quality: 78, // ≈0.78，规范区间 0.7~0.8 的上档
    format: CompressFormat.jpeg,
  );
  if (out == null || out.isEmpty) {
    throw const MediaValidationException('图片处理失败，请换一张试试');
  }
  // 仍超 5MB 目标 → 降到 0.70 档再压一次
  // v2.9.12：对第一档输出字节 compressWithList 二次编码 ——
  // 此前 compressWithFile(src.path) 会重新读盘+解码原图，白费一次 IO 与解码
  if (out.length > MediaRules.imageTargetBytes) {
    final Uint8List retry = await FlutterImageCompress.compressWithList(
      out,
      minWidth: MediaRules.imageLongEdge,
      minHeight: MediaRules.imageLongEdge,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (retry.isNotEmpty) out = retry;
  }
  // 后端硬上限兜底：>10MB 一律拦截不上传（后端也会 400）
  if (out.length > MediaRules.imageMaxBytes) {
    throw const MediaValidationException('图片压缩后仍超过 10MB，无法上传');
  }
  return out;
}

/// 发帖前的图片数量校验（与后端 imageMaxPerPost=4 对齐）
void validateImageCount(int count) {
  if (count > MediaRules.imageMaxPerPost) {
    throw MediaValidationException('单次发帖最多 ${MediaRules.imageMaxPerPost} 张图片');
  }
}

/// v2.9.4 头像压缩管线：长边 ≤1024px、画质 0.8、输出 JPEG。
/// [src] 为裁剪后的原始字节（PNG/任意），原生端走 compressWithList 缩放编码。
/// Web 端 flutter_image_compress 不可用 → 原样返回（头像链路仅移动端联调）。
Future<Uint8List> compressAvatarBytes(Uint8List src) async {
  if (kIsWeb) return src;
  Uint8List? out = await FlutterImageCompress.compressWithList(
    src,
    minWidth: 1024,
    minHeight: 1024,
    quality: 80, // 0.8
    format: CompressFormat.jpeg,
  );
  if (out.isEmpty) {
    throw const MediaValidationException('头像处理失败，请换一张试试');
  }
  return out;
}
