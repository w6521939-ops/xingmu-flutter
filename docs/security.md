# 安全与隐私基线

## 1. 信任边界

手机端属于不可信环境。反编译、代理抓包、Root/调试设备和本地数据读取均在威胁模型内，因此客户端不得获得百炼 API Key、Wan2.2 管理凭据、对象存储永久密钥、服务端数据库凭据或签名私钥。

客户端唯一可调用对象是星幕可信后端。后端再通过私有 Provider Adapter 调用百炼或 Wan2.2，并负责供应商错误归一化、预算、审计、资产落库和结果下载。

## 2. 凭据与认证

- 用户访问令牌应短期有效，通过系统安全存储保存；刷新令牌按后端策略轮换和撤销。
- 供应商密钥存入服务端 Secret Manager 或受控环境变量，不写数据库明文、不返回客户端、不记录日志。
- Video Lab 的 Wan Adapter 默认关闭；只有 `XINGMU_WAN_ADAPTER_ENABLED=true` 且服务端存在 `DASHSCOPE_API_KEY` 或运维者显式指定 `--dashscope-key-file` 时才可调用。禁止自动搜索 `key.txt`、D 盘或原 Electron 项目文件。
- Bearer Token 只放 `Authorization` 请求头，不放 URL、SSE 查询参数、分析事件或崩溃报告。
- 每个请求都按用户和项目执行对象级授权；知道资源 ID 不等于有访问权。
- 登出时清理本地令牌、用户缓存和待上传临时文件。

## 3. 传输安全

- 生产与 release 包只连接 HTTPS，校验证书和主机名，不提供“忽略证书错误”开关。
- Android main/release 清单不放行明文流量；仅 debug 变体设置 `usesCleartextTraffic=true`。
- Android 模拟器访问开发机使用 `10.0.2.2`。OpenHarmony 真机/模拟器使用设备可达的局域网地址或调试端口映射；`localhost` 通常指设备自身。
- 开发期 HTTP 地址不得编译进 release 默认值，CI/发布检查应拒绝 `http://` 的生产 `API_BASE_URL`。

## 4. 防重复收费与并发覆盖

- 创建生成、重试、状态动作、费用估算和导出使用高熵 `Idempotency-Key`。
- 同一用户、路由、幂等键与请求体在服务端至少保留 24 小时；请求体不一致时返回冲突。
- 可编辑资源返回强 ETag，PATCH/DELETE/状态迁移要求 `If-Match`。
- `412` 必须显示冲突并重新读取，不能在客户端自动改成通配符覆盖。
- 用户点击提交后立即禁用按钮；UI 防抖只是体验措施，服务端幂等才是安全边界。

## 5. 上传与下载

- 后端签发短期、单对象、限方法、限 Content-Type 和限大小的上传凭证。
- 上传完成后校验 SHA-256、真实 MIME、文件头、尺寸/时长和内容安全；不能信任扩展名。
- 图像、音频、视频解析放在隔离进程/容器，限制 CPU、内存、磁盘和执行时间。
- 预览与下载使用短期签名 URL；日志、剪贴板和持久缓存不得记录完整 URL 查询参数。
- 供应商临时结果由后端立即下载到受控存储，并验证大小与哈希。
- Wan 临时 `video_url` 不得出现在 Flutter 响应、manifest、script、日志或剪贴板；客户端只获取同源 `/shots/{shotId}/video.mp4`。
- 删除项目时明确软删除期限、最终清理时间和备份保留策略。

## 6. 生成内容与隐私

- 上传前说明文本、参考图、声音和视频将发送到云端及所选模型供应商处理。
- 未得到授权不得上传他人肖像、声音、作品或敏感个人信息。
- 后端执行内容安全策略，并向客户端返回可理解但不过度暴露内部规则的错误码。
- 生成内容应保留来源、模型、时间和计划修订等审计元数据；对外展示时按法规和平台要求标识 AI 生成。
- 本地模板结果必须保留服务端真实性字段：`executionKind=template`、`visualSource=fixed_project_assets`、`generatedForRequest=false`、`containsAiGeneratedAssets=true`、`assetProvenance=openai_imagegen_project_assets`。客户端既不能把固定素材合成误标为本次主题 AI 生成，也不能隐瞒固定画面本身来自预生成 ImageGen 素材。
- Wan hybrid 必须返回 `executionKind=hybrid`、`generatedForRequest=true`、`modelExecution={text: local, image: pre_generated, video: cloud, voice: local}`、`compositionType=shot_videos_concat` 与 `sourceClipCount=3`。`generatedForRequest=true` 只表示本次请求生成了三段 Wan 镜头视频；首尾帧仍是固定 ImageGen 项目素材，不得误标为按 `story` 重绘。
- 默认不把用户内容用于训练；如策略变化必须单独、明确、可撤回地征得同意。

## 7. SSE 与后台任务（客户端后续接入）

- SSE 请求同样要求 Authorization 头和项目授权。
- 每个事件带不可猜测事件 ID；断线使用 `Last-Event-ID`，服务端限制可回放窗口。
- 心跳不包含用户内容；错误事件不回显供应商密钥、原始堆栈或完整提示词。
- 客户端退到后台时关闭长连接；恢复后先 GET 聚合状态再重连。
- 服务端对每用户并发连接数、重连频率和任务提交速率限流。

