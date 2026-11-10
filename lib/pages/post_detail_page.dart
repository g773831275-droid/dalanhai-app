import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../data/data_store_provider.dart';
import '../data/seed_data.dart';

/// 帖子详情页 — 对应 H5 renderPostDetail
/// 多图轮播 + 点赞 + 举报/拉黑/删除
class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  int _imgIndex = 0;

  Post? _findPost(DataStore store) {
    for (final p in [...seedPosts, ...store.data.posts]) {
      if (p.id == widget.postId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = DataStoreProvider.of(context);
    final p = _findPost(store);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('帖子不存在或已被删除', style: AppTypography.bodySub)),
      );
    }

    final imgs = p.images;
    final isMine = p.isMine;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20),
                  onPressed: () => Navigator.pop(context)),
                Expanded(child: Text('航海日志', style: AppTypography.titleZh, textAlign: TextAlign.center)),
                const SizedBox(width: 48),
              ]),
            ),
            // 内容
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面/轮播
                    if (imgs.isNotEmpty)
                      SizedBox(
                        height: 360,
                        child: Stack(
                          children: [
                            PageView.builder(
                              itemCount: imgs.length,
                              onPageChanged: (i) => setState(() => _imgIndex = i),
                              itemBuilder: (_, i) => Image.memory(
                                _decode(imgs[i]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _gradientCover(p),
                              ),
                            ),
                            if (imgs.length > 1) ...[
                              // 导航箭头
                              Positioned(left: 8, top: 0, bottom: 0,
                                child: Center(child: _navBtn(Icons.chevron_left, () => _slide(-1, imgs.length)))),
                              Positioned(right: 8, top: 0, bottom: 0,
                                child: Center(child: _navBtn(Icons.chevron_right, () => _slide(1, imgs.length)))),
                              // dots
                              Positioned(bottom: 10, left: 0, right: 0,
                                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(imgs.length, (i) => Container(
                                    width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == _imgIndex ? AppColors.gold : AppColors.sub.withValues(alpha: 0.4),
                                    ),
                                  )),
                                )),
                            ],
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 240,
                        width: double.infinity,
                        child: _gradientCover(p),
                      ),
                    // 正文
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 作者行
                          Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
                              alignment: Alignment.center,
                              child: p.avatarUrl != null
                                  ? ClipOval(child: Image.memory(_decode(p.avatarUrl!), fit: BoxFit.cover, width: 36, height: 36))
                                  : Text(p.avatar ?? '航', style: const TextStyle(color: AppColors.parchment)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.author, style: AppTypography.titleZh.copyWith(fontSize: 15)),
                                Text('${p.time} · ${Island.byId(p.island ?? '')?.name ?? ''}',
                                  style: AppTypography.caption),
                              ],
                            )),
                            if (isMine)
                              _actionBtn('🗑 删除', AppColors.sub, () => _delete(context, store, p.id))
                            else
                              _actionBtn('🚫 拉黑', AppColors.sub, () => _block(context, store, p.author)),
                          ]),
                          const SizedBox(height: 16),
                          Text(p.text, style: AppTypography.body.copyWith(fontSize: 15, height: 1.7)),
                          if (p.tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, children: p.tags.map((t) =>
                              Text('#$t', style: const TextStyle(color: AppColors.sky, fontSize: 13))).toList()),
                          ],
                          const SizedBox(height: 16),
                          // 操作行
                          Row(children: [
                            GestureDetector(
                              onTap: () => store.toggleLike(p.id),
                              child: Row(children: [
                                Icon(p.liked ? Icons.favorite : Icons.favorite_border,
                                  size: 20, color: p.liked ? AppColors.coral : AppColors.sub),
                                const SizedBox(width: 4),
                                Text('${p.likes}', style: TextStyle(color: p.liked ? AppColors.coral : AppColors.sub)),
                              ]),
                            ),
                            if (!isMine) ...[
                              const SizedBox(width: 24),
                              GestureDetector(
                                onTap: () => _report(context, store, p.id),
                                child: const Row(children: [
                                  Icon(Icons.flag_outlined, size: 18, color: AppColors.sub),
                                  SizedBox(width: 4),
                                  Text('举报', style: TextStyle(color: AppColors.sub, fontSize: 13)),
                                ]),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: AppColors.glass, shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.parchment, size: 24),
    ),
  );

  Widget _actionBtn(String text, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    ),
  );

  Widget _gradientCover(Post p) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(p.bgFrom), Color(p.bgTo)],
    )),
    alignment: Alignment.center,
    child: Text(p.emoji ?? '⚓', style: const TextStyle(fontSize: 56)),
  );

  void _slide(int dir, int total) {
    setState(() => _imgIndex = (_imgIndex + dir + total) % total);
  }

  void _delete(BuildContext context, DataStore store, String id) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.deep,
      content: const Text('确定删除这条日志？', style: TextStyle(color: AppColors.parchment)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () {
          store.deletePost(id);
          Navigator.pop(context);
          Navigator.pop(context);
        }, child: const Text('删除', style: TextStyle(color: AppColors.coral))),
      ],
    ));
  }

  void _block(BuildContext context, DataStore store, String name) {
    store.blockUser(name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已拉黑 $name'), backgroundColor: AppColors.ocean, behavior: SnackBarBehavior.floating),
    );
    Navigator.pop(context);
  }

  void _report(BuildContext context, DataStore store, String id) {
    store.reportPost(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已举报，感谢维护航海秩序'), backgroundColor: AppColors.ocean, behavior: SnackBarBehavior.floating),
    );
  }

  Uint8List _decode(String src) {
    final clean = src.contains(',') ? src.split(',').last : src;
    return base64Decode(clean);
  }
}
