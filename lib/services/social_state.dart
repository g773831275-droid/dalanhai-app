import 'package:flutter/foundation.dart';

import 'cloud_api.dart';

/// 当前登录用户 uid 缓存（v2.9.6 社交链路专用）。
///
/// 本地 Captain（DataStore）只存 name/avatar，无云端 id；
/// 详情页"是否本人日志"、头像跳转"自身公开预览"、船长页本人管理视角
/// 都需要 uid —— 统一从 GET /api/user/me 拉取并缓存。
/// 登出时必须调 [clear]（账号切换防串号）。
class MeState {
  MeState._();
  static final MeState instance = MeState._();

  int? _uid;

  /// 是否已缓存 uid（同步读取，避免 UI 判断前异步等待）
  bool get hasUid => _uid != null;

  Future<int> uid() async {
    final cached = _uid;
    if (cached != null) return cached;
    final me = await CloudApi.instance.fetchMe();
    _uid = me.id;
    return me.id;
  }

  void clear() => _uid = null;
}

/// 全局关注状态单例（v2.9.6 需求"关注状态全局实时联动"）。
///
/// 日志详情页、他人主页、关注/粉丝弹窗都读写本缓存：
/// 任意一处 toggle 成功 → 写入缓存 + notifyListeners，
/// 其他页面经 AnimatedBuilder 监听即时刷新，无状态错乱。
class FollowState extends ChangeNotifier {
  FollowState._();
  static final FollowState instance = FollowState._();

  /// uid → 我是否关注了该用户
  final Map<int, bool> _cache = <int, bool>{};

  /// 同步读取缓存（null=未拉取过；UI 应先用 profile/follow-status 初始化）
  bool? of(int uid) => _cache[uid];

  /// 写入缓存并广播（toggle 成功后调用；不触发网络）
  void set(int uid, bool following) {
    _cache[uid] = following;
    notifyListeners();
  }

  /// 拉取一次状态并缓存（返回最新关注状态）
  Future<bool> ensure(int uid) async {
    final cached = _cache[uid];
    if (cached != null) return cached;
    try {
      final s = await CloudApi.instance.fetchFollowStatus(uid);
      _cache[uid] = s.following;
      notifyListeners();
      return s.following;
    } on ApiException {
      return false;
    }
  }

  /// toggle 关注/取关（网络成功后才写缓存，保证"无状态错乱"）。
  /// 返回 toggle 后的关注状态。
  Future<bool> toggle(int uid) async {
    final r = await CloudApi.instance.followUser(uid);
    _cache[uid] = r.following;
    notifyListeners();
    return r.following;
  }

  void clear() {
    _cache.clear();
    notifyListeners();
  }
}
