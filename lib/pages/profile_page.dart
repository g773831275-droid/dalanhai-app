import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';

/// 个人资料页 · 修改昵称（PATCH /api/user/nickname v1.1）
/// 规则：1-12 字符（中/英/数字均计 1）；空串/全空格 = 清空昵称；
/// 保存成功后本地船长名同步为新 displayName（昵称优先 → 船长{id}），全站实时生效。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nickCtrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  int _uid = 0; // 云端用户 id（displayName 回退拼接用）

  /// 输入框下方内联报错（v2.9.5 统一规范：红色 #ef4444，
  /// 审核失败用固定文案；输入内容变更即自动清除）
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nickCtrl.addListener(_onInputChanged);
    _load();
  }

  @override
  void dispose() {
    _nickCtrl.removeListener(_onInputChanged);
    _nickCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_errorText != null) setState(() => _errorText = null);
  }

  Future<void> _load() async {
    try {
      final me = await CloudApi.instance.fetchMe();
      if (!mounted) return;
      _uid = me.id;
      _nickCtrl.text = me.nickname;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败：${e.message}'), backgroundColor: AppColors.coral, behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// displayName 固化规则（与 CloudAuthor/CloudCaptain 同口径）
  String _displayName(String? nickname) =>
      (nickname != null && nickname.trim().isNotEmpty) ? nickname : '船长$_uid';

  Future<void> _save() async {
    if (_busy || _loading) return;
    // 输入框留空 = 清空昵称（后端把 null/空串/全空格统一清洗为 null）
    final input = _nickCtrl.text.trim();
    final nickname = input.isEmpty ? null : input;
    if (nickname != null && nickname.characters.length > 12) {
      setState(() => _errorText = '昵称长度需要在1-12字符之间');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await CloudApi.instance.updateNickname(nickname);
      if (!mounted) return;
      // 本地船长名同步为新 displayName（islands 卡片/船长页/证书墙实时生效）。
      // ⚠️ 必须用 updateNickname（只改 name 不重建 Captain）——
      // 旧实现走 login() 重建对象丢 avatar，改昵称后头像被重置为默认
      final store = DataStoreProvider.of(context);
      if (store.isLoggedIn) {
        store.updateNickname(_displayName(r.nickname));
      }
      _toast(r.nickname == null ? '昵称已清空 · 展示为 船长$_uid' : '昵称已保存 · ${_displayName(r.nickname)}');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      // v2.9.5 统一规范：文本输入类报错一律内联展示在输入框下方（不再用浮条）。
      // 审核失败用固定文案；其余（超长/网络等）用后端原文。
      // ⚠️ 失败分支禁止 fetchMe / 禁止以任何形式覆盖本地 Captain —— 
      // 接口失败即本地 user 保持提交前状态（avatar/nickname 原样），只展示报错。
      setState(() {
        _errorText =
            e.message.contains('安全审核') ? '昵称未通过安全审核，请修改后再试' : e.message;
      });
    } catch (_) {
      if (mounted) setState(() => _errorText = '网络不可用，请稍后再试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.cardSolid, behavior: SnackBarBehavior.floating),
    );
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
        title: const Text('个人资料', style: TextStyle(color: AppColors.parchment, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                const Text('昵称 · NICKNAME', style: TextStyle(color: AppColors.sub, fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSolid,
                    borderRadius: BorderRadius.circular(12),
                    // 报错时边框转红（v2.9.5 统一规范），否则保持金色描边
                    border: Border.all(
                      color: _errorText != null
                          ? const Color(0xFFEF4444)
                          : const Color(0x33E8B84A),
                    ),
                  ),
                  child: TextField(
                    controller: _nickCtrl,
                    maxLength: 12,
                    style: const TextStyle(color: AppColors.parchment, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: '1-12 字符，留空保存 = 清空昵称',
                      hintStyle: TextStyle(color: AppColors.sub, fontSize: 13),
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                // 内联报错：紧贴输入框下方（红色 #ef4444，改内容自动清除）
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 15),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                const Text(
                  '未设置昵称时将展示「船长+编号」；修改后帖子、评论、船长页实时生效',
                  style: TextStyle(color: AppColors.sub, fontSize: 11, height: 1.6),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.goldBtnText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldBtnText))
                        : const Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
    );
  }
}
