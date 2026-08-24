"""Trusted-backend adapter for Wan first/last-frame video generation.

The adapter is deliberately dependency-free and opt-in.  It never looks for a
default ``key.txt`` file: credentials may only come from the server process
environment or an explicit key-file path supplied by the server operator.
"""

from __future__ import annotations

from dataclasses import dataclass
import base64
import json
import mimetypes
import os
from pathlib import Path
import re
import ssl
import struct
import time
from typing import Any, Callable, Mapping
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlsplit
from urllib.request import (
    HTTPRedirectHandler,
    Request,
    build_opener,
    HTTPSHandler,
)


WAN_VIDEO_MODEL_ID = "wan2.7-i2v-2026-04-25"
WAN_SUBMIT_PATH = "/api/v1/services/aigc/video-generation/video-synthesis"
WAN_TASK_PATH = "/api/v1/tasks/{task_id}"
DEFAULT_PUBLIC_BASE_URL = "https://dashscope.aliyuncs.com"
MAX_JSON_RESPONSE_BYTES = 1024 * 1024
DEFAULT_MAX_VIDEO_BYTES = 128 * 1024 * 1024
WAN_NEGATIVE_PROMPT = "人物变形，服装变化，错误手指，画面闪烁，文字水印，镜头跳切"
_TASK_ID = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")
_WORKSPACE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]{0,62}$")
_IMAGE_MIME_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
}


class WanProviderError(RuntimeError):
    """Safe provider error whose message never contains credentials/bodies."""


class WanProviderConfigurationError(WanProviderError):
    pass


class WanProviderTimeoutError(WanProviderError):
    pass


class WanProviderHttpError(WanProviderError):
    pass


@dataclass(frozen=True)
class WanProviderConfig:
    enabled: bool
    api_key: str | None
    base_url: str
    request_timeout_seconds: float = 30.0
    poll_timeout_seconds: float = 600.0
    poll_interval_seconds: float = 15.0
    max_video_bytes: int = DEFAULT_MAX_VIDEO_BYTES
    allowed_download_host_suffixes: tuple[str, ...] = (".aliyuncs.com",)
    allow_insecure_test_urls: bool = False

    @property
    def available(self) -> bool:
        return self.enabled and bool(self.api_key)

    @classmethod
    def from_server_environment(
        cls,
        *,
        key_file: Path | None = None,
        environment: Mapping[str, str] | None = None,
    ) -> "WanProviderConfig":
        env = os.environ if environment is None else environment
        enabled = env.get("XINGMU_WAN_ADAPTER_ENABLED", "").strip().lower() in {
            "1",
            "true",
            "yes",
        }
        api_key = env.get("DASHSCOPE_API_KEY", "").strip() or None
        if api_key is None and key_file is not None:
            api_key = _read_explicit_key_file(key_file)

        workspace_id = env.get("BAILIAN_WORKSPACE_ID", "").strip()
        if workspace_id:
            if not _WORKSPACE_ID.fullmatch(workspace_id):
                raise WanProviderConfigurationError("BAILIAN_WORKSPACE_ID 格式无效")
            base_url = (
                f"https://{workspace_id}.cn-beijing.maas.aliyuncs.com"
            )
        else:
            base_url = DEFAULT_PUBLIC_BASE_URL

        return cls(enabled=enabled, api_key=api_key, base_url=base_url)


@dataclass(frozen=True)
class WanShotResult:
    remote_task_id: str
    provider_video_url: str
    local_video_path: Path


WanStatusCallback = Callable[[str, str, int], None]


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: ANN001
        return None


