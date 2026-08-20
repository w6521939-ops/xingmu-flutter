# 星幕 AI 漫剧移动端架构

## 1. 架构目标

本仓库是 Flutter 手机客户端，同时支持 Android 与 OpenHarmony。客户端负责项目管理、生成参数输入、资产审核、任务进度和失败重试；它不在手机上运行文生图、图生视频、TTS 或 FFmpeg 合成，也不持有百炼、对象存储或自托管模型的密钥。

当前版本已经实现 Demo Repository、OpenAPI 对齐的 HTTP Repository 和显式 REST 刷新。SSE、手机登录、安全持久会话、真实视频播放器、文件下载与系统分享属于下一阶段，架构中的相应节点是目标边界而不是已完成声明。

后端默认接入阿里云百炼，也可通过同一 Provider 接口接入独立部署的 Wan2.2。模型切换不能改变客户端领域对象和任务状态语义。

## 2. 系统边界

```text
Android / OpenHarmony Flutter App
  ├─ 演示仓库：内置示例数据，不联网、不产生真实费用
  └─ 远程仓库：Bearer + HTTPS + Idempotency-Key + If-Match
                    │
                    ▼
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

后端实现不属于当前客户端仓库；双方以 [`docs/api/openapi.yaml`](../api/openapi.yaml) 为唯一 HTTP 契约。

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

## 4. 核心生成流程

1. 用户新建项目，输入主题、故事梗概或已有剧本。
2. 后端异步生成严格结构化剧本，返回角色、道具、场景和分镜 ID。
3. 用户审核角色卡、场景卡和道具卡；后续提示词按固定 ID 和稳定顺序引用。锁定状态仅展示服务端明确数据，锁定变更尚未接入客户端。
4. 客户端创建 Generation Plan，固化剧本修订、参考资产、镜头集合和 Provider 策略。
5. 后端预估费用并预留预算，随后创建 Generation Run。
6. 编排器依次生成角色图、场景图、分镜首尾帧、镜头视频、配音和字幕。每个子任务具有稳定 ID、输入哈希、重试次数和输出资产 ID。
7. 当前客户端通过显式 REST 刷新校准状态；后续接入 SSE 后再使用 `Last-Event-ID` 做增量恢复。
8. 用户可重试失败镜头；服务端 Export 与限时下载接口已定义，手机播放、下载和分享尚未接入。

模型供应商返回的临时结果必须由后端及时下载进受控对象存储，不能把供应商临时 URL 当成永久资产。

## 5. 状态与一致性

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

## 6. 演示模式与真实模式

演示模式使用确定性的本地样例展示完整产品流程，不联网、不上传内容、不调用模型、不消耗费用。它用于 UI 体验和无后端的双平台构建验证，不能标记为真实生成成功。

真实模式通过 `API_BASE_URL` 连接可信后端。生产包只允许 HTTPS；Android 模拟器连接开发机时使用 `10.0.2.2`，OpenHarmony 真机或模拟器使用设备实际可达的局域网/映射地址，不能假设 `localhost` 指向开发机。

## 7. 后端最低实现要求

- Bearer 身份认证和逐项目授权。
- PostgreSQL 或等价持久存储保存项目、修订、任务和预算账本。
- 可靠任务队列；任务提交和状态落库具备原子性或补偿机制。
- 对象存储使用短期签名上传/下载 URL，并在服务端校验类型、大小、哈希和媒体内容。
- Provider Adapter 隔离百炼与 Wan2.2，密钥来自服务端 Secret Manager 或环境注入。
- 对供应商限流、余额不足、内容安全拒绝和超时进行规范化映射。
- 导出服务在后端运行 FFmpeg；客户端不捆绑 FFmpeg 二进制。
- 预算采用预估、预留、结算、释放四阶段，避免重试造成隐性超支。

## 8. 平台配置基线

- Flutter：CPF-Flutter `oh-3.35.7-dev`，已知版本 `3.35.8-ohos-1.0.3-beta`。
- OpenHarmony：SDK API 20，`runtimeOS: OpenHarmony`，`deviceTypes: ["default"]`。
- Android/OpenHarmony：仅申请联网权限；相机、相册、麦克风等权限应在真正实现相关功能时按需新增。
- 签名文件、`local.properties`、服务端密钥和用户生成资产永不提交 Git。

## 9. 决策边界

MVP 不实现手机端模型推理、模型训练、复杂时间轴剪辑、支付充值、公开素材社区或后台常驻生成。生成在服务端继续运行，客户端回到前台后通过 REST/SSE 恢复状态。
