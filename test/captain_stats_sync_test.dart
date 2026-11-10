library;

/// 船长 Tab 打卡统计实时联动测试（v2.9.6 修复回归测试）
///
/// 验证核心修复机制：DataStore 打卡通知（syncIslandCheckins → notifyListeners）
/// → 船长 Tab 自动去抖重拉云端 profile → 统计数字（累计打卡/最长连续登岛）
/// 实时更新，不再卡死在首次快照。
///
/// 网络层用 package:http MockClient 注入（fakeAsync 环境无法驱动 dart:io 真实
/// IO，官方建议注入 HttpClient 实现）；业务数据链路的云端真值由线上冒烟另行
/// 验证 —— 本测试锁定「联动刷新机制」本身。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dalanhai_app/data/data_store_provider.dart';
import 'package:dalanhai_app/services/cloud_api.dart';
import 'package:dalanhai_app/services/social_state.dart';
import 'package:dalanhai_app/tabs/captain_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CaptainTab.refreshDebounce = Duration.zero; // 测试即时刷新
    MeState.instance.clear();
    FollowState.instance.clear();
  });

  tearDown(() {
    CloudApi.instance.httpClientOverride = null;
    CloudApi.instance.configure(baseUrl: '');
    CloudApi.instance.token = null;
  });

  testWidgets('打卡后船长 Tab 统计自动刷新（累计打卡/最长连续登岛联动）',
      (tester) async {
    // ── mock 云端（stats 可变真源 + 请求路径记录）──
    int totalCheckins = 5; // 可变统计真源（模拟后端）
    int maxStreak = 3;
    final List<String> seen = <String>[];
    CloudApi.instance.configure(baseUrl: 'https://mock.cloud'); // MockClient 不看域名
    CloudApi.instance.httpClientOverride = MockClient((req) async {
      // ignore: avoid_print
      print('[mock-in] ${req.method} ${req.url.path}');
      seen.add(req.url.path);
      Map<String, dynamic> data;
      if (req.url.path == '/api/user/me') {
        data = {'id': 1, 'phone': '13800000000', 'nickname': '测试船长'};
      } else if (req.url.path == '/api/user/1/profile') {
        data = {
          'uid': 1,
          'nickname': '测试船长',
          'isSelf': true,
          'following': false,
          'showSailLevelTag': false,
          'stats': {
            'posts': 0,
            'following': 0,
            'followers': 0,
            'totalCheckins': totalCheckins,
            'maxStreak': maxStreak,
          },
          'certificates': [],
        };
      } else if (req.url.path == '/api/user/1/posts' ||
          req.url.path == '/api/user/liked-posts') {
        data = {'total': 0, 'page': 1, 'size': 10, 'list': []};
      } else {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'code': -1, 'msg': 'not found'})), 404);
      }
      final resp = http.Response.bytes(
        utf8.encode(jsonEncode({'code': 0, 'msg': 'success', 'data': data})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      // ignore: avoid_print
      print('[mock-out] ${req.url.path} OK');
      return resp;
    });

    final store = DataStore();
    await store.load();
    store.login('测试船长', 'phone');

    await tester.pumpWidget(
      MaterialApp(
        home: DataStoreProvider(
          store: store,
          child: const CaptainTab(),
        ),
      ),
    );
    // 页面加载态有常驻 spinner（pumpAndSettle 永不 settle）→ 有限 pump 推进
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print('[mock] seen=$seen');
    expect(seen, contains('/api/user/1/profile'), reason: '首载拉取云端 profile（seen=$seen）');
    expect(find.text('5'), findsOneWidget, reason: '首载显示后端累计打卡 5');
    expect(find.text('3'), findsOneWidget, reason: '首载显示后端最长连续 3');

    // ── 模拟云端打卡成功：本地镜像同步（island_detail_page 打卡成功后的真实调用）──
    final profileCallsBefore =
        seen.where((p) => p == '/api/user/1/profile').length;
    totalCheckins = 6; // 后端统计 +1
    maxStreak = 4;
    store.syncIslandCheckins(
      'qingxin',
      ['2026-11-10'],
      continueDays: 4,
      maxStreakDays: 4,
      totalDays: 6,
    );
    await tester.pump(); // 触发 InheritedNotifier + 监听回调（登记去抖 Timer）
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      seen.where((p) => p == '/api/user/1/profile').length,
      greaterThan(profileCallsBefore),
      reason: '打卡通知触发了 profile 重拉（联动机制生效）',
    );
    expect(find.text('6'), findsOneWidget,
        reason: '打卡后船长 Tab 累计打卡自动刷新 5→6（联动修复核心断言）');
    expect(find.text('4'), findsOneWidget,
        reason: '打卡后船长 Tab 最长连续登岛自动刷新 3→4');
  });

  testWidgets('未登录 → 登录后统计自动加载（登录闸门恢复场景）', (tester) async {
    final List<String> seen = <String>[];
    bool loggedIn = false; // 模拟真实后端：登录前 fetchMe 401
    CloudApi.instance.configure(baseUrl: 'https://mock.cloud');
    CloudApi.instance.httpClientOverride = MockClient((req) async {
      seen.add(req.url.path);
      Map<String, dynamic> data;
      if (req.url.path == '/api/user/me' && !loggedIn) {
        // 真实后端语义：未登录 fetchMe → 401（CaptainTab 保持空占位）
        return http.Response.bytes(
            utf8.encode(jsonEncode({'code': -1, 'msg': '未登录'})), 401);
      }
      if (req.url.path == '/api/user/me') {
        data = {'id': 2, 'phone': '13900000000', 'nickname': '新船长'};
      } else if (req.url.path == '/api/user/2/profile') {
        data = {
          'uid': 2,
          'nickname': '新船长',
          'isSelf': true,
          'following': false,
          'showSailLevelTag': false,
          'stats': {
            'posts': 0,
            'following': 0,
            'followers': 0,
            'totalCheckins': 1,
            'maxStreak': 1,
          },
          'certificates': [],
        };
      } else if (req.url.path == '/api/user/2/posts' ||
          req.url.path == '/api/user/liked-posts') {
        data = {'total': 0, 'page': 1, 'size': 10, 'list': []};
      } else {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'code': -1, 'msg': 'not found'})), 404);
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode({'code': 0, 'msg': 'success', 'data': data})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final store = DataStore();
    await store.load(); // 未登录（captain = null → 船长 Tab 空占位）

    await tester.pumpWidget(
      MaterialApp(home: DataStoreProvider(store: store, child: const CaptainTab())),
    );
    await tester.pump();
    expect(find.text('1'), findsNothing, reason: '未登录时不展示统计');

    // 登录成功（DataStore.notify）→ 去抖重拉 → 统计出现
    store.login('新船长', 'phone'); // 登录后 DataStore.notify → 去抖重拉
    loggedIn = true; // 后端语义：此后 fetchMe 200
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print('[mock2] seen=$seen');
    expect(seen, contains('/api/user/2/profile'), reason: '登录通知触发 profile 拉取（seen=$seen）');
    expect(find.text('1'), findsWidgets,
        reason: '登录后统计自动加载（累计/最长连续各 1）');
  });
}