## 8. 预算与滥用控制

- 启动前给出费用区间并预留预算；任务结束按实际金额结算，取消/失败释放未消费预留。
- 每个项目具有硬上限，供应商余额不足或配额异常时停止继续派发后续收费任务。
- Wan 720P/3 秒请求仍是可能产生费用的供应商调用；本轮真实付费请求、费用与效果均为 `not run`，不得因离线假 Provider 测试通过而宣称已验证付费能力。
- 重试次数、并发度、视频时长、分辨率、上传大小和每日用量均设置服务端上限。
- 管理接口、Provider 切换和预算上调需要更高权限和审计记录。

## 9. 日志与可观测性

- 日志允许记录请求 ID、匿名用户 ID、资源 ID、阶段、耗时、状态码和规范化错误码。
- 日志禁止记录 Token、API Key、签名 URL 查询参数、完整用户提示词、原始图片/音频或支付信息。
- 客户端错误报告先脱敏；服务端堆栈只进入受限日志系统，不返回移动端。
- 审计日志覆盖登录、项目删除、预算修改、生成提交、重试、取消、Provider 选择和导出下载。

## 10. 仓库与发布检查

- `.gitignore` 必须覆盖 `local.properties`、签名材料、`.env*`、`key.txt`、本地数据库和生成资产。
- 提交前运行秘密扫描；任何真实密钥一旦进入 Git 历史都必须立即轮换，删除文件不能代替轮换。
- Android/OpenHarmony 签名只在本地安全配置或 CI Secret 中注入。
- Dart debug kernel 可能嵌入 `file://` 本机源码路径；debug APK 和 unsigned/debug HAP 只作本地编译证据，不作公开发行包。
- 依赖升级需要许可证、漏洞和供应链来源检查；不从未知镜像下载模型或二进制。
- 可分发包在干净 CI 路径做 release/obfuscation 构建后，重新检查字符串与资源，确认没有本地路径、测试账号、HTTP 生产地址或供应商密钥。

## 11. 发布前核对表

- [ ] 客户端与仓库无供应商密钥、永久存储凭据或签名私钥。
- [ ] release 只接受 HTTPS，Android 明文放行仅存在于 debug manifest。
- [ ] Bearer、SSE、对象授权、幂等和 ETag 冲突路径均有服务端测试。
- [ ] 上传类型/大小/哈希/内容校验和限时 URL 已验证。
- [ ] 预算预留、结算、释放和配额中止已验证。
- [ ] 日志、崩溃报告和分析事件完成脱敏检查。
- [ ] 用户可理解云端处理、第三方供应商和删除保留规则。
- [ ] Android 与 OpenHarmony 真机上的拒权、离线、后台恢复和下载失败均已验证。

## 12. 本地 Video Lab 边界

- `services/basic_video_server` 只用于本机开发与模拟器验收，默认监听 loopback。它没有认证，也不返回 CORS 允许头，不能直接暴露到公网或供浏览器跨域调用。
- 本地服务不接收 API Key、支付信息或任意 FFmpeg 参数；文本、图片、视频和声音模型 ID、镜头数、时长、比例和故事长度都由服务端白名单校验。
- 本地三镜头模板固定使用项目自有的 `《月背最后一单》` 画面。任意输入不会触发重新绘图；任务和输出必须返回 `executionKind=template`、`visualSource=fixed_project_assets`、`generatedForRequest=false`、`containsAiGeneratedAssets=true`、`assetProvenance=openai_imagegen_project_assets`、`templateStoryTitle` 和非空 `visualWarning`。
- hybrid 只把固定首尾帧发送给 `wan2.7-i2v-2026-04-25`，不把用户 Key、付费信息或任意本机文件路径放入请求。三段成功镜头须立即转存，再由 FFmpeg 合成最终 MP4；GIF 只是预览。
- Windows 系统 TTS 与 FFmpeg 都是开发机外部依赖，不进入手机安装包。服务端通过受控参数调用，不执行用户拼接的 shell 命令；输出目录按服务生成的 UUID 隔离。
- GIF/MP4 可以支持单段 Range；`manifest.json` 与 `script.json` 不接受媒体 Range 语义。所有结果 URL 必须与任务 API 同源，不能直接暴露供应商临时地址。
- 开发期 HTTP 需要客户端显式启用 `ALLOW_INSECURE_VIDEO_LAB`；release/生产必须使用 HTTPS、认证、授权、速率限制和持久化幂等。
- `wan2.7-i2v-2026-04-25` 只在显式 enable + 服务端 Key 后标记为 `available`；hybrid Pipeline 还要求六张首尾帧、Huihui、FFmpeg 和 ffprobe。`qwen3.6-plus`、`wan2.7-image-pro` 和 `cosyvoice-v3.5-plus` 仍必须为 `requires_configuration`。
- 付费入口只复制 `help.aliyun.com` 上的供应商官方 HTTPS 地址；App 不代收款、不读取余额、不保存支付资料，也不把 Provider 凭据保存到设备。
