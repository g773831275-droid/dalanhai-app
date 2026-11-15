import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../data/auth_service.dart';
import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';
import '../app.dart' show appTabIndex;
import '../widgets/eula_dialog.dart';
import 'forgot_password_page.dart';

class AuthPage extends StatefulWidget {
  /// 登录成功回流目的地：'captain'（默认）→ 船长 Tab；'island' → 返回岛屿详情页继续打卡
  final String returnTo;

  const AuthPage({super.key, this.returnTo = 'captain'});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _auth = AuthService();
  String _mode = 'phone'; // phone / email / password
  int _countdown = 0;
  String? _lastCode; // 邮箱模式：本地开发验证码回显

  bool _busy = false; // 发码/登录请求进行中（防重复提交）
  bool _eulaAccepted = false; // EULA 勾选（未勾选禁止发码/登录）

  // 邮箱模式人机验证（GET /api/captcha/challenge，challenge 一次性）
  String _captchaId = '';
  String _captchaQuestion = '';

  /// 发码错误 → 友好文案（Flash 后端异常约定：400 参数 / 403 人机验证·风控 / 409 业务冲突 / 429 限流）
  String _friendlyError(ApiException e) {
    switch (e.code) {
      case 400:
        return e.message.contains('格式') || e.message.contains('手机号') || e.message.contains('邮箱')
            ? e.message
            : '输入格式不正确';
      case 409:
        return e.message; // 验证码错误/已过期（后端原文）
      case 429:
        return e.message.contains('上限') || e.message.contains('频繁')
            ? e.message
            : '操作太频繁了，喝口海水冷静一下 🌊';
      default:
        return e.message;
    }
  }

  /// EULA 勾选闸门：登录、注册流程必须先同意《航海守则》
  bool _checkEula() {
    if (_eulaAccepted) return true;
    _toast('请先阅读并勾选同意《航海守则》');
    return false;
  }

  /// 拉取邮箱模式人机验证挑战（challenge 一次性，验证后/过期需重取）
  Future<void> _fetchCaptcha() async {
    try {
      final c = await CloudApi.instance.fetchCaptchaChallenge();
      if (!mounted) return;
      setState(() {
        _captchaId = c.captchaId;
        _captchaQuestion = c.question;
      });
    } on ApiException {
      // 拉取失败静默：点「获取」时会以 403 提示
    }
  }

