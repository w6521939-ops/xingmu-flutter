# 星幕 AI 漫剧移动端架构

## 1. 架构目标

本仓库是 Flutter 手机客户端，同时支持 Android 与 OpenHarmony。客户端负责项目管理、生成参数输入、资产审核、任务进度和失败重试；它不在手机上运行文生图、图生视频、TTS 或 FFmpeg 合成，也不持有百炼、对象存储或自托管模型的密钥。

当前版本已经实现 Demo Repository、OpenAPI 对齐的 HTTP Repository、显式 REST 刷新，以及独立的 Video Lab 任务切片。免费路径使用三张固定项目画面、Windows TTS 和 FFmpeg 生成本地模板 MP4；Wan hybrid 路径使用三组固定首尾帧生成三段真实镜头 MP4，随后本地配音、字幕并合片。GIF 在两条路径中都只是预览。

本地模板返回 `executionKind=template`、`generatedForRequest=false`。hybrid 返回 `executionKind=hybrid`、`generatedForRequest=true`、`modelExecution={text: local, image: pre_generated, video: cloud, voice: local}`、`compositionType=shot_videos_concat` 和 `sourceClipCount=3`。两者都使用 `visualSource=fixed_project_assets`、`containsAiGeneratedAssets=true`、`assetProvenance=openai_imagegen_project_assets`；hybrid 的 `generatedForRequest=true` 只指视频片段在本次请求中生成，不表示首尾帧会按用户故事重绘。

模型目录按文本、图片、视频和声音四类展示本地选项与百炼入口。当前只实现了 `wan2.7-i2v-2026-04-25` 首尾帧视频 Adapter，且只有服务端显式 enable + Key 才能使用；`qwen3.6-plus`、`wan2.7-image-pro` 与 `cosyvoice-v3.5-plus` 仍为 `requires_configuration`。真实 Wan 付费调用、费用与效果均为 `not run`。SSE、手机登录、安全持久会话、文件下载与系统分享属于下一阶段。

后端默认接入阿里云百炼，也可通过同一 Provider 接口接入独立部署的 Wan2.2。模型切换不能改变客户端领域对象和任务状态语义。

## 2. 系统边界

```text
Android / OpenHarmony Flutter App
  ├─ 演示仓库：内置示例数据，不联网、不产生真实费用
  ├─ 本地漫剧模板：Video Lab REST
  │    -> 固定《月背最后一单》画面
  │    -> Windows 系统 TTS + 系统 FFmpeg
  │    -> 3 镜头最终 MP4 + GIF 预览
  ├─ Wan hybrid：Video Lab REST
  │    -> 六张固定首尾帧 -> Wan 2.7 三段 MP4
  │    -> Huihui + FFmpeg -> 配音/字幕/shot_videos_concat
  │    -> 最终 MP4 + GIF 预览
  ├─ 远程仓库：Bearer + HTTPS + Idempotency-Key + If-Match
  │                 │
  │                 ▼
可信后端 API / REST（SSE 规划中）
  ├─ 身份认证与项目服务
  ├─ 剧本和资产服务
  ├─ 预算与配额服务
  ├─ 生成编排器 + 持久化任务队列
  ├─ Provider Adapter
  │    ├─ 百炼（默认）
  │    └─ Wan2.2（可选、自托管 GPU）
  ├─ 对象存储 / 短期签名 URL
  └─ TTS、字幕与 FFmpeg 成片服务
```

生产后端实现不属于当前仓库；双方以 [`docs/api/openapi.yaml`](../api/openapi.yaml) 为生产 HTTP 契约。`services/basic_video_server` 是独立的无认证、无 CORS、仅本机开发切片，其附加契约是 [`docs/api/video-lab-openapi.yaml`](../api/video-lab-openapi.yaml)。它不能替代身份、授权、预算、对象存储和持久任务队列。

## 3. 客户端分层

建议保持以下单向依赖：

```text
Presentation（页面、组件、路由）
  -> Application（用例、ViewModel、状态协调）
  -> Domain（实体、值对象、仓库接口）
  -> Data（Demo/HTTP 仓库、DTO 映射；SSE 规划中）
  -> Platform（安全存储、下载、分享、网络状态，规划中）
```

