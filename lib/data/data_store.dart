import 'dart:async';

import 'package:flutter/foundation.dart';
import 'prefs.dart';
import 'island_logic.dart' as logic;
import 'seed_data.dart';
import 'dart:math';

/// 全局数据仓库 — ChangeNotifier 驱动 UI 刷新
///
/// 使用方式：
/// ```dart
/// final store = DataStoreProvider.of(context);
/// store.checkin(islandId);  // 自动 notifyListeners → 所有监听 widget 刷新
/// ```
class DataStore extends ChangeNotifier {
  AppData _data = AppData();
  bool _loaded = false;

  AppData get data => _data;
  bool get loaded => _loaded;

  /// 初始化（在 app 启动时调用一次）
  Future<void> load() async {
    _data = await Prefs.loadData();
    _loaded = true;
    notifyListeners();
  }

  // ── 查询 ──
  List<String> checkinsOf(String islandId) => _data.checkins[islandId] ?? [];

  /// 当前连续：云端镜像值优先（后端 Asia/Shanghai 口径，设备时区无关）；
  /// 镜像为 null（老存档/热重载残留/离线本地模式）→ 空安全降级本地自算
  int streakOf(String islandId) {
    final m = _data.cloudStreaks;
    final v = m == null ? null : m[islandId];
    return v ?? logic.streak(checkinsOf(islandId));
  }

  /// 全历史最长连续：同上，云端下发值优先
  int maxStreakOf(String islandId) {
    final m = _data.cloudMaxStreaks;
    final v = m == null ? null : m[islandId];
    return v ?? streakOf(islandId);
  }

  /// v2.9.6 修复统计断层：该岛全历史累计打卡天数 ——
  /// 云端 total 镜像优先（后端全历史 COUNT，与船长页统计同口径）；
  /// 镜像为 null（老存档/离线本地模式）→ 空安全降级窗口计算（最近 21 天）。
  /// 修复点：此前只算 checkinsOf（21 天窗口），打卡超 21 天后
  /// 岛屿卡片「累计 N 天」会缩水，与船长页全历史统计不一致。
  int totalDaysOf(String islandId) {
    final m = _data.cloudTotals;
    final v = m == null ? null : m[islandId];
    return v ?? logic.totalDays(checkinsOf(islandId));
  }
  bool isCheckedToday(String islandId) => logic.isCheckedToday(checkinsOf(islandId));
  bool hasCert(String islandId) => logic.hasCertificate(_data.certificates, islandId);

  /// 所有岛屿累计打卡次数
  int get totalCheckins => Island.all.fold(0, (s, i) => s + totalDaysOf(i.id));

  /// 最长连续天数（所有岛屿取最大；v2.9.3 起用云端下发的历史最长，不再本地按设备时间算）
  int get maxStreak => Island.all.fold(0, (m, i) {
    final s = maxStreakOf(i.id);
    return s > m ? s : m;
  });

  // ── 操作 ──

  /// 打卡（对应 H5 checkin → doCheckin）
  /// 返回 CheckinResult，UI 层根据结果弹 toast / 证书
  logic.CheckinResult checkin(String islandId) {
    final result = logic.doCheckin(_data.checkins, islandId);
    if (result == logic.CheckinResult.alreadyDone) return result;

    // 达成 21 天 → 发证书（首次）
    if (result == logic.CheckinResult.certificate && !hasCert(islandId)) {
      _data.certificates.add(Certificate(island: islandId, date: logic.todayStr()));
    }
    _persist();
    notifyListeners();
    return result;
  }

  /// 看广告补签（对应 H5 watchAd → doCheckin）
  /// 首版 AD_MAKEUP_ENABLED=false，此方法保留但 UI 不显示入口
  logic.CheckinResult adMakeup(String islandId) {
    if (isCheckedToday(islandId)) return logic.CheckinResult.alreadyDone;
    return checkin(islandId);
  }

  // ── 船长 / 认证 ──

  Captain? get captain => _data.captain;
  /// 登录态 —— 本地模拟登录阶段：有船长即算已登录（含 loginBy=local，用户要求）
  /// TODO(后端对接后改回): _data.captain != null && _data.captain!.loginBy != 'local'
  /// （届时 loginBy='local' 的默认船长重新代表游客态）
  bool get isLoggedIn => _data.captain != null;

