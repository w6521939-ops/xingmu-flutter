# 常见陷阱

1. **把模型密钥放进 Dart 常量或 `--dart-define`**：编译参数仍可从安装包提取。客户端只接收星幕后端地址和短期用户令牌。
2. **把演示模式称为真实生成**：演示数据不调用模型，UI 与文档必须明确标记。
3. **Android 模拟器使用 `localhost`**：这会指向模拟器自身；访问宿主机使用 `10.0.2.2`。
4. **为 release 放行明文 HTTP**：`usesCleartextTraffic=true` 只能存在于 debug manifest。
5. **OpenHarmony 沿用 HarmonyOS/API18 模板值**：检查 API 20、`OpenHarmony` 和 `deviceTypes: default`。
6. **重复点击产生重复收费任务**：客户端禁用按钮，服务端仍必须校验 `Idempotency-Key`。
7. **用 SSE 事件直接覆盖最终状态**：断线后先 GET 聚合资源，SSE 仅做增量提示。
8. **长期保存供应商或签名 URL**：后端及时接管供应商结果；客户端下载时按需换取短期票据。
9. **将签名或 SDK 本机路径提交 Git**：`local.properties`、keystore、证书、`.env` 和密钥文件均不得跟踪。
10. **把未运行的验证写成通过**：只使用 `passed`、`failed`、`not run`。
