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
