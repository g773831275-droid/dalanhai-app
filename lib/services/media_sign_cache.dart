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
        if (m != null) _cache[postId] = m;
        return m;
      } on ApiException {
        return null; // 401/429/网络失败 → 占位图（不抛出，渲染层兜底）
      } finally {
        _inFlight.remove(postId);
      }
    });
  }

  /// 列表页批量预热（≤30 帖/批，一次签名换整页，减少请求）
  Future<void> prefetch(List<int> postIds) async {
    final List<int> need = postIds
        .where((id) => !_fresh(_cache[id] ?? const SignedPostMedia(urls: <String>[], expiresAt: 0)))
        .toList();
    if (need.isEmpty) return;
    try {
      final Map<int, SignedPostMedia> r = await _api.signMedia(need);
      _cache.addAll(r);
    } on ApiException {
      // 预热失败不阻塞渲染，单帖渲染时会再试
    }
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
        if (m != null) _keyCache[key] = m;
        return m?.url;
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
