"""Dependency-free HTTP service for Xingmu's minimum local video loop."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import threading
from typing import Any
from urllib.parse import unquote, urlsplit
from uuid import UUID, uuid4

try:
    from .comic_engine import (
        ASSET_PROVENANCE,
        CONTAINS_AI_GENERATED_ASSETS,
        EXECUTION_KIND,
        GENERATED_FOR_REQUEST,
        TEMPLATE_SHOTS,
        TEMPLATE_STORY_TITLE,
        VISUAL_SOURCE,
        VISUAL_WARNING,
        ComicVideoEngine,
    )
    from .hybrid_comic_engine import (
        HYBRID_EXECUTION_KIND,
        HYBRID_GENERATED_FOR_REQUEST,
        HYBRID_MODEL_EXECUTION,
        HYBRID_SHOTS,
        HYBRID_VISUAL_SOURCE,
        HYBRID_VISUAL_WARNING,
        LOCAL_MODEL_EXECUTION,
        HybridWanComicVideoEngine,
    )
    from .model_catalog import (
        LOCAL_COMIC_IMAGE_MODEL_ID,
        LOCAL_COMIC_SCRIPT_MODEL_ID,
        LOCAL_COMIC_VIDEO_MODEL_ID,
        LOCAL_COMIC_VOICE_MODEL_ID,
        WAN_VIDEO_MODEL_ID,
        available_model_ids,
        get_model_catalog,
    )
    from .wan_video_provider import WanProviderConfig, WanVideoProvider
    from .video_engine import (
        MAX_PROMPT_CHARS,
        MIN_PROMPT_CHARS,
        FfmpegVideoEngine,
    )
except ImportError:  # Allows `python server.py` from this directory.
    from comic_engine import (
        ASSET_PROVENANCE,
        CONTAINS_AI_GENERATED_ASSETS,
        EXECUTION_KIND,
        GENERATED_FOR_REQUEST,
        TEMPLATE_SHOTS,
        TEMPLATE_STORY_TITLE,
        VISUAL_SOURCE,
        VISUAL_WARNING,
        ComicVideoEngine,
    )
    from hybrid_comic_engine import (
        HYBRID_EXECUTION_KIND,
        HYBRID_GENERATED_FOR_REQUEST,
        HYBRID_MODEL_EXECUTION,
        HYBRID_SHOTS,
        HYBRID_VISUAL_SOURCE,
        HYBRID_VISUAL_WARNING,
        LOCAL_MODEL_EXECUTION,
        HybridWanComicVideoEngine,
    )
    from model_catalog import (
        LOCAL_COMIC_IMAGE_MODEL_ID,
        LOCAL_COMIC_SCRIPT_MODEL_ID,
        LOCAL_COMIC_VIDEO_MODEL_ID,
        LOCAL_COMIC_VOICE_MODEL_ID,
        WAN_VIDEO_MODEL_ID,
        available_model_ids,
        get_model_catalog,
    )
    from wan_video_provider import WanProviderConfig, WanVideoProvider
    from video_engine import MAX_PROMPT_CHARS, MIN_PROMPT_CHARS, FfmpegVideoEngine


MAX_REQUEST_BYTES = 64 * 1024
MAX_ACTIVE_JOBS = 2
MAX_RETAINED_JOBS = 20
ALLOWED_JOB_FIELDS = frozenset(
    {"prompt", "textModelId", "videoModelId", "aspectRatio", "durationSeconds"}
)
ALLOWED_COMIC_JOB_FIELDS = frozenset(
    {
        "story",
        "textModelId",
        "imageModelId",
        "videoModelId",
        "voiceModelId",
        "aspectRatio",
        "shotCount",
        "shotDurationSeconds",
    }
)
JOB_PATH = re.compile(
    r"^/v1/video-jobs/([0-9a-fA-F-]{36})(?:/(preview\.gif|video\.mp4))?$"
)
COMIC_JOB_PATH = re.compile(
    r"^/v1/comic-jobs/([0-9a-fA-F-]{36})"
    r"(?:/(preview\.gif|video\.mp4|manifest\.json|script\.json))?$"
)
COMIC_SHOT_PATH = re.compile(
    r"^/v1/comic-jobs/([0-9a-fA-F-]{36})/shots/"
    r"(E01-SH0[1-3])/(first-frame\.png|last-frame\.png|video\.mp4)$"
)


class RequestValidationError(ValueError):
    pass


class ServiceCapacityError(RuntimeError):
    pass


class ComicPipelineUnavailableError(RuntimeError):
    pass


class RangeNotSatisfiable(ValueError):
    pass


@dataclass
class JobRecord:
    id: str
    prompt: str
    text_model_id: str
    video_model_id: str
    aspect_ratio: str
    duration_seconds: int
    status: str = "queued"
    progress: int = 0
    stage: str = "等待执行"
    error: str | None = None
    output: dict[str, str] | None = None
    lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def snapshot(self) -> dict[str, Any]:
        with self.lock:
            return {
                "id": self.id,
                "status": self.status,
                "progress": self.progress,
                "stage": self.stage,
                "error": self.error,
                "output": deepcopy(self.output),
            }

    def update(self, **changes: Any) -> None:
        with self.lock:
            for key, value in changes.items():
                setattr(self, key, value)


@dataclass
class ComicJobRecord:
    id: str
    story: str
    text_model_id: str
    image_model_id: str
    video_model_id: str
    voice_model_id: str
    aspect_ratio: str
    shot_count: int
    shot_duration_seconds: int
    provider_kind: str
    status: str = "queued"
    progress: int = 0
    stage: str = "等待执行"
    stage_code: str = "queued"
    error: str | None = None
    output: dict[str, Any] | None = None
    shots: list[dict[str, Any]] = field(default_factory=list)
    lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def __post_init__(self) -> None:
        source_shots = HYBRID_SHOTS if self.provider_kind == "hybrid" else TEMPLATE_SHOTS
        self.shots = []
        for shot in source_shots:
            item: dict[str, Any] = {
                "id": shot["id"],
                "index": shot["index"],
                "title": shot["title"],
                "status": "queued",
                "progress": 0,
                "stageCode": "queued",
            }
            if self.provider_kind == "hybrid":
                base = f"/v1/comic-jobs/{self.id}/shots/{shot['id']}"
                item.update(
                    firstFrameUrl=f"{base}/first-frame.png",
                    lastFrameUrl=f"{base}/last-frame.png",
                    motionPrompt=shot["motionPrompt"],
                    videoTask={"status": "queued", "progress": 0},
                )
            self.shots.append(item)

    @property
    def truth(self) -> dict[str, Any]:
        if self.provider_kind == "hybrid":
            return {
                "executionKind": HYBRID_EXECUTION_KIND,
                "visualSource": HYBRID_VISUAL_SOURCE,
                "generatedForRequest": HYBRID_GENERATED_FOR_REQUEST,
                "containsAiGeneratedAssets": CONTAINS_AI_GENERATED_ASSETS,
                "assetProvenance": ASSET_PROVENANCE,
                "templateStoryTitle": TEMPLATE_STORY_TITLE,
                "visualWarning": HYBRID_VISUAL_WARNING,
                "modelExecution": deepcopy(HYBRID_MODEL_EXECUTION),
            }
        return {
            "executionKind": EXECUTION_KIND,
            "visualSource": VISUAL_SOURCE,
            "generatedForRequest": GENERATED_FOR_REQUEST,
            "containsAiGeneratedAssets": CONTAINS_AI_GENERATED_ASSETS,
            "assetProvenance": ASSET_PROVENANCE,
            "templateStoryTitle": TEMPLATE_STORY_TITLE,
            "visualWarning": VISUAL_WARNING,
            "modelExecution": deepcopy(LOCAL_MODEL_EXECUTION),
        }

    def snapshot(self) -> dict[str, Any]:
        with self.lock:
            return {
                "id": self.id,
                "status": self.status,
                "progress": self.progress,
                "stage": self.stage,
                "stageCode": self.stage_code,
                "error": self.error,
                **self.truth,
                "shots": deepcopy(self.shots),
                "output": deepcopy(self.output),
            }

    def update(self, **changes: Any) -> None:
        with self.lock:
            for key, value in changes.items():
                setattr(self, key, value)

    def update_shot(
        self,
        shot_id: str,
        *,
        progress: int,
        status: str,
        stage_code: str,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        with self.lock:
            for shot in self.shots:
                if shot["id"] == shot_id:
                    shot.update(
                        progress=max(0, min(100, progress)),
                        status=status,
                        stageCode=stage_code,
                    )
                    if metadata:
                        shot.update(deepcopy(metadata))
                    return


class VideoLabService:
    def __init__(
        self,
        output_root: Path,
        engine: FfmpegVideoEngine | None = None,
        comic_engine: ComicVideoEngine | None = None,
        hybrid_comic_engine: HybridWanComicVideoEngine | None = None,
        wan_provider: WanVideoProvider | None = None,
        dashscope_key_file: Path | None = None,
    ):
        self.output_root = output_root.resolve()
        self.output_root.mkdir(parents=True, exist_ok=True)
        self.engine = engine or FfmpegVideoEngine()
        self.comic_engine = comic_engine or ComicVideoEngine()
        self.wan_provider = wan_provider or WanVideoProvider(
            WanProviderConfig.from_server_environment(key_file=dashscope_key_file)
        )
        self.hybrid_comic_engine = hybrid_comic_engine or HybridWanComicVideoEngine(
            self.wan_provider
        )
        self._jobs: dict[str, JobRecord] = {}
        self._comic_jobs: dict[str, ComicJobRecord] = {}
        self._jobs_lock = threading.Lock()
        self._executor = ThreadPoolExecutor(
            max_workers=1,
            thread_name_prefix="video-lab-ffmpeg",
        )

    def health(self) -> tuple[int, dict[str, Any]]:
        available = self.engine.available
        return (
            HTTPStatus.OK if available else HTTPStatus.SERVICE_UNAVAILABLE,
            {
                "status": "ok" if available else "degraded",
                "ffmpegAvailable": available,
                "huihuiTtsAvailable": self.comic_engine.tts_available,
                "comicPipelineAvailable": self.comic_engine.available,
                "wanVideoProviderAvailable": self.wan_provider.available,
                "hybridComicPipelineAvailable": self.hybrid_comic_engine.available,
            },
        )

    def catalog(self) -> dict[str, list[dict[str, Any]]]:
        return get_model_catalog(
            huihui_available=self.comic_engine.tts_available,
            local_comic_available=self.comic_engine.available,
            wan_video_available=self.wan_provider.available,
            hybrid_comic_available=self.hybrid_comic_engine.available,
        )

    def create_job(self, payload: Any) -> dict[str, Any]:
        request = validate_job_request(payload)
        with self._jobs_lock:
            self._check_capacity_locked()
            job_id = str(uuid4())
            record = JobRecord(id=job_id, **request)
            self._jobs[job_id] = record
        try:
            self._executor.submit(self._run_job, record)
        except RuntimeError as error:
            with self._jobs_lock:
                self._jobs.pop(job_id, None)
            raise ServiceCapacityError("本地视频服务正在关闭") from error
        return record.snapshot()

    def create_comic_job(self, payload: Any) -> dict[str, Any]:
        request = validate_comic_job_request(payload)
        selected_engine = (
            self.hybrid_comic_engine
            if request["provider_kind"] == "hybrid"
            else self.comic_engine
        )
        if not selected_engine.available:
            if request["provider_kind"] == "hybrid":
                raise ComicPipelineUnavailableError(
                    "Wan 混合漫剧需要显式启用的 Provider、服务端凭据、FFmpeg、"
                    "三组固定首尾帧和 Microsoft Huihui Desktop 中文语音"
                )
            raise ComicPipelineUnavailableError(
                "本地漫剧模板需要 FFmpeg、三张固定项目资产和 "
                "Microsoft Huihui Desktop 中文语音"
            )
        with self._jobs_lock:
            self._check_capacity_locked()
            job_id = str(uuid4())
            record = ComicJobRecord(id=job_id, **request)
            self._comic_jobs[job_id] = record
        try:
            self._executor.submit(self._run_comic_job, record)
        except RuntimeError as error:
            with self._jobs_lock:
                self._comic_jobs.pop(job_id, None)
            raise ServiceCapacityError("本地视频服务正在关闭") from error
        return record.snapshot()

    def get_job(self, job_id: str) -> dict[str, Any] | None:
        record = self._get_record(job_id)
        return record.snapshot() if record else None

    def get_comic_job(self, job_id: str) -> dict[str, Any] | None:
        record = self._get_comic_record(job_id)
        return record.snapshot() if record else None

    def get_output_path(self, job_id: str, file_name: str) -> Path | None:
        if file_name not in {"preview.gif", "video.mp4"}:
            return None
        record = self._get_record(job_id)
        if not record or record.snapshot()["status"] != "succeeded":
            return None
        path = (self.output_root / job_id / file_name).resolve()
        expected_parent = (self.output_root / job_id).resolve()
        if path.parent != expected_parent or not path.is_file():
            return None
        return path

    def get_comic_output_path(self, job_id: str, file_name: str) -> Path | None:
        if file_name not in {
            "preview.gif",
            "video.mp4",
            "manifest.json",
            "script.json",
        }:
            return None
        record = self._get_comic_record(job_id)
        if not record or record.snapshot()["status"] != "succeeded":
            return None
        path = (self.output_root / job_id / file_name).resolve()
        expected_parent = (self.output_root / job_id).resolve()
        if path.parent != expected_parent or not path.is_file():
            return None
        return path

    def get_comic_shot_output_path(
        self,
        job_id: str,
        shot_id: str,
        file_name: str,
    ) -> Path | None:
        record = self._get_comic_record(job_id)
        if not record or record.provider_kind != "hybrid":
            return None
        snapshot = record.snapshot()
        try:
            shot = next(
                shot for shot in snapshot["shots"] if shot["id"] == shot_id
            )
        except StopIteration:
            return None
        shot_index = int(shot["index"])
        if file_name == "video.mp4" and (
            shot.get("videoTask", {}).get("status") != "succeeded"
        ):
            return None
        mapped_name = {
            "first-frame.png": f"shot-{shot_index:02d}-first.png",
            "last-frame.png": f"shot-{shot_index:02d}-last.png",
            "video.mp4": f"shot-{shot_index:02d}.mp4",
        }.get(file_name)
        if mapped_name is None:
            return None
        path = (self.output_root / job_id / mapped_name).resolve()
        expected_parent = (self.output_root / job_id).resolve()
        if path.parent != expected_parent or not path.is_file():
            return None
        return path

    def shutdown(self, wait: bool = True) -> None:
        self._executor.shutdown(wait=wait, cancel_futures=False)

    def _get_record(self, job_id: str) -> JobRecord | None:
        try:
            UUID(job_id)
        except ValueError:
            return None
        with self._jobs_lock:
            return self._jobs.get(job_id)

    def _get_comic_record(self, job_id: str) -> ComicJobRecord | None:
        try:
            UUID(job_id)
        except ValueError:
            return None
        with self._jobs_lock:
            return self._comic_jobs.get(job_id)

    def _check_capacity_locked(self) -> None:
        retained_jobs = len(self._jobs) + len(self._comic_jobs)
        if retained_jobs >= MAX_RETAINED_JOBS:
            raise ServiceCapacityError(
                f"本进程最多保留 {MAX_RETAINED_JOBS} 个任务，请重启本地服务后重试"
            )
        records: list[JobRecord | ComicJobRecord] = [
            *self._jobs.values(),
            *self._comic_jobs.values(),
        ]
        active_jobs = sum(
            record.snapshot()["status"] in {"queued", "running"}
            for record in records
        )
        if active_jobs >= MAX_ACTIVE_JOBS:
            raise ServiceCapacityError(
                f"本地服务最多同时接收 {MAX_ACTIVE_JOBS} 个等待或执行中的任务"
            )

    def _run_job(self, record: JobRecord) -> None:
        record.update(status="running", progress=4, stage="启动 FFmpeg")

        def report(progress: int, stage: str) -> None:
            record.update(progress=max(0, min(99, progress)), stage=stage)

        try:
            self.engine.generate(
                record.prompt,
                record.duration_seconds,
                self.output_root / record.id,
                report,
            )
            record.update(
                status="succeeded",
                progress=100,
                stage="生成完成",
                error=None,
                output={
                    "previewUrl": f"/v1/video-jobs/{record.id}/preview.gif",
                    "videoUrl": f"/v1/video-jobs/{record.id}/video.mp4",
                },
            )
        except Exception as error:  # Keep the worker alive for subsequent jobs.
            message = str(error).strip() or "视频生成失败"
            record.update(
                status="failed",
                progress=100,
                stage="生成失败",
                error=message[:500],
                output=None,
            )

    def _run_comic_job(self, record: ComicJobRecord) -> None:
        record.update(
            status="running",
            progress=2,
            stage="准备固定三镜头模板",
            stage_code="preparing",
        )

        def report(
            progress: int,
            stage: str,
            stage_code: str,
            shot_id: str | None,
            shot_progress: int | None,
            shot_status: str | None,
            shot_metadata: dict[str, Any] | None = None,
        ) -> None:
            record.update(
                progress=max(0, min(99, progress)),
                stage=stage,
                stage_code=stage_code,
            )
            if shot_id and shot_progress is not None and shot_status:
                record.update_shot(
                    shot_id,
                    progress=shot_progress,
                    status=shot_status,
                    stage_code=stage_code,
                    metadata=shot_metadata,
                )

        try:
            selected_engine = (
                self.hybrid_comic_engine
                if record.provider_kind == "hybrid"
                else self.comic_engine
            )
            selected_engine.generate(
                job_id=record.id,
                requested_story=record.story,
                shot_duration_seconds=record.shot_duration_seconds,
                output_directory=self.output_root / record.id,
                progress=report,
            )
            base = f"/v1/comic-jobs/{record.id}"
            output = {
                "previewUrl": f"{base}/preview.gif",
                "videoUrl": f"{base}/video.mp4",
                "manifestUrl": f"{base}/manifest.json",
                "scriptUrl": f"{base}/script.json",
                **record.truth,
            }
            if record.provider_kind == "hybrid":
                output.update(
                    compositionType="shot_videos_concat",
                    sourceClipCount=3,
                )
            record.update(
                status="succeeded",
                progress=100,
                stage="漫剧生成完成",
                stage_code="succeeded",
                error=None,
                output=output,
            )
        except Exception as error:  # Keep the worker alive for later jobs.
            message = str(error).strip() or "漫剧生成失败"
            snapshot = record.snapshot()
            for shot in snapshot["shots"]:
                if shot["status"] == "running":
                    record.update_shot(
                        shot["id"],
                        progress=100,
                        status="failed",
                        stage_code="failed",
                    )
            record.update(
                status="failed",
                progress=100,
                stage="漫剧生成失败",
                stage_code="failed",
                error=message[:500],
                output=None,
            )


def validate_job_request(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise RequestValidationError("请求体必须是 JSON 对象")
    unknown = set(payload) - ALLOWED_JOB_FIELDS
    if unknown:
        raise RequestValidationError(f"包含未知字段: {', '.join(sorted(unknown))}")
    missing = ALLOWED_JOB_FIELDS - set(payload)
    if missing:
        raise RequestValidationError(f"缺少字段: {', '.join(sorted(missing))}")

    prompt = payload["prompt"]
    if not isinstance(prompt, str):
        raise RequestValidationError("prompt 必须是字符串")
    prompt = prompt.strip()
    if not MIN_PROMPT_CHARS <= len(prompt) <= MAX_PROMPT_CHARS:
        raise RequestValidationError(
            f"prompt 长度必须为 {MIN_PROMPT_CHARS} 到 {MAX_PROMPT_CHARS} 个字符"
        )

    text_model_id = payload["textModelId"]
    if not isinstance(text_model_id, str):
        raise RequestValidationError("textModelId 必须是字符串")
    if text_model_id not in available_model_ids("textModels"):
        raise RequestValidationError("文本模型不可用或尚未在服务端配置")

    video_model_id = payload["videoModelId"]
    if not isinstance(video_model_id, str):
        raise RequestValidationError("videoModelId 必须是字符串")
    if video_model_id not in available_model_ids("videoModels"):
        raise RequestValidationError("视频模型不可用或尚未在服务端配置")

    aspect_ratio = payload["aspectRatio"]
    if aspect_ratio != "9:16":
        raise RequestValidationError("当前最小版本仅支持 9:16")

    duration_seconds = payload["durationSeconds"]
    if isinstance(duration_seconds, bool) or not isinstance(duration_seconds, int):
        raise RequestValidationError("durationSeconds 必须是整数")
    if not 3 <= duration_seconds <= 8:
        raise RequestValidationError("durationSeconds 必须为 3 到 8 秒")

    return {
        "prompt": prompt,
        "text_model_id": text_model_id,
        "video_model_id": video_model_id,
        "aspect_ratio": aspect_ratio,
        "duration_seconds": duration_seconds,
    }


def validate_comic_job_request(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise RequestValidationError("请求体必须是 JSON 对象")
    unknown = set(payload) - ALLOWED_COMIC_JOB_FIELDS
    if unknown:
        raise RequestValidationError(f"包含未知字段: {', '.join(sorted(unknown))}")
    missing = ALLOWED_COMIC_JOB_FIELDS - set(payload)
    if missing:
        raise RequestValidationError(f"缺少字段: {', '.join(sorted(missing))}")

    story = payload["story"]
    if not isinstance(story, str):
        raise RequestValidationError("story 必须是字符串")
    story = story.strip()
    if not 4 <= len(story) <= 500:
        raise RequestValidationError("story 长度必须为 4 到 500 个字符")

    local_models = {
        "textModelId": LOCAL_COMIC_SCRIPT_MODEL_ID,
        "imageModelId": LOCAL_COMIC_IMAGE_MODEL_ID,
        "videoModelId": LOCAL_COMIC_VIDEO_MODEL_ID,
        "voiceModelId": LOCAL_COMIC_VOICE_MODEL_ID,
    }
    hybrid_models = {
        **local_models,
        "videoModelId": WAN_VIDEO_MODEL_ID,
    }
    submitted_models: dict[str, str] = {}
    for field_name in local_models:
        value = payload[field_name]
        if not isinstance(value, str):
            raise RequestValidationError(f"{field_name} 必须是字符串")
        submitted_models[field_name] = value
    if submitted_models == local_models:
        provider_kind = "local"
    elif submitted_models == hybrid_models:
        provider_kind = "hybrid"
    else:
        raise RequestValidationError(
            "当前服务只允许完整本地模板，或固定首尾帧 + Wan 视频的混合模型组合"
        )

    if payload["aspectRatio"] != "9:16":
        raise RequestValidationError("当前漫剧管线仅支持 9:16")

    shot_count = payload["shotCount"]
    if isinstance(shot_count, bool) or not isinstance(shot_count, int):
        raise RequestValidationError("shotCount 必须是整数")
    if shot_count != 3:
        raise RequestValidationError("当前漫剧管线固定为 3 个镜头")

    shot_duration_seconds = payload["shotDurationSeconds"]
    if isinstance(shot_duration_seconds, bool) or not isinstance(
        shot_duration_seconds, int
    ):
        raise RequestValidationError("shotDurationSeconds 必须是整数")
    if shot_duration_seconds != 3:
        raise RequestValidationError("当前漫剧管线每镜头时长固定为 3 秒")

    return {
        "story": story,
        "text_model_id": submitted_models["textModelId"],
        "image_model_id": submitted_models["imageModelId"],
        "video_model_id": submitted_models["videoModelId"],
        "voice_model_id": submitted_models["voiceModelId"],
        "aspect_ratio": "9:16",
        "shot_count": 3,
        "shot_duration_seconds": 3,
        "provider_kind": provider_kind,
    }


class VideoLabHttpServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], service: VideoLabService):
        self.service = service
        super().__init__(address, VideoLabRequestHandler)

    def server_close(self) -> None:
        super().server_close()
        self.service.shutdown(wait=True)


class VideoLabRequestHandler(BaseHTTPRequestHandler):
    server: VideoLabHttpServer
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802 - stdlib callback name
        path = unquote(urlsplit(self.path).path)
        if path == "/health":
            status, body = self.server.service.health()
            self._send_json(status, body)
            return
        if path == "/v1/model-catalog":
            self._send_json(HTTPStatus.OK, self.server.service.catalog())
            return

        comic_shot_match = COMIC_SHOT_PATH.fullmatch(path)
        if comic_shot_match:
            job_id, shot_id, file_name = comic_shot_match.groups()
            output_path = self.server.service.get_comic_shot_output_path(
                job_id,
                shot_id,
                file_name,
            )
            if not output_path:
                self._send_json(
                    HTTPStatus.NOT_FOUND,
                    {"message": "分镜输出文件尚不可用"},
                )
                return
            self._send_file(
                output_path,
                allow_range=output_path.suffix in {".mp4", ".png"},
            )
            return

        comic_match = COMIC_JOB_PATH.fullmatch(path)
        if comic_match:
            job_id, file_name = comic_match.groups()
            if file_name:
                output_path = self.server.service.get_comic_output_path(
                    job_id, file_name
                )
                if not output_path:
                    self._send_json(
                        HTTPStatus.NOT_FOUND,
                        {"message": "输出文件尚不可用"},
                    )
                    return
                self._send_file(
                    output_path,
                    allow_range=output_path.suffix in {".mp4", ".gif"},
                )
                return
            job = self.server.service.get_comic_job(job_id)
            if job is None:
                self._send_json(HTTPStatus.NOT_FOUND, {"message": "任务不存在"})
                return
            self._send_json(HTTPStatus.OK, job)
            return

        match = JOB_PATH.fullmatch(path)
        if not match:
            self._send_json(HTTPStatus.NOT_FOUND, {"message": "接口不存在"})
            return
        job_id, file_name = match.groups()
        if file_name:
            output_path = self.server.service.get_output_path(job_id, file_name)
            if not output_path:
                self._send_json(HTTPStatus.NOT_FOUND, {"message": "输出文件尚不可用"})
                return
            self._send_file(output_path)
            return
        job = self.server.service.get_job(job_id)
        if job is None:
            self._send_json(HTTPStatus.NOT_FOUND, {"message": "任务不存在"})
            return
        self._send_json(HTTPStatus.OK, job)

    def do_POST(self) -> None:  # noqa: N802 - stdlib callback name
        path = unquote(urlsplit(self.path).path)
        if path not in {"/v1/video-jobs", "/v1/comic-jobs"}:
            self._send_json(HTTPStatus.NOT_FOUND, {"message": "接口不存在"})
            return
        try:
            payload = self._read_json()
            job = (
                self.server.service.create_comic_job(payload)
                if path == "/v1/comic-jobs"
                else self.server.service.create_job(payload)
            )
        except RequestValidationError as error:
            self.close_connection = True
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
            return
        except ComicPipelineUnavailableError as error:
            self._send_json(HTTPStatus.SERVICE_UNAVAILABLE, {"message": str(error)})
            return
        except ServiceCapacityError as error:
            self._send_json(HTTPStatus.TOO_MANY_REQUESTS, {"message": str(error)})
            return
        self._send_json(HTTPStatus.ACCEPTED, job)

    def _read_json(self) -> Any:
        raw_length = self.headers.get("Content-Length")
        if raw_length is None:
            raise RequestValidationError("缺少 Content-Length")
        try:
            length = int(raw_length)
        except ValueError as error:
            raise RequestValidationError("Content-Length 无效") from error
        if length <= 0 or length > MAX_REQUEST_BYTES:
            raise RequestValidationError("请求体大小必须在 1 到 65536 字节之间")
        content_type = self.headers.get_content_type()
        if content_type != "application/json":
            raise RequestValidationError("Content-Type 必须是 application/json")
        body = self.rfile.read(length)
        try:
            return json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise RequestValidationError("请求体不是有效 UTF-8 JSON") from error

    def _send_json(self, status: int, body: Any) -> None:
        encoded = json.dumps(
            body,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        self.send_response(status)
        self._common_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def _send_file(self, path: Path, *, allow_range: bool = True) -> None:
        size = path.stat().st_size
        range_header = self.headers.get("Range") if allow_range else None
        try:
            start, end = parse_byte_range(range_header, size)
        except RangeNotSatisfiable:
            self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
            self._common_headers()
            self.send_header("Content-Range", f"bytes */{size}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        partial = allow_range and range_header is not None
        length = end - start + 1
        self.send_response(HTTPStatus.PARTIAL_CONTENT if partial else HTTPStatus.OK)
        self._common_headers()
        content_type = {
            ".mp4": "video/mp4",
            ".gif": "image/gif",
            ".png": "image/png",
            ".json": "application/json; charset=utf-8",
        }.get(path.suffix, "application/octet-stream")
        self.send_header("Content-Type", content_type)
        if allow_range:
            self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        self.send_header(
            "Cache-Control",
            "private, max-age=3600" if allow_range else "no-store",
        )
        if partial:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()

        try:
            with path.open("rb") as source:
                source.seek(start)
                remaining = length
                while remaining:
                    chunk = source.read(min(64 * 1024, remaining))
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    remaining -= len(chunk)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _common_headers(self) -> None:
        self.send_header("X-Content-Type-Options", "nosniff")

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"{self.address_string()} - {fmt % args}")


def parse_byte_range(header: str | None, size: int) -> tuple[int, int]:
    if header is None:
        return 0, size - 1
    if size <= 0 or not header.startswith("bytes=") or "," in header:
        raise RangeNotSatisfiable
    value = header[6:].strip()
    if "-" not in value:
        raise RangeNotSatisfiable
    raw_start, raw_end = value.split("-", 1)
    try:
        if raw_start:
            start = int(raw_start)
            end = int(raw_end) if raw_end else size - 1
            if start < 0 or start >= size or end < start:
                raise RangeNotSatisfiable
            end = min(end, size - 1)
        else:
            suffix_length = int(raw_end)
            if suffix_length <= 0:
                raise RangeNotSatisfiable
            start = max(0, size - suffix_length)
            end = size - 1
    except ValueError as error:
        raise RangeNotSatisfiable from error
    return start, end


def create_server(
    host: str = "127.0.0.1",
    port: int = 8787,
    output_root: Path | None = None,
    engine: FfmpegVideoEngine | None = None,
    comic_engine: ComicVideoEngine | None = None,
    hybrid_comic_engine: HybridWanComicVideoEngine | None = None,
    wan_provider: WanVideoProvider | None = None,
    dashscope_key_file: Path | None = None,
) -> VideoLabHttpServer:
    root = output_root or Path(__file__).resolve().parent / "storage"
    return VideoLabHttpServer(
        (host, port),
        VideoLabService(
            root,
            engine=engine,
            comic_engine=comic_engine,
            hybrid_comic_engine=hybrid_comic_engine,
            wan_provider=wan_provider,
            dashscope_key_file=dashscope_key_file,
        ),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Xingmu local video-lab server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--dashscope-key-file",
        type=Path,
        help="explicit server-side key file; no default key file is searched",
    )
    args = parser.parse_args()
    server = create_server(
        args.host,
        args.port,
        args.output,
        dashscope_key_file=args.dashscope_key_file,
    )
    host, port = server.server_address[:2]
    print(f"Video Lab listening on http://{host}:{port}")
    print("Local development service only; it has no authentication.")
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        # serve_forever has already unwound here. Calling shutdown() from this
        # same thread is unnecessary; server_close also stops the worker pool.
        server.server_close()


if __name__ == "__main__":
    main()
