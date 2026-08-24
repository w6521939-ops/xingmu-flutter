# 变更日志

## 2026-08-20

- 建立“星幕 AI 漫剧”Android/OpenHarmony Flutter 客户端平台配置。
- Android 主清单加入联网权限，debug 独立开放本地明文调试。
- OpenHarmony 升级到 API 20/OpenHarmony/default 设备基线并补齐应用中文名。
- 新增项目/剧本/资产/生成/SSE/预算/导出 OpenAPI 3.1 契约。
- 新增 MVP、架构、安全、构建、许可证和第三方边界文档。
- 扩展 `.gitignore`，排除本机 SDK、签名、密钥、数据库和生成资产。
- 完成 Flutter 领域模型、Demo/HTTP Repository、Controller、九个响应式页面和 113 项测试。
- 补齐精准镜头生成、单任务重试、取消终态、排队剧本、冷启动运行/导出恢复，以及 320px 小屏和放大字体验证。
- HTTP 客户端对齐 OpenAPI，并加入强 ETag、Bearer、意图级幂等键、资源归属校验、Problem Details、HTTPS、分页和响应大小保护。
- 使用 image2 概念稿完成深色电影风首页，生成真实 Flutter 截图及应用内容全覆盖热力图验收报告。
- Android debug APK 构建通过；OpenHarmony API 20 unsigned HAP 构建通过，signed HAP 等待本机调试签名。

## 2026-08-21

