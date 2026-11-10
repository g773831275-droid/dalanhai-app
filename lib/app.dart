import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';
import 'data/data_store_provider.dart';
import 'widgets/bottom_nav.dart';
import 'tabs/islands_tab.dart';
import 'tabs/port_tab.dart';
import 'tabs/bazaar_tab.dart';
import 'tabs/captain_tab.dart';
import 'pages/composer_page.dart';
import 'pages/auth_page.dart';

/// 全局 Tab 切换通道（登录成功等场景跨页跳转用：appTabIndex.value = 3 → 船长）
final ValueNotifier<int> appTabIndex = ValueNotifier<int>(0);

/// 全局 Navigator key（MaterialApp 注入）——
/// 供根层 context 调 showDialog（EULA 弹窗等）时取 MaterialApp 内部的
/// context（含 Navigator/MaterialLocalizations），修复启动期
/// 「No MaterialLocalizations found」卡死问题
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 大蓝海 App 根组件
/// 管理 4 Tab 切换 + 顶栏 + 背景 + 居中 + 发布动作
class GrandBlueApp extends StatefulWidget {
  final DataStore store;

  const GrandBlueApp({super.key, required this.store});

  @override
  State<GrandBlueApp> createState() => _GrandBlueAppState();
}

class _GrandBlueAppState extends State<GrandBlueApp> {
  int _tabIndex = 0; // 0=岛屿 1=港口 2=闹市 3=船长

  @override
  void initState() {
    super.initState();
    appTabIndex.addListener(_onAppTabIndexChanged);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    appTabIndex.removeListener(_onAppTabIndexChanged);
    super.dispose();
  }

  void _onAppTabIndexChanged() {
    debugPrint('[shell-tab] listener hit, new tabIndex=${appTabIndex.value}, _tabIndex=$_tabIndex, mounted=$mounted');
    if (mounted && appTabIndex.value != _tabIndex) {
      setState(() => _tabIndex = appTabIndex.value);
    }
  }

  final _pages = const [
    IslandsTab(),
    PortTab(),
    BazaarTab(),
    CaptainTab(),
  ];

  static const _tabTitles = ['大蓝海', '港口', '闹市', '船长'];
  static const _tabSubs = [
    'GRAND · BLUE · VOYAGE',
    'HARBOR · 与同海域的船员交换故事',
    'BAZAAR · 岛屿社群与同好酒馆',
    'CAPTAIN · 你的航海身份',
  ];

  void _onTabSelected(int i) {
    // 未登录点「船长」Tab（3）→ 不展示船长主页，直接打开「扬帆登船」登录页；
    // 登录成功后 auth_page 会设 appTabIndex.value = 3，自动落到船长 Tab
    if (i == 3 && !widget.store.isLoggedIn) {
      final BuildContext navCtx = appNavigatorKey.currentContext ?? context;
      if (!navCtx.mounted) return;
      Navigator.of(navCtx).push(MaterialPageRoute(builder: (_) => const AuthPage()));
      return;
    }
    // v2.9.3 修复：统一走 appTabIndex（单一向源）。
    // 旧实现只 setState(_tabIndex) 不写 appTabIndex → 两者脱钩：
    // 底部点过闹市后 appTabIndex 仍是旧值，composer 再设 appTabIndex=1
    // 会因"值未变"不触发通知 → 第二次发帖永远切不回港口
    appTabIndex.value = i; // _onAppTabIndexChanged 监听后统一 setState
  }

