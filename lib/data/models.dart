/// 大蓝海数据模型 — 对应 H5 的 dalanhai_v2 localStorage 结构
library;

/// 主数据对象（对应 localStorage key: dalanhai_v2）
class AppData {
  /// {岛屿id: [日期字符串]}
  Map<String, List<String>> checkins;

  /// v2.9.3：云端下发的当前连续天数 {岛屿id: continueDays}（后端 Asia/Shanghai 口径，
  /// 镜像展示用 —— 设备时区 ≠ +8 时本地自算必错，统计真源在云端）。
  /// 可空：老存档/异常路径为 null → data_store 侧空安全降级本地计算
  Map<String, int>? cloudStreaks;

  /// v2.9.3：云端下发的历史最长连续 {岛屿id: maxStreakDays}（可空，同上）
  Map<String, int>? cloudMaxStreaks;

  /// v2.9.6 修复打卡统计断层：云端下发的全历史累计打卡 {岛屿id: total}
  /// （后端全历史 COUNT 口径，镜像展示用 —— checkins 镜像只有最近 21 天窗口，
  ///  打卡超 21 天后窗口口径会缩水，与船长页全历史统计不一致）
  /// 可空：老存档为 null → data_store 侧空安全降级窗口计算
  Map<String, int>? cloudTotals;

  /// 征服证书列表
  List<Certificate> certificates;

  /// 航海日志（UGC 帖子）
  List<Post> posts;

  /// 当前登录船长（null = 未登录）
  Captain? captain;

  /// 举报记录
  List<Report> reports;

  /// 拉黑的用户名列表
  List<String> blockedUsers;

  /// 群聊消息 {groupId: [GroupMessage]}
  Map<String, List<GroupMessage>> groupMsgs;

