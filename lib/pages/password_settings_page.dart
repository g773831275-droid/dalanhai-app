import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../theme/colors.dart';

/// 密码设置页（v2.9.9，入口：账号设置【我的账号】分组【密码设置】卡片）。
///
/// 功能：输入新密码（默认掩码，右侧小眼睛切换明文/密文）→ 前置校验
/// （非空 + 长度 ≥6，不通过 toast 不发请求）→ PATCH /api/user/set-password
/// （JWT，后端 bcrypt 加密入库）→ toast 密码设置成功 → 自动返回账号设置页。
/// 页面仅 18+ 字段级输入，无其他副作用；深色主题沿用 AppColors 规范。
class PasswordSettingsPage extends StatefulWidget {
  const PasswordSettingsPage({super.key});

  @override
  State<PasswordSettingsPage> createState() => _PasswordSettingsPageState();
}

class _PasswordSettingsPageState extends State<PasswordSettingsPage> {
  final _passCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _obscure = true; // 默认掩码隐藏
  bool _submitting = false; // 防重复提交

  @override
  void dispose() {
    _passCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: error ? AppColors.coral : AppColors.ocean,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final p = _passCtrl.text;
    // 前置校验：密码不能为空、长度 ≥6；不通过 toast 提示，不请求后端
    if (p.isEmpty) return _toast('密码不能为空');
    if (p.length < 6) return _toast('密码至少 6 位');
    setState(() => _submitting = true);
    try {
      await CloudApi.instance.setPassword(p);
      if (!mounted) return;
      _toast('密码设置成功', error: false);
      Navigator.of(context).pop(); // 成功 → 自动返回账号设置页
    } on ApiException catch (e) {
      _toast(e.message); // 401 登录失效 / 400 密码至少 6 位（后端兜底）等
    } catch (_) {
      _toast('设置失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.parchment),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('密码设置',
            style: TextStyle(color: AppColors.parchment, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
          children: [
            // 说明文案（与账号设置分组标题同款金色小字风格）
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text('设置登录密码 · PASSWORD',
                  style: TextStyle(color: AppColors.gold, fontSize: 12, letterSpacing: 2)),
            ),
            // 密码输入卡片（容器样式与账号设置条目同款：圆角14/渐变/细边框）
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1A7DC4FF)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99123A6B), Color(0xB30A1F3D)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _passCtrl,
                  focusNode: _focusNode,
                  autofocus: true,
                  obscureText: _obscure, // 默认掩码 * 隐藏内容
                  maxLength: 40,
                  style: const TextStyle(color: Color(0xFFE5EFFA), fontSize: 14, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: '请输入新密码（至少 6 位）',
                    hintStyle: const TextStyle(color: AppColors.sub, fontSize: 13),
                    counterText: '',
                    border: InputBorder.none,
                    // 小眼睛：点击切换明文/密文
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: AppColors.sub,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 提交按钮（金色主按钮，风格对齐登录页「扬帆登船」）
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF0A1F3D),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_submitting ? '设置中…' : '保存密码',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
