import 'dart:async';

import 'cloud_api.dart';
import 'media_rules.dart';

/// media/sign 时效签名 URL 缓存（v2.6 防爬渲染链路的客户端侧）
///
/// 规范：
///   1. 帖子接口只返回 attachKey，禁止持有/请求原始 OSS 地址
///   2. 渲染前调 POST /api/media/sign（JWT + attachKey 对应的 postId）
///   3. 按 expiresAt 缓存，过期（留 60s 在途余量）自动重取
///   4. 过期 / 违规 / 无权限 / 不存在 → 返回 null，上层渲染占位图
class MediaSignCache {
  MediaSignCache._();

  static final MediaSignCache instance = MediaSignCache._();

  final CloudApi _api = CloudApi.instance;

  /// v2.9.12 图片渲染域名映射：签名 URL → ESA 自定义域名 img.idalanhai.com。
  /// 上传链路（put-sign 直传 host）不走此映射，保持 OSS 原始域名。
  ///
  /// 2026-11-18 ESA 私有访问模式（阿里云工单结论）：ESA 站点已开启 OSS 私有
  /// Bucket 自动回源鉴权 —— ESA 节点内部自行携带签名访问 OSS。URL 上同时
  /// 携带 OSS 签名参数（OSSAccessKeyId/Expires/Signature）会造成双重鉴权
  /// 冲突，引发随机 400 / SSL 重置 / 超时。因此渲染 URL **必须剥离全部
  /// 签名 query**，只保留 path。
  static const String kRenderHost = 'img.idalanhai.com';

  String _mapRenderUrl(String url) {
    try {
      final Uri u = Uri.parse(url);
      if (u.host.isEmpty) return url;
      // 剥离全部 query（OSS 签名参数），ESA 私有访问自动鉴权回源；
      // 用 Uri 重建而非 replace(query:'') —— 后者会留下尾随 '?'。
      return Uri(scheme: 'https', host: kRenderHost, path: u.path)
          .toString();
    } catch (_) {
      return url; // 非 http 形态（如 data:）原样返回
    }
  }

  SignedPostMedia _mapPostMedia(SignedPostMedia m) => SignedPostMedia(
        urls: m.urls.map(_mapRenderUrl).toList(),
        expiresAt: m.expiresAt,
      );

  SignedKeyMedia _mapKeyMedia(SignedKeyMedia m) => SignedKeyMedia(
        url: _mapRenderUrl(m.url),
        expiresAt: m.expiresAt,
      );

  /// postId → 签名结果
  final Map<int, SignedPostMedia> _cache = <int, SignedPostMedia>{};

  /// 去重并发：同一帖子的重取请求只发一次
  final Map<int, Future<SignedPostMedia?>> _inFlight = <int, Future<SignedPostMedia?>>{};

  /// 裸 key（头像等）→ 签名结果
  final Map<String, SignedKeyMedia> _keyCache = <String, SignedKeyMedia>{};
  final Map<String, Future<String?>> _keyInFlight = <String, Future<String?>>{};

  bool _fresh(SignedPostMedia m) =>
      m.expiresAt - MediaRules.signUrlRefreshMarginSec * 1000 >
      DateTime.now().millisecondsSinceEpoch;

  /// 取某帖第 [index] 张附件的时效 URL（多图帖 index < attachKeys.length）。
  /// 过期自动重取；missing（未过审/已清理/无权限/网络失败）返回 null → 占位图。
  Future<String?> urlFor(int postId, {int index = 0}) async {
    final SignedPostMedia? cached = _cache[postId];
    if (cached != null && _fresh(cached)) {
      return index < cached.urls.length ? cached.urls[index] : null;
    }
    final SignedPostMedia? fresh = await _refresh(postId);
    if (fresh == null) return null;
    return index < fresh.urls.length ? fresh.urls[index] : null;
  }

