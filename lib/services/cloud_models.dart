/// v2.7 P0 云端港口流 DTO（对接 /api/post/* 全套接口）
///
/// 后端约定（详见 ../grandblue-server/部署文档.md §18）：
///   - postId 为自增整数（非 UUID）
///   - 附件只返回 OSS 对象 key（coverKey/coverKeys/avatar），
///     渲染统一走 POST /api/media/sign 换 900s 时效 URL（防爬红线）
///   - 审核不通过/被拉黑作者的资源对外一律 404（不区分原因）
library;

/// 岛屿筛选 key（后端枚举）↔ 本地 Island.id（拼音）映射
const Map<String, String> kCloudIslandKeys = <String, String>{
  'qingxin': 'clear-mind', // 清心岛
  'jieyan': 'quit-smoke', // 戒烟岛
  'jianshen': 'fitness', // 健身岛
  'zaoshui': 'early-sleep', // 早睡岛
};

/// 后端 island key → 本地 Island.id（详情页显示岛名用）
String? cloudIslandToLocal(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final e in kCloudIslandKeys.entries) {
    if (e.value == key) return e.key;
  }
  return null;
}

/// 作者信息（瀑布流/详情/评论通用）
class CloudAuthor {
  const CloudAuthor({required this.uid, required this.nickname, this.avatar});

  factory CloudAuthor.fromJson(Map<String, dynamic> j) => CloudAuthor(
        uid: (j['uid'] as num).toInt(),
        nickname: (j['nickname'] as String?) ?? '',
        avatar: j['avatar'] as String?,
      );

  final int uid;
  final String nickname;

  /// 头像 OSS 对象 key（null=未设置；渲染走 media/sign keys）
  final String? avatar;

  /// 展示名：昵称优先，未设置回退「船长+编号」（后端只回 id，前缀由前端拼接）
  String get displayName => nickname.isNotEmpty ? nickname : '船长$uid';
}

/// 帖子条目（瀑布流列表项与帖子详情同构，后端 postToFeedJSON）
class CloudPost {
  const CloudPost({
    required this.postId,
    required this.type,
    required this.content,
    required this.author,
    required this.coverKeys,
    required this.tags,
    required this.likeCount,
    required this.liked,
    required this.commentCount,
    required this.createdAt,
    this.coverKey,
    this.island,
  });

  factory CloudPost.fromJson(Map<String, dynamic> j) => CloudPost(
        postId: (j['postId'] as num).toInt(),
        type: (j['type'] as String?) ?? 'text',
        content: (j['content'] as String?) ?? '',
        author: CloudAuthor.fromJson((j['author'] as Map<String, dynamic>?) ?? const {}),
        coverKey: j['coverKey'] as String?,
        coverKeys: ((j['coverKeys'] as List<dynamic>?) ?? const []).cast<String>(),
        island: j['island'] as String?,
        tags: ((j['tags'] as List<dynamic>?) ?? const []).cast<String>(),
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        liked: (j['liked'] as bool?) ?? false,
        commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as String?) ?? '',
      );

  final int postId;
  final String type; // text | image | video

  /// 首图 key（=coverKeys.first，向后兼容单图字段）
  final String? coverKey;
  final List<String> coverKeys;
  final String content;
  final CloudAuthor author;
  final String? island; // fitness / quit-smoke / early-sleep / clear-mind
  final List<String> tags; // 无 # 前缀（展示时自行拼 #）
  final int likeCount;
  final bool liked;
  final int commentCount;
  final String createdAt;
}

/// 分页通用结构
class PagedPosts {
  const PagedPosts({required this.total, required this.page, required this.list});

