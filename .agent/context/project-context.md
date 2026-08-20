# 项目上下文

- 项目名：星幕 AI 漫剧。
- 仓库性质：Flutter 手机客户端，不包含模型权重和生产后端。
- 目标平台：Android 与 OpenHarmony。
- OpenHarmony 工具链：CPF-Flutter 分支 `oh-3.35.7-dev`（工具报告 `3.35.8-ohos-1.0.3-beta`），OpenHarmony SDK API 20。
- 产品目标：输入主题/剧本后管理云端角色、场景、分镜、镜头视频、配音和成片生成。
- 默认生成 Provider：可信后端中的阿里云百炼适配器。
- 可选 Provider：独立部署的 Wan2.2；客户端契约不随 Provider 改变。
- 演示模式：本地确定性数据，不联网、不调用模型、不产生费用。
- 安全边界：手机端永远不保存百炼/Wan2.2/对象存储永久密钥。
- API 权威契约：`docs/api/openapi.yaml`。

## 本地覆盖顺序

修改前依次检查：最近的 `AGENTS.md`、`.agent/context/*`、`.agent/memory/*`、实际平台配置、当前 Flutter/DevEco/OpenHarmony SDK 输出和真实构建日志。实际证据高于通用经验。

## 受保护范围

除非任务明确要求，不修改依赖、锁文件、签名、CI、权限、全局路由、分析、发布脚本和模型 Provider 密钥边界。签名与 `local.properties` 始终留在本机或 CI Secret。
