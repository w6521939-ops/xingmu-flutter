"""Allowlisted FFmpeg pipeline for the local dynamic-caption model."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import textwrap
from typing import Callable


ProgressCallback = Callable[[int, str], None]
MIN_PROMPT_CHARS = 4
MAX_PROMPT_CHARS = 108


class VideoEngineError(RuntimeError):
    """Raised when the local FFmpeg pipeline cannot produce an output."""


class FfmpegVideoEngine:
    WIDTH = 720
    HEIGHT = 1280
    FRAME_RATE = 24

    def __init__(self, ffmpeg: str | None = None, ffprobe: str | None = None):
        self.ffmpeg = ffmpeg or os.environ.get("FFMPEG_BIN") or shutil.which("ffmpeg")
        self.ffprobe = ffprobe or os.environ.get("FFPROBE_BIN") or shutil.which("ffprobe")

    @property
    def available(self) -> bool:
        return bool(self.ffmpeg and self.ffprobe)

    def generate(
        self,
        prompt: str,
        duration_seconds: int,
        output_directory: Path,
        progress: ProgressCallback,
    ) -> tuple[Path, Path]:
        if not self.available:
            raise VideoEngineError("本机未找到 ffmpeg 或 ffprobe")

        output_directory.mkdir(parents=True, exist_ok=True)
        caption_path = output_directory / "caption.txt"
        video_path = output_directory / "video.mp4"
        preview_path = output_directory / "preview.gif"
        caption_path.write_text(self._caption(prompt), encoding="utf-8")

        progress(12, "准备字幕卡")
        self._run(
            self._video_command(duration_seconds),
            cwd=output_directory,
            timeout=120,
        )
        progress(76, "生成动图预览")
        self._run(self._gif_command(), cwd=output_directory, timeout=120)
        self._verify(video_path, preview_path)
        progress(96, "校验输出")
        return video_path, preview_path

    def probe_json(self, video_path: Path) -> str:
        if not self.ffprobe:
            raise VideoEngineError("本机未找到 ffprobe")
        command = [
            self.ffprobe,
            "-v",
            "error",
            "-show_entries",
            "stream=codec_type,codec_name,width,height,pix_fmt:format=duration",
            "-of",
            "json",
            str(video_path),
        ]
        return self._run(command, cwd=video_path.parent, timeout=30)

    def _video_command(self, duration_seconds: int) -> list[str]:
        assert self.ffmpeg is not None
        fade_out_start = max(0, duration_seconds - 1)
        font_option = self._font_option()
        video_filter = ",".join(
            [
                "drawbox=x=36:y=298:w=648:h=670:color=black@0.34:t=fill",
                "drawbox=x=56:y=300:w=7:h=668:color=0x65E5C4@0.96:t=fill",
                (
                    "drawtext="
                    f"{font_option}"
                    "text='XINGMU VIDEO LAB':expansion=none:"
                    "fontcolor=white@0.88:fontsize=28:x=56:y=92:"
                    "shadowcolor=black@0.5:shadowx=2:shadowy=2"
                ),
                (
                    "drawtext="
                    f"{font_option}"
                    "textfile='caption.txt':expansion=none:reload=0:"
                    "fontcolor=white:fontsize=46:line_spacing=18:"
                    "x=86:y=(h-text_h)/2:"
                    "shadowcolor=black@0.8:shadowx=3:shadowy=3"
                ),
                (
                    "drawtext="
                    f"{font_option}"
                    "text='LOCAL FFMPEG / 9\\:16':expansion=none:"
                    "fontcolor=white@0.7:fontsize=23:x=56:y=h-112"
                ),
                "fade=t=in:st=0:d=0.45",
                f"fade=t=out:st={fade_out_start}:d=1",
                "format=yuv420p",
            ]
        )
        audio_filter = (
            "volume=0.025,afade=t=in:st=0:d=0.45,"
            f"afade=t=out:st={fade_out_start}:d=1"
        )
        return [
            self.ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-f",
            "lavfi",
            "-i",
            (
                "gradients="
                f"s={self.WIDTH}x{self.HEIGHT}:r={self.FRAME_RATE}:"
                "c0=0x070B1C:c1=0x3B1D68:c2=0x006D77:n=3:"
                f"d={duration_seconds}:speed=0.018:type=radial"
            ),
            "-f",
            "lavfi",
            "-i",
            f"sine=frequency=220:sample_rate=44100:duration={duration_seconds}",
            "-vf",
            video_filter,
            "-af",
            audio_filter,
            "-t",
            str(duration_seconds),
            "-map",
            "0:v:0",
            "-map",
            "1:a:0",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "23",
            "-pix_fmt",
            "yuv420p",
            "-r",
            str(self.FRAME_RATE),
            "-c:a",
            "aac",
            "-b:a",
            "96k",
            "-ar",
            "44100",
            "-movflags",
            "+faststart",
            "-shortest",
            "video.mp4",
        ]

    def _gif_command(self) -> list[str]:
        assert self.ffmpeg is not None
        palette_filter = (
            "[0:v]fps=8,scale=360:640:flags=lanczos,split[s0][s1];"
            "[s0]palettegen=max_colors=96:stats_mode=diff[p];"
            "[s1][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle"
        )
        return [
            self.ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-ss",
            "0.35",
            "-i",
            "video.mp4",
            "-filter_complex",
            palette_filter,
            "-loop",
            "0",
            "preview.gif",
        ]

    def _verify(self, video_path: Path, preview_path: Path) -> None:
        if not video_path.is_file() or video_path.stat().st_size < 1_024:
            raise VideoEngineError("FFmpeg 未生成有效 MP4")
        if not preview_path.is_file() or preview_path.stat().st_size < 1_024:
            raise VideoEngineError("FFmpeg 未生成有效 GIF")
        with video_path.open("rb") as video_file:
            header = video_file.read(32)
        with preview_path.open("rb") as preview_file:
            gif_header = preview_file.read(6)
        if b"ftyp" not in header:
            raise VideoEngineError("MP4 文件头校验失败")
        if gif_header not in (b"GIF87a", b"GIF89a"):
            raise VideoEngineError("GIF 文件头校验失败")

    @staticmethod
    def _caption(prompt: str) -> str:
        normalized = " ".join(prompt.strip().split())
        if not MIN_PROMPT_CHARS <= len(normalized) <= MAX_PROMPT_CHARS:
            raise VideoEngineError(
                f"字幕文本长度必须为 {MIN_PROMPT_CHARS} 到 {MAX_PROMPT_CHARS} 个字符"
            )
        return "\n".join(textwrap.wrap(normalized, width=12, break_long_words=True))

    @staticmethod
    def _font_option() -> str:
        configured = os.environ.get("VIDEO_LAB_FONT")
        candidates = [
            configured,
            r"C:\Windows\Fonts\msyh.ttc",
            r"C:\Windows\Fonts\msyhbd.ttc",
            r"C:\Windows\Fonts\simhei.ttf",
            "/System/Library/Fonts/PingFang.ttc",
            "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ]
        for candidate in candidates:
            if candidate and Path(candidate).is_file():
                escaped = candidate.replace("\\", "/").replace(":", r"\:")
                escaped = escaped.replace("'", r"\'")
                return f"fontfile='{escaped}':"
        return ""

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
            raise VideoEngineError(f"FFmpeg 执行失败: {error}") from error
        if completed.returncode != 0:
            detail = completed.stdout.strip()[-1_500:]
            raise VideoEngineError(f"FFmpeg 返回 {completed.returncode}: {detail}")
        return completed.stdout
