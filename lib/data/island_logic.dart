import 'models.dart';

/// 打卡纯逻辑函数 — 从 H5 JS 翻译，无副作用、无状态
/// 状态管理在 data_store.dart 中

/// 日期格式化为 'YYYY-MM-DD'（对应 H5 dateStr / todayStr）
String dateStr(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String todayStr() => dateStr(DateTime.now());

/// 连续打卡天数（从今天往回数）
/// 对应 H5 streak(id)：如果今天没打卡则返回 0
int streak(List<String> checkins) {
  final set = checkins.toSet();
  if (set.isEmpty) return 0;
  int count = 0;
  DateTime d = DateTime.now();
  if (!set.contains(dateStr(d))) return 0;
  while (set.contains(dateStr(d))) {
    count++;
    d = d.subtract(const Duration(days: 1));
  }
  return count;
}

/// 累计打卡天数
int totalDays(List<String> checkins) => checkins.length;

/// 今日是否已打卡
bool isCheckedToday(List<String> checkins) => checkins.contains(todayStr());

/// 打卡结果
enum CheckinResult {
  alreadyDone,  // 今日已打卡
  success,      // 打卡成功（未达 21 天）
  certificate,  // 打卡成功 + 达成 21 天征服
}

/// 执行打卡（纯逻辑，不涉及持久化）
/// 返回 CheckinResult，调用方负责保存数据和弹证书
/// 对应 H5 doCheckin(id)
CheckinResult doCheckin(Map<String, List<String>> checkins, String id) {
  final today = todayStr();
  checkins.putIfAbsent(id, () => []);
  if (checkins[id]!.contains(today)) return CheckinResult.alreadyDone;
  checkins[id]!.add(today);
  if (streak(checkins[id]!) >= Island.target) {
    return CheckinResult.certificate;
  }
  return CheckinResult.success;
}

/// 检查某岛屿是否已获得征服证书
bool hasCertificate(List<Certificate> certs, String islandId) {
  return certs.any((c) => c.island == islandId);
}
