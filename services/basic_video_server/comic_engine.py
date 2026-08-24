"""Fixed-asset, three-shot motion-comic pipeline for local validation."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from typing import Any, Callable

try:
    from .model_catalog import (
        LOCAL_COMIC_IMAGE_MODEL_ID,
        LOCAL_COMIC_SCRIPT_MODEL_ID,
        LOCAL_COMIC_VIDEO_MODEL_ID,
        LOCAL_COMIC_VOICE_MODEL_ID,
    )
    from .video_engine import FfmpegVideoEngine, VideoEngineError
except ImportError:  # Allows direct execution from this directory.
    from model_catalog import (
        LOCAL_COMIC_IMAGE_MODEL_ID,
        LOCAL_COMIC_SCRIPT_MODEL_ID,
        LOCAL_COMIC_VIDEO_MODEL_ID,
        LOCAL_COMIC_VOICE_MODEL_ID,
    )
    from video_engine import FfmpegVideoEngine, VideoEngineError


ComicProgressCallback = Callable[
    [int, str, str, str | None, int | None, str | None],
    None,
]

TEMPLATE_STORY_TITLE = "月背最后一单"
EXECUTION_KIND = "template"
VISUAL_SOURCE = "fixed_project_assets"
GENERATED_FOR_REQUEST = False
CONTAINS_AI_GENERATED_ASSETS = True
ASSET_PROVENANCE = "openai_imagegen_project_assets"
VISUAL_WARNING = (
    "本次请求未调用 AI，也未按 story 重新绘制；画面是预先生成且有来源记录的 "
    "OpenAI ImageGen 项目素材。"
)

TEMPLATE_SHOTS: tuple[dict[str, Any], ...] = (
    {
        "id": "E01-SH01",
        "index": 1,
        "title": "抵达月背",
        "narration": "月背停电第七天，她送来最后一封信。",
        "subtitle": "月背停电第七天，她送来最后一封信。",
        "assetFile": "moon-courier-shot-01.png",
        "motion": "slow_zoom_in",
    },
    {
        "id": "E01-SH02",
        "index": 2,
        "title": "打开来信",
        "narration": "信上写着：别怕，灯会再亮。",
        "subtitle": "信上写着：别怕，灯会再亮。",
        "assetFile": "moon-courier-shot-02.png",
        "motion": "pan_left_to_right",
    },
    {
        "id": "E01-SH03",
        "index": 3,
        "title": "望向地球",
        "narration": "最后一单送达，月光重新亮起。",
        "subtitle": "最后一单送达，月光重新亮起。",
        "assetFile": "moon-courier-shot-03.png",
        "motion": "slow_zoom_out",
    },
)


@dataclass(frozen=True)
class ComicGenerationResult:
    video_path: Path
    preview_path: Path
    manifest_path: Path
    script_path: Path
    shots: tuple[dict[str, Any], ...]


class HuihuiTtsEngine:
    """Invoke Windows SAPI through a fixed script and path-only arguments."""

    VOICE_NAME = "Microsoft Huihui Desktop"

    def __init__(
        self,
        powershell: str | None = None,
        script_path: Path | None = None,
    ) -> None:
        self.powershell = (
            powershell
            or shutil.which("powershell.exe")
            or shutil.which("powershell")
        )
        self.script_path = (
            script_path or Path(__file__).resolve().with_name("huihui_tts.ps1")
        ).resolve()
        self._available: bool | None = None

    @property
    def available(self) -> bool:
        if self._available is None:
            self._available = self._probe()
        return self._available

    def synthesize(self, text: str, output_path: Path) -> None:
        if not self.available:
            raise VideoEngineError(
                "未检测到 Microsoft Huihui Desktop 中文语音，漫剧模板不可用"
            )
        output_path.parent.mkdir(parents=True, exist_ok=True)
        input_path = output_path.with_suffix(".txt")
        input_path.write_text(text, encoding="utf-8")
        try:
            self._run(
                [
                    "-NoLogo",
                    "-NoProfile",
                    "-NonInteractive",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(self.script_path),
                    "-InputPath",
                    str(input_path.resolve()),
                    "-OutputPath",
                    str(output_path.resolve()),
                    "-VoiceName",
                    self.VOICE_NAME,
                ],
                timeout=30,
            )
        finally:
            input_path.unlink(missing_ok=True)
        if not output_path.is_file() or output_path.stat().st_size <= 44:
            raise VideoEngineError("Huihui 未生成有效 WAV 配音")

    def _probe(self) -> bool:
        if os.name != "nt" or not self.powershell or not self.script_path.is_file():
            return False
        try:
            self._run(
                [
                    "-NoLogo",
                    "-NoProfile",
                    "-NonInteractive",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(self.script_path),
                    "-Probe",
                    "-VoiceName",
                    self.VOICE_NAME,
                ],
                timeout=15,
            )
        except VideoEngineError:
            return False
        return True

    def _run(self, arguments: list[str], timeout: int) -> None:
        if not self.powershell:
            raise VideoEngineError("本机未找到 Windows PowerShell")
        creation_flags = 0
        if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW"):
            creation_flags = subprocess.CREATE_NO_WINDOW
        try:
            completed = subprocess.run(
                [self.powershell, *arguments],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
                check=False,
                shell=False,
                creationflags=creation_flags,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise VideoEngineError(f"Huihui 配音执行失败: {error}") from error
        if completed.returncode != 0:
            detail = completed.stdout.strip()[-800:]
            raise VideoEngineError(
                f"Huihui 配音返回 {completed.returncode}: {detail}"
            )


class ComicVideoEngine:
    WIDTH = 720
    HEIGHT = 1280
    FRAME_RATE = 24
    SHOT_COUNT = 3
    SHOT_DURATION_SECONDS = 3

    def __init__(
        self,
        ffmpeg: str | None = None,
        ffprobe: str | None = None,
        tts: HuihuiTtsEngine | None = None,
        asset_root: Path | None = None,
    ) -> None:
        media_engine = FfmpegVideoEngine(ffmpeg=ffmpeg, ffprobe=ffprobe)
        self.ffmpeg = media_engine.ffmpeg
        self.ffprobe = media_engine.ffprobe
        self.tts = tts or HuihuiTtsEngine()
        repository_root = Path(__file__).resolve().parents[2]
        self.asset_root = (
            asset_root
            or repository_root / "assets" / "showcase" / "motion_comic"
        ).resolve()

    @property
    def tts_available(self) -> bool:
        return self.tts.available

    @property
    def assets_available(self) -> bool:
        return all((self.asset_root / shot["assetFile"]).is_file() for shot in TEMPLATE_SHOTS)

    @property
    def available(self) -> bool:
        return bool(
            self.ffmpeg
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
        progress: ComicProgressCallback,
    ) -> ComicGenerationResult:
        if not self.ffmpeg or not self.ffprobe:
            raise VideoEngineError("本机未找到 ffmpeg 或 ffprobe")
        if not self.assets_available:
            raise VideoEngineError("月球快递员三镜头项目资产不完整")
        if not self.tts_available:
            raise VideoEngineError(
                "未检测到 Microsoft Huihui Desktop 中文语音，漫剧模板不可用"
            )
        if shot_duration_seconds != self.SHOT_DURATION_SECONDS:
            raise VideoEngineError("本地漫剧模板每镜头时长固定为 3 秒")

        output_directory.mkdir(parents=True, exist_ok=True)
        shots = [
            {**deepcopy(shot), "durationSeconds": shot_duration_seconds}
            for shot in TEMPLATE_SHOTS
        ]
        script_path = output_directory / "script.json"
        manifest_path = output_directory / "manifest.json"
        video_path = output_directory / "video.mp4"
        preview_path = output_directory / "preview.gif"
        self._write_json(
            script_path,
            self._script_document(requested_story, shots),
        )

        clip_paths: list[Path] = []
        for offset, shot in enumerate(shots):
            shot_id = shot["id"]
            progress(
                6 + offset * 24,
                f"正在合成第 {offset + 1} 镜配音",
                "synthesizing_voice",
                shot_id,
                12,
                "running",
            )
            voice_path = output_directory / f"shot-{offset + 1:02d}-voice.wav"
            self.tts.synthesize(shot["narration"], voice_path)
            voice_duration = self._probe_duration(voice_path)
            voice_tempo = self._voice_tempo(
                voice_duration,
                shot_duration_seconds,
            )
            shot["voiceSourceDurationSeconds"] = round(voice_duration, 3)
            shot["voiceTempo"] = round(voice_tempo, 4)
            progress(
                12 + offset * 24,
                f"正在渲染第 {offset + 1} 镜动效",
                "rendering_shot",
                shot_id,
                45,
                "running",
            )
            clip_path = output_directory / f"shot-{offset + 1:02d}.mp4"
            self._render_shot(
                shot=shot,
                voice_path=voice_path,
                output_path=clip_path,
                duration_seconds=shot_duration_seconds,
                voice_tempo=voice_tempo,
            )
            clip_paths.append(clip_path)
            progress(
                24 + offset * 24,
                f"第 {offset + 1} 镜完成",
                "rendering_shot",
                shot_id,
                100,
                "succeeded",
            )

        progress(80, "正在拼接三镜头", "composing", None, None, None)
        self._compose(clip_paths, output_directory, video_path)
        progress(91, "正在生成动图预览", "generating_preview", None, None, None)
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

    def probe_json(self, video_path: Path) -> str:
        if not self.ffprobe:
            raise VideoEngineError("本机未找到 ffprobe")
        return self._run(
            [
                self.ffprobe,
                "-v",
                "error",
                "-show_entries",
                "stream=codec_type,codec_name,width,height,pix_fmt:format=duration",
                "-of",
                "json",
                str(video_path),
            ],
            cwd=video_path.parent,
            timeout=30,
        )

    def _probe_duration(self, media_path: Path) -> float:
        if not self.ffprobe:
            raise VideoEngineError("本机未找到 ffprobe")
        output = self._run(
            [
                self.ffprobe,
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "json",
                str(media_path),
            ],
            cwd=media_path.parent,
            timeout=30,
        )
        try:
            return float(json.loads(output)["format"]["duration"])
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
            raise VideoEngineError("无法读取 Huihui 配音时长") from error

    @staticmethod
    def _voice_tempo(source_duration: float, shot_duration: int) -> float:
        target_duration = shot_duration - 0.15
        tempo = max(1.0, source_duration / target_duration)
        if tempo > 2.0:
            raise VideoEngineError("固定剧本配音过长，无法安全压入 3 秒镜头")
        return tempo

    def _render_shot(
        self,
        *,
        shot: dict[str, Any],
        voice_path: Path,
        output_path: Path,
        duration_seconds: int,
        voice_tempo: float,
    ) -> None:
        assert self.ffmpeg is not None
        shot_number = int(shot["index"])
        frame_count = duration_seconds * self.FRAME_RATE
        subtitle_path = output_path.with_name(f"shot-{shot_number:02d}-subtitle.txt")
        title_path = output_path.with_name(f"shot-{shot_number:02d}-title.txt")
        subtitle_path.write_text(
            self._wrap_subtitle(shot["subtitle"]),
            encoding="utf-8",
        )
        title_path.write_text(
            f"{TEMPLATE_STORY_TITLE}  ·  {shot['title']}",
            encoding="utf-8",
        )
        motion = self._motion_filter(shot["motion"], frame_count)
        font_option = FfmpegVideoEngine._font_option()
        fade_out = max(0.0, duration_seconds - 0.28)
        video_filter = ",".join(
            [
                "scale=900:1600:force_original_aspect_ratio=increase",
                "crop=900:1600",
                motion,
                "setsar=1",
                "drawbox=x=28:y=ih-254:w=iw-56:h=172:color=black@0.58:t=fill",
                (
                    "drawtext="
                    f"{font_option}"
                    f"textfile='{title_path.name}':expansion=none:"
                    "fontcolor=0xBFEFFF:fontsize=24:x=52:y=h-231:"
                    "shadowcolor=black@0.8:shadowx=2:shadowy=2"
                ),
                (
                    "drawtext="
                    f"{font_option}"
                    f"textfile='{subtitle_path.name}':expansion=none:"
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
                    f"atempo={voice_tempo:.4f},"
                    f"volume=1.20,apad=pad_dur={duration_seconds},"
                    f"atrim=0:{duration_seconds},afade=t=in:st=0:d=0.08,"
                    f"afade=t=out:st={fade_out:.2f}:d=0.28[voice]"
                ),
                (
                    f"[2:a]volume=0.022,lowpass=f=260,"
                    f"afade=t=in:st=0:d=0.18,"
                    f"afade=t=out:st={fade_out:.2f}:d=0.28[bed]"
                ),
                "[voice][bed]amix=inputs=2:duration=longest:normalize=0,"
                "alimiter=limit=0.95[aout]",
            ]
        )
        command = [
            self.ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-loop",
            "1",
            "-framerate",
            str(self.FRAME_RATE),
            "-i",
            str((self.asset_root / shot["assetFile"]).resolve()),
            "-i",
            str(voice_path.resolve()),
            "-f",
            "lavfi",
            "-i",
            f"sine=frequency={88 + shot_number * 7}:sample_rate=44100:duration={duration_seconds}",
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
        ]
        self._run(command, cwd=output_path.parent, timeout=180)

    def _compose(
        self,
        clip_paths: list[Path],
        output_directory: Path,
        video_path: Path,
    ) -> None:
        assert self.ffmpeg is not None
        concat_path = output_directory / "shots.concat.txt"
        concat_path.write_text(
            "".join(f"file '{path.name}'\n" for path in clip_paths),
            encoding="utf-8",
        )
        self._run(
            [
                self.ffmpeg,
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-f",
                "concat",
                "-safe",
                "1",
                "-i",
                concat_path.name,
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
                video_path.name,
            ],
            cwd=output_directory,
            timeout=240,
        )

    def _generate_preview(self, output_directory: Path) -> None:
        assert self.ffmpeg is not None
        palette_filter = (
            "[0:v]fps=8,scale=360:640:flags=lanczos,split[s0][s1];"
            "[s0]palettegen=max_colors=96:stats_mode=diff[p];"
            "[s1][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle"
        )
        self._run(
            [
                self.ffmpeg,
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                "video.mp4",
                "-filter_complex",
                palette_filter,
                "-loop",
                "0",
                "preview.gif",
            ],
            cwd=output_directory,
            timeout=180,
        )

    def _verify(
        self,
        video_path: Path,
        preview_path: Path,
        shot_duration_seconds: int,
    ) -> None:
        if not video_path.is_file() or video_path.stat().st_size < 16_384:
            raise VideoEngineError("漫剧管线未生成有效 MP4")
        if not preview_path.is_file() or preview_path.stat().st_size < 1_024:
            raise VideoEngineError("漫剧管线未生成有效 GIF")
        probe = json.loads(self.probe_json(video_path))
        streams = {stream["codec_type"]: stream for stream in probe.get("streams", [])}
        video = streams.get("video", {})
        audio = streams.get("audio", {})
        expected_duration = self.SHOT_COUNT * shot_duration_seconds
        duration = float(probe.get("format", {}).get("duration", 0))
        if (
            video.get("codec_name") != "h264"
            or video.get("width") != self.WIDTH
            or video.get("height") != self.HEIGHT
            or video.get("pix_fmt") != "yuv420p"
            or audio.get("codec_name") != "aac"
            or duration < expected_duration - 0.5
        ):
            raise VideoEngineError("漫剧 MP4 编码、尺寸、音轨或时长校验失败")
        if not preview_path.read_bytes()[:6] in (b"GIF87a", b"GIF89a"):
            raise VideoEngineError("漫剧 GIF 文件头校验失败")

    @staticmethod
    def _motion_filter(motion: str, frame_count: int) -> str:
        last_frame = max(1, frame_count - 1)
        if motion == "slow_zoom_in":
            return (
                "zoompan=z='min(zoom+0.0012,1.08)':"
                "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
                f"d={frame_count}:s=720x1280:fps=24"
            )
        if motion == "pan_left_to_right":
            return (
                "zoompan=z='1.08':"
                f"x='(iw-iw/zoom)*on/{last_frame}':"
                "y='ih/2-(ih/zoom/2)':"
                f"d={frame_count}:s=720x1280:fps=24"
            )
        return (
            "zoompan=z='if(eq(on,0),1.08,max(zoom-0.0011,1.0))':"
            "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
            f"d={frame_count}:s=720x1280:fps=24"
        )

    @staticmethod
    def _wrap_subtitle(value: str) -> str:
        normalized = " ".join(value.strip().split())
        if len(normalized) <= 13:
            return normalized
        split_at = (len(normalized) + 1) // 2
        while (
            split_at < len(normalized) - 1
            and normalized[split_at] in "，。！？：；、"
        ):
            split_at += 1
        return f"{normalized[:split_at]}\n{normalized[split_at:]}"

    @staticmethod
    def _script_document(
        requested_story: str,
        shots: list[dict[str, Any]],
    ) -> dict[str, Any]:
        return {
            "schemaVersion": "1.0",
            "executionKind": EXECUTION_KIND,
            "visualSource": VISUAL_SOURCE,
            "generatedForRequest": GENERATED_FOR_REQUEST,
            "containsAiGeneratedAssets": CONTAINS_AI_GENERATED_ASSETS,
            "assetProvenance": ASSET_PROVENANCE,
            "requestedStory": requested_story,
            "templateStoryTitle": TEMPLATE_STORY_TITLE,
            "visualWarning": VISUAL_WARNING,
            "title": TEMPLATE_STORY_TITLE,
            "logline": "停电基地收到月球快递员送来的最后一封信，重新点亮希望。",
            "characters": [
                {
                    "id": "C01",
                    "name": "月球快递员",
                    "appearanceLock": "白灰宇航服、蓝色背部能源环、黑色马尾",
                }
            ],
            "scenes": [
                {
                    "id": "S01",
                    "name": "月背基地内外",
                    "environmentLock": "蓝黑月面、冷蓝与暖橙灯光、停电中的月背基地内外",
                }
            ],
            "shots": deepcopy(shots),
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
            "schemaVersion": "1.0",
            "jobId": job_id,
            "executionKind": EXECUTION_KIND,
            "visualSource": VISUAL_SOURCE,
            "generatedForRequest": GENERATED_FOR_REQUEST,
            "containsAiGeneratedAssets": CONTAINS_AI_GENERATED_ASSETS,
            "assetProvenance": ASSET_PROVENANCE,
            "requestedStory": requested_story,
            "templateStoryTitle": TEMPLATE_STORY_TITLE,
            "visualWarning": VISUAL_WARNING,
            "aspectRatio": "9:16",
            "width": 720,
            "height": 1280,
            "shotCount": 3,
            "shotDurationSeconds": shot_duration_seconds,
            "durationSeconds": shot_duration_seconds * 3,
            "models": {
                "textModelId": LOCAL_COMIC_SCRIPT_MODEL_ID,
                "imageModelId": LOCAL_COMIC_IMAGE_MODEL_ID,
                "videoModelId": LOCAL_COMIC_VIDEO_MODEL_ID,
                "voiceModelId": LOCAL_COMIC_VOICE_MODEL_ID,
            },
            "shots": [
                {
                    **deepcopy(shot),
                    "status": "succeeded",
                    "progress": 100,
                    "visualSource": VISUAL_SOURCE,
                    "sourceAsset": (
                        "assets/showcase/motion_comic/" + shot["assetFile"]
                    ),
                    "sourceAssetSha256": self._sha256(
                        self.asset_root / shot["assetFile"]
                    ),
                }
                for shot in shots
            ],
            "output": {
                "previewUrl": f"{base}/preview.gif",
                "videoUrl": f"{base}/video.mp4",
                "manifestUrl": f"{base}/manifest.json",
                "scriptUrl": f"{base}/script.json",
            },
        }

    @staticmethod
    def _sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest().upper()

    @staticmethod
    def _write_json(path: Path, payload: dict[str, Any]) -> None:
        path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    @staticmethod
    def _run(command: list[str], cwd: Path, timeout: int) -> str:
        creation_flags = 0
        if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW"):
            creation_flags = subprocess.CREATE_NO_WINDOW
        try:
            completed = subprocess.run(
                command,
                cwd=str(cwd),
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
                check=False,
                shell=False,
                creationflags=creation_flags,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise VideoEngineError(f"漫剧媒体处理失败: {error}") from error
        if completed.returncode != 0:
            detail = completed.stdout.strip()[-1_500:]
            raise VideoEngineError(
                f"漫剧媒体处理返回 {completed.returncode}: {detail}"
            )
        return completed.stdout
