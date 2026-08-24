# 星幕本地漫剧与视频实验服务

这是一个仅依赖 Python 标准库、Windows SAPI 与系统 FFmpeg 的开发服务。免费路径把固定项目画面合成为《月背最后一单》模板；可选混合路径会把每镜明确的固定首尾帧提交给 Wan，下载三个真实 MP4 片段后再配音、字幕和合片。旧版动态字幕卡 API 仍保留兼容。

本地漫剧是模板合成，不是按请求实时生成画面：

- `executionKind = template`
- `visualSource = fixed_project_assets`
- `generatedForRequest = false`
- `containsAiGeneratedAssets = true`
- `assetProvenance = openai_imagegen_project_assets`
- `visualWarning = 本次请求未调用 AI，也未按 story 重新绘制；画面是预先生成且有来源记录的 OpenAI ImageGen 项目素材。`

FFmpeg 成片不会保留源 PNG 的 C2PA 元数据。`manifest.json` 会为每个镜头记录仓库相对路径 `sourceAsset` 和运行时计算的 `sourceAssetSha256`，用于与 `THIRD_PARTY_NOTICES.md` 核对；这不表示来源元数据已嵌入 MP4 或 GIF。

## 运行条件

- Python 3.11+
- Windows PowerShell 与 .NET `System.Speech`
- Windows 已安装中文语音 `Microsoft Huihui Desktop`
- `ffmpeg` 与 `ffprobe` 可从 `PATH` 找到
- FFmpeg 构建包含 `drawtext`、`zoompan`、`sine`、`libx264` 与 `aac`
- 以下三张素材存在：
  - `assets/showcase/motion_comic/moon-courier-shot-01.png`
  - `assets/showcase/motion_comic/moon-courier-shot-02.png`
  - `assets/showcase/motion_comic/moon-courier-shot-03.png`
- Wan 混合路径还需要三个明确尾帧：
  - `assets/showcase/motion_comic/moon-courier-shot-01-end.png`
  - `assets/showcase/motion_comic/moon-courier-shot-02-end.png`
  - `assets/showcase/motion_comic/moon-courier-shot-03-end.png`

如 FFmpeg 工具不在 `PATH`，可设置 `FFMPEG_BIN` 与 `FFPROBE_BIN`。中文字体可用 `VIDEO_LAB_FONT` 指向本机字体文件。

启动服务：

```powershell
python services/basic_video_server/server.py
```

默认只监听 `127.0.0.1:8787`，API 根地址是 `http://127.0.0.1:8787/v1`。Android 模拟器通常用 `http://10.0.2.2:8787/v1` 访问宿主机。只有在受信局域网调试时才应使用 `--host 0.0.0.0`；该服务没有认证、HTTPS 或 CORS，不能直接暴露到公网。

## 模型目录与执行边界

`GET /v1/model-catalog` 返回 `textModels`、`imageModels`、`videoModels`、`voiceModels` 与 `comicPipelines`。

唯一可提交的本地漫剧组合是：

| 能力 | 模型 ID |
| --- | --- |
| 文本/分镜 | `local_storyboard_template` |
| 固定画面 | `fixed_moon_courier_assets` |
| 动效合成 | `local_ffmpeg_motion_comic` |
| 中文配音 | `windows_sapi_huihui` |

本地管线只有在 FFmpeg、三张素材和 Huihui 语音全部可用时才标记为 `available`。缺少 Huihui 时目录状态为 `requires_configuration`，`POST /v1/comic-jobs` 返回 HTTP 503，不会用提示音冒充配音。配音通过固定 PowerShell 脚本、参数数组和临时文本文件调用，用户文本不会进入 shell 命令；临时文本文件用后即删。若旁白略长，服务只在安全范围内用 `atempo` 压入约 3 秒镜头。

目录还展示以下百炼云端模型：

- 文本：`qwen3.6-plus`
- 图像：`wan2.7-image-pro`
- 视频：`wan2.7-i2v-2026-04-25`
- 语音：`cosyvoice-v3.5-plus`

当前只实现 Wan 首尾帧视频 Adapter。千问、Wan 图片和 CosyVoice 仍为 `requires_configuration`，完整四云模型组合会被拒绝，不能把未执行的模型冒充为已执行。可执行的付费混合组合是：

| 能力 | 模型 ID | 实际执行 |
| --- | --- | --- |
| 文本/分镜 | `local_storyboard_template` | 本地固定模板 |
| 首尾帧 | `fixed_moon_courier_assets` | 预生成固定项目资产 |
| 镜头视频 | `wan2.7-i2v-2026-04-25` | 百炼 Wan 云端生成 |
| 配音 | `windows_sapi_huihui` | 本机 SAPI |

只有同时设置 `XINGMU_WAN_ADAPTER_ENABLED=true` 与服务端 `DASHSCOPE_API_KEY`，Wan 视频模型才标记为 `available`；只有 Provider、六张首尾帧、Huihui、FFmpeg 和 ffprobe 全部就绪，混合管线才标记为 `available`。也可在启动时传 `--dashscope-key-file <显式路径>`，服务不会自动搜索 `key.txt`。Key 不进入请求/响应、日志、Flutter 客户端或产物清单。

