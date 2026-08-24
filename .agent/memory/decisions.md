# 工程决策

## 2026-08-20：移动端只做生成编排

- Flutter 客户端不运行大模型、不捆绑 FFmpeg、不保存供应商密钥。
- 默认 Provider 为可信后端中的百炼适配器，Wan2.2 作为可选独立后端。
- 演示模式使用确定性本地数据，不联网、不收费，且必须明确标记。

## 2026-08-20：契约优先

- `docs/api/openapi.yaml` 是客户端与后端的唯一 HTTP 契约。
- 创建/动作 POST 使用 `Idempotency-Key`；覆盖与状态迁移使用 ETag/`If-Match`。
- SSE 只做增量提示，REST 聚合资源为事实来源。

## 2026-08-20：平台和网络

- CPF-Flutter 固定 `oh-3.35.7-dev`；OpenHarmony 固定 API 20、`runtimeOS: OpenHarmony`、`deviceTypes: default`。
- Android 明文流量只在 debug manifest 开放；main/release 默认 HTTPS。
- Android 模拟器本地后端地址使用 `10.0.2.2`；OpenHarmony 使用设备可达地址。
- SDK 路径、签名、证书、`.env` 和用户生成资产不进入 Git。

## 2026-08-21：最小视频实验切片

- `services/basic_video_server` 只用于开发期真实媒体闭环，不冒充 AI 文生视频或生产后端。
- 手机提交提示词与本地模型 ID，服务端用 FFmpeg 生成 9:16 H.264/AAC MP4 和 GIF；提示词为 4–108 字。
- 本地服务无认证、无 CORS，最多 2 个活跃任务和 20 个本进程任务；生产部署必须另做 HTTPS、认证、持久队列、对象存储和配额。
- 千问/Wan 仅作为后端未配置的模型目录项；付费按钮只复制允许的阿里云官方链接，客户端不保存 Provider 密钥或支付信息。

## 2026-08-21：移动端全部页面导航

- CPF-Flutter debug 在 Android 冷启动关闭 `Scaffold.drawer` 时可触发 FocusInheritedScope/布局断言，页面本身经底部导航验证正常。
- 移动端“全部页面”改为普通 Scaffold body 切换，不再创建 Drawer route 或动态遮罩层；真实 API 35 模拟器冷启动回归通过。

## 2026-08-21：本地漫剧模板的真实性边界

- 免费路径必须真实生成三镜头、有配音、有字幕的 MP4/GIF，但画面固定来自项目自有 `《月背最后一单》` 素材，不随任意主题重新绘制。
- 服务端 Job 与 Output 均必须返回 `executionKind`、`visualSource`、`generatedForRequest`、`containsAiGeneratedAssets`、`assetProvenance`、`templateStoryTitle` 和 `visualWarning`；当前本地值固定为 `template`、`fixed_project_assets`、`false`、`true`、`openai_imagegen_project_assets`，分别表达本次任务未调用模型与固定画面的真实来源。
- 手机端不依据 `DEMO_MODE`、进度动画或输出文件是否存在来推断 AI 真实性，只展示服务端声明。
- 缺少固定素材、Windows 系统 TTS 或 FFmpeg 时明确失败或不可用，不能用提示音、文字卡、占位进度冒充漫剧。

## 2026-08-21：四类模型与云端入口

- Video Lab 模型目录按文本、图片、视频、声音四类分组；本地组合用于模板，`wan_fixed_frames_motion_comic` 用于受控 hybrid。
- 云目录 ID 固定为 `qwen3.6-plus`、`wan2.7-image-pro`、`wan2.7-i2v-2026-04-25`、`cosyvoice-v3.5-plus`。只有 Wan 视频 Adapter 已实现；文本、图片和 CosyVoice 仍为 `requires_configuration`。
- Wan 视频只在 `XINGMU_WAN_ADAPTER_ENABLED=true` 且受信服务端存在 `DASHSCOPE_API_KEY` 或运维者显式传入 `--dashscope-key-file` 时可用；可选 `BAILIAN_WORKSPACE_ID`。不默认搜索 `key.txt`、D 盘或原 Electron 项目。
- Provider Key 不得进入 Flutter、Git、请求/响应、日志或 manifest。App 只复制 `help.aliyun.com` 的官方价格/充值链接，不收款、不保存支付资料。
- Wan 真实付费调用、费用和效果均为 `not run`；离线假 Provider 测试不等于已验证付费能力。

## 2026-08-21：本地开发服务边界

- `comic-jobs` 是当前三镜头契约；旧 `video-jobs` 继续保留并标记 legacy，避免破坏上一轮客户端/测试。
- 本地服务无认证、无 CORS，只用于 loopback 或受信模拟器联调；正式部署必须另做 HTTPS、身份授权、持久化、配额和限流。
- Windows 系统 TTS 和 FFmpeg 是独立外部依赖，不放进 Flutter/Android/OpenHarmony 安装包，也不在 Apache-2.0 仓库中重新授权其二进制或声音模型。
- GIF/MP4 支持媒体 Range；manifest/script 使用普通 JSON 响应。结果路径保持同源，不向客户端暴露供应商临时 URL。

## 2026-08-21：Wan hybrid 固定首尾帧视频

- hybrid 固定使用 `local_storyboard_template + fixed_moon_courier_assets + wan2.7-i2v-2026-04-25 + windows_sapi_huihui`，三镜头各有一组 `firstFrameUrl`、`lastFrameUrl`、`motionPrompt` 和嵌套 `videoTask`。
- Job/Output 固定返回 `executionKind=hybrid`、`visualSource=fixed_project_assets`、`generatedForRequest=true`、`containsAiGeneratedAssets=true`、`assetProvenance=openai_imagegen_project_assets`、`templateStoryTitle`、`visualWarning` 与 `modelExecution={text: local, image: pre_generated, video: cloud, voice: local}`。
- 最终输出必须是三段供应商 MP4 标准化并顺序合片，声明 `compositionType=shot_videos_concat`、`sourceClipCount=3`；GIF 仅作预览。
- script 不包含 `videoTask`；manifest 包含镜头任务、首尾帧路由/哈希/素材与 `providerVideoSha256`，但绝不保存供应商临时 `video_url`。
- 镜头媒体只通过 `/v1/comic-jobs/{uuid}/shots/E01-SH0[1-3]/{first-frame.png|last-frame.png|video.mp4}` 同源路由提供，并支持 Range。
- 最终 MP4 应进入主 App 内嵌 `video_player` 页播放；不再把 GIF 预览当成用户所要的分镜视频。
