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
| Bundle ID | `com.kaitengguan.dalanhai`（双平台统一） |
| 商业模式 | App 内零收费、无 IAP。盈利靠「看广告补签」+ 客服微信引流 |
| 当前阶段 | P0~P5 代码完成 + UI 与 H5 1:1 对齐；**Flutter 版功能全量落地（岛屿/打卡/船长/UGC/集市 + 头像上传）**；**后端 v2.9.6 已上线生产**（v2.7 港口七接口 → v2.9.4 多岛屿分发 → v2.9.5 头像昵称审核 → **v2.9.6 社交关系全套：关注/粉丝/他人主页/双向拉黑/航级占位/黑名单管理/举报用户**）；**Flutter 端 v2.9.6 全量落地**（他人主页/日志详情关注按钮+···菜单/船长页双 Tab+入口收拢/全局关注状态）；**Flutter 网络层域名统一锁定 `https://api.idalanhai.com`**（session_store 单点管理，设备旧缓存自动清除）；2026-11-10 修复船长页打卡统计联动断层（cloudTotals 全历史口径）；软著补正材料已就绪待提交（~11/20 截止）；Apple 个人→组织迁移进行中（案例 103004430882）；⚠️ dalanhai-app/（Flutter）**还没有 git 仓库**，所有改动未 commit |

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
│   │   ├── colors.dart                 # AppColors 配色 + 12 个渐变（bodyGradient/heroGradient/detailGradient/goldTextGradient/titleGoldGradient/btnGoldGradient/streakPillGradient/gridDoneGradient/certGradient/tabbarGradient/mineBubbleGradient/islandCardGradient）
│   │   ├── typography.dart             # AppTypography 文字样式（Cinzel + 中文降级）
│   │   └── theme.dart                  # AppTheme.dark ThemeData
│   ├── data/
│   │   ├── models.dart                 # 数据模型（AppData/Certificate/Post/Captain/Report/Island/Group/GroupMessage）
│   │   ├── prefs.dart                  # Prefs 封装（3 个键：dalanhai_v2/used_names/eula）
│   │   ├── island_logic.dart           # 打卡纯逻辑（streak/totalDays/doCheckin/CheckinResult）
│   │   ├── data_store.dart             # DataStore（ChangeNotifier，全局状态管理）
│   │   ├── data_store_provider.dart    # InheritedNotifier 注入
│   │   ├── seed_data.dart              # 7 条种子帖 + 70+ 敏感词 + 6 群定义 + 种子消息 + filterText()
│   │   └── auth_service.dart           # 认证服务（dev 本地模式，prod 接 SMS）
│   ├── services/                      # v2.6.1 媒体上传规范 + 云端对接层
│   │   ├── media_rules.dart           # 媒体规范常量（与后端 MEDIA_RULES 对齐：10MB/2048/4张、30MB/30s/1条）
│   │   ├── image_pipeline.dart        # 图片压缩（flutter_image_compress，两档 78→70，>10MB 拦截）
│   │   ├── video_pipeline.dart        # 视频转码（video_compress；①原始时长>30s 拒 ②转码 ③输出≤30MB≤30s 校验）
│   │   ├── cloud_api.dart             # API 客户端（统一 {code,msg,data} + oss put-sign 直传 + media/sign + 发帖；v2.7 /api/post/* 七方法；v2.9.6 增 follow/follow-status/followers/following/userProfile/userPosts/likedPosts/unblock/blocklist + updateProfile bio + @visibleForTesting httpClientOverride 注入；onAuthenticated 静态回调 = 鉴权后落库 hook）
│   │   ├── cloud_models.dart          # 云端 DTO（CloudPost/CloudAuthor/PagedPosts/CloudComment/LikeResult/ReportResult/TagStat/AuthUser/LoginResult/CloudCaptain；v2.9.6 增 CloudUserProfile/Stats/Certificate/UserEntry/PagedUsers/FollowResult/FollowStatus + cloudCertIslandToLocal）
│   │   ├── session_store.dart         # v2.7 JWT 登录态持久化；**v2.9.6 域名单点**：defaultBaseUrl=https://api.idalanhai.com 唯一线上域名（代码单点管理，restore 强制注入并清除设备端持久化旧 baseUrl 残留键 dalanhai_api_base）
│   │   ├── social_state.dart          # v2.9.6 社交全局状态单例：MeState（本人云端 uid 缓存，登出 clear）+ FollowState（关注状态 Map 缓存 + notifyListeners，toggle 成功才写缓存——详情页/他人主页双向实时联动）
│   │   ├── cloud_feed.dart            # v2.7 云端瀑布流 Loader（分页累积/筛选/触底加载/点赞同步/拉黑移除/签名预热，ChangeNotifier；代际守卫 _gen 勿删）
│   │   └── media_sign_cache.dart      # 时效签名缓存（900s 过期重取，missing→占位图；v2.7 增 urlForKey 裸 key 头像渲染）
│   ├── tabs/
│   │   ├── islands_tab.dart            # 航海报 + 四岛卡片
│   │   ├── port_tab.dart               # 港口瀑布流（单列时间线 v2.9.2；作者头像点击→他人主页）
│   │   ├── bazaar_tab.dart             # 闹市群列表
│   │   └── captain_tab.dart            # v2.9.6 本人管理视角：hero 卡片（头像/昵称/航级标签占位/简介 + 竖排【编辑资料】【账号设置】双按钮）→ 统计栏（关注/粉丝可点弹列表）→ 征服证书横滚 → 航海日志/SAIL LOG 双 Tab（我的日志/点赞的日志）→ 页脚；**底部船员服务已收拢进账号设置页**；订阅 DataStore 打卡通知 → 600ms 去抖重拉 profile（统计联动修复，refreshDebounce 可测试注入）
│   ├── pages/
│   │   ├── island_detail_page.dart     # 详情页（大数字 + 21 天进度格 + 云端打卡；镜像同步传 totalDays 全历史口径）
│   │   ├── auth_page.dart              # 登录/注册（phone/email 云端 + password 本地 flag 模拟）
│   │   ├── post_detail_page.dart       # 帖子详情（多图轮播 + 点赞/举报）——本地种子数据
│   │   ├── cloud_post_detail_page.dart # 云端帖子详情（多图/点赞/评论/发评论；v2.9.6：本人无关注按钮、非本人金色关注按钮+顶栏···菜单收纳举报/拉黑、作者/评论头像点击→他人主页）
│   │   ├── user_profile_page.dart      # v2.9.6 他人主页/自身公开访客预览（同一页面双视角：头像区+航级标签+简介 → 关注/发消息/··· → 统计栏 → 证书横滚 → 日志流式列表；无编辑/无服务菜单）
│   │   ├── account_settings_page.dart  # v2.9.6 账号设置（入口=船长页 hero【账号设置】按钮）：三分组【船员服务】联系船务长/打卡提醒 →【黑名单】黑名单管理（路由）→【其他】隐私政策/下船登出（弹窗与逻辑沿用旧版）
│   │   ├── edit_profile_page.dart      # v2.9.6 编辑资料（头像上传复用 avatar_upload + 昵称 1-12 + 简介 ≤100，内联红字报错规范）
│   │   ├── blacklist_page.dart         # v2.9.6 黑名单管理独立页（分页 + 解除拉黑；解除不恢复原关注关系）
│   │   ├── composer_page.dart          # 发帖（文本 + 4 图片 + 7 标签；多岛屿分发 + 压缩管线）
│   │   └── group_page.dart             # 群聊（消息气泡 + 输入栏）
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
- Bundle ID: `com.kaitengguan.dalanhai`（双平台统一，不要改）
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

