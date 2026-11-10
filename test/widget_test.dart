import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dalanhai_app/app.dart';
import 'package:dalanhai_app/data/data_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots and shows bottom nav tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1242, 2688);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final store = DataStore();
    await store.load();
    await tester.pumpWidget(GrandBlueApp(store: store));

    expect(find.text('岛屿'), findsOneWidget);
    expect(find.text('港口'), findsOneWidget);
    expect(find.text('闹市'), findsOneWidget);
    expect(find.text('船长'), findsOneWidget);

    // 航海报标题
    expect(find.text('今日出海'), findsOneWidget);
  });

  testWidgets('Island cards show and navigate to detail', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1242, 2688);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final store = DataStore();
    await store.load();
    await tester.pumpWidget(GrandBlueApp(store: store));

    // 滚动找到早睡岛
    await tester.scrollUntilVisible(
      find.text('早睡岛'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 点击清心岛进入详情页
    await tester.tap(find.text('清心岛'));
    await tester.pumpAndSettle();

    expect(find.text('扬帆登岛 · 今日已修行'), findsOneWidget);
  });

  testWidgets('Check-in works and updates streak', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1242, 2688);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final store = DataStore();
    await store.load();
    await tester.pumpWidget(GrandBlueApp(store: store));

    // 进入清心岛详情
    await tester.tap(find.text('清心岛'));
    await tester.pumpAndSettle();

    // 滚动到打卡按钮并点击
    await tester.scrollUntilVisible(
      find.text('扬帆登岛 · 今日已修行'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('扬帆登岛 · 今日已修行'));
    await tester.pumpAndSettle();

    // 打卡后按钮应变「今日已打卡」
    expect(find.textContaining('今日已打卡'), findsOneWidget);
  });
}