  /// ⚠️ 不再自动创建本地船长（原 ensureLocalCaptain 已移除）：
  /// 登录态现按「captain != null」判定，自动创建会把未登录用户直接变成已登录；
  /// 未登录时船长页由登录闸门拦截（app.dart _onTabSelected），CaptainTab 对 null 做空占位防御。

  /// 登录成功后设置船长
  void login(String name, String loginBy) {
    _data.captain = Captain(name: name, loginBy: loginBy, at: DateTime.now().millisecondsSinceEpoch);
    Prefs.addUsedName(name);
    // v2.9.11 账号注销配套：本地打卡镜像按会话隔离 —— 登录即清残留
    // （旧 uid/旧账号的 checkins/cloudTotals 等不再带给新登录账号，云端数据由
    // auth_page 登录成功后的 4 岛回填写入真实值）
    resetCheckinMirror();
    notifyListeners();
  }

  /// 更新昵称（v2.9.5 修复头像重置 bug）：只改现有 Captain.name，
  /// **绝不重建对象** —— 旧实现走 login() 会整体重建 Captain 丢掉 avatar 字段，
  /// 导致改昵称后船长页头像被重置为默认首字。avatar 等其余字段原样保留。
  void updateNickname(String name) {
    if (_data.captain == null) return;
    _data.captain!.name = name;
    _persist();
    notifyListeners();
  }

  void logout() {
    _data.captain = null;
    // v2.9.11：登出同步清打卡镜像（未登录岛屿页显示清零，不残留上一账号数据）
    resetCheckinMirror();
    notifyListeners();
  }

  /// v2.9.11：清空打卡相关本地镜像（21 天窗口 + 云端三镜像 + 证书）。
  /// 登录/登出/账号切换时调用 —— 打卡数据真源在云端（按 uid 绑定），
  /// 本地存档 dalanhai_v2 是设备级单份，不隔离账号，必须在会话边界重置。
  void resetCheckinMirror() {
    _data.checkins.clear();
    _data.cloudStreaks?.clear();
    _data.cloudMaxStreaks?.clear();
    _data.cloudTotals?.clear();
    _data.certificates.clear();
    _persist();
  }

  /// v2.9.3：服务端"今天"（Asia/Shanghai）—— 日历窗口/选中格唯一时间来源
  /// [dates] = 云端 checkinDateList（yyyy-MM-dd，最近 21 天）。
  /// v2.9.3：[continueDays]/[maxStreakDays] = 后端计算的连续值（镜像存储，
  /// 船长页/卡片统计不再用设备时间自算 —— 设备时区≠+8 时必错）。
  /// v2.9.6：[totalDays] = 后端全历史去重打卡总数（累计口径真源，
  /// 岛屿卡片与船长页统计统一）。
  void syncIslandCheckins(
    String islandId,
    List<String> dates, {
    bool conquered = false,
    int? continueDays,
    int? maxStreakDays,
    int? totalDays,
  }) {
    _data.checkins[islandId] = List<String>.from(dates);
    // ??= 自愈：老存档/热重载实例上镜像 map 可能为 null，写入时即初始化
    final streaks = _data.cloudStreaks ??= <String, int>{};
    if (continueDays != null) streaks[islandId] = continueDays;
    final maxStreaks = _data.cloudMaxStreaks ??= <String, int>{};
    if (maxStreakDays != null) maxStreaks[islandId] = maxStreakDays;
    final totals = _data.cloudTotals ??= <String, int>{};
    if (totalDays != null) totals[islandId] = totalDays;
    if (conquered && !hasCert(islandId)) {
      _data.certificates.add(Certificate(
        island: islandId,
        date: dates.isNotEmpty ? dates.last : logic.todayStr(),
      ));
    }
    _persist();
    notifyListeners();
  }

  /// 更新船长名
  String? updateName(String name) {
    if (_data.captain == null) return '未登录';
    if (name.trim().isEmpty) return '名字不能为空';
    if (reservedNames.any((r) => r.toLowerCase() == name.toLowerCase())) return '该名称已被保留';
    _data.captain!.name = name.trim();
    _persist();
    notifyListeners();
    return null;
  }

