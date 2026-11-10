import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// 本地持久化封装 — 对应 H5 的 localStorage 操作
///
/// 三个键（与 H5 保持一致，便于未来跨平台数据迁移）：
/// - dalanhai_v2         主数据对象（打卡/证书/帖子/船长/举报）
/// - dalanhai_used_names 已注册用户名数组（唯一性校验）
/// - dalanhai_eula       EULA 同意标记
class Prefs {
  static const _keyData = 'dalanhai_v2';
  static const _keyNames = 'dalanhai_used_names';
  static const _keyEula = 'dalanhai_eula';

  static SharedPreferences? _instance;

  static Future<SharedPreferences> get _sp async =>
      _instance ??= await SharedPreferences.getInstance();

  // ── 主数据 ──
  static Future<AppData> loadData() async {
    final sp = await _sp;
    final raw = sp.getString(_keyData);
    if (raw == null) return AppData();
    try {
      return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppData();
    }
  }

  static Future<void> saveData(AppData data) async {
    final sp = await _sp;
    await sp.setString(_keyData, jsonEncode(data.toJson()));
  }

  // ── 用户名 ──
  static Future<List<String>> loadUsedNames() async {
    final sp = await _sp;
    final raw = sp.getString(_keyNames);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveUsedNames(List<String> names) async {
    final sp = await _sp;
    await sp.setString(_keyNames, jsonEncode(names));
  }

  /// 检查用户名是否已被占用（不区分大小写）
  static Future<bool> isNameUsed(String name) async {
    final names = await loadUsedNames();
    return names.any((n) => n.toLowerCase() == name.toLowerCase());
  }

  /// 添加用户名到已用列表
  static Future<void> addUsedName(String name) async {
    final names = await loadUsedNames();
    if (!names.any((n) => n.toLowerCase() == name.toLowerCase())) {
      names.add(name);
      await saveUsedNames(names);
    }
  }

  // ── EULA ──
  static Future<bool> isEulaAccepted() async {
    final sp = await _sp;
    return sp.getString(_keyEula) == '1';
  }

  static Future<void> acceptEula() async {
    final sp = await _sp;
    await sp.setString(_keyEula, '1');
  }

  // ── 重置（开发调试用）──
  static Future<void> clearAll() async {
    final sp = await _sp;
    await sp.remove(_keyData);
    await sp.remove(_keyNames);
    await sp.remove(_keyEula);
  }
}
