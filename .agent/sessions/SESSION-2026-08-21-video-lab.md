# SESSION-2026-08-21-video-lab

## 目标

在现有 Flutter Android/OpenHarmony 客户端中加入最小真实视频生成、文本/视频模型选择和厂商官方付费入口。双端模拟器验证是目标之一，但只有实际运行后才能标记 `passed`。

同日后续目标：把单段字幕卡升级为本地三镜头漫剧模板，加入文本、图片、视频、声音四类模型选择和不可误解的 AI 真实性字段，同时保留旧 `video-jobs` 兼容接口。

最终目标：用六张固定首尾帧让 Wan 2.7 生成 3 段真实分镜 MP4，在服务端配音/字幕/合片，并在主 App 内嵌播放最终 MP4；GIF 仅作预览。

## 实现

- 新增 Video Lab 的 Domain、HTTP Repository、Controller 和响应式页面。
- 新增 Python 标准库 HTTP 服务与 FFmpeg 引擎，提供目录、创建任务、轮询、GIF 和 MP4 Range 接口。
- 免费路径为 `manual + local_ffmpeg_slides`；千问与 Wan 仅展示 `requires_configuration`，不在手机保存 Key。
- 付费入口仅允许 `help.aliyun.com` HTTPS 地址，点击后复制给系统浏览器使用，不在客户端收款。
- Android 本地 HTTP 使用 `10.0.2.2`；OpenHarmony 使用经过验证的 HDC 映射。release 仍只允许 HTTPS。
- 手机导航从 Drawer route 收敛为普通正文页切换，避免 CPF-Flutter 冷启动焦点/布局断言。

### 三镜头漫剧升级

- 本地 Pipeline 固定为 `《月背最后一单》`，使用三张项目自有 ImageGen 画面、Windows 系统 TTS 和系统 FFmpeg 生成三镜头配音成片。
- Job 与 Output 同时返回 `executionKind=template`、`visualSource=fixed_project_assets`、`generatedForRequest=false`、`containsAiGeneratedAssets=true`、`assetProvenance=openai_imagegen_project_assets`、`templateStoryTitle` 和 `visualWarning`；本次任务不调用 AI，用户输入不会触发重新绘图，但固定画面本身来自有记录的 ImageGen 项目素材。
- 模型目录扩展为文本/图片/视频/声音四组。云端显示 `qwen3.6-plus`、`wan2.7-image-pro`、`wan2.7-i2v-2026-04-25`、`cosyvoice-v3.5-plus`；只有 Wan 视频 Adapter 已实现，其余三项仍为 `requires_configuration`。
- Wan 默认关闭，仅在服务端显式 enable + Key 时可用。Provider Key 只允许在可信服务端，不默认搜索 `key.txt`或 D 盘；App 只复制官方价格/充值链接，不收款。
- Video Lab OpenAPI 新增 `comic-jobs`、阶段代码、三条镜头状态、manifest/script 输出与真实性字段；旧 `video-jobs` 保留为 legacy。

### Wan hybrid 与成片播放升级

- hybrid Pipeline ID 为 `wan_fixed_frames_motion_comic`，组合 `local_storyboard_template + fixed_moon_courier_assets + wan2.7-i2v-2026-04-25 + windows_sapi_huihui`。
- Job/Output 返回 `executionKind=hybrid`、`visualSource=fixed_project_assets`、`generatedForRequest=true`、`containsAiGeneratedAssets=true`、`assetProvenance=openai_imagegen_project_assets`、`templateStoryTitle`、`visualWarning` 与 `modelExecution={text: local, image: pre_generated, video: cloud, voice: local}`。
- 三镜头各自包含 `firstFrameUrl`、`lastFrameUrl`、`motionPrompt` 和嵌套 `videoTask`。供应商 MP4 下载并标准化后按顺序合片，Output 声明 `compositionType=shot_videos_concat`、`sourceClipCount=3`。
- script 不包含 `videoTask`；manifest 包含首尾帧路由/哈希/素材、镜头任务和 `providerVideoSha256`，不包含供应商临时 `video_url`。
- 主 App 使用 Flutter `video_player` OpenHarmony 适配打开同源最终 `videoUrl`；GIF 仅作预览。

## 较早单段视频基线（历史）

- `passed`：格式检查 42 files、0 changed；Flutter analyze 0 issues；Flutter tests 122/122。
- `passed`：Python tests 8/8；FFmpeg/ffprobe 输出 4 秒、720×1280、H.264/yuv420p + AAC。
- `passed`：Android 15/API 35 x86_64 最终 APK 安装、冷启动导航、真实生成和 GIF；较早候选 10 页矩阵。
- `passed`：HarmonyOS 6.1.1/API 24 x86_64 安装 API 20 配置 HAP、9/10 页、模型/付费入口、真实生成和 GIF。
- `failed`：DevEco signed debug HAP，原因是本机未配置调试签名；未写入签名材料。
- `not run`：鸿蒙设置页和最终 MP4 复制反馈、API 20 专用镜像、双端真实手机、云模型推理与支付。

