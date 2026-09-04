# Changelog

本项目所有重要变更都记录在此文件中。格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [2.0.0] — 2026-09-04

### 阶段四：开源工程化 + 新管线扩展

**新增**
- 新增 3 条制作管线：口播视频、屏幕录制演示、播客再利用
- 管线选择器 UI，支持在 4 种管线间切换
- `PipelineDefinition.all` 静态列表与 `findById` 方法
- GitHub CI 工作流（analyze + test + Android 构建 + 许可证检查 + 密钥扫描）
- Bug 报告 Issue 模板
- 功能请求 Issue 模板
- Pull Request 模板
- 贡献指南 `CONTRIBUTING.md`
- 行为准则 `CODE_OF_CONDUCT.md`
- 安全政策 `SECURITY.md`
- 版本变更记录 `CHANGELOG.md`
- 新增 4 个测试文件：管线定义、Agent Builder、多轨混音、Keyring

**改进**
- `pubspec.yaml` 版本升至 2.0.0，更新项目描述
- `analysis_options.yaml` 补充 30+ 条 lint 规则（代码风格、空安全、错误预防）
- `THIRD_PARTY_NOTICES.md` 许可证引用从 Apache-2.0 更新为 MIT
- `.gitignore` 补充 Keyring 保险库与凭据文件忽略规则

## [1.5.0] — 2026-09-04

### 阶段三：扩展与生态

**新增**
- 自定义 Agent 扩展 UI（模板化创建 + 手动创建双 Tab）
- 4 个内置 Agent 模板：风格增强、镜头优化、台词润色、配乐选择
- `CustomAgentRegistry` 自定义 Agent 注册表（CRUD + 按阶段过滤）
- 多轨道混音台（音量/声像/静音/独奏/淡入淡出/效果链）
- 5 种轨道效果：混响、压缩器、均衡器、噪声门、齿音消除
- GPU 能力自动检测（NVIDIA NVENC / AMD AMF / Intel QSV / Apple VideoToolbox）
- GPU 渲染配置（编码器/质量预设/CRF/码率/B帧/HDR）
- 渲染进度模型与状态枚举
- Keyring 加密保险库（AES-256-GCM / ChaCha20-Poly1305 / AES-256-CBC）
- 6 种 Provider 凭据管理（DashScope/百炼/OpenAI/Anthropic/Azure/自定义）
- 审计日志（密钥库操作全记录）
- .env 文件导入导出功能

## [1.0.0] — 2026-09-03

### 阶段二：核心能力升级

**新增**
- 角色一致性系统（IP-Adapter 锚点锁脸）
- 角色漂移检测与修正
- `CharacterIdentity` 与 `ConsistencyAnchor` 模型
- 8 种运镜类型：推/拉/平移/俯仰/横摇/纵摇/ Ken Burns/组合
- 缓动函数（线性/缓入/缓出/缓入缓出/弹性）
- 分镜规划器与运镜规划应用
- 3 列分镜工作台 UI
- 字幕同步系统（毫秒级时间戳计算）
- SRT / ASS 字幕导出
- 多轨音频混音支持
- Multi-Agent 架构（Hub-and-Spoke 模型）
- `ProjectBlackboard` 共享状态总线（事件流）
- `MasterDirectorAgent` 总导演 Agent
- 5 个内置子 Agent：剧本摄入、角色设计、分镜规划、运镜、配音同步
- `AgentRegistry` Agent 注册表

## [0.5.0] — 2026-09-01

### 阶段一：基础设施重构

**新增**
- 文件导入与脚本解析（.txt / .md / .json）
- 剧本自动拆分场景与角色
- 多 Provider 抽象层（统一接口适配 DashScope / 百炼 / OpenAI）
- `ProviderSelector` 服务商选择器
- `CostTable` 成本估算表
- 管线状态机（8 阶段：素材导入→剧本生成→角色设计→分镜规划→镜头生成→配音合成→视频合成→导出发布）
- 管线依赖编排与并行执行支持
- 审批门机制
- 仓库接口定义
- 项目结构重构为 DDD 分层（domain / data / application / presentation）

## [0.1.0] — 2026-08-20

### 初始版本

- Flutter Android & HarmonyOS 客户端
- 深空暗色主题 UI
- 主题成剧功能
- 角色设定
- 分镜生成
- 视频生成（万相 Wan 2.7 i2v）
- 配音工作室
- 任务中心
- 成片预览
- 本地 Python 后端服务（basic_video_server）
