import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';
import '../services/cloud_feed.dart';
import '../services/cloud_models.dart';
import '../services/social_state.dart';
import '../theme/colors.dart';
import '../widgets/cloud_post_card.dart';
import '../widgets/follow_list_sheet.dart';
import '../widgets/profile_sections.dart';
import '../widgets/sail_level_tag.dart';
import '../widgets/alert_toast.dart';
import '../widgets/avatar_upload.dart';
import '../widgets/user_avatar.dart';
import '../pages/account_settings_page.dart';
import '../pages/edit_profile_page.dart';
import '../pages/user_profile_page.dart';

/// 船长 Tab — 本人管理视角（v2.9.6 改造，需求三）
///
/// 页面结构（自上而下）：
/// ① 头像简介区：头像(点击换) + 昵称 + 航级标签占位(开关控制) + 简介 +【编辑资料】
/// ② 数据统计栏：航海日志/关注/粉丝 + 累计打卡/最长连续登岛（关注/粉丝可点弹列表）
/// ③ 征服证书专区：横向滚动卡片（复用打卡/证书数据，无证书海盗旗占位）
/// ④ 航海日志 / SAIL LOG 双 Tab：我的日志 | 点赞的日志（Tab 样式参照船员服务菜单；
///    解决日志过多导致底部服务菜单下沉难以触达的问题）
/// ⑤ 船员服务菜单（单一组）：联系船务长 · 打卡提醒 · 账号设置（子页含黑名单/隐私/登出）
///
/// 视角规则（需求四）：仅底部船长 Tab 入口是本人管理视角；
/// 头像在港口/详情页点击一律进访客视角主页（UserProfilePage）。
class CaptainTab extends StatefulWidget {
  const CaptainTab({super.key});

  /// 打卡通知后的去抖间隔（生产 600ms 防连击；测试可置零即时刷新）
  @visibleForTesting
  static Duration refreshDebounce = const Duration(milliseconds: 600);

  @override
  State<CaptainTab> createState() => _CaptainTabState();
}

class _CaptainTabState extends State<CaptainTab> {
  static const int _size = 10;

  final ScrollController _scrollCtrl = ScrollController();
  CloudUserProfile? _profile;

  // 双 Tab（false=我的日志 / true=点赞的日志）
  bool _likedTab = false;
  final List<CloudPost> _myPosts = <CloudPost>[];
  final List<CloudPost> _likedPosts = <CloudPost>[];
  int _myTotal = 0;
  int _likedTotal = 0;
  bool _myReachedEnd = false;
  bool _likedReachedEnd = false;
  bool _loadingPosts = false;
  bool _loadingMore = false;

  // v2.9.6 修复：打卡统计实时联动（对齐旧 H5「打卡 → 全局通知 → 统计重算」语义）
  // DataStore 打卡成功后 syncIslandCheckins 会 notifyListeners；本页在
  // IndexedStack 常驻不重建，必须主动订阅才不会卡死在首次快照。
  DataStore? _boundStore;
  Timer? _profileDebounce;

