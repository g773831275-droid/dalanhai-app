import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../data/auth_service.dart';

/// 找回密码页 — 验证码重置密码
/// 对接后端（联调后启用，见 TODO 标注）：
///   POST /api/sms/send   { phone, purpose: "reset" }
///   POST /api/email/send { email, purpose: "reset" }
///   POST /api/password/reset { type: "sms|email", target, code, newPassword }
/// 当前验证码走本地 AuthService 演示，联调时替换为真实 API（api_client 接入）
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _auth = AuthService();
  String _mode = 'phone'; // phone / email（验证方式二选一）
  int _countdown = 0;
  String? _lastCode; // 开发模式：显示验证码

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  /// 当前输入的账号（手机号或邮箱）
  String get _target => _mode == 'phone' ? _phoneCtrl.text.trim() : _emailCtrl.text.trim();

  void _sendCode() {
    if (_mode == 'phone') {
      if (!AuthService.isValidPhone(_target)) return _toast('请输入正确的手机号');
    } else {
      if (!AuthService.isValidEmail(_target)) return _toast('请输入正确的邮箱');
    }
    // TODO(联调): POST /api/{sms|email}/send { target, purpose: "reset" }，取 data.devCode 展示
    final err = _auth.sendCode(_target);
    if (err != null) return _toast(err);
    setState(() {
      _lastCode = _auth.lastSentCode;
      _countdown = 60;
    });
    _toast('验证码已发送（开发模式：$_lastCode）');
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown > 0) _tick();
    });
  }

  void _submit() {
    // 1. 账号格式
    if (_mode == 'phone') {
      if (!AuthService.isValidPhone(_target)) return _toast('请输入正确的手机号');
    } else {
      if (!AuthService.isValidEmail(_target)) return _toast('请输入正确的邮箱');
    }
    // 2. 验证码
    final code = _codeCtrl.text.trim();
    if (code.length != 6) return _toast('请输入 6 位验证码');
    final err = _auth.verifyCode(_target, code);
    if (err != null) return _toast(err);
    // 3. 新密码
    final p1 = _passCtrl.text;
    final p2 = _pass2Ctrl.text;
    if (p1.length < 6) return _toast('新密码至少 6 位');
    if (p1 != p2) return _toast('两次输入的密码不一致');

    // TODO(联调): POST /api/password/reset
    //   { "type": _mode == 'phone' ? 'sms' : 'email', "target": _target, "code": code, "newPassword": p1 }
    //   成功 code:0 → toast + 返回登录页
    _toast('密码已重置（演示）· 请用新密码登录');
    Navigator.of(context).pop();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.ocean, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('找回密码'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(child: Text('RESET PASSWORD', style: AppTypography.brand.copyWith(fontSize: 26))),
              const SizedBox(height: 6),
              Center(child: Text('选择验证方式重置密码', style: AppTypography.bodySub)),
              const SizedBox(height: 32),
              _buildModeTabs(),
              const SizedBox(height: 24),
              _buildForm(),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _submit, child: const Text('重置密码')),
              const SizedBox(height: 12),
              Text(
                '重置成功后请返回登录页，使用新密码登录',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 验证方式切换：手机号 / 邮箱
  Widget _buildModeTabs() {
    Widget tab(String id, String label) {
      final active = _mode == id;
      return GestureDetector(
        onTap: () => setState(() => _mode = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active ? Border.all(color: AppColors.gold, width: 1) : null,
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
            color: active ? AppColors.gold : AppColors.sub,
            fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
        ),
      );
    }

    return Row(children: [
      Expanded(child: tab('phone', '手机号验证')),
      const SizedBox(width: 8),
      Expanded(child: tab('email', '邮箱验证')),
    ]);
  }

  Widget _buildForm() {
    return Column(children: [
      if (_mode == 'phone')
        _Field(label: '手机号 · PHONE', child: TextField(
          controller: _phoneCtrl, keyboardType: TextInputType.phone, maxLength: 11,
          style: const TextStyle(color: AppColors.parchment),
          decoration: const InputDecoration(hintText: '请输入 11 位手机号', counterText: ''),
        ))
      else
        _Field(label: '邮箱 · EMAIL', child: TextField(
          controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.parchment),
          decoration: const InputDecoration(hintText: 'captain@grandblue.io'),
        )),
      const SizedBox(height: 16),
      _Field(label: '验证码 · CODE', child: Row(children: [
        Expanded(child: TextField(
          controller: _codeCtrl, keyboardType: TextInputType.number, maxLength: 6,
          style: const TextStyle(color: AppColors.parchment),
          decoration: const InputDecoration(hintText: '6 位验证码', counterText: ''),
        )),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _countdown > 0 ? null : _sendCode,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.cardSolid),
          child: Text(_countdown > 0 ? '$_countdown s' : '获取', style: const TextStyle(color: AppColors.gold, fontSize: 13)),
        ),
      ])),
      const SizedBox(height: 16),
      _Field(label: '新密码 · NEW PASSWORD', child: TextField(
        controller: _passCtrl, obscureText: true,
        style: const TextStyle(color: AppColors.parchment),
        decoration: const InputDecoration(hintText: '至少 6 位'),
      )),
      const SizedBox(height: 16),
      _Field(label: '确认新密码 · CONFIRM', child: TextField(
        controller: _pass2Ctrl, obscureText: true,
        style: const TextStyle(color: AppColors.parchment),
        decoration: const InputDecoration(hintText: '再次输入新密码'),
      )),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.sub, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