  AppData({
    Map<String, List<String>>? checkins,
    Map<String, int>? cloudStreaks,
    Map<String, int>? cloudMaxStreaks,
    Map<String, int>? cloudTotals,
    List<Certificate>? certificates,
    List<Post>? posts,
    this.captain,
    List<Report>? reports,
    List<String>? blockedUsers,
    Map<String, List<GroupMessage>>? groupMsgs,
  })  : checkins = checkins ?? {},
        certificates = certificates ?? [],
        posts = posts ?? [],
        reports = reports ?? [],
        blockedUsers = blockedUsers ?? [],
        groupMsgs = groupMsgs ?? {};

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      checkins: (json['checkins'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<String>.from(v as List)),
          ) ??
          {},
      cloudStreaks: (json['cloudStreaks'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
          ),
      cloudMaxStreaks: (json['cloudMaxStreaks'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
          ),
      cloudTotals: (json['cloudTotals'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
          ),
      certificates: (json['certificates'] as List?)
              ?.map((e) => Certificate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      posts: (json['posts'] as List?)
              ?.map((e) => Post.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      captain: json['captain'] != null
          ? Captain.fromJson(json['captain'] as Map<String, dynamic>)
          : null,
      reports: (json['reports'] as List?)
              ?.map((e) => Report.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      blockedUsers: List<String>.from(json['blockedUsers'] as List? ?? []),
      groupMsgs: (json['groupMsgs'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
                k, (v as List).map((m) => GroupMessage.fromJson(m as Map<String, dynamic>)).toList()),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'checkins': checkins,
        'cloudStreaks': cloudStreaks,
        'cloudMaxStreaks': cloudMaxStreaks,
        'cloudTotals': cloudTotals,
        'certificates': certificates.map((e) => e.toJson()).toList(),
        'posts': posts.map((e) => e.toJson()).toList(),
        'captain': captain?.toJson(),
        'reports': reports.map((e) => e.toJson()).toList(),
        'blockedUsers': blockedUsers,
        'groupMsgs': groupMsgs.map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList())),
      };
}

/// 征服证书
class Certificate {
  final String island;
  final String date;

  Certificate({required this.island, required this.date});

  factory Certificate.fromJson(Map<String, dynamic> json) =>
      Certificate(island: json['island'] as String, date: json['date'] as String);

  Map<String, dynamic> toJson() => {'island': island, 'date': date};
}

/// 航海日志帖子
class Post {
  final String id;
  final String author;
  final String? avatar;      // 单字头像（"黑"/"雾"/...）
  final String? avatarUrl;   // 图片头像（base64，可选）
  final String? island;      // 关联岛屿 id
  final String text;
  final List<String> images;
  final List<String> tags;
  final String time;         // "12 分钟前"
  final String? emoji;       // 无图时的占位 emoji
  final int bgFrom;          // 渐变起始色
  final int bgTo;            // 渐变结束色
  int likes;
  bool liked;

  bool get isMine => id.startsWith('u');

  Post({
    required this.id,
    required this.author,
    this.avatar,
    this.avatarUrl,
    this.island,
    required this.text,
    List<String>? images,
    List<String>? tags,
    required this.time,
    this.emoji,
    this.bgFrom = 0xFF123A6B,
    this.bgTo = 0xFF0A1F3D,
    this.likes = 0,
    this.liked = false,
  })  : images = images ?? [],
        tags = tags ?? [];

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        author: json['author'] as String,
        avatar: json['avatar'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        island: json['island'] as String?,
        text: json['text'] as String,
        images: List<String>.from(json['images'] as List? ?? []),
        tags: List<String>.from(json['tags'] as List? ?? []),
        time: json['time'] as String,
        emoji: json['emoji'] as String?,
        bgFrom: json['bgFrom'] as int? ?? 0xFF123A6B,
        bgTo: json['bgTo'] as int? ?? 0xFF0A1F3D,
        likes: json['likes'] as int? ?? 0,
        liked: json['liked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'avatar': avatar,
        'avatarUrl': avatarUrl,
        'island': island,
        'text': text,
        'images': images,
        'tags': tags,
        'time': time,
        'emoji': emoji,
        'bgFrom': bgFrom,
        'bgTo': bgTo,
        'likes': likes,
        'liked': liked,
      };
}

/// 船长（用户）
class Captain {
  String name;
  String? avatar;
  String loginBy; // phone / email / password / local
  int at;         // 登录时间戳

  Captain({
    required this.name,
    this.avatar,
    required this.loginBy,
    required this.at,
  });

  factory Captain.fromJson(Map<String, dynamic> json) => Captain(
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
        loginBy: json['loginBy'] as String,
        at: json['at'] as int,
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'avatar': avatar, 'loginBy': loginBy, 'at': at};
}

/// 举报记录
class Report {
  final String postId;
  final String reason;
  final int at;

  Report({required this.postId, required this.reason, required this.at});

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        postId: json['postId'] as String,
        reason: json['reason'] as String,
        at: json['at'] as int,
      );

  Map<String, dynamic> toJson() =>
      {'postId': postId, 'reason': reason, 'at': at};
}

/// 群组定义（静态配置，对应 H5 GROUPS 数组）
class Group {
  final String id;
  final String cat;     // 'island' / 'club'
  final String name;
  final String avatar;  // emoji
  final String desc;
  final int count;      // 成员数
  final int badge;      // 未读红点
  final String last;    // 最后一条消息
  final String time;    // 时间

  const Group({
    required this.id,
    required this.cat,
    required this.name,
    required this.avatar,
    required this.desc,
    required this.count,
    required this.badge,
    required this.last,
    required this.time,
  });
}

/// 群聊消息
class GroupMessage {
  final bool sys;    // 系统消息
  final bool mine;   // 我发的
  final String? name;
  final String? avatar;
  final String text;

  GroupMessage({this.sys = false, this.mine = false, this.name, this.avatar, required this.text});

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
        sys: json['sys'] as bool? ?? false,
        mine: json['mine'] as bool? ?? false,
        name: json['name'] as String?,
        avatar: json['avatar'] as String?,
        text: json['text'] as String,
      );

  Map<String, dynamic> toJson() => {
        'sys': sys,
        'mine': mine,
        'name': name,
        'avatar': avatar,
        'text': text,
      };
}

/// 岛屿定义（静态配置，对应 H5 的 ISLANDS 数组）
class Island {
  final String id;
  final String name;
  final String en;       // 英文短名（MIND/BREATH/IRON/MOON）
  final String slogan;   // 标语
  final String action;   // 打卡动作描述（今日已修行/今日未吸烟...）
  final String emoji;
  final int color;       // 主色 0xFF...
  final int bgFrom;      // 渐变起始色
  final int bgTo;        // 渐变结束色

  const Island({
    required this.id,
    required this.name,
    required this.en,
    required this.slogan,
    required this.action,
    required this.emoji,
    required this.color,
    required this.bgFrom,
    required this.bgTo,
  });

  static const int target = 21; // 征服目标天数

  static const List<Island> all = [
    Island(
      id: 'qingxin',
      name: '清心岛',
      en: 'MIND',
      slogan: '一念清净，海阔天空',
      action: '今日已修行',
      emoji: '🧘',
      color: 0xFF7A6BE0,
      bgFrom: 0xFF3D3599,
      bgTo: 0xFF1A1550,
    ),
    Island(
      id: 'jieyan',
      name: '戒烟岛',
      en: 'BREATH',
      slogan: '今天少一根，明天多一天',
      action: '今日未吸烟',
      emoji: '🚭',
      color: 0xFF2ECC9E,
      bgFrom: 0xFF0F6E56,
      bgTo: 0xFF053B2D,
    ),
    Island(
      id: 'jianshen',
      name: '健身岛',
      en: 'IRON',
      slogan: '每一滴汗都是勋章',
      action: '今日已训练',
      emoji: '💪',
      color: 0xFF4DA6FF,
      bgFrom: 0xFF185FA5,
      bgTo: 0xFF0A2F5C,
    ),
    Island(
      id: 'zaoshui',
      name: '早睡岛',
      en: 'MOON',
      slogan: '23:00 前入睡，给身体一个交代',
      action: '今日已早睡',
      emoji: '🌙',
      color: 0xFFE8B84A,
      bgFrom: 0xFF854F0B,
      bgTo: 0xFF3B2205,
    ),
  ];

  static Island? byId(String id) {
    for (final i in all) {
      if (i.id == id) return i;
    }
    return null;
  }
}

/// ── 岛屿页 Banner 卡片数据（后端 /api/banners 动态下发，AGENTS.md §13）──
/// 本地短时缓存（10 分钟 TTL），后台增删/排序/改 action 后 App 刷新即生效
class BannerItem {
  final int id;
  final String title;
  final String subtitle;
  final String buttonText;
  final String icon;
  final String theme;       // gold / ocean
  final String action;      // reward / internal_page / none
  final String actionValue; // internal_page 路由（预留）

  const BannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.icon,
    required this.theme,
    required this.action,
    required this.actionValue,
  });

  factory BannerItem.fromJson(Map<String, dynamic> j) => BannerItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        subtitle: (j['subtitle'] as String?) ?? '',
        buttonText: (j['buttonText'] as String?) ?? '',
        icon: (j['icon'] as String?) ?? '',
        theme: (j['theme'] as String?) ?? 'gold',
        action: (j['action'] as String?) ?? 'none',
        actionValue: (j['actionValue'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'subtitle': subtitle, 'buttonText': buttonText,
        'icon': icon, 'theme': theme, 'action': action, 'actionValue': actionValue,
      };

  /// 网络与缓存全空时的内置兜底卡片（保证岛屿页顶部不空白）
  static List<BannerItem> get fallback => [
        BannerItem(
            id: -1, title: '开服公告',
            subtitle: '一人公司独立开发 · 支持开发者帮助项目持续运营',
            buttonText: '支持开发者', icon: '📢', theme: 'gold', action: 'reward', actionValue: ''),
        BannerItem(
            id: -2, title: '今日出海',
            subtitle: '乘风破浪 · 一日一航',
            buttonText: '', icon: '⛵', theme: 'ocean', action: 'none', actionValue: ''),
      ];
}

/// 支付预下单结果（POST /api/pay/reward / /api/pay/order）
class PayOrderResult {
  final String outTradeNo;
  final String amount;
  final String orderString; // 原样交给支付宝唤起，任何字符不可改（§13 契约）

  const PayOrderResult({
    required this.outTradeNo,
    required this.amount,
    required this.orderString,
  });

  factory PayOrderResult.fromJson(Map<String, dynamic> j) => PayOrderResult(
        outTradeNo: (j['outTradeNo'] as String?) ?? '',
        amount: (j['amount'] as String?) ?? '',
        orderString: (j['orderString'] as String?) ?? '',
      );
}
