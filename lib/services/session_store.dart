import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_api.dart';
import 'media_sign_cache.dart';

/// JWT 登录态持久化 + 自动注入 CloudApi（v2.7 P0；v2.9.6 域名单点管理）
///
/// 职责：
///   - token/refreshToken 的本地持久化（shared_preferences）
///   - 启动时 [restore] 自动注入 CloudApi（此后所有请求经
///     CloudApi._jsonHeaders 统一带上 Authorization: Bearer —— 拦截器语义）
///   - 退出登录 [clear]（同时清 media/sign 签名缓存，签名与用户绑定）
///
/// ⚠️ v2.9.6 域名策略（全局唯一线上域名，代码单点管理）：
///   线上服务器 = 香港节点（nginx 443 反代 → 127.0.0.1:3000）。
///   域名只在本文件 [defaultBaseUrl] 一处维护，不再从设备端
///   shared_preferences 读取 —— 防止历史调试期持久化的本地旧地址
///   （http://8.210.145.212:3000 / localhost 等）覆盖线上配置。
///   后端 3000 仅监听 127.0.0.1，公网必须走 HTTPS 域名（iOS ATS 也强制）。
///
/// 使用：
///   1. main() 里 `await SessionStore.instance.restore();`
///   2. 登录成功后 `SessionStore.instance.saveSession(token, refreshToken);`
///   3. 401（token 失效）时调 [clear] 并引导重新登录
class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();

  /// 线上服务器唯一域名（全局单点配置；所有接口统一走这里）
  static const String defaultBaseUrl = 'https://api.idalanhai.com';

  static const String _kBase = 'dalanhai_api_base'; // 历史遗留键：restore 时清除
  static const String _kToken = 'dalanhai_api_token';
  static const String _kRefresh = 'dalanhai_api_refresh';

  String? refreshToken;

  bool get hasToken => (CloudApi.instance.token ?? '').isNotEmpty;

  /// App 启动时调用：读本地持久化 token → 注入 CloudApi。
  /// 域名恒为 [defaultBaseUrl]（线上唯一），并清除历史持久化的旧 baseUrl
  /// 残留（调试期可能写入过本地地址）。无 token 时同样预配置（游客可拉公开列表）。
  /// 同时接管 CloudApi.onAuthenticated 回调：登录成功自动持久化 + 即时生效。
  Future<void> restore() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString(_kToken);
    refreshToken = sp.getString(_kRefresh);
    // 清除历史遗留的 baseUrl 持久化键（旧版本写入过本地调试地址）
    await sp.remove(_kBase);
    CloudApi.instance.configure(baseUrl: defaultBaseUrl, token: token);
    CloudApi.onAuthenticated = (String token, String rt) =>
        saveSession(token, refreshToken: rt);
  }

  /// 登录/注册/续期成功后调用（覆盖写入并即时生效）。
  /// [baseUrl] 参数仅为兼容旧调用签名保留，实际恒用 [defaultBaseUrl]。
  Future<void> saveSession(String token, {String? refreshToken, String? baseUrl}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
    if (refreshToken != null) {
      await sp.setString(_kRefresh, refreshToken);
      this.refreshToken = refreshToken;
    }
    CloudApi.instance.configure(baseUrl: defaultBaseUrl, token: token);
  }

  /// 退出登录 / 401 token 失效时调用
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kRefresh);
    refreshToken = null;
    CloudApi.instance.configure(baseUrl: defaultBaseUrl);
    MediaSignCache.instance.clear(); // 时效签名与用户绑定，登出即清
  }
}
