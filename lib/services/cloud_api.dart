import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import 'cloud_models.dart';

/// 后端统一响应 {code: 0|-1, msg, data}，code != 0 抛 ApiException
class ApiException implements Exception {
  const ApiException(this.message, [this.code = -1]);
  final String message;
  final int code;

  @override
  String toString() => message;
}

/// 图片上传失败（结构化分类，2026-11-19 排障日志专用）：
/// failType ∈ risk_limit（risk.js 用户每分钟配额）/ ip_freq_waf（WAF/ESA/nginx
/// IP 频控层）/ timeout / network / sign_invalid（签名失效）/ file_validate
/// （文件校验）/ auth_expired / oss_<Code> / other
/// 仅用于日志分类与用户提示文案选择，不改变上传行为与限流阈值。
class ImageUploadFailure implements Exception {
  final String stage; // put_sign | put_oss
  final String failType;
  final String message;
  final int? httpStatus;
  final String? ossResponse; // OSS XML 或服务端响应体（截断）
  final int? putSignAt; // put-sign 生成时刻（epoch ms）
  final int? putStartAt; // PUT 发起时刻（epoch ms）

  ImageUploadFailure(this.stage, this.failType, this.message,
      {this.httpStatus, this.ossResponse, this.putSignAt, this.putStartAt});

  @override
  String toString() => 'ImageUploadFailure($stage/$failType): $message';
}

/// OSS 直传签名（GET /api/oss/policy 出参）
class OssPolicy {
  const OssPolicy({
    required this.accessKeyId,
    required this.policy,
    required this.signature,
    required this.host,
    required this.dir,
    required this.maxSize,
  });

  factory OssPolicy.fromJson(Map<String, dynamic> j) => OssPolicy(
        accessKeyId: j['accessKeyId'] as String,
        policy: j['policy'] as String,
        signature: j['signature'] as String,
        host: j['host'] as String,
        dir: j['dir'] as String,
        maxSize: j['maxSize'] as int,
      );

  final String accessKeyId;
  final String policy;
  final String signature;
  final String host;
  final String dir;
  final int maxSize;
}

/// OSS PUT 直传签名（GET /api/oss/put-sign 出参，v2.9.3 新通道）
/// 客户端直接 PUT 二进制到 host/key，三个请求头原样回传（均已参与服务端签名）
class OssPutSign {
  const OssPutSign({
    required this.host,
    required this.key,
    required this.contentType,
    required this.date,
    required this.authorization,
    required this.maxSize,
  });

  factory OssPutSign.fromJson(Map<String, dynamic> j) => OssPutSign(
        host: j['host'] as String,
        key: j['key'] as String,
        contentType: j['contentType'] as String,
        date: j['date'] as String,
        authorization: j['authorization'] as String,
        maxSize: (j['maxSize'] as num?)?.toInt() ?? 0,
      );

  final String host; // https://bucket.region.aliyuncs.com（不含结尾 /）
  final String key; // 服务端生成：ugc/yyyyMMdd/时间戳-随机.ext（客户端不可改）
  final String contentType; // 已参与签名，PUT 时不可改
  final String date; // 服务端 UTC 时间（RFC 7231），原样回传 Date 头
  final String authorization; // "OSS AKID:Sig"，原样回传
  final int maxSize;
}

/// media/sign 出参里的单帖签名结果
class SignedPostMedia {
  const SignedPostMedia({required this.urls, required this.expiresAt});

  /// 该帖全部附件的时效 URL（多图帖有多条；顺序与 attachKeys 一致）
  final List<String> urls;

  /// 签名失效时间（毫秒时间戳）
  final int expiresAt;
}

/// media/sign keys 参数的单个裸 key 签名结果（头像等非帖子绑定资源）
class SignedKeyMedia {
  const SignedKeyMedia({required this.url, required this.expiresAt});

  final String url;

  /// 签名失效时间（毫秒时间戳）
  final int expiresAt;
}

/// GrandBlue 后端 API 客户端（v2.6.1 媒体上传规范对接层）
///
/// 职责边界：本类只做「HTTP 通道 + 统一响应解析 + OSS 直传」，
/// 登录态（token 的获取/刷新/持久化）由认证模块负责，登录后调
/// [configure] 注入 baseUrl + token 即可。
///
/// 渲染链路（防爬四道闸的客户端侧）：
///   帖子接口只返回 attachKey（无永久直链）→ [signMedia] 换 900s 时效 URL
///   → 过期/违规/无权限（missing）→ 渲染占位图（SignedImage 组件内置）。
class CloudApi {
  CloudApi._();

  static final CloudApi instance = CloudApi._();

  /// 鉴权成功回调（loginBySms 成功后触发）：
  /// 由 SessionStore.restore() 注入 → 持久化 token 并即时生效。
  /// 回调解耦保证本文件零 Flutter 插件依赖（dart run 冒烟脚本可直接跑）。
  static Future<void> Function(String token, String refreshToken)? onAuthenticated;

  /// 生产：香港节点（HTTP 调试期）；上 HTTPS 后替换为域名
  String? baseUrl;

  /// v2.9.6：测试可注入的 HTTP 客户端（null = 真实网络）。
  /// 注入后所有 _request 走该客户端（widget 测试在 fakeAsync 中无法驱动
  /// dart:io 真实 IO，官方建议注入 HttpClient 实现）；生产行为不变 ——
  /// 未注入时每次新建 IO 客户端，与 http.get/post 静态快捷方法等价。
  http.Client? httpClientOverride;

  /// 共享 HTTP 客户端（keep-alive 连接池）：
  /// 此前每请求新建 Client 用完即关 —— 每次都重新 TCP+TLS 握手，
  /// 信息流（列表+批量签名+头像签名）密集请求下延迟/耗电放大。
  /// host 变更（configure 换域名）时旧连接池废弃重建；httpClientOverride 优先。
  http.Client? _sharedClient;
  String? _sharedClientHost;

  http.Client _shared() {
    final String host = Uri.parse(baseUrl ?? '').host;
    if (_sharedClient != null && _sharedClientHost != host) {
      _sharedClient!.close();
      _sharedClient = null;
    }
    return _sharedClient ??= () {
      _sharedClientHost = host;
      return http.Client();
    }();
  }

  /// JWT AccessToken（Authorization: Bearer）
  String? token;

  bool get isConfigured => (baseUrl ?? '').isNotEmpty;

  void configure({required String baseUrl, String? token}) {
    this.baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    this.token = token;
  }

