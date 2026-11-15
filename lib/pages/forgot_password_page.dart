import 'package:flutter/material.dart';
import '../services/cloud_api.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../data/auth_service.dart';

/// 找回密码页 — 验证码重置密码（v2.9.9 联调真实接口）
///   POST /api/sms/code   { phone, purpose: "reset" }（账号不存在报错，不建号）
///   POST /api/email/code { email(归一化后), purpose: "reset" }（后端豁免人机验证，风控+限流兜底）
///   POST /api/password/reset { account, code, newPassword }
/// 与【账号设置-密码设置】是两套独立流程：本页不需要原密码，靠验证码核验身份；
/// 重置成功后不自动登录，toast 引导返回登录页用新密码登录。
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  String _mode = 'phone'; // phone / email（验证方式二选一）
  int _countdown = 0;
  bool _busy = false; // 发码/重置请求进行中（防重复提交）

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

  /// 当前输入的账号（手机号或邮箱；邮箱走全角归一化，校验与请求共用同一值）
  String get _target => _mode == 'phone'
      ? _phoneCtrl.text.trim()
      : AuthService.normalizeEmail(_emailCtrl.text.trim());

  Future<void> _sendCode() async {
    if (_mode == 'phone') {
      if (!AuthService.isValidPhone(_target)) return _toast('请输入正确的手机号');
    } else {
      if (!AuthService.isValidEmail(_target)) return _toast('请输入正确的邮箱');
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // purpose=reset：账号不存在后端直接报错（不自动建号）
      if (_mode == 'phone') {
        await CloudApi.instance.sendSmsCode(_target, purpose: 'reset');
      } else {
        await CloudApi.instance.sendEmailCode(_target, '', '', purpose: 'reset');
      }
      if (!mounted) return;
      setState(() => _countdown = 60);
      _toast(_mode == 'phone' ? '验证码已发送，请查收短信' : '验证码已发送，请查收邮件');
      _tick();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('发送失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown > 0) _tick();
    });
  }

  Future<void> _submit() async {
    // 1. 账号格式
    if (_mode == 'phone') {
      if (!AuthService.isValidPhone(_target)) return _toast('请输入正确的手机号');
    } else {
      if (!AuthService.isValidEmail(_target)) return _toast('请输入正确的邮箱');
    }
    // 2. 验证码（格式前置；正确性由后端 purpose=reset 核验）
    final code = _codeCtrl.text.trim();
    if (code.length != 6) return _toast('请输入 6 位验证码');
    // 3. 新密码（≥6 位 + 两次一致，前置校验不发请求）
    final p1 = _passCtrl.text;
    final p2 = _pass2Ctrl.text;
    if (p1.length < 6) return _toast('新密码至少 6 位');
    if (p1 != p2) return _toast('两次输入的密码不一致');
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await CloudApi.instance.resetPassword(account: _target, code: code, newPassword: p1);
      if (!mounted) return;
      _toast('密码重置成功，请返回登录页使用新密码登录');
      Navigator.of(context).pop(); // 重置成功 → 返回登录页（不自动登录）
    } on ApiException catch (e) {
      if (mounted) _toast(e.message); // 验证码错误/账号不存在/格式错误等友好提示
    } catch (_) {
      if (mounted) _toast('重置失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
