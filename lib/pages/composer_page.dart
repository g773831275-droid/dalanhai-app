import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../services/cloud_api.dart';
import '../services/cloud_feed.dart';
import '../services/cloud_models.dart' show cloudIslandToLocal;
import '../services/image_pipeline.dart';
import '../services/media_rules.dart';
import '../services/session_store.dart';
import '../app.dart' show appTabIndex;

/// 发帖页 — v2.9.2 起接通云端（此前只写本地 DataStore，云端列表永远看不到新帖）
///
/// 链路：图片压缩 → OSS 直传（uploadImage 换对象 key）→ POST /api/posts
/// （type=text/image + content + attachUrl(s) + island + tags）。
/// 成功后发 kCloudFeedRefreshSignal 让港口流重拉第一页；失败报错不关页。
class ComposerPage extends StatefulWidget {
  /// initialTags：预选标签（如岛屿详情页「去港口分享今日日志」带入当前岛名）
  const ComposerPage({super.key, this.initialTags});

  final Set<String>? initialTags;

  @override
  State<ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<ComposerPage> {
  final _textCtrl = TextEditingController();
  final _selectedTags = <String>{};
  // v2.6.1 媒体规范：单帖最多 4 张（后端强校验，前端同规则前置拦截）
  final List<String?> _images = List<String?>.filled(MediaRules.imageMaxPerPost, null);

  static const _allTags = ['清心岛', '戒烟岛', '健身岛', '早睡岛', '日更', '新船员', '妙招'];

  /// 岛屿标签 → 后端 island key（POST /api/posts 的 island 枚举，单值）
  static const Map<String, String> _islandKeyByName = <String, String>{
    '清心岛': 'clear-mind',
    '戒烟岛': 'quit-smoke',
    '健身岛': 'fitness',
    '早睡岛': 'early-sleep',
  };

  final _picker = ImagePicker();
  final CloudApi _api = CloudApi.instance;
  bool _submitting = false; // 防重复提交（发布中禁用按钮）

  /// 选择图片（点击图片槽触发）
  /// v2.6.1 压缩管线：长边 2048px / 画质 0.7~0.8 / 目标 ≤5MB（后端硬上限 10MB 兜底）；
  /// 压缩失败 / 超限 → SnackBar 提示，不占槽位
  Future<void> _pickImage(int slot) async {
    if (_images.where((x) => x != null).length >= MediaRules.imageMaxPerPost) {
      _toast('单次发帖最多 ${MediaRules.imageMaxPerPost} 张图片');
      return;
    }
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      // v2.9.3：直接传 XFile（Web 跳过原生压缩用原图；移动端走原生压缩管线）
      final bytes = await compressImage(picked);
      setState(() => _images[slot] = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    } on MediaValidationException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('图片处理失败，请换一张试试');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.coral, behavior: SnackBarBehavior.floating),
    );
  }

  /// 删除图片（点击已选图片）
  void _removeImage(int slot) {
    setState(() => _images[slot] = null);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _textCtrl.text.trim();
    final imgs = _images.where((x) => x != null).cast<String>().toList();
    // v2.6.1：单帖 ≤4 张（与后端闸门同规则；槽位本身也限制 4）
    if (imgs.length > MediaRules.imageMaxPerPost) {
      _toast('单次发帖最多 ${MediaRules.imageMaxPerPost} 张图片');
      return;
    }
    if (text.isEmpty && imgs.isEmpty) {
      _toast('写点什么或选张图片再发布吧');
      return;
    }
    if (!SessionStore.instance.hasToken) {
      _toast('登录已失效，请重新登录后再发布');
      return;
    }

    setState(() => _submitting = true);
    try {
      // 1. 图片逐张 OSS 直传（压缩产物为 jpeg base64 data url → 换对象 key）
      final keys = <String>[];
      for (final dataUrl in imgs) {
        final bytes = base64Decode(dataUrl.split(',').last);
        keys.add(await _api.uploadImage(bytes, ext: 'jpg'));
      }
      // 2. 岛屿归属（v2.9.3 多岛屿分发）：勾选几个岛就传几个 key，
      //    主岛（展示用）取第一个 —— 不再只取第一个丢掉其余
      final List<String> islandKeys = _islandKeyByName.entries
          .where((e) => _selectedTags.contains(e.key))
          .map((e) => e.value)
          .toList();
      // 3. 发帖（tags 原样传，后端白名单校验 + 自动去 # 前缀）
      final r = await _api.createPost(
        type: keys.isEmpty ? 'text' : 'image',
        content: text,
        attachKeys: keys.isEmpty ? null : keys,
        island: islandKeys.isEmpty ? null : islandKeys.first,
        islands: islandKeys.isEmpty ? null : islandKeys,
        tags: _selectedTags.toList(),
      );
      // 4. 成功：popUntil 回根（清掉岛屿详情页栈）→ 统一切港口 Tab →
      //    按需切岛屿分类 → 刷新流 + 定位新帖（v2.9.3/v2.9.4）
      final int postId =
          (r['postId'] as num?)?.toInt() ?? ((r['id'] as num?)?.toInt() ?? 0);
      if (!mounted) return;
      // toast 先发（用未 pop 的 context；SnackBar 挂在根 messenger，跨路由可见）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(postId > 0 ? '发布成功，已为你跳转到帖子' : '航海日志已发布'),
          backgroundColor: AppColors.ocean,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // 跟随最终帖子的岛标签：以提交时的实际选中集为准 ——
      // 换岛（取消预选岛、勾别的岛）跟随新岛；无任何岛标签 → 停【全部】不发信号
      // （pop 前捕获，popUntil 后本 State 不可再读）
      final String? finalIslandName = _selectedTags
          .where(_islandKeyByName.keys.contains)
          .cast<String>()
          .firstOrNull;
      final String? islandKey =
          finalIslandName != null ? _islandKeyByName[finalIslandName] : null;
      // 入口区分：岛屿详情页带 initialTags 进来 = 岛屿入口；否则 = 底部发布入口
      final bool fromIslandEntry = (widget.initialTags ?? const <String>{}).isNotEmpty;
      // popUntil 首页：清空 composer + 岛屿详情页路由栈，直接落回主壳层
      // （正常入口只压了 composer 一层，行为与原 pop 等价，不受影响）
      Navigator.of(context).popUntil((route) => route.isFirst);
      // 切 tab / 发信号延后一帧：等 pop 渲染完成，避免与路由动画同帧抢占时序。
      // ⚠️ 不用 composer 的 mounted 守卫 —— pop 动画结束后本 State 已 dispose，
      // mounted 会恒 false 导致切 tab 被跳过；以下全是全局单例，无 context 依赖。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('[composer-post] callback run, current appTabIndex=${appTabIndex.value}');
        appTabIndex.value = 1; // 港口 Tab（无论从哪个入口进入发布页，行为统一）
        debugPrint('[composer-post] set appTabIndex=1');
        // ── 入口分流（两套信号互相独立）──
        // 1) 岛屿详情页入口：跟随最终帖子的主岛标签切分类（原有逻辑不动）。
        //    ⚠️ PortTab 的 chip id 是本地 Island.id（qingxin/zaoshui...），
        //    必须用 cloudIslandToLocal 转换；直接发后端 key（clear-mind）会
        //    匹配不上 chip 且 kCloudIslandKeys 查不到 → 回落 'all' 刷新（踩坑实锤）
        if (fromIslandEntry) {
          if (islandKey != null) {
            final String? localId = cloudIslandToLocal(islandKey);
            if (localId != null) {
              kPortIslandFilterSignal.value = localId;
              debugPrint('[composer-post] set island filter=$localId');
            }
          }
        } else {
          // 2) 底部发布入口：固定落点【全部】+【最新】—— 无论帖子带不带岛标签。
          //    发 ''（无岛语义）→ PortTab._onFeedAlign 走「切全部+最新」分支；
          //    已在全部+最新时两处判断跳过，等于停留原地，定位照常
          kPortFeedAlignSignal.add('');
          debugPrint('[composer-post] feed align → all+latest');
        }
        kCloudFeedRefreshSignal.value++;
        if (postId > 0) kFeedLocatePostSignal.add(postId);
      });
    } on ApiException catch (e) {
      _toast(e.message); // 失败不关页，草稿保留可改后重发
    } catch (_) {
      _toast('发布失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 预选标签初始化（岛屿详情页跳转带入当前岛名；只接受合法标签，防脏值）
  @override
  void initState() {
    super.initState();
    final pre = widget.initialTags;
    if (pre != null && pre.isNotEmpty) {
      _selectedTags.addAll(pre.where(_allTags.contains));
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏（返回 + 标题 + 发布按钮；发布中禁用防重复提交）
            _TopBar(onSubmit: _submit, busy: _submitting),
            // 内容（v2.9.2：留白适度加大，减少拥挤感）
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 文本输入（v2.9.2：上限 200→800 字符，对标 X）
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0x59000000), // rgba(0,0,0,.35)
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sky.withValues(alpha: 0.2)),
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        maxLines: 6,
                        minLines: 4,
                        maxLength: 800,
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
                        decoration: const InputDecoration(
                          hintText: '分享今天的坚持与状态（最多800字）',
                          hintStyle: TextStyle(color: AppColors.placeholder),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                          counterStyle: TextStyle(color: AppColors.sub, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 4 个图片槽（v2.6.1 媒体规范：单帖最多 4 张；选中即预览缩略图 + 右上角单独删除）
                    Row(
                      children: List.generate(MediaRules.imageMaxPerPost, (i) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < MediaRules.imageMaxPerPost - 1 ? 10 : 0),
                          child: _ImageSlot(
                            image: _images[i],
                            onTap: () => _images[i] == null ? _pickImage(i) : _removeImage(i),
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 16),
                    // 标签 chips（v2.9.2：弱化厚重边框、降低饱和度；选中保留金色高亮）
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: _allTags.map((t) {
                        final on = _selectedTags.contains(t);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (on) {
                              _selectedTags.remove(t);
                            } else {
                              _selectedTags.add(t);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: on ? AppColors.btnGoldGradient : null,
                              color: on ? null : AppColors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: on ? null : Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              '#$t',
                              style: TextStyle(
                                fontSize: 11,
                                color: on ? AppColors.goldBtnText : AppColors.sub,
                                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
}

/// 顶栏 — 对应 H5 composer 弹窗顶栏
class _TopBar extends StatelessWidget {
  final VoidCallback onSubmit;
  final bool busy;
  const _TopBar({required this.onSubmit, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.gold, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  '✍️ 发布航海日志',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gold),
                ),
                const SizedBox(height: 2),
                Text(
                  '记录今天的坚持，寄给同海域的船员',
                  style: TextStyle(fontSize: 11, color: AppColors.sub),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onSubmit,
            child: Text(
              busy ? '发布中…' : '发布',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 图片槽 — 对应 H5 .composer .img-slot（aspect-ratio:1, dashed border, + 占位）
class _ImageSlot extends StatelessWidget {
  final String? image; // base64 data url 或 null
  final VoidCallback onTap;

  const _ImageSlot({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: hasImage ? Colors.black : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: hasImage
                ? null
                : Border.all(color: AppColors.sky.withValues(alpha: 0.3), style: BorderStyle.solid),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(base64Decode(image!.split(',').last), fit: BoxFit.cover),
                    // 删除小角标
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: onTap,
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xCC000000),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.sub, size: 28),
                ),
        ),
      ),
    );
  }
}