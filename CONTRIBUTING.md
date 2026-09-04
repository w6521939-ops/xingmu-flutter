# 贡献指南

感谢你对星幕 AI 漫剧工作室的兴趣！本文档帮助你快速参与项目贡献。

## 开发环境

| 工具 | 版本要求 |
|------|----------|
| Flutter | >= 3.22.0 |
| Dart | >= 3.4.0 |
| Android SDK | API 24+ |
| HarmonyOS SDK | API 20+ (OpenHarmony) |
| Python | >= 3.10 (后端服务) |

## 快速开始

```bash
git clone https://github.com/w6521939-ops/xingmu-flutter.git
cd xingmu-flutter
flutter pub get
flutter run
```

## 项目结构

- `lib/features/` — 功能模块，每个模块内分 domain / application / presentation 三层
- `lib/domain/` — 核心领域层（Agent 架构、管线、Provider）
- `lib/data/` — 数据层（HTTP 仓库、演示数据）
- `services/basic_video_server/` — Python 后端服务
- `test/` — 单元测试和 Widget 测试

## 编码规范

### Dart 代码

- 使用 `flutter analyze` 检查，不得有 error 级别问题
- 遵循 [Dart 官方风格指南](https://dart.dev/guides/language/effective-dart/style)
- 私有成员以 `_` 前缀
- 文件命名：`snake_case.dart`
- 类命名：`PascalCase`

### 架构约束

- **领域层** (`domain/`) 不依赖 UI 和平台包
- **功能模块** (`features/`) 内部分三层：domain → application → presentation
- **数据层** (`data/`) 实现 domain 层定义的接口
- 新增 Provider 时实现 `BaseProvider` 并注册到 `ProviderSelector`

### 安全红线

- **不得**在源码中硬编码 API Key
- **不得**提交 `.env` / `.env.*` 文件
- **不得**在日志中输出密钥或用户数据
- 所有密钥通过环境变量或 Keyring 加密存储注入

## 提交规范

提交信息格式：`<type>: <description>`

| type | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `refactor` | 重构 |
| `docs` | 文档变更 |
| `test` | 测试相关 |
| `chore` | 工程配置 |

示例：
```
feat: 添加口播视频管线
fix: 修复分镜工作台空指针异常
docs: 更新 README 管线说明
```

## PR 流程

1. Fork 仓库并创建功能分支：`feat/your-feature`
2. 确保通过 `flutter analyze` 和 `flutter test`
3. 提交 PR 并关联 Issue
4. 等待 CI 检查通过
5. 代码评审通过后合并

## 许可证

本项目采用 MIT + 商业双许可。提交的代码将同样受此许可证约束。

Copyright (c) 2026 w6521939 <w6521939@gmail.com>
