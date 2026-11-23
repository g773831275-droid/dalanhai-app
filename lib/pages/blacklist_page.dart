import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../theme/colors.dart';
import '../widgets/alert_toast.dart';
import '../widgets/user_avatar.dart';

/// 黑名单管理页（v2.9.6 账号设置 →【黑名单管理】入口路由页）。
///
/// 分页加载 + 单项解除拉黑；解除仅恢复双向浏览/关注权限，
/// 不自动恢复拉黑前的关注/粉丝关系（需手动重新关注）。
class BlacklistPage extends StatefulWidget {
  const BlacklistPage({super.key});

  @override
  State<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends State<BlacklistPage> {
  final ScrollController _scrollCtrl = ScrollController();
  final List<CloudUserEntry> _list = <CloudUserEntry>[];
  bool _loading = true;
  bool _reachedEnd = false;
  bool _loadingMore = false;
  int _unblockingUid = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    try {
      final r = await CloudApi.instance.fetchBlocklist();
      if (!mounted) return;
      setState(() {
        _list.addAll(r.list);
        _reachedEnd = !r.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _reachedEnd || _loading) return;
    _loadingMore = true;
    try {
      final r = await CloudApi.instance
          .fetchBlocklist(page: (_list.length / 20).floor() + 1);
      if (!mounted) return;
      final known = _list.map((e) => e.uid).toSet();
      setState(() {
        _list.addAll(r.list.where((e) => !known.contains(e.uid)));
        _reachedEnd = !r.hasMore;
      });
    } on ApiException {
      // 追加失败静默（触底再试）
    } finally {
      _loadingMore = false;
    }
  }

  /// 解除拉黑（仅恢复双向浏览/关注权限；不自动恢复原有关注/粉丝关系）
  Future<void> _unblock(CloudUserEntry e) async {
    setState(() => _unblockingUid = e.uid);
    try {
      await CloudApi.instance.unblockUser(e.uid);
      if (!mounted) return;
      setState(() {
        _list.removeWhere((x) => x.uid == e.uid);
        _unblockingUid = 0;
      });
      _toast('已解除拉黑（拉黑前的关注/粉丝关系不会自动恢复，需手动重新关注）');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _unblockingUid = 0);
      showAlertToast(context, err.message);
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
        title: const Text('黑名单管理',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      );
    }
    if (_list.isEmpty) {
      return const Center(
        child: Text(
          '🏴‍☠️\n黑名单空空如也，一帆风顺',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 14, height: 2),
        ),
      );
    }
    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
      itemCount: _list.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i >= _list.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
          );
        }
        return _blockRow(_list[i]);
      },
    );
  }

  Widget _blockRow(CloudUserEntry e) {
    final busy = _unblockingUid == e.uid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x8C123A6B), Color(0xB30A1F3D)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
            child: UserAvatar(avatar: e.avatar, fallbackText: e.displayName, size: 40, fontSize: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(e.displayName,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ),
          GestureDetector(
            onTap: busy ? null : () => _unblock(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                  : const Text('解除拉黑',
                      style: TextStyle(color: AppColors.gold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