  // ── 统一请求 ────────────────────────────────────────────
  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    if (!isConfigured) {
      throw const ApiException('云端服务未配置');
    }
    final Uri uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final http.Request req = http.Request(method, uri)
      ..headers.addAll(_jsonHeaders);
    if (body != null) req.body = jsonEncode(body);
    final http.Client client = httpClientOverride ?? _shared();
    late http.Response res;
    try {
      // GET/POST/PATCH 统一走 Request.send（method 原样发出；PATCH 必须真发 PATCH）
      // 超时兜底：连接+读响应各 15s，防止服务端失联时请求永久挂起
      // （曾导致置顶/取消置顶后 _topBusy、_loadingPosts 永久锁死、无限转圈）
      const Duration timeout = Duration(seconds: 15);
      final http.StreamedResponse streamed =
          await client.send(req).timeout(timeout);
      res = await http.Response.fromStream(streamed).timeout(timeout);
    } on SocketException {
      throw const ApiException('网络不可用，请检查网络后重试');
    } on TimeoutException {
      throw const ApiException('请求超时，请稍后重试');
    }
    // 共享客户端/注入客户端均不在此关闭：共享池跨请求复用（keep-alive），
    // 注入客户端由调用方管理生命周期
    if (res.statusCode == 401) {
      // 401 统一态：优先透传后端业务 msg（密码登录的「账号或密码错误」/「账号不存在，
      // 请使用短信/邮箱注册」/「该账号未设置密码」等），解析失败回退默认登录态文案；
      // token 失效场景后端 msg 本就是「登录已失效，请重新登录」，行为不变
      String msg = '登录已失效，请重新登录';
      try {
        final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final m = (j['msg'] as String?) ?? '';
        if (m.isNotEmpty) msg = m;
      } catch (_) {}
      throw ApiException(msg, 401);
    }
    if (res.statusCode == 429) {
      throw const ApiException('操作过于频繁，请稍后再试', 429);
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('服务响应异常（HTTP ${res.statusCode}）');
    }
    if (j['code'] != 0 && j['code'] != 200) {
      // 双后端兼容：grandblue-server v2.7 成功码 = 0；Flash 后端（第一轮联调）成功码 = 200
      throw ApiException((j['msg'] as String?) ?? '请求失败', res.statusCode);
    }
    return j['data'];
  }

  Map<String, String> get _jsonHeaders => <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── OSS 直传（v2.6.1：带声明参数，后端 PutObject 之前校验）──
  /// 上传图片：put-sign（ext/size 声明）→ PUT 二进制直传 → 返回对象 key
  /// [fileBytes] 建议先过 compressImage（长边 2048 / ≤5MB 目标）。
  ///
  /// v2.9.3：POST Form → PUT 二进制（服务端签名 Authorization/Date/Content-Type），
  /// 规避 multipart 报文畸形 MalformedPOSTRequest（http 包安卓端换行符问题）。
  Future<String> uploadImage(List<int> fileBytes, {required String ext}) async {
    // 2026-11-19 排障日志：失败分类（risk限流/IP频控/超时/签名/文件校验/其他）
    // 只做异常包装与时间戳记录，上传逻辑本身不变；composer 侧消费结构化信息。
    final int signAt = DateTime.now().millisecondsSinceEpoch;
    Map<String, dynamic> data;
    try {
      data = await _request('GET', '/api/oss/put-sign', query: <String, String>{
        'type': 'ugc',
        'media': 'image',
        'ext': ext,
        'size': '${fileBytes.length}',
      }) as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw _classifyImageFailure(e, 'put_sign', putSignAt: signAt);
    }
    final int putStart = DateTime.now().millisecondsSinceEpoch;
    try {
      return await _putObject(OssPutSign.fromJson(data), fileBytes);
    } on ApiException catch (e) {
      throw _classifyImageFailure(e, 'put_oss',
          putSignAt: signAt, putStartAt: putStart);
    } catch (e) {
      throw ImageUploadFailure('put_oss', 'network', 'OSS 直传异常：$e',
          putSignAt: signAt, putStartAt: putStart);
    }
  }

  /// 把上传链路的 ApiException 归类为结构化失败（不改变异常语义/行为）：
  /// - put_sign 阶段：「操作过于频繁」= risk.js 用户每分钟配额（JSON code!=0 429）；
  ///   「服务响应异常（HTTP 429/403）」= WAF/ESA/nginx 层非 JSON 拦截；
  ///   401 = 登录态失效（签名未拿到）
  /// - put_oss 阶段：OSS XML <Code> 精确归类（SignatureDoesNotMatch=签名失效 /
  ///   EntityTooLarge / InvalidArgument=文件校验 / RequestTimeout=超时 等）
  ImageUploadFailure _classifyImageFailure(ApiException e, String stage,
      {int? putSignAt, int? putStartAt}) {
    final m = e.message;
    String ft;
    if (stage == 'put_sign') {
      if (m.contains('操作过于频繁')) {
        ft = 'risk_limit';
      } else if (m.contains('服务响应异常（HTTP 429') ||
          m.contains('服务响应异常（HTTP 403')) {
        ft = 'ip_freq_waf';
      } else if (m.contains('不支持的图片格式') || m.contains('仅支持')) {
        ft = 'file_validate'; // put-sign 后端 ext 白名单校验
      } else if (m.contains('超过大小上限') || m.contains('文件过大')) {
        ft = 'file_validate';
      } else if (m.contains('超时')) {
        ft = 'timeout';
      } else if (m.contains('网络不可用')) {
        ft = 'network';
      } else if (e.code == 401) {
        ft = 'auth_expired';
      } else {
        ft = 'other';
      }
      return ImageUploadFailure(stage, ft, m, httpStatus: e.code,
          putSignAt: putSignAt, putStartAt: putStartAt);
    }
    // put_oss：OSS XML 响应按 <Code> 归类
    final codeMatch = RegExp(r'<Code>([^<]+)</Code>').firstMatch(m);
    final ossCode = codeMatch?.group(1);
    if (ossCode != null) {
      ft = switch (ossCode) {
        'SignatureDoesNotMatch' || 'AccessDenied' => 'sign_invalid',
        'RequestTimeout' => 'timeout',
        'EntityTooLarge' || 'InvalidArgument' => 'file_validate',
        _ => 'oss_$ossCode',
      };
    } else if (m.contains('超时')) {
      ft = 'timeout';
    } else if (m.contains('大小上限')) {
      ft = 'file_validate';
    } else if (m.contains('网络异常')) {
      ft = 'network';
    } else {
      ft = 'other';
    }
    return ImageUploadFailure(stage, ft, m,
        httpStatus: e.code, ossResponse: m, putSignAt: putSignAt,
        putStartAt: putStartAt);
  }

  /// 上传视频（仅白名单用户）：put-sign（ext/size/duration 声明）→ PUT 流式直传。
  /// [file] 必须是 prepareVideoForUpload 的转码产物（mp4 + H.264 + AAC）。
  /// v2.9.12：改为文件流式上传（openRead 边读边发），不再整体 readAsBytes 载入内存。
  Future<String> uploadVideo(File file,
      {required String ext, required int durationSec}) async {
    final int size = await file.length();
    final data = await _request('GET', '/api/oss/put-sign', query: <String, String>{
      'type': 'ugc',
      'media': 'video',
      'ext': ext,
      'size': '$size',
      'duration': '$durationSec',
    }) as Map<String, dynamic>;
    return _putObjectStream(OssPutSign.fromJson(data), file, size);
  }

  /// OSS PUT 直传（v2.9.3，替代 POST Form / _postObject）：
  /// - 无 multipart 表单 → 不存在 boundary/换行符格式问题（MalformedPOSTRequest 根因）
  /// - host/key/contentType/date/authorization 全部服务端下发，客户端只透传
  /// - key 服务端生成，杜绝客户端越权路径
  /// - 全链路 debugPrint 调试日志（headers/statusCode/body/异常堆栈，release 静默）
  Future<String> _putObject(OssPutSign s, List<int> bytes) async {
    if (bytes.length > s.maxSize) {
      throw ApiException('文件超过大小上限（${s.maxSize} 字节），请压缩后重试');
    }
    final Uri uri = Uri.parse('${s.host}/${s.key}');

    _ossDebug('PUT $uri');
    _ossDebug('headers: Date="${s.date}" Content-Type="${s.contentType}" '
        'Authorization="${s.authorization.substring(0, s.authorization.length.clamp(0, 24))}…" '
        'bytes=${bytes.length}');

    final http.Request req = http.Request('PUT', uri)
      ..headers['Authorization'] = s.authorization // ⚠️ 原样回传，已参与服务端签名
      ..headers['Date'] = s.date // ⚠️ 原样回传（服务端时间，免设备时钟偏差）
      ..headers['Content-Type'] = s.contentType // ⚠️ 已参与签名，不可改
      ..headers['Content-Length'] = '${bytes.length}'
      ..bodyBytes = bytes; // body = 纯二进制，无表单

    try {
      final http.StreamedResponse res = await _shared().send(req);
      // PUT 成功 200 空体（ETag 头）/ 失败为 XML —— 统一读出便于日志与透出
      final String body = await res.stream.bytesToString();
      _ossDebug('statusCode = ${res.statusCode}');
      if (body.isNotEmpty) _ossDebug('response body =\n$body');
      if (res.statusCode >= 300) {
        // OSS 失败时返回 XML（<Code>SignatureDoesNotMatch</Code> 等），完整透出
        throw ApiException('OSS 直传失败（HTTP ${res.statusCode}）：$body');
      }
      return s.key;
    } on ApiException {
      rethrow; // 业务异常原样上抛（含 OSS XML），不吞不二次包装
    } catch (e, st) {
      // 网络/底层异常（SocketException / HandshakeException 等）：打堆栈单独定位
      _ossDebug('EXCEPTION: $e\n$st');
      throw ApiException('OSS 直传网络异常：$e');
    }
  }

  /// OSS PUT 流式直传（视频专用，v2.9.12）：
  /// 与 [_putObject] 签名头同口径（Authorization/Date/Content-Type 原样回传），
  /// 但 body 用 file.openRead() 流式灌包 —— 大文件不整体进内存。
  /// 视频体积小、上传慢（蜂窝网络 30MB 可能数十秒），超时放宽到 120s。
  Future<String> _putObjectStream(OssPutSign s, File file, int size) async {
    if (size > s.maxSize) {
      throw ApiException('文件超过大小上限（${s.maxSize} 字节），请压缩后重试');
    }
    final Uri uri = Uri.parse('${s.host}/${s.key}');
    _ossDebug('PUT(stream) $uri bytes=$size');

    final http.StreamedRequest req = http.StreamedRequest('PUT', uri)
      ..headers['Authorization'] = s.authorization // ⚠️ 原样回传，已参与服务端签名
      ..headers['Date'] = s.date // ⚠️ 原样回传（服务端时间，免设备时钟偏差）
      ..headers['Content-Type'] = s.contentType // ⚠️ 已参与签名，不可改
      ..headers['Content-Length'] = '$size';

    // 边读边发；读文件出错/取消时关 sink，避免请求悬挂
    file.openRead().listen(
          req.sink.add,
          onDone: () => req.sink.close(),
          onError: (Object e) => req.sink.close(),
          cancelOnError: true,
        );

    try {
      final http.StreamedResponse res =
          await _shared().send(req).timeout(const Duration(seconds: 120));
      final String body = await res.stream.bytesToString();
      _ossDebug('statusCode = ${res.statusCode}');
      if (body.isNotEmpty) _ossDebug('response body =\n$body');
      if (res.statusCode >= 300) {
        throw ApiException('OSS 直传失败（HTTP ${res.statusCode}）：$body');
      }
      return s.key;
    } on ApiException {
      rethrow;
    } catch (e, st) {
      _ossDebug('EXCEPTION: $e\n$st');
      throw ApiException('OSS 直传网络异常：$e');
    }
  }

  /// OSS PUT 直传调试日志（与 _debugLogUserList 同规范：release 包静默）──
  // debugPrint 本身不被 release tree-shake，必须显式 kReleaseMode 守卫
  // （日志含 OSS URL / Authorization 前缀 / 错误 XML，不能进 release logcat）
  static void _ossDebug(String msg) {
    if (kReleaseMode) return;
    debugPrint('[oss-direct] $msg');
  }

  // ── 发帖（v2.6.1：多图 attachUrls / 视频 duration；v2.9.2：+island/tags）──
  /// [island] 后端枚举 key（clear-mind/quit-smoke/fitness/early-sleep，可空）
  /// [tags] 标签数组（后端白名单校验 + 自动去 # 前缀，≤7 个）
  Future<Map<String, dynamic>> createPost({
    required String type, // text | image | video
    String? content,
    List<String>? attachKeys,
    int? durationSec,
    String? island,
    List<String>? islands, // v2.9.3 多岛屿分发（勾选几个传几个，≤4）
    List<String>? tags,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'type': type};
    if (content != null && content.isNotEmpty) body['content'] = content;
    if (attachKeys != null && attachKeys.isNotEmpty) {
      if (attachKeys.length == 1) {
        body['attachUrl'] = attachKeys.first;
      } else {
        body['attachUrls'] = attachKeys;
      }
    }
    if (durationSec != null) body['duration'] = durationSec;
    if (island != null && island.isNotEmpty) body['island'] = island;
    if (islands != null && islands.isNotEmpty) body['islands'] = islands;
    if (tags != null && tags.isNotEmpty) body['tags'] = tags;
    return (await _request('POST', '/api/posts', body: body))
        as Map<String, dynamic>;
  }

  // ── 时效签名（v2.6 防爬：只换 attachKey，不持有永久直链）──
  /// 批量换取帖子附件的 900s 时效签名 URL（≤30 帖/批）。
  /// 返回 postId → 签名结果；missing 的帖子（未过审/已清理/无权限）不在返回里。
  Future<Map<int, SignedPostMedia>> signMedia(List<int> postIds) async {
    final data = await _request('POST', '/api/media/sign', body: <String, dynamic>{
      'postIds': postIds,
    }) as Map<String, dynamic>;
    final Map<int, SignedPostMedia> out = <int, SignedPostMedia>{};
    final urls = (data['urls'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    urls.forEach((postId, v) {
      final int? id = int.tryParse(postId);
      if (id == null) return; // 异常 key 防御：跳过，不炸渲染链路
      final m = v as Map<String, dynamic>;
      out[id] = SignedPostMedia(
        urls: (m['urls'] as List<dynamic>).cast<String>(),
        expiresAt: m['expiresAt'] as int,
      );
    });
    return out;
  }

  // ════════════════════════════════════════════════════════
  // v2.7 P0 港口流 / 帖子详情（对接 /api/post/* 全套接口）
  // 异常约定：401 未登录/token 失效；403 权限/风控锁定；
  //          404 帖子不存在·作者被拉黑·审核不通过（统一 404）；
  //          429 限流 —— 统一由 [_request] 抛 ApiException(code)
  // ════════════════════════════════════════════════════════

  /// 瀑布流列表（GET /api/post/list）
  /// [islandKey] 后端枚举：all/fitness/quit-smoke/early-sleep/clear-mind
  /// （本地 Island.id → 后端 key 用 [kCloudIslandKeys] 映射）
  /// [tag] 标签筛选（清心岛/戒烟岛/健身岛/早睡岛/日更/新船员/妙招/装备党，
  /// 后端自动兼容带 #/不带 #）；[sort] latest 最新时序 | hot 热度；[size] 上限 20
  Future<PagedPosts> fetchPostList({
    String islandKey = 'all',
    String? tag,
    String sort = 'latest',
    int page = 1,
    int size = 10,
  }) async {
    final data = await _request('GET', '/api/post/list', query: <String, String>{
      'island': islandKey,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      'sort': sort,
      'page': '$page',
      'size': '$size',
    }) as Map<String, dynamic>;
    return PagedPosts.fromJson(data);
  }

  /// 帖子详情（GET /api/post/:postId）。
  /// 不存在/被拉黑/未过审 → ApiException('帖子不存在', 404)
  Future<CloudPost> fetchPostDetail(int postId) async {
    final data = await _request('GET', '/api/post/$postId') as Map<String, dynamic>;
    return CloudPost.fromJson(data);
  }

  /// 评论分页（GET /api/post/:postId/comments，时间正序）
  Future<PagedComments> fetchComments(int postId, {int page = 1, int size = 10}) async {
    final data = await _request('GET', '/api/post/$postId/comments',
        query: <String, String>{'page': '$page', 'size': '$size'}) as Map<String, dynamic>;
    return PagedComments.fromJson(data);
  }

  /// 点赞 / 取消点赞（POST /api/post/:postId/like，幂等 toggle）
  Future<LikeResult> toggleLike(int postId) async {
    final data = await _request('POST', '/api/post/$postId/like') as Map<String, dynamic>;
    return LikeResult.fromJson(data);
  }

  /// 拉黑用户（POST /api/user/block）。幂等；创始人不可被拉黑（403）
  Future<bool> blockUser(int targetUid) async {
    final data = await _request('POST', '/api/user/block',
        body: <String, dynamic>{'targetUid': targetUid}) as Map<String, dynamic>;
    return (data['blocked'] as bool?) ?? true;
  }

  /// 提交举报（POST /api/report）。[type] = post | comment
  /// 返回 reportId；重复举报（24h 内同目标）返回已有 id + duplicated=true
  Future<ReportResult> submitReport({
    required String type,
    required int targetId,
    required String reason,
  }) async {
    final data = await _request('POST', '/api/report', body: <String, dynamic>{
      'type': type,
      'targetId': targetId,
      'reason': reason,
    }) as Map<String, dynamic>;
    return ReportResult.fromJson(data);
  }

  /// 热门标签（GET /api/tag/list，按出现帖数降序）
  Future<List<TagStat>> fetchHotTags() async {
    final data = await _request('GET', '/api/tag/list') as Map<String, dynamic>;
    return ((data['list'] as List<dynamic>?) ?? const [])
        .map((e) => TagStat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 发表评论（POST /api/posts/:postId/comment —— v2.6 既有接口，
  /// v2.7 补客户端方法；文本送审失败 403 / 未登录 401 由 [_request] 抛出）
  /// v2.9.7：[replyToCommentId] 非空 = 子评论；[atUserIds] = @预埋（不触发通知）。
  /// 返回新评论 + 帖子评论总数。
  Future<({CloudComment comment, int commentCount})> createComment(
    int postId,
    String content, {
    int? replyToCommentId,
    List<int> atUserIds = const [],
  }) async {
    final data = await _request('POST', '/api/posts/$postId/comment',
        body: <String, dynamic>{
          'content': content,
          'replyToCommentId': ?replyToCommentId,
          if (atUserIds.isNotEmpty) 'atUserIds': atUserIds,
        }) as Map<String, dynamic>;
    return (
      comment: CloudComment.fromJson(data['comment'] as Map<String, dynamic>),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  // ── v2.9.7 评论系统 v2 ────────────────────────────────────

  /// 删除日志（DELETE /api/posts/:postId，仅作者；后端级联清评论/点赞/举报）
  Future<void> deletePost(int postId) async {
    await _request('DELETE', '/api/posts/$postId');
  }

  /// v2.9.8 置顶/取消置顶（PATCH /api/posts/:postId/top，仅作者；
  /// 置顶 true 时后端同事务自动清该用户其他帖的置顶，单用户最多 1 条）
  Future<void> setPostTop(int postId, {required bool isTop}) async {
    await _request('PATCH', '/api/posts/$postId/top', body: <String, dynamic>{
      'isTop': isTop,
    });
  }

  /// v2.9.8 批量删除（POST /api/posts/batch-delete，仅本人帖子；
  /// 任一 id 不存在或非本人 → 403 不部分删除）。返回实际删除条数
  Future<int> batchDeletePosts(List<int> postIds) async {
    final data = await _request('POST', '/api/posts/batch-delete',
        body: <String, dynamic>{'postIds': postIds}) as Map<String, dynamic>;
    return (data['deleted'] as num?)?.toInt() ?? 0;
  }

  /// 子评论分页（GET /api/comments/:commentId/replies，时间正序）
  Future<PagedComments> fetchReplies(int commentId, {int page = 1, int size = 10}) async {
    final data = await _request('GET', '/api/comments/$commentId/replies',
        query: <String, String>{'page': '$page', 'size': '$size'}) as Map<String, dynamic>;
    return PagedComments.fromJson(data);
  }

  /// 评论点赞 toggle（POST /api/comments/:commentId/like）
  Future<LikeResult> toggleCommentLike(int commentId) async {
    final data = await _request('POST', '/api/comments/$commentId/like') as Map<String, dynamic>;
    return LikeResult.fromJson(data);
  }

  /// 删除评论（DELETE /api/comments/:commentId）。
  /// 权限：评论本人 / 帖子作者 / 父一级评论作者；删一级评论连带全部子评论。
  /// 返回本帖剩余评论总数。
  Future<int> deleteComment(int commentId) async {
    final data = await _request('DELETE', '/api/comments/$commentId') as Map<String, dynamic>;
    return (data['commentCount'] as num?)?.toInt() ?? 0;
  }

  /// @用户搜索（GET /api/users/search?q=，昵称模糊，排除自己/拉黑，≤10 条）
  /// [includeClosed]=true 时返回已注销用户（closed:true）——仅供正文/评论 @提及
  /// 点击回查用（命中 closed 前端静默不跳转）；@用户选择弹窗不得传（closed 不被搜索）
  Future<List<CloudUserSearchItem>> searchUsers(String query,
      {bool includeClosed = false}) async {
    if (query.trim().isEmpty) return const [];
    final data = await _request('GET', '/api/users/search',
        query: <String, String>{
          'q': query.trim(),
          if (includeClosed) 'includeClosed': '1',
        }) as Map<String, dynamic>;
    return ((data['list'] as List<dynamic>?) ?? const [])
        .map((e) => CloudUserSearchItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 裸 key 签名（POST /api/media/sign 的 keys 参数，≤10 个/批）——
  /// 头像等非帖子绑定资源的渲染专用（coverKey 走 [signMedia]）。
  /// 返回 key → SignedKeyMedia；invalid（非法 key）不在返回里。
  Future<Map<String, SignedKeyMedia>> signKeys(List<String> keys) async {
    if (keys.isEmpty) return const {};
    final data = await _request('POST', '/api/media/sign', body: <String, dynamic>{
      'keys': keys,
    }) as Map<String, dynamic>;
    final signed = (data['signedKeys'] as Map<String, dynamic>?) ?? const {};
    return signed.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(
        k,
        SignedKeyMedia(
          url: m['url'] as String,
          expiresAt: (m['expiresAt'] as num).toInt(),
        ),
      );
    });
  }

  // ════════════════════════════════════════════════════════
  // 第一轮前后端联调（Flash 后端，统一 code=200 成功）
  // 链路：短信登录 → 用户信息 → 云端打卡 → 登出
  // 异常约定：400 参数错误 · 401 token无效/过期/未登录 · 403 权限拒绝
  //          409 业务冲突（重复打卡/验证码错误）· 429 限流（发码频繁）
  // 401 由 UI 层统一执行登出（清本地状态 → 船长闸门重新生效）
  // ════════════════════════════════════════════════════════

  /// 发送短信验证码（POST /api/sms/code）。
  /// 60s/次 冷却（429）；[purpose] 默认 login（手机号不存在自动注册）；
  /// reset=找回密码重置（账号不存在直接报错，不建号）。验证码 5 分钟有效。
  Future<void> sendSmsCode(String phone, {String purpose = 'login'}) async {
    await _request('POST', '/api/sms/code',
        body: <String, dynamic>{'phone': phone, 'purpose': purpose});
  }

  /// 短信验证码登录（POST /api/login/sms）。
  /// 成功后经 [onAuthenticated] 回调落 SessionStore（持久化 + token 即时生效），
  /// 返回云端船长档案供 UI 写入本地登录态。
  Future<CloudCaptain> loginBySms(String phone, String code) async {
    final data = await _request('POST', '/api/login/sms',
        body: <String, dynamic>{'phone': phone, 'code': code}) as Map<String, dynamic>;
    final token = (data['token'] as String?) ?? '';
    final captain = CloudCaptain.fromJson((data['captain'] as Map<String, dynamic>?) ?? const {});
    await onAuthenticated?.call(token, ''); // Flash 后端本轮无 refreshToken
    return captain;
  }

  /// 当前登录用户信息（GET /api/user/me）。
  /// App 冷启动/页面恢复时校验 token 并刷新用户档案；401 → UI 层自动登出。
  Future<CloudCaptain> fetchMe() async {
    final data = await _request('GET', '/api/user/me') as Map<String, dynamic>;
    return CloudCaptain.fromJson(data);
  }

  /// 登出（POST /api/logout，吊销当前 token 加入黑名单）。
  /// 成功或失败都不阻塞 —— UI 层收到结果后一律清空本地状态。
  Future<void> logout() async {
    try {
      await _request('POST', '/api/logout');
    } on ApiException catch (e) {
      // token 已失效（401）视为登出成功；其他错误向上抛由 UI 决定
      if (e.code != 401) rethrow;
    }
  }

  /// 岛屿打卡数据（GET /api/user/island/:islandId，[islandKey] 见 kCloudCheckinKeys）。
  /// 连续天数/征服判定全部后端计算，前端只展示。
  Future<IslandCheckinData> fetchIslandCheckin(String islandKey) async {
    final data = await _request('GET', '/api/user/island/$islandKey') as Map<String, dynamic>;
    return IslandCheckinData.fromJson(data);
  }

  // ── 岛屿页 Banner + 支付（AGENTS.md §13 支付契约）──────────

  static const String _bannerCacheKey = 'banner_cache_v1';
  static const Duration _bannerCacheTtl = Duration(minutes: 10);

  /// Banner 卡片列表（GET /api/banners，游客可读）。
  /// 本地 10 分钟短缓存：命中直接返回；[forceRefresh]=true（下拉刷新）强制拉取。
  /// 网络失败回退缓存（无论是否过期）；缓存也无 → 返回 AppBanner.fallback。
  Future<List<BannerItem>> fetchBanners({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? cache;
    try {
      final raw = prefs.getString(_bannerCacheKey);
      if (raw != null) cache = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      cache = null;
    }
    final cachedAt = (cache?['t'] as num?)?.toInt() ?? 0;
    final fresh = DateTime.now().millisecondsSinceEpoch - cachedAt < _bannerCacheTtl.inMilliseconds;
    List<BannerItem> parseCache() {
      final list = (cache?['list'] as List?) ?? const [];
      return list.map((e) => BannerItem.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (!forceRefresh && cache != null && fresh) return parseCache();
    try {
      final data = await _request('GET', '/api/banners') as List<dynamic>;
      final list = data.map((e) => BannerItem.fromJson(e as Map<String, dynamic>)).toList();
      await prefs.setString(
          _bannerCacheKey,
          jsonEncode(<String, dynamic>{
            't': DateTime.now().millisecondsSinceEpoch,
            'list': data,
          }));
      return list;
    } catch (_) {
      // 网络失败：有缓存用缓存（哪怕过期），没有用内置兜底卡片
      if (cache != null && (cache['list'] as List?)?.isNotEmpty == true) return parseCache();
      return BannerItem.fallback;
    }
  }

  /// 支持开发者预下单（POST /api/pay/reward，档位白名单硬校验在后端）
  Future<PayOrderResult> createRewardOrder(String amount) async {
    final data = await _request('POST', '/api/pay/reward', body: <String, dynamic>{'amount': amount})
        as Map<String, dynamic>;
    return PayOrderResult.fromJson(data);
  }

  /// 查订单状态（GET /api/pay/order/:outTradeNo）→ UNPAID / PAID / CLOSED / REFUNDED
  Future<String> fetchOrderStatus(String outTradeNo) async {
    final data = await _request('GET', '/api/pay/order/$outTradeNo') as Map<String, dynamic>;
    return (data['status'] as String?) ?? 'UNPAID';
  }

  /// Apple IAP 预下单（POST /api/pay/apple/order，仅 iOS 调用；productId 白名单与金额映射在服务端）
  /// 返回 outTradeNo（本地 UNPAID 单，pay_type='apple_iap'）与 amount（服务端映射金额）
  Future<PayOrderResult> createAppleIapOrder(String productId) async {
    final data = await _request('POST', '/api/pay/apple/order', body: <String, dynamic>{'productId': productId})
        as Map<String, dynamic>;
    return PayOrderResult.fromJson(data);
  }

  /// Apple IAP 收据验签（POST /api/pay/apple/verify，仅 iOS 调用）
  /// [outTradeNo] 正常购买传（强校验归属）；恢复购买/补单场景省略（后端按
  /// 该用户最近一笔同商品 UNPAID IAP 单定位）。返回订单状态（PAID）。
  Future<String> verifyAppleIapReceipt({String? outTradeNo, required String receipt}) async {
    final data = await _request('POST', '/api/pay/apple/verify', body: <String, dynamic>{
      ?outTradeNo: outTradeNo,
      'receipt': receipt,
    }) as Map<String, dynamic>;
    return (data['status'] as String?) ?? 'PAID';
  }

  /// 修改昵称（PATCH /api/user/nickname，v1.1：仅自身）。
  /// [nickname] 传 null 表示清空（后端把空串/全空格也清洗为 null 入库）。
  /// 超长/非法 → ApiException('昵称长度需要在1-12字符之间')。
  Future<({int uid, String? nickname})> updateNickname(String? nickname) async {
    final data = await _request('PATCH', '/api/user/nickname',
        body: <String, dynamic>{'nickname': nickname}) as Map<String, dynamic>;
    return (
      uid: (data['uid'] as num?)?.toInt() ?? 0,
      nickname: data['nickname'] as String?,
    );
  }

  /// 更新个人资料（POST /api/user/profile，v2.9.4 头像/昵称统一入口；v2.9.6 +bio）。
  /// [avatar] 传 OSS 对象 key（put-sign 直传产物）；后端二次校验大小/类型 +
  /// Green 图片审核，违规/异常 → ApiException（403 违规 / 400 校验失败 / 500 服务异常）。
  /// [nickname]/[bio] 可选；三者至少传一个（后端校验）。bio ≤100 字，空串=清空。
  Future<({String? nickname, String? avatar, String? bio})> updateProfile(
      {String? avatar, String? nickname, String? bio}) async {
    final body = <String, dynamic>{};
    if (avatar != null) body['avatar'] = avatar;
    if (nickname != null) body['nickname'] = nickname;
    if (bio != null) body['bio'] = bio;
    final data = await _request('POST', '/api/user/profile',
        body: body) as Map<String, dynamic>;
    return (
      nickname: data['nickname'] as String?,
      avatar: data['avatar'] as String?,
      bio: data['bio'] as String?,
    );
  }

  // ════════════════════════════════════════════════════════
  // v2.9.6 社交关系与个人主页（关注/粉丝/黑名单/航级占位）
  // 异常约定：404 用户不存在·双向拉黑；403 拉黑互动拦截；401 未登录
  // ════════════════════════════════════════════════════════

  /// 关注/取关（POST /api/user/follow，幂等 toggle）。
  /// 任一方拉黑对方 → 403「无法关注该用户」；成功后记得同步 FollowState
  Future<FollowResult> followUser(int targetUid) async {
    final data = await _request('POST', '/api/user/follow',
        body: <String, dynamic>{'targetUid': targetUid}) as Map<String, dynamic>;
    return FollowResult.fromJson(data);
  }

  /// 关注状态查询（GET /api/user/follow-status?targetUid=N）
  Future<FollowStatus> fetchFollowStatus(int targetUid) async {
    final data = await _request(
        'GET', '/api/user/follow-status',
        query: <String, String>{'targetUid': '$targetUid'}) as Map<String, dynamic>;
    return FollowStatus.fromJson(data);
  }

  /// 粉丝列表分页（GET /api/user/:uid/followers）
  Future<PagedUsers> fetchFollowers(int uid, {int page = 1, int size = 20}) async {
    final data = await _request('GET', '/api/user/$uid/followers',
        query: <String, String>{'page': '$page', 'size': '$size'}) as Map<String, dynamic>;
    _debugLogUserList('followers', data);
    return PagedUsers.fromJson(data);
  }

  /// 关注列表分页（GET /api/user/:uid/following）
  Future<PagedUsers> fetchFollowing(int uid, {int page = 1, int size = 20}) async {
    final data = await _request('GET', '/api/user/$uid/following',
        query: <String, String>{'page': '$page', 'size': '$size'}) as Map<String, dynamic>;
    _debugLogUserList('following', data);
    return PagedUsers.fromJson(data);
  }

  /// DEBUG：打印关注/粉丝列表原始 JSON（release 包自动剔除）
  static void _debugLogUserList(String tag, Map<String, dynamic> data) {
    if (kReleaseMode) return;
    debugPrint('[FollowList][$tag] raw = $data');
  }

  /// 他人主页/自身公开预览（GET /api/user/:uid/profile）。
  /// 双向拉黑/用户不存在 → ApiException('用户不存在', 404)
  Future<CloudUserProfile> fetchUserProfile(int uid) async {
    final data = await _request('GET', '/api/user/$uid/profile') as Map<String, dynamic>;
    return CloudUserProfile.fromJson(data);
  }

  /// 当前用户支持者徽章持有状态（GET /api/user/badge）。
  /// 纯纪念装饰标记；未持有/网络失败 → has:false（徽章缺失不影响船长页其余内容）
  /// 含 totalSupported（本人累计支持，仅自己详情页展示）
  Future<CloudSupporterBadge> fetchSupporterBadge() async {
    try {
      final data = await _request('GET', '/api/user/badge') as Map<String, dynamic>;
      return CloudSupporterBadge.fromJson(data);
    } catch (_) {
      return CloudSupporterBadge.none;
    }
  }

  /// 他人支持者徽章持有状态（GET /api/user/:uid/badge）。
  /// ⚠️ 后端不下发 totalSupported（隐私保护：累计金额仅本人可见），
  /// 返回值 totalSupported 恒为 0；未持有/网络失败 → has:false
  Future<CloudSupporterBadge> fetchUserBadge(int uid) async {
    try {
      final data = await _request('GET', '/api/user/$uid/badge') as Map<String, dynamic>;
      return CloudSupporterBadge.fromJson(data);
    } catch (_) {
      return CloudSupporterBadge.none;
    }
  }

  /// 某用户发布的日志列表分页（GET /api/user/:uid/posts，只含 pass 帖）
  Future<PagedPosts> fetchUserPosts(int uid, {int page = 1, int size = 10}) async {
    final data = await _request('GET', '/api/user/$uid/posts',
        query: <String, String>{'page': '$page', 'size': '$size'}) as Map<String, dynamic>;
    return PagedPosts.fromJson(data);
  }

  /// 当前用户点赞的日志列表分页（GET /api/user/liked-posts）。
  /// 后端自动剔除双向拉黑用户的帖子（点赞列表专用过滤）
  Future<PagedPosts> fetchLikedPosts({int page = 1, int size = 10}) async {
    final data = await _request('GET', '/api/user/liked-posts',
        query: <String, String>{'page': '$page', 'size': '$size'}) as Map<String, dynamic>;
    return PagedPosts.fromJson(data);
  }

  /// 解除拉黑（POST /api/user/unblock，幂等；不恢复拉黑前的关注/粉丝关系）
  Future<void> unblockUser(int targetUid) async {
    await _request('POST', '/api/user/unblock',
        body: <String, dynamic>{'targetUid': targetUid});
  }

  /// 黑名单列表分页（GET /api/user/blocklist）
  Future<PagedUsers> fetchBlocklist({int page = 1, int size = 20}) async {
    final data = await _request('GET', '/api/user/blocklist',
        query: <String, String>{'page': '$page', 'size': '$size'}) as Map<String, dynamic>;
    return PagedUsers.fromJson(data);
  }

  /// 提交当日打卡（POST /api/user/island/:islandId/checkin，以服务器日期为准）。
  /// 重复打卡 → ApiException('今日已经打卡，明天再来', 409)。
  Future<CloudCheckinResult> cloudCheckin(String islandKey) async {
    final data = await _request('POST', '/api/user/island/$islandKey/checkin')
        as Map<String, dynamic>;
    return CloudCheckinResult.fromJson(data);
  }

  /// 人机验证挑战（GET /api/captcha/challenge）—— 邮箱发码强制要求。
  /// 返回 captchaId + 算术题 question；challenge 一次性，验证/过期后需重取。
  Future<({String captchaId, String question})> fetchCaptchaChallenge() async {
    final data = await _request('GET', '/api/captcha/challenge') as Map<String, dynamic>;
    return (
      captchaId: (data['captchaId'] as String?) ?? '',
      question: (data['question'] as String?) ?? '',
    );
  }

  /// 发送邮箱验证码（POST /api/email/code）。
  /// 强制人机验证（captchaId+Answer 必填）+ 临时邮箱拦截 + 单邮箱 3 条/h、单 IP 10 条/h。
  /// 邮箱不存在 → 后端自动创建账号（凭证隔离，不与手机号账号合并）。
  /// [purpose] 默认 login；reset=找回密码（后端豁免 captcha，账号不存在报错不建号）。
  Future<void> sendEmailCode(String email, String captchaId, String captchaAnswer,
      {String purpose = 'login'}) async {
    await _request('POST', '/api/email/code', body: <String, dynamic>{
      'email': email,
      'captchaId': captchaId,
      'captchaAnswer': captchaAnswer,
      'purpose': purpose,
    });
  }

  /// 邮箱验证码登录（POST /api/email/login）。
  /// 出参与短信登录完全一致；token 自动落 SessionStore，返回云端船长档案。
  Future<CloudCaptain> loginByEmail(String email, String code) async {
    final data = await _request('POST', '/api/email/login',
        body: <String, dynamic>{'email': email, 'code': code}) as Map<String, dynamic>;
    final token = (data['token'] as String?) ?? '';
    final captain = CloudCaptain.fromJson((data['captain'] as Map<String, dynamic>?) ?? const {});
    await onAuthenticated?.call(token, '');
    return captain;
  }

  /// 密码登录（POST /api/login，v2.9.9 联调）。
  /// account 支持：手机号（11位）/ 邮箱 / 账号ID（纯数字 uid，后端按 users.id 查；
  /// 不存在的 uid 返回「账号不存在，请使用短信/邮箱注册」）。
  /// 成功返回 token+refreshToken（grandblue 双 token，落 SessionStore），user 为 buildProfile 档案。
  Future<CloudCaptain> loginByPassword(String account, String password) async {
    final data = await _request('POST', '/api/login',
        body: <String, dynamic>{'account': account, 'password': password}) as Map<String, dynamic>;
    final token = (data['token'] as String?) ?? '';
    final refreshToken = (data['refreshToken'] as String?) ?? '';
    final captain = CloudCaptain.fromJson((data['user'] as Map<String, dynamic>?) ?? const {});
    await onAuthenticated?.call(token, refreshToken);
    return captain;
  }

  /// 设置/修改登录密码（PATCH /api/user/set-password，JWT，v2.9.9 账号设置-密码设置）。
  /// 后端 bcrypt 加密入库；<6 位由前端前置拦截，后端同规则兜底。
  Future<void> setPassword(String password) async {
    await _request('PATCH', '/api/user/set-password',
        body: <String, dynamic>{'password': password});
  }

  /// 找回密码-验证码重置（POST /api/password/reset，v2.9.9 忘记密码流程）。
  /// [account] 仅支持手机号/邮箱（账号ID 不允许）；验证码 purpose=reset 核验身份，
  /// 不需要原密码；成功后不自动登录（前端引导回登录页）。
  Future<void> resetPassword({
    required String account,
    required String code,
    required String newPassword,
  }) async {
    await _request('POST', '/api/password/reset', body: <String, dynamic>{
      'account': account,
      'code': code,
      'newPassword': newPassword,
    });
  }

  // ── v2.9.9 消息中心（4 类互动通知 + 私信）─────────────────

  /// 4 类消息未读数（GET /api/user/notifications/unread）
  Future<CloudUnreadCounts> fetchUnreadCounts() async {
    final data = await _request('GET', '/api/user/notifications/unread') as Map<String, dynamic>;
    return CloudUnreadCounts.fromJson(data);
  }

  /// 分类通知平铺列表（GET /api/user/notifications?type=...）
  /// like 类聚合展示由调用方按 postId/commentId 分组
  Future<List<CloudNotification>> fetchNotifications(
      {required String type, int page = 1, int size = 20}) async {
    final data = await _request('GET', '/api/user/notifications',
        query: {'type': type, 'page': '$page', 'size': '$size'}) as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>?) ?? const [];
    return list.map((j) => CloudNotification.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 批量标记通知已读（POST /api/user/notifications/read）
  Future<void> markNotificationsRead(List<int> ids) async {
    await _request('POST', '/api/user/notifications/read',
        body: <String, dynamic>{'ids': ids});
  }

  /// 分类全部已读（POST /api/user/notifications/read-all）
  Future<void> markAllNotificationsRead(String type) async {
    await _request('POST', '/api/user/notifications/read-all',
        body: <String, dynamic>{'type': type});
  }

  /// 私信会话列表（GET /api/user/dm/conversations）
  Future<List<CloudConversation>> fetchConversations() async {
    final data = await _request('GET', '/api/user/dm/conversations') as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>?) ?? const [];
    return list.map((j) => CloudConversation.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 会话消息（GET /api/user/dm/:peerUid/messages；打开即置对方消息已读）
  Future<List<CloudDmMessage>> fetchDmMessages(int peerUid) async {
    final data = await _request('GET', '/api/user/dm/$peerUid/messages') as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>?) ?? const [];
    return list.map((j) => CloudDmMessage.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 发送私信（POST /api/user/dm）
  Future<void> sendDm({required int toUid, required String content}) async {
    await _request('POST', '/api/user/dm',
        body: <String, dynamic>{'toUid': toUid, 'content': content});
  }

  /// v2.9.11 账号注销（AGENTS.md §12）：POST /api/account/close
  /// 匿名化：昵称改【已注销用户】/头像简介清空/关注粉丝双向清空/会话全部吊销；
  /// 帖子评论私信保留不删；成功后旧 token 即时失效（需重新走登录流程）
  Future<void> closeAccount() async {
    await _request('POST', '/api/account/close');
  }

  // ── v2.9.10 群聊（6 个固定内置群）─────────────────────────

  /// 群列表（GET /api/group/list）：基础信息+最新消息+当前用户未读数
  Future<List<CloudGroupEntry>> fetchGroups() async {
    final data = await _request('GET', '/api/group/list') as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>?) ?? const [];
    return list.map((j) => CloudGroupEntry.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 群详情（GET /api/group/:groupId/info）
  Future<CloudGroupInfo> fetchGroupInfo(String groupId) async {
    final data = await _request('GET', '/api/group/$groupId/info') as Map<String, dynamic>;
    return CloudGroupInfo.fromJson(data);
  }

  /// 群历史消息分页（GET /api/group/:groupId/msg）
  /// 进群不带 lastMsgId → 最新 [limit] 条；上拉历史带 lastMsgId → 更早 limit 条
  Future<List<CloudGroupMessage>> fetchGroupMessages(String groupId,
      {int? lastMsgId, int limit = 20}) async {
    final query = <String, String>{'limit': '$limit'};
    if (lastMsgId != null) query['last_msg_id'] = '$lastMsgId';
    final data =
        await _request('GET', '/api/group/$groupId/msg', query: query) as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>?) ?? const [];
    return list.map((j) => CloudGroupMessage.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 发群文本消息（POST /api/group/:groupId/msg，风控审核）→ 返回完整消息回执
  Future<CloudGroupMessage> sendGroupMessage(String groupId, String content) async {
    final data = await _request('POST', '/api/group/$groupId/msg',
        body: <String, dynamic>{'content': content}) as Map<String, dynamic>;
    return CloudGroupMessage.fromJson(data);
  }

  /// 标记群已读（POST /api/group/:groupId/read，进群/收到新消息时调用）
  Future<void> markGroupRead(String groupId, int lastReadMsgId) async {
    await _request('POST', '/api/group/$groupId/read',
        body: <String, dynamic>{'lastReadMsgId': lastReadMsgId});
  }
}
