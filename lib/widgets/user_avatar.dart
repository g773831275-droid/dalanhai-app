import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/media_sign_cache.dart';
import '../theme/colors.dart';

/// v2.9.4 统一头像组件 —— 船长页 / 港口 feed / 帖子详情 / 评论区 / 群组共用。
///
/// [avatar] 三种形态：
/// ① null / 空 → 首字占位圆
/// ② `data:` 开头（旧版本 base64 数据）→ Image.memory
/// ③ OSS 对象 key → MediaSignCache.urlForKey 时效签名 URL（900s，过期自动重取），
///    加载失败 / 签名失败 → 回退首字占位（不破版）
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatar,
    required this.fallbackText,
    this.size = 36,
    this.fontSize,
  });

  final String? avatar;
  final String fallbackText;
  final double size;
  final double? fontSize;

  String get _initial {
    final t = fallbackText.trim();
    return t.isNotEmpty ? t.characters.first : '航';
  }

  @override
  Widget build(BuildContext context) {
    final a = avatar?.trim() ?? '';
    Widget? inner;
    if (a.startsWith('data:')) {
      try {
        final Uint8List bytes =
            Uint8List.fromList(UriData.parse(a).contentAsBytes());
        inner = ClipOval(
          child: Image.memory(bytes, fit: BoxFit.cover, width: size, height: size),
        );
      } catch (_) {
        inner = null; // 脏数据回退首字
      }
    } else if (a.isNotEmpty && !a.contains(' ')) {
      // OSS key → 时效签名 URL（media/sign keys 通道，900s）
      inner = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: FutureBuilder<String?>(
            future: MediaSignCache.instance.urlForKey(a),
            builder: (context, snap) {
              final url = snap.data;
              if (url == null || url.isEmpty) return _initialCircle();
              return Image.network(
                url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, _, _) => _initialCircle(),
              );
            },
          ),
        ),
      );
    }
    return inner ?? _initialCircle();
  }

  Widget _initialCircle() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ocean),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: AppColors.parchment,
          fontSize: fontSize ?? size * 0.42,
        ),
      ),
    );
  }
}