  /// 发码（POST /api/sms/code、POST /api/email/code）：60s 冷却；凭证不存在自动注册。
  /// ⚠️ EULA 未勾选禁止发码。
  Future<void> _sendCode() async {
    if (!_checkEula()) return;
    if (_mode == 'phone') {
      final contact = _phoneCtrl.text.trim();
      if (!AuthService.isValidPhone(contact)) {
        _toast('请输入正确的手机号');
        return;
      }
      if (_busy) return;
      setState(() => _busy = true);
      try {
        await CloudApi.instance.sendSmsCode(contact);
        if (!mounted) return;
        setState(() => _countdown = 60);
        _toast('验证码已发送，请查收短信');
        _tick();
      } on ApiException catch (e) {
        _toast(_friendlyError(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    if (_mode == 'email') {
      // 邮箱发码：强制人机验证（captchaId+Answer）+ 临时邮箱拦截 + 双限流（后端）
      final e = _emailCtrl.text.trim();
      if (!AuthService.isValidEmail(e)) {
        _toast('请输入正确的邮箱');
        return;
      }
      if (_captchaId.isEmpty || _captchaCtrl.text.trim().isEmpty) {
        _toast('请先完成人机验证');
        return;
      }
      if (_busy) return;
      setState(() => _busy = true);
      try {
        await CloudApi.instance.sendEmailCode(e, _captchaId, _captchaCtrl.text.trim());
        if (!mounted) return;
        setState(() => _countdown = 60);
        _captchaCtrl.clear();
        _fetchCaptcha(); // challenge 一次性 → 立即换新题备用
        _toast('验证码已发送，请查收邮件');
        _tick();
      } on ApiException catch (e2) {
        _toast(_friendlyError(e2));
        _fetchCaptcha(); // 验证失败换新题
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    // TODO(后续批次): 密码模式 POST /api/login（本轮后置，仍为本地开发模式）
    final err = _auth.sendCode(_acctCtrl.text.trim());
    if (err != null) {
      _toast(err);
      return;
    }
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

  Future<void> _doAuth() async {
    final store = DataStoreProvider.of(context);

    // ── 短信登录：POST /api/login/sms（第一轮联调真实接口）──
    // token 自动落 SessionStore（CloudApi.onAuthenticated → 持久化 + 即时生效）
    if (_mode == 'phone') {
      final p = _phoneCtrl.text.trim();
      final c = _codeCtrl.text.trim();
      if (!AuthService.isValidPhone(p)) return _toast('请输入正确的手机号');
      if (c.length != 6) return _toast('请输入 6 位验证码');
      if (!_checkEula()) return;
      if (_busy) return;
      setState(() => _busy = true);
      try {
        final captain = await CloudApi.instance.loginBySms(p, c);
        if (!mounted) return;
        // 本地登录标记（isLoggedIn = captain != null）
        store.login(captain.displayName, 'phone');
        // v2.9.5：云端档案带头像时回填（login 重建对象会丢 avatar）
        if (captain.avatar.isNotEmpty) store.updateAvatar(captain.avatar);
        if (widget.returnTo == 'island') {
          // 岛屿打卡触发的登录 → 返回岛屿详情页继续打卡
          Navigator.of(context).pop();
        } else {
          // 船长闸门触发的登录 → 停留船长 Tab
          appTabIndex.value = 3;
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
        _toast('登船成功 · ${captain.displayName}');
      } on ApiException catch (e) {
        _toast(_friendlyError(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // ── 邮箱登录：POST /api/email/login（Flash 契约，与短信登录完全一致）──
    if (_mode == 'email') {
      final e = _emailCtrl.text.trim();
      final c = _codeCtrl.text.trim();
      if (!AuthService.isValidEmail(e)) return _toast('请输入正确的邮箱');
      if (c.length != 6) return _toast('请输入 6 位验证码');
      if (!_checkEula()) return;
      if (_busy) return;
      setState(() => _busy = true);
      try {
        final captain = await CloudApi.instance.loginByEmail(e, c);
        if (!mounted) return;
        store.login(captain.displayName, 'email');
        // v2.9.5：云端档案带头像时回填（login 重建对象会丢 avatar）
        if (captain.avatar.isNotEmpty) store.updateAvatar(captain.avatar);
        if (widget.returnTo == 'island') {
          Navigator.of(context).pop(); // 岛屿打卡触发 → 回岛屿页继续打卡
        } else {
          appTabIndex.value = 3; // 船长闸门触发 → 停留船长 Tab
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
        _toast('登船成功 · ${captain.displayName}');
      } on ApiException catch (e2) {
        _toast(_friendlyError(e2));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // ── 密码模式：本轮后置，暂保留本地开发模式（TODO 联调 POST /api/login）──
    // v2.9.9：密码登录不走 EULA 勾选闸门（复选框仅短信/邮箱模式渲染，见 build 内 if (_mode != 'password')）
    final n = _acctCtrl.text.trim();
    final p = _passCtrl.text;
    if (n.isEmpty || p.length < 6) return _toast('账号不能为空，密码至少 6 位');
    store.login(n, 'password'); // 本地 flag 模拟登录态
    appTabIndex.value = 3; // 登录成功 → 停留船长 Tab
    Navigator.of(context).popUntil((r) => r.isFirst);
    _toast('登船成功 · $n');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.ocean, behavior: SnackBarBehavior.floating),
    );
  }

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _acctCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController(); // 邮箱模式人机验证答案

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _acctCtrl.dispose();
    _passCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扬帆登船'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(child: Text('GRAND BLUE', style: AppTypography.brand.copyWith(fontSize: 32))),
              const SizedBox(height: 6),
              Center(child: Text('大蓝海 · 自律航海', style: AppTypography.bodySub)),
              const SizedBox(height: 32),
              // 模式切换（短信登录 / 邮箱登录 / 密码登录）
              _buildModeTabs(),
              const SizedBox(height: 24),
              // 表单
              _buildForm(),
              const SizedBox(height: 16),
              // EULA 勾选（短信/邮箱模式强制：未勾选无法获取验证码、无法登录）
              if (_mode != 'password')
                GestureDetector(
                  onTap: () => setState(() => _eulaAccepted = !_eulaAccepted),
                  child: Row(
                    children: [
                      Icon(
                        _eulaAccepted ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 18,
                        color: _eulaAccepted ? AppColors.gold : AppColors.sub,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: '我已阅读并同意 ',
                            style: const TextStyle(color: AppColors.sub, fontSize: 12),
                            children: [
                              WidgetSpan(
                                child: GestureDetector(
                                  // 弹窗「同意并继续」→ 自动勾选；「不同意」/关闭 → 保持原状态不改动
                                  onTap: () async {
                                    final agreed = await EulaDialog.show(context);
                                    if (!mounted || !agreed) return;
                                    setState(() => _eulaAccepted = true);
                                  },
                                  child: const Text(
                                    '《航海守则》',
                                    style: TextStyle(color: AppColors.gold, fontSize: 12, decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                              const TextSpan(text: '，未勾选将无法获取验证码和登录'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _busy ? null : _doAuth, child: const Text('扬帆登船')),
              if (_mode == 'password') ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                  ),
                  child: const Text(
                    '忘记密码？',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.gold, fontSize: 13, decoration: TextDecoration.underline),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    Widget tab(String id, String label) {
      final active = _mode == id;
      return GestureDetector(
        onTap: () {
          setState(() => _mode = id);
          // 切到邮箱模式 → 预取人机验证挑战（challenge 一次性）
          if (id == 'email' && _captchaId.isEmpty) _fetchCaptcha();
        },
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
      Expanded(child: tab('phone', '短信登录')),
      const SizedBox(width: 8),
      Expanded(child: tab('email', '邮箱登录')),
      const SizedBox(width: 8),
      Expanded(child: tab('password', '密码登录')),
    ]);
  }

  Widget _buildForm() {
    if (_mode == 'phone') {
      return Column(children: [
        _Field(label: '手机号 · PHONE', child: TextField(
          controller: _phoneCtrl, keyboardType: TextInputType.phone, maxLength: 11,
          style: const TextStyle(color: AppColors.parchment),
          decoration: const InputDecoration(hintText: '请输入 11 位手机号', counterText: ''),
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
            onPressed: (_countdown > 0 || _busy) ? null : _sendCode,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cardSolid),
            child: Text(_countdown > 0 ? '$_countdown s' : '获取', style: const TextStyle(color: AppColors.gold, fontSize: 13)),
          ),
        ])),
      ]);
    }
    if (_mode == 'email') {
      return Column(children: [
        _Field(label: '邮箱 · EMAIL', child: TextField(
          controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.parchment),
          decoration: const InputDecoration(hintText: 'captain@grandblue.io'),
        )),
        const SizedBox(height: 16),
        // 人机验证（邮箱发码强制要求；算术题 challenge 一次性，点题换新题）
        _Field(label: '人机验证 · CAPTCHA', child: Row(children: [
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: _fetchCaptcha,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardSolid,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  _captchaQuestion.isEmpty ? '点击获取验证题' : _captchaQuestion,
                  style: TextStyle(
                    fontSize: 14,
                    color: _captchaQuestion.isEmpty ? AppColors.sub : AppColors.gold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _captchaCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.parchment),
              decoration: const InputDecoration(hintText: '计算结果'),
            ),
          ),
        ])),
        const SizedBox(height: 16),
        _Field(label: '验证码 · CODE', child: Row(children: [
          Expanded(child: TextField(
            controller: _codeCtrl, keyboardType: TextInputType.number, maxLength: 6,
            style: const TextStyle(color: AppColors.parchment),
            decoration: const InputDecoration(hintText: '6 位验证码', counterText: ''),
          )),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: (_countdown > 0 || _busy) ? null : _sendCode,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cardSolid),
            child: Text(_countdown > 0 ? '$_countdown s' : '发送', style: const TextStyle(color: AppColors.gold, fontSize: 13)),
          ),
        ])),
      ]);
    }
    return Column(children: [
      _Field(label: '账号 · ACCOUNT', child: TextField(
        controller: _acctCtrl,
        style: const TextStyle(color: AppColors.parchment),
        decoration: const InputDecoration(hintText: '手机/邮箱/账号ID'),
      )),
      const SizedBox(height: 16),
      _Field(label: '密码 · PASSWORD', child: TextField(
        controller: _passCtrl, obscureText: true,
        style: const TextStyle(color: AppColors.parchment),
        decoration: const InputDecoration(hintText: '至少 6 位'),
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
