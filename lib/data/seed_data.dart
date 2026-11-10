import 'models.dart';

export 'models.dart';

/// 种子数据 + 敏感词表 — 对应 H5 的 SEED_POSTS / BANNED_WORDS / GROUPS / SEED_GROUP_MSGS

// ── 种子帖子（对应 H5 SEED_POSTS）──
final List<Post> seedPosts = [
  Post(id: 'p1', author: '黑帆船长', avatar: '黑', island: 'jianshen', text: '第 47 天，深蹲 5×10。海风很咸，肌肉很鼓。', tags: ['健身岛', '日更'], likes: 128, time: '12 分钟前', emoji: '💪', bgFrom: 0xFF0B2A5C, bgTo: 0xFF08A2C9),
  Post(id: 'p2', author: '雾岛航海士', avatar: '雾', island: 'zaoshui', text: '22:47 熄灯，明早的太阳等我。', tags: ['早睡岛'], likes: 56, time: '34 分钟前', emoji: '🌙', bgFrom: 0xFF3B2205, bgTo: 0xFFE8B84A),
  Post(id: 'p3', author: '铁锚 · 一等水手', avatar: '铁', island: 'qingxin', text: '今天忍住没点开那些页面。打坐 15 分钟，很稳。', tags: ['清心岛', '21天挑战'], likes: 212, time: '1 小时前', emoji: '🧘', bgFrom: 0xFF1A1550, bgTo: 0xFF7A6BE0),
  Post(id: 'p4', author: '南十字', avatar: '南', island: 'jieyan', text: '戒烟第 14 天。抽屉里那包烟已经拆封两周没动。', tags: ['戒烟岛'], likes: 341, time: '2 小时前', emoji: '🚭', bgFrom: 0xFF053B2D, bgTo: 0xFF2ECC9E),
  Post(id: 'p5', author: '磐石', avatar: '磐', island: 'jianshen', text: '雨天不出门，pull-up 8×5。装备升级：加重腰带。', tags: ['健身岛', '装备党'], likes: 77, time: '3 小时前', emoji: '⚓', bgFrom: 0xFF123A6B, bgTo: 0xFF4DA6FF),
  Post(id: 'p6', author: '远洋日志', avatar: '远', island: 'zaoshui', text: '手机丢客厅，卧室只留纸质书。这一招真好用。', tags: ['早睡岛', '妙招'], likes: 98, time: '5 小时前', emoji: '📖', bgFrom: 0xFF2A1A05, bgTo: 0xFFB7702B),
  Post(id: 'p7', author: '新兵蛋子', avatar: '新', island: 'qingxin', text: '刚登岛第 3 天，求带。真的很难。', tags: ['清心岛', '新船员'], likes: 33, time: '昨天', emoji: '🧭', bgFrom: 0xFF0D3163, bgTo: 0xFF7DC4FF),
];

// ── 群组定义（对应 H5 GROUPS）──
const List<Group> groups = [
  Group(id: 'g-qingxin', cat: 'island', name: '清心岛 · 静水深流', avatar: '🧘', desc: '冥想 · 静心 · 同行', count: 1284, badge: 5, last: '铁锚：分享一段冥想音频', time: '2 分钟前'),
  Group(id: 'g-jieyan', cat: 'island', name: '戒烟岛 · 无烟港', avatar: '🚭', desc: '戒烟 · 互助 · 坚持', count: 892, badge: 0, last: '南十字获得【坚持14天】徽章', time: '34 分钟前'),
  Group(id: 'g-jianshen', cat: 'island', name: '健身岛 · 铁血船队', avatar: '💪', desc: '增肌 · 减脂 · 装备', count: 2103, badge: 12, last: '磐石：今天谁陪我练背？', time: '刚刚'),
  Group(id: 'g-zaoshui', cat: 'island', name: '早睡岛 · 熄灯号', avatar: '🌙', desc: '早睡 · 规律 · 妙招', count: 1567, badge: 0, last: '雾岛航海士：22:47 熄灯成功', time: '1 小时前'),
  Group(id: 'g-emotion', cat: 'club', name: '情感觉醒交流群', avatar: '💭', desc: '情感 · 觉察 · 成长', count: 3456, badge: 0, last: '向日葵：分享今天的觉察', time: '5 分钟前'),
  Group(id: 'g-ai', cat: 'club', name: 'AI 学习交流群', avatar: '🤖', desc: 'AI · 工具 · 副业', count: 5210, badge: 0, last: '码农老张：推荐一个好用的工具', time: '8 分钟前'),
];

