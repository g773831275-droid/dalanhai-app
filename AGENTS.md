# AGENTS.md — dalanhai-app (Flutter 重写版「大蓝海」)

> **本文件供 AI 编码代理（codex / Claude Code / Copilot 等）及协作者快速接手项目。改动代码前请先读完。**
>
> 接手前必读：① 项目简介 ② 设计规范 ③ 当前进度 ④ 关键文件说明 ⑤ 已知陷阱

---

## 1. 项目简介

**大蓝海（GRAND BLUE）** Flutter 重写版，替代原有的 H5 + Capacitor 栈。iOS + Android 统一用 Flutter 出包。

| 项 | 值 |
|---|---|
| 定位 | 习惯记录工具（App Store 12+ 分级 / Google Play 全年龄） |
| 开发者 | kaiteng guan（苹果个人开发者 + Google Play 个人开发者，**Google Play 待注册**） |
| **著作权人** | **杭州浩海星辰数字科技有限公司**（软著以企业名义申请，所有材料署名必须统一，不得出现个人姓名） |
| Bundle ID | **双平台分离（2026-11-21）**：iOS = `com.kaitengguan.dalanhai`（线上存量，勿动）；Android applicationId = `com.haohaixingchen.dalanhai`（软著登记包名，安卓商店上架用）；Android namespace 仍为 `com.kaitengguan.dalanhai`（代码包路径，≠applicationId，不影响最终包名） |
| 商业模式 | 基础功能永久免费。变现：「支持开发者」自愿赞赏（Android = 支付宝 App 支付 tobias；iOS = Apple IAP 内购，§13.14~13.16）+ 客服微信引流；赞赏仅发纪念徽章，不解锁任何功能/权益/曝光（§13.12 合规定位）。⚠️ 旧定位「App 内零收费、无 IAP」自 2026-11-22 起作废 |
| 当前阶段 | P0~P5 代码完成 + UI 与 H5 1:1 对齐；**Flutter 版功能全量落地（岛屿/打卡/船长/UGC/集市 + 头像上传）**；**后端 v2.9.10 已上线生产**（2026-11-15：v2.9.7 评论系统 v2 → v2.9.8 置顶/批量删除 → **v2.9.9 密码找回全栈 + 消息中心（4 类互动通知聚合 + 私信）** → **v2.9.10 群聊第一版（g001-g006 固定群，list/info/msg/read + Green 线上审核 + 本地敏感词兜底）**，最新备份锚点 index.js.bak-20261115-220456 + src/db.js.bak 同时间戳）；**Flutter 端 v2.9.8 全量落地**（置顶金标/单人上限1条替换确认/批量删除二次确认/长按菜单/置顶接口不存在友好 toast；**关注/取关粉丝数乐观更新+对账**）；**Flutter 网络层域名统一锁定 `https://api.idalanhai.com`**（session_store 单点管理，设备旧缓存自动清除）；2026-11-10 修复船长页打卡统计联动断层（cloudTotals 全历史口径）；软著补正材料已就绪待提交（~11/20 截止）；Apple 个人→组织迁移进行中（案例 103004430882）；**2026-11-11 下午：@提及系统全量落地（正文高亮跳转 MentionText + 发帖页 @搜索弹窗 AtUserPicker 共用组件）+ 游客可见图片（media/sign 匿名化）+ 批量操作栏吸顶 + @搜索排除 founder 系统账号 + 未登录点 @ 直跳主页（users/search optionalAuth，查看类游客可读）**（后端三次热修已部署生产，备份 bak-20261111-125211/144604/151506）；✅ dalanhai-app/ 已 git init（2026-11-10，本地 master 领先远程，**待 user push**）；⚠️ grandblue-server/ 本地 git 仓已建（v2.9.8 基座 + 11-11 热修 29c0ddf/a942470 等，无远程）；**2026-11-16/17 冲刺（v2.9.11，全栈已上线生产）**：深蓝主题文字对比度优化（38 文件文字层级+卡片边框阴影）→ 色彩对齐 H5 原版质感（正文 #EAF2FF/辅助 #8FA6C4/hint #5A7099，聊天气泡改左浅米 #F1E4C6 右金色渐变）→ 发帖弹窗 4 图片槽尺寸 bug 修复 → 私信/群聊头像跳主页 + 他人主页【发消息】打通私信 → **账号注销功能全栈落地（§12 已实现：closed 匿名化 + 双层确认 UI + 生产真实注销 uid12 验收）** → 注销后同手机号重注册打卡统计残留 bug 修复（本地存档会话边界重置） | **2026-11-18 冲刺（v2.9.12 安全/性能 9 项修复 + 图片渲染域名切换，Pixel7 adb + 单元测试验收）**：高危修复 = cleartext 出主 manifest（仅 debug 包保留 `usesCleartextTraffic`，release 恒 HTTPS）+ `_ossDebug` 加 kReleaseMode 守卫（debugPrint 不被 release tree-shake，曾泄露 Authorization 前缀/OSS XML 进 release logcat）→ 性能修复 = CloudApi 共享 http.Client 连接池（host 变更才重建）+ 头像批量签名 prefetchKeys（≤10/批，消除 N+1）+ composer 图片 Uint8List 直存（去 base64 中转）+ DataStore 400ms 防抖写盘（catchError；clearAll 先取消定时器防旧数据回写）+ 私信/群聊轮询 WidgetsBindingObserver 生命周期感知（后台停/resume 立即拉一次）+ 签名缓存过期淘汰 + 视频流式直传（不再整文件 readAsBytes）+ compressImage 二次压缩复用首档输出 + signMedia postId int.tryParse 防御 → **图片渲染域名切换 img.idalanhai.com（media_sign_cache 单点 _mapRenderUrl：只换 scheme+host，防盗链签名 query 原样跟随；上传链路 put-sign 仍走 OSS 原始域名；服务端实测 200/防盗链 403 正常）**。未做（下版本）：token 迁 flutter_secure_storage、auth_service 死代码清理、SSL pinning | **2026-11-18 下午（服务端端口迁移 3000→8080 + 匿名图片放行回归）**：Node 服务 .env 迁 8080（HOST/PORT 两行，nginx 反代同步）、后端部署生效后 curl 回归 = media/sign 匿名 200（多图帖全签）而 user/me/点赞/发帖仍 401（放行仅签名通道，登录校验零回退）；Pixel7 实测匿名态与 uid23 登录态港口页图片/文字渲染完全一致（App UI 登录表单 adb 自动化走通） | **2026-11-18 晚（ESA 图片域名接入事件全记录）**：img.idalanhai.com 切 ESA 边缘 → 初期边缘证书下发不完整+回源 9-12s → 24 轮复测 24/24 占位 → App 端 kRenderHost 临时回退 OSS 原始域名止血 → **阿里云工单定性：ESA 已开启 OSS 私有 Bucket 自动回源鉴权，URL 携带 OSS 签名参数 = 双重鉴权冲突（随机 400/SSL 重置）** → 最终方案 = 渲染 URL 剥离全部签名 query（_mapRenderUrl 用 Uri 重建）+ kRenderHost='img.idalanhai.com'，双场景 12/12+7/7 图片恢复、直连 OSS 无签名 403 防盗链生效；**Green 图片审核 404 已修（2026-11-19 00:31 部署）：送审 imageUrl 改 ESA 无签名直链 + 下载重试 ≤2 次（单次 12s 超时），生产实战 uid23 发图帖第 3 次重试成功入库** | **2026-11-19 凌晨（多图上传 429 修复 + 审核等待体验 + 上传失败结构化日志）**：①多图 429 真根因 = checkUploadGate 用户维度 60s/5 张（一次 4 图发布即破限；App 端本就串行 for-await 非并发）→ risk.js 默认 5→20 **（⚠️ .env 残留同名变量=5 覆盖代码默认值，改代码未生效 —— 部署遗漏已 sed 修正，教训见 §7）** + POST /api/posts 加独立 postsLimiter（10/min/IP，实测 9×200+3×429 精确生效）②composer 预上传改造：选图即入串行泵 _pumpUploads（新图自动接力/失败槽回收），上传中发布按钮禁用显示「上传中 x/N」，全部就绪才可发布 ③带图帖提交时按钮文案 =「图片审核加载中，请耐心等待」（_submitLabel，纯文本帖保持「发布中…」）④上传失败结构化日志：ImageUploadFailure 异常类（stage/failType/httpStatus/ossResponse/putSignAt/putStartAt）+ _classifyImageFailure 分类（risk_limit=JSON 429 用户配额层 / ip_freq_waf=非 JSON 429/403 WAF 层 / sign_invalid=OSS XML / file_validate=后端 ext/size 校验 / timeout/network/auth_expired）+ composer _logUploadFailure 输出 uid/时间戳/文件指纹（kReleaseMode 守卫）—— 实机命中 network（断网）+ risk_limit（并发 curl 打满配额）两场景，正常上传零错误日志 | **2026-11-22 冲刺（支付三连：§13.14~13.16，全栈已上线生产）**：①支付宝原生接入 tobias ^5.3.4（弃 flutter_alipay——Dart 3 incompatible；reward_sheet Android 分支 Tobias().pay(orderString)，iOS 分支不调插件；AGP9 consumer proguard 坑见 §7）→ ②赞赏档位 256→198（1/6/30/68/198 三端统一）→ ③**Apple IAP 接入（§13.16）**：in_app_purchase ^3.3.1 + StoreKit1 回退（verifyReceipt 路线）、后端 src/appleiap.js（生产/沙箱 21007 自动分流 + 白名单映射金额 + transaction_id 防重放）、orders 表 v3.1 迁移 +pay_type、补单双保险（后端 5 分钟轮询留档 receipt + 前端恢复购买）；数据收集与隐私清单见 §14 |

H5 原版位置（参考用，不要再改）：`../dalanhai/index.html`（约 1542 行 CSS + JS 单文件）

---

## 2. 技术栈

| 依赖 | 版本 | 用途 |
|---|---|---|
| Flutter | 3.44.9 stable | UI 框架 |
| Dart | 3.12.2 | 语言 |
| shared_preferences | ^2.3.2 | 本地持久化（对应 H5 localStorage） |
| image_picker | ^1.1.2 | 发帖/头像 图片选择 |
| image | ^4.5.4 | 图片压缩备用（JPEG 1920px max / 85% quality；composer 已切 flutter_image_compress） |
| flutter_image_compress | ^2.3.0 | **v2.6.1 媒体规范**：图片压缩（长边 2048 / 画质 0.7~0.8 / 目标 ≤5MB，输出 jpg） |
| video_compress | ^3.1.4 | **v2.6.1 媒体规范**：视频转码（mov/HEVC → mp4+H.264+AAC，24fps 中等画质） |
| http | ^1.2.2 | 云端对接（OSS PostObject 直传 + media/sign + 发帖） |
| tobias | ^5.3.4 | 支付宝原生 App 支付（alipay.trade.app.pay，仅 Android 调用；iOS 分支不调用本插件，见 §13.14） |
| flutter_launcher_icons | ^0.14.1 (dev) | 从单一源图生成 iOS+Android 图标 |

**字体**：Cinzel Variable TTF（125KB，打包在 `assets/fonts/`，拉丁装饰）+ 系统中文降级（iOS=PingFang SC / Android=Noto Sans CJK）

**Flutter SDK 路径**：`E:\Program\FlutterSDK\flutter\bin\flutter`
**iOS 构建**：本机无 Mac，走 Codemagic 云端

---

## 3. 目录结构

```
dalanhai-app/
├── lib/
│   ├── main.dart                       # 入口：WidgetsFlutterBinding + runApp(GrandBlueApp)
│   ├── app.dart                        # 根组件：多层径向渐变背景 + 水波纹 + 顶栏 + 4 Tab
│   ├── theme/
│   │   ├── colors.dart                 # AppColors 配色 + 12 个渐变（bodyGradient/heroGradient/detailGradient/goldTextGradient/titleGoldGradient/btnGoldGradient/streakPillGradient/gridDoneGradient/certGradient/tabbarGradient/mineBubbleGradient/islandCardGradient）+ **v2.9.11 文字层级六常量（textPrimary/textSecondary/textTertiary/textHint/cardBorder/cardShadow，口径见 §4.1 表）**
│   │   ├── typography.dart             # AppTypography 文字样式（Cinzel + 中文降级）
│   │   └── theme.dart                  # AppTheme.dark ThemeData
│   ├── data/
│   │   ├── models.dart                 # 数据模型（AppData/Certificate/Post/Captain/Report/Island/Group/GroupMessage）
│   │   ├── prefs.dart                  # Prefs 封装（3 个键：dalanhai_v2/used_names/eula）
│   │   ├── island_logic.dart           # 打卡纯逻辑（streak/totalDays/doCheckin/CheckinResult）
│   │   ├── data_store.dart             # DataStore（ChangeNotifier，全局状态管理；**v2.9.11 关键：本地存档 dalanhai_v2 设备级单份，账号维度数据必须经 resetCheckinMirror() 会话边界重置——login()/logout()/main.dart 冷启动三处已挂，新增账号维度数据照此办理，见 §7 账号数据隔离坑**；v2.9.12：_persist 改 400ms 防抖 + catchError，clearAll 先取消定时器防旧数据回写，勿改回同步直写）
│   │   ├── data_store_provider.dart    # InheritedNotifier 注入
│   │   ├── seed_data.dart              # 7 条种子帖 + 70+ 敏感词 + 6 群定义 + 种子消息 + filterText()
│   │   └── auth_service.dart           # 认证服务（dev 本地模式，prod 接 SMS）
│   ├── services/                      # v2.6.1 媒体上传规范 + 云端对接层
│   │   ├── media_rules.dart           # 媒体规范常量（与后端 MEDIA_RULES 对齐：10MB/2048/4张、30MB/30s/1条）
│   │   ├── image_pipeline.dart        # 图片压缩（flutter_image_compress，两档 78→70，>10MB 拦截）
│   │   ├── video_pipeline.dart        # 视频转码（video_compress；①原始时长>30s 拒 ②转码 ③输出≤30MB≤30s 校验）
│   │   ├── cloud_api.dart             # API 客户端（统一 {code,msg,data} + oss put-sign 直传 + media/sign + 发帖；v2.7 /api/post/* 七方法；v2.9.6 增 follow/follow-status/followers/following/userProfile/userPosts/likedPosts/unblock/blocklist + updateProfile bio + @visibleForTesting httpClientOverride 注入；onAuthenticated 静态回调 = 鉴权后落库 hook；v2.9.9 增 sendDm/dm 会话/通知/密码找回 + v2.9.11 增 closeAccount()、searchUsers 返回带 closed；v2.9.12 增 **共享 http.Client 连接池（_shared()，host 变更才重建，勿改回每请求新建——keep-alive 依赖它）** + _putObjectStream 视频流式直传（openRead 边读边发，勿改回 readAsBytes）+ _ossDebug kReleaseMode 守卫（勿删守卫——debugPrint release 照打）+ signMedia postId int.tryParse 防御）
│   │   ├── cloud_models.dart          # 云端 DTO（CloudPost/CloudAuthor/PagedPosts/CloudComment/LikeResult/ReportResult/TagStat/AuthUser/LoginResult/CloudCaptain；v2.9.6 增 CloudUserProfile/Stats/Certificate/UserEntry/PagedUsers/FollowResult/FollowStatus + cloudCertIslandToLocal）
│   │   ├── session_store.dart         # v2.7 JWT 登录态持久化；**v2.9.6 域名单点**：defaultBaseUrl=https://api.idalanhai.com 唯一线上域名（代码单点管理，restore 强制注入并清除设备端持久化旧 baseUrl 残留键 dalanhai_api_base）
│   │   ├── social_state.dart          # v2.9.6 社交全局状态单例：MeState（本人云端 uid 缓存，登出 clear）+ FollowState（关注状态 Map 缓存 + notifyListeners，toggle 成功才写缓存——详情页/他人主页双向实时联动）
│   │   ├── cloud_feed.dart            # v2.7 云端瀑布流 Loader（分页累积/筛选/触底加载/点赞同步/拉黑移除/签名预热，ChangeNotifier；代际守卫 _gen 勿删）
│   │   └── media_sign_cache.dart      # 时效签名缓存（900s 过期重取，missing→占位图；v2.7 增 urlForKey 裸 key 头像渲染；v2.9.12 增 prefetchKeys 头像批量签名（≤10/批）+ 过期淘汰 _purgeExpired + **渲染域名映射 _mapRenderUrl：签名 URL 的 OSS host → img.idalanhai.com（只换 scheme+host，签名 query 原样；改图片域名只动这里）**；登录/登出仍全量 clear 兜底）
│   ├── tabs/
│   │   ├── islands_tab.dart            # 航海报 + 四岛卡片
│   │   ├── port_tab.dart               # 港口瀑布流（单列时间线 v2.9.2；作者头像点击→他人主页）
│   │   ├── bazaar_tab.dart             # 闹市群列表
│   │   └── captain_tab.dart            # v2.9.6 本人管理视角：hero 卡片（头像/昵称/航级标签占位/简介 + 竖排【编辑资料】【账号设置】双按钮）→ 统计栏（关注/粉丝可点弹列表）→ 征服证书横滚 → 航海日志/SAIL LOG 双 Tab（我的日志/点赞的日志）→ 页脚；**底部船员服务已收拢进账号设置页**；订阅 DataStore 打卡通知 → 600ms 去抖重拉 profile（统计联动修复，refreshDebounce 可测试注入）
│   ├── pages/
│   │   ├── island_detail_page.dart     # 详情页（大数字 + 21 天进度格 + 云端打卡；镜像同步传 totalDays 全历史口径）
│   │   ├── auth_page.dart              # 登录/注册（phone/email 云端 + password 本地 flag 模拟；**v2.9.11：登录成功后 _prefetchCheckinMirror 拉 4 岛云端打卡镜像回填——kCloudIslandKeys 循环 fetchIslandCheckin→syncIslandCheckins，静默容错**）
│   │   ├── post_detail_page.dart       # 帖子详情（多图轮播 + 点赞/举报）——本地种子数据
│   │   ├── cloud_post_detail_page.dart # 云端帖子详情（多图/点赞/评论/发评论；v2.9.6：本人无关注按钮、非本人金色关注按钮+顶栏···菜单收纳举报/拉黑、作者/评论头像点击→他人主页）
│   │   ├── user_profile_page.dart      # v2.9.6 他人主页/自身公开访客预览（同一页面双视角：头像区+航级标签+简介 → 关注/发消息/··· → 统计栏 → 证书横滚 → 日志流式列表；无编辑/无服务菜单）
│   │   ├── account_settings_page.dart  # v2.9.6 账号设置（入口=船长页 hero【账号设置】按钮）：顶部【账号ID】静态展示当前登录 uid（v2.9.9，只读无点击，MeState 缓存）→ 三分组【船员服务】联系船务长/打卡提醒 →【黑名单】黑名单管理（路由）→【其他】隐私政策 / 退出登录（v2.9.11 由「下船登出」改文案，逻辑不变）/ **注销账号（v2.9.11：⚠️红字条目，双层弹窗——确认 → 身份校验输入账号 ID 匹配才可执行，成功后清本地会话回首页）**
│   │   ├── edit_profile_page.dart      # v2.9.6 编辑资料（头像上传复用 avatar_upload + 昵称 1-12 + 简介 ≤100，内联红字报错规范）
│   │   ├── blacklist_page.dart         # v2.9.6 黑名单管理独立页（分页 + 解除拉黑；解除不恢复原关注关系）
│   │   ├── composer_page.dart          # 发帖（文本 + 4 图片槽等大 + 7 标签金系；多岛屿分发 + 压缩管线；v2.9.12 图片槽直存 Uint8List 压缩字节，勿改回 base64 dataUrl 中转）
│   │   ├── group_page.dart             # 群聊（消息气泡左浅米右金 + 输入栏；成员头像点击→成员主页，closed 拦截；v2.9.12 轮询挂 WidgetsBindingObserver 后台停/前台恢复，勿删 observer）
│   │   ├── dm_chat_page.dart           # v2.9.9 私信会话（10s 轮询 + v2.9.12 生命周期感知后台停/前台恢复；对方头像云端加载+点击→对方主页，closed 拦截）
│   │   ├── dm_conversations_page.dart  # v2.9.9 私信会话列表（金色昵称 + coral 未读角标）
│   │   ├── notification_list_page.dart # v2.9.9 消息中心（4 类互动通知聚合 + 全部已读）
│   │   ├── forgot_password_page.dart   # v2.9.9 密码找回（三步流：账号→验证码→新密码）
│   │   ├── password_settings_page.dart # v2.9.9 密码设置（设置/修改密码）
│   │   └── profile_page.dart           # v2.9.9 补设密码的昵称补充页
│   └── widgets/
│       ├── bottom_nav.dart             # 4 Tab + 居中凸起金色「+」发布按钮
│       ├── glass_card.dart             # 玻璃拟态卡片
│       ├── progress_grid.dart          # 21 天进度格（7×3）
│       ├── certificate_dialog.dart     # 征服证书弹窗
│       ├── eula_dialog.dart            # 航海守则弹窗
│       ├── signed_image.dart           # v2.6.1：attachKey→media/sign 时效 URL 渲染 + 占位图
│       ├── image_viewer.dart           # v2.9.4：PostImageGrid（1/2/3/4 图自适应网格，>4 截前4）+ showImageViewer 全屏预览（自研零依赖）
│       ├── avatar_crop_page.dart       # v2.9.5：1:1 头像裁剪页（拖动/捏合/圆形参考线）
│       ├── avatar_upload.dart          # v2.9.6：头像上传全流程抽取（选图→>10MB拦截→裁剪→压缩→put-sign直传→后端审核→返回 key；船长页/编辑资料页共用）
│       ├── user_avatar.dart            # v2.9.5：统一头像组件（OSS key→media/sign 900s 签名；data: base64 兼容；失败回退首字）
│       ├── alert_toast.dart            # v2.9.5：统一醒目报错 Toast（深底+红边框红字 2500ms）
│       ├── sail_level_tag.dart         # v2.9.6：航级身份标签（金色小胶囊；showSailLevelTag=false 完全不渲染，无空白占位）
│       ├── social_dialogs.dart         # v2.9.6：「···」更多操作菜单（举报/拉黑/取消）+ 拉黑专属二次确认弹窗（标准文案全站统一）
│       ├── follow_list_sheet.dart      # v2.9.6：关注/粉丝列表底部弹窗（仅展示）+ 黑名单弹窗（带解除）
│       ├── cloud_post_card.dart        # v2.9.6：公共日志卡片（样式=港口流 _CloudCard；他人主页/船长页双 Tab 复用；onAvatarTap 头像跳主页）
│       ├── profile_sections.dart       # v2.9.6：主页公共区块（ProfileStatsGrid 统计栏两行五项 + ProfileCertGallery 证书横滚 + ProfileSectionTitle），他人主页与船长页共用保证样式一致
│       ├── comment_section.dart        # v2.9.7：评论区全套组件（分层评论树/子回复折叠展开/长按菜单/点赞防抖/回复关系头部标签/_stripReplyPrefix/@高亮），改评论逻辑前必读 §6 comment_section 条目
│       ├── at_user_picker.dart         # v2.9.9：@用户搜索底部弹窗（详情页评论/楼中楼与发帖页共用；搜索框 autofocus 自动聚焦 + 空文本退格关弹窗兜底 + 结果按 userId 去重）
│       ├── mention_text.dart           # v2.9.9：正文 @提及渲染组件（正则解析 + sky 蓝高亮 + TapGestureRecognizer 点击「昵称精确搜索→跳主页」，评论区同口径；recognizer 按昵称缓存防泄漏；港口卡片/帖子详情正文已接入）
│       └── service_dialog.dart         # v2.9.6：showServiceDialog 联系船务长二维码弹窗 + showInfoDialog 通用提示弹窗（账号设置页用）
├── test/
│   ├── widget_test.dart                # 旧冒烟测试（「打卡」用例已过时：未适配云端登录闸门，失败非产品 bug）
│   └── captain_stats_sync_test.dart    # v2.9.6 船长页统计联动回归测试（MockClient 注入；打卡通知→统计刷新 + 登录闸门恢复两用例）
├── assets/
│   ├── fonts/Cinzel-Variable.ttf       # Cinzel 字体（125KB）
│   └── images/
│       ├── icon.png                    # 品牌图标（帆船+灯塔+巨浪+海鸥，1024×1024）
│       └── wechat-qr.jpg               # 客服微信二维码（H5 复用）
├── android/                            # Android 工程（已配置 release signing 结构 + 国内镜像）
├── ios/                                # iOS 工程（Info.plist 5 项合规已加：加密声明/全屏/竖屏/相机/相册权限）
├── codemagic.yaml                      # iOS Codemagic CI 配置（从 H5/Capacitor 改写为 Flutter pipeline）
├── pubspec.yaml                        # 依赖 + 字体 + 资产声明
└── AGENTS.md                           # 本文件

../copyright-materials/                 # 软著申请材料（父目录，不在本仓库内）
├── 程序鉴别材料-大蓝海移动应用软件V1.0.pdf   # 源码前30页+后30页，每页50行，共60页
├── 文档鉴别材料-...-用户手册.pdf          # 60页手册：23张图(图3-1~图9-5)统一207×450pt，纯文字页≥30行
├── gen_program_pdf.py                  # 程序鉴别材料生成脚本（改代码后重跑）
├── gen_manual_pdf.py                   # 手册生成脚本（FIGURES锚点系统+TIPS/QUICKREF迭代填充+TARGET_PAGES=60）
├── gen_login_mockups.py                # 4张登录页配图生成（按 auth_page.dart+theme.dart 真实渲染绘制）
└── screenshots/                        # 全部配图：s01~s19 真机截图 + mock_login_*.png + mock_logout_confirm.png + _statusbar_strip.png(真机状态栏裁切)
```

