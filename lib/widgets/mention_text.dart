import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../pages/user_profile_page.dart';
import '../services/cloud_api.dart';
import '../theme/colors.dart';

/// 帖子正文 @昵称 高亮渲染（v2.9.9，对齐评论区 _buildContentSpans 行为）：
/// - 正则与评论区一致：@[^@\s，。！？；、]+（含 @ 前缀整段命中）
/// - @ 段落 AppColors.sky 高亮可点击，其余文本保持传入样式
/// - 点击 → /api/users/search 按昵称精确匹配 → 跳转对方主页；
///   未登录/找不到/接口异常 → toast 提示（与评论同口径）
/// 评论区自身渲染保持原实现不动，本组件仅供帖子正文使用。
/// recognizer 按 @名 缓存复用（跨 rebuild 保持同实例防手势中断），State 销毁统一释放。
class MentionText extends StatefulWidget {
  const MentionText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;

  /// 非 @ 文本的基础样式（详情页正文/卡片正文字体各不相同）
  final TextStyle? style;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  static final RegExp _mentionRegex = RegExp(r'@[^@\s，。！？；、]+');

  final Map<String, TapGestureRecognizer> _mentionTaps = <String, TapGestureRecognizer>{};

  TapGestureRecognizer _recognizerOf(String name) {
    return _mentionTaps.putIfAbsent(name, () {
      final r = TapGestureRecognizer();
      r.onTap = () => _openMentionProfile(name);
      return r;
    });
  }

  @override
  void dispose() {
    for (final r in _mentionTaps.values) {
      r.dispose();
    }
    _mentionTaps.clear();
    super.dispose();
  }

  /// 点击 @昵称 → 昵称精确匹配 → 跳对方主页（游客可读，无需登录）；
  /// 找不到/接口异常 → toast；
  /// v2.9.11 账号注销：命中已注销用户 → 静默不跳转不弹窗（AGENTS.md §12.1.4）
  Future<void> _openMentionProfile(String name) async {
    try {
      final list = await CloudApi.instance.searchUsers(name, includeClosed: true);
      final match = list.where((u) => u.nickname == name).firstOrNull;
      if (!mounted) return;
      if (match == null) {
        _toast('未找到该船员');
        return;
      }
      if (match.closed) return; // 已注销用户：无响应（不跳转/不报错/不弹窗）
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfilePage(uid: match.userId)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.code == 401 ? '登录已失效，请重新登录' : '未找到该船员');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          backgroundColor: AppColors.ocean,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final base = widget.style ??
        const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFFEAF2FF));
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _mentionRegex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      final name = m.group(0)!.substring(1);
      spans.add(TextSpan(
        text: m.group(0), // 含 @ 前缀
        style: base.copyWith(color: AppColors.sky),
        recognizer: _recognizerOf(name),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return Text.rich(TextSpan(children: spans));
  }
}
