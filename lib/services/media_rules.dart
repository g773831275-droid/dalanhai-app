/// v2.6.1 媒体上传规范常量 —— 与后端 index.js 的 MEDIA_RULES 严格对齐
///
/// 链路：前端压缩/转码 + 声明参数 → 后端 PutObject 之前校验（失败 400/429，
/// 不上 OSS 不调审核）→ 私有 OSS 存储 → AI 内容审核 → 通过后仅返回 attachKey
/// → POST /api/media/sign 换 900s 时效签名 URL 渲染（不返回原始 OSS 地址）。
class MediaRules {
  MediaRules._();

  // ── 图片 ──
  /// 单张后端硬上限 10MB（超限后端 400 拒绝）
  static const int imageMaxBytes = 10 * 1024 * 1024;

  /// 前端压缩目标 5MB 以内（控制流量/审核成本；后端闸门放宽到 10MB，
  /// 避免 iPhone 高像素原图压缩异常时误拦正常用户）
  static const int imageTargetBytes = 5 * 1024 * 1024;

  /// 长边上限 2048px（前端压缩目标 + 后端声明值校验）
  static const int imageLongEdge = 2048;

  /// 单次发帖最多 4 张（后端强校验）
  static const int imageMaxPerPost = 4;

  /// 格式白名单（gif / heic 及其它后端全部拦截）
  static const List<String> imageExts = <String>['jpg', 'jpeg', 'png', 'webp'];

  // ── 视频 ──
  /// 单文件后端硬上限 30MB（校验【转码输出后的 mp4】）
  static const int videoMaxBytes = 30 * 1024 * 1024;

  /// 前端转码目标：尽量压制到 20MB 以内
  static const int videoTargetBytes = 20 * 1024 * 1024;

  /// 时长上限 30s（原始视频先校验，超过直接弹窗不启动转码）
  static const int videoMaxDurationSec = 30;

  /// 单次发帖最多 1 条
  static const int videoMaxPerPost = 1;

  /// 仅放行 mp4 容器 + H.264 视频 + AAC 音频；mov / mkv / avi / H.265(HEVC) 全拦截
  static const List<String> videoExts = <String>['mp4'];

  /// 转码参数：24fps、中等画质（fast preset 由平台编码器内部决定）
  static const int videoFrameRate = 24;

  // ── 渲染 ──
  /// 时效签名有效期 900s（OSS_SIGN_URL_EXPIRE_SECONDS；过期重取）
  static const int signUrlExpireSec = 900;

  /// 签名 URL 提前 60s 视为过期（留出请求在途时间）
  static const int signUrlRefreshMarginSec = 60;
}
