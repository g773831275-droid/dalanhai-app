import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/progress_grid.dart';
import '../widgets/certificate_dialog.dart';
import '../data/models.dart';
import '../data/data_store_provider.dart';
import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../services/session_store.dart';
import '../pages/composer_page.dart';
import 'auth_page.dart';

/// 岛屿详情页 — 1:1 复刻 H5 renderIsland()
/// 大数字金色渐变 + 21天格子 + 扬帆打卡 + 规则列表
///
/// 第一轮联调（Flash 后端）打卡链路：
///   游客：可自由浏览日历/规则，仅点击打卡按钮 → 弹「需要登船」引导
///   登录 + 云端岛（本轮仅早睡岛 sleep）：GET /api/user/island/:id 拉数据，
///     POST .../checkin 提交打卡 —— 连续天数/征服判定全部后端计算，前端只展示
///   登录 + 非云端岛：暂走本地打卡（后端扩展后切换）
///   401（token 失效）→ 自动登出清本地状态 → 重新弹登录引导
class IslandDetailPage extends StatefulWidget {
  final Island island;

  const IslandDetailPage({super.key, required this.island});

  @override
  State<IslandDetailPage> createState() => _IslandDetailPageState();
}

class _IslandDetailPageState extends State<IslandDetailPage> {
  /// 云端打卡数据（登录 + 云端岛时加载；null = 游客/非云端岛/加载失败走本地）
  IslandCheckinData? _cloud;
  bool _loading = false;
  bool _posting = false; // 打卡请求进行中（防重复提交）

  String get _cloudKey => kCloudCheckinIslandKeys[widget.island.id] ?? '';

