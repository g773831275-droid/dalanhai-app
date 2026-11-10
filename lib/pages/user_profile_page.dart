import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../services/session_store.dart';
import '../services/social_state.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/cloud_post_card.dart';
import '../widgets/follow_list_sheet.dart';
import '../widgets/profile_sections.dart';
import '../widgets/sail_level_tag.dart';
import '../widgets/social_dialogs.dart';
import '../widgets/user_avatar.dart';

/// 他人主页 / 自身公开访客预览（v2.9.6，同一页面双视角）。
///
/// 视角规则（需求二/四）：
/// - 点击帖子/评论内他人头像 → 进入对应他人主页
/// - 港口页/自己的日志详情页点击自己头像 → 以访客视角预览自己的公开主页
///   （完全等同于他人查看效果：无编辑、无设置、无船员服务菜单）
/// - 仅底部船长 Tab 入口才是本人管理视角（captain_tab.dart）
///
/// 结构：头像区（头像+昵称+航级标签占位+简介）→ 操作按钮行（关注/发消息/···，
/// 自身预览不显示）→ 数据统计栏（关注/粉丝数字可点弹列表）→ 征服证书专区
/// （横向滚动卡片）→ 航海日志流式列表（无 Tab 栏，卡片样式与港口流一致）。
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.uid});

  /// 目标用户云端 id（传自己的 uid 即为访客视角公开预览）
  final int uid;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final CloudApi _api = CloudApi.instance;
  final ScrollController _scrollCtrl = ScrollController();

  CloudUserProfile? _profile;
  final List<CloudPost> _posts = <CloudPost>[];
  int _postsTotal = 0;
  bool _loadingProfile = true;
  bool _loadingPosts = true;
  bool _loadingMore = false;
  bool _reachedEnd = false;
  bool _followBusy = false;
  String? _fatal; // 404（用户不存在/双向拉黑）等整页占位

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPostsFirst();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMorePosts();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _api.fetchUserProfile(widget.uid);
      if (!mounted) return;
      // 关注状态写入全局缓存（详情页/主页双向同步）
      FollowState.instance.set(p.uid, p.following);
      setState(() {
        _profile = p;
        _loadingProfile = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fatal = e.code == 404 ? '该船长已消失在茫茫大海' : e.message;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadPostsFirst() async {
    try {
      final r = await _api.fetchUserPosts(widget.uid);
      if (!mounted) return;
      setState(() {
        _postsTotal = r.total;
        _posts.addAll(r.list);
        _reachedEnd = !r.hasMore;
        _loadingPosts = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingPosts = false); // 日志失败不阻塞整页
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || _reachedEnd || _loadingPosts) return;
    _loadingMore = true;
    final page = (_posts.length / 10).floor() + 1;
    try {
      final r = await _api.fetchUserPosts(widget.uid, page: page);
      if (!mounted) return;
      final known = _posts.map((p) => p.postId).toSet();
      setState(() {
        _postsTotal = r.total;
        _posts.addAll(r.list.where((p) => !known.contains(p.postId)));
        _reachedEnd = !r.hasMore;
      });
    } on ApiException {
      // 追加失败静默（下次触底再试）
    } finally {
      _loadingMore = false;
    }
  }

  // ── 关注 / 取关（FollowState 全局联动：详情页/主页双向实时同步）──
  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    if (!SessionStore.instance.hasToken) {
      _toast('请先登录后再关注其他船长');
      return;
    }
    _followBusy = true;
    try {
      await FollowState.instance.toggle(widget.uid);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.code == 401 ? '登录已失效，请重新登录' : e.message);
    } finally {
      _followBusy = false;
    }
  }

  // ── 拉黑（···菜单 → 标准二次确认弹窗）──
  Future<void> _block() async {
    final ok = await showBlockConfirmDialog(context);
    if (ok != true) return;
    if (!SessionStore.instance.hasToken) {
      _toast('请先登录后再操作');
      return;
    }
    try {
      await _api.blockUser(widget.uid);
      if (!mounted) return;
      _toast('已拉黑，对方内容将不再展示');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  // ── 举报（无需二次确认，直接触发流程；type=user 举报该用户）──
  Future<void> _reportUser() async {
    final reason = await _askText('举报该船长', '填写举报原因（≤200 字）');
    if (reason == null || reason.trim().isEmpty) return;
    try {
      final r = await _api.submitReport(
        type: 'user',
        targetId: widget.uid,
        reason: reason.trim(),
      );
      if (!mounted) return;
      _toast(r.duplicated ? '您已提交过举报，正在人工审核中' : '举报已提交，等待人工审核');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  // ── ··· 菜单（举报/拉黑/取消；拉黑弹专属二次确认）──
  Future<void> _showMoreMenu() async {
    final action = await showMoreActionsSheet(
      context,
      nickname: _profile?.displayName ?? '该船长',
    );
    if (!mounted || action == null) return;
    if (action == 'report') {
      await _reportUser();
    } else if (action == 'block') {
      await _block();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.ocean,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _askText(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deep,
        title: Text(title, style: const TextStyle(color: AppColors.parchment, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLength: 200,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFEAF2FF)),
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppColors.sub)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('提交', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(children: [
      _buildTopBar(),
      Expanded(child: _buildContent()),
    ]);
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text('船长主页 · PROFILE',
              style: AppTypography.titleZh.copyWith(fontSize: 15),
              textAlign: TextAlign.center),
        ),
        const SizedBox(width: 48),
      ]),
    );
  }

  Widget _buildContent() {
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_fatal != null || _profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌫️', style: TextStyle(fontSize: 44)),
            Text(_fatal ?? '加载失败', style: AppTypography.bodySub),
          ],
        ),
      );
    }
    final p = _profile!;
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(p),
          if (!p.isSelf) _buildActionRow(p),
          const SizedBox(height: 14),
          ProfileStatsGrid(
            stats: p.stats,
            onFollowingTap: () => _openFollowList(p, false),
            onFollowersTap: () => _openFollowList(p, true),
          ),
          const SizedBox(height: 4),
          ProfileSectionTitle('征服证书 · Certificates'),
          ProfileCertGallery(certificates: p.certificates),
          _buildPostsSection(p),
        ],
      ),
    );
  }

  // ── 头像区：圆形头像 + 昵称 + 航级标签占位 + 简介 ──
  Widget _buildHero(CloudUserProfile p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.goldLight, AppColors.copper],
            ),
            border: Border.all(color: const Color(0x99E8B84A), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: ClipOval(
            child: UserAvatar(avatar: p.avatar, fallbackText: p.displayName, size: 68, fontSize: 32),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 昵称 + 航级标签（开关关闭 → showSailLevelTag=false → 完全不渲染）
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(p.displayName,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800,
                          color: Color(0xFFF4FAFF), letterSpacing: 1)),
                  if (p.showSailLevelTag && p.sailLevel != null)
                    SailLevelTag(text: p.sailLevel!),
                ],
              ),
              if (p.bio != null && p.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(p.bio!,
                    style: const TextStyle(color: AppColors.sub, fontSize: 12.5, height: 1.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── 操作按钮行：关注/已关注 + 发消息 + ···（自身预览不显示）──
  Widget _buildActionRow(CloudUserProfile p) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          // 关注/已关注（金色主按钮，视觉与现有金色按钮统一）
          Expanded(
            child: AnimatedBuilder(
              animation: FollowState.instance,
              builder: (context, _) {
                final following = FollowState.instance.of(p.uid) ?? p.following;
                return GestureDetector(
                  onTap: _followBusy ? null : _toggleFollow,
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: following ? null : AppColors.btnGoldGradient,
                      color: following ? null : null,
                      borderRadius: BorderRadius.circular(999),
                      border: following
                          ? Border.all(color: AppColors.gold.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: following
                        ? const Text('已关注',
                            style: TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w700))
                        : const Text('关注',
                            style: TextStyle(color: AppColors.goldBtnText, fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          // 发消息（本期占位：不新增私信功能，点击引导客服微信）
          Expanded(
            child: GestureDetector(
              onTap: () => _toast('私信功能即将开放，先添加客服微信 abccba978 一起出海'),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x1A7DC4FF)),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99123A6B), Color(0xB30A1F3D)],
                  ),
                ),
                child: const Text('发消息',
                    style: TextStyle(color: Color(0xFFE5EFFA), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ··· 更多（举报/拉黑）
          GestureDetector(
            onTap: _showMoreMenu,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: const Text('···',
                  style: TextStyle(color: AppColors.foam, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  void _openFollowList(CloudUserProfile p, bool followers) {
    showFollowListSheet(context, uid: p.uid, isFollowers: followers);
  }

  // ── 航海日志：流式列表（无 Tab 栏；卡片样式与港口流完全一致）──
  Widget _buildPostsSection(CloudUserProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('航海日志 · SAIL LOG'),
        if (_loadingPosts)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
          )
        else if (_posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('这片海域还很安静，还没有留下航海日志',
                  style: TextStyle(color: AppColors.sub, fontSize: 13)),
            ),
          )
        else ...[
          ..._posts.map((post) => CloudPostCard(
                post: post,
                onAvatarTap: (author) => _openProfile(author.uid),
              )),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _loadingMore
                    ? '正在打捞更多日志…'
                    : _reachedEnd
                        ? '已经到底啦 · 共 $_postsTotal 条'
                        : '',
                style: const TextStyle(fontSize: 11, color: AppColors.sub),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openProfile(int uid) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
    );
  }
}