  /// 更新头像
  void updateAvatar(String dataUrl) {
    if (_data.captain == null) return;
    _data.captain!.avatar = dataUrl;
    _persist();
    notifyListeners();
  }

  /// 军衔（对应 H5 captain-rank）
  String get rank {
    final c = _data.certificates.length;
    if (c >= 2) return 'GRAND ADMIRAL 大提督';
    if (c >= 1) return 'CAPTAIN 船长';
    return 'FIRST MATE 大副';
  }

  // ── 帖子 / UGC ──

  /// 可见帖子列表（种子帖 + 用户帖，过滤被拉黑用户）
  List<Post> get visiblePosts {
    final all = [...seedPosts, ..._data.posts];
    return all.where((p) => !_data.blockedUsers.contains(p.author)).toList();
  }

  /// 按岛屿筛选的帖子
  List<Post> filteredPosts(String islandFilter) {
    final posts = visiblePosts;
    if (islandFilter == 'all') return posts;
    return posts.where((p) => p.island == islandFilter).toList();
  }

  /// 发帖（对应 H5 submitPost）
  /// 返回 null 成功，返回字符串为错误消息
  String? addPost({required String text, List<String> images = const [], List<String> tags = const []}) {
    if (text.trim().isEmpty && images.isEmpty) return '写点什么，或至少传一张图';
    final bad = filterText(text);
    if (bad != null) return '含敏感词: $bad，请修改后发布';

    final r = Random();
    _data.posts.insert(0, Post(
      id: 'u${DateTime.now().millisecondsSinceEpoch}',
      author: _data.captain?.name ?? '航海家',
      avatar: _data.captain?.name.isNotEmpty == true ? _data.captain!.name[0] : '航',
      avatarUrl: _data.captain?.avatar,
      text: text.trim(),
      images: images,
      tags: tags,
      time: '刚刚',
      emoji: postEmojiPool[r.nextInt(postEmojiPool.length)],
      bgFrom: postBgPool[r.nextInt(postBgPool.length)][0],
      bgTo: postBgPool[r.nextInt(postBgPool.length)][1],
    ));
    _persist();
    notifyListeners();
    return null;
  }

  void deletePost(String id) {
    _data.posts.removeWhere((p) => p.id == id);
    _persist();
    notifyListeners();
  }

  void toggleLike(String id) {
    for (final p in [...seedPosts, ..._data.posts]) {
      if (p.id == id) {
        p.liked = !p.liked;
        p.likes += p.liked ? 1 : -1;
        break;
      }
    }
    _persist();
    notifyListeners();
  }

  void reportPost(String id) {
    _data.reports.add(Report(postId: id, reason: '用户举报', at: DateTime.now().millisecondsSinceEpoch));
    _persist();
    notifyListeners();
  }

  void blockUser(String name) {
    if (!_data.blockedUsers.contains(name)) {
      _data.blockedUsers.add(name);
      _persist();
      notifyListeners();
    }
  }

  bool isBlocked(String name) => _data.blockedUsers.contains(name);

  // ── 群聊 ──

  /// 获取群消息（种子 + 用户发送的）
  List<GroupMessage> groupMessages(String groupId) {
    return [...seedGroupMsgs[groupId] ?? [], ..._data.groupMsgs[groupId] ?? []];
  }

  void sendGroupMsg(String groupId, String text) {
    _data.groupMsgs.putIfAbsent(groupId, () => []);
    _data.groupMsgs[groupId]!.add(GroupMessage(mine: true, text: text, name: _data.captain?.name ?? '航海家'));
    _persist();
    notifyListeners();
  }

  // ── 持久化 ──
  // v2.9.12 防抖写盘：此前每次小操作（点赞/发消息/改昵称）都全量 jsonEncode 写盘，
  // 连续操作时反复整包序列化。合并 400ms 窗口内的写入，失败打印不静默。
  Timer? _persistDebounce;

  void _persist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), () {
      Prefs.saveData(_data).catchError((Object e) {
        debugPrint('[data-store] persist failed: $e');
      });
    });
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    super.dispose();
  }

  /// 重置所有数据（调试用）
  Future<void> clearAll() async {
    _persistDebounce?.cancel(); // 防止防抖定时器在清空后又把旧数据写回去
    _data = AppData();
    await Prefs.clearAll();
    notifyListeners();
  }
}