  factory PagedPosts.fromJson(Map<String, dynamic> j) => PagedPosts(
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        list: ((j['list'] as List<dynamic>?) ?? const [])
            .map((e) => CloudPost.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int total;
  final int page;
  final List<CloudPost> list;

  bool get hasMore => list.isNotEmpty && list.length < total;
}

/// 评论/子评论（v2.9.7 评论系统 v2，一级与子评论同构）
class CloudComment {
  const CloudComment({
    required this.commentId,
    required this.author,
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.liked = false,
    this.replyCount = 0,
    this.rootCommentId,
    this.replyToCommentId,
    this.replyToNickname,
    this.replyToUid,
    this.isPostAuthor = false,
    this.atUserIds = const [],
  });

  factory CloudComment.fromJson(Map<String, dynamic> j) => CloudComment(
        commentId: (j['commentId'] as num).toInt(),
        author: CloudAuthor.fromJson((j['author'] as Map<String, dynamic>?) ?? const {}),
        content: (j['content'] as String?) ?? '',
        createdAt: (j['createdAt'] as String?) ?? '',
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        liked: (j['liked'] as bool?) ?? false,
        replyCount: (j['replyCount'] as num?)?.toInt() ?? 0,
        rootCommentId: (j['rootCommentId'] as num?)?.toInt(),
        replyToCommentId: (j['replyToCommentId'] as num?)?.toInt(),
        replyToNickname: j['replyToNickname'] as String?,
        replyToUid: (j['replyToUid'] as num?)?.toInt(),
        isPostAuthor: (j['isPostAuthor'] as bool?) ?? false,
        atUserIds: ((j['atUserIds'] as List<dynamic>?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );

  final int commentId;
  final CloudAuthor author;
  final String content;
  final String createdAt;

  /// 点赞数 / 我是否已点赞（评论与子评论通用）
  final int likeCount;
  final bool liked;

  /// 一级评论：直属子评论总数；子评论恒 0
  final int replyCount;

  /// 子评论：所属一级评论 id；一级评论为 null
  final int? rootCommentId;

  /// 子评论：被回复的评论 id（回复一级评论时 = 一级评论 id）
  final int? replyToCommentId;

  /// 场景B（回复的是另一条子评论）▶ 后 @昵称；场景A 为 null
  final String? replyToNickname;

  /// 场景B：被回复人 uid（头部关系标签跳主页用）
  final int? replyToUid;

  /// 评论人是否为帖子作者（渲染【作者】轻标识）
  final bool isPostAuthor;

  /// @用户 id 列表（通知模块预埋，本期不触发通知）
  final List<int> atUserIds;

  /// 是否子评论
  bool get isReply => rootCommentId != null;

  /// 复制并覆盖部分字段（本地乐观更新用）
  CloudComment copyWith({int? likeCount, bool? liked, int? replyCount}) =>
      CloudComment(
        commentId: commentId,
        author: author,
        content: content,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        liked: liked ?? this.liked,
        replyCount: replyCount ?? this.replyCount,
        rootCommentId: rootCommentId,
        replyToCommentId: replyToCommentId,
        replyToNickname: replyToNickname,
        replyToUid: replyToUid,
        isPostAuthor: isPostAuthor,
        atUserIds: atUserIds,
      );
}

/// @用户搜索结果（GET /api/users/search）
class CloudUserSearchItem {
  const CloudUserSearchItem({required this.userId, required this.nickname, this.avatar});

  factory CloudUserSearchItem.fromJson(Map<String, dynamic> j) => CloudUserSearchItem(
        userId: (j['userId'] as num).toInt(),
        nickname: (j['nickname'] as String?) ?? '',
        avatar: j['avatar'] as String?,
      );

  final int userId;
  final String nickname;
  final String? avatar;

  String get displayName => nickname.isNotEmpty ? nickname : '船长$userId';
}

class PagedComments {
  const PagedComments({required this.total, required this.page, required this.list});

  factory PagedComments.fromJson(Map<String, dynamic> j) => PagedComments(
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        list: ((j['list'] as List<dynamic>?) ?? const [])
            .map((e) => CloudComment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int total;
  final int page;
  final List<CloudComment> list;

  bool get hasMore => list.isNotEmpty && list.length < total;
}

/// 点赞切换返回（POST /api/post/:postId/like）
class LikeResult {
  const LikeResult({required this.likeCount, required this.liked});

  factory LikeResult.fromJson(Map<String, dynamic> j) => LikeResult(
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        liked: (j['liked'] as bool?) ?? false,
      );

  final int likeCount;
  final bool liked;
}

/// 热门标签条目（GET /api/tag/list）
class TagStat {
  const TagStat({required this.tag, required this.count});

  factory TagStat.fromJson(Map<String, dynamic> j) => TagStat(
        tag: (j['tag'] as String?) ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );

  final String tag;
  final int count;
}

/// 举报提交返回（POST /api/report）
class ReportResult {
  const ReportResult({required this.reportId, this.duplicated = false});

  factory ReportResult.fromJson(Map<String, dynamic> j) => ReportResult(
        reportId: (j['reportId'] as num?)?.toInt() ?? 0,
        duplicated: (j['duplicated'] as bool?) ?? false,
      );

  final int reportId;

  /// true = 24h 内已对同一目标举报过（后端去重，未新建记录）
  final bool duplicated;
}

/// 登录用户档案（登录/注册/me 接口的 user 对象）
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.nickname,
    this.avatar,
    this.isFounder = false,
    this.isVideoWhitelist = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] as num).toInt(),
        username: (j['username'] as String?) ?? '',
        nickname: j['nickname'] as String?,
        avatar: j['avatar'] as String?,
        isFounder: (j['isFounder'] as bool?) ?? false,
        isVideoWhitelist: (j['isVideoWhitelist'] as bool?) ?? false,
      );

  final int id;
  final String username; // 登录账号（手机号/邮箱）

  /// 昵称（未设置时 null，客户端可回退脱敏账号或引导设置）
  final String? nickname;
  final String? avatar; // 头像 OSS key（渲染走 media/sign keys）
  final bool isFounder;
  final bool isVideoWhitelist;

  /// 展示名（固化规则，前缀仅此一处）：昵称去首尾空格后非空 → 原始昵称；
  /// null / 全空白 → 「船长+id」。后端绝不拼接前缀。
  String get displayName {
    final n = nickname;
    if (n != null && n.trim().isNotEmpty) return n;
    return '船长$id';
  }
}

/// 登录/注册成功返回（POST /api/login/sms 等鉴权接口）
class LoginResult {
  const LoginResult({required this.token, required this.refreshToken, required this.user});

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
        token: (j['token'] as String?) ?? '',
        refreshToken: (j['refreshToken'] as String?) ?? '',
        user: AuthUser.fromJson((j['user'] as Map<String, dynamic>?) ?? const {}),
      );

  /// AccessToken（7 天，接口鉴权）
  final String token;

  /// RefreshToken（30 天滑动续期）
  final String refreshToken;
  final AuthUser user;
}

// ════════════════════════════════════════════════════════════
// 第一轮前后端联调（Flash 后端，统一 code=200 成功）
// 文档：游客浏览岛屿 → 打卡触发登录弹窗 → 短信登录 → 云端打卡 → 船长页 → 登出
// ════════════════════════════════════════════════════════════

/// 打卡接口的 islandId 映射（全部岛屿统一云端打卡）
/// 后端白名单：sleep / fitness / quit-smoke / clear-mind（早睡岛固定 sleep）
const Map<String, String> kCloudCheckinIslandKeys = <String, String>{
  'zaoshui': 'sleep', // 早睡岛
  'jianshen': 'fitness', // 健身岛
  'jieyan': 'quit-smoke', // 戒烟岛
  'qingxin': 'clear-mind', // 清心岛
};

/// 云端船长档案（POST /api/login/sms / GET /api/user/me 的 captain 对象）
class CloudCaptain {
  const CloudCaptain({
    required this.id,
    required this.phone,
    this.nickname = '',
    this.avatar = '',
    this.createdAt = '',
    this.bio,
    this.sailLevel,
  });

