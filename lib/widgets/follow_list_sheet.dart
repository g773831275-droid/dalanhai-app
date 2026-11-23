import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../pages/user_profile_page.dart';
import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../theme/colors.dart';
import '../widgets/user_avatar.dart';

/// 关注/粉丝列表底部弹窗（v2.9.6，仅展示 —— 需求禁止分组/筛选/搜索/批量操作）。
///
/// [isFollowers] true=粉丝列表 / false=关注列表；分页触底加载。
/// 黑名单列表请用 [showBlocklistSheet]（带解除拉黑操作）。
Future<void> showFollowListSheet(
  BuildContext context, {
  required int uid,
  required bool isFollowers,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _UserListSheet(
      uid: uid,
      isFollowers: isFollowers,
      title: isFollowers ? '粉丝 · FOLLOWERS' : '关注 · FOLLOWING',
    ),
  );
}

/// 状态文案判断（关注/粉丝弹窗共用同一套规则，依据后端逐条返回的两个字段）：
/// - isMyFollow && isFollowMe  → 已互相关注
/// - isMyFollow && !isFollowMe → 已关注
/// - !isMyFollow && isFollowMe → 关注了你（粉丝弹窗专用）
/// 其余组合（两个弹窗按定义不会出现）返回 null，不显示副标题。
String? followStatusLabel(CloudUserEntry e, {required bool isFollowers}) {
  if (e.isMyFollow && e.isFollowMe) return '已互相关注';
  if (e.isMyFollow) return '已关注';
  if (isFollowers && e.isFollowMe) return '关注了你';
  return null;
}

/// 黑名单列表底部弹窗（账号设置子页用；支持单项解除拉黑）
Future<void> showBlocklistSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _BlocklistSheet(),
  );
}

class _UserListSheet extends StatefulWidget {
  const _UserListSheet({
    required this.uid,
    required this.isFollowers,
    required this.title,
  });

  final int uid;
  final bool isFollowers;
  final String title;

  @override
  State<_UserListSheet> createState() => _UserListSheetState();
}

class _UserListSheetState extends State<_UserListSheet> {
  final ScrollController _ctrl = ScrollController();
  final List<CloudUserEntry> _list = <CloudUserEntry>[];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _reachedEnd = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _ctrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_ctrl.position.pixels > _ctrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// DEBUG：打印解析后的关注关系布尔值（release 包自动剔除）
  void _debugLogParsed(PagedUsers r) {
    if (kReleaseMode) return;
    for (final e in r.list) {
      debugPrint('[FollowList][parsed] ${widget.isFollowers ? 'followers' : 'following'}'
          ' uid=${e.uid} name=${e.displayName}'
          ' isMyFollow=${e.isMyFollow} isFollowMe=${e.isFollowMe}'
          ' label=${followStatusLabel(e, isFollowers: widget.isFollowers)}');
    }
  }

  Future<void> _loadFirst() async {
    try {
      final PagedUsers r = widget.isFollowers
          ? await CloudApi.instance.fetchFollowers(widget.uid)
          : await CloudApi.instance.fetchFollowing(widget.uid);
      if (!mounted) return;
      _debugLogParsed(r);
      setState(() {
        _total = r.total;
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
    final page = (_list.length / 20).floor() + 1;
    try {
      final PagedUsers r = widget.isFollowers
          ? await CloudApi.instance.fetchFollowers(widget.uid, page: page)
          : await CloudApi.instance.fetchFollowing(widget.uid, page: page);
      if (!mounted) return;
      _debugLogParsed(r);
      final known = _list.map((e) => e.uid).toSet();
      setState(() {
        _list.addAll(r.list.where((e) => !known.contains(e.uid)));
        _reachedEnd = !r.hasMore;
      });
    } on ApiException {
      // 追加失败静默（下次触底再试）
    } finally {
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cardSolid, AppColors.abyss],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${widget.title} · $_total',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20, color: AppColors.sub),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.line, height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
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
          '🌊\n这片海域还没有水手',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13, height: 2),
        ),
      );
    }
    return ListView.separated(
      controller: _ctrl,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _list.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(color: AppColors.line, height: 1, indent: 16),
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
        final e = _list[i];
        final label = followStatusLabel(e, isFollowers: widget.isFollowers);
        return ListTile(
          // 点头像/整行 → 他人主页（传自己的 uid 时页面自动为访客视角预览）
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserProfilePage(uid: e.uid)),
          ),
          leading: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
            child: UserAvatar(avatar: e.avatar, fallbackText: e.displayName, size: 40, fontSize: 17),
          ),
          title: Text(e.displayName,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          subtitle: label == null
              ? null
              : Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        );
      },
    );
  }
}

class _BlocklistSheet extends StatefulWidget {
  const _BlocklistSheet();

  @override
  State<_BlocklistSheet> createState() => _BlocklistSheetState();
}

class _BlocklistSheetState extends State<_BlocklistSheet> {
  final ScrollController _ctrl = ScrollController();
  final List<CloudUserEntry> _list = <CloudUserEntry>[];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _reachedEnd = false;
  int _unblockingUid = 0; // 解除中的条目
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _ctrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_ctrl.position.pixels > _ctrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    try {
      final r = await CloudApi.instance.fetchBlocklist();
      if (!mounted) return;
      setState(() {
        _total = r.total;
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
    final page = (_list.length / 20).floor() + 1;
    try {
      final r = await CloudApi.instance.fetchBlocklist(page: page);
      if (!mounted) return;
      final known = _list.map((e) => e.uid).toSet();
      setState(() {
        _list.addAll(r.list.where((e) => !known.contains(e.uid)));
        _reachedEnd = !r.hasMore;
      });
    } on ApiException {
      // 静默重试
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _unblock(CloudUserEntry e) async {
    setState(() => _unblockingUid = e.uid);
    try {
      await CloudApi.instance.unblockUser(e.uid);
      if (!mounted) return;
      setState(() {
        _list.removeWhere((x) => x.uid == e.uid);
        _total = (_total - 1).clamp(0, 1 << 31);
        _unblockingUid = 0;
      });
      _toast('已解除拉黑（关注关系需手动重新关注）');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _unblockingUid = 0);
      _toast(err.message);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          backgroundColor: AppColors.cardSolid,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cardSolid, AppColors.abyss],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('黑名单 · BLOCKLIST · $_total',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20, color: AppColors.sub),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.line, height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
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
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13, height: 2),
        ),
      );
    }
    return ListView.separated(
      controller: _ctrl,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _list.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(color: AppColors.line, height: 1, indent: 16),
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
        final e = _list[i];
        final busy = _unblockingUid == e.uid;
        return ListTile(
          leading: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
            child: UserAvatar(avatar: e.avatar, fallbackText: e.displayName, size: 40, fontSize: 17),
          ),
          title: Text(e.displayName,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          trailing: GestureDetector(
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
        );
      },
    );
  }
}
