import 'dart:math';

/// 认证服务 — 验证码生成/校验
///
/// 当前为 **本地开发模式**：生成随机 6 位验证码，存在内存中，
/// 通过 [lastSentCode] 暴露给 UI 层显示（方便测试）。
///
/// 生产环境替换为真实 SMS/邮件服务时，只需实现相同的接口：
/// - [sendCode] 改为调用短信 API（腾讯云/阿里云/Twilio）
/// - [verifyCode] 改为调用后端校验接口
/// - 移除 [lastSentCode]（生产环境不应暴露验证码给客户端）
class AuthService {
  final Map<String, String> _codes = {}; // {contact: code}
  String? lastSentCode; // 开发模式：最后一次发送的验证码（UI 显示用）

  /// 发送验证码
  /// [contact] 手机号或邮箱
  /// 返回 null 表示成功，返回错误消息表示失败
  String? sendCode(String contact) {
    if (contact.isEmpty) return '请输入手机号或邮箱';
    final code = (100000 + Random().nextInt(900000)).toString();
    _codes[contact] = code;
    lastSentCode = code; // 开发模式：暴露给 UI
    // TODO(prod): 调用短信/邮件 API 发送验证码
    // 例：await http.post(Uri.parse('$apiUrl/sms/send'), body: {'contact': contact});
    return null;
  }

  /// 校验验证码
  /// 返回 null 表示成功，返回错误消息表示失败
  String? verifyCode(String contact, String code) {
    final stored = _codes[contact];
    if (stored == null) return '请先获取验证码';
    if (stored != code) return '验证码错误';
    _codes.remove(contact);
    lastSentCode = null;
    return null;
  }

  /// 手机号格式校验
  static bool isValidPhone(String phone) => RegExp(r'^1\d{10}$').hasMatch(phone);

  /// 邮箱输入归一化（v2.9.9 修复误拦截）：中文输入法（拼音键盘）手输的
  /// 全角＠(U+FF20)、中文句号。(U+3002)、全角句点．(U+FF0E) 转半角 @ / .，
  /// 归一化结果同时用于格式校验与发码/登录请求（后端正则只认半角）。
  static String normalizeEmail(String email) => email
      .replaceAll('＠', '@')
      .replaceAll('。', '.')
      .replaceAll('．', '.');

  /// 邮箱格式校验（半角合法邮箱；内部先做全角归一化，避免手输全角＠/。被误判非法）
  static bool isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizeEmail(email));
}