### 本地三镜头模板的历史验证

- `passed`：Video Lab OpenAPI 3.1.0 YAML、本地引用、路径参数与实现字段形状检查，12 paths、12 operations、60 refs、0 unresolved；独立语义 linter `not run`。
- `passed`：Dart format 42 files、0 changed；Flutter analyze 0 issues；Flutter tests 130/130，包含首帧 1px 到 320px 的网格回归。
- `passed`：Python/FFmpeg/Windows TTS 漫剧服务测试 19/19；实际成片 9.041814 秒、720×1280、H.264/yuv420p + AAC 44.1 kHz mono，三镜头与 GIF 均通过。
- `passed`：Android 15/API 35 x86_64 当前 APK（156,375,462 bytes，SHA-256 `0F4A9614ED70111642BAE9C45D3121413162ACCED62B40AE0800A4B7E60BCB98`）安装和两次冷启动；500 字 Job `8ffd4422-6222-4608-a15f-1ebb13e068e4` 实际生成，501 字被输入层限制在 `500/500` 且无新 POST。此前候选的四类模型、云端禁用边界、GIF 与 MP4 Range 206 完整链路已通过。
- `passed`：HarmonyOS 6.1.1/API 24 x86_64 安装当前 API 20 配置 no-codesign HAP（100,523,296 bytes，SHA-256 `4F815722FB190D34C7497B86B14083759BA650DA23D5C211FA0F0885D62CA59A`）；500 字 Job `bea81cd0-e457-47eb-a7f8-a2553626098d` 实际生成，501 字被输入层限制在 `500/500` 且无新 POST。此前候选的四类模型、云端禁用边界、GIF 与 MP4 地址复制完整链路已通过。这是 API 24 对 API 20 构建的兼容验证，不是 API 20 专用镜像验证。
- `not run`：当时的百炼四类云模型 HTTP Adapter、真实推理、费用和支付。后续已实现 Wan 视频 Adapter，但真实付费调用仍未运行。

### Wan hybrid 当前验证

- `passed`：Video Lab OpenAPI 0.3.0 YAML、92 个本地引用、所有路径参数、唯一操作 ID 与 14 个 local/hybrid 后端构造器形状实例；15 paths、15 operations、0 unresolved。独立 OpenAPI 语义 linter `not run`。
- `passed`：Dart format 44 files、0 changed；Flutter analyze 0 issues；Flutter tests 142/142；Python tests 30/30（含离线假 Wan Provider）。
- `passed`：Android APK 157,402,618 bytes，SHA-256 `09677D2940743DCB39033C982D9C38587EFA8A56ED97F841C6170059C2AC362A`；OpenHarmony x64 unsigned HAP 103,749,706 bytes，SHA-256 `4EB4E6709B8961B17B83E91CC7BB36EFA9A5E80D820A9E63B6D317E3BEB6A807`。
- `passed`：CPF `video_player` 2.10.1 与 `video_player_ohos` 已进入依赖锁、自动注册与双端构建。Windows 跨盘 Pub 缓存会使 Hvigor 拒绝插件绝对 `srcPath`；改用与项目同盘的用户级 Pub 缓存后 HAP 构建通过，未修改全局 Git 配置。
- `passed`：Android API 35 最新 APK 完成本地模板 Job 并打开内嵌 MP4 播放页，视频时长 `0:09`，实际播放至 `0:09 / 0:09`，目标错误日志 0 命中。该项只验证播放器与本地模板媒体，不代表真实 Wan 效果。
- `not run`：Android/OpenHarmony 模拟器 E2E；构建通过不等于安装、生成、播放或跨端验收通过。
- `not run`：真实 Wan 付费请求、实际费用和视频效果；千问脚本、Wan 图片重绘和 CosyVoice Adapter 仍未实现。

## 产物边界

- Android debug APK 与 unsigned/debug HAP 只作本机验证，不作为公开发行包。
- 生成媒体与模拟器证据不纳入 Git。
- MoneyPrinterTurbo 仅用于架构调研；本实现未复制其源码、品牌或素材。
- 三张本地模板首帧和三张匹配尾帧由 OpenAI 内置 ImageGen 于 2026-08-21 为项目生成，引用项目自有月球快递画面；来源与 SHA-256 见 `THIRD_PARTY_NOTICES.md`。
- Windows 系统 TTS 和 FFmpeg 是开发机外部依赖，仓库不捆绑其二进制或声音模型。
- 原始 Windows/Electron 项目保持未修改；本轮未提交、未推送 GitHub。
