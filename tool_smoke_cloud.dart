// CloudApi v2.7 P0 对接冒烟（直连生产 API，只读接口无需登录）
// 运行：dart run tool_smoke_cloud.dart
// ignore_for_file: avoid_print
import 'lib/services/cloud_api.dart';

Future<void> main() async {
  final api = CloudApi.instance;
  api.configure(baseUrl: 'https://api.idalanhai.com');

  int pass = 0, fail = 0;
  void check(String name, bool ok, [Object? detail]) {
    if (ok) {
      pass++;
      print('✅ PASS $name');
    } else {
      fail++;
      print('❌ FAIL $name  $detail');
    }
  }

  // 1. 瀑布流（匿名）
  final feed = await api.fetchPostList(islandKey: 'all', page: 1, size: 5);
  check('fetchPostList total=${feed.total}', feed.total >= 0 && feed.list.isNotEmpty, 'list 为空');
  final first = feed.list.first;
  print('   首条: postId=${first.postId} island=${first.island} tags=${first.tags} '
      'author=${first.author.nickname} likes=${first.likeCount} coverKeys=${first.coverKeys.length}');

  // 2. 岛屿筛选
  final fitness = await api.fetchPostList(islandKey: 'fitness', page: 1, size: 5);
  check('island=fitness 全部命中', fitness.list.every((p) => p.island == 'fitness'));

  // 3. 标签筛选（带 # 兼容）
  final tagged = await api.fetchPostList(islandKey: 'all', tag: '日更', page: 1, size: 5);
  check('tag=日更 命中 ${tagged.total}', tagged.list.every((p) => p.tags.contains('日更')));

  // 4. 详情
  final detail = await api.fetchPostDetail(first.postId);
  check('fetchPostDetail postId=${detail.postId}', detail.postId == first.postId && detail.commentCount >= 0);

  // 5. 评论分页
  final comments = await api.fetchComments(first.postId, page: 1, size: 10);
  check('fetchComments total=${comments.total}', comments.total >= 0);

  // 6. 热门标签（生产库当前无标签帖 → 空数组是正确返回）
  final tags = await api.fetchHotTags();
  check('fetchHotTags 返回 ${tags.length} 个标签（无标签帖时为空属正常）', tags.every((t) => t.tag.isNotEmpty && t.count > 0));

  // 7. 未登录点赞 → 401
  try {
    await api.toggleLike(first.postId);
    check('toggleLike 匿名 401', false, '未抛 401');
  } on ApiException catch (e) {
    check('toggleLike 匿名 401', e.code == 401, 'code=${e.code} msg=${e.message}');
  }

  // 8. 不存在帖子 → 404
  try {
    await api.fetchPostDetail(99999999);
    check('详情 99999999 → 404', false, '未抛 404');
  } on ApiException catch (e) {
    check('详情 99999999 → 404', e.code == 404 && e.message.contains('不存在'), 'code=${e.code}');
  }

  print('──────────────\n结果: PASS=$pass FAIL=$fail');
}
