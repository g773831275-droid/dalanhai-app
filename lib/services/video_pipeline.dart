import 'dart:io';

import 'package:video_compress/video_compress.dart';

import 'media_rules.dart';
import 'image_pipeline.dart' show MediaValidationException;

/// 转码产物：标准 mp4（H.264 + AAC）+ 实测时长/大小
class TranscodedVideo {
  const TranscodedVideo({required this.file, required this.durationMs, required this.sizeBytes});
  final File file;

  /// 实测时长（毫秒）
  final int durationMs;

  /// 实测文件大小（字节）
  final int sizeBytes;

  int get durationSec => (durationMs / 1000).ceil();
}

/// v2.6.1 视频发布管线（iPhone 原生 mov/H.265 必须转码，Android 同样统一转码）
///
/// 执行顺序（严格按规范，不依赖手机相机设置）：
///   ① 读取原始视频时长，>30s → 抛异常（弹窗拒绝，不启动转码，不白耗电）
///      —— 原始视频【大小】不拦截，允许加载大文件进入转码
///   ② video_compress 转码：平台编码器（iOS AVFoundation / Android MediaCodec）
///      默认输出 mp4 容器 + H.264 视频 + AAC 音频；24fps、中等画质
///      （fast preset 由平台编码器内部决定，插件不暴露该参数）
///   ③ 转码完成后校验输出 mp4：≤30MB 且 ≤30s，不满足抛异常拦截不上传
Future<TranscodedVideo> prepareVideoForUpload(File src) async {
  // ① 原始时长前置校验
  final MediaInfo srcInfo = await VideoCompress.getMediaInfo(src.path);
  final int srcDurationMs = srcInfo.duration?.toInt() ?? 0;
  if (srcDurationMs <= 0) {
    throw const MediaValidationException('无法读取视频信息，请换一段试试');
  }
  if (srcDurationMs > MediaRules.videoMaxDurationSec * 1000) {
    throw const MediaValidationException(
        '视频超过 ${MediaRules.videoMaxDurationSec} 秒上限，请裁剪后再发布');
  }

  // ② 转码：mp4 + H.264 + AAC，24fps 中等画质
  final MediaInfo? out = await VideoCompress.compressVideo(
    src.path,
    quality: VideoQuality.MediumQuality,
    frameRate: MediaRules.videoFrameRate,
    deleteOrigin: false, // 保留原文件，由用户/系统相册管理
    includeAudio: true,
  );
  final File? outFile = out?.file;
  if (out == null || outFile == null || !await outFile.exists()) {
    throw const MediaValidationException('视频转码失败，请重试');
  }

  // ③ 输出校验：大小 ≤30MB、时长 ≤30s（实测，不信任转码参数）
  final int sizeBytes = await outFile.length();
  if (sizeBytes > MediaRules.videoMaxBytes) {
    throw const MediaValidationException('视频压缩后仍超过 30MB，无法上传');
  }
  final int durationMs = out.duration?.toInt() ?? 0;
  if (durationMs > MediaRules.videoMaxDurationSec * 1000) {
    throw const MediaValidationException(
        '视频时长超过 ${MediaRules.videoMaxDurationSec} 秒上限，无法上传');
  }
  return TranscodedVideo(file: outFile, durationMs: durationMs, sizeBytes: sizeBytes);
}
