"""Hybrid three-shot comic: fixed storyboard frames, Wan video, local voice."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import shutil
from typing import Any, Callable

try:
    from .comic_engine import (
        ASSET_PROVENANCE,
        CONTAINS_AI_GENERATED_ASSETS,
        TEMPLATE_SHOTS,
        TEMPLATE_STORY_TITLE,
        ComicGenerationResult,
        ComicVideoEngine,
    )
    from .model_catalog import (
        LOCAL_COMIC_IMAGE_MODEL_ID,
        LOCAL_COMIC_SCRIPT_MODEL_ID,
        LOCAL_COMIC_VOICE_MODEL_ID,
    )
    from .video_engine import FfmpegVideoEngine, VideoEngineError
    from .wan_video_provider import WAN_VIDEO_MODEL_ID, WanVideoProvider
except ImportError:  # Allows direct execution from this directory.
    from comic_engine import (
        ASSET_PROVENANCE,
        CONTAINS_AI_GENERATED_ASSETS,
        TEMPLATE_SHOTS,
        TEMPLATE_STORY_TITLE,
        ComicGenerationResult,
        ComicVideoEngine,
    )
    from model_catalog import (
        LOCAL_COMIC_IMAGE_MODEL_ID,
        LOCAL_COMIC_SCRIPT_MODEL_ID,
        LOCAL_COMIC_VOICE_MODEL_ID,
    )
    from video_engine import FfmpegVideoEngine, VideoEngineError
    from wan_video_provider import WAN_VIDEO_MODEL_ID, WanVideoProvider


HYBRID_EXECUTION_KIND = "hybrid"
HYBRID_VISUAL_SOURCE = "fixed_project_assets"
HYBRID_GENERATED_FOR_REQUEST = True
HYBRID_VISUAL_WARNING = (
    "本次请求只调用 Wan 按固定项目首尾帧生成视频片段；文本分镜是本地固定模板，"
    "画面首尾帧不会按 story 重绘，配音使用本机 Microsoft Huihui。"
)
LOCAL_MODEL_EXECUTION = {
    "text": "local",
    "image": "pre_generated",
    "video": "local",
    "voice": "local",
}
HYBRID_MODEL_EXECUTION = {
    "text": "local",
    "image": "pre_generated",
    "video": "cloud",
    "voice": "local",
}

_MOTION_PROMPTS = (
    "保持角色、宇航服和月背基地一致。快递员从远处稳步走近舱门，镜头缓慢推进，人物和背景产生自然视差，不要切镜。",
    "保持角色脸型、发型、宇航服和信件一致。她抬手打开信封并低头阅读，镜头轻微横移，衣料与信纸自然运动，不要切镜。",
    "保持角色、宇航服和月背平台一致。她抬头望向地球，基地灯光依次亮起，镜头缓慢拉远，不要切镜。",
)

HYBRID_SHOTS: tuple[dict[str, Any], ...] = tuple(
    {
        **deepcopy(shot),
        "firstFrameFile": shot["assetFile"],
        "lastFrameFile": f"moon-courier-shot-{index:02d}-end.png",
        "motionPrompt": _MOTION_PROMPTS[index - 1],
    }
    for index, shot in enumerate(TEMPLATE_SHOTS, start=1)
)


HybridProgressCallback = Callable[..., None]


class HybridWanComicVideoEngine(ComicVideoEngine):
    """Generate each shot remotely, then normalize/voice/concat the real clips."""

    def __init__(
        self,
        provider: WanVideoProvider,
        *,
        ffmpeg: str | None = None,
        ffprobe: str | None = None,
        tts=None,
        asset_root: Path | None = None,
    ) -> None:
        super().__init__(
            ffmpeg=ffmpeg,
            ffprobe=ffprobe,
            tts=tts,
            asset_root=asset_root,
        )
        self.provider = provider

    @property
    def assets_available(self) -> bool:
        return all(
            (self.asset_root / shot[field]).is_file()
            for shot in HYBRID_SHOTS
            for field in ("firstFrameFile", "lastFrameFile")
        )

    @property
    def available(self) -> bool:
        return bool(
            self.provider.available
            and self.ffmpeg
            and self.ffprobe
            and self.assets_available
            and self.tts_available
        )

    def generate(
        self,
        *,
        job_id: str,
        requested_story: str,
        shot_duration_seconds: int,
        output_directory: Path,
        progress: HybridProgressCallback,
    ) -> ComicGenerationResult:
        if not self.provider.available:
            raise VideoEngineError("Wan Provider Adapter 或服务端凭据未配置")
        if not self.ffmpeg or not self.ffprobe:
            raise VideoEngineError("本机未找到 ffmpeg 或 ffprobe")
        if not self.assets_available:
            raise VideoEngineError("Wan 漫剧需要三组明确的首帧和尾帧项目资产")
        if not self.tts_available:
            raise VideoEngineError(
                "未检测到 Microsoft Huihui Desktop 中文语音，Wan 混合漫剧不可用"
            )
        if shot_duration_seconds != self.SHOT_DURATION_SECONDS:
            raise VideoEngineError("Wan 混合漫剧每镜头时长固定为 3 秒")

        output_directory.mkdir(parents=True, exist_ok=True)
        shots = [
            {**deepcopy(shot), "durationSeconds": shot_duration_seconds}
            for shot in HYBRID_SHOTS
        ]
        script_path = output_directory / "script.json"
        manifest_path = output_directory / "manifest.json"
        video_path = output_directory / "video.mp4"
        preview_path = output_directory / "preview.gif"

        for shot in shots:
            number = int(shot["index"])
            first_copy = output_directory / f"shot-{number:02d}-first.png"
            last_copy = output_directory / f"shot-{number:02d}-last.png"
            shutil.copyfile(self.asset_root / shot["firstFrameFile"], first_copy)
            shutil.copyfile(self.asset_root / shot["lastFrameFile"], last_copy)
            shot["firstFrameUrl"] = self._shot_url(
                job_id, shot["id"], "first-frame.png"
            )
            shot["lastFrameUrl"] = self._shot_url(
                job_id, shot["id"], "last-frame.png"
            )
            shot["firstFrameSha256"] = self._sha256(first_copy)
            shot["lastFrameSha256"] = self._sha256(last_copy)
            shot["videoTask"] = {
                "status": "queued",
                "progress": 0,
            }

        self._write_json(script_path, self._script_document(requested_story, shots))

        clip_paths: list[Path] = []
        for offset, shot in enumerate(shots):
            number = int(shot["index"])
            shot_id = shot["id"]
            first_path = output_directory / f"shot-{number:02d}-first.png"
            last_path = output_directory / f"shot-{number:02d}-last.png"
            voice_path = output_directory / f"shot-{number:02d}-voice.wav"
            remote_path = output_directory / f"shot-{number:02d}-provider.mp4"
            clip_path = output_directory / f"shot-{number:02d}.mp4"

            progress(
                4 + offset * 28,
                f"正在合成第 {number} 镜配音",
                "synthesizing_voice",
                shot_id,
                5,
                "running",
                self._shot_metadata(shot),
            )
            self.tts.synthesize(shot["narration"], voice_path)
            voice_duration = self._probe_duration(voice_path)
            voice_tempo = self._voice_tempo(voice_duration, shot_duration_seconds)
            shot["voiceSourceDurationSeconds"] = round(voice_duration, 3)
            shot["voiceTempo"] = round(voice_tempo, 4)

            def report_remote(
                remote_task_id: str,
                remote_status: str,
                remote_progress: int,
                *,
                current_shot: dict[str, Any] = shot,
                current_offset: int = offset,
            ) -> None:
                normalized_status = {
                    "PENDING": "queued",
                    "RUNNING": "running",
                    "SUCCEEDED": "running",
                }[remote_status]
                current_shot["videoTask"] = {
                    "remoteTaskId": remote_task_id,
                    "status": normalized_status,
                    "progress": min(95, remote_progress),
                }
                progress(
                    min(89, 8 + current_offset * 28 + remote_progress // 5),
                    f"Wan 正在生成第 {current_offset + 1} 镜视频",
                    "generating_shot_video",
                    current_shot["id"],
                    min(90, remote_progress),
                    "running",
                    self._shot_metadata(current_shot),
                )

            try:
                result = self.provider.generate_shot(
                    prompt=shot["motionPrompt"],
                    first_frame=first_path,
                    last_frame=last_path,
                    duration_seconds=shot_duration_seconds,
                    output_path=remote_path,
                    status=report_remote,
                )
                shot["providerVideoSha256"] = self._sha256(remote_path)
                self._normalize_generated_shot(
                    shot=shot,
                    remote_path=remote_path,
                    voice_path=voice_path,
                    output_path=clip_path,
                    duration_seconds=shot_duration_seconds,
                    voice_tempo=voice_tempo,
                )
            except Exception as error:
                video_task = deepcopy(shot.get("videoTask", {}))
                video_task.update(
                    status="failed",
                    progress=100,
                    error=(str(error).strip() or "Wan 镜头生成失败")[:500],
                )
                shot["videoTask"] = video_task
                progress(
                    100,
                    f"第 {number} 镜视频生成失败",
                    "failed",
                    shot_id,
                    100,
                    "failed",
                    self._shot_metadata(shot),
                )
                raise

            shot["videoTask"] = {
                "remoteTaskId": result.remote_task_id,
                "status": "succeeded",
                "progress": 100,
                "videoUrl": self._shot_url(job_id, shot_id, "video.mp4"),
            }
            clip_paths.append(clip_path)
            progress(
                28 + offset * 28,
                f"第 {number} 镜真实视频片段完成",
                "normalizing_shot_video",
                shot_id,
                100,
                "succeeded",
                self._shot_metadata(shot),
            )

        progress(90, "正在拼接三段真实镜头视频", "composing", None, None, None)
        self._compose(clip_paths, output_directory, video_path)
        progress(94, "正在生成动图预览", "generating_preview", None, None, None)
        self._generate_preview(output_directory)
        progress(97, "正在校验漫剧成片", "verifying", None, None, None)
        self._verify(video_path, preview_path, shot_duration_seconds)
        self._write_json(
            manifest_path,
            self._manifest_document(
                job_id=job_id,
                requested_story=requested_story,
                shots=shots,
                shot_duration_seconds=shot_duration_seconds,
            ),
        )
        return ComicGenerationResult(
            video_path=video_path,
            preview_path=preview_path,
            manifest_path=manifest_path,
            script_path=script_path,
            shots=tuple(shots),
        )

    def _normalize_generated_shot(
        self,
        *,
        shot: dict[str, Any],
        remote_path: Path,
        voice_path: Path,
        output_path: Path,
        duration_seconds: int,
        voice_tempo: float,
    ) -> None:
        assert self.ffmpeg is not None
        number = int(shot["index"])
        subtitle_path = output_path.with_name(f"shot-{number:02d}-subtitle.txt")
        title_path = output_path.with_name(f"shot-{number:02d}-title.txt")
        subtitle_path.write_text(self._wrap_subtitle(shot["subtitle"]), encoding="utf-8")
        title_path.write_text(
            f"{TEMPLATE_STORY_TITLE}  ·  {shot['title']}",
            encoding="utf-8",
        )
        font_option = FfmpegVideoEngine._font_option()
        fade_out = max(0.0, duration_seconds - 0.28)
        video_filter = ",".join(
            [
                "scale=720:1280:force_original_aspect_ratio=increase",
                "crop=720:1280",
                f"fps={self.FRAME_RATE}",
                "setsar=1",
                "drawbox=x=28:y=ih-254:w=iw-56:h=172:color=black@0.58:t=fill",
                (
                    "drawtext="
                    f"{font_option}textfile='{title_path.name}':expansion=none:"
                    "fontcolor=0xBFEFFF:fontsize=24:x=52:y=h-231:"
                    "shadowcolor=black@0.8:shadowx=2:shadowy=2"
                ),
                (
                    "drawtext="
                    f"{font_option}textfile='{subtitle_path.name}':expansion=none:"
                    "fontcolor=white:fontsize=39:line_spacing=10:"
                    "x=(w-text_w)/2:y=h-187:"
                    "shadowcolor=black@0.9:shadowx=3:shadowy=3"
                ),
                "fade=t=in:st=0:d=0.18",
                f"fade=t=out:st={fade_out:.2f}:d=0.28",
                "format=yuv420p",
            ]
        )
        audio_filter = ";".join(
            [
                (
                    f"[1:a]aformat=sample_rates=44100:channel_layouts=mono,"
                    f"atempo={voice_tempo:.4f},volume=1.20,"
                    f"apad=pad_dur={duration_seconds},atrim=0:{duration_seconds},"
                    "afade=t=in:st=0:d=0.08,"
                    f"afade=t=out:st={fade_out:.2f}:d=0.28[voice]"
                ),
                (
                    f"[2:a]volume=0.022,lowpass=f=260,"
                    "afade=t=in:st=0:d=0.18,"
                    f"afade=t=out:st={fade_out:.2f}:d=0.28[bed]"
                ),
                "[voice][bed]amix=inputs=2:duration=longest:normalize=0,"
                "alimiter=limit=0.95[aout]",
            ]
        )
        self._run(
            [
                self.ffmpeg,
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                str(remote_path.resolve()),
                "-i",
                str(voice_path.resolve()),
                "-f",
                "lavfi",
                "-i",
                f"sine=frequency={88 + number * 7}:sample_rate=44100:duration={duration_seconds}",
                "-vf",
                video_filter,
                "-filter_complex",
                audio_filter,
                "-map",
                "0:v:0",
                "-map",
                "[aout]",
                "-t",
                str(duration_seconds),
                "-c:v",
                "libx264",
                "-preset",
                "veryfast",
                "-crf",
                "22",
                "-pix_fmt",
                "yuv420p",
                "-r",
                str(self.FRAME_RATE),
                "-c:a",
                "aac",
                "-b:a",
                "128k",
                "-ar",
                "44100",
                "-movflags",
                "+faststart",
                str(output_path.resolve()),
            ],
            cwd=output_path.parent,
            timeout=240,
        )

    @staticmethod
    def _shot_url(job_id: str, shot_id: str, file_name: str) -> str:
        return f"/v1/comic-jobs/{job_id}/shots/{shot_id}/{file_name}"

    @staticmethod
    def _shot_metadata(shot: dict[str, Any]) -> dict[str, Any]:
        return {
            "firstFrameUrl": shot["firstFrameUrl"],
            "lastFrameUrl": shot["lastFrameUrl"],
            "motionPrompt": shot["motionPrompt"],
            "videoTask": deepcopy(shot["videoTask"]),
        }

    @staticmethod
    def _script_document(
        requested_story: str,
        shots: list[dict[str, Any]],
    ) -> dict[str, Any]:
        script_shots = []
        for shot in shots:
            item = deepcopy(shot)
            item.pop("videoTask", None)
            script_shots.append(item)
        return {
            "schemaVersion": "1.1",
            "executionKind": HYBRID_EXECUTION_KIND,
            "visualSource": HYBRID_VISUAL_SOURCE,
            "generatedForRequest": HYBRID_GENERATED_FOR_REQUEST,
            "containsAiGeneratedAssets": CONTAINS_AI_GENERATED_ASSETS,
            "assetProvenance": ASSET_PROVENANCE,
            "requestedStory": requested_story,
            "templateStoryTitle": TEMPLATE_STORY_TITLE,
            "visualWarning": HYBRID_VISUAL_WARNING,
            "modelExecution": deepcopy(HYBRID_MODEL_EXECUTION),
            "title": TEMPLATE_STORY_TITLE,
            "shots": script_shots,
        }

    def _manifest_document(
        self,
        *,
        job_id: str,
        requested_story: str,
        shots: list[dict[str, Any]],
        shot_duration_seconds: int,
    ) -> dict[str, Any]:
        base = f"/v1/comic-jobs/{job_id}"
        return {
            "schemaVersion": "1.1",
            "jobId": job_id,
            "executionKind": HYBRID_EXECUTION_KIND,
            "visualSource": HYBRID_VISUAL_SOURCE,
            "generatedForRequest": HYBRID_GENERATED_FOR_REQUEST,
            "containsAiGeneratedAssets": CONTAINS_AI_GENERATED_ASSETS,
            "assetProvenance": ASSET_PROVENANCE,
            "requestedStory": requested_story,
            "templateStoryTitle": TEMPLATE_STORY_TITLE,
            "visualWarning": HYBRID_VISUAL_WARNING,
            "modelExecution": deepcopy(HYBRID_MODEL_EXECUTION),
            "compositionType": "shot_videos_concat",
            "sourceClipCount": 3,
            "aspectRatio": "9:16",
            "width": 720,
            "height": 1280,
            "shotCount": 3,
            "shotDurationSeconds": shot_duration_seconds,
            "durationSeconds": shot_duration_seconds * 3,
            "models": {
                "textModelId": LOCAL_COMIC_SCRIPT_MODEL_ID,
                "imageModelId": LOCAL_COMIC_IMAGE_MODEL_ID,
                "videoModelId": WAN_VIDEO_MODEL_ID,
                "voiceModelId": LOCAL_COMIC_VOICE_MODEL_ID,
            },
            "shots": [
                {
                    **deepcopy(shot),
                    "status": "succeeded",
                    "progress": 100,
                    "visualSource": HYBRID_VISUAL_SOURCE,
                    "firstFrameAsset": (
                        "assets/showcase/motion_comic/" + shot["firstFrameFile"]
                    ),
                    "lastFrameAsset": (
                        "assets/showcase/motion_comic/" + shot["lastFrameFile"]
                    ),
                }
                for shot in shots
            ],
            "output": {
                "previewUrl": f"{base}/preview.gif",
                "videoUrl": f"{base}/video.mp4",
                "manifestUrl": f"{base}/manifest.json",
                "scriptUrl": f"{base}/script.json",
                "compositionType": "shot_videos_concat",
                "sourceClipCount": 3,
            },
        }