  Future<void> _onCompose() async {
    // 根层 State 的 context 在 MaterialApp 外部（Navigator/ScaffoldMessenger
    // 都是其后代而非祖先）→ 统一经全局 navigatorKey 取 MaterialApp 内部 context
    final BuildContext navCtx = appNavigatorKey.currentContext ?? context;
    if (!navCtx.mounted) return;

    // v2.9：未登录点发布 → 弹窗引导登录/注册，不直接进发布页
    //（EULA 勾选已前移至登录/注册流程，发帖处不再重复弹守则）
    if (!widget.store.isLoggedIn) {
      final go = await showDialog<bool>(
        context: navCtx,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.cardSolid,
          title: const Text(
            '需要登船',
            style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '登录后即可发布航海日志，与船员们分享你的航程',
            style: TextStyle(color: AppColors.sub, fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(navCtx, false),
              child: const Text('取消', style: TextStyle(color: AppColors.sub)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(navCtx, true),
              child: const Text('去登录', style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      );
      if (go == true && navCtx.mounted) {
        await Navigator.of(navCtx).push(
          MaterialPageRoute(builder: (_) => const AuthPage(returnTo: 'captain')),
        );
      }
      return;
    }

    if (!navCtx.mounted) return;
    Navigator.of(navCtx).push(MaterialPageRoute(builder: (_) => const ComposerPage()));
  }

  @override
  Widget build(BuildContext context) {
    return DataStoreProvider(
      store: widget.store,
      child: MaterialApp(
        title: '大蓝海',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        navigatorKey: appNavigatorKey, // 全局导航键（EULA 等根层弹窗的 context 来源）
        home: Scaffold(
          backgroundColor: AppColors.abyss,  // 防止 IndexedStack 边缘露出 Material 黑色
          body: Stack(
            children: [
              // 背景层：径向渐变 + 水波纹
              const _AppBackground(),
              // 前景：顶栏 + 内容
              Column(
                children: [
                  // 顶栏
                  _TopBar(
                    title: _tabTitles[_tabIndex],
                    subtitle: _tabSubs[_tabIndex],
                  ),
                  // Tab 内容
                  Expanded(
                    child: IndexedStack(
                      index: _tabIndex,
                      children: _pages,
                    ),
                  ),
                ],
              ),
            ],
          ),
          extendBody: true,
          bottomNavigationBar: BottomNav(
            currentIndex: _tabIndex,
            onTabSelected: _onTabSelected,
            onCompose: _onCompose,
          ),
        ),
      ),
    );
  }
}

// ── 背景层：多层径向渐变 + 水波纹点阵 ──
// 对应 H5 body 背景 + body::before 水波纹层
class _AppBackground extends StatelessWidget {
  const _AppBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 基础线性渐变 #04101F → #061a34 → #04101F
        Container(decoration: const BoxDecoration(gradient: AppColors.bodyGradient)),
        // 2. 顶部径向光晕 #1a4c86
        Positioned(
          top: -200,
          left: -200,
          right: -200,
          height: 600,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  AppColors.bgGlow1.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 3. 底部径向光晕 #0b2a52
        Positioned(
          bottom: -150,
          right: -100,
          width: 500,
          height: 400,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  AppColors.bgGlow2.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 4. 水波纹点阵层（对应 body::before）
        Positioned.fill(
          child: CustomPaint(painter: _WaterTexturePainter()),
        ),
      ],
    );
  }
}

/// 水波纹点阵绘制器 — 对应 H5 body::before
/// 三组不同颜色/大小/间距的重复圆点
class _WaterTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 第一组：蓝色点，间距 220px，半径 2px
    final paint1 = Paint()..color = AppColors.sky.withValues(alpha: 0.12);
    const step1 = 220.0;
    for (double x = step1 * 0.2; x < size.width; x += step1) {
      for (double y = step1 * 0.3; y < size.height; y += step1) {
        canvas.drawCircle(Offset(x, y), 2, paint1);
      }
    }
    // 第二组：金色点，间距 300px，半径 1.5px
    final paint2 = Paint()..color = AppColors.gold.withValues(alpha: 0.10);
    const step2 = 300.0;
    for (double x = step2 * 0.7; x < size.width; x += step2) {
      for (double y = step2 * 0.6; y < size.height; y += step2) {
        canvas.drawCircle(Offset(x, y), 1.5, paint2);
      }
    }
    // 第三组：蓝色点，间距 260px，半径 2px
    final paint3 = Paint()..color = AppColors.sky.withValues(alpha: 0.10);
    const step3 = 260.0;
    for (double x = step3 * 0.4; x < size.width; x += step3) {
      for (double y = step3 * 0.8; y < size.height; y += step3) {
        canvas.drawCircle(Offset(x, y), 2, paint3);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 顶栏 — 对应 H5 .topbar ──
// 金色渐变标题 + 副标题 + 罗盘 SVG 装饰 + 渐变背景
class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TopBar({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top;
    return ClipRect(
      child: Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 8),
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 罗盘装饰（右上角，opacity 0.10）— 70x70 不溢出
            Positioned(
              right: -20,
              top: -8,
              child: Opacity(
                opacity: 0.10,
                child: CustomPaint(
                  size: const Size(70, 70),
                  painter: _CompassPainter(),
                ),
              ),
            ),
            // 标题 + 副标题：H5 默认左对齐（详情页才居中）
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 金色渐变标题（ShaderMask 实现 background-clip:text 效果）
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.titleGoldGradient.createShader(bounds),
                      child: Text(
                        title,
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
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.sub,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
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

/// 罗盘装饰绘制器 — 对应 H5 .compass-mark SVG
/// 两个同心圆 + 中心点 + 两个十字指针
class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // 外圆 r=46
    canvas.drawCircle(Offset(cx, cy), 46, paint);
    // 中圆 r=36
    canvas.drawCircle(Offset(cx, cy), 36, paint);
    // 中心实心圆 r=4
    final centerPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 4, centerPaint);

    // 垂直指针（上下菱形）
    final vertPath = Path();
    vertPath.moveTo(cx, cy - 44); // 上
    vertPath.lineTo(cx + 4, cy);
    vertPath.lineTo(cx, cy + 44); // 下
    vertPath.lineTo(cx - 4, cy);
    vertPath.close();
    canvas.drawPath(
      vertPath,
      Paint()..color = AppColors.gold.withValues(alpha: 0.6),
    );

    // 水平指针
    final horzPath = Path();
    horzPath.moveTo(cx - 44, cy); // 左
    horzPath.lineTo(cx, cy - 4);
    horzPath.lineTo(cx + 44, cy); // 右
    horzPath.lineTo(cx, cy + 4);
    horzPath.close();
    canvas.drawPath(
      horzPath,
      Paint()..color = AppColors.gold.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
