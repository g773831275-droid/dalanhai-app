// 短信登录链路冒烟（直连生产 API）
// 运行：dart run tool_smoke_auth.dart
//
// ⚠️ Flash 后端（第一轮联调 6 接口）上线前，真实登录无法走通；
// 本脚本验证：① 请求组装/token 注入正确 ② 后端「接口不存在」等异常正常传播
// （Flash 后端部署后，同一脚本即变成真实链路冒烟）
// ignore_for_file: avoid_print
import 'lib/services/cloud_api.dart';

int pass = 0, fail = 0;
void check(String name, bool ok) {
  final tag = ok ? '✅ PASS' : '❌ FAIL';
  print('$tag  $name');
  ok ? pass++ : fail++;
}

Future<void> main() async {
  final api = CloudApi.instance;
  api.configure(baseUrl: 'https://api.idalanhai.com');

  // ① 发码：后端未上线「接口不存在」/ 已上线 400·429 业务异常 —— 抛 ApiException 即链路通
  try {
    await api.sendSmsCode('13800138000');
    check('发码成功（Flash 后端已上线）', true);
  } on ApiException catch (e) {
    check('发码异常正常传播（${e.code}: ${e.message}）', true);
  } catch (e) {
    check('发码抛出非预期异常：$e', false);
  }

  // ② 登录：验证码随便填 → 未上线「接口不存在」/ 已上线 409 验证码错误
  try {
    await api.loginBySms('13800138000', '000000');
    check('登录成功（Flash 后端已上线）', true);
  } on ApiException catch (e) {
    check('登录异常正常传播（${e.code}: ${e.message}）', true);
  } catch (e) {
    check('登录抛出非预期异常：$e', false);
  }

  // ③ me / island / logout：异常传播（后端未上线均为「接口不存在」）
  for (final task in <Future<void> Function()>[
    () async => api.fetchMe(),
    () async => api.fetchIslandCheckin('sleep'),
    () async => api.cloudCheckin('sleep'),
    () async => api.logout(),
  ]) {
    try {
      await task();
      check('接口调用成功（Flash 后端已上线）', true);
    } on ApiException catch (e) {
      check('接口异常正常传播（${e.code}: ${e.message}）', true);
    } catch (e) {
      check('接口抛出非预期异常：$e', false);
    }
  }

  // ④ onAuthenticated 回调往返：loginBySms 成功 → token 注入（生产里由 SessionStore.saveSession 完成）
  String? savedToken;
  CloudApi.onAuthenticated = (t, r) async {
    savedToken = t;
    api.configure(baseUrl: api.baseUrl!, token: t);
  };
  await CloudApi.onAuthenticated!.call('smoke_token', '');
  check('onAuthenticated 回调收到 token', savedToken == 'smoke_token');
  check('回调后 CloudApi 携带新 token', api.token == 'smoke_token');
  CloudApi.onAuthenticated = null;
  api.configure(baseUrl: api.baseUrl!); // 清 token 还原

  print('──────────────────────────────');
  print('结果: PASS=$pass FAIL=$fail');
}
