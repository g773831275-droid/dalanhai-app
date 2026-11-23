import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart' show appTabIndex;
import '../data/models.dart';
import '../pages/announcement_page.dart';
import '../services/cloud_api.dart';
import '../theme/colors.dart';

/// 岛屿页顶部 Banner — 后端动态配置卡片（AGENTS.md §13）
/// - 仅手动拖拽切换（❌ 无自动轮播/定时翻页）
/// - 卡片尺寸/外框 1:1 沿用原版 H5 voyage hero（全宽 margin14 + 圆角22 + 同高）
/// - 圆点指示器位于 Banner 容器内部、卡片正下方居中，跟随滑动同步高亮
/// - 点击行为由后端 action 字段决定：reward→开服公告页 / internal_page(预留) / none→无动作
/// - 数据源：GET /api/banners + 本地 10 分钟缓存；网络失败回退缓存/内置兜底卡片
/// - ⚠️ 前端强制保证第 0 项为开服公告卡（无论后端 sort 如何配置）；切回岛屿 Tab 强制回第 0 页
class AppBanner extends StatefulWidget {
  /// 今日出海卡片的动态统计（原 voyage hero 数据，注入 action=none 卡片展示）
  final int totalConquered;
  final int maxStreak;

  const AppBanner({
    super.key,
    required this.totalConquered,
    required this.maxStreak,
  });

  @override
  State<AppBanner> createState() => AppBannerState();
}

