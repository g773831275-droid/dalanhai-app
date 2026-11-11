import 'dart:async';

import 'package:flutter/material.dart';

import '../services/cloud_api.dart';
import '../services/cloud_models.dart';
import '../theme/colors.dart';
import 'user_avatar.dart';

/// @用户选择弹窗（v2.9.7 评论输入提取，v2.9.9 起发布页共用）：
/// 搜索框 + 头像/昵称结果列表；选中返回 (nickname, uid)，
/// 头像走 OSS key 签名加载，失败回退首字占位。
/// [onClose] 供外部（删字自动收起）程序化关闭。
class AtUserPicker extends StatefulWidget {
  const AtUserPicker({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<AtUserPicker> createState() => _AtUserPickerState();
}

class _AtUserPickerState extends State<AtUserPicker> {
  final CloudApi _api = CloudApi.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  List<CloudUserSearchItem> _results = <CloudUserSearchItem>[];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => _onSearchChanged(_searchCtrl.text));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _doSearch);
  }

  Future<void> _doSearch() async {
    setState(() => _loading = true);
    try {
      final r = await _api.searchUsers(_searchCtrl.text);
      if (!mounted) return;
      setState(() => _results = r);
    } on ApiException {
      if (!mounted) return;
      setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.only(top: 14),
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: AppColors.deep,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          // 顶部：搜索框 + 关闭
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  // v2.9.9：不做 autofocus —— 焦点留在主输入框，删 @ 可自动
                  // 收起本弹窗；用户点搜索框后才开始过滤搜索
                  style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索昵称，选择要 @ 的船长',
                    hintStyle: const TextStyle(color: AppColors.sub, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.sub),
                    filled: true,
                    fillColor: AppColors.abyss,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.sub),
                onPressed: widget.onClose,
              ),
            ]),
          ),
          const Divider(color: AppColors.line, height: 1),
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold)))
                : _results.isEmpty
                    ? const Center(
                        child: Text('输入昵称关键词搜索',
                            style: TextStyle(color: AppColors.sub, fontSize: 12)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: AppColors.line, height: 1, indent: 16),
                        itemBuilder: (_, i) {
                          final u = _results[i];
                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: AppColors.ocean),
                              child: UserAvatar(
                                avatar: u.avatar,
                                fallbackText: u.displayName,
                                size: 36,
                                fontSize: 15,
                              ),
                            ),
                            title: Text(u.displayName,
                                style: const TextStyle(
                                    color: Color(0xFFEAF2FF), fontSize: 14)),
                            onTap: () =>
                                Navigator.pop(context, (u.displayName, u.userId)),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