Wan Adapter 固定使用 720P、3 秒、`prompt_extend=false`、`watermark=false`，首尾 PNG 作为 data URL 直接提交；异步任务按 `PENDING/RUNNING` 轮询，成功后立即从受限 HTTPS 主机下载 H.264 MP4。下载执行超时、重定向复检、URL 主机白名单、JSON/视频大小限制和 MP4 文件头校验；供应商临时 `video_url` 不返回手机客户端，也不写入 manifest。

启用 Adapter 会产生真实云端调用和费用。测试和默认启动不会自动发起任务；本仓库测试只连接进程内假 HTTP 服务。

混合请求只把视频模型改为 Wan：

```json
{
  "story": "月背停电第七天，她送来最后一封信。",
  "textModelId": "local_storyboard_template",
  "imageModelId": "fixed_moon_courier_assets",
  "videoModelId": "wan2.7-i2v-2026-04-25",
  "voiceModelId": "windows_sapi_huihui",
  "aspectRatio": "9:16",
  "shotCount": 3,
  "shotDurationSeconds": 3
}
```

混合 Job 使用 `executionKind=hybrid`、`visualSource=fixed_project_assets`，并通过 `modelExecution={text: local, image: pre_generated, video: cloud, voice: local}` 逐能力披露。`generatedForRequest=true` 只表示本次请求生成了视频片段；`visualWarning` 会明确首尾帧没有按任意 `story` 重绘。

每个镜头返回同源 `firstFrameUrl`、`lastFrameUrl`、`motionPrompt` 与 `videoTask`；成功的 `videoTask.videoUrl` 指向本服务立即转存并标准化后的镜头 MP4。只读资源路由为：

- `GET /v1/comic-jobs/{id}/shots/{shotId}/first-frame.png`
- `GET /v1/comic-jobs/{id}/shots/{shotId}/last-frame.png`
- `GET /v1/comic-jobs/{id}/shots/{shotId}/video.mp4`

最终 output/manifest 使用 `compositionType=shot_videos_concat` 与 `sourceClipCount=3`，明确成片由三段真实镜头视频拼接，不是把首帧再次做图片运镜。

## 创建本地漫剧

请求字段采用严格白名单，模型必须完整匹配上表，画幅固定 `9:16`，镜头数固定为 3，每镜头固定约 3 秒：

```powershell
$body = @{
  story = "月背停电第七天，她送来最后一封信。"
  textModelId = "local_storyboard_template"
  imageModelId = "fixed_moon_courier_assets"
  videoModelId = "local_ffmpeg_motion_comic"
  voiceModelId = "windows_sapi_huihui"
  aspectRatio = "9:16"
  shotCount = 3
  shotDurationSeconds = 3
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8787/v1/comic-jobs `
  -ContentType application/json `
  -Body $body
```

提交任意其他 `story` 仍会输出固定样片，响应、剧本和清单会同时保留 `requestedStory`、`templateStoryTitle` 与 `visualWarning`，不会暗示画面已按输入重绘。

轮询与产物路由：

- `GET /v1/comic-jobs/{id}`
- `GET /v1/comic-jobs/{id}/preview.gif`
- `GET /v1/comic-jobs/{id}/video.mp4`
- `GET /v1/comic-jobs/{id}/manifest.json`
- `GET /v1/comic-jobs/{id}/script.json`

MP4 与 GIF 支持单段 HTTP `Range`；JSON 不支持 Range。任务返回稳定的 `stageCode`、三个镜头的状态/进度，以及同源的四个产物 URL。最终 MP4 使用 H.264、720×1280、yuv420p、AAC 与 faststart；镜头包含推拉或平移、字幕、淡入淡出、Huihui 配音和低音背景混音，并额外生成 GIF 预览。

每个进程最多接受 2 个排队或执行中的任务，旧视频任务与漫剧任务共享限额；两类任务合计最多保留 20 个。容量满时返回 HTTP 429，不创建新输出。

## 旧版兼容 API

旧版 `POST /v1/video-jobs` 与 `GET /v1/video-jobs/{id}` 保持可用，仍使用 `manual` + `local_ffmpeg_slides` 生成动态字幕卡。它不是漫剧，也不是 AI 文生视频：

```powershell
$body = @{
  prompt = "霓虹雨夜里的月球快递员"
  textModelId = "manual"
  videoModelId = "local_ffmpeg_slides"
  aspectRatio = "9:16"
  durationSeconds = 3
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8787/v1/video-jobs `
  -ContentType application/json `
  -Body $body
```

## 验证

```powershell
python -m compileall -q services/basic_video_server
python -m unittest discover -s services/basic_video_server/tests -v
```

测试覆盖严格目录/请求契约、Huihui 不可用、无 CORS、共享限流、三镜头阶段、清单/剧本、素材 SHA-256、媒体 Range 与旧端点回归，并真实调用 FFmpeg、Huihui 和 ffprobe 检查 720×1280 H.264/yuv420p、AAC、约 9 秒成片及 GIF 文件头。

本实现未复制 MoneyPrinterTurbo 的源码、品牌或素材；只采用了“任务编排 + FFmpeg 输出”的通用架构思路。
