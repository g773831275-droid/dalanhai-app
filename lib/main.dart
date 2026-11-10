import 'package:flutter/material.dart';
import 'app.dart';
import 'data/data_store.dart';
import 'services/cloud_api.dart';
import 'services/session_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据仓库（从 shared_preferences 加载本地数据）
  final store = DataStore();
  await store.load();

  // v2.7：恢复 JWT 登录态并注入 CloudApi（此后全部请求自动带 Bearer token）
  await SessionStore.instance.restore();

  // 第一轮联调：冷启动校验 token 并刷新用户档案（GET /api/user/me）。
  //   成功 → 本地登录态与云端档案对齐（换设备登录自动同步）；
  //   401 / 网络失败 → 静默清理或保持现状，不打断启动。
  if (SessionStore.instance.hasToken) {
    try {
      final captain = await CloudApi.instance.fetchMe();
      if (!store.isLoggedIn || store.captain?.name != captain.displayName) {
        store.login(captain.displayName, 'phone'); // 云端档案 → 本地登录标记
      }
      // v2.9.5 修复头像重置：冷启动把云端 avatar（OSS 对象 key）回填本地
      // Captain —— 旧逻辑只 login(name) 重建对象，avatar 永远丢失，
      // 杀 App 重开后船长页/feed 头像全部回退默认首字
      if (captain.avatar.isNotEmpty) {
        store.updateAvatar(captain.avatar);
      }
    } on ApiException catch (e) {
      if (e.code == 401) {
        // token 失效：自动登出（清本地状态 → 船长闸门重新生效）
        await SessionStore.instance.clear();
        store.logout();
      }
      // 其他错误（后端未就绪/网络）→ 静默跳过，本地登录态保持
    } catch (_) {
      // 网络异常等 → 静默跳过
    }
  }

  runApp(GrandBlueApp(store: store));
}