  // ── v2.9.8 长按菜单 / 置顶 / 批量删除（仅「我的日志」Tab）──
  bool _batchMode = false; // 批量选择模式
  bool _topBusy = false; // 置顶/批量删除请求防抖
  final Set<int> _selectedIds = <int>{}; // 批量模式已勾选 postId

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPosts();
    _scrollCtrl.addListener(_onScroll);
    // 关注/取关发生在他人主页或日志详情页 → FollowState 通知 → 计数重拉。
    // 本页在 IndexedStack 常驻，不订阅就会卡死在首次快照（计数与弹窗错位）。
    FollowState.instance.addListener(_onStoreChanged);
    // 详情页删除日志 → 全局信号 → 重拉日志列表（本页常驻不重建）
    kPostDeletedSignal.addListener(_onPostDeleted);
    // 详情页发评论/删评论 → 全局信号 → 重拉日志列表（评论计数对齐）
    kCommentCountChangedSignal.addListener(_onCommentCountChanged);
  }

  void _onCommentCountChanged() {
    _loadPosts(); // 重拉后 comment_count 与详情/港口一致
  }

  void _onPostDeleted() {
    _myPosts.clear();
    _myTotal = 0;
    _myReachedEnd = false;
    _loadPosts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // initState 里不能 dependOnInheritedWidget → 首帧后订阅一次
    final store = DataStoreProvider.of(context);
    if (_boundStore != store) {
      _boundStore?.removeListener(_onStoreChanged);
      _boundStore = store;
      store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    _profileDebounce?.cancel();
    _boundStore?.removeListener(_onStoreChanged);
    FollowState.instance.removeListener(_onStoreChanged);
    kPostDeletedSignal.removeListener(_onPostDeleted);
    kCommentCountChangedSignal.removeListener(_onCommentCountChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// DataStore 变化（打卡同步 / 登录 / 登出）→ 去抖重拉云端统计。
  /// 去抖防连击：打卡弹窗期间多次 notify 只发一次请求；刷新期间旧值继续展示不闪 0。
  void _onStoreChanged() {
    _profileDebounce?.cancel();
    _profileDebounce = Timer(CaptainTab.refreshDebounce, _loadProfile);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<int> _myUid() => MeState.instance.uid();

  Future<void> _loadProfile() async {
    try {
      final uid = await _myUid();
      final p = await CloudApi.instance.fetchUserProfile(uid);
      if (!mounted) return;
      setState(() => _profile = p);
    } on ApiException {
      // 主页数据加载失败静默（未登录/网络异常时保持现值，下次通知再试；
      // 统计/证书保持占位，日志列表独立加载）
      // 终态兜底：若此前从未成功加载过，置空 profile 终止证书区转圈，
      // 避免 loading 永久卡死（请求超时后 UI 必须可达可交互）
      if (!mounted || _profile != null) return;
      setState(() {
        _profile = CloudUserProfile(
            uid: 0, isSelf: true, stats: const CloudProfileStats());
      });
    }
  }

  List<CloudPost> get _currentPosts => _likedTab ? _likedPosts : _myPosts;

  Future<void> _loadPosts() async {
    if (_loadingPosts) return;
    setState(() => _loadingPosts = true);
    try {
      final uid = await _myUid();
      final r = _likedTab
          ? await CloudApi.instance.fetchLikedPosts(size: _size)
          : await CloudApi.instance.fetchUserPosts(uid, size: _size);
      if (!mounted) return;
      setState(() {
        if (_likedTab) {
          _likedPosts
            ..clear()
            ..addAll(r.list);
          _likedTotal = r.total;
          _likedReachedEnd = !r.hasMore;
        } else {
          _myPosts
            ..clear()
            ..addAll(r.list);
          _myTotal = r.total;
          _myReachedEnd = !r.hasMore;
        }
        _loadingPosts = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingPosts = false);
      showAlertToast(context, e.message);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loadingPosts) return;
    final posts = _currentPosts;
    final reachedEnd = _likedTab ? _likedReachedEnd : _myReachedEnd;
    if (reachedEnd) return;
    _loadingMore = true;
    final page = (posts.length / _size).floor() + 1;
    try {
      final uid = await _myUid();
      final r = _likedTab
          ? await CloudApi.instance.fetchLikedPosts(page: page, size: _size)
          : await CloudApi.instance.fetchUserPosts(uid, page: page, size: _size);
      if (!mounted) return;
      final known = posts.map((p) => p.postId).toSet();
      setState(() {
        final fresh = r.list.where((p) => !known.contains(p.postId)).toList();
        if (_likedTab) {
          _likedPosts.addAll(fresh);
          _likedTotal = r.total;
          _likedReachedEnd = !r.hasMore;
        } else {
          _myPosts.addAll(fresh);
          _myTotal = r.total;
          _myReachedEnd = !r.hasMore;
        }
      });
    } on ApiException {
      // 追加失败静默（触底再试）
    } finally {
      _loadingMore = false;
    }
  }

  /// 切换双 Tab：清空目标列表重拉（切换流畅、数据准确无重复）
  void _switchTab(bool liked) {
    if (_likedTab == liked) return;
    setState(() {
      _likedTab = liked;
      // 切 Tab 退出批量模式（批量仅限我的日志）
      _batchMode = false;
      _selectedIds.clear();
    });
    _loadPosts();
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // ── v2.9.8 长按菜单 / 置顶 / 批量删除 ─────────────────────

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          backgroundColor: AppColors.cardSolid,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200)),
    );
  }

  /// 长按「我的日志」单条日志 → 底部弹出操作菜单（Sheet 垂直排列 + 固定取消）
  Future<void> _showPostMenu(CloudPost post) async {
    if (_batchMode || _likedTab || _topBusy) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.deep,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetItem(
                post.isTop ? '取消置顶' : '置顶该日志',
                () => Navigator.pop(context, 'top')),
            _sheetItem('批量删除', () => Navigator.pop(context, 'batch')),
            _sheetItem('取消', () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'top') {
      await _toggleTop(post);
    } else if (action == 'batch') {
      setState(() {
        _batchMode = true;
        _selectedIds.clear();
      });
    }
  }

  Widget _sheetItem(String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: color ?? const Color(0xFFEAF2FF),
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// 置顶状态乐观回显：立即改本地列表（isTop + 排序），不等网络刷新。
  /// 排序规则与后端一致：is_top DESC, id DESC。
  void _applyTopLocally(int postId, bool top) {
    setState(() {
      final updated = _myPosts
          .map((p) => p.postId == postId ? p.copyWith(isTop: top) : (top ? p.copyWith(isTop: false) : p))
          .toList()
        ..sort((a, b) {
          if (a.isTop != b.isTop) return a.isTop ? -1 : 1;
          return b.postId.compareTo(a.postId);
        });
      _myPosts
        ..clear()
        ..addAll(updated);
    });
  }

  /// 置顶 / 取消置顶。置顶第二条时弹替换确认（确认后后端自动清旧置顶）。
  /// 无论成功失败（含超时），finally 释放 _topBusy，长按菜单始终可再次唤起。
  Future<void> _toggleTop(CloudPost post) async {
    if (_topBusy) return;
    final nowTop = !post.isTop;
    if (!post.isTop) {
      final hasOtherPinned =
          _myPosts.any((p) => p.isTop && p.postId != post.postId);
      if (hasOtherPinned) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.deep,
            title: Text('替换置顶',
                style: const TextStyle(color: AppColors.parchment, fontSize: 16)),
            content: Text('最多只能置顶1条日志，是否替换置顶？',
                style: const TextStyle(color: AppColors.sub, fontSize: 13)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('确认',
                      style: TextStyle(color: AppColors.gold))),
            ],
          ),
        );
        if (ok != true || !mounted) return;
      }
    }
    _topBusy = true;
    try {
      await CloudApi.instance.setPostTop(post.postId, isTop: nowTop);
      if (!mounted) return;
      _applyTopLocally(post.postId, nowTop); // 标签/排序即时回显
      _toast(nowTop ? '已置顶该日志' : '已取消置顶');
      unawaited(_loadPosts()); // 后台对账刷新；失败由其内部 toast，不阻塞交互
    } on ApiException catch (e) {
      if (!mounted) return;
      showAlertToast(context, e.code == 403 ? '只有日志作者可以置顶' : e.message);
    } finally {
      _topBusy = false;
    }
  }

  void _toggleSelect(int postId) {
    setState(() {
      if (!_selectedIds.add(postId)) _selectedIds.remove(postId);
    });
  }

  bool get _allLoadedSelected =>
      _myPosts.isNotEmpty &&
      _myPosts.every((p) => _selectedIds.contains(p.postId));

  /// 全选 / 取消全选（针对已加载的我的日志）
  void _toggleSelectAll() {
    setState(() {
      if (_allLoadedSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_myPosts.map((p) => p.postId));
      }
    });
  }

  Future<void> _exitBatchMode() async {
    setState(() {
      _batchMode = false;
      _selectedIds.clear();
    });
  }

  /// 批量删除：二次确认 → 批量接口 → 刷新列表（删置顶帖后端自动清置顶标记）
  Future<void> _deleteSelected() async {
    if (_topBusy || _selectedIds.isEmpty) {
      _toast('请先勾选要删除的日志');
      return;
    }
    final n = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deep,
        title: Text('批量删除',
            style: const TextStyle(color: AppColors.parchment, fontSize: 16)),
        content: Text('确定删除选中$n条日志？删除后不可恢复',
            style: const TextStyle(color: AppColors.sub, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除',
                  style: TextStyle(color: AppColors.coral))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _topBusy = true;
    try {
      final ids = _selectedIds.toList();
      final deleted = await CloudApi.instance.batchDeletePosts(ids);
      if (!mounted) return;
      _toast('已删除 $deleted 条日志');
      kCloudFeedRefreshSignal.value++; // 港口流计数同步
      await _exitBatchMode();
      await _loadPosts();
      await _loadProfile(); // 日志数统计同步
    } on ApiException catch (e) {
      if (!mounted) return;
      showAlertToast(context, e.code == 403 ? '只能删除自己的日志' : e.message);
    } finally {
      _topBusy = false;
    }
  }

  // ── v2.9.5 头像修改全流程（仅本人：船长 Tab 登录闸门保证）──
  Future<void> _changeAvatar() async {
    final newKey = await uploadAvatarFlow(context);
    if (newKey == null) return;
    if (!mounted) return;
    final store = DataStoreProvider.of(context);
    store.updateAvatar(newKey);
    setState(() {
      final p = _profile;
      if (p != null) {
        _profile = CloudUserProfile(
          uid: p.uid,
          nickname: p.nickname,
          avatar: newKey,
          bio: p.bio,
          sailLevel: p.sailLevel,
          showSailLevelTag: p.showSailLevelTag,
          isSelf: p.isSelf,
          following: p.following,
          stats: p.stats,
          certificates: p.certificates,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = DataStoreProvider.of(context);
    final captain = store.captain;
    // 未登录（登出后 IndexedStack 仍会构建本页）：空占位防御；
    // 登录闸门在 app.dart _onTabSelected 拦截 → 未登录点本 Tab 直接开登录页
    if (captain == null) return const SizedBox.shrink();

    // 下拉刷新：重拉统计 + 日志列表，评论/点赞计数与详情、港口口径对齐
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.deep,
      onRefresh: () async {
        await Future.wait([_loadProfile(), _loadPosts()]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(captain),
            const SizedBox(height: 14),
            _buildStats(),
            ProfileSectionTitle('征服证书 · Certificates'),
            _buildCerts(),
            ProfileSectionTitle('航海日志 · SAIL LOG'),
            _buildTabBar(),
            _buildPostsList(),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'GRAND BLUE · V1.3',
                style: TextStyle(color: AppColors.sub, fontSize: 11, letterSpacing: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ① 头像简介区 ────────────────────────────────────────
  Widget _buildHero(Captain captain) {
    final p = _profile;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4DE8B84A)),
        gradient: const LinearGradient(
          begin: Alignment(-0.5, -0.5),
          end: Alignment(0.5, 0.5),
          colors: [AppColors.detailStart, AppColors.abyss],
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 头像（点击 → 选图裁剪压缩直传，仅本人管理视角）
              GestureDetector(
                onTap: _changeAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
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
                        child: UserAvatar(
                          avatar: p?.avatar ?? captain.avatar,
                          fallbackText: captain.name,
                          size: 60,
                          fontSize: 30,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 22,
                        height: 22,
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
                          child: Text('📷', style: TextStyle(fontSize: 11, height: 1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 昵称 + 航级标签占位（后台开关关闭 → 完全不渲染）
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          captain.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF4FAFF),
                            letterSpacing: 1,
                          ),
                        ),
                        if (p != null && p.showSailLevelTag && p.sailLevel != null)
                          SailLevelTag(text: p.sailLevel!),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RANK · CAPTAIN',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gold,
                        letterSpacing: 2,
                        fontFamily: 'Cinzel',
                      ),
                    ),
                    // 简介（未设置不占位）
                    if (p?.bio != null && p!.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(p.bio!,
                          style: const TextStyle(color: AppColors.sub, fontSize: 12.5, height: 1.5)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 操作按钮组（v2.9.6 入口收拢：竖向右对齐堆叠 —— 上【编辑资料】高频，
              // 下【账号设置】低频；同卡片同样式，不再横向挤占简介区域）
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _heroActionButton(
                    icon: '✎',
                    label: '编辑资料',
                    onTap: _openEditProfile,
                  ),
                  const SizedBox(height: 8),
                  _heroActionButton(
                    icon: '⚙️',
                    label: '账号设置',
                    onTap: _openAccountSettings,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// hero 卡片内操作按钮（金色描边胶囊，与编辑资料完全同样式）
  Widget _heroActionButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12, color: AppColors.gold)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (changed != false) _loadProfile(); // 回来刷新简介/统计
  }

  Future<void> _openAccountSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
    );
    _loadProfile(); // 黑名单/登出操作后回来刷新
  }

  // ── ② 数据统计栏（与他人主页字段、排版对齐）──────────────
  Widget _buildStats() {
    final p = _profile;
    final uid = p?.uid;
    if (uid == null) {
      return ProfileStatsGrid(
        stats: p?.stats ??
            const CloudProfileStats(), // 加载中/失败先 0 占位，回来自动刷新
      );
    }
    // 弹窗关闭后回读统计：弹窗是实时接口，粉丝列表可能看到远端新增/移除，
    // 关闭时对齐一次，保证计数与弹窗口径一致
    Future<void> openSheet(bool isFollowers) async {
      await showFollowListSheet(context, uid: uid, isFollowers: isFollowers);
      _loadProfile();
    }

    return ProfileStatsGrid(
      stats: p?.stats ?? const CloudProfileStats(),
      onFollowingTap: () => openSheet(false),
      onFollowersTap: () => openSheet(true),
    );
  }

  // ── ③ 征服证书专区（横向滚动卡片，完全复用现有逻辑）──────
  Widget _buildCerts() {
    final p = _profile;
    if (p == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }
    return ProfileCertGallery(certificates: p.certificates);
  }

  // ── ④ 双 Tab 栏（样式参照船员服务菜单：ocean→deep 渐变 + 蓝描边）──
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A7DC4FF)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99123A6B), Color(0xB30A1F3D)],
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _tabItem('我的日志', !_likedTab)),
          const SizedBox(width: 4),
          Expanded(child: _tabItem('点赞的日志', _likedTab)),
        ],
      ),
    );
  }

  Widget _tabItem(String label, bool active) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTab(label == '点赞的日志'),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active ? AppColors.btnGoldGradient : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? AppColors.goldBtnText : const Color(0xFFE5EFFA),
          ),
        ),
      ),
    );
  }

  // ── ④ 日志列表（卡片样式与港口流完全一致）────────────────
  Widget _buildPostsList() {
    if (_loadingPosts && _currentPosts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }
    if (_currentPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            _likedTab ? '还没有点赞过任何航海日志' : '还没有发布过航海日志，点底栏 ＋ 发出第一条',
            style: const TextStyle(color: AppColors.sub, fontSize: 13),
          ),
        ),
      );
    }
    final total = _likedTab ? _likedTotal : _myTotal;
    return Column(
      children: [
        // v2.9.8 批量模式操作栏（仅我的日志；【全选】【删除选中】【退出批量】）
        if (_batchMode && !_likedTab) _buildBatchBar(),
        // 点赞的日志：作者头像点击进对方主页；我的日志：进自身公开预览。
        // 长按菜单/批量勾选仅限我的日志；点赞的日志 Tab 无菜单
        ..._currentPosts.map((post) {
          final mine = !_likedTab;
          return CloudPostCard(
            post: post,
            onAvatarTap: (author) {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => UserProfilePage(uid: author.uid)),
              );
            },
            onLongPress: mine && !_batchMode
                ? () => _showPostMenu(post)
                : null,
            selectMode: mine && _batchMode,
            checked: _selectedIds.contains(post.postId),
            onToggleSelect:
                mine && _batchMode ? () => _toggleSelect(post.postId) : null,
          );
        }),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              _loadingMore
                  ? '正在打捞更多日志…'
                  : (_likedTab ? _likedReachedEnd : _myReachedEnd)
                      ? '已经到底啦 · 共 $total 条'
                      : '',
              style: const TextStyle(fontSize: 11, color: AppColors.sub),
            ),
          ),
        ),
      ],
    );
  }

  /// 批量模式顶部操作栏：【全选/取消全选】【删除选中(N)】【退出批量】
  Widget _buildBatchBar() {
    final n = _selectedIds.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        color: AppColors.deep.withValues(alpha: 0.6),
      ),
      child: Row(
        children: [
          _batchBarItem(
            _allLoadedSelected ? '取消全选' : '全选',
            _toggleSelectAll,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _batchBarItem(
              n > 0 ? '删除选中($n)' : '删除选中',
              _deleteSelected,
              highlight: n > 0,
            ),
          ),
          const SizedBox(width: 8),
          _batchBarItem('退出批量', _exitBatchMode),
        ],
      ),
    );
  }

  Widget _batchBarItem(String label, VoidCallback onTap,
      {bool highlight = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: highlight ? AppColors.coral.withValues(alpha: 0.18) : null,
          border: Border.all(
            color: highlight
                ? AppColors.coral.withValues(alpha: 0.6)
                : AppColors.gold.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.coral : AppColors.gold,
          ),
        ),
      ),
    );
  }
}