### 🟡 待用户操作（按优先级）

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

### 🚨 本机 Flutter 全局关闭 Windows 桌面编译支持

执行 `flutter config --no-enable-windows-desktop`。目的：防止 `flutter run`/`flutter devices` 误选中 Windows desktop 目标，避免 C 盘生成大量 CMake 编译中间文件占用空间。注意：仅本机全局配置，**不影响 Codemagic CI、Android / iOS 打包**。后续如需开发 Windows 桌面端，恢复命令：`flutter config --enable-windows-desktop`。

补充说明——开启 Windows 桌面编译仅在以下场景需要：① 开发、调试 Windows 桌面端版本（本地直接运行 exe）；② CI 打包产出 Windows 安装包。本项目现阶段只维护 Android / iOS 移动端，无桌面端计划，**保持关闭即可**，不影响移动端开发、模拟器调试、Codemagic 打包。

---

## 8. 常用命令

```bash
# 安装依赖
flutter pub get

# 运行（Android 模拟器或真机）
flutter run

# 测试
flutter test

# 静态分析（修复 lint）
flutter analyze

# 生成双平台图标（改完 icon.png 后跑这个）
dart run flutter_launcher_icons

# 构建 Android Debug APK
flutter build apk --debug

# 构建 iOS（需 Mac + Xcode）
flutter build ipa
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
- [ ] ⚠️ **dalanhai-app/ 还没有 git 仓库** —— 2026-11-08 起的全部 Flutter 改动（定位链路/多岛/头像/报错规范 + 2026-11-10 v2.9.6 社交/统计联动/入口收拢）都未 commit，任何误操作都无法回滚。尽快 `git init` + 补英文 commit
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
| 部署状态 | ✅ **v2.9.6 已上线**（2026-11-10；改代码后 scp 对应文件 + pm2 restart 即可，⚠️ 严禁上传 grandblue.db；本地验证 curl 必须 `export no_proxy=127.0.0.1,localhost`，生产验证走 `ssh → 127.0.0.1:3000`——安全组未放行 3000 公网） |
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