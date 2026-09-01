# 星幕 AI 漫剧工作室 — Flutter 移动端

> Flutter Android & HarmonyOS 客户端，AI 动态漫剧视频生成。

## 项目信息

- **名称**: xingmu_ai_video_studio
- **版本**: 0.1.0+1
- **Dart SDK**: ^3.9.2
- **支持平台**: Android / HarmonyOS (OHOS)

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── app/                         # 应用根组件
│   ├── app.dart
│   └── xingmu_app.dart          # 星幕 App 根 Widget
├── application/                 # 应用引导与控制器
│   ├── studio_bootstrap.dart      # 启动引导（环境变量读取 API_BASE_URL）
│   └── studio_controller.dart    # 状态控制器
├── data/                        # 数据层
│   ├── demo/                     # 演示数据源
│   └── remote/                   # 远程 HTTP 仓库
├── domain/                      # 领域层
│   ├── studio_models.dart        # 数据模型
│   ├── studio_repository.dart    # 仓库接口
│   ├── generation_planner.dart   # 生成计划器
│   ├── studio_status.dart        # 状态枚举
│   └── studio_validation.dart    # 验证逻辑
├── features/                    # 功能模块
│   ├── home/                     # 首页
│   ├── creation/                # 主题成剧
│   ├── script/                   # 剧本
│   ├── shots/                    # 分镜工作台
│   ├── voice/                    # 配音工作室
│   ├── video_lab/               # 视频实验室
│   ├── result/                   # 成片预览
│   ├── settings/                # 设置
│   ├── tasks/                   # 任务中心
│   └── assets/                  # 视觉素材
├── presentation/               # 表示层适配
│   ├── adapters/                 # 适配器
│   └── models/                   # 视图数据
└── shared/                     # 共享组件
    ├── theme/                    # 星幕深空主题
    └── widgets/                  # 通用 Widget
```

## 后端服务

`services/basic_video_server/` — Python 后端服务，负责：
- 万相视频生成（Wan 2.7 i2v）
- FFmpeg 漫剧合成
- TTS 配音

## 安全说明

- 所有 API Key 通过环境变量注入，不硬编码在源码中
- `DASHSCOPE_API_KEY` — 百炼 API 密钥
- `BAILIAN_WORKSPACE_ID` — 百炼工作空间
- `API_BASE_URL` — 后端服务地址

## 许可证

私有项目，保留所有权利。
