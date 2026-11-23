import 'package:flutter/material.dart';

import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';
import '../services/cloud_feed.dart' show kCloudFeedRefreshSignal;
import '../theme/colors.dart';
import '../widgets/alert_toast.dart';
import '../widgets/avatar_upload.dart';
import '../widgets/user_avatar.dart';

/// 编辑资料页（v2.9.6，需求三.1：支持修改头像、昵称、简介）。
///
/// 入口：船长 Tab（本人管理视角）→【编辑资料】按钮。
/// 报错规范（v2.9.5）：文本输入类 → 输入框下方内联红字 + 边框转红，
/// 内容变更自动清除；头像上传类 → showAlertToast 醒目提示。
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nickCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  int _uid = 0;
  String? _avatarKey; // 当前头像 OSS key（上传成功即时更新）

  String? _nickError;
  String? _bioError;

  @override
  void initState() {
    super.initState();
    _nickCtrl.addListener(() => _clearErr(true));
    _bioCtrl.addListener(() => _clearErr(false));
    _load();
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _clearErr(bool isNick) {
    if (isNick && _nickError != null) setState(() => _nickError = null);
    if (!isNick && _bioError != null) setState(() => _bioError = null);
  }

  Future<void> _load() async {
    try {
      final me = await CloudApi.instance.fetchMe();
      if (!mounted) return;
      var nickname = me.nickname.trim();
      var avatar = me.avatar;
      var bio = '';
      // /api/user/me 不下发 bio（flashCaptain 早期结构），简介回显补拉
      // /api/user/:uid/profile（v2.9.6 既有接口，含 bio）；该请求失败不阻塞
      // 页面打开（bio 留空、沿用 me 的昵称/头像）
      try {
        final p = await CloudApi.instance.fetchUserProfile(me.id);
        if (p.nickname != null && p.nickname!.trim().isNotEmpty) {
          nickname = p.nickname!.trim();
        }
        final pa = p.avatar;
        if (pa != null && pa.isNotEmpty) avatar = pa;
        bio = (p.bio ?? '').trim();
      } on ApiException catch (_) {
        // 静默：编辑页仍可打开，简介留空可继续编辑
      }
      if (!mounted) return;
      setState(() {
        _uid = me.id;
        _avatarKey = avatar;
        _nickCtrl.text = nickname;
        _bioCtrl.text = bio;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAlertToast(context, '加载失败：${e.message}');
    }
  }

  /// 换头像：uploadAvatarFlow（选图→裁剪→压缩→直传→后端审核）
  Future<void> _changeAvatar() async {
    final newKey = await uploadAvatarFlow(context);
    if (newKey == null) return; // 取消或失败（失败已弹 Toast，流程终止不更新本地）
    if (!mounted) return;
    setState(() => _avatarKey = newKey);
    // 本地船长头像更新 + 全局 feed 刷新（与船长页换头像口径一致）
    final store = DataStoreProvider.of(context);
    if (store.isLoggedIn) {
      store.updateAvatar(newKey);
      kCloudFeedRefreshSignal.value++;
    }
    _toast('头像已更新');
  }

  Future<void> _save() async {
    if (_busy || _loading) return;
    // ── 前端校验（与后端口径一致）──
    final nickname = _nickCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    if (nickname.isNotEmpty && nickname.characters.length > 12) {
      setState(() => _nickError = '昵称长度需要在1-12字符之间');
      return;
    }
    if (bio.length > 100) {
      setState(() => _bioError = '简介最长 100 字');
      return;
    }
    setState(() => _busy = true);
    try {
      // 昵称：留空=清空 → PATCH /api/user/nickname null（updateProfile 不接受空串）；
      // 非空 → POST /api/user/profile（送审落库）
      final nickResult = nickname.isEmpty
          ? await CloudApi.instance.updateNickname(null)
          : null;
      if (nickname.isNotEmpty) {
        await CloudApi.instance.updateProfile(nickname: nickname);
      }
      // 简介：始终提交（空串 = 清空）
      await CloudApi.instance.updateProfile(bio: bio.isEmpty ? '' : bio);
      if (!mounted) return;
      // 本地船长名同步为 displayName（昵称优先 → 船长{id}）
      final store = DataStoreProvider.of(context);
      if (store.isLoggedIn) {
        final effectiveNick = nickname.isEmpty
            ? nickResult?.nickname
            : nickname;
        store.updateNickname(
            (effectiveNick != null && effectiveNick.trim().isNotEmpty)
                ? effectiveNick
                : '船长$_uid');
        kCloudFeedRefreshSignal.value++;
      }
      _toast('资料已保存');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.contains('昵称') && e.message.contains('审核')) {
        setState(() => _nickError = '昵称未通过安全审核，请修改后再试');
      } else if (e.message.contains('简介') && e.message.contains('审核')) {
        setState(() => _bioError = '简介未通过安全审核，请修改后再试');
      } else if (e.message.contains('昵称长度')) {
        setState(() => _nickError = e.message);
      } else if (e.message.contains('bio 最长')) {
        setState(() => _bioError = '简介最长 100 字');
      } else {
        showAlertToast(context, e.message);
      }
    } catch (_) {
      if (mounted) showAlertToast(context, '网络不可用，请稍后再试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          backgroundColor: AppColors.cardSolid,
          behavior: SnackBarBehavior.floating),
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
        title: const Text('编辑资料',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                // ── 头像（点击更换，与船长页同流程）──
                Center(
                  child: GestureDetector(
                    onTap: _changeAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.goldLight, AppColors.copper],
                            ),
                            border: Border.all(color: const Color(0x99E8B84A), width: 2),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: ClipOval(
                            child: UserAvatar(
                              avatar: _avatarKey,
                              fallbackText: '船长$_uid',
                              size: 80,
                              fontSize: 36,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppColors.goldLight, AppColors.copper],
                              ),
                              border: Border.all(color: AppColors.abyss, width: 2),
                            ),
                            child: const Center(
                                child: Text('📷', style: TextStyle(fontSize: 12, height: 1))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('点击头像更换', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                ),
                const SizedBox(height: 28),

                // ── 昵称 ──
                const Text('昵称 · NICKNAME',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 10),
                _textField(
                  controller: _nickCtrl,
                  hint: '1-12 字符，留空保存 = 清空昵称',
                  maxLength: 12,
                  errorText: _nickError,
                ),
                _errorRow(_nickError),
                const SizedBox(height: 20),

                // ── 简介 ──
                const Text('简介 · BIO',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 10),
                _textField(
                  controller: _bioCtrl,
                  hint: '介绍一下你的航海计划（≤100 字）',
                  maxLength: 100,
                  errorText: _bioError,
                  maxLines: 4,
                ),
                _errorRow(_bioError),
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
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.goldBtnText))
                        : const Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required String? errorText,
    int maxLines = 1,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 8 : 0),
      decoration: BoxDecoration(
        color: AppColors.cardSolid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorText != null ? const Color(0xFFEF4444) : const Color(0x33E8B84A),
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
          counterText: '',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _errorRow(String? errorText) {
    if (errorText == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 15),
          const SizedBox(width: 5),
          Expanded(
            child: Text(errorText,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
