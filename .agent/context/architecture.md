# 架构约定

## 客户端

采用 Presentation → Application/ViewModel → Domain → Repository/Data → Platform 的单向依赖。页面不直接解析 HTTP 或供应商返回；Data 层只实现 `docs/api/openapi.yaml`，供应商字段转换留在可信后端。

演示仓库与远程仓库实现同一领域接口。演示模式必须明显标记，不能把占位进度或占位成片视为真实生成。

## 后端边界

可信后端持有身份、项目、资产、预算、任务和 Provider Adapter。百炼为默认 Provider，Wan2.2 为可选 Provider。大模型推理、TTS、对象存储和 FFmpeg 合成都不在手机上运行。

## 一致性

- 创建/动作 POST：`Idempotency-Key`。
- 覆盖/状态迁移：ETag + `If-Match`。
- 实时更新：SSE + `Last-Event-ID`，REST 聚合状态为最终事实。
- 状态：`queued/running/paused/succeeded/failed/canceled`。
- 费用：预估、预留、结算、释放。

## 平台

- Android main/release 只申请联网，不放行明文；debug 可连接本地 HTTP。
- Android 模拟器连接宿主机使用 `10.0.2.2`。
- OpenHarmony 使用 API 20、`runtimeOS: OpenHarmony`、`deviceTypes: ["default"]`。
- OpenHarmony 设备连接本地后端时使用设备可达地址，不能假设 `localhost` 指开发机。
