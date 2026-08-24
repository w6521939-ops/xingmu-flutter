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

### Flutter video_player and OpenHarmony adaptation

- Upstream project: Flutter `video_player` 2.10.1
- Upstream source: <https://github.com/flutter/packages/tree/main/packages/video_player/video_player>
- Upstream license: BSD-3-Clause
- CPF source: <https://gitcode.com/CPF-Flutter/flutter_packages>
- CPF revision/path: `97e9265ae2ab44c913d5d943ad68bec0c07a040e`, `packages/video_player/video_player`
- OpenHarmony implementation source: <https://gitcode.com/openharmony-tpc/flutter_packages>
- OpenHarmony implementation revision: `97e9265ae2ab44c913d5d943ad68bec0c07a040e`
- Usage: embedded playback of the same-origin final MP4 on Android and OpenHarmony

The package source and OpenHarmony adaptation remain subject to their upstream BSD-3-Clause license and notices. This repository pins the CPF revision because the OpenHarmony platform implementation is not provided by the default pub.dev package alone. The project does not relicense those sources under Apache-2.0 and does not bundle a provider video, codec binary or generated clip as part of this dependency notice.

### flutter_lints

- Source: <https://pub.dev/packages/flutter_lints>
- License: BSD 3-Clause
- Usage: development-only lint configuration

### @ohos/hypium

- Source: <https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fhypium>
- Version: 1.0.6
- License: Apache License 2.0
- Usage: development-only OpenHarmony `ohosTest` test framework

### Windows SAPI speech synthesis

- Component: Microsoft Speech API (SAPI) through .NET `System.Speech` / installed Windows voices
- Usage: optional local-development TTS for the three-shot motion-comic template
- Distribution boundary: this repository contains no Windows speech binary or voice model

The local TTS adapter is a Windows host capability, not a Flutter, Android or OpenHarmony runtime dependency. Availability depends on voices installed on the development machine. A distributor must not copy Microsoft voice data into this repository or imply that the voices are licensed under Apache-2.0.

## External services and optional backends

### Alibaba Cloud Model Studio (Bailian / DashScope)

- Source: <https://help.aliyun.com/zh/model-studio/>
- Usage: optional server-side Wan first-and-last-frame video provider; the production provider remains behind the trusted server
- Distribution boundary: this repository contains an opt-in development adapter, but no provider credential or provider model weight

Alibaba Cloud Model Studio is a hosted service, not code licensed under this repository. Operators must accept and follow the applicable service terms, regional requirements, content policies and pricing.

The local catalog displays `qwen3.6-plus`, `wan2.7-image-pro`, `wan2.7-i2v-2026-04-25` and `cosyvoice-v3.5-plus`. Only the Wan 2.7 first-and-last-frame video adapter is implemented, and it is unavailable unless a trusted server operator explicitly enables it and provides a server-side credential. The Qwen text, Wan image and CosyVoice adapters remain unimplemented. No real paid Wan request, charge or output-quality evaluation has been run for this repository.

### Wan2.2

- Source: <https://github.com/Wan-Video/Wan2.2>
- Upstream repository license: Apache License 2.0 at the time this notice was written
- Usage: optional self-hosted video-generation provider behind the same trusted server contract
- Distribution boundary: no Wan2.2 source code or model weight is included here

Operators must review the exact license and model card for the version/weights they deploy; this notice does not grant rights beyond the upstream terms.

### FFmpeg

- Source: <https://ffmpeg.org/>
- Usage: the optional local development service invokes a separately installed FFmpeg executable for MP4/GIF composition
- Distribution boundary: no FFmpeg source, library or binary is bundled in this repository

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

The launcher mark in `assets/branding/`, the original moon-courier hero artwork in `assets/showcase/`, and the visual concept in `docs/design/` were generated specifically for this project on 2026-08-20 with OpenAI's built-in image-generation tool. They do not copy an existing brand mark or franchise and contain no third-party stock asset.

The following six images were generated specifically for this project on 2026-08-21 with OpenAI's built-in image-generation tool:

- `assets/showcase/motion_comic/moon-courier-shot-01.png` — SHA-256 `D08A980877E12AF8808C564D186B4FCD9916BDDBC1CC86859EC0C65B43B65E6F`
- `assets/showcase/motion_comic/moon-courier-shot-02.png` — SHA-256 `5571043EC5F55DC1133DAF99A2AA7107F3C5F33A58BCE6783DBF2460BF6D85D1`
- `assets/showcase/motion_comic/moon-courier-shot-03.png` — SHA-256 `B2713FBED97FFE9FDCE91DC5E8627040EE1F5EB1AD9F7BBECD787381E678BCD1`
- `assets/showcase/motion_comic/moon-courier-shot-01-end.png` — SHA-256 `78A2FAEC73C6176EB6C53C059B913367669885453DBBF0B4D7B2B460B1019773`
- `assets/showcase/motion_comic/moon-courier-shot-02-end.png` — SHA-256 `9B68569CDD8C82BEC46E5FB3D438DDF8499A1321A8FB43E984D743A158BB32FC`
- `assets/showcase/motion_comic/moon-courier-shot-03-end.png` — SHA-256 `14AA600547C587DD0653982A4A13AEABE3B464F8E80E9D10666C51C6FE896326`

Their generation used the project's own 2026-08-20 moon-courier artwork as a visual reference to preserve the established character and art direction. The three `-end.png` files were generated with OpenAI ImageGen as matching tail frames for those same project-owned shots. No stock asset or third-party franchise was requested or used. All six are fixed visuals for the local template story `《月背最后一单》`; they are not redrawn from an arbitrary user theme and must not be represented as such.

`docs/screenshots/mobile-home.png` is rendered from this repository's deterministic demo UI. The project maintainer should retain the prompts, reference lineage and generation records for all ImageGen assets when redistributing them.

Only assets owned by the project or explicitly licensed for redistribution may be committed. Before a public release, maintainers must:

1. verify the provenance and license of every image, font, audio clip and video;
2. run Flutter's license collection for actual package dependencies;
3. update this file when source code or assets are copied, modified or newly bundled; and
4. preserve all upstream copyright, license and NOTICE files required by those dependencies.