  factory CloudCaptain.fromJson(Map<String, dynamic> j) => CloudCaptain(
        id: (j['id'] as num?)?.toInt() ?? 0,
        phone: (j['phone'] as String?) ?? '',
        nickname: (j['nickname'] as String?) ?? '',
        avatar: (j['avatar'] as String?) ?? '',
        createdAt: (j['createdAt'] as String?) ?? '',
        bio: j['bio'] as String?,
        sailLevel: j['sailLevel'] as String?,
      );

  final int id;
  final String phone;
  final String nickname;
  final String avatar;
  final String createdAt;

  /// v2.9.6：个人简介 + 航级文本（buildProfile 已下发）
  final String? bio;
  final String? sailLevel;

  /// 展示名（固化规则）：昵称 trim 后非空 → 原始昵称；null/全空白 → 「船长+编号」
  String get displayName => nickname.trim().isNotEmpty ? nickname : '船长$id';
}

/// 岛屿打卡数据（GET /api/user/island/:islandId 出参）
class IslandCheckinData {
  const IslandCheckinData({
    required this.islandId,
    required this.continueDays,
    required this.remainDays,
    required this.isConquer,
    required this.checkinDateList,
    required this.todayChecked,
    this.today,
    this.maxStreakDays,
    this.totalDays,
  });