- 新增独立 Video Lab 领域、Repository、Controller 与“模型与视频实验室”页面。
- 新增无第三方 Python 依赖的本地 FFmpeg 开发服务，支持模型目录、任务提交/轮询、GIF 预览和 MP4 Range 输出。
- 文本模型提供免费直接输入与未配置的千问选项；视频模型提供免费 FFmpeg 字幕卡与未配置的 Wan 选项。
- 付费入口只接受阿里云官方 HTTPS 域名并复制官方计费/充值地址；客户端不保存模型 Key、不代收款。
- 修复 Dart POST 缺少 `Content-Length` 导致模拟器无法创建任务的问题，并将 JSON 响应改为流式 2 MiB 上限。
- 本地服务统一 4–108 字边界，移除 CORS，并限制最多 2 个活跃、20 个保留任务。
- 移除移动端 `Scaffold.drawer` 路由，改为普通正文导航页，解决 CPF-Flutter 冷启动焦点/布局断言。
- 较早单段视频基线完成 122 项 Flutter 测试、8 项 Python/FFmpeg 测试、Android API 35 与 HarmonyOS API 24 x64 模拟器验证。
- 将 Video Lab 契约从单段字幕卡升级为本地三镜头漫剧模板，新增文本、图片、视频、声音四组模型目录与 `comic-jobs` 任务/结果资源；旧 `video-jobs` 保留为兼容接口。
- 本地模板固定使用项目自有 `《月背最后一单》` 三张画面、Windows 系统 TTS 与系统 FFmpeg；真实性字段固定为 `executionKind=template`、`visualSource=fixed_project_assets`、`generatedForRequest=false`、`containsAiGeneratedAssets=true`、`assetProvenance=openai_imagegen_project_assets`，任意输入不会重新绘图，同时如实披露固定画面的 ImageGen 来源。
- 新增三张 2026-08-21 OpenAI 内置 ImageGen 漫剧画面，并在第三方声明中记录其对项目自有月球快递画面的引用链；未使用 stock 或第三方 franchise 素材。
- 云目录统一展示 `qwen3.6-plus`、`wan2.7-image-pro`、`wan2.7-i2v-2026-04-25`、`cosyvoice-v3.5-plus`；只有 Wan 首尾帧视频 Adapter 已实现，且仅在服务端显式 enable + Key 时可用，其余三项仍为 `requires_configuration`。
- 修复 Android 冷启动首帧宽度暂为 0 时工具网格算出 `-6px` 卡片宽度的问题；极窄宽先按一列布局并把卡片宽度限制为非负，新增 1px 到 320px 回归。
- 本地模板阶段验证为 `passed`：OpenAPI 12 paths、12 operations、60 refs、0 unresolved；Dart format 42 files、0 changed；Flutter analyze 0 issues；Flutter tests 130/130；Python/FFmpeg/SAPI tests 19/19；9.041814 秒三镜头媒体；Android API 35 与 HarmonyOS API 24 x64 模拟器真实生成。这些是 hybrid 改造前的历史记录。
- 将 Flutter 故事输入上限由 240 统一为 OpenAPI/服务端的 500；全量 Flutter 130/130 重新通过。双端重建后，500 字实际生成与 501 字输入层硬限制（无 POST）均为 `passed`。
- 新增 `wan_fixed_frames_motion_comic` hybrid Pipeline：六张固定首尾帧分别生成 3 段 Wan MP4，再与本地 Huihui 配音、字幕合成 `compositionType=shot_videos_concat`、`sourceClipCount=3` 的最终 MP4；GIF 仅作预览。
- hybrid Job/Output 固定声明 `executionKind=hybrid`、`visualSource=fixed_project_assets`、`generatedForRequest=true`、`containsAiGeneratedAssets=true`、`assetProvenance=openai_imagegen_project_assets` 与 `modelExecution={text: local, image: pre_generated, video: cloud, voice: local}`。
- 新增镜头 `first-frame.png`、`last-frame.png`、`video.mp4` 同源 Range 路由和嵌套 `videoTask`；manifest 记录帧/供应商视频哈希，不保存供应商临时 `video_url`。
- Wan 只允许通过 `XINGMU_WAN_ADAPTER_ENABLED` + 服务端 `DASHSCOPE_API_KEY`（可选 `BAILIAN_WORKSPACE_ID`）或显式 `--dashscope-key-file` 启用；禁止默认搜索 `key.txt`或读取 D 盘原项目密钥。
- hybrid 与内嵌播放器改造后当前验证：Dart format 44 files、0 changed，Flutter analyze 0 issues，Flutter tests 142/142 `passed`，Python tests 30/30 `passed`；Android APK 157,402,618 bytes（SHA-256 `09677D2940743DCB39033C982D9C38587EFA8A56ED97F841C6170059C2AC362A`）重建 `passed`，OpenHarmony x64 unsigned HAP 103,749,706 bytes（SHA-256 `4EB4E6709B8961B17B83E91CC7BB36EFA9A5E80D820A9E63B6D317E3BEB6A807`）重建 `passed`。双端模拟器 E2E 与真实 Wan 付费调用/效果均为 `not run`。
- Video Lab OpenAPI 0.3.0 最终契约检查 `passed`：15 paths、15 operations、92 refs、0 unresolved，14 个 local/hybrid 真实构造器形状实例通过 JSON Schema 2020-12 验证；独立 OpenAPI 语义 linter 为 `not run`。
- 主 App 新增最终 MP4 内嵌播放边界，使用 CPF `video_player` 2.10.1 与 OpenHarmony 适配；依赖固定到 commit `97e9265ae2ab44c913d5d943ad68bec0c07a040e`，来源与 BSD-3-Clause 声明已记入第三方通知。
- Windows 上 CPF/Hvigor 要求原生插件 `srcPath` 为相对路径；项目与 Pub 缓存跨盘会构建失败。本轮使用 C 盘用户级 Pub 缓存重新解析依赖后 HAP 构建通过，未修改全局 Git 配置。
- 最新 Android APK 在 API 35 模拟器完成本地三镜头模板任务，点击“播放 MP4”进入内嵌播放器并实际播放 9 秒 H.264/AAC 成片至结束，目标错误日志 0 命中；该 smoke 仅验证播放器，真实 Wan 分镜视频与 OpenHarmony 播放仍为 `not run`。