- 页面只渲染状态和接收用户意图，不拼接 URL、不解析供应商响应。
- Application 层处理防重复点击、加载/空/错误/离线状态和页面销毁后的回写保护。
- Domain 层不依赖 Flutter、Android 或 ArkTS 类型。
- Data 层只认识星幕后端契约；百炼/Wan2.2 的字段转换在服务端 Provider Adapter 中完成。
- Platform 能力必须有 Android/OpenHarmony 适配和不可用时的明确降级。

## 4. 生产目标生成流程

1. 用户新建项目，输入主题、故事梗概或已有剧本。
2. 后端异步生成严格结构化剧本，返回角色、道具、场景和分镜 ID。
3. 用户审核角色卡、场景卡和道具卡；后续提示词按固定 ID 和稳定顺序引用。锁定状态仅展示服务端明确数据，锁定变更尚未接入客户端。
4. 客户端创建 Generation Plan，固化剧本修订、参考资产、镜头集合和 Provider 策略。
5. 后端预估费用并预留预算，随后创建 Generation Run。
6. 编排器依次生成角色图、场景图、分镜首尾帧、镜头视频、配音和字幕。每个子任务具有稳定 ID、输入哈希、重试次数和输出资产 ID。
7. 当前客户端通过显式 REST 刷新校准状态；后续接入 SSE 后再使用 `Last-Event-ID` 做增量恢复。
8. 用户可重试失败镜头；Video Lab 已接入同源最终 MP4 内嵌播放，生产 Export 的限时下载与系统分享尚未接入。

模型供应商返回的临时结果必须由后端及时下载进受控对象存储，不能把供应商临时 URL 当成永久资产。

## 5. 本地三镜头漫剧模板

本地模板只验证一条可重复、零 Provider 费用的真实媒体流水线：

1. 客户端提交故事文本，并选择四个可用的本地目录项。
2. 服务端返回固定模板故事名 `《月背最后一单》`，并声明 `executionKind=template`、`visualSource=fixed_project_assets`、`generatedForRequest=false`、`containsAiGeneratedAssets=true` 与 `assetProvenance=openai_imagegen_project_assets`。
3. 三个镜头依次使用 `assets/showcase/motion_comic/` 下的三张固定画面。输入不同故事不会触发重新绘图，也不能声称画面与任意主题语义一致。
4. Windows 主机使用系统语音能力合成对白，系统 FFmpeg 完成 9:16 镜头推拉、字幕、配音、转场、MP4 和 GIF。
5. 任务通过稳定的 `stageCode` 和三条 `shots` 状态推进；成功结果返回同源 `previewUrl`、`videoUrl`、`manifestUrl` 和 `scriptUrl`。

### 5.1 Wan hybrid 镜头视频

1. 客户端仍提交本地脚本、固定图片和 Huihui，仅将视频模型改为 `wan2.7-i2v-2026-04-25`。
2. 服务端为每镜复制 `first-frame.png` 与 `last-frame.png`，返回 `motionPrompt` 和嵌套 `videoTask`，然后异步轮询供应商任务。
3. 成功后立即下载临时 `video_url`，验证大小/编码并转存为同源 `/shots/{shotId}/video.mp4`；客户端和 manifest 不会看到供应商临时 URL。
4. FFmpeg 把三段真实供应商视频标准化、混入本地 Huihui 配音和字幕，再按顺序合片。
5. Wan 只在 `XINGMU_WAN_ADAPTER_ENABLED=true` 且服务端存在 `DASHSCOPE_API_KEY` 或显式 `--dashscope-key-file` 时启用；可选 `BAILIAN_WORKSPACE_ID` 选择北京 Workspace Endpoint。不默认搜索任何 `key.txt` 或 D 盘文件。

本地模板依赖开发机外部安装的 Windows 语音和 FFmpeg，不把二进制、声音模型或模型权重放入 Flutter 安装包。Android/OpenHarmony 只负责调用开发机服务。缺少 TTS、FFmpeg 或固定素材时，服务必须明确不可用或失败，不能用提示音、文字卡或假进度冒充漫剧。