  factory IslandCheckinData.fromJson(Map<String, dynamic> j) => IslandCheckinData(
        islandId: (j['islandId'] as String?) ?? '',
        continueDays: (j['continueDays'] as num?)?.toInt() ?? 0,
        remainDays: (j['remainDays'] as num?)?.toInt() ?? 21,
        isConquer: (j['isConquer'] as bool?) ?? false,
        checkinDateList:
            ((j['checkinDateList'] as List<dynamic>?) ?? const []).cast<String>(),
        todayChecked: (j['todayChecked'] as bool?) ?? false,
        // v2.9.3：服务端"今天"（Asia/Shanghai）—— 日历窗口/选中格唯一时间来源
        today: j['today'] as String?,
        // v2.9.3：历史最长连续（后端计算下发，前端不再自算）
        maxStreakDays: (j['maxStreakDays'] as num?)?.toInt(),
        // v2.9.6 修复统计断层：全历史去重打卡总天数（后端 total，非 21 天窗口）
        totalDays: (j['total'] as num?)?.toInt(),
      );

  final String islandId;

  /// 连续打卡天数（后端计算，前端只展示）
  final int continueDays;

  /// 距离 21 天征服还差几天
  final int remainDays;
  final bool isConquer;

  /// 最近 21 天打卡日期 yyyy-MM-dd（渲染日历）
  final List<String> checkinDateList;

  /// 今日是否已打卡（控制按钮置灰）
  final bool todayChecked;

  /// 服务端"今天"（Asia/Shanghai，YYYY-MM-DD）—— 日历窗口/选中格唯一时间来源
  final String? today;

  /// 历史最长连续（后端计算下发）
  final int? maxStreakDays;

  /// v2.9.6：全历史去重打卡总天数（后端 total；与船长页统计同口径）
  final int? totalDays;
}

/// 云端打卡提交返回（POST /api/user/island/:islandId/checkin）
class CloudCheckinResult {
  const CloudCheckinResult({
    required this.continueDays,
    required this.remainDays,
    required this.isConquer,
    required this.checkinDateList,
    this.today,
    this.maxStreakDays,
    this.totalDays,
  });

  factory CloudCheckinResult.fromJson(Map<String, dynamic> j) => CloudCheckinResult(
        continueDays: (j['continueDays'] as num?)?.toInt() ?? 0,
        remainDays: (j['remainDays'] as num?)?.toInt() ?? 0,
        isConquer: (j['isConquer'] as bool?) ?? false,
        // v2.9.3：打卡成功后以后端返回为准（完整 21 天列表 + 服务端今天）
        checkinDateList:
            ((j['checkinDateList'] as List<dynamic>?) ?? const []).cast<String>(),
        today: j['today'] as String?,
        // v2.9.3：历史最长连续（后端计算下发）
        maxStreakDays: (j['maxStreakDays'] as num?)?.toInt(),
        // v2.9.6 修复统计断层：全历史去重打卡总天数（后端 total，非 21 天窗口）
        totalDays: (j['total'] as num?)?.toInt(),
      );

  final int continueDays;
  final int remainDays;
  final bool isConquer;
  final List<String> checkinDateList;
  final String? today; // 服务端"今天"（Asia/Shanghai）

  /// 历史最长连续（后端计算下发）
  final int? maxStreakDays;

  /// v2.9.6：全历史去重打卡总天数（后端 total；与船长页统计同口径）
  final int? totalDays;
}

// ════════════════════════════════════════════════════════════
// v2.9.6 社交关系与个人主页 DTO（关注/粉丝/黑名单/航级占位）
// ════════════════════════════════════════════════════════════

/// 他人主页/自身公开预览（GET /api/user/:uid/profile 出参）
class CloudUserProfile {
  const CloudUserProfile({
    required this.uid,
    this.nickname,
    this.avatar,
    this.bio,
    this.sailLevel,
    this.showSailLevelTag = false,
    this.isSelf = false,
    this.following = false,
    required this.stats,
    this.certificates = const [],
  });