class WanVideoProvider:
    """Submit, poll and promptly download one Wan-generated shot."""

    def __init__(
        self,
        config: WanProviderConfig,
        *,
        sleep: Callable[[float], None] = time.sleep,
        monotonic: Callable[[], float] = time.monotonic,
    ) -> None:
        self.config = config
        self._sleep = sleep
        self._monotonic = monotonic
        self._opener = build_opener(
            _NoRedirect(),
            HTTPSHandler(context=ssl.create_default_context()),
        )
        self._validate_api_base()

    @property
    def available(self) -> bool:
        return self.config.available

    def generate_shot(
        self,
        *,
        prompt: str,
        first_frame: Path,
        last_frame: Path,
        duration_seconds: int,
        output_path: Path,
        status: WanStatusCallback | None = None,
    ) -> WanShotResult:
        self._require_available()
        if (
            not isinstance(prompt, str)
            or not prompt.strip()
            or len(prompt.strip()) > 5000
        ):
            raise WanProviderConfigurationError(
                "Wan 镜头 motion prompt 长度必须为 1 到 5000 个字符"
            )
        if not 2 <= duration_seconds <= 15:
            raise WanProviderConfigurationError("Wan 镜头时长必须为 2 到 15 秒")

        first_frame_url = _image_data_url(first_frame)
        last_frame_url = _image_data_url(last_frame)
        first_size = _png_dimensions(first_frame)
        last_size = _png_dimensions(last_frame)
        if first_size and last_size and first_size != last_size:
            raise WanProviderConfigurationError("Wan 首帧和尾帧必须使用相同尺寸")

        body = {
            "model": WAN_VIDEO_MODEL_ID,
            "input": {
                "prompt": prompt.strip(),
                "negative_prompt": WAN_NEGATIVE_PROMPT,
                "media": [
                    {
                        "type": "first_frame",
                        "url": first_frame_url,
                    },
                    {
                        "type": "last_frame",
                        "url": last_frame_url,
                    },
                ],
            },
            "parameters": {
                "resolution": "720P",
                "duration": duration_seconds,
                "prompt_extend": False,
                "watermark": False,
            },
        }
        submitted = self._request_json(
            "POST",
            self.config.base_url + WAN_SUBMIT_PATH,
            body=body,
            extra_headers={"X-DashScope-Async": "enable"},
        )
        task_id = _required_task_id(submitted)
        if status:
            status(task_id, "PENDING", 10)

        deadline = self._monotonic() + self.config.poll_timeout_seconds
        poll_url = self.config.base_url + WAN_TASK_PATH.format(task_id=task_id)
        last_status = "PENDING"
        while True:
            if self._monotonic() >= deadline:
                raise WanProviderTimeoutError(
                    f"Wan 任务 {task_id} 在限定时间内未完成"
                )
            if self.config.poll_interval_seconds > 0:
                self._sleep(self.config.poll_interval_seconds)
            polled = self._request_json("GET", poll_url)
            task_status = _task_status(polled)
            if task_status in {"PENDING", "RUNNING"}:
                if status and task_status != last_status:
                    status(task_id, task_status, 50 if task_status == "RUNNING" else 20)
                last_status = task_status
                continue
            if task_status != "SUCCEEDED":
                raise WanProviderError(
                    f"Wan 任务 {task_id} 结束于 {task_status}"
                )
            video_url = _required_video_url(polled)
            self._validate_download_url(video_url)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            self._download_video(video_url, output_path)
            if status:
                status(task_id, "SUCCEEDED", 100)
            return WanShotResult(task_id, video_url, output_path.resolve())

    def _request_json(
        self,
        method: str,
        url: str,
        *,
        body: dict[str, Any] | None = None,
        extra_headers: Mapping[str, str] | None = None,
    ) -> dict[str, Any]:
        encoded = None
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {self.config.api_key}",
        }
        if body is not None:
            encoded = json.dumps(body, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if extra_headers:
            headers.update(extra_headers)
        request = Request(url, method=method, data=encoded, headers=headers)
        try:
            with self._opener.open(
                request,
                timeout=self.config.request_timeout_seconds,
            ) as response:
                raw = _read_limited(response, MAX_JSON_RESPONSE_BYTES)
        except HTTPError as error:
            error.close()
            raise WanProviderHttpError(
                f"Wan HTTP 请求失败，状态码 {error.code}"
            ) from None
        except (TimeoutError, URLError, OSError) as error:
            if isinstance(error, URLError) and not isinstance(
                error.reason, TimeoutError
            ):
                raise WanProviderHttpError("Wan HTTP 请求无法完成") from None
            raise WanProviderTimeoutError("Wan HTTP 请求超时") from None
        try:
            payload = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            raise WanProviderHttpError("Wan 返回了无效 JSON") from None
        if not isinstance(payload, dict):
            raise WanProviderHttpError("Wan JSON 顶层必须是对象")
        return payload

    def _download_video(self, initial_url: str, output_path: Path) -> None:
        current_url = initial_url
        temporary = output_path.with_suffix(output_path.suffix + ".part")
        temporary.unlink(missing_ok=True)
        try:
            for _ in range(4):
                self._validate_download_url(current_url)
                request = Request(
                    current_url,
                    method="GET",
                    headers={"Accept": "video/mp4,application/octet-stream"},
                )
                try:
                    response = self._opener.open(
                        request,
                        timeout=self.config.request_timeout_seconds,
                    )
                except HTTPError as error:
                    if error.code in {301, 302, 303, 307, 308}:
                        location = error.headers.get("Location")
                        error.close()
                        if not location:
                            raise WanProviderHttpError(
                                "Wan 视频重定向缺少 Location"
                            ) from None
                        current_url = urljoin(current_url, location)
                        continue
                    error.close()
                    raise WanProviderHttpError(
                        f"Wan 视频下载失败，状态码 {error.code}"
                    ) from None
                except (TimeoutError, URLError, OSError) as error:
                    if isinstance(error, URLError) and not isinstance(
                        error.reason, TimeoutError
                    ):
                        raise WanProviderHttpError("Wan 视频下载无法完成") from None
                    raise WanProviderTimeoutError("Wan 视频下载超时") from None

                with response:
                    content_length = response.headers.get("Content-Length")
                    if content_length is not None:
                        try:
                            declared_size = int(content_length)
                        except ValueError:
                            raise WanProviderHttpError(
                                "Wan 视频 Content-Length 无效"
                            ) from None
                        if not 0 < declared_size <= self.config.max_video_bytes:
                            raise WanProviderHttpError("Wan 视频大小超过安全限制")
                    total = 0
                    with temporary.open("wb") as target:
                        while True:
                            chunk = response.read(64 * 1024)
                            if not chunk:
                                break
                            total += len(chunk)
                            if total > self.config.max_video_bytes:
                                raise WanProviderHttpError(
                                    "Wan 视频大小超过安全限制"
                                )
                            target.write(chunk)
                if total < 12:
                    raise WanProviderHttpError("Wan 返回的视频文件过小")
                with temporary.open("rb") as source:
                    header = source.read(12)
                if header[4:8] != b"ftyp":
                    raise WanProviderHttpError("Wan 返回的文件不是 MP4")
                temporary.replace(output_path)
                return
            raise WanProviderHttpError("Wan 视频重定向次数过多")
        finally:
            temporary.unlink(missing_ok=True)

    def _validate_api_base(self) -> None:
        parsed = urlsplit(self.config.base_url)
        if parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise WanProviderConfigurationError("Wan API base URL 无效")
        if parsed.path not in {"", "/"}:
            raise WanProviderConfigurationError("Wan API base URL 不得包含路径")
        host = (parsed.hostname or "").lower()
        official = host == "dashscope.aliyuncs.com" or host.endswith(
            ".cn-beijing.maas.aliyuncs.com"
        )
        test_url = self.config.allow_insecure_test_urls and host in {
            "127.0.0.1",
            "localhost",
        }
        if not ((parsed.scheme == "https" and official) or test_url):
            raise WanProviderConfigurationError("Wan API base URL 不在允许列表")

    def _validate_download_url(self, url: str) -> None:
        parsed = urlsplit(url)
        host = (parsed.hostname or "").lower()
        if parsed.username or parsed.password or not host:
            raise WanProviderHttpError("Wan 视频 URL 无效")
        if parsed.scheme != "https":
            if not (
                self.config.allow_insecure_test_urls
                and parsed.scheme == "http"
                and host in {"127.0.0.1", "localhost"}
            ):
                raise WanProviderHttpError("Wan 视频 URL 必须使用 HTTPS")
        base_host = (urlsplit(self.config.base_url).hostname or "").lower()
        allowed = host == base_host or any(
            host.endswith(suffix.lower())
            for suffix in self.config.allowed_download_host_suffixes
        )
        if not allowed and not (
            self.config.allow_insecure_test_urls
            and host in {"127.0.0.1", "localhost"}
        ):
            raise WanProviderHttpError("Wan 视频 URL 主机不在允许列表")

    def _require_available(self) -> None:
        if not self.config.enabled:
            raise WanProviderConfigurationError("Wan Provider Adapter 未启用")
        if not self.config.api_key:
            raise WanProviderConfigurationError("服务端未配置 DASHSCOPE_API_KEY")


def _read_explicit_key_file(path: Path) -> str | None:
    resolved = path.resolve()
    try:
        if not resolved.is_file() or resolved.stat().st_size > 8192:
            raise WanProviderConfigurationError("显式 DashScope key file 无效")
        raw = resolved.read_text(encoding="utf-8").strip()
    except OSError:
        raise WanProviderConfigurationError("无法读取显式 DashScope key file") from None
    match = re.search(r"^(?:DASHSCOPE_API_KEY\s*=\s*)?([^\s#]+)", raw)
    if not match:
        raise WanProviderConfigurationError("显式 DashScope key file 中没有有效 Key")
    return match.group(1).strip("'\"") or None


def _image_data_url(path: Path) -> str:
    resolved = path.resolve()
    mime_type = _IMAGE_MIME_TYPES.get(resolved.suffix.lower())
    if not mime_type:
        guessed, _ = mimetypes.guess_type(resolved.name)
        mime_type = guessed if guessed in _IMAGE_MIME_TYPES.values() else None
    if not mime_type or not resolved.is_file():
        raise WanProviderConfigurationError("Wan 首尾帧必须是有效的本地图像")
    try:
        size = resolved.stat().st_size
        if not 0 < size <= 20 * 1024 * 1024:
            raise WanProviderConfigurationError("Wan 首尾帧大小超出限制")
        raw = resolved.read_bytes()
        if mime_type == "image/png":
            _validate_png_frame(raw)
        encoded = base64.b64encode(raw).decode("ascii")
    except OSError:
        raise WanProviderConfigurationError("无法读取 Wan 首尾帧") from None
    return f"data:{mime_type};base64,{encoded}"


def _validate_png_frame(raw: bytes) -> None:
    if len(raw) < 33 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
        raise WanProviderConfigurationError("Wan PNG 首尾帧文件头无效")
    width, height = struct.unpack(">II", raw[16:24])
    color_type = raw[25]
    if not (240 <= width <= 8000 and 240 <= height <= 8000):
        raise WanProviderConfigurationError("Wan PNG 首尾帧尺寸超出 240 到 8000")
    ratio = width / height
    if not 1 / 8 <= ratio <= 8:
        raise WanProviderConfigurationError("Wan PNG 首尾帧宽高比超出 1:8 到 8:1")
    has_transparency_chunk = False
    offset = 8
    while offset + 12 <= len(raw):
        chunk_length = struct.unpack(">I", raw[offset : offset + 4])[0]
        chunk_type = raw[offset + 4 : offset + 8]
        offset += 12 + chunk_length
        if offset > len(raw):
            raise WanProviderConfigurationError("Wan PNG 首尾帧结构无效")
        if chunk_type == b"tRNS":
            has_transparency_chunk = True
        if chunk_type == b"IEND":
            break
    if color_type in {4, 6} or has_transparency_chunk:
        raise WanProviderConfigurationError("Wan PNG 首尾帧不得包含透明通道")


def _png_dimensions(path: Path) -> tuple[int, int] | None:
    if path.suffix.lower() != ".png":
        return None
    try:
        raw = path.read_bytes()[:24]
    except OSError:
        raise WanProviderConfigurationError("无法读取 Wan 首尾帧") from None
    if len(raw) < 24 or raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise WanProviderConfigurationError("Wan PNG 首尾帧文件头无效")
    return struct.unpack(">II", raw[16:24])


def _read_limited(response: Any, limit: int) -> bytes:
    content_length = response.headers.get("Content-Length")
    if content_length is not None:
        try:
            if int(content_length) > limit:
                raise WanProviderHttpError("Wan JSON 响应过大")
        except ValueError:
            raise WanProviderHttpError("Wan JSON Content-Length 无效") from None
    raw = response.read(limit + 1)
    if len(raw) > limit:
        raise WanProviderHttpError("Wan JSON 响应过大")
    return raw


def _required_task_id(payload: Mapping[str, Any]) -> str:
    output = payload.get("output")
    task_id = output.get("task_id") if isinstance(output, dict) else None
    if not isinstance(task_id, str) or not _TASK_ID.fullmatch(task_id):
        raise WanProviderHttpError("Wan submit 响应缺少有效 task_id")
    return task_id


def _task_status(payload: Mapping[str, Any]) -> str:
    output = payload.get("output")
    status = output.get("task_status") if isinstance(output, dict) else None
    if status not in {
        "PENDING",
        "RUNNING",
        "SUCCEEDED",
        "FAILED",
        "CANCELED",
        "UNKNOWN",
    }:
        raise WanProviderHttpError("Wan poll 响应缺少有效 task_status")
    return status


def _required_video_url(payload: Mapping[str, Any]) -> str:
    output = payload.get("output")
    url = output.get("video_url") if isinstance(output, dict) else None
    if not isinstance(url, str) or len(url) > 8192:
        raise WanProviderHttpError("Wan 成功响应缺少有效 video_url")
    return url