---

## 4. 设计规范（与 H5 一致，必须遵守）

### 4.1 配色（H5 `:root` CSS 变量 → AppColors）

| 颜色名 | AppColors 常量 | 值 | 用途 |
|---|---|---|---|
| abyss | `AppColors.abyss` | `#04101F` | 最深底色（背景、文本色） |
| deep | `AppColors.deep` | `#0A1F3D` | 次深色（按钮背景） |
| ocean | `AppColors.ocean` | `#123A6B` | 主蓝（岛屿、按钮） |
| foam | `AppColors.foam` | `#BFE3FF` | 浪花（today 描边、副标题） |
| gold | `AppColors.gold` | `#E8B84A` | 帝国金（强调色） |
| goldLight | `AppColors.goldLight` | `#F7D77A` | 金渐变亮端 |
| goldBright | `AppColors.goldBright` | `#FFF3C4` | 金色文字渐变最亮 |
| copper | `AppColors.copper` | `#B7702B` | 金渐变暗端 |
| coral | `AppColors.coral` | `#E45B3A` | 旗帜红（红点、警告） |
| parchment | `AppColors.parchment` | `#F1E4C6` | 羊皮纸 |
| inkLight | `AppColors.inkLight` | `#3B2708` | 证书文字色 |
| sub | `AppColors.sub` | `#8FA6C4` | 次要文本 |
| goldHalf | `AppColors.goldHalf` | `gold@50%` | 渐变线（const 上下文用） |
| goldBtnText | `AppColors.goldBtnText` | `#2A1A05` | 金色按钮上的深色文字 |

**v2.9.11 文字层级常量（2026-11-17 色彩对齐 H5 定版，改文字色一律用这组，别散落硬编码）**：

| 常量 | 值 | 语义 |
|---|---|---|
| `AppColors.textPrimary` | `#EAF2FF` | 主正文（H5 body color；岛屿名/帖子正文/评论/群消息/弹窗正文/昵称类另用 #F4FAFF） |
| `AppColors.textSecondary` | `#8FA6C4` | 次级辅助 = `sub` 同值（slogan/签名/消息预览/未选中导航） |
| `AppColors.textTertiary` | `#8FA6C4` | 时间/计数弱小字（与 secondary 同值，语义分层保留扩展位） |
| `AppColors.textHint` | `#5A7099` | 输入框 hint 占位（H5 ::placeholder；`placeholder` 常量已同步此值） |
| `AppColors.cardBorder` | `sky@12%` | 卡片统一细边框（H5 .post 边框口径） |
| `AppColors.cardShadow` | `0 6px 16px black35%` | 卡片统一柔和阴影（const List<BoxShadow>，引用勿重写） |

> 聊天气泡既定规范：**左侧对方气泡浅米色 `#F1E4C6` 墨字、右侧己方气泡金色渐变深棕字**（群聊 + 私信两处已落地，深蓝气泡已移除）；@高亮仍为 sky 蓝、置顶金标/红点/证书羊皮纸不动。

### 4.2 关键视觉规范

- **金色渐变文字**：用 `ShaderMask` + `AppColors.titleGoldGradient`（顶栏标题/船长名字）或 `AppColors.goldTextGradient`（大数字）
- **波浪 SVG**：用 `CustomPainter`，2 条波浪 path（opacity .25 + .4），底部 44px 高
- **罗盘装饰**：70x70 CustomPainter，opacity 0.10，放在 _TopBar 右上角（被 ClipRect 限制不溢出）
- **emoji 图标**：底栏用 🏝️⚓🧭 + CustomPaint 房屋 SVG（闹市），未选中用 `ColorFiltered` 矩阵去饱和度 40% + `Opacity(0.75)`
- **发布按钮**：54x54 圆形金色渐变 + 68x68 虚线圆圈（40 个 dash）+ CustomPaint + 号（stroke-width 3.0）

### 4.3 已知约束（绝对不能违反）

- **「戒色岛」必须叫「清心岛」**（Adult Content 审核风险）
- 整体定位「习惯记录工具」，12+ 分级
- 无 IAP、无广告 SDK（首版）
- icon 不得含文字（App Store 约束）
- iOS Bundle ID: `com.kaitengguan.dalanhai`（不要改）；Android applicationId: `com.haohaixingchen.dalanhai`（软著包名，不要改）
- Android release 签名：`android/dalanhai-release.jks`（alias=dalanhai，有效期 10950 天）+ `android/key.properties`，两者均 gitignore 不入库；release 构建已禁用 debug 签名降级

### 4.3.1 Android Release 签名档案

> ⚠️ 高危重要资产：丢失后该安卓包无法迭代更新，无法补发，不可恢复！

- jks 文件名称：dalanhai-release.jks
- 存放路径：android/dalanhai-release.jks
- 密钥别名 alias：dalanhai
- 密钥库密码 & 密钥密码：bDqnb0BAJXyo9QilHWtu8DDP
- 加密算法：RSA 2048
- 有效期：10950天
- SHA256指纹（支付宝开放平台使用）：
  `F5:27:FE:30:E2:ED:50:F2:E5:EE:85:87:05:5B:8A:A3:22:3C:A4:5B:64:E3:E0:53:EA:C1:C7:D8:FA:25:F7:0B`
- 绑定包名：com.haohaixingchen.dalanhai
- 用途：华为应用市场、安卓全渠道 release 包签名
- 备份要求：离线网盘 + 独立密码管理器两处备份，禁止提交到 git
- 客服微信 `abccba978`，邮箱 `gktvipyx@163.com`，开发者 `kaiteng guan`
- 认证用真实短信/邮件服务（**非演示验证码**，P2 阶段选型）
- **软著著作权人 = 杭州浩海星辰数字科技有限公司**：申请表、源码 PDF、手册三处统一，源码注释中不得出现个人著作权署名

---

## 5. 当前进度

### ✅ 已完成

| 阶段 | 内容 |
|---|---|
| P0 脚手架 | 主题/字体/底栏/4 Tab 占位/数据层 |
| P1 岛屿 | 航海报 + 4 岛卡片 + 详情页 + 21 天进度格 |
| P2 船长 | 登录/注册 + 船长档案 + 证书墙 + 服务列表 |
| P3 港口 | 瀑布流 + 帖子详情 + 发帖（含真实图片选择/压缩）+ EULA |
| P4 闹市 | 群列表 + 群聊 |
| P5 代码 | iOS Info.plist 5 项合规 + Codemagic 流水线 + 品牌图标 + Android 签名结构 |
| UI 1:1 复刻 | 2026-08-07：14 个 UI 文件对照 H5 CSS 逐项重写（渐变文字/光晕/波浪/罗盘/羊皮纸证书/emoji 底栏等全部对齐），`flutter analyze` 0 issue |
| 软著材料 | 2026-09-16 首版 → **2026-10-21 补正版**：补正通知书（流水号 2026R11L3218139）两缺陷已修——①软件名改「大蓝海移动应用软件」②手册补 23 张界面截图（图3-1~图9-5，统一 207×450pt，4 张登录页按 auth_page.dart 真实渲染绘制+真机状态栏裁切）；60 页、纯文字页全部 ≥30 行；12 项自动审计全过 |
| **2026-11-09 冲刺**（全部模拟器 adb 自动化 E2E 验收，逐项日志+截图双重确认） | ①**发帖定位链路终局修复**：`_onTabSelected` 改 `appTabIndex.value=i` 单一向源（旧版只 setState 导致第二遍发帖不切 tab）；定位弃用 GlobalKey（ctx 恒 null 死路）→ idx==0 直接 `animateTo(0)` + 高亮走 postId 比较；②**多岛屿分发**：后端 `post_island` 多对多表（存量回填 + ON DELETE CASCADE）+ composer 传全部勾选岛 `islands[]`；③**多图网格+大图预览器**（零新增依赖自研）；④**全岛打卡按钮置灰**（done 参与禁用 + 守卫只信云端日期——模拟器 UTC 时区与云端 Asia/Shanghai 偏移会让本地镜像误报已打卡）；⑤**岛屿页分享日志发帖闭环**：ComposerPage +`initialTags` 预选岛标签 → 成功 popUntil 回港口 + 分类信号跟随最终帖子的岛标签（`kPortIslandFilterSignal`；⚠️ 两套岛屿 key 命名空间：UI chip=本地 id `qingxin/zaoshui`，后端=`clear-mind/early-sleep`，发信号必须 `cloudIslandToLocal` 转换）；⑥**底部发布入口固定落【全部+最新】**（`kPortFeedAlignSignal` broadcast Stream + 未匹配保留 pending 重试 3 次×700ms 补偿）+ **CloudFeedLoader 代际守卫 `_gen`**（迟到的旧筛选响应覆盖新列表 → 过期丢弃）；⑦**船长页头像修改全流程**（前端裁剪/压缩/直传 + 后端 PATCH nickname 补 Green 文本审核 + profile 头像 OSS HEAD 二次校验）；⑧**统一表单报错规范**（§7.1）；⑨**头像重置 bug 修复**（DataStore.login 重建 Captain 丢 avatar → +updateNickname 只改名 + 冷启动/登录 fetchMe 回填） |
| **2026-11-10 冲刺（v2.9.6 社交 + 统计联动 + 环境治理）** | ①**后端 v2.9.6 已上线生产**（备份锚点 index.js.bak-v2.9.5 + grandblue.db.bak-20261110）：users 补 bio/sail_level、新表 user_follow/app_settings、reports.type+user；接口 9+ 新增（follow toggle/follow-status/followers/following/user profile 全历史统计+证书派生/user posts/liked-posts 自动过滤拉黑/unblock/blocklist/admin settings 航级开关/admin sail-level）；profile bio 编辑（送审）；report type=user；**双向拉黑 isBlockedPair 全站拦截**（详情/点赞/评论/关注/主页 404/403）+ 拉黑瞬间双向清空关注；自测 test-social-api.sh 42 PASS + 全量回归 181 PASS（4 失败=频控/清理时序既有项）；②**Flutter 社交全量**：他人主页/自身公开预览双视角、日志详情关注按钮+···菜单（拉黑标准文案二次确认）、船长页双 Tab（我的日志/点赞的日志）+ 证书横滚 + 统计栏、FollowState 全局关注状态单例、航级标签 UI 占位（后台开关 enable_sail_level_tag 控制）、头像点击全站跳主页；③**打卡统计联动修复**：v2.9.6 重写船长页后统计成一次性快照+无 DataStore 监听 → IndexedStack 常驻卡死——CaptainTab 订阅 DataStore 600ms 去抖重拉 profile；**口径统一**：checkins 镜像只有 21 天窗口会缩水 → 补解析后端 total（全历史）+ AppData.cloudTotals 持久化 + totalDaysOf 云端优先（岛屿卡片/航海报与船长页同口径）；Pixel7 实测打卡后船长页 2→3 实时更新；④**Flutter 域名统一锁定** `https://api.idalanhai.com`（session_store 单点 + 清设备旧 baseUrl 键；裸 IP 不可路由——3000 仅监听 127.0.0.1）；⑤**环境治理**：C 盘清 ~1.15G（.gradle 907M 废弃缓存——GRADLE_USER_HOME/PUB_CACHE 已迁 D:\FlutterCache；gradle wrapper 切 -bin 防膨胀；node_modules 51M 清）；⑥**release 联网阻断修复**：main/AndroidManifest.xml 补 INTERNET 权限（Flutter 新模板只给 debug/profile）；⑦**船长页入口收拢**：hero 卡片竖排双按钮（编辑资料/账号设置）+ 底部服务菜单移除收进账号设置页（三分组）+ 黑名单管理独立路由页；⑧联动回归测试 test/captain_stats_sync_test.dart 2 用例（MockClient 注入） |
| **2026-11-10/11 冲刺（v2.9.7 评论系统 v2，全部模拟器 adb 自动化验收）** | ①**后端 v2.9.7 已上线生产**（备份锚点 index.js.bak-v2.9.6 + src/db.js.bak-v2.9.6；详见 §11.4 v2.9.7 增量）：评论/子评论/评论点赞/删评论/删帖级联/@用户搜索全套接口 + comments 三列迁移 + comment_likes 表；自测 test-v297-comments.sh 全过；②**Flutter 评论区组件** lib/widgets/comment_section.dart：分层评论树（子回复缩进、场景B头部「A ↩ B」纤细箭头关系标签、正文剥离历史预填 @前缀 `_stripReplyPrefix`）、长按 500ms 菜单（复制/删除按权限显隐）、❤️点赞防抖、子回复折叠（默认前2条+「查看余下X条回复」+转圈loading+收起回复）、【作者】标识、统一日期、空态「暂无评论，快来抢沙发」；③**回复输入框**：预置 @昵称置灰固定前缀（prefix Widget 内部不可编辑、空文本退格整体删除 `_commentFocus.onKeyEvent`）、hint 回复@xxx、空内容置灰、@用户搜索弹窗（头像+模糊搜索，删字到光标前紧邻单独@才唤起——半角/全角＠兼容，删字自动收起）；④**删帖**：作者···菜单+二次确认+后端级联清理+`kPostDeletedSignal` 船长页同步；⑤**计数/刷新对齐**：`kCommentCountChangedSignal` 船长页同步评论计数、船长页+他人主页 RefreshIndicator 下拉刷新、评论点赞 FollowState 联动；⑥dalanhai-app git init（本地 master 15+ commit 待 push）；grandblue-server 仍无 git |
| **2026-11-11 下午冲刺（@提及系统 + 匿名图片 + 吸顶栏，全部模拟器 adb 验收）** | ①**船长页批量操作栏吸顶（commit 4572d10，仅改 captain_tab.dart）**：批量模式【全选/删除选中/退出批量】banner 触顶后固定在船长导航栏（_TopBar）正下方、回滚解除——锚点=CaptainTab 视口顶部（IndexedStack Expanded 顶边=导航栏底边）；吸顶时流内 banner `IgnorePointer+Opacity(0)` 原位保留高度（列表零跳动），可见副本 `Stack>Positioned(top:0)` 渲染同一 `_buildBatchBar()`（样式/回调同源）；仅批量模式生效，切 Tab/退出批量重置 `_batchBarStuck`；②**密码登录占位文案**：`手机号 / 邮箱 / 创始人账号` → `手机/邮箱/大蓝海账号`（app 071108f + server b2fd11d 注释对齐；⚠️ 密码登录 tab 仍是本地模拟登录 auth_page.dart TODO，不走后端 /api/login）；③**未登录港口图片不加载修复（server 29c0ddf 已部署，备份 index.js.bak-20261111-125211）**：根因=`POST /api/media/sign` 挂 authRequired 游客 401 → 前端签名缓存吞异常返回 null → 占位图；修复=authRequired→optionalAuth（复用现成中间件）+ 匿名 media_sign_log 记哨兵 userId=0 + `checkMediaSignGate` userId=0 跳过用户维度仅按 IP 频控（否则全游客共享 0 号桶 120张/分钟误伤）——**前端零改动**，点赞/评论/发布等 authRequired 全部未动；未登录端测 5 项全过（图片渲染/4图田字格/预览器/三拦截）；④**发布页 @ 用户搜索弹窗（commit 52a5936）**：详情页私有 `_AtUserPicker` 提取为公共 `lib/widgets/at_user_picker.dart`，composer 主输入框接入同款触发（光标前紧邻单独 @/＠ → 唤起；选中插入 `@昵称␣` 光标后置；createPost 无 atUserIds 不记 uid）；**顺带修了评论区两个从未生效的隐性 bug**：`_closeAtPicker` 从未赋值（?.call() 打 null）+ 弹窗搜索框 autofocus 抢焦点致主框删字检测永不触发；⑤**正文 @ 高亮跳转 + 弹窗自动聚焦（commit 3257d60）**：新建公共 `lib/widgets/mention_text.dart`（正则/sky高亮/昵称精确搜索跳主页同评论区口径，recognizer 缓存防泄漏）接入港口卡片正文+详情正文；AtUserPicker 恢复 autofocus + 搜索框空文本退格关弹窗兜底 + 回填后 refocus 主输入框；⑥**@搜索重复用户修复（app a42a72c / server a942470 已部署，备份 index.js.bak-20261111-144604）**：根因=生产库 uid=1（founder 系统账号）与 uid=12（真实用户）同名「大蓝海创始人」——SQL 单表不可能返回重复行，userId 去重滤不掉不同 uid 同名条目；修复=后端 users/search 加 `AND account_type != 'founder'`（系统账号不参与社交 @）+ 前端 AtUserPicker 结果按 userId 去重防御；验收：搜「海」单条/回填/跳转主页 61 日志=uid=12 确证；⑦**未登录点 @ 弹错误 toast 修复（app 2cebfd9 / server 80cfb74 已部署 bak-20261111-151506）**：根因双层=前端 @ 点击写死登录拦截（MentionText + comment_section 两处 hasToken→「请先登录后再点亮航标」，是④对齐口径时错误带上的）+ 后端 users/search authRequired 游客必 401；修复=前端两处删拦截（跳主页=游客可读）+ 后端改 optionalAuth（游客哨兵 userId=0）；未登录自测 4 项全过（正文/评论 @ 直跳主页无 toast、点赞/关注拦截原样、高亮不变）；⚠️ 教训：用户手动操作模拟器会污染 adb 自测读数，验收前先确认画面是自己的操作结果 |
| **2026-11-11 冲刺（v2.9.8 置顶/批量删除 + 生产部署 + 粉丝数乐观更新）** | ①**UI/交互精修一批**（逐项模拟器验收）：评论时间统一 `yyyy-MM-dd HH:mm:ss`；抖音式布局对齐（主帖+评论/子回复 时间/点赞右侧统一基准线 Expanded+right:4、超长昵称 ellipsis 截断）；评论正文 @用户名 TapGestureRecognizer 点击跳主页（GET /api/users/search 精确匹配）；编辑资料页简介回显（`_load()` 补拉 /api/user/:uid/profile，根因=/api/user/me 不下发 bio）；②**日志置顶+批量删除全栈**（后端 v2.9.8：posts.is_top 列幂等迁移、PATCH /api/posts/:id/top 仅作者+单人上限1条同事务清旧、POST /api/posts/batch-delete 仅本人+任一非法 id 403 全量不删+级联清理、排序 is_top DESC,id DESC；前端 commit b170fc4+7b6945a：CloudPost.isTop/copyWith、置顶金标 Positioned(top:10,right:10)、长按菜单 Sheet+替换确认+批量操作栏、乐观更新+finally 释放 _topBusy、`_loadProfile(silent)` 空终态；**⚠️ CloudPostCard 外层 GestureDetector 必须 HitTestBehavior.opaque**——默认 deferToChild 下卡片空白装饰区不参与命中，「空白区长按」从未生效）；③**网络层健壮性**：cloud_api._request 连接+读响应各 15s 超时（TimeoutException→ApiException，防后端失联时 _topBusy/_loadingPosts 永久锁死无限转圈）；AndroidManifest `usesCleartextTraffic=true`（过渡期兼容生产 http 签名 URL，后端部署后为无害冗余）；port_tab `_onFilterChanged/_onSortChanged` 在 _cloud==null 时调 _retryCloud()（消除种子死锁——云端首拉瞬时失败静默回落种子后切筛选/排序 no-op 卡死）；④**后端 getUgcOssClient 加 secure:true**（ali-oss 默认签 http:// 明文 URL，Android 9+ 禁明文→图片全占位；同 URL https 实测 200）；⑤**生产部署 v2.9.8（2026-11-11 由 AI 经 SSH 直连执行）**：安全组加白 112.10.221.79/32 后——备份 index.js.bak-20261111-095542+src/db.js.bak-20261111-095542 → scp index.js+src/db.js → node --check → pm2 restart grandblue → 日志确认 is_top 迁移自动执行+health OK；服务端零数据变更冒烟（置顶空操作 wantTop=当前值/batch-delete 非法 id 验路由/media/sign 验 https）；Pixel7 生产包全套自测过（三轮发帖定位/置顶金标/替换确认/取消置顶不锁死/图片/打卡/评论删/批量删，posts 总数 67 部署前后一致零污染；**⚠️ .env FOUNDER_USER=dalanhai 是 uid1 role:founder，App「大蓝海创始人」是 uid12——403 只有日志作者可置顶是正确权限行为**）；⑥**粉丝数关注/取关刷新不同步修复（commit bc055b2）**：根因=端侧 POST 偶发迟滞（后端实测 0.18s 秒达无任何问题）——POST 未落库时下拉刷新 GET 先到拉到旧值；修复=`_toggleFollow` 乐观更新（点击瞬间 FollowState.set 翻按钮+`_applyLocalFollowers` 本地±1粉丝数，成功 `_loadProfile(silent:true)` 对账、失败回滚+toast）+ `_onRefresh` 先 await `_pendingToggle` 再拉数据 + `CloudUserProfile.withFollowers` 拷贝构造；Pixel7 验收：取关→0/关注→1（核心场景）+二轮循环全过；⑦**数据疑云三次排查**（均无损失）：「船长62」空白号=测试包连本地库真实手机号自动建号（备份后清 293 测试帖+uid62）；「图片全没了」=游客态 media/sign 强制 JWT 防爬设计+http 明文占位（非误删，生产 66 帖 attachKeys/OSS 全完好）；「港口变回 H5」=debug 包种子死锁（见③） |