// ── 群聊种子消息（对应 H5 SEED_GROUP_MSGS）──
final Map<String, List<GroupMessage>> seedGroupMsgs = {
  'g-qingxin': [
    GroupMessage(sys: true, text: '铁锚 邀请你加入清心岛 · 静水深流'),
    GroupMessage(name: '铁锚', avatar: '铁', text: '分享一段冥想音频，今晚 22:00 一起静心 🧘'),
    GroupMessage(name: '磐石', avatar: '磐', text: '第 7 天打卡，感觉心越来越静了'),
    GroupMessage(name: '雾岛', avatar: '雾', text: '新人报到，求带！'),
  ],
  'g-jieyan': [
    GroupMessage(sys: true, text: '南十字 邀请你加入戒烟岛 · 无烟港'),
    GroupMessage(name: '南十字', avatar: '南', text: '戒烟第 14 天，抽屉那包烟两周没动了 🚭'),
    GroupMessage(name: '旧日水兵', avatar: '旧', text: '今天又忍住了一根，加油兄弟们'),
  ],
  'g-jianshen': [
    GroupMessage(sys: true, text: '磐石 邀请你加入健身岛 · 铁血船队'),
    GroupMessage(name: '磐石', avatar: '磐', text: '今天谁陪我练背？pull-up 8×5 💪'),
    GroupMessage(name: '黑帆船长', avatar: '黑', text: '深蹲 5×10 完成，海风很咸肌肉很鼓'),
  ],
  'g-zaoshui': [
    GroupMessage(sys: true, text: '雾岛航海士 邀请你加入早睡岛 · 熄灯号'),
    GroupMessage(name: '雾岛航海士', avatar: '雾', text: '22:47 熄灯，明早的太阳等我 🌙'),
    GroupMessage(name: '远洋日志', avatar: '远', text: '手机丢客厅，卧室只留纸质书，这招真好用'),
  ],
  'g-emotion': [
    GroupMessage(sys: true, text: '向日葵 邀请你加入情感觉醒交流群'),
    GroupMessage(name: '向日葵', avatar: '向', text: '分享今天的觉察：情绪来了先停 3 秒'),
    GroupMessage(name: '深海', avatar: '深', text: '最近在练非暴力沟通，很有启发'),
  ],
  'g-ai': [
    GroupMessage(sys: true, text: '码农老张 邀请你加入 AI 学习交流群'),
    GroupMessage(name: '码农老张', avatar: '码', text: '推荐一个好用的 AI 工具，效率翻倍 🤖'),
    GroupMessage(name: '极客', avatar: '极', text: '最近在学 prompt engineering，一起交流'),
  ],
};

// ── 敏感词表（对应 H5 BANNED_WORDS，App Store 1.2 UGC 内容过滤要求）──
const List<String> bannedWords = [
  '色情', '黄片', '约炮', '援交', '卖淫', '嫖娼', '成人视频', '裸体', '裸照', '一夜情',
  'av女优', '色情网站', '杀人', '放火', '抢劫', '强奸', '暴力恐怖', '恐怖袭击',
  '炸弹制作', '枪支制造', '自杀方法', '赌博', '时时彩', '百家乐', '赌球', '赌场',
  '博彩平台', '毒品', '大麻', '冰毒', '摇头丸', '海洛因', '可卡因', '吸毒', '贩毒',
  '反动', '推翻政府', '分裂国家', '港独', '台独', '疆独', '藏独', '辱华', '支那',
  '东亚病夫', '纳粹', '希特勒', '种族灭绝', '傻逼', '草泥马', '尼玛', 'fuck', 'shit',
  '混蛋', '滚蛋', '绿茶婊', '圣母婊', '小三', '婊子', '贱货', '骚货',
  '加我微信', 'vx:', 'qq:', '赚钱兼职', '刷单', '代购', '招嫖', '找小姐', '同城约',
];

/// 敏感词过滤（对应 H5 filterText）
/// 返回命中的敏感词，null 表示通过
String? filterText(String text) {
  final lower = text.toLowerCase();
  for (final w in bannedWords) {
    if (lower.contains(w.toLowerCase())) return w;
  }
  return null;
}

// ── 发帖时随机选 emoji/渐变（对应 H5 submitPost 的 emojiPool/bgPool）──
const List<String> postEmojiPool = ['⚓', '🌊', '🧭', '🏴‍☠️', '⛵', '💪', '🌙', '🧘', '🚭'];
const List<List<int>> postBgPool = [
  [0xFF123A6B, 0xFF4DA6FF],
  [0xFF0F6E56, 0xFF2ECC9E],
  [0xFF3B2205, 0xFFE8B84A],
  [0xFF1A1550, 0xFF7A6BE0],
];

// ── 保留用户名黑名单（对应 H5 RESERVED_NAMES）──
const List<String> reservedNames = [
  'admin', 'root', 'system', 'test', 'user', 'administrator', 'superuser',
  'operator', 'null', 'undefined', 'guest', 'anonymous', 'official',
  'dalanhai', 'grandblue', '船长', '管理员', '系统',
];
