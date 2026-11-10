import 'dart:async';

import 'package:flutter/material.dart';

/// UGC 图片/文件上传类审核报错的统一「醒目 Toast」（v2.9.5 表单报错规范）。
///
/// 规范（区别于旧版页面底部淡色半透明浮条 SnackBar）：
/// - 高对比不透明底色 + 描边 + 红色 #ef4444 文字 + 图标，屏幕中央弹出
/// - 默认展示 2500ms 后自动消失，点击可提前关闭
/// - 适用于：头像审核失败、帖子配图审核失败等「上传类」报错；
///   单行文本输入类（昵称/简介）报错请用控件下方内联红字，不要用本组件
void showAlertToast(
  BuildContext context,
  String msg, {
  Duration duration = const Duration(milliseconds: 2500),
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AlertToastView(
      message: msg,
      duration: duration,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _AlertToastView extends StatefulWidget {
  const _AlertToastView({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_AlertToastView> createState() => _AlertToastViewState();
}

class _AlertToastViewState extends State<_AlertToastView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 避开状态栏与底部导航，屏幕中央偏上
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.38,
      left: 32,
      right: 32,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onDismiss, // 点击提前关闭
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220), // 高对比：不透明深底
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Color(0xFFEF4444), // 红色 #ef4444
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