| **2026-11-15 冲刺（v2.9.9 消息中心 + 密码找回 + v2.9.10 群聊接入，全部模拟器 adb/curl 自动化验收）** | ①**邮箱输入全角归一化（app 6c41381）**：Gboard 拼音键盘手输 `.`→「。」、`@`→全角＠（小屏肉眼难辨），前端正则只认半角 → 误拦李雷 gmail；修复=`AuthService.normalizeEmail`（＠→@、。/．→.）`isValidEmail` 内部先归一化，auth_page 邮箱两处读取点（发码/登录）校验与请求共用同一归一化值（后端正则也只认半角）；输入框展示保持原样；②**找回密码双分支全栈（app 553ffdf / server 6468697 已部署，备份 index.js.bak-20261115-182220）**：`/api/sms/code`、`/api/email/code` 加 `purpose=reset`（reset 不自动注册、未注册 404、冷却按 purpose 分桶，login 原逻辑零变化）+ `POST /api/password/reset`（仅手机/邮箱，purpose=reset 一次性核验复用登录风控口径，bcrypt 更新，成功不自动登录）；Flutter 找回密码页弃本地模拟接真实 API，成功 toast 后 pop 回登录页；**Email reset 发码豁免 captcha**（找回页无验证题 UI，风控闸门+3条/h/邮箱+10条/h/IP+60s 冷却兜底）；李雷/创始人两账号真实短信+邮件收码全链路验收（新密码 666666）；③**HTTP 401 业务文案透传（app cde8b0f）**：`cloud_api._request` 原 401 一律替换「登录已失效，请重新登录」吞掉后端「账号或密码错误/账号不存在/未设置密码」→ 改为优先透传 body.msg 解析失败回退默认文案（token 失效场景后端 msg 本就相同行为不变）；④**船长页日志列表登录态刷新修复（app 98879fd）**：IndexedStack 常驻 initState 只跑一次，冷启动未登录态 _loadPosts 401 失败后登录新账号 `_onStoreChanged` 只重拉统计不重拉列表 → 统计对了列表仍空；修复=去抖回调里 `_loadProfile()+_loadPosts()` 一起拉；⑤**消息中心（server 5c155f0 已部署 bak-20261115-205815 / app d09ea56）**：新表 notifications（like_post/like_comment/reply/mention）+ dm_conversations/dm_messages；埋点=帖子赞/**⚠️ Flutter likePost 走 `/api/post/:postId/like`（该路由必须埋），`/api/posts/:postId/like` 旧路由也埋（单请求只走一条）**+评论赞+评论（reply 通知被回复者、mention 通知 atUserIds 并与 reply 去重）；接口 unread 4 类计数/平铺列表（聚合「磐石、南十字等4人点赞了你的航海日志」由前端按 postId/commentId 分组）/read 批量/read-all；私信 POST /api/user/dm（拉黑禁止、founder 拒收、500 字上限）+会话列表（未读）+会话消息（打开即置已读）；Flutter：闹市 5 个大圆角方形入口一行 Expanded×5（评论获赞=气泡内嵌红心自绘 Stack、角标>99 显 99+、未登录整体隐藏）+ 4 类共用通知列表页（like 聚合+全部已读+空态「暂无消息，等待船员互动」）+ 私信会话/聊天页（10s 轮询、失败回填）+ 详情页 `initialCommentId` → `CommentSectionState.scrollToComment`（等首屏 loadFirst → 逐页 loadMore → 子评论展开根线程 → ensureVisible+金色边框高亮 2s）；⑥**群聊后端接入 v2.9.10（server e7e3b75 已部署 bak-20261115-220456 / app c837ace）**：新表 groups（g001-g006 seed 幂等）/group_msg/user_group_unread（PK uid+group_id）；接口 list（member_count=发过言去重 uid 动态统计、unread=动态 COUNT(msg_id>last_read_msg_id) 无需推送）/info/msg 分页（last_msg_id 上拉更早）/POST msg（登录+Green 线上审核（实测已启用）+**本地敏感词兜底词表** GROUP_LOCAL_BANNED_WORDS 第二道闸）/POST read UPSERT；Flutter：闹市群列表登录→云端渲染（未读角标时间右侧）未登录→seed 降级、点击登录直进群免邀请、未登录弹「需要登船」引导、seed 群 id→g00x 映射 `_seedToCloudId`；群聊页乐观发送（负 msgId 临时气泡→回执替换→失败 toast 回填）+滚动到顶上拉分页+10s 轮询+空输入置灰+头像 UserAvatar+sys 邀请文案移除；自测 9/9 过；测试残留：g001-g003 有群消息（训练日志 25 条等），上线前清库 `DELETE FROM group_msg; UPDATE groups SET member_count=0;` |
| **2026-11-16/17 冲刺（v2.9.11 对比度优化 + H5 色彩对齐 + 注销功能全栈落地，全部 Pixel7 adb 自动化验收）** | ①**文字对比度优化**：colors.dart 新增 textPrimary/textSecondary/textTertiary/textHint/cardBorder/cardShadow 六组 const 常量，38 文件按语义套用（金色/底色/布局零改动，git diff 扫描确认无误改）；②**色彩对齐 H5 原版**：常量值级切换（正文 #EAF2FF、辅助 #8FA6C4、hint #5A7099、卡片边框 sky@12%、阴影 0 6px 16px black35%、名字类 #F4FAFF、列表卡渐变 ocean@55%），聊天气泡既定规范落地（左浅米 #F1E4C6 墨字 / 右金渐变 深棕字，群聊+私信两处），composer 未选中标签纠回金系；③**4 图片槽等大 bug 修复**：Row 内 Padding 内缩改 SizedBox 独立占位（composer_page 1 处）；④**私信/群聊头像跳转 + 发消息链路**：dm_chat 补 _peerAvatar 加载+点击跳主页、群聊 _Avatar 全员可点跳主页、他人主页【发消息】由占位 toast 改 push DmChatPage；⑤**账号注销功能全栈落地（按 §12）**：后端 users.status 迁移 + POST /api/account/close 匿名化事务 + closed 全链路拦截（登录/续期 401、搜索排除、profile 匿名清零、dm/follow 403、群聊快照实时匿名覆盖）+ Flutter 注销入口（账号设置【退出登录】改文案 +【注销账号】⚠️双层弹窗身份校验）+ closed 渲染（作者/@提及点击无响应或静默、关注按钮/操作行隐藏）；本地 API 自测 23/23 PASS；**生产真实注销 uid12 验收通过**（库确认 closed/昵称改写/手机号释放）；⑥**注销后同手机号重注册打卡残留修复**：根因=Flutter 本地存档 dalanhai_v2 设备级单份不隔离账号，DataStore.resetCheckinMirror() 会话边界重置（login/logout/冷启动三处）+ 登录后 4 岛云端回填（auth_page _prefetchCheckinMirror + main.dart refreshCheckinMirror）+ 后端注销事务加 DELETE user_island_checkins（uid12 残留 15 条已清）；§12.1.7/12.2.2 规范同步改版（打卡注销即清） |
| **2026-11-18 冲刺（v2.9.12 安全/性能 9 项 + 图片域名切换，单测 6/6 + Pixel7 adb 验收）** | ①cleartext 出主 manifest（release 恒 HTTPS，debug 保留）；②_ossDebug kReleaseMode 守卫；③CloudApi 共享 http.Client（keep-alive 连接池，host 变更重建，httpClientOverride 测试注入语义不变）；④MediaSignCache.prefetchKeys 头像批量签名（≤10/批）+ _purgeExpired 过期淘汰；⑤composer 图片 Uint8List 直存（去 base64 中转省 33% 内存）；⑥DataStore 400ms 防抖写盘 + catchError（clearAll 先取消定时器防旧数据回写；拆分 key 存储未做）；⑦dm/group 轮询 WidgetsBindingObserver（paused/hidden 停、resumed 立即拉+恢复；/proc/net/tcp 实测后台 0 连接）；⑧视频 _putObjectStream 流式直传（openRead 边读边发，120s 超时）；⑨compressImage 二档复用首档输出 + signMedia postId int.tryParse 防御；⑩**渲染域名 img.idalanhai.com**（_mapRenderUrl 单点，签名 query 跟随，curl 实测 200/无签名 403；新单测覆盖 host 替换 + 参数保留断言）；回归用例落 test/regression_fixes_test.dart（防抖/分批/防御/域名映射） |
| **2026-11-18 下午（服务端迁移 + 匿名放行回归，curl + Pixel7 adb 验收）** | Node .env 迁 HOST=0.0.0.0/PORT=8080（两行外零改动，nginx 反代跟随）；部署生效后四接口探针：media/sign 匿名 200 / user-me 401 / like 401 / posts 401 —— **匿名放行只覆盖 media/sign 签名通道**；模拟器匿名态（pm clear）与登录态（uid23 App UI 登录）港口页图片渲染一致 |
| **2026-11-18 晚（ESA 图片域名事件，curl 矩阵 + 24 轮 + 13 轮复测）** | 排障三层实锤：①ESA 边缘节点质量参差（8 节点 2 个 TCP 死、多数 TLS 秒断、正常节点回源 9-12s）②工单定性双重鉴权冲突 → App 端 `_mapRenderUrl` 剥离签名 query（Uri 重建防尾随 `?`）③最终 13/13 图片恢复（匿名 7 + 登录 6） |
| **2026-11-19 凌晨（Green 审核 404 修复，仅后端 2 文件）** | ①`moderateImage` 送审 imageUrl：`ugcSignedUrl(600)` → **ESA 无签名直链** `https://img.idalanhai.com/<key>`（规避国内 Green 节点跨境下载香港 OSS 404）②`imageModerationPlus` 重试循环（1+2 次尝试、单次 `IMAGE_TIMEOUT_MS=12s` 可 env 调、间隔 500ms）+ `cipRpc` 支持 `opts.timeoutMs`；③兜底 fail-closed 不变。生产实战：uid23 发图帖重试第 3 次成功入库（前 2 次 ESA 偶发 404 被兜住），composer-post 回调 + feed 展示 ✓；敏感词文本帖 403 拦截链路 ✓。遗留观察：Green 经 ESA 下载仍偶发 404（重试兜住，若持续 3/3 失败再评估 Green 切香港 region / OSS 迁国内） |
| **2026-11-19 凌晨二（多图 429 + 预上传 + 审核文案 + 上传失败日志）** | ①risk.js 图片配额默认 5→20（**.env 残留 5 覆盖代码 —— 部署遗漏实锤**）+ postsLimiter 独立计数器 10/min/IP ②composer 预上传串行泵 + 发布按钮上传就绪才启用 ③带图帖 loading 文案「图片审核加载中，请耐心等待」④ImageUploadFailure 结构化分类日志（实机命中 network/risk_limit，响应形态实锤 file_validate=「不支持的图片格式」、sign 形态 RequestTimeTooSkewed）；probe 帖已清理（DELETE `/api/posts/:postId` **复数路径**，单数 `/api/post/:id` 是 404） |
| **2026-11-21 下午（支付宝支付后端模块全链路验收闭环 ✅，详见 §13）** | grandblue-server 新增支付模块（src/alipay.js + orders 表 + 三接口）：预下单 RSA2 签名 / 异步 notify 验签（字节级，剔 GBK 转码坑）/ 幂等防重发货 / 定时查单兜底（5min 扫描 + 30min 自动关单）；**0.01 元真实订单全链路生产验收通过**（scheme 二维码扫码付款 → 真实 notify → PAID，交易号 2026112123001470161403747523，0 验签报错）；密钥三件套已配好入服务器 .env（AppId 2021007121620744，应用公钥/支付宝公钥均已验证生效），**平台配置与密钥不再动**；Flutter 端支付页面待开发（对接契约见 §13，入口计划放开服公告） |

### 🟡 待用户操作（按优先级）

**（2026-11-18 追加）v2.9.12 两端改动未 commit**：Flutter 端 9 项安全/性能修复 + 图片渲染域名 img.idalanhai.com 切换 + 新增 test/regression_fixes_test.dart；工作区还叠着 v2.9.11 未提交内容，建议按功能分批 commit。**下版本排期**：token 迁 flutter_secure_storage（现为 shared_preferences 明文）、auth_service 死代码清理（sendCode/verifyCode/lastSentCode 内存验证码逻辑仅本地演示，生产只该留 isValidPhone/normalizeEmail/isValidEmail）、api.idalanhai.com SSL pinning、release 包 [feed-refresh] 等 debugPrint 统一加 kReleaseMode 守卫。**验证备注**：uid23（13125557972）已实测登录态发帖图片上传全链路（PUT 走 OSS 原始域名、渲染走 CDN）+ 私信/群聊轮询后台停前台恢复 + 匿名图片放行回归（media/sign 匿名 200、受保护接口仍 401，2026-11-18 下午）；群聊「发送消息」UI 自动化未覆盖（模拟器 input text 焦点问题），建议手点一次。

**（2026-11-17 追加）dalanhai-app + grandblue-server 两端本次改动未 commit**：v2.9.11 全量（对比度优化 38 文件 + H5 色彩对齐 + 图片槽修复 + 私信链路 + 注销功能 + 打卡镜像修复），工作区改动量较大，建议按功能分批 commit；grandblue-server 生产已部署但本地仓未推（无远程）。

**（2026-11-17 追加）uid12 手机号重注册验收**：13125557972 已释放，可随时走注册流程拿全新空白 uid（需真实短信码；重注后打卡/粉丝/日志全部从零，旧内容保持【已注销用户】——§12.2 已实测打卡口径，其余链路顺带核对）。

**Apple 个人→组织迁移（2026-10-25 启动，案例 103004430882）**
- 邮件 6 要点：①双重认证（去 appleid.apple.com 确认已开）②**组织网站=硬门槛**（公开可访问+域名与公司关联）③迁移期间 CIP 门户锁、ASC 不受影响（Codemagic 签名会受阻，别排 iOS 构建）④迁移后开发者名变公司（✅ 与软著对齐）⑤个人版"销售和趋势"无法获取 ⑥付费收入转银行账户（无 IAP 不适用）
- 关键路径：买域名（阿里云公司实名）→ 做公司官网 → 部署杭州 ECS → ICP 备案 1~2 周 → 网站公开可访问后回复 Apple 开始迁移
- **迁移时机最佳**：未上架无用户无收入，迁移成本最低；但要避开审核/构建任务
- 回复 Apple 邮件模板（确认双重认证+询问网站要求+说明正在准备）已在历史对话中给出

**软著补正提交（材料已就绪，30 天期限 ~11/20）**
1. 申请表软件全称「大蓝海移动应用软件」+ 版本号 V1.0 + 著作权人「杭州浩海星辰数字科技有限公司」（与两份 PDF 一致）
2. 申请表"软件主要功能"照手册 1.3 节 7 条填；"源程序量"填约 5800 行
3. 补正说明栏模板已在历史对话中给出（2 条：名称规范 + 截图补充）
4. 提交：申请表 + 两份 PDF + 企业营业执照副本

**后端 / 服务器（✅ 本地 v2.6.2 完成 166 PASS/0 FAIL/3 SKIP 全绿 + 真实链路 9/9 健康检查 + 视频 E2E 闭环，待部署；完整文档见 §11 及 ../grandblue-server/部署文档.md §15-§17）**
1. **版本演进**（本地路径 `../grandblue-server/`，Express + JWT + SQLite + 零新增 npm 依赖）：
   - **v2.4 OSS 直传 + 内容安全审核**：`GET /api/oss/policy` 双 bucket 直传签名（UGC 图片 `ugc/`+视频 `video/` 全存香港 `dalanhai-app-check`；官网资源走杭州 `dalanhai-website-cn` 仅创始人）；`src/moderation.js` 手写 acs ROA 签名调阿里云内容安全旧版 green API（官方 SDK 有缺陷弃用）——图片**同步**审核不过不入库 403，视频**异步**审核入库 `pending`；posts 表加 `status/moderation_task_id/moderation_detail/reviewed_at` 四列；审核开关=`GREEN_ACCESS_KEY_ID/SECRET` 配置即启用，未配放行（仅限开发）
   - **v2.5 短信防刷风控**（`src/risk.js`，纯 SQLite 4 张新表）：规则①账号近1h发码≥3次且零核销→前置人机验证；②验证码连错3次→锁10分钟；③同IP 1h内给≥6个不同账号发码→强制滑块（算术题 `GET /api/captcha/challenge`，无第三方依赖）；运营看板 `GET /api/admin/sms/stats`（核销率<30%告警、TOP10号码/IP、风险分级）；阈值全 `RISK_*` 可调
   - **v2.5.1 流水自动清理**：`sms_send_log` 默认保留 30 天（`SMS_LOG_RETENTION_DAYS` 可调），每日 03:00 调度器 + 手动接口 `POST /api/admin/sms/cleanup`（创始人）
   - **v2.5.2 P1 三项基建**：①captcha 过期凭证清理（并入 03:00 调度器）；②创始人风控管理接口 5 个（`POST /api/admin/sms/risk/lock|unlock|clearFlag|blacklistAdd|blacklistRemove`，审计写 risk_flags.note）；③全局异常捕获 + `src/logger.js` 结构化 JSON 日志（敏感字段打码/手机号中段打码/AK 保留前6位）+ `wrap()` 包装 async 路由 + 进程级兜底
   - **v2.6 机器审核增强版 + OSS 时效签名防爬（P0，2026-11-07）**：①文本审核 TextModerationPlus（`ugc_moderation_byllm_pro`，同步先审后放行，接入发帖正文+评论）；②图片审核 ImageModeration（`postImageCheckByVL`，同步；⚠️ 控制台 `image_moderation_pro` 只是控制台服务标识不是 API Service 参数值，五地域实测 401；`ImageModerationPlus` Action 不存在）；③判定映射 RiskLevel none/low→pass、medium→review 拦截、high→block，超时/异常兜底一律拦截不入库；④审核留存 `moderation_logs` 表（requestId/label/判定/帖子/用户，90 天）；⑤防爬四道闸：UGC 桶私有读（✅ 2026-11-07 已改私有，直访 403）+ 帖子只返回 `attachKey` 不发永久直链 + `POST /api/media/sign`（JWT+频控 120/600 每分钟+只签 status=pass 帖+900s 时效）+ 高频拦截 429 写 `media_sign_log`/`risk_flags`；⑥签名实现手写 RPC V1 HMAC-SHA1（green-cip 2022-03-02），零 npm 依赖，文本/图片真机验证 Code=200；⑦视频链路 v2.6.2 已迁移 green-cip `VideoModeration`（异步提交）+ `VideoModerationResult`（轮询，Code 280=检测中），旧版 green 2018-05-09 + acs ROA 签名代码整体删除（新账号未开通旧版服务返回 596）
   - **v2.6.2 视频审核迁移 green-cip 统一栈（2026-11-07）**：文本/图片/视频三链路全部走 green-cip 2022-03-02 + 同一 `cipRpc`（RPC V1 签名）；视频=Service `videoDetection`（杭州仅此服务，`MODERATION_VIDEO_SERVICE` 可换 videoDetectionByVL 仅北京/上海），判定口径与图文一致（Data.RiskLevel none/low→pass、medium/high→reject）；结果接口单 taskId/次→逐任务并发查询，单任务失败（网络/限流/bad taskId）降级 pending 下轮重试不阻断整批，24h 兜底 reject 零改动；`videoScanSubmit/videoScanQuery` 函数签名不变 → index.js 轮询/提交调用点零改动、DB/对外接口/错误码零改动（Flutter 零感知）；回调改轮询模式（旧 callback 端点保留兼容不再触发）；真实 E2E：991KB mp4 上传→发帖 pending→`vi_f_*` 任务提交→60s 轮询→pass 入库→media/sign 900s URL GET 200
   - **v2.7 P0 港口流/帖子详情七接口（2026-11-08，已上线生产）**：①`GET /api/post/list` 瀑布流分页（island 枚举筛选 + tag 白名单筛选带不带 # 均可 + page/size≤20 + 拉黑过滤 + 只返回 pass）；②`GET /api/post/:postId` 详情（coverKey/coverKeys/author{uid,nickname,avatar}/island/tags/likeCount/liked/commentCount，拉黑作者 404）；③`GET /api/post/:postId/comments` 评论分页（正序 + 拉黑评论过滤）；④`POST /api/post/:postId/like` 幂等 toggle（复用 likes 表，返回 {likeCount,liked}）；⑤`POST /api/user/block` 拉黑（列表/详情/评论三向隔离，创始人不可被拉黑）；⑥`POST /api/report` 举报（理由送审→reports 人工队列不自动删帖，同目标 24h 去重，隐藏资源 404）；⑦`GET /api/tag/list` 热门标签；配套：`POST /api/posts` 接受 island/tags（白名单=清心岛/戒烟岛/健身岛/早睡岛/日更/新船员/妙招/装备党）、`POST /api/user/profile`（nickname/avatar 送审落库）、media/sign 新增 `keys` 参数（≤10，头像等非帖子资源）、读取接口 IP 风控 readRiskGate（READ_LIMIT_IP_PER_MIN 默认 120，超限 flagRisk(read_rate)+403；验证码锁定账号 403）；DB 迁移幂等：posts+island/tags/comment_count（存量回填）、users+nickname/avatar、新表 user_block/reports、moderation_logs biz_type 扩展+report/profile（重建表）；⚠️ 两处与需求文档的必要适配：postId=整数自增 ID（非 uuid）、coverUrl→coverKey/coverKeys（防爬红线不下发永久直链，头像走 media/sign keys）；⚠️ scp 陷阱：`scp index.js src/db.js host:/opt/grandblue/` 会把 src/db.js 平铺到根目录而非 src/ 子目录，必须分两条 scp；本地 test-p0-api.sh 62 PASS + 全量回归 166 PASS/0 FAIL/3 SKIP 零回归；生产部署后真实审核模式 62 PASS/0 FAIL，测试残留已清（终态 founder+2 原帖）；备份锚点 `grandblue.db.bak_p0_20261108`
   - **v2.6.1 媒体上传规范（PutObject 之前闸门，2026-11-07）**：①`MEDIA_RULES` 常量：图片 10MB/长边 2048px/4 张/帖/jpg,jpeg,png,webp（拦截 gif/heic），视频 30MB（转码后 mp4）/30s/1 条/帖/仅 mp4 容器（H.264+AAC 由 Flutter video_compress 转码保证）；②`GET /api/oss/policy` 前置校验声明参数 ext/size/duration/width/height，非法 400 不发签名，视频必带 duration；③上传频控：单用户图片 5 张/分钟、视频 1 条/分钟（policy 签发+中传统一计数），超限 429 写 `upload_log`（第 14 张表）+ `risk_flags(upload_rate)`；④`POST /api/posts` 支持 `attachUrls` 多图数组（1-4 张逐张送审），违规有附件帖入库 status=reject 留存（审计+清理定位）；⑤OSS 7 天清理任务：reject 帖超 `OSS_PURGE_REJECT_AFTER_DAYS`（默认 7）删对象+标记 `posts.oss_purged=1`，每日 03:00 调度 + `POST /api/admin/oss/purge` 手动；⑥media/sign 多图帖逐 key 签发 `{url, urls[], expiresAt, expiresIn}`，oss_purged=1 不再签发；⑦中转 `/api/upload` 去 gif、`/api/upload/video` 收紧仅 mp4 ≤30MB
2. **真实链路已验证（2026-11-07）**：①OSS 直传——RAM 子账号 `dalanhai-oss-app`（仅 oss:PutObject）授权后，香港桶 ugc/、video/ 与杭州桶 static/ 均 HTTP 204，越权目录 403；②短信——`src/notify.js` 修复 3 个致命 bug（方法名小写驼峰 / 必传 SendSmsRequest 模型实例 / 补业务码检查）后，13125557972 真实收码，发码→冷却→注册→登录全链路闭环；③增强版审核——手写 RPC V1 签名调 green-cip 2022-03-02 一次跑通，TextModerationPlus（ugc_moderation_byllm_pro）与 ImageModeration（postImageCheckByVL）均 Code=200，新 AK（GREEN/OSS 共用）PutObject 204 / 审核签名 URL 200 / 过期签名 403 全验证
3. 业务规则（v2）：**所有登录用户可发图文帖/评论/点赞/传图；视频帖+视频上传仅白名单用户（创始人默认在）；白名单仅创始人可管，用户加微信 abccba978 人工开通**；规避网文证风险
4. **架构红线**：UGC 全走香港 `dalanhai-app-check` 桶；官网/APK 走杭州 `dalanhai-website-cn` 桶；零新增 npm 依赖；AK/SK 全走 `.env` 不入文档不入公开仓库
5. **生产节点（✅ 已上线，2026-11-08）**：香港 `8.210.145.212` `/opt/grandblue`（pm2: `grandblue`），Base URL **`https://api.idalanhai.com`**（nginx 443 反代 + Let's Encrypt 自动续期 + 限流；后端仅监听 127.0.0.1:3000，公网 3000 不可达）。运维锚点：全量备份 `/opt/grandblue_bak_20261108_pre_v262`（部署前）与 `/opt/grandblue_db_backup_before_cleanup_20261108.db`（清库前）；nginx 配置 `/etc/nginx/conf.d/api.idalanhai.com.conf`；证书 `/etc/nginx/ssl/api.idalanhai.com.{crt,key}`（acme.sh cron 自动续期）。服务器 `.env` 现状：真实 OSS/GREEN AK（与本地同组）+ 真实 SMTP（163 新授权码）+ SMS 未配置走日志兜底 + `DEV_MODE=0`/无 `MODERATION_MOCK`/`TRUST_PROXY=1`。**改代码后部署**：scp 改动文件 → `pm2 restart grandblue --update-env`（⚠️ 严禁上传 grandblue.db）。剩余运维项：安全组删 3000 放行规则（无实际风险，清理性质）、AK 上线稳定后轮换
6. 下一步（按优先级）：**Flutter 对接生产 API**（`https://api.idalanhai.com`；services 层已就绪：CloudApi/MediaSignCache/双管线/SignedImage，剩登录态注入 + DataStore 混改 + needCaptcha 适配 + composer 视频入口）；P2（私信/举报/帖子管理/大盘）后续迭代

**上架**
1. Google Play 开发者账号注册（$25 一次性，验证几天）
2. 生成 Android keystore：`keytool -genkey -v -keystore ~/dalanhai.jks -keyalg RSA -keysize 2048 -validity 10000 -alias dalanhai`，填入 `android/key.properties`
3. Codemagic 配置：确认 ASC 集成名「大蓝海」、Team ID `5QLTMB4JGC`、Provisioning Profile 已上传
4. 触发首次 Codemagic 构建验证 `codemagic.yaml`
5. App Store Connect 截图重出 6.5"（Flutter UI）

### 🟢 ASC 端已就绪（可复用 H5 版）

- iOS App「大蓝海」1.0 已可分发（之前 H5 上架过，**Flutter 版不需要新建 App 条目**）
- Bundle ID `com.kaitengguan.dalanhai` 已注册
- 销售范围已设：175 个国家或地区（141 正常 + 34 无法销售）
- 名称「大蓝海」、副标题「自律打卡岛屿 · 21天养成好习惯」已填

---

## 6. 关键文件说明

### `lib/app.dart`
- `GrandBlueApp`：根组件，4 Tab + 顶栏 + 背景
- `_AppBackground`：多层径向渐变 + 水波纹点阵
- `_TopBar`：金色渐变标题（ShaderMask）+ 罗盘装饰（70x70, opacity 0.10），被 ClipRect 包（防止溢出）
- **顶栏标题**：H5 默认**左对齐**（详情页才居中），用 `Align(alignment: Alignment.centerLeft)` + `Column(crossAxisAlignment: start)`

### `lib/widgets/bottom_nav.dart`
- 4 Tab + 居中凸起发布按钮
- **关键陷阱 1**：发布按钮放在 `ClipRect` 外面独立 Stack 节点，否则上半圆被裁剪
- **关键陷阱 2**：`_ComposeButton` 的 GestureDetector 必须设 `behavior: HitTestBehavior.opaque`，否则 Positioned+BackdropFilter 组合下点击穿透无反应
- 整体 `SizedBox(height: 72 + 22 + bottomInset)`，tab 行高 72 + 凸出空间 22 + home indicator

### `lib/data/data_store.dart`
- 全局状态管理（ChangeNotifier）
- 关键方法：`checkin/islandId → CheckinResult`、`addPost(text, tags, images) → String?`、`toggleLike`、`deletePost`、`reportPost`、`blockUser`、`clearAll`、`ensureLocalCaptain`
- **打卡统计口径（v2.9.6 修复后）**：`totalDaysOf/streakOf/maxStreakOf` 均云端镜像优先（cloudTotals/cloudStreaks/cloudMaxStreaks，全历史口径）→ 老存档 null 时空安全降级本地计算；`syncIslandCheckins(..., totalDays:)` 打卡/拉取时同步三镜像 → 岛屿卡片/航海报与船长页 stats 完全同口径
- **v2.9.5 状态更新红线**：改昵称必须用 `updateNickname(name)`（只改 name），改头像用 `updateAvatar(key)`；**绝不用 `login()` 更新已登录用户的资料** —— login 会整体重建 Captain 对象丢掉 avatar（已修过的头像重置 bug，别退化）

### 社交状态单例（services/social_state.dart，v2.9.6 改社交逻辑前必读）
- `MeState.instance.uid()`：本人云端 uid（本地 Captain 无 id 字段），冷启动/登录后 fetchMe 拉取并缓存；**登出必须 clear**（账号切换防串号）
- `FollowState.instance`：关注状态 `Map<uid,bool>` 缓存 + ChangeNotifier；`toggle(uid)` **网络成功后才写缓存**（保证无状态错乱）→ 日志详情页/他人主页 AnimatedBuilder 监听实时刷新；`ensure(uid)` 拉状态；登出 clear
- 船长 Tab 统计联动：CaptainTab 在 didChangeDependencies 订阅 DataStore（IndexedStack 常驻不重建，**必须主动订阅**）→ 打卡通知（syncIslandCheckins）→ 600ms 去抖重拉 profile；`CaptainTab.refreshDebounce` 可测试注入（联动测试 test/captain_stats_sync_test.dart）

### 统一表单报错规范（v2.9.5，后续 UGC 审核报错一律参照）

| 类型 | 形式 |
|---|---|
| 单行文本输入类（昵称、简介） | 控件下方**内联红色 #ef4444 文字** + 输入框边框转红；内容变更自动清除（参照 profile_page.dart `_errorText`） |
| 图片/文件上传类（头像、帖子配图） | `showAlertToast`（widgets/alert_toast.dart）：不透明深底 + 红边框红字，中央弹出 2500ms；**禁止用底部淡色半透明 SnackBar 报错**（成功提示类浮条可保留） |
| 审核失败固定文案 | 昵称「昵称未通过安全审核，请修改后再试」/ 头像「头像未通过安全审核，请更换图片后重试」（判定：`e.message.contains('安全审核')`） |

### 全局信号一览（services/cloud_feed.dart，改发帖/港口逻辑前必读）

| 信号 | 类型 | 触发方 → 消费方 | 语义 |
|---|---|---|---|
| `kCloudFeedRefreshSignal` | ValueNotifier<int> | composer 成功 → port_tab 刷新流 | 值自增 |
| `kFeedLocatePostSignal` | broadcast Stream\<int\> | composer 成功 → port_tab `_onLocateSignal` | 定位+金框高亮新帖 |
| `kPortIslandFilterSignal` | ValueNotifier\<String\> | composer（**岛屿详情页入口**，跟随最终帖子岛标签）→ port_tab 切分类 | 值=**本地 Island.id**（cloudIslandToLocal 转换过），''=无操作 |
| `kPortFeedAlignSignal` | broadcast Stream\<String\> | composer（**底部发布入口**，固定落全部+最新）→ port_tab `_onFeedAlign` | 值=帖子主岛本地 id 或 ''（''=切全部+最新） |
| `appTabIndex` | ValueNotifier\<int\> | 底部 tab 双向同步单一向源 | 0岛屿/1港口/2闹市/3船长 |

两条分类信号**互相独立**（composer 按 `initialTags` 是否为空分流），改任何一边先读 port_tab.dart 的 `_onExternalFilter` / `_onFeedAlign`。

### EULA 重置链路（与 H5 doResetLocal 行为一致）
- 船长页「重置本地数据」确认后执行 `store.clearAll()` + **`await Prefs.clearAll()`**（清 data/used_names/**eula** 三键）
- 只清 DataStore 不清 Prefs 的话，重置后点「发布」不会再弹 EULA —— 这是已修过的 bug，别退化
- EULA 逻辑：点发布 → `Prefs.isEulaAccepted()` 为 false → 弹协议 → 同意后才进发帖页

### `lib/widgets/comment_section.dart`（v2.9.7 评论区组件，改评论逻辑前必读）
- 一级评论列表 + `_ReplyThread`（每条一级评论的子回复线程：list/total/expanded/loading）
- **预热**：一级评论加载后并发拉前 2 条子回复（折叠展示）；展开按钮「查看余下 X 条回复」X=total−2；展开 size50 去重合并；`expanded && loadedAll` → 「收起回复」（⚠️ 外层渲染条件含 `t.total > 2` 分支，漏了会导致收起按钮消失——已修过的 bug）
- 长按 500ms → 复制/删除评论（权限=本人∥帖主∥父一级评论作者，二次确认）
- 点赞防抖 `_likeBusy`；`insertComment/insertReply` 发送后实时插入 + `Scrollable.ensureVisible` 定位
- 回复关系排版（抖音对齐）：头部「A昵称 ↩ B昵称」纤细箭头标签（Icons.reply 翻转），**头部昵称点击跳主页、正文不渲染系统 @前缀**（`_stripReplyPrefix` 剥离历史预填数据）；用户手敲 @ 高亮纯样式无点击
- 输入框预置 @：detail 页 `_replyPrefix`（灰色 prefix Widget，内部不可编辑，空文本退格整体删除——`_commentFocus.onKeyEvent`）；发送 content 只含用户输入，关系由 replyToCommentId 表达

### 全局信号补充（v2.9.7，cloud_feed.dart）
| 信号 | 方向 | 说明 |
|---|---|---|
| `kPostDeletedSignal` | 详情删帖 → captain_tab 重拉列表 | 港口流本地移除走 `loader.removePostById` |
| `kCommentCountChangedSignal` | 详情发/删评论 → captain_tab 重拉 | 船长页评论计数与详情/港口对齐 |
| 详情页 `_onReplyTap` | 💬 → 输入框预置 @置灰前缀 | 见上 comment_section 条目 |

### @ 提及体系（v2.9.9，改 @ 相关逻辑前必读）
- **渲染**：`MentionText`（widgets/mention_text.dart）——正则 `@[\w\u4e00-\u9fa5·\-]{1,20}`、sky 蓝高亮、点击「`GET /api/users/search` 昵称精确匹配 → 跳 UserProfilePage」；已接入港口卡片正文 + 帖子详情正文；**评论区渲染是独立实现，勿往 MentionText 合**；**点 @ 跳主页是游客可读权限（v2.9.9 热修）：前端两处（MentionText/comment_section）登录拦截已删、后端 users/search 改 optionalAuth——未登录点 @ 直接跳主页不弹 toast**；搜不到 → 「未找到该船员」
- **输入唤起**：`AtUserPicker`（widgets/at_user_picker.dart）——发帖页 composer 与详情页评论/楼中楼共用；触发=光标前紧邻单独 @/＠（onChanged 监听 + `_lastTextLength` 判增删）；选中插入 `@昵称␣` 光标后置
- **焦点取舍（实测定版）**：搜索框 `autofocus: true`（弹窗弹出光标即进搜索框，直接打字）——代价是主输入框删字检测在弹窗打开期间不触发，「删 @ 自动收起」由**搜索框空文本退格关弹窗**兜底（Focus.onKeyEvent）；关闭/选中后 refocus 主输入框（composer `_focusNode` / detail `_commentFocus`），键盘不收可续打
- **去重**：AtUserPicker 结果按 `userId` 去重（`seen.add(u.userId)`）；后端 users/search 已排除 founder 系统账号（uid=1 与 uid=12 同名「大蓝海创始人」曾致列表重复）
- composer 不记 atUserIds（`POST /api/posts` 无该参数），详情页评论才传

### `lib/theme/colors.dart`
- 12 个渐变 + 20+ 颜色
- 添加新颜色时**保持 const**（避免 .withValues() 在 const 上下文报错）
- 想用半透明颜色时定义独立常量（如 `goldHalf = Color(0x80E8B84A)`），不要在 const 里调 `.withValues()`

### `../copyright-materials/` 软著生成脚本
- `gen_program_pdf.py`：读 lib/*.dart 按模块顺序拼接 → 折行 → 前 30+后 30 页，每页 50 行。改代码后重跑即可更新
- `gen_manual_pdf.py`：MARKDOWN 文本 + FIGURES 锚点系统（按章节标题插入图）+ TIPS/QUICKREF 两内容池迭代填充短页。改图或文字后重跑
- `gen_login_mockups.py`：4 张登录页配图——严格按 `lib/pages/auth_page.dart` + `lib/theme/theme.dart` 真实渲染绘制，状态栏用真机截图裁切（`_statusbar_strip.png`）贴入

---

## 7. Flutter 调试关键经验（踩过的坑）

### 🚨 Stack 尺寸规则：必须有一个 non-positioned child

```dart
// ❌ 错误：全 Positioned.fill → Stack 变成 0×0，整个内容消失
Stack(children: [
  Positioned.fill(child: ...),
  Positioned.fill(child: ...),
  Positioned.fill(child: ...),  // 全部 0×0，banner 消失
])

// ✅ 正确：内容层用普通 child 决定尺寸
Stack(children: [
  Positioned.fill(child: DecoratedBox(...)),  // 装饰层
  Padding(child: Column(...)),  // ← non-positioned，决定 Stack 尺寸
  Positioned.fill(child: ...),  // 其他装饰
])
```

### 🚨 emoji 颜色控制：`TextStyle.color` 对 emoji 无效

```dart
// ❌ 错：emoji 仍显示默认彩色
Text(emoji, style: TextStyle(color: Colors.transparent))

// ✅ 对：用 ColorFiltered 矩阵去饱和度 + Opacity
ColorFiltered(
  colorFilter: ColorFilter.matrix([...去饱和度矩阵...]),
  child: Opacity(opacity: 0.75, child: Text(emoji)),
)
```

### 🚨 ClipRect 会裁剪溢出子 widget

发布按钮如果放在 ClipRect 内部，凸出到 Container 顶部之上的部分会被裁剪。**解决方法**：把要凸出的元素放在 ClipRect 外面独立 Stack 节点。

### 🚨 Scaffold 默认 backgroundColor 是 Material 黑色

如果 IndexedStack 的某个 Tab 没填满整个区域，会露出 Scaffold 默认的 `#121212` 黑色背景。**解决**：显式设置 `Scaffold(backgroundColor: AppColors.abyss)`。

### 🚨 pubspec 中 icon 路径

`flutter_launcher_icons` 配置的 `image_path` 必须是 PNG，源图放 `assets/images/icon.png`。改图标后重新跑 `dart run flutter_launcher_icons`。

### 🚨 GestureDetector 点击无反应（hit test 穿透）

在 `Stack > Positioned` + 兄弟节点有 `BackdropFilter` 的组合下，`GestureDetector` 不设 `behavior` 时点击区域可能被下层吞掉。**解决**：`GestureDetector(behavior: HitTestBehavior.opaque, ...)`，且按钮 Column 用 `mainAxisSize: MainAxisSize.min`。

### 🚨 底栏 tabbar 渐变必须不透明

半透明渐变（如 abyss@70%→95%）会在 home indicator 区域透出底层黑色，造成「底部颜色断层」。**解决**：tabbarGradient 用不透明端点（abyss@80%→abyss@100%）。

### 🚨 软著文档 PDF 分页（reportlab）单位统一

`gen_manual_pdf.py` 的分页计数**必须用"行槽"整数单位**，不能 pt 与行数混用——否则 `state["h"] += SLOT`（每行加 20pt）会早早触发 `h >= CAPACITY`（35），导致每页只有 2 行。全部用行槽：`_h[0] += 1`（文字）/`_h[0] += FIG_SLOTS`（图），`CAPACITY = 35`。

### 🚨 PDF 生成中的列表引用陷阱

`pages.append(cur_page)` 后**不能 `cur_page.clear()`**——pages 里存的是同一列表对象的引用，clear 会把已入队的页清空。必须 `pages.append(list(cur_page))` 拷贝再 clear。

### 🚨 reportlab 绘图：Cinzel 字体无中文字形

`assets/fonts/Cinzel-Variable.ttf` 是纯拉丁字体，渲染中文会显示成方块（tofu）。Flutter 实际运行时会自动降级到系统字体，但 reportlab/PIL 不会——**手绘或 PDF 里混排中文时，中文部分用 SimHei 系统字体**（如按钮文字），Cinzel 只用于纯拉丁品牌词（GRAND BLUE）。

### 🚨 短文字页填充策略

含图手册里图前后页容易只排十几行文字（<30 行违规）。**不能跨章节拉文字填页**（会破坏图文对应顺序，审核员会看出图跑位）。解决：迭代算法找出短页→在断点处插入真实"提示"（≤5 条/页）+"功能速查"行→重排→收敛到全部 ≥30 行。

### 🚨 岛屿 key 两套命名空间（v2.9.4 实锤，跨 UI/后端必转）

UI 岛屿 chip id 用**本地 Island.id**（`qingxin/jieyan/jianshen/zaoshui`），composer/后端用**枚举 key**（`clear-mind/quit-smoke/fitness/early-sleep`）。直接把后端 key 发给 port_tab 的分类信号：chip 永不亮（`filterId == id` 不匹配）+ `kCloudIslandKeys` 查不到回落 `'all'`。**转换用 `cloudIslandToLocal(key)`（cloud_models.dart），别造轮子**。

### 🚨 ValueNotifier 同值不通知（tab 切换/信号类）

`appTabIndex.value = 1` 连续两次赋同值，第二次不触发 listener。底部发布入口的对齐信号因此用 **broadcast Stream**（`kPortFeedAlignSignal`）。状态双写（setState + ValueNotifier）也会脱钩 —— **单一向源**：tab 状态只走 `appTabIndex.value`，listener 统一 setState。

### 🚨 异步刷新响应乱序（列表数据竞态）

`CloudFeedLoader.refresh` 无并发防护时，40 秒前发出的旧筛选慢请求迟到完成会把新列表整体覆盖（日志打印的 `island=all` 是当前字段值，掩盖响应归属）。已加**代际守卫 `_gen`**：refresh 响应回来若代际已过期直接丢弃，loadMore 期间发生过刷新不追加。改刷新逻辑时别删 `_gen` 判断。

### 🚨 GlobalKey.currentContext 定位是死路（惰性 build）

SliverList 惰性 build 下，刷新重建后新帖的 GlobalKey 根本没进 map（offset=0、卡片可见、keys 数不增），`currentContext` 恒 null，逐帧重试无效。**新帖定位正确做法**：最新流 idx==0 直接 `feedCtrl.animateTo(0)` + 高亮走 itemBuilder 的 `postId == highlightPostId` 比较，完全不依赖 ctx。另外定位 pending 未匹配（首次刷新响应还没含新帖）时**保留 pending 重试 3 次×700ms** 再放弃，别一次未匹配就消费掉。

### 🚨 adb/工具链自动化坑（模拟器 E2E）

- `adb shell input text` 空格必须 `%s`（裸空格整条静默丢弃）；中文走 Gboard 拼音候选逐词上屏（点候选前先截图确认字与坐标，**点候选会撤销整个 composing 拼音串**；生僻字翻不到直接改 DB 更省）
- `adb emu clipboard set` 不可用；ViewImage 工具按内容去重（相同画面返回 unchanged 提示），验证「画面无变化」用 `md5sum` 对比 adb 截屏 PNG
- uiautomator dump 偶发空输出；Flutter 页面坐标定位用截图换算（**截图 px → 物理坐标按屏幕比例换算**，如 1080x2400 屏上 486x1080 截图坐标 ×2.222）
- flutter run 会话被 force-stop 带崩 exit 1 属预期；flutter 日志可 `adb logcat -d -s flutter` 抓（不占用 run 会话）
- **非交互 flutter run 会挂**：后台跑 `flutter run`（无 stdin）会 "Lost connection to device"；要独立运行 App 用 `flutter build apk --debug` + `adb install -r` + `adb shell am start -n com.kaitengguan.dalanhai/.MainActivity`
- 同名 AVD 不能双开（FATAL Running multiple emulators with the same AVD）；`adb shell` 里的路径在 Git Bash 会被 MSYS 转换 → 包 `MSYS_NO_PATHCONV=1` 或整条命令加引号
- **release 包 adb 点击命中率极低（2026-11-11 实锤 ~1/6）**：`input tap`/`input swipe 零距离`/`motionevent DOWN+UP` 在 release 构建上同一按钮多次点击被吞（同屏无 AnimatedBuilder 的按钮正常）——先怀疑注入而非代码，换坐标/方式重试或临时 `debugPrint` 构建 **debug 包**（`flutter run` attach 失败无妨，APK 已装，`adb logcat -d | grep flutter` 直接抓输出）定位「onTap 是否触发」，验完移除打印重建 release；中文 IME 下 `input text` 会把字母/数字转成候选字（e→哦 2→2），自测文本用无意义短串即可
- flutter run 附加被本机代理拦（WebSocket upgrade 失败）不影响 debug 包已装运行——**不需要 attach 也能拿日志**；生产部署 SSH：阿里云安全组加白开发机公网 IP（112.10.221.79 这类动态 IP 用完删规则）后可直接 `ssh/scp root@8.210.145.212`，沙箱内可能拦 22 出站需沙箱外执行

### 🚨 本机代理会劫持 localhost（curl/flutter test 全中招）

环境变量 `http_proxy=127.0.0.1:59838`（WorkBuddy 动态端口）会把 curl 到 127.0.0.1/localhost 的请求全部劫持（os error 10061），flutter test 的 WebSocket（flutter_tester 连接）同样被劫持直接失败。**解决**：跑任何本地 curl/test 前先 `export no_proxy='127.0.0.1,localhost' NO_PROXY='127.0.0.1,localhost'`。

### 🚨 flutter_test fakeAsync 无法驱动 dart:io 真实 IO

widget 测试里 `http.get` 真实请求永远不会完成（fakeAsync 冻结事件循环，runAsync 轮询也救不了）——**官方解法是注入 HttpClient 实现**。本项目方案：`CloudApi.instance.httpClientOverride = MockClient(...)`（package:http/testing.dart），fakeAsync 下全同步可 pumpAndSettle。两个坑：①MockClient 返回含中文的 body 必须 `http.Response.bytes(utf8.encode(...), 200, headers: charset=utf-8)`——默认 latin1 编码对中文直接 ArgumentError；②测试完 `tearDown` 清 override + configure(baseUrl: '')，**下个测试必须重新 configure 否则 isConfigured=false 静默抛"云端服务未配置"**。

### 🚨 testWidgets 里 dependOnInherited 必须在首帧后

`initState` 里调 `DataStoreProvider.of(context)` 会 assert 崩。**解决**：`didChangeDependencies` 中订阅（配合 `_boundStore` 判重防重复注册），或 `addPostFrameCallback`。另外 IndexedStack 常驻的 Tab 页（船长页统计/日志）**不会因切 Tab 重建**——需要响应全局状态（打卡/登录/登出）就必须主动 addListener 订阅 ChangeNotifier，别指望 initState 一次性拉取。

### 🚨 hero 卡片横排双按钮溢出（1080 宽屏实锤）

船长页 hero「编辑资料+账号设置」横排 Row 固定宽，昵称 Expanded 挤压不足时整体溢出 45px（Flutter 渲染红条 RIGHT OVERFLOWED BY 45 PIXELS）。**终版解法：竖向右对齐堆叠**（Column + crossAxisAlignment.end，上高频下低频），竖排宽度只占一个按钮天然无溢出。

### 🚨 本地构建缓存已迁 D 盘（C 盘清理后新格局）

`GRADLE_USER_HOME=D:\FlutterCache\Gradle`、`PUB_CACHE=D:\FlutterCache\PubCache`（用户级环境变量）——C 盘 `~/.gradle`、`AppData\Local\Pub\Cache` 均为**废弃目录**（2026-11-10 已删）。Gradle wrapper 已切 `gradle-9.1.0-bin.zip`（腾讯镜像）。命令行跑 gradlew 需 `JAVA_HOME=E:\Program\Android\Androidstudio\jbr`（Android Studio 自带 JBR）；pub 拉包国内镜像偶发 "package not available" → 切 `PUB_HOSTED_URL=https://pub.dev` + 代理。

### 🚨 main/AndroidManifest.xml 缺 INTERNET 权限（已修，勿回退）

Flutter 新模板只在 debug/profile manifest 给 INTERNET 权限——release 正式包会**完全无法联网**。v2.9.6 已在 main manifest 补 `<uses-permission android:name="android.permission.INTERNET"/>`，勿删。

### 🚨 本机 Flutter 配置：已开启 Windows 桌面编译支持

已执行 `flutter config --enable-windows-desktop`。目的：保留桌面端编译能力，后续如需开发 Windows 版本可直接调试打包。
风险提醒：如果误选中 Windows desktop 目标运行，会生成大量 CMake 编译中间文件占用 C 盘。
约束规则：**所有自动化自测命令固定指定 `-d emulator-5554`**，强制走 Pixel7 模拟器，不自动选择 Windows 桌面。
后续如需关闭桌面端，执行命令：`flutter config --no-enable-windows-desktop`。

补充说明——开启 Windows 桌面编译仅在以下场景需要：① 开发、调试 Windows 桌面端版本，本地直接运行 exe；② CI 打包产出 Windows 安装包。本项目现阶段只维护 Android / iOS 移动端，无桌面端计划，日常开发固定使用 Pixel7 模拟器。

### 🚨 adb 自动化 E2E 补充坑（2026-11-15 实锤）

1. **`adb input text` 会被拼音 IME composing 污染**：Gboard 中文模式下注入 `g773831275@gmail.com` 实际上屏「给773831275@Gmail。」——字母 g 组词成汉字「给」、`.` 转中文句号「。」（这正是线上邮箱误拦 bug 的真实用户场景）。对策：输入前先切英文（点键盘「拼音」键会 commit composing，点地球键切英文模式；composing 状态下退格 keyevent 67 无效，先 commit 再删）；或用 `input keyevent 66`（Enter）前先 commit composing，否则 Enter 只确认候选词不触发 onSubmitted。
2. **release 包按钮点击命中率不稳定**：GestureDetector 包小文本链接（如「忘记密码？」）adb tap 几十次全部 miss；BackdropFilter/键盘遮挡下的发送按钮同理。对策：能 URL 化的交互用 curl 直测接口 + 气泡/列表渲染截图佐证；大块 Material 按钮（ElevatedButton/InkWell 卡片）命中率高；「冷启动后前几秒点击窗口期」规律——重要导航序列在启动后立即连续执行。
3. **App 重启会恢复 Activity 页面栈**（install -r 不清数据）：截图前先 `screencap` 确认当前页面，别假设在首页；导航前用 md5 对比截图判断点击是否生效。
4. **HTTP 401 统一文案会吞业务 msg**（已修）：`cloud_api._request` 对 401 状态码曾直接 throw 固定文案「登录已失效，请重新登录」，导致密码登录「账号或密码错误」「账号不存在」「该账号未设置密码」全被遮蔽。已改为优先透传 body.msg（解析失败回退默认）。新增接口时后端 401 业务语义可直接依赖此透传。
5. **IndexedStack 常驻 Tab 的登录态数据刷新**：Tab 页 initState 只在 App 冷启动跑一次，登录/登出必须经 DataStore listener 重拉**所有**登录态数据（统计+列表），只重拉一部分会出现「统计对了、列表还是登出前的空数据」。
6. **后端同名业务双路由陷阱**：点赞同时存在 `/api/post/:postId/like`（Flutter 现用）与 `/api/posts/:postId/like`（旧）——埋点/改逻辑必须两条路由都改，或先确认 Flutter 端 `cloud_api.dart` 实际调用哪条。
7. **评论区跨页定位**：`CommentSectionState.scrollToComment` 必须先等 `loadFirst` 完成（`_loading` 期间 `loadMore` 会被 guard 直接 return，循环空转 10 次瞬间结束定位失败）；子评论定位需展开其根评论线程（`_itemKeys` 只挂一级评论块）。

### 🚨 adb 自动化 E2E 补充坑（2026-11-16/17 实锤）

1. **adb tap「无响应」九成是坐标差几像素**：底部输入条 tap y=2185 无反应（EditText 真实 bounds `[39,2187][856,2308]`，差 2px miss）——**先 `uiautomator dump` 拿真实 bounds 再点**，别靠截图目测坐标反复试；键盘弹出后输入条被顶起，发送按钮坐标必须重新 dump（实测从 y≈2188 变 y≈1409）
2. **数字键盘污染输入**：身份校验输入 `12` 实际上屏 `012`（number 键盘 composing 残留），先验证不匹配拦截路径反而是意外收获；重输前先连发 keyevent 67（退格）清空
3. **本地 node 服务随 shell 退出被杀**：`(node index.js &)` 子 shell 后台化在 Git Bash 会话结束即死，curl 全部 connection refused——**必须用后台任务机制启动**（run_in_background），且重启后确认监听端口（本地 3100/生产 3000 不同）
4. **node -e 直接 require 后端模块不会自动加载 .env**：`JWT_SECRET` 为空 → issueTokens 签出的 token 服务端验签必败；自测脚本须手动 parse `.env` 注入 process.env
5. **本地验证码双重坑**：①生产 .env 配了真实阿里云短信，本地起服务会真发短信且 13800138000 假号码触发天级流控——本地自测用 `SMS_ACCESS_KEY_ID= SMS_ACCESS_KEY_SECRET=` 空值启动走日志兜底；②日志兜底的验证码也被打码 → 直接读本地库 `verify_codes` 表拿码；③login/sms 本地通道「发 login 码→自动建号」，与生产 register 通道口径不同，自测脚本要按通道适配
6. **短信风控会让 E2E 注册测试卡死**：60s 冷却 + 天级上限层层触发，连续跑注册类自测脚本前先想清楚号码池/冷却，或直接用库内现有账号签 token（绕开短信链路）
7. **md5 对比截图是验证「无响应」的利器**：@提及静默/作者点击无响应这类「什么都不该发生」的验收，md5 对比点击前后截图 + ViewImage 双重确认，比肉眼比对可靠
8. **（2026-11-18）登录页表单 adb 自动化可行**：扬帆登船页数字输入（手机号/验证码）`input text` 正常注入 —— 先勾 EULA 复选框、逐框 tap 聚焦再输入即可；群聊输入框注不进是个例，别一概而论
9. **（2026-11-18）目检陷阱：帖子图片内容 ≠ 真实 UI**：历史截图（如「需要登船」弹窗图）作为帖子附件渲染时，极易误读为真实弹窗/页面状态 —— 目检时以**底部 tab 高亮 + 状态栏时间**判断真实页面，图片区域先确认所属帖子卡片边界

### 🚨 账号数据隔离坑（2026-11-17 实锤，v2.9.11 注销验收暴露）

1. **本地存档 dalanhai_v2 是设备级单份，不分账号**：DataStore 里 checkins（21 天窗口）/cloudTotals/cloudStreaks/cloudMaxStreaks/certificates 全是设备级——换账号登录会直接读到上一账号的打卡镜像残留。**改账号相关逻辑前必读**：`resetCheckinMirror()` 已在 login()/logout()/冷启动恢复登录态（main.dart fetchMe 分支）三处调用；新增任何账号维度数据必须走同样的会话边界重置
2. **冷启动恢复登录态不走 auth_page 的 login()**：main.dart `fetchMe` 成功后仅 updateCaptain/updateAvatar，昵称相同则不触发 login() → 只在 auth_page 挂镜像重置**漏掉冷启动场景**（注销验收时「已征服 10 次」残留就是这么漏的）；会话边界初始化必须三处对齐：login()/logout()/main.dart 冷启动
3. **better-sqlite3 数字绑定陷阱**：注销事务里 `account` 改名用 JS 数字拼字符串出现 `closed#12.0#`（number 类型 `.0` 尾巴）——拼 uid 前先 `String(parseInt(uid))`；无功能影响但日志/排查看着别扭
4. **IndexedStack 常驻 Tab 的登出红 toast**：注销/登出回首页时常驻页仍会重拉一次数据弹「未登录，缺少 token」红 toast（登出既有伴随现象，非注销引入）——做登录态相关验收时别误判为新 bug；根治方向=DataStore 登出信号统一闸门（§7 前一节第 5 条同源）

### 🚨 调试/验证坑（2026-11-18 实锤，v2.9.12 冲刺）

1. **debugPrint 在 release 包照常输出**：不被 tree-shake（`[feed-refresh]`/`[oss-direct]` 曾进 release logcat）——凡要「release 静默」的日志必须显式 `if (kReleaseMode) return;` 守卫（_ossDebug 已修，[feed-refresh] 等待统一处理）
2. **模拟器同一 AVD 不可双开**：`emulator -avd Pixel_7` 报 `FATAL: Running multiple emulators with the same AVD` 时，先查 `adb devices` 是否已有 `emulator-5554` 在线，直接复用
3. **curl(schannel) 报 CRYPT_E_REVOCATION_OFFLINE**：本机代理环境下证书吊销检查被挡的误报（服务器证书正常），加 `--ssl-no-revoke` 重试即可，别误判为证书配置问题
4. **flutter_test 里 `Prefs._instance` 跨 setMockInitialValues 串扰**：SharedPreferences 实例被静态缓存，setUp 里 reset mock 后旧实例读写可能落到旧 store —— 断言读写统一走 `Prefs.loadData()` 同一实例路径（regression_fixes_test.dart 有注释）
5. **uiautomator dump 看不到 Flutter 节点**（未开 semantics）：只有系统 UI（photo picker 等）可 dump；Flutter 页面坐标定位靠截图目测 + 换算（截图 540 宽 = 真机 1080，坐标 ×2）
6. **adb input text 注不进 Flutter TextField**：焦点注入在群聊输入框两次失败（photo picker 可用）；遇到 UI 自动化卡点先评估收益，改用 curl 直调 API 或等效路径（pm clear ≈ 登出态），别死磕
7. **Android Studio Run 会话会抢占模拟器**：IDE 部署（logcat `installPackageLI`）会 force-stop + 重装覆盖 adb 手动装的包 —— adb 装包验证期间若出现异常白屏/重启，先查 logcat 是否被 IDE 重装打断
8. **相册 Recent 排序按媒体库时间**：adb push 的图保留源文件 mtime（可能排到很后面）；`touch -m` 改时间 + `content call --method scan_file` 重扫，或直接选列表里的既有截图（验证上传链路等效）
9. **（2026-11-18）ViewImage 展示的是缩略图，坐标换算是大坑**：截图文件实际 1080x2400，ViewImage 呈现 485x1080 缩略 —— 目测缩略坐标 ×2.2268 换算极易偏（EULA「同意并继续」真实 y≈1778 而非目测 1420；auth 页 tab 行 y=741 而非 679）。**程序化定位代替目测**：`dart run tools/find_btn.dart <截图>` 输出金色按钮包围盒+中心坐标；点击无反应先怀疑坐标而非代码
10. **（2026-11-18）键盘遮挡按钮**：input text 后软键盘占下半屏，底部按钮（扬帆登船等）被盖 → 先 `input keyevent KEYCODE_BACK` 收键盘再点（**单次 BACK**，双击 = 收键盘+退 App）
11. **（2026-11-18）登录页 BACK = 退出 App**：auth_page 是根路由页面，BACK 直接出桌面 —— 冷启动恢复（am start）等 15s+ 再操作；恢复后表单残留直接点按钮即可
12. **（2026-11-18）验证登出/匿名态必须 pm clear**：IndexedStack 常驻 tab 登出后残留登录态数据（船长日志仍显示），UI 登出不彻底；pm clear 连带清 EULA 同意（每次重弹「航海守则」）+ 图片缓存 —— 这才是真状态

### 🚨 ESA 图片链路与跨境坑（2026-11-18 深夜实锤，图片渲染必读）

1. **ESA 私有访问模式 = URL 不能带签名参数**（阿里云工单结论）：ESA 站点开启 OSS 私有 Bucket 自动回源鉴权后，ESA 节点内部自行签名回源；URL 再带 OSSAccessKeyId/Expires/Signature 会双重鉴权冲突 → **随机 400/SSL 重置/断连**（curl 矩阵实锤：同 URL 无 query 200、带 query 000 秒断）。渲染 URL 必须剥离全部 query —— `_mapRenderUrl` 已实现（Uri 重建，勿用 `replace(query:'')` 会留尾随 `?`）
2. **鉴权边界正确形态**：经 ESA 域名无签名 = 200（ESA 自动鉴权）；**直连 OSS 原始域名无签名 = 403（防盗链生效）** —— 验收时 403 不是坏事，是边界正确
3. **「列表图正常」是缓存假象**：签名 URL 900s 有效 + Flutter ImageCache 命中 → 旧截图里图片正常 ≠ 链路正常；**pm clear 后冷启动才见真状态**（24 轮复测 24/24 占位就是这么漏判的）
4. **概率性故障用像素方差批量判定**：`dart run tools/analyze_shots.dart <png...>` 采样首帖图片区域方差（占位≈225 / 真图≈645，阈值 400）—— 多轮 chips 切换（tap 107,416）驱动 feed 重载，每轮截图批量判，比逐张目检可靠且快
5. **边缘节点质量参差是常态风险**：8 节点中出现过 2 个 TCP 死、多数 TLS 秒断、可用节点回源 9-12s；DNS 轮询命中坏节点 = 概率性失败 —— 疑似节点问题先 `--resolve` 逐 IP 强制测，别被平均值骗
6. **跨境链路系统性问题（境内 ↔ 香港 OSS）**：ESA 国内边缘回源香港 9-12s 慢、Green 内容审核境内下载香港图片 404 —— 同一根因，两处表现。**Green 侧已修（2026-11-19）**：送审 imageUrl 改 ESA 无签名直链（ESA 自动鉴权回源）+ 下载重试 ≤2 次/12s 超时（`moderation.js` `IMAGE_TIMEOUT_MS`/`IMAGE_RETRY_MAX` 可调），实战兜住偶发 404；根治仍 = bucket 迁国内或审核切香港 region（若重试也持续失败再启动）
7. **模拟器偶发断网**：状态栏 3G 图标 + ping 100% 丢包 + feed-refresh n=0 → App 全部请求失败（别误判为 App bug）；`cmd connectivity airplane-mode enable/disable` 开关一轮即恢复
8. **发帖带图生产链路（已修 2026-11-19）**：上传 PUT 走 OSS 原始域名、送审走 ESA 无签名直链 + 重试 —— 排障先查服务端日志（pm2 logs grandblue / `~/.pm2/logs/grandblue-error.log`，重试日志格式「图片审核第 N/3 次尝试失败」）而非 App 端

### 🚨 .env 覆盖代码默认值的部署陷阱（2026-11-19 实锤，改配置类代码必读）

**改任何「env 可调」的默认值前，先查生产 .env 是否有同名变量** —— env 优先于代码默认值，只改代码 = 改动静默失效。实锤案例：多图 429 修复把 `UPLOAD_IMAGE_LIMIT_USER_PER_MIN` 默认 5→20 并部署，但生产 .env 残留 `=5` → 线上仍是 5（429 继续发生），curl 实测响应「上限 5 张」才暴露 → sed 修 .env + restart 才真正生效。**部署检查清单**：①改默认值的变量 → grep 生产 .env；②部署后 curl 实测行为（响应里的数值/文案）；③pm2 restart 后 `pm2 list` 确认 pid 变化。

### 🚨 限流体系与上传失败分类（2026-11-19 实锤，排障必读）

1. **三层限流独立计数**（互不影响，排障先定位层）：
   - `policyLimiter`（60/min/IP）挂 policy/put-sign —— express-rate-limit 非 JSON 429
   - `checkUploadGate`（risk.js 用户维度，图片 20/min 可 env 调、视频 1/min）—— JSON 429「图片上传过于频繁（单用户每分钟上限 N 张）」
   - `postsLimiter`（10/min/IP）挂 POST /api/posts（2026-11-19 新增）+ signBurstLimiter（300/min/IP）挂 media/sign
   - **_request 统一改写 429 文案**为「操作过于频繁，请稍后再试」（丢失服务端原始 msg，但 statusCode 保留）—— App 端分类只能靠 message 模式 + http 状态
2. **App 端 ImageUploadFailure 分类**（cloud_api.dart `_classifyImageFailure` + composer `_logUploadFailure`）：`[upload-fail] uid=.. failType=.. stage=put_sign/put_oss http=.. msg=.. putSignAt=.. putStartAt=.. file={size,ext,fp}` —— failType 判定：`risk_limit`（msg 含「操作过于频繁」）/ `ip_freq_waf`（msg 含「服务响应异常（HTTP 429/403」= 非 JSON 层）/ `file_validate`（「不支持的图片格式」「超过大小上限」或 OSS XML EntityTooLarge/InvalidArgument）/ `sign_invalid`（OSS XML SignatureDoesNotMatch/AccessDenied）/ `timeout` / `network` / `auth_expired`（401）
3. **实测触发方法**：risk_limit = 并发 21 curl put-sign 打满用户配额 → App 立即选图（滚动窗口 60s，慢速串行 curl 早期请求会滚出窗口测不准）；network = 飞行模式选图；file_validate 形态 = curl put-sign `ext=exe` →「不支持的图片格式（exe）」；sign 形态 = 伪造 Authorization PUT → OSS XML（RequestTimeTooSkewed）
4. **ICMP ping 在模拟器 NAT 恒 100% loss**（误判断网）—— 断网判定改看 logcat `feed-refresh` 是否 n=0 或 App 请求是否 SocketException；真断网恢复用 `cmd connectivity airplane-mode enable/disable` 开关一轮
5. **composer 预上传架构（v2.9.13）**：选图即入串行泵 `_pumpUploads`（一张成功再下一张、泵运行中新增图自动接力、失败槽回收+中止），`_keys` 槽位对齐 `_images`；发布按钮 `busy: _submitting || _uploading`，文案三态「上传中 x/N / 图片审核加载中，请耐心等待（带图帖）/ 发布中…」—— 改 composer 相关逻辑先读这套状态机
6. **测试垃圾帖清理**：创始人删帖 `DELETE /api/posts/:postId`（**复数**；单数 `/api/post/:id` 404）；rate-limit probe 之类压测帖记得删，别污染 feed

### 🚨 tobias 5.3.4 consumer proguard 与 AGP 9 不兼容（2026-11-22 实锤，pub cache 修复后必看）

1. **现象**：接入 tobias 后 `flutter build apk` 报 `:tobias:mergeDebugConsumerProguardFiles > Global keep option -dontshrink was specified as a consumerProguardFile... should not be used in a consumer configuration file` —— 本项目 AGP 9.0.1 严禁插件 consumer 配置携带全局 proguard 指令（`-dontshrink`/`-dontoptimize`/`-dontpreverify`/`-flattenpackagehierarchy`/`-allowaccessmodification`/`-printmapping`/`-renamesourcefileattribute`/`-optimizationpasses`/`-verbose`/`-dontusemixedcaseclassnames`/`-dontskipnonpublic*`/`-ignorewarnings`）
2. **已采用的修复**：直接注释 pub cache 文件 `D:\FlutterCache\PubCache\hosted\pub.flutter-io.cn\tobias-5.3.4\android\consumer-proguard-rules.txt` 里的全局指令（keep 类规则保留）。⚠️ **`flutter pub cache repair` / 删 cache 重装后该文件回退、构建再挂** —— 报错时回来重新注释即可
3. **无效方案勿再试**：根 build.gradle.kts 里 `afterEvaluate` 清空 tobias 的 `consumerProguardFiles`（AGP 9 在 task 创建时锁定 inputs，DSL 改动不生效）。支付宝 SDK keep 规则已放 `android/app/proguard-rules.pro`（当前 release 未开 minify 无实际作用，开 R8 时兜底）
4. **版本升级注意**：tobias 6.0.0 修复面未知但要求 Dart ≥3.13（本项目 3.12.2 装不上）；升级 Flutter/AGP 时同步验证 tobias 构建兼容

---

## 8. 常用命令

```bash
# 安装依赖
flutter pub get

# 运行（Android 模拟器或真机）
flutter run

# 测试
flutter test
# 回归专项（v2.9.12：防抖写盘/签名分批/postId 防御/CDN 域名映射断言）
flutter test test/regression_fixes_test.dart

# 静态分析（修复 lint）
flutter analyze

# 生成双平台图标（改完 icon.png 后跑这个）
dart run flutter_launcher_icons

# 构建 Android Debug APK
flutter build apk --debug

# ── Release 打包规范（2026-11-22 起，双平台产物分流见 §13.14）──────────
# 安卓 release：apk（集成 tobias 支付宝 SDK，安卓渠道专用）
flutter build apk --release
# iOS release：ipa（不引入 tobias，走苹果原生 IAP 内购，见 §13.14）
flutter build ipa --release

# 打包顺序建议：先打安卓 apk → 模拟器/真机验证 H5 兜底链路（2026-11-22 已验证）
# → 再打 iOS ipa（IAP 商品配置 + 内购流程后续单独开发）
# 双平台同一套 Flutter 代码，靠平台分支自动分流（Android 走 tobias / iOS 跳过支付宝），
# 打包互不冲突，无需改代码切换
```

---

## 9. H5 → Flutter 迁移备忘

| H5 概念 | Flutter 对应 |
|---|---|
| `:root` CSS 变量 | `AppColors` 常量 |
| `localStorage` 三个键 | `Prefs` 封装（dalanhai_v2 / used_names / eula） |
| `render()` 函数 + 单一 `currentView` 状态 | IndexedStack + StatefulWidget（每个 Tab 独立状态） |
| `<div onclick>` | `GestureDetector(onTap:)` |
| `<input type="file">` (HEIC 转换) | `image_picker.pickImage` + `image` 包压缩 |
| `<svg>` 图标 | `CustomPaint`（不引入 flutter_svg 依赖） |
| `filter:grayscale(.4)` | `ColorFiltered` 矩阵 + `Opacity` |
| `background-clip:text` | `ShaderMask` + `LinearGradient.createShader` |

---

## 10. 待办清单（接手时检查）

**最高优先（2026-11-09 新增）**
- [x] dalanhai-app/ 已 git init（2026-11-10，此后所有改动逐 commit 可回滚；v2.9.9/v2.9.10 共 10+ commit：6c41381 归一化 / 553ffdf+cde8b0f 找回密码 / 98879fd 列表刷新 / d09ea56 消息中心 / c837ace 群聊）；[ ] 本地 master 待 user push 远程
- [x] **首次 push 前安全加固（2026-11-23 完成）**：.gitignore 补齐 iOS（Pods//DerivedData//.p12/.certSigningRequest/.mobileprovision/GoogleService-Info.plist）+ Android（.gradle//全局 build//local.properties 含 keystore 口令引用）+ .env 系（含 grandblue-server 侧已忽略）；已审计 `git ls-files` 确认**零敏感文件被跟踪**（jks/key.properties/local.properties 均在忽略态）。⚠️ 铁律：密钥/证书一旦 push 即永久写进 git 历史，只能 force push 重写历史 + 全部作废重发——新增敏感类文件时先补 .gitignore 再生成
- [ ] Codemagic 出包后真机回归：①岛屿 tab 发帖落点/金框 ②头像上传裁剪+昵称改后头像保持 ③多图预览捏合/下滑关闭手感（iOS 手势重点）④他人主页/日志详情关注按钮/···菜单（iOS 底部弹窗适配）⑤船长页双 Tab 与统计联动
- [ ] 上线前拆临时埋点（`[composer-post]/[shell-tab]/[feed-locate]/[feed-highlight]/[port-filter]/[feed-refresh]`，均为 debugPrint release 静默，可留观一轮再拆）

**代码健康**
- [x] `flutter analyze` = No issues found（2026-11-10 复核）
- [x] 新增联动回归测试 test/captain_stats_sync_test.dart 2 用例全过（MockClient 注入）
- [ ] `flutter test` 中 test/widget_test.dart「Check-in works and updates streak」用例**已过时**（写于本地打卡时代，未适配云端登录闸门——游客点打卡弹登录引导而非直接打卡）——要么改写为云端 mock 版要么删除，非产品 bug
- [ ] 点「发布」是否先弹 EULA（首次）→ 同意 → 进发帖页（回归验证）
- [ ] 船长页「重置本地数据」后，点「发布」是否重新弹 EULA（回归验证）

**iOS 合规与 CI**
- [ ] iOS Info.plist 5 项合规是否在位（加密/全屏/竖屏/相机/相册）
- [ ] codemagic.yaml 是否可工作（实际跑一次 ios-release workflow）

**Apple 个人→组织迁移（最高优先）**
- [ ] 双重认证是否已开启（appleid.apple.com 确认）
- [ ] 域名购买（阿里云，公司实名）
- [ ] 公司官网制作（静态站点，可由我生成代码）
- [ ] 官网部署到杭州 ECS
- [ ] ICP 备案启动（企业备案：营业执照+域名+ECS，1~2 周）
- [ ] 网站公开可访问后回复 Apple（案例 103004430882）开始迁移
- [ ] 迁移期间避开 iOS 构建；迁移后验证 Codemagic 签名/Profile

**软著补正（材料已就绪，~11/20 截止）**
- [ ] 申请表软件全称「大蓝海移动应用软件」+ V1.0（原填的「大蓝海1.0」不合规）
- [ ] 申请表著作权人 = 杭州浩海星辰数字科技有限公司（与两份 PDF 一致）
- [ ] 申请表"软件主要功能"照手册 1.3 节 7 条填
- [ ] 申请表"源程序量"填约 5800 行
- [ ] 提交申请表 + 两份 PDF + 企业营业执照副本
- [ ] `../copyright-materials/` 两份 PDF 是否为最新（代码大改后重跑生成脚本）

**Android**
- [ ] key.properties 是否配置（生成 keystore 后填入）
- [ ] Google Play 开发者账号是否已注册

**后端**
- [x] 阿里云 ECS 公网 IP / 安全组就绪，pm2 部署完成（香港节点 8.210.145.212，/opt/grandblue，pm2: grandblue）
- [x] `GET /health` 健康检查接口已加入 index.js
- [x] v2.4 OSS 直传 + 内容安全审核（真实直传已验证，两桶均 204）
- [x] v2.5 短信防刷风控 + v2.5.1 流水清理 + v2.5.2 P1 三项（本地 117 PASS/0 FAIL）
- [x] 真实短信链路验证（notify.js 3 bug 已修，13125557972 收码闭环）
- [x] **P0 v2.6：机器审核增强版文本+图片审核（真机验证 Code=200）+ OSS 时效签名防爬**（2026-11-07）
- [x] **v2.6.1 媒体上传规范：policy 前置校验 + 上传频控（5图/1视频每分钟）+ 多图帖 attachUrls + 视频 duration 必填 + 违规帖 reject 留存 + OSS 7 天清理任务**（2026-11-07，本地 162 PASS/4 FAIL/3 SKIP；test.sh 须以 `DEV_MODE=1 MODERATION_MOCK=1 node index.js` 启动跑全量，json_get undefined 污染 bug 已修）
- [x] **香港桶 dalanhai-app-check 已改【私有读】**（2026-11-07 实测无签名直访 403 ✓）
- [x] **RAM 已给共用 AK 补齐 `oss:GetObject` + `oss:DeleteObject`**（2026-11-07 10:20 实测通过：`node test-ram-perms.js` 上传→签名URL→删除全链路 ✓；本地 test.sh **166 PASS / 0 FAIL / 3 SKIP 全绿**，4 红项转绿）
- [x] **服务器部署 v2.6.2（2026-11-08 完成）**：代码上线香港 /opt/grandblue + mock 回归 166 PASS/1 FAIL/2 SKIP（唯一 FAIL=163 SMTP 授权失效，与代码无关，同日已修复）；v2.3→v2.6 老 DB 升级崩溃已修（db.js 幂等迁移块 posts 补 4 审核列）；test-ram-perms 三项权限过；测试残留已清（终态 founder+2 原帖）；回滚锚点 /opt/grandblue_bak_20261108_pre_v262
- [x] **生产化三件套完成（2026-11-08）**：①SMTP 修复（163 新授权码，适配代码键名 SMTP_*，发码验证 channel:email ✓）；②测试数据清理（备份后删 12 帖+6 用户+71 流水）；③**api.idalanhai.com 上线**：DNS→8.210.145.212 ✓ + nginx（开机自启，80→301 HTTPS，443 反代 127.0.0.1:3000，X-Real-IP/X-Forwarded-For/X-Forwarded-Proto，限流 10r/s burst20+并发20，client_max_body_size 40m，HSTS，旧版 nginx 用 listen 443 ssl http2 语法）+ acme.sh Let's Encrypt 证书（ec-256，/etc/nginx/ssl/api.idalanhai.com.{crt,key}，~2027-02-05，cron 自动续期+reloadcmd）+ TRUST_PROXY=1；外网 https://api.idalanhai.com/health 200（SSL 验证通过，~165ms）
- [x] **基座安全闭环复测（2026-11-08 07:30，五项全过）**：①index.js 固化 `LISTEN_HOST=127.0.0.1`（env 可覆盖，本地+服务器双核对）；②`ss -tlnp` → 仅监听 127.0.0.1:3000；③外网直连 :3000 → 连接失败（无公网监听，双保险）；④HTTPS 业务链路 200；⑤TRUST_PROXY 端到端铁证——走 nginx 的请求 sms_send_log 记录真实公网 IP（对比本机直连记录 127.0.0.1），IP 透传风控生效。**【域名 + Nginx 443 反代 + TRUST_PROXY】三件套部署完成、风险闭环**
- [x] **v2.7 P0 港口流七接口部署（2026-11-08）**：index.js + src/db.js 上线香港节点（⚠️ scp src 子目录必须单独传），db.js 幂等迁移自动执行；服务器真实审核模式 test-p0-api.sh **62 PASS / 0 FAIL**（瀑布流筛选/详情/评论分页/点赞切换/拉黑隔离/举报入库/标签统计全过）；本地全量回归 166 PASS 零回归；测试残留已清（终态 founder+2 原帖）；DB 备份锚点 grandblue.db.bak_p0_20261108；自测脚本 `test-p0-api.sh`（62 用例 + CLEANUP=1 清理模式）；详见 ../grandblue-server/部署文档.md §18
- [x] **v2.9.4 多岛屿分发（2026-11-09 已上线）**：`post_island` 多对多表（PK(post_id,island_id) + ON DELETE CASCADE + 存量回填）+ `POST /api/posts` 收 `islands[]`（≤4 枚举强校验，缺省回落单值 island）+ 列表过滤改 `EXISTS OR island 兜底`；详见部署文档 §28
- [x] **v2.9.5 头像/昵称审核闭环（2026-11-09 已上线）**：`PATCH /api/user/nickname` 补 Green 文本审核（此前只校验长度直接落库，违规昵称可绕过）；`POST /api/user/profile` 头像分支 +OSS HEAD 二次校验（≤10MB + content-type 白名单，防直传绕过）+ Green 图片增强版审核（与 UGC 图片同函数）；头像存储=users.avatar 存 OSS 对象 key（私有桶），渲染走 media/sign 900s 时效签名；详见部署文档 §39
- [x] **v2.9.6 社交关系全套（2026-11-10 已上线生产）**：users 补 bio/sail_level、新表 user_follow/app_settings、reports.type 扩展 +user（重建表迁移）；接口：`POST /api/user/follow`（幂等 toggle，双向拉黑 403）、`GET /api/user/follow-status`、`GET /api/user/:uid/followers|following`（分页 + followedByViewer）、`GET /api/user/:uid/profile`（stats=posts/following/followers/totalCheckins/maxStreak + certificates 打卡数据派生 + showSailLevelTag 开关）、`GET /api/user/:uid/posts`、`GET /api/user/liked-posts`（自动剔除双向拉黑）、`POST /api/user/unblock`、`GET /api/user/blocklist`、`POST /api/admin/settings`（enable_sail_level_tag）、`POST /api/admin/user/sail-level`（手工赋航级文本，无计算逻辑）；`POST /api/user/block` 升级**双向清空关注关系**（clearedFollows）+ `isBlockedPair` 全站双向拦截（详情/点赞/评论/关注/主页一律 404/403 不泄露细节）；`POST /api/user/profile` 支持 bio（≤100 字送审）；`POST /api/report` type 扩展 user；自测 `test-social-api.sh` 42 PASS（独立测试库自启服务）+ 生产 verify-prod-v296.sh 21 项全过 + 全量回归 181 PASS；DB 备份锚点 grandblue.db.bak-20261110
- [ ] 生产部署遗留：1 条测试举报记录（type=user，prodv 测试账号所提）留在审核队列可忽略；测试账号 prodv_a/prodv_b_*@test.com（uid 19/20，无内容无关系）无需处理
- [ ] 香港 bucket 控制台配 CORS（App/浏览器直传需要）✅ 已定读取方式=私有桶+时效签名（不再考虑公共读/CDN）
- [x] 配置 GREEN_* 审核 AK（2026-11-07 与 OSS 共用一组 AK，green+oss 权限已真机验证）
- [x] **v2.9.9 密码找回全栈 + 消息中心（2026-11-15 已上线生产）**：发码 purpose=reset（不自动注册）、POST /api/password/reset（验证码核身、复用登录风控口径）、notifications 4 类互动通知（赞/评论赞/回复/@mention 埋点+聚合展示前端做）、私信会话/消息、Email reset 发码豁免 captcha（限流兜底）；详见 §11.4 v2.9.9 增量
- [x] **v2.9.10 群聊第一版（2026-11-15 已上线生产）**：groups/group_msg/user_group_unread 三表 + 6 固定群 seed + list/info/msg/read 四接口 + Green 线上审核 + 本地敏感词兜底双闸；Flutter 闹市群列表云端渲染（未读角标时间右侧）+ 乐观发送 + 上拉分页 + 10s 轮询；⚠️ 上线前清群聊测试数据 `DELETE FROM group_msg; UPDATE groups SET member_count=0;`
- [ ] ⚠️ 上线稳定后 RAM 轮换 OSS/SMS/GREEN AK（Secret 出现过在对话明文）；轮换时同时补 GetObject/DeleteObject 授权
- [x] **Flutter 对接生产 API 完成（2026-11-10）**：域名统一锁定 `https://api.idalanhai.com`（session_store.defaultBaseUrl 单点；裸 IP 不可路由——3000 仅监听 127.0.0.1、80→301 且 IP 证书校验失败）；设备端持久化旧 baseUrl 键自动清除；Pixel7 模拟器实测港口流/打卡/社交全链路走线上
- [x] 生产化：域名 + Nginx 443 反代 + TRUST_PROXY=1 + 后端仅监听 127.0.0.1（2026-11-08 全部完成，安全闭环复测五项全过；安全组 3000 放行规则建议顺手删除，清理性质无实际风险）

**上架**
- [ ] 截图重出 6.5" iPhone（Flutter UI 与 H5 不同）

---

## 11. 后端部署文档（GrandBlue Node.js + SQLite + PM2）

> 项目：大蓝海 App 后端 **v2.9.6**（2026-11-10 已上线），Flutter App 全面对接。生产节点**香港 `8.210.145.212`（`/opt/grandblue`，pm2: `grandblue`，无需 ICP 备案），对外入口 `https://api.idalanhai.com`**（2026-11-08 上线 + 安全闭环；2026-11-10 v2.9.6 增量部署，备份锚点 `index.js.bak-v2.9.5` + `grandblue.db.bak-20261110`）。**备案域名单独国内节点（杭州 ECS 47.114.60.214），两套分离**。完整部署/运维细节见 `../grandblue-server/部署文档.md` 与 `.workbuddy/memory/2026-11-08.md`、`2026-11-10.md`。

### 11.1 服务器信息（当前）

| 项 | 值 |
|---|---|
| 生产节点 | 香港节点 `8.210.145.212`（无需 ICP 备案，UGC 合规架构的核心） |
| **对外入口** | **`https://api.idalanhai.com`**（Flutter CloudApi Base URL；nginx 443 SSL + 限流 10r/s + 80→301 + HSTS） |
| 项目路径 | `/opt/grandblue`（香港节点） |
| 后端入口 | `index.js`（本地源码 `../grandblue-server/`，当前 **v2.9.6**） |
| pm2 进程名 | `grandblue`（`pm2 restart grandblue --update-env`；开机自启已配） |
| 监听地址 | `127.0.0.1:3000`（index.js `LISTEN_HOST` 固化回环，公网流量只走 nginx 反代；env `LISTEN_HOST` 可覆盖） |
| nginx | `/etc/nginx/conf.d/api.idalanhai.com.conf`；证书 `/etc/nginx/ssl/api.idalanhai.com.{crt,key}`（Let's Encrypt ec-256，acme.sh cron 自动续期 ~2027-02-05） |
| Node 版本 | v20.20.2（Alibaba Cloud Linux 3） |
| 数据库 | SQLite `./grandblue.db`（**18 张表**：14 + v2.9.6 user_follow/app_settings，users 补 bio/sail_level，reports 重建含 user 类型；生产库含测试账号 prodv_*×3 无害，回滚备份锚点 grandblue.db.bak-20261110） |
| 部署状态 | ✅ **v2.9.8 + 2026-11-11 下午热修已上线**（media/sign 匿名化 bak-20261111-125211、users/search 排除 founder bak-20261111-144604；改代码后 scp 对应文件 + pm2 restart 即可，⚠️ 严禁上传 grandblue.db；本地验证 curl 必须 `export no_proxy=127.0.0.1,localhost`，生产验证走 `ssh → 127.0.0.1:3000`——安全组未放行 3000 公网） |
| SSH 通道 | 本机 `~/.ssh/id_ed25519`（workbuddy-deploy@dalanhai）已授权，可全自动 ssh/scp |
| 调试模式 | 变量名 **`DEV_MODE`**（1=验证码回显；**服务器必须 =0** 已确认；⚠️ `.env.example` 里曾误写 `DEV_GKLH`，复制模板后注意改对变量名） |

**src/ 模块结构**（改代码前先看职责边界）：

| 文件 | 职责 |
|---|---|
| `src/db.js` | 建表 + 自动迁移（users/sessions/video_whitelist/posts/comments/likes/verify_codes + sms_send_log/verify_fail_counters/risk_flags/captcha_challenges + moderation_logs/media_sign_log/upload_log 共 14 张；含 v2.3→v2.6 老库幂等迁移块 migratePostsFromV23） |
| `src/middleware.js` | 鉴权（JWT 双 Token 查 sessions）/权限/限流 |
| `src/notify.js` | 短信（阿里云 dysmsapi v3.x）/邮件（nodemailer，读 SMTP_* 键）；⚠️ 已修 3 个致命 bug，别回退成旧写法 |
| `src/moderation.js` | 内容安全统一栈（v2.6.2）：green-cip 2022-03-02 手写 RPC V1 签名——TextModerationPlus/ImageModeration 同步 + VideoModeration/VideoModerationResult 视频异步（旧版 green ROA 已删除）；MODERATION_MOCK=1 标记式 mock |
| `src/risk.js` | 防刷风控引擎（3 规则/滑块/看板/创始人管理接口/清理调度器/图片签名频控 media_sign/上传频控；TRUST_PROXY=1 时信任 XFF 首段取真实 IP） |
| `src/logger.js` | 结构化 JSON 日志 + 敏感字段打码（v2.5.2 新增） |

### 11.2 安全组配置（当前）

- 香港节点：入方向放行 `22/TCP`（SSH 运维）+ `80/TCP` + `443/TCP`（nginx）
- **3000 已无公网监听**（index.js 固定 127.0.0.1，双保险）；安全组里残留的 3000 放行规则建议删除（清理性质）
- 代码 CORS 已配 `app.use(cors())`，外网不通优先查安全组而非跨域
- `TRUST_PROXY=1` 已生效（端到端验证：走 nginx 请求记录真实公网 IP，本机直连记录 127.0.0.1）

### 11.3 PM2 部署与 .env（已上线，此为增量更新流程）

```bash
# 日常改代码后的增量部署（本机已配 SSH 密钥通道，全自动）：
scp index.js root@8.210.145.212:/opt/grandblue/            # 或 src/*.js → /opt/grandblue/src/
ssh root@8.210.145.212 "cd /opt/grandblue && pm2 restart grandblue --update-env"
# ⚠️ 严禁上传 grandblue.db / *.db-wal / *.db-shm（生产数据）
# 服务器 .env 关键项：DEV_MODE=0、无 MODERATION_MOCK、TRUST_PROXY=1、真实 OSS/GREEN AK、SMTP_*（163）、SMS 未配置走日志兜底

# 历史首次部署记录（2026-11-08 已完成，仅存档）：
# scp index.js src/ test.sh test-ram-perms.js package*.json → /opt/grandblue/ + npm install --omit=dev
# v2.3 老库自动迁移（db.js migratePostsFromV23 补 posts 审核四列）+ .env 补 17 个 v2.6 键
# 回滚锚点：/opt/grandblue_bak_20261108_pre_v262（部署前全量）+ /opt/grandblue_db_backup_before_cleanup_20261108.db（清库前）
```

服务器 `.env` 关键项：`PORT=3000`、`JWT_SECRET`（32 字节 hex，只存在服务器上）、**`DEV_MODE=0`**（⚠️ 变量名是 DEV_MODE，模板里曾有笔误）、`FOUNDER_USER/FOUNDER_PASS`（创始人账号，db.js 启动同步入库）、`OSS_UGC_BUCKET=dalanhai-app-check` + `OSS_WEB_BUCKET=dalanhai-website-cn`、`SMS_*`（签名「杭州浩海星辰数字科技」+ 模板已过审）、`GREEN_*`（审核 AK，2026-11-07 起与 OSS 共用一组 AK，green+oss 权限已真机验证）、`MODERATION_TEXT_SERVICE=ugc_moderation_byllm_pro` + `MODERATION_IMAGE_SERVICE=postImageCheckByVL`（增强版服务，勿改回 image_moderation_pro）、`OSS_SIGN_URL_EXPIRE_SECONDS=900` + `MEDIA_SIGN_LIMIT_USER_PER_MIN=120` + `MEDIA_SIGN_LIMIT_IP_PER_MIN=600`（v2.6 签名防爬）、**⚠️ 服务器严禁配置 `MODERATION_MOCK`（=1 时审核形同虚设，仅本地测试用）**。

**PM2 运维命令**

```bash
pm2 list                # 查看服务状态
pm2 logs grandblue       # 实时查看日志（v2.5.2 起为结构化 JSON 单行）
pm2 restart grandblue --update-env   # 修改代码/.env后重启
pm2 stop grandblue       # 停止服务
# nginx：nginx -t 校验 / systemctl reload nginx 重载（证书续期由 acme.sh cron 自动+reloadcmd）
# 外网连通性自测：curl https://api.idalanhai.com/health（应 200）
```

### 11.4 接口清单与连通性（v2.9.6，2026-11-10）

> **v2.9.7 增量（评论系统 v2，2026-11-10 已上线，备份锚点 index.js.bak-v2.9.6 + src/db.js.bak-v2.9.6）**：comments 表迁移 +`root_comment_id`（NULL=一级评论）/`reply_to_comment_id`（被回复评论 id）/`at_user_ids`（@预埋 JSON，通知后置）三列 + `comment_likes` 表（PK comment_id+user_id）；新接口 `DELETE /api/posts/:postId`（仅作者，事务级联清 comments/comment_likes/likes/post_island/reports）、`DELETE /api/comments/:commentId`（权限=评论本人∥帖主∥父一级评论作者；删一级连带全部子评论；posts.comment_count 同步扣减）、`POST /api/comments/:commentId/like`（toggle）、`GET /api/comments/:commentId/replies`（子评论分页，时间正序）、`GET /api/users/search?q=`（昵称模糊 ≤10，排除双向拉黑+founder 系统账号）；`POST /api/posts/:id/comment` 扩展入参 `replyToCommentId`+`atUserIds`（≤10 去重、过滤拉黑），**返回新评论 JSON+commentCount**（breaking：旧版返回帖子对象）；评论列表只返回一级评论（root IS NULL），条目含 replyCount/likeCount/liked/isPostAuthor/atUserIds/replyToNickname/replyToUid；统一序列化 `commentJSON`。自测脚本 `test-v297-comments.sh`。

> **2026-11-11 下午热修增量（已上线生产）**：①`POST /api/media/sign` authRequired→optionalAuth（游客可签名看图；匿名 media_sign_log 记哨兵 userId=0；checkMediaSignGate userId=0 跳过用户维度仅按 IP 频控，登录用户保持用户+IP 双闸；备份 index.js.bak-20261111-125211）；②`GET /api/users/search` 加 `AND account_type != 'founder'`（uid=1 系统账号与 uid=12 真实用户同名「大蓝海创始人」曾致 @ 列表重复；备份 index.js.bak-20261111-144604）；③登录入参注释/建表注释账号描述统一「手机/邮箱/大蓝海账号」（b2fd11d）；④`GET /api/users/search` authRequired→optionalAuth（游客点 @昵称跳主页属查看类可读权限，游客哨兵 userId=0、blocked 仅登录时算；app 侧同批删 MentionText/comment_section 的 @ 点击登录拦截，备份 index.js.bak-20261111-151506）。部署流程同 §11.3（scp + pm2 restart grandblue）。

> **2026-11-15 热修（已上线生产，server commit 9cabca3，备份 index.js.bak-20261115-090052）**：`GET /api/users/search` 去掉 `AND id != ?` 自我排除——登录 uid12 搜自己昵称「大蓝海创始人」被过滤（发帖@弹窗列表空 + 正文/评论区点 @ 解析失败 toast「未找到该船员」），搜其他用户正常所以此前未暴露；@自己属合法场景（运营号自指）。founder 排除与双向拉黑过滤保留；Pixel7 全清单 5 项验收过（uid12 登录态搜全名命中→选中回填→发帖→正文@高亮点击跳 uid12 主页→评论区@点击不受影响→搜「李」命中李雷），验收测试帖已删零残留。

> **v2.9.8 增量（日志置顶 + 批量删除，2026-11-11 已上线，备份锚点 index.js.bak-20261111-095542 + src/db.js.bak-20261111-095542）**：posts 表补 `is_top` 列（幂等迁移，启动日志 `[迁移 v2.4] posts 表补列 is_top`）；新接口 `PATCH /api/posts/:id/top`（仅日志作者 403，body `{wantTop:bool}`，置顶时同事务清同用户其他置顶=**单人上限 1 条**，返回 `{postId,isTop}`）、`POST /api/posts/batch-delete`（仅本人，body `{postIds:[1~100]}`，**任一非法 id 403 全量不删**，级联清 comments/comment_likes/likes/reports/post_island）；`GET /api/user/:uid/posts` 排序改 `is_top DESC, id DESC`、条目下发 `isTop`；**getUgcOssClient 加 `secure:true`**（签名 URL http→https，修 Android 9+ 明文禁用导致图片全占位，commit 41ff648）。部署通道：阿里云安全组对开发机 IP 加白 TCP 22 后 AI 可 SSH 直连执行备份/scp/pm2 restart 全流程（用完建议删白名单规则）。

> **v2.9.6 增量（社交关系，全部已上线）**：`POST /api/user/follow`（幂等 toggle，双向拉黑 403，不能关注自己）、`GET /api/user/follow-status?targetUid=N`（following/followedBy）、`GET /api/user/:uid/followers|following`（分页，条目含 followedByViewer）、`GET /api/user/:uid/profile`（uid/nickname/avatar/bio/sailLevel/showSailLevelTag/isSelf/following/stats{posts,following,followers,totalCheckins,maxStreak}/certificates[]——双向拉黑或用户不存在一律 404「用户不存在」）、`GET /api/user/:uid/posts`（pass 帖分页）、`GET /api/user/liked-posts`（点赞列表，自动剔除双向拉黑用户帖子）、`POST /api/user/unblock`、`GET /api/user/blocklist`（分页）、`POST /api/admin/settings`（key 白名单 enable_sail_level_tag，value 归一化 1/0）、`POST /api/admin/user/sail-level`（手工赋航级 ≤20 字，无计算逻辑）；`POST /api/user/profile` 增 bio（≤100 字送审，空串清空）；`POST /api/report` type 增 user；`POST /api/user/block` 拉黑时**双向清空关注关系**（返回 clearedFollows）+ 全站双向拦截（isBlockedPair：详情/点赞/评论/关注/主页统一 404/403）；`blockedIdsOf` 双向化（我拉黑的 ∪ 拉黑我的，UNION）。自测脚本：`test-social-api.sh`（42 用例，独立测试库自启服务）、`verify-prod-v296.sh`（生产 21 项，BASE 指 127.0.0.1）。以下为 v2.6~v2.7 存量清单：

- 业务接口 42 个（v2.6.1 +1）：`/health`、`POST /api/register`（密码注册，保留）、`POST /api/login`（密码，兼容 account/username 字段）、`POST /api/refresh`（v2.3 Token 续期）、`POST /api/logout`（v2.3 退出登录）、`POST /api/login/sms`（短信验证码登录）、`POST /api/login/email`（邮箱验证码登录）、`POST /api/sms/register`、`POST /api/email/register`（验证码自助注册，v2.3 password 选填）、`POST /api/sms/send`、`POST /api/email/send`（发码，purpose=login|register|reset）、`POST /api/password/reset`（type/target 命名，与旧 `/api/reset-password` 等价）、`POST /api/password/set`（v2.3 无密码账号补设密码）、`GET /api/me`、`POST /api/change-password`、`POST /api/send-code`（旧发码，purpose=reset）、`POST /api/posts`（type:text/image/video，video 校验白名单；v2.4 image 同步审核/video 异步审核 pending 入库；v2.6 所有类型正文文本同步送审 + attachUrl 只认本平台 UGC 桶、外部直链 400；**v2.6.1 支持 attachUrls 多图数组（1-4 张逐张送审）+ video 必带 duration≤30 + 附件扩展名白名单（图 jpg/jpeg/png/webp、视频 mp4）+ 违规有附件帖入库 reject 留存**）、`GET /api/posts`（v2.4 只返回 status=pass；创始人 `?includeAll=1&status=` 可查全部；**v2.6 附件只返回 attachKey 不再返回永久直链；v2.6.1 多图帖返回 attachKeys 数组**）、`POST /api/posts/:id/comment`（**v2.6 文本同步送审，违规/疑似/异常一律拦截**）、`POST /api/posts/:id/like`（toggle）、`POST /api/upload`（图，全员，**v2.6.1 仅 jpg/jpeg/png/webp（gif 拦截）+ 上传频控**）、`POST /api/upload/video`（白名单，**v2.6.1 仅 mp4 ≤30MB + 频控**）、`GET /api/oss/policy`（v2.4 直传签名 type=ugc/website + media=image/video；**v2.6.1 前置校验声明参数 ext/size/width/height/duration（视频必填），非法 400；上传频控 图片 5 张/分钟、视频 1 条/分钟，超限 429 写 upload_log+risk_flags**）、`POST /api/media/sign`（**v2.6 图片/视频访问签名：JWT + 单用户/单IP 频控 + 只签 status=pass 帖 + OSS_SIGN_URL_EXPIRE_SECONDS 默认 900s 时效 URL；v2.6.1 多图帖逐 key 签发 urls[postId]={url,urls[],expiresAt,expiresIn}，oss_purged=1 不签**）、`POST /api/admin/oss/purge`（**v2.6.1 手动触发 reject 资源 OSS 清理，创始人，days 0-365**）、`POST /api/moderation/callback`（v2.4 审核回调）、`POST /api/admin/moderation/poll`（v2.4 手动轮询）、`POST /api/admin/whitelist/add|remove`、`GET /api/admin/whitelist/list`、`POST /api/admin/token/revoke`（v2.3 创始人吊销会话踢下线）、`GET /api/captcha/challenge`（**v2.5 风控滑块**，算术题 5 分钟一次性）、`GET /api/admin/sms/stats`（**v2.5 风控看板**，仅创始人）、`POST /api/admin/sms/cleanup`（**v2.5.1 手动清理流水**，仅创始人，days 1-365）、`POST /api/admin/sms/risk/lock|unlock|clearFlag|blacklistAdd|blacklistRemove`（**v2.5.2 创始人风控管理 5 接口**，审计入 risk_flags.note）（管理员类仅创始人）；DEV 模式另有 `/api/__test/boom` 调试路由（生产不注册）
- **v2.5 风控响应约定**：命中风控的发码接口返回 `403 {needCaptcha:true, rules:[], captcha:"/api/captcha/challenge"}`，客户端先取挑战、再带 `captchaId/captchaAnswer` 重发；验证码连错 3 次锁 10 分钟（锁定期间禁发码禁校验）
- **v2.3 双 Token 机制**：登录/注册/续期返回 `{token(7天), refreshToken(30天), user}`；`/api/refresh` 轮换制（旧 token 对立即作废，30 天滑动续期）；会话存 `sessions` 表（jti=sid 写进两种 token payload），authRequired 每次查会话吊销状态 → 踢下线即时生效；RefreshToken 不能当 AccessToken 用（typ 标记）；超 30 天未续期需重新登录
- **v2.3 密码选填**：验证码注册不填密码 → `password_hash` 存 NULL（无密码账号仅验证码登录，密码登录 401「该账号未设置密码」）；个人中心 `/api/password/set` 补设后两种方式均可；首次重启自动迁移（旧库 NOT NULL 重建，日志打印 `[迁移 v2.3]`）
- **验证码规则**：三码隔离（login/register/reset 互不通用）；5 分钟有效、一次性；60s 冷却按「账号+用途」；login/register 码真实发送（不防枚举），仅 reset 码防枚举
- 存储：SQLite `grandblue.db`（v2.3 七表 + v2.5 风控四表 + v2.6 审核留存/签名流水 + v2.6.1 上传频控 = 14 表，重启不丢）；密码 bcrypt；限流：登录类 20 次/分钟/IP、refresh 30 次/分钟/IP（独立配额）、注册 10 次/小时/IP、发码 20 次/小时/IP；users 表字段 snake_case（account/password_hash/role/created_at），id 自增、创始人恒为 1
- **全局异常约定（v2.5.2）**：未捕获异常统一返回 `{code:-1, msg:'服务器内部错误', data:null}`（字段名是 `msg` 不是 `message`，与 Flutter 既有对接保持一致）；日志为单行 JSON `{time,level,type,msg,err,ctx}`，敏感字段自动打码
- 架构目标：后端 + OSS 部署香港服务器（大陆域名备案单独走杭州节点，两套分离）
- 自动化测试：`bash test.sh`（本地 **166 PASS / 0 FAIL / 3 SKIP 全绿**；香港服务器 2026-11-08 回归 166 PASS/1 FAIL/2 SKIP，唯一 FAIL=SMTP 授权失效已当日修复；⚠️ 须以 `DEV_MODE=1 MODERATION_MOCK=1 node index.js` 启动跑全量，连续重跑注意限流（registerLimiter 10次/h/IP），重启服务清计数；test.sh 启动时自动清理本机 127.0.0.1 发码流水，防 ip_multi_phone 跨次误伤；服务器跑真实模式预期 PASS≈13x，真实链路验收用 deploy-health-check.sh 9 项）
- 上传接口为二进制 body + `x-file-ext` 头（非 multipart）
- 登录入参兼容 `account` / `username` 两种字段名

> **v2.9.9 增量（消息中心 + 密码找回，2026-11-15 已上线生产，备份锚点 index.js.bak-20261115-182220 / -205815，server commit 6468697+5c155f0）**：新表 notifications（user_id/type like_post|like_comment|reply|mention/actor_id/post_id/comment_id/created_at/read）、dm_conversations（user_a<user_b UNIQUE）、dm_messages（conv_id/sender_id/content/read 收件方已读）；**发码接口 purpose 扩展**：`/api/sms/code`、`/api/email/code` 加 `purpose=reset`（reset 不自动注册、未注册 404「账号不存在，请先用短信/邮箱注册」、60s 冷却按 purpose 分桶；login 原逻辑含自动注册零变化）；**Email reset 发码豁免 captcha**（找回页无验证题 UI，由风控闸门+单邮箱 3条/h+单 IP 10条/h+60s 冷却兜底）；`POST /api/password/reset`（仅手机号/邮箱，accountTypeOf 拦截账号 ID；purpose=reset 码一次性核验，锁定期/连错计数/文案与登录完全一致；bcrypt 更新 password_hash；成功不自动登录）；通知埋点：帖子赞（⚠️ `/api/post/:postId/like` 与 `/api/posts/:postId/like` 双路由都埋）、评论赞、评论（reply→被回复评论作者；mention→atUserIds 逐个，与 reply 已通知者去重；自赞/自@上游过滤）；`GET /api/user/notifications/unread`（4 类计数）、`GET /api/user/notifications?type=&page=&size=`（平铺，聚合展示由前端按 postId/commentId 分组）、`POST /api/user/notifications/read`（ids 批量 ≤200）、`POST /api/user/notifications/read-all`；私信：`POST /api/user/dm`（拉黑 403、founder 拒收、≤500 字）、`GET /api/user/dm/conversations`、`GET /api/user/dm/:peerUid/messages`（打开即置对方消息已读）。Flutter 端聚合格式「磐石、南十字等4人点赞了你的航海日志」。

> **v2.9.10 增量（群聊第一版，2026-11-15 已上线生产，备份锚点 index.js.bak-20261115-220456 + src/db.js.bak 同时间戳，server commit e7e3b75）**：新表 groups（g001 清心岛·静水深流 island「冥想·静心·同行」/ g002 戒烟岛·无烟港 island / g003 健身岛·铁血船队 island / g004 早睡岛·熄灯号 island / g005 情感觉醒交流群 tavern「情感·觉察·成长」/ g006 AI学习交流群 tavern；db.js 启动 seed 幂等 INSERT OR IGNORE）、group_msg（sender_name/sender_avatar 冗余，仅 msg_type=text）、user_group_unread（PK uid+group_id，last_read_msg_id）；接口全 JWT（未登录无法进群/发消息）：`GET /api/group/list`（member_count=**发过言去重 uid 动态统计**、lastContent/lastAt、unread=**动态 COUNT(msg_id > last_read_msg_id) 无需推送**）、`GET /api/group/:groupId/info`、`GET /api/group/:groupId/msg?limit=&last_msg_id=`（进群不带 last_msg_id=最新 limit 条正序；带=更早 limit 条）、`POST /api/group/:groupId/msg`（≤500 字；Green 线上审核（生产 AK 已配置实测拦截生效）+ 本地敏感词兜底 `GROUP_LOCAL_BANNED_WORDS`（20 词，线上审核未启用时也保证拦截；命中 403「消息包含违规内容」不入库））、`POST /api/group/:groupId/read`（UPSERT last_read_msg_id）；权限模型：所有登录用户免邀请/申请/审核直接进全部 6 群。**上线前清测试数据**：`DELETE FROM group_msg; UPDATE groups SET member_count=0;`（g001-g003 有「训练日志第 N 条」等测试消息）。

> **v2.9.11 增量（账号注销 + closed 全链路，2026-11-17 已上线生产，备份锚点 index.js.bak-20261117-221020；打卡清除补丁同日二刷部署）**：
> - `POST /api/account/close`【JWT】：注销事务——status=closed、昵称落库改写【已注销用户】、avatar/bio/sail_level 清空、`account` 改名 `closed#<id>#<原值>`（**手机号/邮箱释放可重注册**）、user_follow 双向清空、sessions 全吊销、`DELETE FROM user_island_checkins WHERE user_id=?`；founder 拒注销；幂等（closed 再调报错）
> - **closed 全链路拦截**：`middleware.resolveAccessUser` 对 closed 用户返回 null（authRequired 全接口 401 + optionalAuth 按未登录）→ 等效于旧 token 全失效；`/api/login`、验证码登录、`/api/refresh` 三处显式 401「账号已注销」
> - `GET /api/users/search?q=` 默认排除 closed；`includeClosed=1` 参数仅供 @点击回查（命中 closed 下发 `closed:true`，前端静默不跳转）
> - `authorJSON` +`closed` 字段（帖子/评论作者全量下发）；`GET /api/user/:uid/profile` closed → 匿名占位（已注销用户/空头像/统计清零/closed:true）；`GET /api/user/:uid/posts` closed → 空列表；dm 收件人 / follow 目标 closed → 403「该用户已注销」；`groupMsgJSON` 对 closed 发送者**实时匿名覆盖**快照（senderName/senderAvatar/senderClosed）
> - **打卡数据归属定版**：云端真源一直按 `user_id` 绑定（user_island_checkins/checkinSummary），注销即清；同手机号重注册 = 全新 uid、数据从零（§12.2）

### 11.5 当前部署状态与账号（2026-11-07 实测）

**启动日志确认**：`[GrandBlue v2] 后端服务已启动：http://localhost:3000`、`数据库：./grandblue.db，用户 1 人`、`创始人账号已创建：dalanhai`、`DEV_MODE=开（验证码回显，仅调试！）`

**创始人账号**（服务器 .env 的 `FOUNDER_USER/FOUNDER_PASS` 同步入库）：

- 用户名 `dalanhai` / 密码 `gkt123456`（⚠️ 联调临时密码：上线前必须更换，且不得写入任何公开仓库或客户端代码）
- `isFounder: true` + `isVideoWhitelist: true`（创始人自动在视频白名单内）

**权限模型（按代码实际实现）**：

| 操作 | 普通登录用户 | 创始人 | 视频白名单用户 |
|---|---|---|---|
| 登录/注册/评论/点赞/浏览 | ✅ | ✅ | ✅ |
| 发图文帖（type:text/image）+ 传图 | ✅ | ✅ | ✅ |
| 发视频帖 + 传视频 | ❌ 403 | ✅ | ✅ |
| 白名单管理 `/api/admin/whitelist/*` | ❌ | ✅ | ❌ |

**已验证登录接口**：

```bash
curl -X POST http://127.0.0.1:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"dalanhai","password":"gkt123456"}'
# → { "code":0, "msg":"登录成功", "data":{ "token":"...", "user":{ "id":1, "username":"dalanhai", "isFounder":true, "isVideoWhitelist":true } } }
```

后续需登录的接口统一带 Header：`Authorization: Bearer {token}`（JWT，有效期可配置，默认 7 天）。

### 11.6 Flutter 对接规范

- 统一响应格式：`{code:0|-1, msg, data}`，客户端以 `code===0` 判定成功
- 鉴权：登录后保存 token，所有需登录接口带 `Authorization: Bearer <token>`
- **v2.3 双 Token 对接**：登录/注册响应同时含 `token`（7 天，请求头用）和 `refreshToken`（30 天，本地持久化）；App 启动先调 `POST /api/refresh {refreshToken}` 续期，成功后**两个 token 都替换保存**（轮换制旧对已作废）；任意接口 401「登录已失效/已过期」→ 先试一次 refresh，再失败才引导重新登录；退出登录调 `POST /api/logout`（可带 refreshToken）并清空本地凭证
- 用户对象字段：`id`、`username`、`isFounder`、`isVideoWhitelist`（发布页据此控制视频入口：非白名单置灰 + 弹窗「如需发布视频，请添加客服微信 abccba978 申请开通视频发布权限」；**前端仅做体验控制，权限校验在后端**）
- 注册（验证码）：`POST /api/sms|email/register {phone|email, code, password?}`，password 选填——注册表单密码栏可留空；无密码账号个人中心提供 `/api/password/set` 补设入口
- 发帖参数：`{ "type": "text|image|video", "content": "...", "attachUrl": "..." }`
- **v2.4 OSS 直传对接**（替代 /api/upload 中转）：①`GET /api/oss/policy?type=ugc&media=image|video` 取 `{accessKeyId, policy, signature, host, dir, expire, maxSize}` → ②前端构造 multipart 表单 POST 直传 `host`（file 必须是最后一个字段）→ ③拿 OSS 返回的 Etag/URL 填 `attachUrl` 调 `POST /api/posts`（只认本平台 UGC 桶地址或 key）；视频帖后端入库 `status=pending`，列表不可见，前端需展示「审核中」状态提示
- **v2.6 图片/视频渲染对接**（防爬改造，替代旧 attachUrl 直连）：①帖子列表/详情响应只有 `attachKey`（无永久直链）→ ②渲染前调 `POST /api/media/sign {postIds:[...]}`（≤30/批，返回 `{urls:{"<postId>":{url,expiresAt,expiresIn}}, missing:[]}`）→ ③客户端按 `expiresAt` 缓存时效 URL，过期重取；missing 里的帖子不渲染附件（未过审/不存在）
- **v2.6 审核交互**：发帖/评论 403「未通过安全审核」→ 提示修改内容（block/review 话术统一，防探测）；500「审核服务异常」→ 提示稍后再试
- **v2.5 风控对接**：发码接口返回 `403 {needCaptcha:true}` → 调 `GET /api/captcha/challenge` 取算术题 → 用户作答后带 `captchaId/captchaAnswer` 重发；连错 3 次锁定 10 分钟（提示用户稍后再试）
- **BaseURL（✅ 已锁定）**：`https://api.idalanhai.com`（session_store.defaultBaseUrl 单点管理；裸 IP `http://8.210.145.212` 不可路由——3000 仅监听 127.0.0.1、80→301 且 IP 证书校验失败、iOS ATS 强制 HTTPS；2026-11-10 设备端旧 baseUrl 持久化键已自动清除）
- **支付宝支付对接**：预下单 `POST /api/pay/order` + 查单 `GET /api/pay/order/:no`，orderString 交 SDK 唤起——完整契约/红线/踩坑见 **§13**（后端已验收闭环，Flutter 端待开发）
- **Android 网络**：全 HTTPS 后无明文需求（manifest 无 usesCleartextTraffic 配置，勿加）；⚠️ **main/AndroidManifest.xml 必须保留 `<uses-permission android:name="android.permission.INTERNET"/>`**（Flutter 新模板只在 debug/profile manifest 给权限，删掉 release 包完全无法联网——v2.9.6 已修复过一次）

### 11.7 上线检查项与风险清单（2026-11-08 复核更新）

1. ✅ 服务器 `.env` 已确认 `DEV_MODE=0`（变量名是 `DEV_MODE`，`.env.example` 模板里曾误写 `DEV_GKLH`）
2. ⚠️ 创始人密码更换 + JWT_SECRET 不入库不入公开仓库（本文件不含密钥明文）
3. ⚠️ **上线稳定后 RAM 轮换 OSS/SMS/GREEN AK**（Secret 在历史对话明文出现过）；当前 OSS/GREEN 共用一组 AK（green + oss:PutObject/GetObject/DeleteObject 权限，服务器端 test-ram-perms 已验证），早期专用 `dalanhai-oss-app`（仅 PutObject）已被替代
4. ✅ `GREEN_ACCESS_KEY_ID/SECRET` 已配置并上线（与 OSS 共用 AK，green-cip 统一栈真机验证；服务器回归全过）
5. ✅ 香港桶 dalanhai-app-check 已改【私有读】（无签名直访 403）；读取方式=私有桶 + `POST /api/media/sign` 时效签名（审核送审走内部签名 URL，桶私有不影响审核）；CORS 待 App 直传联调时按需配置（规则见部署文档 §12.3）
6. ✅ 域名 + Nginx 443 反代上线（api.idalanhai.com，80→301，限流+HSTS）；后端仅监听 127.0.0.1:3000（公网直连已验证不可达）；`TRUST_PROXY=1` 已配置并端到端验证（走反代记录真实 IP）；安全组 3000 残留规则建议删除（无实际风险）
7. `/health` 接入监控告警（待办）；CC 防护（nginx 限流 + JWT + 风控三层已就位）
8. ✅ v2.6.2 已部署香港 `/opt/grandblue`（2026-11-08）：服务器 mock 回归 166 PASS + 安全闭环五项复测全过；增量部署流程见 §11.3
9. Flutter 联调期 `usesCleartextTraffic=true` 是临时配置，Google Play 对明文流量拒审（⚠️ 现在已有 HTTPS 域名，对接 `https://api.idalanhai.com` 后可移除该配置）
---

## 12. 账号注销规范（✅ 已实现 v2.9.11，2026-11-17 全栈上线生产——本章即实现依据）

> 2026-11-17 产品定版并**当日实现上线**。核心策略：**账号标记注销 + 匿名化，不删除历史 UGC 帖子/评论/私信**，避免 @、评论、私信链路断裂报错。
> 约束：仅用于注销场景；正常用户发帖/@/私信/关注/置顶/批量删除等业务逻辑、内容审核与敏感词过滤逻辑一律不动。
> ⚠️ **严禁直接删除用户帖子/评论**——注销是匿名化，不是数据清除。
>
> **实现落点（改注销相关代码前先看这里，避免重复踩坑）**：
> - 后端（已部署，备份锚点 index.js.bak-20261117-221020）：`users.status` 幂等迁移；`POST /api/account/close` 匿名化事务（status=closed、昵称落库改写【已注销用户】、avatar/bio/sail_level 清空、**account 改名 `closed#<id>#<原值>` 释放手机号**、user_follow 双向清空、sessions 全吊销、user_island_checkins 全清）；closed 拦截在 middleware.resolveAccessUser（authRequired 全接口 401 + optionalAuth 按未登录）+ 三处登录/续期入口；`users/search` 默认排除 closed、`includeClosed=1` 仅供 @点击回查（下发 closed:true）；authorJSON/profile/posts/dm/follow/groupMsgJSON 全部带 closed 口径
> - Flutter：account_settings_page【注销账号】双层弹窗（确认 → 身份校验输入账号 ID）；CloudAuthor/CloudUserProfile/CloudGroupMessage/CloudUserSearchItem 带 `closed` 字段；closed 渲染=点击无响应或静默（港口/详情/评论/私信/群聊作者头像昵称、@提及正文+评论）、详情页关注按钮隐藏、他人主页操作行隐藏
> - 已知边角：①注销/登出后 IndexedStack 常驻页重拉数据会弹一次「未登录，缺少 token」红 toast（登出既有伴随现象，待顺手修）；②account 改名出现 `closed#12.0#`（better-sqlite3 数字绑定行为，无功能影响）；③生产真实注销验收用 uid12 完成（用户授权），其手机号已释放
> - 本地自测脚本：`D:/WorkBuddyProject/tmp/test-close-account.js`（23/23 PASS；绕短信直接签 token，跑前须加载 .env 的 JWT_SECRET）

### 12.1 账号注销规则（匿名化方案）

1. **账号状态**：`user` 表增加 `status` 字段，`normal`=正常，`closed`=注销；注销后**禁止登录**、**不能再被搜索**
2. **用户展示信息**：昵称统一替换为**【已注销用户】**，头像清空，个人主页所有统计数字清零
3. **航海日志、评论**：内容保留，发布者展示为【已注销用户】，**不再跳转主页（点击无响应）**
4. **@提及记录**：帖子/评论里曾经 @该用户的文本保留，点击 @标签**不再跳转主页、不抛异常、不弹窗**
5. **私信会话**：双方聊天记录完整保留；注销方展示为【已注销用户】，头像为空
6. **粉丝/关注关系**：全部解除，双向清掉关注、粉丝数据
7. **打卡记录**：注销时**同步清除**该 uid 全部岛屿打卡/连续天数/征服计数（v2.9.11 补丁定版——打卡真源按 uid 绑定，防止同手机号新注册账号经任何旧口径读到旧数据）；打赏记录保留对账，对外展示身份匿名化
8. **数据留存**：按合规要求留存必要日志，**不可恢复**原账号身份信息

### 12.2 注销后同手机号/邮箱再次注册规则（配套 12.1）

核心原则：**旧注销账号与新账号完全隔离**，互不关联，旧数据不回滚、不迁移、不合并不恢复。

1. **手机号/邮箱释放**：账号标记 `closed` 后该手机号/邮箱解绑，允许重新注册**全新账号**（全新 uid）
2. **新旧数据隔离**：旧注销账号的日志/评论/私信/打赏全部留在旧 uid 下（保持【已注销用户】展示），**不绑定到新账号**；打卡记录注销即清（v2.9.11 补丁）；新账号粉丝/关注/日志/徽章/打卡全部从零开始
3. **历史关联内容**：历史帖子/评论/私信里的【已注销用户】标识保持不变，**不会**自动变成新注册用户的昵称
4. **登录校验**：旧 uid（closed）禁止登录；新注册走正常注册流程，独立权限
5. **重复注册限制**：无额外拦截，手机号/邮箱验证码校验通过即可注册

### 12.3 验收清单（✅ 2026-11-17 已按本清单完成生产真实注销验收——uid12 全链路 + 本地 API 23/23 PASS；后续改动注销相关代码时仍须按本清单回归）

1. 注销账号后无法登录该账号
2. 他人打开该用户主页：显示【已注销用户】，数据清零
3. 历史帖子/评论正常可见，作者显示【已注销用户】，点击作者无跳转
4. 历史 @该用户的标签：点击无跳转，页面不报错、不弹窗
5. 历史私信会话保留：对方头像为空、昵称【已注销用户】，聊天记录正常查看
6. 该账号不再出现在搜索列表、粉丝列表、关注列表
7. 注销后手机号释放，可正常走注册流程并得到**全新 uid**（主页空白，无旧数据）
8. 翻看历史旧帖子/私信，依然显示【已注销用户】，不会被新账号昵称顶替
9. 新账号发帖/私信/被 @ 与普通账号行为一致；旧注销账号无法再次登录

---

## 13. 支付宝支付对接规范（后端已就绪 ✅ 2026-11-21 全链路验收闭环；Flutter 端已接入 tobias ✅ 2026-11-22，见 §13.14）

> 后端（grandblue-server src/alipay.js）已稳定跑通：预下单 RSA2 签名、异步 notify 验签、幂等防重复回调、定时查单兜底，**0.01 元真实订单生产验收通过**（交易号 2026112123001470161403747523，0 验签报错）。**密钥、支付宝开放平台配置（AppId `2021007121620744`）全部就绪，不要再动。**

### 13.1 接口契约（Flutter 端调用）

1. **预下单** `POST /api/pay/order`（Bearer token）
   - 当前入参：`{ "productId": "makeup_card_1" }`（商品白名单在后端 PRODUCTS 常量：makeup_card_1=6.00 / makeup_card_5=25.00 / test_001=0.01 验收专用）
   - 返回：`{ outTradeNo, amount, orderString }`
   - **⚠️ 前端计划的入参形态是「金额 + 商品标题 + 订单来源标记」**——当前实现是 productId 查白名单表；开发支付页时需后端把下单接口扩展为动态入参版本（**金额必须做白名单/受控校验，绝不能开放任意金额**，防客户端篡价），小改动，对接前加
2. **查单** `GET /api/pay/order/:outTradeNo`（Bearer token）→ `{ status, trade_no, paid_at, ... }`
3. **异步回调** 固定 `https://api.idalanhai.com/api/pay/notify`（已在 orderString 内下发 + nginx 已豁免限流），前端无感知；**订单状态的权威来源是支付宝 notify 回调改库**，前端轮询查单只做 UI 弹窗兜底（1~2s 间隔轮到 PAID 展示成功弹窗），不等回调超时也以查单为准

### 13.2 Flutter 端唤起收银台（对接要点，防踩坑）

- `orderString` **原样**交给支付宝 SDK（✅ 2026-11-22 已实接 **tobias ^5.3.4**，仅 Android 调用；任何字符都不能改），后端零改动
- iOS：**不走支付宝、不调用 tobias 插件**（reward_sheet 平台分支直接拦截，见 §13.14）；Android：插件自带 Activity/Intent 过滤，manifest 零配置
- 端上**不依赖** SDK 支付结果回调也可以：以轮询查单 + 后端 notify 为准（端上回调只是加速 UI 反馈）

### 13.3 红线与坑（记牢，防返工）

- ❌ **当面付 precreate 未签约**（isv.insufficient-isv-permissions），**不要用这个接口**
- ✅ App 支付正式接入走 `alipay.trade.app.pay`：后端返回 orderString → SDK 唤起，后端代码不用改
- ⚠️ nginx 已对 `/api/pay/notify` 路径级豁免限流（支付宝重试风暴 4m/10m/10m/1h 不能被 429 拦），**别给这个路径加限流**；伪造通知由应用层 RSA2 验签拦截，与限流无关
- ⚠️ 幂等闸门在后端：`UPDATE ... WHERE status='UNPAID'` 原子变更 changes=1 才发货，支付宝重复通知/查单兜底重复补单都不会重复发货——前端无需去重
- ⚠️ 查单兜底每 5 分钟扫 UNPAID 单、>30 分钟未支付自动关单——前端展示「订单已关闭」场景对应 CLOSED 状态，引导用户重新下单

### 13.4 验收入口计划与复测

- 支付入口计划放在**开服公告**里（Flutter 端实现时接入）
- 链路复测：服务器跑 `node gen-accept-qr.js` 生成 0.01 元（test_001）扫码验收二维码 → 手机支付宝扫码付款 → `watch-acceptance.sh` 或直接查单看 PAID；本地全链路自测跑 `test-alipay-e2e.sh`（测试密钥对模拟支付宝，四场景：正常/幂等/伪造/篡改）

### 13.5 岛屿 Banner + 开服公告 + 赞赏链路（✅ 2026-11-21 已实现并 Pixel7 验收）

**后端**（grandblue-server）：
- `banners` 表（title/subtitle/button_text/icon/theme/action/action_value/sort/enabled）+ 幂等 seed（开服公告 reward sort=0 / 今日出海 none sort=1）
- `GET /api/banners` 公开（游客可读）；CRUD `POST/PATCH/DELETE /api/admin/banners`（founderOnly）
- `POST /api/pay/reward`（authRequired）动态金额赞赏下单：**金额受控**（正则两位小数 / >0 / ≤9999），orders.product_id='reward'，grantProduct reward 分支记账即交付；后端负例 5/5 拦截实测（0/-5/1.234/abc/10000）

**Flutter 端**：
- `lib/widgets/app_banner.dart`：PageView（viewportFraction 0.88）**仅手动拖拽无自动轮播** + 底部居中圆点指示器（金色长条高亮）+ action 分发（reward→公告页 / internal_page 预留无动作 / none→无任何动作）；今日出海卡片（action=none）自动追加 voyage 统计行
- `lib/pages/announcement_page.dart`：开服公告二级页（固定文案 + 自愿赞赏按钮）
- `lib/widgets/reward_sheet.dart`：档位 chips → `POST /api/pay/reward` → **tobias 原生唤起支付宝（2026-11-22 起，曾用 url_launcher scheme 已替换）** → 轮询查单 → PAID 成功流程；详见 §13.14
- `lib/tabs/islands_tab.dart`：改 StatefulWidget，RefreshIndicator 包全页，onRefresh → AppBannerState.refresh()（防抖 300ms 强拉最新配置）
- 数据模型 `BannerItem`（⚠️ 勿与顶栏 `AppBanner` widget 混淆——数据类叫 BannerItem）/ `PayOrderResult`（models.dart）
- 缓存：prefs `banner_cache_v1` 10 分钟 TTL；网络失败回退缓存，缓存也无 → 内置 fallback 卡片（保证顶部不空白）

**Pixel7 验收记录（2026-11-21）**：Banner 默认停开服公告 ✅ / 左拖切今日出海无自动翻页 ✅ / 指示器居中同步高亮 ✅ / 公告页文案+按钮 ✅ / 档位弹窗 ✅ / 30元档确认预下单成功（uid23 订单入库）✅ / 今日出海点击无反应 ✅ / 后台改排序→下拉刷新生效（今日出海变第一张）✅ / 已改回默认排序。⚠️ 自定义金额输入的 UI 层模拟器 adb 键盘交互未覆盖（sheet 键盘动画期坐标漂移），逻辑三重校验已就位（前端过滤+校验+后端拦截），真机手测即可。

### 13.6 Banner 卡片 v2（✅ 2026-11-21 20:35 二次迭代，Pixel7 验收全过）

- **卡片骨架统一**：`_HeroBannerCard` 1:1 复刻原版 H5 voyage hero（全宽 margin(14,4,14,4) + 圆角22 + eyebrow/title/desc 排版 + ⛵/📢 角标 + 底部 _WavePainter 波浪），两卡同一骨架 → 宽高完全一致；`_cardHeight=108` 固定（原版自然高度）
- **今日出海 = 原版视觉**：CHAPTER·{year} eyebrow（Cinzel）+ heroStart→deep→abyss 渐变 + 动态统计行 + ⛵44px；开服公告 = 同构金调（ANNOUNCEMENT eyebrow + 4A3A12→2A2410→abyss 渐变 + subtitle + 📢38px）
- **Banner 上不放按钮**：buttonText 字段不渲染，整卡点击按 action 分发
- **顺序保证**：后端 seed sort 0=开服公告 / 1=今日出海，前端按 ORDER BY sort 顺序渲染不重排 → 默认首屏必为开服公告
- **PageView viewportFraction 1.0**（原版全宽；不再露边 0.88），指示器收在 Banner 容器内部卡片正下方（SizedBox 16 居中）
- **adb 自测坑（重要）**：模拟器 1080×2400，截图看坐标要按比例换算；keyevent 111(ESC) 会连 modal bottom sheet 一起关，收键盘用 keyevent 4(BACK)（键盘弹起时 BACK 只收键盘不关 route）；sheet 无键盘态确认按钮 y≈2151、输入框 y≈1976、公告页自愿赞赏按钮 y≈1396
- 验收记录：默认开服公告✅/左拖切今日出海✅/两卡同尺寸✅/原版视觉✅/无按钮✅/指示器容器内居中✅/公告页✅/档位弹窗✅/自定义0拦截（赞赏金额必须大于0）✅/自定义6.5预下单入库（GB2611212032100099849, 6.50, reward）✅/今日出海点击无反应✅/后台改排序下拉刷新生效✅/15秒无自动翻页✅/默认排序已恢复

### 13.7 Banner 顺序强制修正（✅ 2026-11-21 20:55，仅改 app_banner.dart）
- **根因**：前端沿用后端数组顺序渲染 + PageView 缓存浏览位置（IndexedStack 常驻切 Tab 不销毁 State）→ 切 Tab 返回岛屿时可能停在上次的今日出海
- **修复**：①`_forceAnnouncementFirst`——`_load` 后本地重排，`action=='reward' || title=='开服公告'` 识别（后端无 type 字段且禁新增，用现有字段等价实现）挪到 index 0；②`PageController(initialPage:0, keepPage:false)`；③订阅全局 `appTabIndex`（lib/app.dart:15 ValueNotifier，`import '../app.dart' show appTabIndex` 有先例），切回岛屿 Tab（value==0）`jumpToPage(0)` 重置
- **验收（Pixel7）**：默认首屏开服公告✅ / 左滑今日出海→切港口→切回岛屿自动回开服公告✅ / 后端 sort 反转+下拉刷新首屏仍开服公告✅（已恢复默认排序）/ 视觉交互零改动✅

### 13.8 赞赏弹窗登录跳转修复（✅ 2026-11-21 21:15，仅改 announcement_page.dart）
- **逻辑前置**：登录闸门从 reward_sheet.showRewardSheet 前置到 announcement_page 的 `_onRewardTap`（约束只改公告页；reward_sheet 未动，其内部未登录分支成死代码但保留无害）
- 流程：已登录→直接 showRewardSheet；未登录→「需要登船」AlertDialog（文案原样）→「好的」→push `AuthPage(returnTo: 'island')`（三种登录方式成功后都 pop 回来源页且不跳船长 Tab）→回来后 hasToken 同步检查→已登录自动 showRewardSheet 唤起档位弹窗；用户直接返回则不打扰
- **验收（Pixel7，pm clear 未登录态）**：未登录点赞赏→「需要登船」弹窗✅/好的→登录页✅/登录成功→自动回公告页+档位弹窗✅/已登录再点→直弹档位✅/6元档预下单入库（GB2611212111180814220, 6.00）✅/页面文案样式零改动✅
- adb 坐标（1080×2400）：公告页自愿赞赏按钮 (540,1393)、登船弹窗「好的」(792,1284)、密码登录tab (870,690)、账号框 (540,993)、密码框 (540,1244)、登录按钮 (540,1402)、档位chips y≈1805、确认赞赏 (540,2151)

### 13.9 自愿资助定位改版（✅ 2026-11-21 23:20，合规风控）
- **定位变更**：自愿赞赏 → 自愿资助（非商品交易），规避大额恶意退款/苹果审核/支付风控；**不授予任何站内权益**（grantProduct reward 分支只记账，代码注释已声明）
- **reward_sheet.dart**：删自定义输入框；档位 1/6/30/68/256（原 98/648 删除）；副标题「选择金额支持项目运营成本，单笔最高256元」；底部温馨提示（理性支持/未成年勿资助/不对应权益/不退款）；按钮「确认自愿资助」；点确认直接拉起支付宝无二次确认弹窗
- **后端 alipay.js**：`REWARD_TIERS` 白名单硬闸（归一化 toFixed(2) 比对，非 5 档位一律 400 拒绝+warn 日志）；orders 表留存 UID/金额/订单号/下单时间 + 下单/交付双链路结构化举证日志；product_title 改「大蓝海-自愿资助」
- **验收（Pixel7 + 生产）**：弹窗 5 档位无输入框文案全对 ✅ / 68 元确认直接预下单（GB2611212317220564603, 68.00）✅ / 生产 curl 负例 98/648/6.5/9999 全 400 拦截 ✅ / 公告页主文案零改动 ✅ / 登录跳转链路不受影响 ✅

### 13.10 大蓝海支持者徽章（✅ 2026-11-22 00:45，Pixel7 开关验收全过）
- **定位**：reward 资助支付成功后发放的纯纪念徽章（无等级差异、重复支付不重复发、不附带任何特权/流量倾斜/审核优待/额度加成）
- **后端**：`user_badges` 表（user_id 主键幂等，awarded_at 留首次获取时间）；grantProduct reward 分支 `grantSupporterBadge`（INSERT ON CONFLICT DO NOTHING）；`GET /api/user/badge`（authRequired → has/badgeId/awardedAt）；`.env DEV_BADGE_UID` 调试开关（启动幂等 upsert，**生产验收后必须清空**，当前已置空）
- **Flutter**：`CloudSupporterBadge`（cloud_models，失败静默 none）+ `fetchSupporterBadge()`（与 fetchUserProfile 并行拉取）；徽章卡片 `_SupporterBadgeCard` 在 ProfileCertGallery 画廊第一位（badge 参数，150×96 羊皮纸+虚线内框+`_ShipWheelPainter` 船舵线条暗金+自愿资助纪念·时间）；点击跳 `SupporterLetterPage`（圆形徽章 asset 图 assets/images/supporter_badge.jpg + 敬语正文四段 + 获取时间回填 + 纯纪念装饰小字）
- **验收（Pixel7）**：开关开→uid23 证书区徽章卡+船舵装饰+时间回填 ✅ / 点击跳感谢信文案正常 ✅ / 关开关+清标记→下拉刷新回到占位不展示 ✅ / 幂等验证（重复发放 granted:false 保留首次时间）✅ / 生产 badge 接口 has:false ✅
- **真实支付验收待办（支付宝审核通过后）**：安卓真机支付 → 徽章自动出现；iOS IAP 后续接入时在 IAP 回调处调 grantSupporterBadge 即可共用

- **13.10 文案微调（2026-11-22 00:50）**：感谢信正文第三句更新为「您的支持，会用来支付服务器、存储、内容审核和项目运营成本，让这片海继续存在。」（Pixel7 渲染确认）

### 13.11 徽章 UI 自测专用账号（2026-11-22 00:58，仅内部使用勿外传）
- **uid=24**（nickname 徽章测试号，account badge-test-internal，bcrypt 密码 `666666`，走 uid 数字分支登录：账号输 `24`）
- 预置状态：user_badges 已预置 supporter 徽章（获取时间 2026-11-22 00:55:31），0 打卡 0 日志
- 用途：Pixel7 模拟器徽章页面 UI 自测（证书区徽章卡/感谢信/时间回填），登录即见徽章，无需真实支付
- **不对外提供给普通用户**；与 DEV_BADGE_UID 开关互不影响（该账号走真实表标记）
- 验收记录：uid24 登录→船长页徽章卡（certificates 为空时徽章独立展示）✅ / 点击进感谢信文案+时间回填 ✅

- **13.11 补充（2026-11-22 01:05）空白对照号**：**uid=25**（nickname 空白对照号，account badge-blank-internal，密码同 `666666`，账号输 `25`）——无徽章/无证书/无日志干净对照；badge 接口 has:false，船长页证书区显示「连续21天登岛即可获得证书」占位 ✅。与 uid24（徽章测试号，有徽章）成对用于 Pixel7 UI 对照验证，均仅内部使用勿外传

### 13.12 术语规范改版「支持开发者」（✅ 2026-11-22 02:40，Pixel7 验收）
- **术语红线**：全 lib 禁用词清零（赞赏/资助/打赏/捐赠/不支持退款）；后端注释同步清零；product_title=「大蓝海-支持开发者」
- **announcement_page**：按钮单行「支持开发者」（副文案已按用户要求删除，恢复 50 高）+ 底部小字「所有核心功能永久免费 · 支持行为完全自愿」；公告正文改定稿：「可以选择支持开发者」+「购买完全自愿，将获得一枚电子纪念徽章，暂无任何特权、回报…」
- **reward_sheet**：标题「支持开发者」/说明「选择金额，帮助项目持续运营」；温馨提示（理性消费/未成年人请勿消费/电子纪念徽章/不解锁任何额外功能权益曝光加成）；按钮双态（未选置灰「请选择金额」不可点 / 选中「确认支持 ¥N」）；结果流：PAID→pop+「感谢支持」toast(2s 不跳转)、CLOSED/超时→静默关面板、唤起/下单失败→「支付未完成，请重试」保留档位
- **感谢信**：+「您累计支持：{N}元」（badge 接口 totalSupported=PAID reward 单合计，uid24 实测 78 元）；iOS 退款提示行 Platform.isIOS 分支（安卓不渲染）
- **徽章卡**：副文案「支持开发者纪念 · 时间」；models fallback subtitle 同步
- **验收**：面板初始化无默认选中置灰 ✅/选档变「确认支持 ¥30.00」✅/失败态保留档位+无渠道名 ✅/感谢信累计支持 78 元 ✅/安卓无退款行 ✅/全文禁用词清零 ✅
- **待真机验收**：「感谢支持」toast 实图（模拟器无支付 App，launchUrl 失败走错误分支不进轮询——真机唤起成功后才走轮询 PAID→toast）；iOS IAP + Apple 退款提示渲染

- **13.12 感谢信视觉改版（2026-11-22 02:58）**：删除正文顶部重复金色大标题（导航栏承担定位）；徽章图换裁剪版 `supporter_badge_round.jpg`（PIL 自动检测金色 bbox 裁除图内「大蓝海支持者」小字，原图 1920² 徽章圆心(960,888) 半径336）并放大 190 占满原圆环尺寸；金色圆圈外环移除、阴影保留

### 13.13 徽章他人主页展示 + 隐私分视图（✅ 2026-11-22 03:15，Pixel7 验收）
- **后端**：新增 `GET /api/user/:uid/badge`（optionalAuth）——⚠️ **totalSupported 恒不下发（隐私保护从后端切断）**，仅本人接口 /api/user/badge 返回累计金额
- **Flutter**：user_profile_page 并行拉取 fetchUserBadge(uid) → ProfileCertGallery(badge, badgeIsSelf:false)；详情页 `isSelf` 分支：本人显示「您累计支持：N元」，他人隐藏（isSelf + 后端双保险）；导航栏标题统一「支持者徽章」
- **验收（uid25 看 uid24）**：他人主页证书区徽章卡展示 ✅ / 点击进他人详情**无累计行**（uid24 实际有 78 元但不显示）✅ / 本人视图累计 78 元正常 ✅ / uid23 测试标记已清除（用户实际未购买，不污染真实账号）✅

### 13.14 Flutter 端支付宝原生接入 tobias（✅ 2026-11-22 完成 + 模拟器全链路验证 + release 包已出）

**插件选型**：
- ❌ `flutter_alipay`（1.0.0，2020 年发布）6 年未更新、Dart 3 incompatible，**物理上装不进本项目**
- ✅ **tobias ^5.3.4**（106 likes / 36k 下载 / 原生支付宝 SDK 支持 alipay.trade.app.pay，API 即「传 orderString 唤起」）；6.0.0 要求 Dart ≥3.13（本项目 3.12.2 用不了），升级 Flutter 后可考虑
- ⚠️ AGP 9 + tobias consumer proguard 不兼容坑见 §7 末条（pub cache 修复，cache 重装会回退）

**代码改动（仅支付范围）**：
- `pubspec.yaml`：+ tobias ^5.3.4（url_launcher 保留未删）
- `lib/widgets/reward_sheet.dart` `_submit` 唤起段改造：`Platform.isAndroid` 分支调 `Tobias().pay(order.orderString)`；**iOS 分支不走支付宝、不调用插件**（提示「当前系统暂不支持在线支付」并复位按钮）；resultStatus **9000/8000 → 进入轮询**，**6001/4000/6002 → 「支付未完成，请重试」保留档位**；订单状态权威来源不变 = 后端 notify 改库 + 前端轮询 `GET /api/pay/order/:no`（**不依赖插件回调判定订单状态**）
- `android/app/proguard-rules.pro`（新建）：支付宝 SDK keep 规则（当前 release 未开 minify 无实际作用，未来开 R8 兜底）
- 后端 alipay.js 维持手写 RSA2，未引入 Node SDK ✅

**模拟器验证（emulator-554 Pixel x86_64 debug 包，2026-11-22）**：
- 无支付宝 App → tobias SDK **自动兜底拉起内置 H5PayActivity 收银台**（FLAG_SECURE 防截屏：screencap 0 字节即它的特征；`dumpsys activity activities | grep topResumedActivity` 可确认前台）
- 关闭收银台 → 回调 `resultStatus=6001`（用户取消）→ App 捕获 →「支付未完成，请重试」+ 档位保留，**不崩溃** ✅
- adb 自动化坑：ModalBottomSheet 内确认按钮实际 y=2208（物理 1080x2400），缩略截图估算偏差 100+px；用 PIL 扫金色像素带定位最准

**Release 打包规范（双平台产物分流）**：
| 产物 | 命令 | 支付逻辑 |
|---|---|---|
| 安卓 `.apk` | `flutter build apk --release` | 集成 tobias 支付宝 SDK（安卓渠道） |
| iOS `.ipa` | `flutter build ipa --release` | **不引入 tobias，走苹果原生 IAP 内购**（后续单独开发） |

- 同一套 Flutter 代码，靠 `Platform.isAndroid` 平台分支自动分流：Android 加载 tobias 支付逻辑，iOS 跳过支付宝进入 IAP 流程；**打包互不冲突，无需改代码切换**
- 打包顺序建议：先打安卓 apk（H5 兜底链路 2026-11-22 已模拟器验证；**原生 App 唤起分支待真机验收**：`app-release.apk` 54.1MB，正式签名 CN=dalanhai/浩海星辰，SHA-256 f527fe30…）→ 再配 IAP 商品打 iOS ipa
- 真机验收要点：装正式支付宝 App 的安卓机 → 登录 → 开服公告 → 支持开发者 → 选档位确认 → 应**原生唤起支付宝 App**（非 H5 收银台）→ 支付后 App 轮询查单 → 「感谢支持」toast

### 13.15 赞赏档位调整：256 → 198（✅ 2026-11-22 17:40，两端统一 + 生产部署 + 模拟器验证）

- **最终档位（安卓支付宝 / iOS IAP 共用一套）**：`1 / 6 / 30 / 68 / 198 元`（历史：§13.9 时期为 1/6/30/68/256，本次仅 256→198，68 保留）
- **前端**：`reward_sheet.dart` `_tiers = [1, 6, 30, 68, 198]` + 文件头注释同步；其余文案/UI 零改动
- **后端**：`src/alipay.js` `REWARD_TIERS = ['1.00','6.00','30.00','68.00','198.00']` + 白名单拒绝文案同步；已部署生产（scp alipay.js + pm2 restart，2026-11-22 17:41）
- **生产 curl 验证**：正例 1/6/30/68/198 全 200 + orderString；负例 98/256 全 400「仅支持固定档位：1 / 6 / 30 / 68 / 198 元」✅（curl 需 `--ssl-no-revoke` 绕过本机代理 schannel 吊销检查，见 §7 代理坑）
- **模拟器验证（Pixel7 debug 包）**：面板 5 chip 显示 1/6/30/68/198 ✅；68/198 两档实点下单 → H5PayActivity 拉起 ✅ → back → 6001 → 「支付未完成，请重试」不崩溃 ✅（5 chip 物理中心 x≈134/331/529/726/934，y≈1900；确认按钮 540,2208）
- 测试单均为 UNPAID，30 分钟后端自动关单，不污染数据
- **2026-11-23 IAP 产品 ID 更新**：ASC 实际配置为无点号 `support1/6/30/68/198`（原计划 support.N 带点号作废）——`iap_service.dart` productIds/productIdForTier、`src/appleiap.js` IAP_PRODUCTS 白名单、§13.16 表已三处同步，生产已重新部署

### 13.16 苹果 IAP 内购接入（✅ 2026-11-22 18:20 代码全量完成 + 生产后端上线；iOS 真机验收待用户 TestFlight）

**分工**：WorkBuddy 写码 + 编译保证 + 安卓链路回归；用户用本机证书打 IPA → TestFlight → iPhone 真机 + 沙盒账号全链路验收（唤起支付/上传凭证/后端验签/订单 PAID）。

**档位与产品 ID（iOS IAP 与安卓支付宝共用一套档位；⚠️ 产品 ID 以 ASC 实际配置为准——无点号 supportN，2026-11-23 由 support.N 更新）**：
| 档位 | 产品 ID（App Store Connect 需配置为消耗型） |
|---|---|
| 1 元 | `support1` |
| 6 元 | `support6` |
| 30 元 | `support30` |
| 68 元 | `support68` |
| 198 元 | `support198` |

**后端（grandblue-server，已部署生产 2026-11-22 18:10）**：
- `src/appleiap.js`（新增）：verifyReceipt 验签 + 幂等发货 + 补单轮询。**双地址自动分流**：先打生产 `buy.itunes.apple.com/verifyReceipt`，返回 status=21007（沙箱收据）→ 自动转 `sandbox.itunes.apple.com` 重试（Apple 官方推荐模式，沙盒账号无需配置区分）
- 安全闸：①bundle_id 必须匹配 `APPLE_BUNDLE_ID`（防他 App 收据冒充）②product_id 白名单映射金额（`IAP_PRODUCTS`，**服务端映射金额，客户端不传金额，杜绝篡价**）③transaction_id 防重放（同一苹果交易全局只发一次货）④订单归属强校验（userId 一致 + 商品一致）
- 幂等发货：`UPDATE ... WHERE status='UNPAID'` 原子变更 changes=1 才发货，与支付宝链路同口径；交付复用 product_id='reward' → 支持者徽章（user_badges 主键幂等）
- orders 表 v3.1 迁移（幂等）：+`pay_type`（默认 'alipay'，IAP 单='apple_iap'）+`iap_product_id`+`iap_transaction_id`+`iap_receipt`
- 新接口：`POST /api/pay/apple/order`（authRequired，{productId}→{outTradeNo,amount}）；`POST /api/pay/apple/verify`（authRequired，{receipt, outTradeNo?}→PAID；**outTradeNo 可选**——恢复购买/补单场景前端拿不到单号，后端验签拿 product_id 后自动定位该用户最近一笔同商品 UNPAID IAP 单）；查单复用 `GET /api/pay/order/:no`
- 补单兜底（双保险）：**后端定时轮询** `sweepAppleUnpaid`（默认 5 分钟，`APPLE_IAP_SWEEP_INTERVAL_MIN` 可调；用留档 iap_receipt 重试验签；网络临时失败不关单，>30min 未付自动关单）+ **前端恢复购买**（reward_sheet iOS 面板底部「已支付未到账？恢复购买」→ restorePurchases → 未完成交易重推 → 无单号验签补发）
- 生产 `.env` 已加 `APPLE_BUNDLE_ID=com.kaitengguan.dalanhai`；可选 `APPLE_IAP_SHARED_SECRET`（ASC App 专用密钥）未配——验签不依赖它，后续需要收据高级信息再补
- 生产 curl 验证：5 档正例全 200（金额映射 1/6/30/68/198.00）、负例 support.98 → 400；本地实例假 receipt 实测打到苹果生产验签地址得 status=21002（网络往返+状态解析全通）

**Flutter 端**：
- pubspec：+ `in_app_purchase ^3.3.1`（flutter.dev 官方）+ `in_app_purchase_storekit ^0.4.17`（显式声明，enableStoreKit1 直接调用）
- `lib/services/iap_service.dart`（新增）：IapService 单例。**⚠️ StoreKit1 回退是关键**：in_app_purchase 3.x iOS 默认 StoreKit2（verificationData=JWS 交易串），后端 verifyReceipt 老接口需要 SK1 base64 收据 → `ensureConfigured()` 里 `InAppPurchaseStoreKitPlatform.enableStoreKit1()`，**必须在 InAppPurchase.instance 首次访问前调用**（deprecated 警告属预期——SK1 未来会被 Apple 移除，届时需升级 App Store Server API JWS 验签路线）
- `lib/services/cloud_api.dart`：+ `createAppleIapOrder(productId)` / `verifyAppleIapReceipt({outTradeNo?, receipt})`
- `lib/widgets/reward_sheet.dart` iOS 分支：initState（仅 isIOS）订阅 purchaseStream；确认按钮 → 建本地单 → queryProducts → buyConsumable → stream 回调：purchased/restored → 上传收据验签 → PAID → completePurchase + pop + 「感谢支持」toast；error → complete + 「支付未完成，请重试」；pending → 静默等待；**验签失败不 complete**（交易保持未完成，后端轮询补单 + 面板重开自动重推）——restored 则 complete（历史重放交易，避免循环投递）
- Android 分支代码零改动（tobias 支付宝链路原样；Platform.isIOS 分支先行 return，Android 走原逻辑）

**验证状态（2026-11-22）**：
- analyze：三改动文件 0 error（1 个 enableStoreKit1 deprecated info 属预期）
- 回归专项 test/regression_fixes_test.dart：6/6 全过 ✅
- Pixel7 安卓回归：新包（含 IAP 代码）198 档支付宝链路完整拉起 H5PayActivity + 6001 处理，行为不变 ✅
- ⚠️ test/widget_test.dart 2 个断言失败为**历史遗留**（widget_test.dart 自 2026-08-07 未更新，其「今日出海」可见断言与 §13.7 banner 顺序修正「默认首屏必为开服公告」冲突；本次 IAP 改动与 banner 无交集），后续单独修复
- release APK 已出（54.5MB）；**iOS 验收前置条件**：ASC 配置 5 个消耗型 IAP 商品（support.1/6/30/68/198，对应价格等级 1/6/30/68/198 元）+ 沙盒测试账号

## 14. 数据收集与隐私清单（2026-11-22 建档，数据流变更时必读必更）

> 本章是 App 内「隐私政策」弹窗（`lib/pages/account_settings_page.dart` `_showPrivacy`）与各应用商店隐私政策申报的**唯一事实来源**。
> **同步纪律：任何涉及数据收集/第三方服务的改动，必须先更新本章，再同步隐私政策文案**（App 弹窗 + 商店隐私申报），防止申报与实现脱节。

### 14.1 我们收集的信息（服务端 grandblue.db 入库）

| 类别 | 内容 | 对应存储 |
|---|---|---|
| 账号信息 | 手机号或邮箱（登录标识）、账号类型、昵称、头像、uid、注册/登录时间、密码哈希（bcrypt 单向加密，不存明文） | users / sessions |
| 打卡记录 | 岛屿 ID、打卡日期、连续天数（用户主动打卡产生） | user_island_checkins |
| 发布内容 | 帖子文字/图片/视频、评论、@提及（用户主动发布；媒体文件存阿里云 OSS） | posts / comments |
| 互动数据 | 点赞、关注/粉丝关系、举报记录、拉黑名单、私信会话与消息、群聊消息 | posts/likes/follows/reports/blocks/dm/group |
| 订单信息 | 商户订单号、用户 uid、商品与金额、订单状态、支付渠道交易号；支付宝单额外存买家 ID 与通知原文留档；Apple 单额外存收据（base64，仅用于验签与补单）与苹果交易号 | orders |
| 支持记录 | 支持者徽章获取时间；累计支持金额（**仅本人可见，绝不下发他人**，§13.13） | user_badges / orders 聚合 |
| 安全风控 | IP 地址（限流、风控分级）、人机验证挑战记录、异常行为标记、验证码发送日志、登录会话令牌 | risk_flags / captcha / 各类 log / sessions |

### 14.2 信息的使用方式

- 仅用于：提供核心服务（打卡/社区/消息）、内容安全审核、防刷防攻击风控、支付订单发货与对账、账号找回与注销
- 不用于：用户画像广告、数据挖掘转售、任何与产品功能无关的场景

### 14.3 第三方服务与数据流转

| 第三方 | 用途 | 传输的数据 |
|---|---|---|
| 阿里云 OSS | 用户媒体文件存储（头像/帖子图片视频） | 媒体文件本身 |
| 阿里云内容安全（Green-cip） | UGC 文本/图片/视频合规审核 | 待审核的文本与媒体 |
| 阿里云短信 | 注册/找回密码验证码 | 手机号、验证码 |
| SMTP 邮件服务 | 邮箱验证码/密码找回 | 邮箱地址、验证码 |
| 支付宝（Android） | 「支持开发者」App 支付 | 订单号、金额（SDK 直连支付宝，本服务端仅接收交易结果） |
| Apple App Store（iOS） | 「支持开发者」内购 | 收据（验签发货后留档） |

### 14.4 承诺与用户权利

- 绝不出售、绝不为营销目的向第三方共享用户个人信息
- 存储于加密服务器（HTTPS 全链路 + 云端数据库）
- **账号注销**（§12）：closed 匿名化，账号标识/昵称/头像/内容脱钩
- 密码自助找回；举报 24 小时内响应（EULA 守则第 4 条）
- 未成年人：温馨提示不鼓励消费（§13.12）；无任何面向未成年人的营销设计

### 14.5 隐私政策文案同步位置

1. App 内弹窗：`lib/pages/account_settings_page.dart` → `_showPrivacy`（用户侧简版，覆盖 14.1~14.4 要点）
2. 对外公示网页：**dalanhai-privacy-public** 独立仓库（github.com/g773831275-droid/dalanhai-privacy-public，GitHub Pages：https://g773831275-droid.github.io/dalanhai-privacy-public/privacy-policy.html）——App Store Connect「隐私政策 URL」指向该页。V2.0（2026-11-23）已按本章口径全面重写并上线生效；App Store Connect 隐私政策 URL **无需变更**（URL 不变，内容已更新）
3. 三层分离纪律：**AGENTS.md §14 = 内部开发规范（唯一基准，含表名字段）** / **privacy-policy.html = 对外公示文案（用户可读，禁止出现内部路径/表名/实现细节）** / **App Store 隐私申报 = ASC 勾选表（按 14.6 映射填报）**。数据流变更时三层同步更新

### 14.6 App Store「隐私详情」（App Privacy）申报勾选映射

> ASC 后台 App Privacy 页面按此表填报（2026-11-23 口径，替代旧版「未收集数据」声明）。
> 总原则：所有类别均 **不用于跟踪（Tracking = No）**（App 不接入任何广告/跨 App 追踪 SDK）；所有类别均 **与用户身份关联（Linked = Yes）**（账号体系实名化）；用途统一为 **App Functionality**。

| Apple 数据分类 | 数据类型 | Linked | Tracking | 用途 | 对应本项目数据 |
|---|---|---|---|---|---|
| Contact Info（联系信息） | Email Address | Yes | No | App Functionality | 邮箱登录标识、找回密码 |
| Contact Info | Phone Number | Yes | No | App Functionality | 手机号登录标识、短信验证码 |
| Identifiers（标识符） | User ID | Yes | No | App Functionality | 用户 uid（订单/内容归属） |
| User Content（用户内容） | Other User Content | Yes | No | App Functionality | 帖子文字/媒体、评论、私信、群聊、打卡记录 |
| Purchases（购买） | Purchase History | Yes | No | App Functionality | 订单号/商品/金额/交易号/IAP 收据 |
| Usage Data（使用数据） | Product Interaction | Yes | No | App Functionality | 点赞/关注/拉黑等互动记录 |
| Diagnostics（诊断） | Other Diagnostic Data | Yes | No | App Functionality | IP 地址（限流风控）、人机验证记录、异常行为标记 |

**不申报**（当前不收集）：Location、Health、Financial Info（我们接触不到支付宝/苹果侧的卡号余额等支付工具信息）、Browsing/Search History、Sensitive Info、Contacts、Crash Data（未接崩溃收集 SDK）。

**变更纪律**：接入崩溃收集 SDK、广告 SDK、统计 SDK 或新增收集类别时，先更新 14.1 → 同步 privacy-policy.html → 再按本表更新 ASC 申报。
