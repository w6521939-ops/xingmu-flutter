# Third-Party Notices

This repository is an independent Flutter client implementation. Unless a source file says otherwise, no source code, model weight, generated output, API credential, or media asset from the reference projects below is vendored in this repository.

## Runtime and development dependencies

### Flutter and Dart

- Project: Flutter / Dart
- Source: <https://github.com/flutter/flutter>
- License: BSD 3-Clause and component-specific notices in the upstream distribution
- Usage: Flutter framework, generated platform scaffold, build tooling and Dart SDK

The OpenHarmony build uses the CPF-Flutter fork and branch documented in the README:

- Source: <https://gitcode.com/CPF-Flutter/flutter_flutter>
- Usage: OpenHarmony platform support and build tooling

The fork's upstream license and bundled notices remain authoritative. No Flutter engine binary is relicensed by this project's Apache-2.0 license.

### flutter_lints

- Source: <https://pub.dev/packages/flutter_lints>
- License: BSD 3-Clause
- Usage: development-only lint configuration

### @ohos/hypium

- Source: <https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fhypium>
- Version: 1.0.6
- License: Apache License 2.0
- Usage: development-only OpenHarmony `ohosTest` test framework

## External services and optional backends

### Alibaba Cloud Model Studio (Bailian / DashScope)

- Source: <https://help.aliyun.com/zh/model-studio/>
- Usage: default remote provider behind the trusted server
- Distribution boundary: this repository contains no provider credential, server proxy implementation or provider model weight

Alibaba Cloud Model Studio is a hosted service, not code licensed under this repository. Operators must accept and follow the applicable service terms, regional requirements, content policies and pricing.

### Wan2.2

- Source: <https://github.com/Wan-Video/Wan2.2>
- Upstream repository license: Apache License 2.0 at the time this notice was written
- Usage: optional self-hosted video-generation provider behind the same trusted server contract
- Distribution boundary: no Wan2.2 source code or model weight is included here

Operators must review the exact license and model card for the version/weights they deploy; this notice does not grant rights beyond the upstream terms.

### FFmpeg

- Source: <https://ffmpeg.org/>
- Usage: recommended server-side media composition boundary
- Distribution boundary: no FFmpeg source, library or binary is bundled in this mobile client

FFmpeg licensing depends on build configuration and enabled codecs. A backend distributor must audit its own binary and comply with the applicable LGPL/GPL and codec patent obligations.

## Architecture references only

The following projects were considered for workflow or interface ideas. No code or assets from them are copied into this repository.

### MoneyPrinterTurbo

- Source: <https://github.com/harry0703/MoneyPrinterTurbo>
- Upstream license: MIT at the time this notice was written
- Reference boundary: asynchronous task and media-assembly workflow concepts only

### ComfyUI

- Source: <https://github.com/Comfy-Org/ComfyUI>
- Upstream license: GPL-3.0 at the time this notice was written
- Reference boundary: optional external workflow-service interface only

If a future deployment connects to ComfyUI, it must remain an independently deployed service unless a complete license review approves a different integration. This project's Apache-2.0 license does not override ComfyUI's GPL terms.

## Assets and generated notices

The launcher mark in `assets/branding/`, the moon-courier hero artwork in `assets/showcase/`, and the visual concept in `docs/design/` were generated specifically for this project on 2026-08-20 with OpenAI's built-in image-generation tool. They do not copy an existing brand mark or franchise and contain no third-party stock asset. `docs/screenshots/mobile-home.png` is rendered from this repository's deterministic demo UI. The project maintainer should retain the generation records when redistributing these assets.

Only assets owned by the project or explicitly licensed for redistribution may be committed. Before a public release, maintainers must:

1. verify the provenance and license of every image, font, audio clip and video;
2. run Flutter's license collection for actual package dependencies;
3. update this file when source code or assets are copied, modified or newly bundled; and
4. preserve all upstream copyright, license and NOTICE files required by those dependencies.