  @override
  void initState() {
    super.initState();
    // initState 里不能 dependOnInheritedWidget → 帧后加载
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCloud());
  }

  /// 拉取云端打卡数据（登录 + 云端岛才发请求），成功后回写本地镜像
  Future<void> _loadCloud() async {
    final store = DataStoreProvider.of(context);
    if (_cloudKey.isEmpty || !store.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final d = await CloudApi.instance.fetchIslandCheckin(_cloudKey);
      if (!mounted) return;
      setState(() => _cloud = d);
      store.syncIslandCheckins(
        widget.island.id,
        d.checkinDateList,
        conquered: d.isConquer,
        continueDays: d.continueDays,
        maxStreakDays: d.maxStreakDays,
        totalDays: d.totalDays, // v2.9.6：全历史累计口径（与船长页统计同源）
      );
    } on ApiException catch (e) {
      if (e.code == 401) await _handle401();
      // 其他错误静默：回落展示本地数据
    } catch (_) {
      // 网络异常静默：回落展示本地数据
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 401 统一处理：token 失效 → 清 SessionStore + 本地登录态（船长闸门重新生效）
  Future<void> _handle401() async {
    await SessionStore.instance.clear();
    if (!mounted) return;
    DataStoreProvider.of(context).logout();
    if (mounted) setState(() => _cloud = null);
  }

  Future<void> _checkin() async {
    final store = DataStoreProvider.of(context);

    // ── 游客：仅打卡动作触发登录引导（浏览不拦截）──
    if (!store.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    // ── 全岛统一云端打卡：连续天数/征服判定全部后端计算，本地只做镜像展示 ──
    if (_cloudKey.isEmpty) {
      _snack('该岛屿暂未开放云端打卡'); // 防御：未知岛 id（正常不会出现）
      return;
    }
    if (_posting) return;
    // 防御：已打卡状态下的竞态点击（按钮虽已禁用，仍兜底拦截重复提交）。
    // 只信云端 todayChecked（服务端 Asia/Shanghai 日期）：本地镜像日期与设备时区
    // 可能存在偏移（如设备 UTC vs 服务端 +8），不能作为拦截依据。
    if (_cloud?.todayChecked == true) {
      _snack('今日已经打卡，明天再来');
      return;
    }
    setState(() => _posting = true);
    try {
      final r = await CloudApi.instance.cloudCheckin(_cloudKey);
      if (!mounted) return;
      // v2.9.3：以后端返回为准（服务端 Asia/Shanghai 日期），禁止前端本地时间拼日期
      // 本地镜像同步（islands 卡片/船长统计/证书墙与云端对齐）
      store.syncIslandCheckins(
        widget.island.id,
        r.checkinDateList,
        conquered: r.isConquer,
        continueDays: r.continueDays,
        maxStreakDays: r.maxStreakDays,
        totalDays: r.totalDays, // v2.9.6：全历史累计口径（与船长页统计同源）
      );
      setState(() {
        _cloud = IslandCheckinData(
          islandId: _cloudKey,
          today: r.today,
          continueDays: r.continueDays,
          remainDays: r.remainDays,
          isConquer: r.isConquer,
          checkinDateList: r.checkinDateList,
          todayChecked: true,
        );
      });
      _showSuccessDialog(context, r.continueDays, remain: r.remainDays);
      if (r.isConquer) CertificateDialog.show(context, widget.island);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 401) {
        await _handle401();
        if (mounted) _showLoginRequired(); // 登录态失效 → 重新引导登录
      } else if (e.code == 409) {
        _snack('今日已经打卡，明天再来');
      } else {
        _snack(e.message);
      }
    } catch (_) {
      if (mounted) _snack('网络不可用，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  /// 游客登录引导弹窗（点击打卡时触发）：
  /// 去登录 → 扬帆登船页（returnTo=island，登录成功自动回到本页继续打卡）
  Future<void> _showLoginRequired() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSolid,
        title: const Text(
          '需要登船',
          style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '打卡记录将和你的账号云端同步，请先登录',
          style: TextStyle(color: AppColors.sub, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppColors.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('去登录', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AuthPage(returnTo: 'island')),
      );
      if (mounted) _loadCloud(); // 登录成功回到本页 → 拉取云端打卡数据
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.ocean,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 打卡成功居中弹窗 — 对应 H5 maskToast 风格（深蓝渐变卡 + 金色标题 + 金色「好的」按钮）
  void _showSuccessDialog(BuildContext context, int streak, {required int remain}) {
    showDialog(
      context: context,
      barrierColor: const Color(0xBF040A14),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.cardSolid, AppColors.abyss],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60, offset: const Offset(0, 20)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 金色标题「登岛成功」
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.goldBright, AppColors.gold],
                ).createShader(b),
                child: const Text(
                  '登岛成功',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 副标题：连续 X 天 · 距离征服还差 X 天（后端计算值）
              Text(
                '连续 $streak 天 · 距离征服还差 $remain 天',
                style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              // 金色「好的」按钮 → 关闭弹窗回到岛屿主页
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppColors.btnGoldGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.copper.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '好的',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.goldBtnText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = DataStoreProvider.of(context);
    final hasCloud = _cloud != null;
    // 云端岛数据优先（后端为打卡真源）；游客/非云端岛回落本地
    final s = hasCloud ? _cloud!.continueDays : store.streakOf(widget.island.id);
    // 游客按钮恒可点（点击弹登录引导）；登录后按 todayChecked/本地状态置灰
    final done = store.isLoggedIn
        ? (hasCloud ? _cloud!.todayChecked : store.isCheckedToday(widget.island.id))
        : false;
    final checkins = hasCloud ? _cloud!.checkinDateList : store.checkinsOf(widget.island.id);
    final certified = hasCloud ? _cloud!.isConquer : store.hasCert(widget.island.id);

    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: Column(
        children: [
          // 顶栏（返回按钮 + 岛屿名 + 副标题）
          _DetailTopBar(island: widget.island, streak: s),
          // 内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DetailHero(island: widget.island, streak: s),
                  if (certified)
                    _CertNote(island: widget.island)
                  else
                    const SizedBox(height: 14),
                  _SectionTitle('最近 21 天 · Last 21 Days'),
                  // v2.9.3：日历"今天"以服务端下发为准（云端模式）；离线本地模式回退设备时间
                  ProgressGrid(
                    checkins: checkins,
                    todayOverride: hasCloud ? _cloud!.today : null,
                  ),
                  const SizedBox(height: 16),
                  // 打卡按钮（全岛统一状态机，对齐 H5）：
                  // done（云端/本地今日已打卡）→ 置灰禁用，禁止重复提交；
                  // 未打卡 → 金色可点；_posting/_loading 过程态同样禁用；
                  // 打卡请求失败 → done 仍为 false，按钮保持金色可重试
                  _PrimaryButton(
                    text: done ? '✓ 今日已打卡 · ${widget.island.action}' : '扬帆登岛 · ${widget.island.action}',
                    onPressed: (done || _posting || _loading) ? null : _checkin,
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('岛屿规则 · Rules'),
                  _RuleItem(icon: '📌', text: '每日打卡"${widget.island.action}"，连续 ${Island.target} 天征服本岛'),
                  _RuleItem(icon: '👥', text: '加入官方船队 · 找搭子', onTap: () => _toastService(context)),
                  _RuleItem(icon: '⚓', text: '去港口分享今日日志', onTap: _gotoPortComposer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 「去港口分享今日日志」— 对齐老 H5：跳发布页并预选当前岛屿标签，
  /// 用户填正文/图片后直接发布打卡日志（全岛统一，岛名跟随当前页）
  void _gotoPortComposer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComposerPage(initialTags: {widget.island.name}),
      ),
    );
  }

  /// 「加入官方船队 · 找搭子」— 老 H5 maskService 同款完整弹窗
  /// 标题 + 说明 + 二维码 + 船务长微信 + 客服邮箱 + 金色「我知道了」
  void _toastService(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: const Color(0xBF040A14),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.cardSolid, AppColors.abyss],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60, offset: const Offset(0, 20)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 金色渐变标题「联系船务长 · 登上官方船」
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.goldBright, AppColors.gold],
                ).createShader(b),
                child: const Text(
                  '联系船务长 · 登上官方船',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 说明文字（两行，H5 同文案）
              const Text(
                '长按识别二维码，添加船务长微信\n他会带你上对应岛屿的官方船',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.6),
              ),
              const SizedBox(height: 16),
              // 二维码（白底圆角容器，对齐 H5 .qr-box）
              Container(
                width: 200,
                height: 200,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/wechat-qr.jpg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '船务长微信：abccba978',
                style: TextStyle(fontSize: 12, color: AppColors.sub),
              ),
              const SizedBox(height: 4),
              const Text(
                '客服邮箱：gktvipyx@163.com',
                style: TextStyle(fontSize: 12, color: AppColors.sub),
              ),
              const SizedBox(height: 18),
              // 金色「我知道了」→ 关闭弹窗
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppColors.btnGoldGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.copper.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '我知道了',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.goldBtnText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 顶栏 — H5 topbar 在详情页的状态 ──
// 返回按钮 + 金色渐变标题 + 副标题
class _DetailTopBar extends StatelessWidget {
  final Island island;
  final int streak;

  const _DetailTopBar({required this.island, required this.streak});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, topPadding + 6, 8, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.abyss.withValues(alpha: 0.9),
            AppColors.abyss.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            // 返回按钮
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('‹', style: TextStyle(fontSize: 26, color: AppColors.gold, height: 1)),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 金色渐变标题
                  ShaderMask(
                    shaderCallback: (b) => AppColors.titleGoldGradient.createShader(b),
                    child: Text(
                      island.name,
                      style: const TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ON VOYAGE · $streak DAYS',
                    style: const TextStyle(fontSize: 11, color: AppColors.sub, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 42), // 平衡返回按钮
          ],
        ),
      ),
    );
  }
}

// ── 详情 Hero — 对应 H5 .detail-hero ──
// 径向渐变 + 线性渐变 + 大数字金色渐变文字 + 图标
class _DetailHero extends StatelessWidget {
  final Island island;
  final int streak;

  const _DetailHero({required this.island, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppColors.detailGradient,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        // Stack 默认 topStart 会把 non-positioned 的内容 Column 钉在左侧，
        // 导致卡片内小人/标题/大数字整组偏左 ~70px；topCenter 修复水平居中
        alignment: Alignment.topCenter,
        children: [
          // 径向光晕叠层
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.2),
                    radius: 0.9,
                    colors: [
                      AppColors.gold.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 内容
          Column(
            children: [
              // 图标
              Text(island.emoji, style: const TextStyle(fontSize: 52, height: 1)),
              const SizedBox(height: 6),
              // 岛屿名（金色渐变文字 #FFF3C4 → #E8B84A）
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.goldBright, AppColors.gold],
                ).createShader(b),
                child: Text(
                  island.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // slogan
              Text(
                '"${island.slogan}"',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.foam.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
              ),
              // 大数字（金色渐变文字 #FFF3C4 → #E8B84A 60% → #B7702B）
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (b) => AppColors.goldTextGradient.createShader(b),
                child: Text(
                  '$streak',
                  style: const TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // label
              Text(
                'CONSECUTIVE · TARGET ${Island.target}'.toUpperCase(),
                style: const TextStyle(fontSize: 12, color: AppColors.sub, letterSpacing: 2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 证书卡片 — 对应 H5 .cert-card ──
// 羊皮纸渐变 + 虚线内边框
class _CertNote extends StatelessWidget {
  final Island island;
  const _CertNote({required this.island});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: AppColors.certGradient,
        border: Border.all(color: AppColors.certBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 虚线内边框（::before）
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CustomPaint(painter: _DashedRectPainter()),
              ),
            ),
          ),
          // 内容
          Row(
            children: [
              const Text('🏴‍☠️', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已征服本岛',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppColors.inkLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '连续 ${Island.target} 天登岛达成，可联系船务长登官方船',
                      style: TextStyle(fontSize: 12, color: AppColors.inkLight.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 虚线矩形绘制器 — 对应 H5 .cert-card::before
class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.inkLight.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制虚线矩形
    const dashLen = 4.0;
    const gapLen = 3.0;
    final w = size.width;
    final h = size.height;

    // 上边
    for (double x = 0; x < w; x += dashLen + gapLen) {
      canvas.drawLine(Offset(x, 0), Offset((x + dashLen).clamp(0, w), 0), paint);
    }
    // 下边
    for (double x = 0; x < w; x += dashLen + gapLen) {
      canvas.drawLine(Offset(x, h), Offset((x + dashLen).clamp(0, w), h), paint);
    }
    // 左边
    for (double y = 0; y < h; y += dashLen + gapLen) {
      canvas.drawLine(Offset(0, y), Offset(0, (y + dashLen).clamp(0, h)), paint);
    }
    // 右边
    for (double y = 0; y < h; y += dashLen + gapLen) {
      canvas.drawLine(Offset(w, y), Offset(w, (y + dashLen).clamp(0, h)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 段落标题 — 对应 H5 .section-title（前后渐变线）──
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, AppColors.goldHalf]),
            ),
          )),
          const SizedBox(width: 10),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 12,
              letterSpacing: 3,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.goldHalf, Colors.transparent]),
            ),
          )),
        ],
      ),
    );
  }
}

// ── 金色渐变按钮 — 对应 H5 .btn-primary ──
class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _PrimaryButton({required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: disabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF5a6f8c), Color(0xFF2d3d55)],
                  )
                : AppColors.btnGoldGradient,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.copper.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: disabled ? const Color(0xFFc8d5e6) : AppColors.goldBtnText,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 规则列表项 — 对应 H5 .list-item ──
class _RuleItem extends StatelessWidget {
  final String icon;
  final String text;
  final VoidCallback? onTap;

  const _RuleItem({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99123A6B), Color(0xB30A1F3D)],
          ),
          border: Border.all(color: AppColors.sky.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(icon, style: const TextStyle(fontSize: 20, color: AppColors.gold), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFFE5EFFA))),
            ),
            if (onTap != null)
              const Text('›', style: TextStyle(fontSize: 18, color: AppColors.sub)),
          ],
        ),
      ),
    );
  }
}
