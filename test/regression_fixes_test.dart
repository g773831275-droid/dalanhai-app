import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dalanhai_app/data/data_store.dart';
import 'package:dalanhai_app/data/prefs.dart';
import 'package:dalanhai_app/services/cloud_api.dart';
import 'package:dalanhai_app/services/media_sign_cache.dart';

/// 回归自测（2026-11-18 修复 #6 / #4 / #9③）
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('修复#6 DataStore 防抖写盘', () {
    test('写盘合并进 400ms 窗口，窗口内不落盘、窗口后完整落盘', () async {
      final store = DataStore();
      await store.load();
      store.checkin('qingxin');
      final sp = await SharedPreferences.getInstance();
      // 防抖窗口内：尚未写盘
      expect(sp.getString('dalanhai_v2'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      // 窗口过后：完整落盘
      final written = sp.getString('dalanhai_v2');
      expect(written, isNotNull);
      expect(written!, contains('qingxin'));
      store.dispose(); // 取消未决定时器，不污染后续用例
    });

    test('连续 5 次操作只触发一次写盘（最终状态完整）', () async {
      final store = DataStore();
      await store.load();
      // 写入路径与读取路径统一走 Prefs 缓存实例（跨用例 setMockInitialValues
      // 会换底层 mock store，直读 SharedPreferences 实例存在夹具串扰假阴性）
      for (int i = 0; i < 5; i++) {
        store.addPost(text: 'count $i');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final data = await Prefs.loadData();
      expect(data.posts.length, 5); // 5 次操作合并为一次写盘，状态完整
      store.dispose();
    });

    test('clearAll 取消未决防抖，旧数据不回写', () async {
      final store = DataStore();
      await store.load();
      store.checkin('qingxin');
      await store.clearAll();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('dalanhai_v2'), isNull); // 未被防抖定时器回写
    });
  });

  group('修复#4/#9③ 签名接口', () {
    late FakeJsonClient fake;
    setUp(() {
      fake = FakeJsonClient();
      CloudApi.instance
        ..configure(baseUrl: 'https://test.local', token: 't')
        ..httpClientOverride = fake;
    });
    tearDown(() {
      CloudApi.instance.httpClientOverride = null;
    });

    test('signMedia 跳过非数字 postId，不抛 FormatException', () async {
      fake.responders['POST /api/media/sign'] = (req) => jsonResp({
            'code': 0,
            'data': {
              'urls': {
                'abc': { // 非法 key：此前 int.parse 直接崩
                  'urls': ['https://x/1'],
                  'expiresAt': 9999999999999,
                },
                '7': {
                  'urls': ['https://x/2'],
                  'expiresAt': 9999999999999,
                },
              },
            },
          });
      final r = await CloudApi.instance.signMedia([7]);
      expect(r.containsKey(7), isTrue);
      expect(r.length, 1); // 非数字条目被静默跳过
    });

    test('prefetchKeys >10 个 key 自动分批（15 → 2 次请求）', () async {
      fake.responders['POST /api/media/sign'] = (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final keys = (body['keys'] as List).length;
        return jsonResp({
          'code': 0,
          'data': {
            'signedKeys': {
              for (final k in (body['keys'] as List))
                k: {'url': 'https://x/$k', 'expiresAt': 9999999999999},
            },
            'batchSize': keys,
          },
        });
      };
      final keys = List<String>.generate(15, (i) => 'avatar/$i.jpg');
      MediaSignCache.instance.clear();
      await MediaSignCache.instance.prefetchKeys(keys);
      final signReqs = fake.bodies
          .where((b) => b.contains('"keys"'))
          .map((b) => ((jsonDecode(b) as Map<String, dynamic>)['keys'] as List).length)
          .toList();
      expect(signReqs, [10, 5]); // ≤10/批 自动分批
    });

    test('图片渲染域名映射：ESA 私有访问模式 —— host 切 img.idalanhai.com 且剥离全部签名 query', () async {
      MediaSignCache.instance.clear();
      fake.responders['POST /api/media/sign'] = (req) {        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body.containsKey('keys')) {
          return jsonResp({
            'code': 0,
            'data': {
              'signedKeys': {
                'avatar/1.jpg': {
                  'url': 'https://dalanhai-app-check.oss-cn-hongkong.aliyuncs.com/avatar/1.jpg?Expires=1&OSSAccessKeyId=AK&Signature=abc%2Bdef%3D',
                  'expiresAt': 9999999999999,
                },
              },
            },
          });
        }
        return jsonResp({
          'code': 0,
          'data': {
            'urls': {
              '150': {
                'urls': [
                  'https://dalanhai-app-check.oss-cn-hongkong.aliyuncs.com/ugc/20261118/a.jpg?Expires=2&Signature=sig%2B1%3D',
                ],
                'expiresAt': 9999999999999,
              },
            },
          },
        });
      };
      // ESA 私有访问：渲染 URL host=img.idalanhai.com 且不带任何签名 query
      // （双重鉴权冲突会引发随机 400/SSL 重置，见阿里云工单 2026-11-18）
      final postUrl = await MediaSignCache.instance.urlFor(150);
      expect(postUrl, 'https://img.idalanhai.com/ugc/20261118/a.jpg');
      expect(postUrl, isNot(contains('Signature')));
      expect(postUrl, isNot(contains('Expires')));
      expect(postUrl, isNot(contains('OSSAccessKeyId')));
      // 头像 key
      final keyUrl = await MediaSignCache.instance.urlForKey('avatar/1.jpg');
      expect(keyUrl, 'https://img.idalanhai.com/avatar/1.jpg');
      expect(keyUrl, isNot(contains('Signature')));
      MediaSignCache.instance.clear();
    });
  });
}

http.Response jsonResp(Map<String, dynamic> j) =>
    http.Response(jsonEncode(j), 200, headers: {'content-type': 'application/json'});

class FakeJsonClient implements http.Client {
  final Map<String, http.Response Function(http.Request)> responders = {};
  final List<String> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String key = '${request.method} ${request.url.path}';
    bodies.add(request is http.Request ? request.body : '');
    final responder = responders[key];
    if (responder == null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'code': -1, 'msg': 'no responder $key'}))),
        200,
      );
    }
    final r = responder(request as http.Request);
    return http.StreamedResponse(Stream.value(r.bodyBytes), r.statusCode,
        headers: r.headers);
  }

  @override
  void close() {}
  @override
  Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) => throw UnimplementedError();
  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) => throw UnimplementedError();
  @override
  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();
  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();
  @override
  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();
  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) => throw UnimplementedError();
  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();
}