  Future<SignedPostMedia?> _refresh(int postId) {
    return _inFlight.putIfAbsent(postId, () async {
      try {
        final Map<int, SignedPostMedia> r = await _api.signMedia(<int>[postId]);
        final SignedPostMedia? m = r[postId];
        final SignedPostMedia? mapped = m == null ? null : _mapPostMedia(m);
        if (mapped != null) _cache[postId] = mapped;
        return mapped; // 返回值与缓存同口径（渲染域名已映射）
      } on ApiException {
        return null; // 401/429/网络失败 → 占位图（不抛出，渲染层兜底）
      } finally {
        _inFlight.remove(postId);
      }
    });
  }

  /// 列表页批量预热（≤30 帖/批，一次签名换整页，减少请求）
  Future<void> prefetch(List<int> postIds) async {
    _purgeExpired();
    final List<int> need = postIds
        .where((id) => !_fresh(_cache[id] ?? const SignedPostMedia(urls: <String>[], expiresAt: 0)))
        .toList();
    if (need.isEmpty) return;
    try {
      final Map<int, SignedPostMedia> r = await _api.signMedia(need);
      _cache.addAll(r.map((k, v) => MapEntry(k, _mapPostMedia(v))));
    } on ApiException {
      // 预热失败不阻塞渲染，单帖渲染时会再试
    }
  }

  /// 裸 key 批量预热（v2.9.12）：列表页收集可见头像 key 一次批量签名，
  /// 消除 N 个头像 = N 次 /api/media/sign 的请求放大（signKeys ≤10 个/批，分批发）。
  Future<void> prefetchKeys(List<String> keys) async {
    _purgeExpired();
    final List<String> need = keys
        .where((k) =>
            k.isNotEmpty &&
            !k.startsWith('data:') &&
            !k.contains(' ') && // 与 UserAvatar 判定口径一致：仅 OSS key 形态
            !_keyFresh(_keyCache[k] ?? const SignedKeyMedia(url: '', expiresAt: 0)))
        .toSet()
        .toList();
    if (need.isEmpty) return;
    for (int i = 0; i < need.length; i += 10) {
      final batch = need.sublist(i, (i + 10).clamp(0, need.length));
      try {
        final Map<String, SignedKeyMedia> r = await _api.signKeys(batch);
        _keyCache.addAll(r.map((k, v) => MapEntry(k, _mapKeyMedia(v))));
      } on ApiException {
        // 批量预热失败不阻塞渲染，单 key 渲染时会再试
      }
    }
  }

  /// 过期条目淘汰（v2.9.12）：随 prefetch 顺手清理，防长会话缓存无界累积；
  /// 登出 clear() 仍是全量兜底。
  void _purgeExpired() {
    _cache.removeWhere((_, m) => !_fresh(m));
    _keyCache.removeWhere((_, m) => !_keyFresh(m));
  }

  /// v2.7：裸 key 时效 URL（头像等非帖子绑定资源，走 media/sign keys 参数）。
  /// 与帖子附件同口径：过期自动重取，失败返回 null → 上层渲染占位。
  Future<String?> urlForKey(String key) async {
    if (key.isEmpty) return null;
    final SignedKeyMedia? cached = _keyCache[key];
    if (cached != null && _keyFresh(cached)) return cached.url;
    return _keyInFlight.putIfAbsent(key, () async {
      try {
        final Map<String, SignedKeyMedia> r = await _api.signKeys(<String>[key]);
        final SignedKeyMedia? m = r[key];
        final SignedKeyMedia? mapped = m == null ? null : _mapKeyMedia(m);
        if (mapped != null) _keyCache[key] = mapped;
        return mapped?.url; // 与缓存同口径（渲染域名已映射）
      } on ApiException {
        return null; // 401/429/网络失败 → 占位
      } finally {
        _keyInFlight.remove(key);
      }
    });
  }

  bool _keyFresh(SignedKeyMedia m) =>
      m.expiresAt - MediaRules.signUrlRefreshMarginSec * 1000 >
      DateTime.now().millisecondsSinceEpoch;

  /// 退出登录 / 切换账号时清空（签名与用户绑定）
  void clear() {
    _cache.clear();
    _inFlight.clear();
    _keyCache.clear();
    _keyInFlight.clear();
  }
}