## 6. 状态与一致性

统一异步状态：

```text
queued -> running -> succeeded
             ├────> failed -> retry -> queued
             ├────> paused -> resume -> queued
             └────> canceled
```

- 创建与动作类 POST 必须使用 `Idempotency-Key`；网络超时后可安全重放同一用户意图。
- 可编辑资源在响应中返回强 ETag；PATCH、DELETE 和状态迁移使用 `If-Match`。
- 收到 `412 Precondition Failed` 时客户端重新读取资源，不能静默覆盖。
- SSE 是提示通道，不是唯一事实来源；项目、运行、任务和预算的 REST 表示才是权威状态。
- 失败码区分可重试、余额/配额不足、内容安全、输入错误和服务端故障。

## 7. 演示、模板与云端模式

演示模式使用确定性的本地样例展示完整产品流程，不联网、不上传内容、不调用模型、不消耗费用。它用于 UI 体验和无后端的双平台构建验证，不能标记为真实生成成功。

本地模板会真实生成 MP4 和 Windows 配音，hybrid 会真实生成三段视频并合片，但两者的首尾画面都来自预先生成的固定 ImageGen 项目素材。客户端必须展示 `visualWarning` 与 `modelExecution`，不得从是否存在 MP4/GIF 自行推断真实性。

主 App 使用 Flutter `video_player` 的 OpenHarmony 适配在独立内嵌页播放最终 MP4，让用户看到真正分镜成片。GIF 只用于快速预览，不是最终播放或验收媒体。客户端仍只使用服务端返回的同源 `videoUrl`，不直接访问供应商临时 URL。

云端真实模式通过 `API_BASE_URL` 连接可信后端。当前 Video Lab 只实现 Wan 2.7 视频子集；千问脚本、Wan 图片重绘与 CosyVoice 仍未实现。真实 Wan 付费调用、费用和效果为 `not run`。生产包只允许 HTTPS；Android 模拟器使用 `10.0.2.2`，OpenHarmony 使用设备实际可达地址。

## 8. 后端最低实现要求

- Bearer 身份认证和逐项目授权。
- PostgreSQL 或等价持久存储保存项目、修订、任务和预算账本。
- 可靠任务队列；任务提交和状态落库具备原子性或补偿机制。
- 对象存储使用短期签名上传/下载 URL，并在服务端校验类型、大小、哈希和媒体内容。
- Provider Adapter 隔离百炼与 Wan2.2，密钥来自服务端 Secret Manager、环境注入或运维者显式指定的受控 Key 文件；禁止默认扫描工作目录、D 盘或原项目。
- 对供应商限流、余额不足、内容安全拒绝和超时进行规范化映射。
- 导出服务在后端运行 FFmpeg；客户端不捆绑 FFmpeg 二进制。
- 预算采用预估、预留、结算、释放四阶段，避免重试造成隐性超支。
- 云端文本、图片、视频和声音模型只能由服务端白名单选择；百炼 Key 只从服务端 Secret Manager 或环境变量读取，不能由手机提交。

## 9. 平台配置基线

- Flutter：CPF-Flutter `oh-3.35.7-dev`，已知版本 `3.35.8-ohos-1.0.3-beta`。
- 成片播放：`video_player` 2.10.1 固定到 CPF-Flutter `flutter_packages` commit `97e9265ae2ab44c913d5d943ad68bec0c07a040e`，并由其 `video_player_ohos` 依赖连接 `openharmony-tpc/flutter_packages` 的同 commit。
- OpenHarmony：SDK API 20，`runtimeOS: OpenHarmony`，`deviceTypes: ["default"]`。
- Android/OpenHarmony：仅申请联网权限；相机、相册、麦克风等权限应在真正实现相关功能时按需新增。
- 签名文件、`local.properties`、服务端密钥和用户生成资产永不提交 Git。

## 10. 决策边界

MVP 不实现手机端模型推理、模型训练、复杂时间轴剪辑、应用内支付或公开素材社区。Wan hybrid 仅是服务端受控开发切片，不扩大手机信任边界。App 只复制官方计费/充值链接，不收款、不读取余额或 Provider Key。