class AppBannerState extends State<AppBanner> {
  // keepPage:false：页面缓存不保留上次浏览位置；initialPage:0 首屏必为开服公告
  final PageController _pageController = PageController(
    initialPage: 0,
    keepPage: false,
    viewportFraction: 1.0,
  );
  List<BannerItem> _items = BannerItem.fallback;
  bool _loading = true;
  int _page = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(forceRefresh: false);
    // 本页在 IndexedStack 常驻（切 Tab 不销毁 State）——必须主动订阅 Tab 索引，
    // 每次切回岛屿 Tab（index 0）强制 PageView 重置到第 0 页（开服公告）
    appTabIndex.addListener(_onTabSwitched);
  }

  @override
  void dispose() {
    appTabIndex.removeListener(_onTabSwitched);
    _debounce?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSwitched() {
    if (appTabIndex.value != 0) return; // 只处理「切回岛屿」
    if (!_pageController.hasClients) return;
    if (_page == 0) return;
    _pageController.jumpToPage(0);
    setState(() => _page = 0);
  }

  Future<void> _load({required bool forceRefresh}) async {
    final items = await CloudApi.instance.fetchBanners(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _items = _forceAnnouncementFirst(items.isEmpty ? BannerItem.fallback : items);
      _loading = false;
      if (_page >= _items.length) _page = 0;
    });
  }

  /// 强制把开服公告卡排到第 0 位（其余卡片依原顺序后置）。
  /// 识别口径：action == 'reward'（开服公告 seed/兜底卡均为 reward）或 title == '开服公告'
  /// 兜底——无论后端 sort 如何配置，首屏固定为开服公告。
  List<BannerItem> _forceAnnouncementFirst(List<BannerItem> list) {
    final idx = list.indexWhere((b) => b.action == 'reward' || b.title == '开服公告');
    if (idx <= 0) return list; // 未找到或已在第 0 位
    final item = list.removeAt(idx);
    return [item, ...list];
  }

  /// 下拉刷新入口（IslandsTab 的 RefreshIndicator 调用）——强制拉取最新配置
  Future<void> refresh() async {
    // 防抖：快速连续下拉只发一次请求
    _debounce?.cancel();
    final completer = Completer<void>();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _load(forceRefresh: true).whenComplete(() {
        if (!completer.isCompleted) completer.complete();
      });
    });
    return completer.future;
  }

  void _handleTap(BannerItem banner) {
    switch (banner.action) {
      case 'reward':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AnnouncementPage()),
        );
        break;
      case 'internal_page':
        // 预留：action_value 指定路由，暂无已注册页面——保持无动作（后端配置后前端再接线）
        break;
      case 'none':
      default:
        // 纯展示：点击无任何动作（不弹窗、不跳转、不提示）
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return SizedBox(
        height: _cardHeight + 20,
        child: const Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _cardHeight + 8, // 卡片自身上下 margin 4×2
          child: PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _page = i),
            // ❌ 无 autoPlay/Timer —— 仅手指拖拽切换
            itemBuilder: (context, i) => _HeroBannerCard(
              banner: _items[i],
              totalConquered: widget.totalConquered,
              maxStreak: widget.maxStreak,
              onTap: () => _handleTap(_items[i]),
            ),
          ),
        ),
        // 圆点指示器：Banner 容器内部、卡片区域底部正下方居中（不贴左下角、不出容器）
        SizedBox(
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_items.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active ? AppColors.gold : AppColors.gold.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// 卡片统一高度：与原版 H5 voyage hero 自然高度对齐
/// （18 + eyebrow ~15 + 6 + title ~31 + 4 + desc ~17 + 16 ≈ 107，取 108 留 1px 余量）
const double _cardHeight = 108;

/// 单张 Banner 卡片 — 1:1 复刻原版 H5 voyage hero 骨架（尺寸/外框/排版/波浪/角标）
/// 两张卡（开服公告 gold / 今日出海 ocean）结构完全一致 → 宽高完全相同；
/// 差异仅：渐变色板、eyebrow 文案、角标 emoji、desc 行内容（全部可由后端配置驱动）。
/// ❌ 卡片上不放按钮——整卡点击由 action 字段分发。
class _HeroBannerCard extends StatelessWidget {
  final BannerItem banner;
  final int totalConquered;
  final int maxStreak;
  final VoidCallback onTap;

  const _HeroBannerCard({
    required this.banner,
    required this.totalConquered,
    required this.maxStreak,
    required this.onTap,
  });

  bool get _isOcean => banner.theme == 'ocean';

  LinearGradient get _gradient => _isOcean
      ? const LinearGradient(
          begin: Alignment(-0.5, -0.5),
          end: Alignment(0.5, 0.5),
          colors: [AppColors.heroStart, AppColors.deep, AppColors.abyss],
          stops: [0.0, 0.6, 1.0],
        )
      // gold：金调同构渐变（开服公告）
      : const LinearGradient(
          begin: Alignment(-0.5, -0.5),
          end: Alignment(0.5, 0.5),
          colors: [Color(0xFF4A3A12), Color(0xFF2A2410), AppColors.abyss],
          stops: [0.0, 0.6, 1.0],
        );

  // eyebrow 小字：今日出海沿用原版 CHAPTER，开服公告用 ANNOUNCEMENT（后端 title 可配，eyebrow 按 theme 派生）
  String get _eyebrow =>
      '${_isOcean ? 'CHAPTER' : 'ANNOUNCEMENT'} · ${DateTime.now().year}';

  // desc 行：今日出海 = 原 voyage hero 动态统计（原版文案）；开服公告 = 后端 subtitle
  String get _descLine => _isOcean
      ? '已征服 $totalConquered 次 · 最长连续 $maxStreak 天'
      : (banner.subtitle.isNotEmpty ? banner.subtitle : '');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 1:1 原版 H5 banner 外距（14, 4, 14, 4）
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // 1. 主体：双层渐变背景 + 边框 + 阴影（原版）
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: _gradient,
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
              // 2. 径向金色光晕叠层（原版）
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: RadialGradient(
                        center: const Alignment(0, -1.2),
                        radius: 0.9,
                        colors: [
                          AppColors.gold.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55],
                      ),
                    ),
                  ),
                ),
              ),
              // 3. 内容（eyebrow + title + desc 左对齐）— 原版排版
              SizedBox(
                height: _cardHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _eyebrow,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 11,
                          letterSpacing: 3,
                          color: AppColors.gold.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // 标题渐变文字 #fff → #BFE3FF（原版）
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, AppColors.foam],
                        ).createShader(b),
                        child: Text(
                          banner.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_descLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _descLine,
                          style: const TextStyle(fontSize: 12, color: AppColors.sub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 4. 角标 emoji 右上角（H5 right:14px top:14px；⛵ 原版 44px）
              Positioned(
                right: 14,
                top: 14,
                child: Text(
                  banner.icon.isEmpty ? (_isOcean ? '⛵' : '📢') : banner.icon,
                  style: TextStyle(
                    fontSize: _isOcean ? 44 : 38,
                    height: 1,
                    shadows: const [
                      Shadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 4)),
                    ],
                  ),
                ),
              ),
              // 5. 底部波浪 SVG（原版 .waves，两条不同透明度）
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 44,
                child: CustomPaint(painter: _WavePainter()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部波浪 — 对应 H5 .waves SVG（原版 _WavePainter 1:1 恢复）
/// 两条波浪 path，不同透明度
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 第一条波：opacity .25
    final paint1 = Paint()..color = AppColors.sky.withValues(alpha: 0.25);
    final path1 = Path();
    path1.moveTo(0, 20);
    final w = size.width;
    final seg = w / 4;
    path1.quadraticBezierTo(seg * 0.5, 0, seg, 20);
    for (int i = 1; i < 4; i++) {
      path1.quadraticBezierTo(seg * (i + 0.5), 40, seg * (i + 1), 20);
    }
    path1.lineTo(w, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // 第二条波：opacity .4
    final paint2 = Paint()..color = AppColors.sky.withValues(alpha: 0.4);
    final path2 = Path();
    path2.moveTo(0, 28);
    path2.quadraticBezierTo(seg * 0.5, 12, seg, 28);
    for (int i = 1; i < 4; i++) {
      path2.quadraticBezierTo(seg * (i + 0.5), 44, seg * (i + 1), 28);
    }
    path2.lineTo(w, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