  factory CloudUserProfile.fromJson(Map<String, dynamic> j) => CloudUserProfile(
        uid: (j['uid'] as num).toInt(),
        nickname: j['nickname'] as String?,
        avatar: j['avatar'] as String?,
        bio: j['bio'] as String?,
        sailLevel: j['sailLevel'] as String?,
        showSailLevelTag: (j['showSailLevelTag'] as bool?) ?? false,
        isSelf: (j['isSelf'] as bool?) ?? false,
        following: (j['following'] as bool?) ?? false,
        stats: CloudProfileStats.fromJson(
            (j['stats'] as Map<String, dynamic>?) ?? const {}),
        certificates: ((j['certificates'] as List<dynamic>?) ?? const [])
            .map((e) => CloudCertificate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int uid;
  final String? nickname;
  final String? avatar; // OSS key（渲染走 media/sign）
  final String? bio;
  final String? sailLevel;

  /// 后台开关 && sail_level 非空 —— false 时前端完全不渲染标签（无空白占位）
  final bool showSailLevelTag;
  final bool isSelf;
  final bool following;
  final CloudProfileStats stats;
  final List<CloudCertificate> certificates;

  /// 展示名（与 CloudAuthor 同口径）：昵称优先 → 船长{id}
  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname! : '船长$uid';
}

/// 主页统计栏（两行五项）
class CloudProfileStats {
  const CloudProfileStats({
    this.posts = 0,
    this.following = 0,
    this.followers = 0,
    this.totalCheckins = 0,
    this.maxStreak = 0,
  });

  factory CloudProfileStats.fromJson(Map<String, dynamic> j) => CloudProfileStats(
        posts: (j['posts'] as num?)?.toInt() ?? 0,
        following: (j['following'] as num?)?.toInt() ?? 0,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        totalCheckins: (j['totalCheckins'] as num?)?.toInt() ?? 0,
        maxStreak: (j['maxStreak'] as num?)?.toInt() ?? 0,
      );

  final int posts; // 航海日志数
  final int following;
  final int followers;
  final int totalCheckins; // 累计打卡
  final int maxStreak; // 最长连续登岛
}

/// 征服证书（后端按打卡数据计算：单岛最长连续 ≥21 天）
/// island 为后端枚举（sleep/fitness/quit-smoke/clear-mind），渲染前转本地 id
class CloudCertificate {
  const CloudCertificate({required this.island, required this.date});

  factory CloudCertificate.fromJson(Map<String, dynamic> j) => CloudCertificate(
        island: (j['island'] as String?) ?? '',
        date: (j['date'] as String?) ?? '',
      );

  final String island;
  final String date;
}

/// 关注/粉丝/黑名单列表条目（分页）
class CloudUserEntry {
  const CloudUserEntry({
    required this.uid,
    this.nickname,
    this.avatar,
    this.isMyFollow = false,
    this.isFollowMe = false,
  });

  factory CloudUserEntry.fromJson(Map<String, dynamic> j) => CloudUserEntry(
        uid: (j['uid'] as num).toInt(),
        nickname: j['nickname'] as String?,
        avatar: j['avatar'] as String?,
        // isMyFollow=我是否关注对方（兼容旧字段 followedByViewer）；isFollowMe=对方是否关注我
        isMyFollow: (j['isMyFollow'] as bool?) ??
            (j['followedByViewer'] as bool?) ??
            false,
        isFollowMe: (j['isFollowMe'] as bool?) ?? false,
      );

  final int uid;
  final String? nickname;
  final String? avatar;
  final bool isMyFollow; // 我关注了 TA
  final bool isFollowMe; // TA 关注了我

  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname! : '船长$uid';
}

/// 用户列表分页（粉丝/关注/黑名单通用）
class PagedUsers {
  const PagedUsers({required this.total, required this.page, required this.list});

  factory PagedUsers.fromJson(Map<String, dynamic> j) => PagedUsers(
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        list: ((j['list'] as List<dynamic>?) ?? const [])
            .map((e) => CloudUserEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int total;
  final int page;
  final List<CloudUserEntry> list;

  bool get hasMore => list.isNotEmpty && list.length < total;
}

/// 关注 toggle 返回（POST /api/user/follow）
class FollowResult {
  const FollowResult({required this.targetUid, required this.following});

  factory FollowResult.fromJson(Map<String, dynamic> j) => FollowResult(
        targetUid: (j['targetUid'] as num?)?.toInt() ?? 0,
        following: (j['following'] as bool?) ?? false,
      );

  final int targetUid;
  final bool following;
}

/// 关注状态查询（GET /api/user/follow-status）
class FollowStatus {
  const FollowStatus({
    required this.targetUid,
    this.following = false,
    this.followedBy = false,
  });

  factory FollowStatus.fromJson(Map<String, dynamic> j) => FollowStatus(
        targetUid: (j['targetUid'] as num?)?.toInt() ?? 0,
        following: (j['following'] as bool?) ?? false,
        followedBy: (j['followedBy'] as bool?) ?? false,
      );

  final int targetUid;
  final bool following; // 我关注了 TA
  final bool followedBy; // TA 关注了我
}

/// 后端证书岛屿枚举 → 本地 Island.id（cloudCertIslandToLocal）
/// 复用 kCloudCheckinIslandKeys 的映射方向：后端 sleep/fitness/quit-smoke/clear-mind
String? cloudCertIslandToLocal(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final e in kCloudCheckinIslandKeys.entries) {
    if (e.value == key) return e.key;
  }
  return null;
}
