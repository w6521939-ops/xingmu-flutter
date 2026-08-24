from __future__ import annotations

from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import threading
import time
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen
import zlib

from services.basic_video_server.hybrid_comic_engine import (
    HYBRID_SHOTS,
    HybridWanComicVideoEngine,
)
from services.basic_video_server.model_catalog import (
    LOCAL_COMIC_IMAGE_MODEL_ID,
    LOCAL_COMIC_SCRIPT_MODEL_ID,
    LOCAL_COMIC_VOICE_MODEL_ID,
    WAN_VIDEO_MODEL_ID,
)
from services.basic_video_server.server import (
    RequestValidationError,
    VideoLabService,
    VideoLabHttpServer,
    validate_comic_job_request,
)
from services.basic_video_server.wan_video_provider import (
    WAN_SUBMIT_PATH,
    WanProviderConfig,
    WanProviderError,
    WanProviderHttpError,
    WanProviderTimeoutError,
    WanVideoProvider,
)


HYBRID_REQUEST = {
    "story": "月背停电第七天，她送来最后一封信。",
    "textModelId": LOCAL_COMIC_SCRIPT_MODEL_ID,
    "imageModelId": LOCAL_COMIC_IMAGE_MODEL_ID,
    "videoModelId": WAN_VIDEO_MODEL_ID,
    "voiceModelId": LOCAL_COMIC_VOICE_MODEL_ID,
    "aspectRatio": "9:16",
    "shotCount": 3,
    "shotDurationSeconds": 3,
}


class _FakeWanState:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.submissions: list[dict[str, object]] = []
        self.task_statuses: dict[str, deque[str]] = {}
        self.next_sequences: deque[list[str]] = deque()
        self.submit_status = 200
        self.submit_body: dict[str, object] | None = None
        self.result_url_override: str | None = None
        self.video_payload = b"\x00\x00\x00\x18ftypisom" + b"v" * 1024
        self.declared_video_size: int | None = None


class _FakeWanHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server: "_FakeWanServer"

    def do_POST(self) -> None:  # noqa: N802
        if self.path != WAN_SUBMIT_PATH:
            self._json(404, {"message": "missing"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        with self.server.state.lock:
            self.server.state.submissions.append(
                {
                    "body": payload,
                    "authorization": self.headers.get("Authorization"),
                    "async": self.headers.get("X-DashScope-Async"),
                }
            )
            if self.server.state.submit_status != 200:
                self._json(
                    self.server.state.submit_status,
                    self.server.state.submit_body or {"message": "provider failed"},
                )
                return
            task_id = f"task-{len(self.server.state.submissions)}"
            sequence = (
                self.server.state.next_sequences.popleft()
                if self.server.state.next_sequences
                else ["PENDING", "RUNNING", "SUCCEEDED"]
            )
            self.server.state.task_statuses[task_id] = deque(sequence)
        self._json(
            200,
            {"output": {"task_id": task_id, "task_status": "PENDING"}},
        )

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/api/v1/tasks/"):
            task_id = self.path.rsplit("/", 1)[-1]
            with self.server.state.lock:
                statuses = self.server.state.task_statuses.get(task_id)
                if not statuses:
                    self._json(404, {"message": "unknown task"})
                    return
                status = statuses[0]
                if len(statuses) > 1:
                    statuses.popleft()
                result_url = self.server.state.result_url_override
            output: dict[str, object] = {
                "task_id": task_id,
                "task_status": status,
            }
            if status == "SUCCEEDED":
                output["video_url"] = result_url or (
                    f"http://127.0.0.1:{self.server.server_port}/results/{task_id}.mp4"
                )
            self._json(200, {"output": output})
            return
        if self.path.startswith("/results/") and self.path.endswith(".mp4"):
            payload = self.server.state.video_payload
            declared = self.server.state.declared_video_size
            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header(
                "Content-Length",
                str(len(payload) if declared is None else declared),
            )
            self.end_headers()
            self.wfile.write(payload)
            return
        self._json(404, {"message": "missing"})

    def _json(self, status: int, payload: dict[str, object]) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, fmt: str, *args: object) -> None:
        pass


class _FakeWanServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self) -> None:
        self.state = _FakeWanState()
        super().__init__(("127.0.0.1", 0), _FakeWanHandler)


class _WanFixture:
    def setUp(self) -> None:
        self.fake_server = _FakeWanServer()
        self.fake_thread = threading.Thread(
            target=self.fake_server.serve_forever,
            daemon=True,
        )
        self.fake_thread.start()
        self.base_url = f"http://127.0.0.1:{self.fake_server.server_port}"

    def tearDown(self) -> None:
        self.fake_server.shutdown()
        self.fake_server.server_close()
        self.fake_thread.join(timeout=5)

    def provider(self, **changes: object) -> WanVideoProvider:
        values: dict[str, object] = {
            "enabled": True,
            "api_key": "test-secret-key",
            "base_url": self.base_url,
            "request_timeout_seconds": 2.0,
            "poll_timeout_seconds": 2.0,
            "poll_interval_seconds": 0.0,
            "max_video_bytes": 2 * 1024 * 1024,
            "allowed_download_host_suffixes": (),
            "allow_insecure_test_urls": True,
        }
        values.update(changes)
        return WanVideoProvider(WanProviderConfig(**values))


class WanProviderHttpTests(_WanFixture, unittest.TestCase):
    def test_submit_poll_download_uses_official_shape_and_never_sends_key_in_body(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "first.png"
            last = root / "last.png"
            first.write_bytes(_rgb_png())
            last.write_bytes(_rgb_png(red=48, green=80, blue=112))
            statuses: list[tuple[str, str, int]] = []
            result = self.provider().generate_shot(
                prompt="人物自然抬头，镜头缓慢推进，不要切镜",
                first_frame=first,
                last_frame=last,
                duration_seconds=3,
                output_path=root / "shot.mp4",
                status=lambda *value: statuses.append(value),
            )

            self.assertEqual(result.remote_task_id, "task-1")
            self.assertTrue(result.local_video_path.is_file())
            self.assertEqual(result.local_video_path.read_bytes()[4:8], b"ftyp")
            submission = self.fake_server.state.submissions[0]
            body = submission["body"]
            self.assertEqual(submission["authorization"], "Bearer test-secret-key")
            self.assertEqual(submission["async"], "enable")
            self.assertNotIn("test-secret-key", json.dumps(body))
            self.assertEqual(body["model"], WAN_VIDEO_MODEL_ID)
            self.assertEqual(
                [item["type"] for item in body["input"]["media"]],
                ["first_frame", "last_frame"],
            )
            self.assertTrue(
                all(
                    item["url"].startswith("data:image/png;base64,")
                    for item in body["input"]["media"]
                )
            )
            self.assertEqual(body["parameters"]["resolution"], "720P")
            self.assertEqual(body["parameters"]["duration"], 3)
            self.assertFalse(body["parameters"]["prompt_extend"])
            self.assertFalse(body["parameters"]["watermark"])
            self.assertIn("人物变形", body["input"]["negative_prompt"])
            self.assertEqual(
                [value[1] for value in statuses],
                ["PENDING", "RUNNING", "SUCCEEDED"],
            )

    def test_failed_remote_task_is_terminal(self) -> None:
        self.fake_server.state.next_sequences.append(["FAILED"])
        with tempfile.TemporaryDirectory() as directory:
            first, last = _write_frames(Path(directory))
            with self.assertRaisesRegex(WanProviderError, "结束于 FAILED"):
                self.provider().generate_shot(
                    prompt="缓慢推进",
                    first_frame=first,
                    last_frame=last,
                    duration_seconds=3,
                    output_path=Path(directory) / "shot.mp4",
                )

    def test_poll_timeout_stops_without_downloading(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first, last = _write_frames(Path(directory))
            with self.assertRaises(WanProviderTimeoutError):
                self.provider(poll_timeout_seconds=0.0).generate_shot(
                    prompt="缓慢推进",
                    first_frame=first,
                    last_frame=last,
                    duration_seconds=3,
                    output_path=Path(directory) / "shot.mp4",
                )
            self.assertEqual(len(self.fake_server.state.submissions), 1)

    def test_http_error_does_not_echo_provider_body_or_key(self) -> None:
        self.fake_server.state.submit_status = 500
        self.fake_server.state.submit_body = {
            "message": "test-secret-key must never escape"
        }
        with tempfile.TemporaryDirectory() as directory:
            first, last = _write_frames(Path(directory))
            with self.assertRaises(WanProviderHttpError) as caught:
                self.provider().generate_shot(
                    prompt="缓慢推进",
                    first_frame=first,
                    last_frame=last,
                    duration_seconds=3,
                    output_path=Path(directory) / "shot.mp4",
                )
            self.assertNotIn("test-secret-key", str(caught.exception))

    def test_result_url_allowlist_blocks_untrusted_host(self) -> None:
        self.fake_server.state.next_sequences.append(["SUCCEEDED"])
        self.fake_server.state.result_url_override = "https://evil.example/video.mp4"
        with tempfile.TemporaryDirectory() as directory:
            first, last = _write_frames(Path(directory))
            with self.assertRaisesRegex(WanProviderHttpError, "主机不在允许列表"):
                self.provider().generate_shot(
                    prompt="缓慢推进",
                    first_frame=first,
                    last_frame=last,
                    duration_seconds=3,
                    output_path=Path(directory) / "shot.mp4",
                )

    def test_download_rejects_declared_size_over_limit(self) -> None:
        self.fake_server.state.next_sequences.append(["SUCCEEDED"])
        self.fake_server.state.declared_video_size = 4097
        with tempfile.TemporaryDirectory() as directory:
            first, last = _write_frames(Path(directory))
            with self.assertRaisesRegex(WanProviderHttpError, "大小超过安全限制"):
                self.provider(max_video_bytes=4096).generate_shot(
                    prompt="缓慢推进",
                    first_frame=first,
                    last_frame=last,
                    duration_seconds=3,
                    output_path=Path(directory) / "shot.mp4",
                )

    def test_submit_rejects_mismatched_first_and_last_frame_sizes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "first.png"
            last = root / "last.png"
            first.write_bytes(_rgb_png(width=240, height=240))
            last.write_bytes(_rgb_png(width=320, height=240))
            with self.assertRaisesRegex(WanProviderError, "相同尺寸"):
                self.provider().generate_shot(
                    prompt="缓慢推进",
                    first_frame=first,
                    last_frame=last,
                    duration_seconds=3,
                    output_path=root / "shot.mp4",
                )
            self.assertEqual(self.fake_server.state.submissions, [])


class WanConfigurationTests(unittest.TestCase):
    def test_key_is_only_environment_or_explicit_file_and_adapter_is_opt_in(self) -> None:
        without_key = WanProviderConfig.from_server_environment(environment={})
        self.assertFalse(without_key.available)
        self.assertIsNone(without_key.api_key)

        with tempfile.TemporaryDirectory() as directory:
            key_file = Path(directory) / "explicit.key"
            key_file.write_text("DASHSCOPE_API_KEY=explicit-secret\n", encoding="utf-8")
            file_config = WanProviderConfig.from_server_environment(
                key_file=key_file,
                environment={"XINGMU_WAN_ADAPTER_ENABLED": "true"},
            )
            self.assertTrue(file_config.available)
            self.assertEqual(file_config.api_key, "explicit-secret")

            env_config = WanProviderConfig.from_server_environment(
                key_file=key_file,
                environment={
                    "XINGMU_WAN_ADAPTER_ENABLED": "true",
                    "DASHSCOPE_API_KEY": "environment-secret",
                },
            )
            self.assertEqual(env_config.api_key, "environment-secret")

    def test_validation_accepts_hybrid_but_rejects_unimplemented_full_cloud(self) -> None:
        validated = validate_comic_job_request(dict(HYBRID_REQUEST))
        self.assertEqual(validated["provider_kind"], "hybrid")
        with self.assertRaises(RequestValidationError):
            validate_comic_job_request(
                {
                    **HYBRID_REQUEST,
                    "textModelId": "qwen3.6-plus",
                    "imageModelId": "wan2.7-image-pro",
                    "voiceModelId": "cosyvoice-v3.5-plus",
                }
            )


class _FakeTts:
    available = True

    def synthesize(self, text: str, output_path: Path) -> None:
        output_path.write_bytes(b"RIFF" + b"voice" * 20)


class _TestHybridEngine(HybridWanComicVideoEngine):
    def __init__(self, provider: WanVideoProvider, asset_root: Path) -> None:
        super().__init__(
            provider,
            ffmpeg="fake-ffmpeg",
            ffprobe="fake-ffprobe",
            tts=_FakeTts(),
            asset_root=asset_root,
        )
        self.provider_inputs: list[Path] = []
        self.composed_inputs: list[Path] = []

    def _probe_duration(self, media_path: Path) -> float:
        return 1.0

    def _normalize_generated_shot(
        self,
        *,
        shot,
        remote_path,
        voice_path,
        output_path,
        duration_seconds,
        voice_tempo,
    ) -> None:
        self.provider_inputs.append(remote_path)
        self.assert_provider_clip(remote_path)
        shutil.copyfile(remote_path, output_path)

    @staticmethod
    def assert_provider_clip(path: Path) -> None:
        if path.read_bytes()[4:8] != b"ftyp":
            raise AssertionError("normalization did not receive provider MP4")

    def _compose(self, clip_paths, output_directory, video_path) -> None:
        self.composed_inputs = list(clip_paths)
        with video_path.open("wb") as target:
            for clip in clip_paths:
                target.write(clip.read_bytes())

    def _generate_preview(self, output_directory: Path) -> None:
        (output_directory / "preview.gif").write_bytes(b"GIF89a" + b"g" * 32)

    def _verify(self, video_path, preview_path, shot_duration_seconds) -> None:
        if len(self.provider_inputs) != 3 or self.composed_inputs != [
            video_path.parent / f"shot-{index:02d}.mp4" for index in range(1, 4)
        ]:
            raise AssertionError("final composition did not use three provider clips")


class HybridThreeShotOrchestrationTests(_WanFixture, unittest.TestCase):
    def test_three_remote_clips_are_downloaded_normalized_and_used_for_final_composition(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            assets = root / "assets"
            assets.mkdir()
            for index, shot in enumerate(HYBRID_SHOTS, start=1):
                (assets / shot["firstFrameFile"]).write_bytes(_rgb_png(red=index))
                (assets / shot["lastFrameFile"]).write_bytes(_rgb_png(blue=index))

            provider = self.provider()
            hybrid_engine = _TestHybridEngine(provider, assets)
            service = VideoLabService(
                root / "outputs",
                hybrid_comic_engine=hybrid_engine,
                wan_provider=provider,
            )
            try:
                catalog = service.catalog()
                wan = next(
                    item
                    for item in catalog["videoModels"]
                    if item["id"] == WAN_VIDEO_MODEL_ID
                )
                hybrid_pipeline = next(
                    item
                    for item in catalog["comicPipelines"]
                    if item["id"] == "wan_fixed_frames_motion_comic"
                )
                self.assertEqual(wan["availability"], "available")
                self.assertEqual(hybrid_pipeline["availability"], "available")
                self.assertTrue(
                    all(
                        item["availability"] == "requires_configuration"
                        for group in ("textModels", "imageModels", "voiceModels")
                        for item in catalog[group]
                        if item["provider"] == "Alibaba Cloud Model Studio"
                    )
                )

                created = service.create_comic_job(dict(HYBRID_REQUEST))
                job_id = created["id"]
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    job = service.get_comic_job(job_id)
                    if job and job["status"] in {"succeeded", "failed"}:
                        break
                    time.sleep(0.01)
                self.assertEqual(job["status"], "succeeded", job.get("error"))
                self.assertEqual(job["executionKind"], "hybrid")
                self.assertEqual(job["visualSource"], "fixed_project_assets")
                self.assertTrue(job["generatedForRequest"])
                self.assertEqual(
                    job["modelExecution"],
                    {
                        "text": "local",
                        "image": "pre_generated",
                        "video": "cloud",
                        "voice": "local",
                    },
                )
                self.assertEqual(job["output"]["compositionType"], "shot_videos_concat")
                self.assertEqual(job["output"]["sourceClipCount"], 3)
                self.assertEqual(len(self.fake_server.state.submissions), 3)
                self.assertEqual(len(hybrid_engine.provider_inputs), 3)
                self.assertEqual(len(hybrid_engine.composed_inputs), 3)
                self.assertTrue(
                    all(
                        shot["videoTask"]["status"] == "succeeded"
                        and shot["videoTask"]["remoteTaskId"] == f"task-{index}"
                        and shot["videoTask"]["videoUrl"].endswith("/video.mp4")
                        and shot["firstFrameUrl"].endswith("/first-frame.png")
                        and shot["lastFrameUrl"].endswith("/last-frame.png")
                        and shot["motionPrompt"]
                        for index, shot in enumerate(job["shots"], start=1)
                    )
                )
                for index, shot in enumerate(job["shots"], start=1):
                    for file_name in ("first-frame.png", "last-frame.png", "video.mp4"):
                        path = service.get_comic_shot_output_path(
                            job_id,
                            shot["id"],
                            file_name,
                        )
                        self.assertIsNotNone(path)
                        self.assertTrue(path.is_file())

                manifest_path = service.get_comic_output_path(job_id, "manifest.json")
                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                self.assertEqual(manifest["compositionType"], "shot_videos_concat")
                self.assertEqual(manifest["sourceClipCount"], 3)
                self.assertNotIn("providerVideoUrl", json.dumps(manifest))

                http_server = VideoLabHttpServer(("127.0.0.1", 0), service)
                http_thread = threading.Thread(
                    target=http_server.serve_forever,
                    daemon=True,
                )
                http_thread.start()
                try:
                    base_url = f"http://127.0.0.1:{http_server.server_port}"
                    first_shot = job["shots"][0]
                    for field, content_type in (
                        ("firstFrameUrl", "image/png"),
                        ("lastFrameUrl", "image/png"),
                        ("videoUrl", "video/mp4"),
                    ):
                        url = (
                            first_shot["videoTask"][field]
                            if field == "videoUrl"
                            else first_shot[field]
                        )
                        request = Request(
                            base_url + url,
                            headers={"Range": "bytes=0-7"},
                        )
                        with urlopen(request, timeout=5) as response:
                            self.assertEqual(response.status, 206)
                            self.assertEqual(response.headers["Content-Type"], content_type)
                            self.assertEqual(len(response.read()), 8)
                    traversal = Request(
                        base_url
                        + f"/v1/comic-jobs/{job_id}/shots/E01-SH01/"
                        + "%2e%2e/video.mp4"
                    )
                    with self.assertRaises(HTTPError) as blocked:
                        urlopen(traversal, timeout=5)
                    self.assertEqual(blocked.exception.code, 404)
                    blocked.exception.close()
                finally:
                    http_server.shutdown()
                    http_server.server_close()
                    http_thread.join(timeout=5)
            finally:
                service.shutdown()


class HybridRealMediaIntegrationTests(_WanFixture, unittest.TestCase):
    def test_fake_http_provider_clips_are_used_by_real_ffmpeg_composition(self) -> None:
        repository_root = Path(__file__).resolve().parents[3]
        asset_root = repository_root / "assets" / "showcase" / "motion_comic"
        provider = self.provider(max_video_bytes=8 * 1024 * 1024)
        engine = HybridWanComicVideoEngine(provider, asset_root=asset_root)
        if not engine.available:
            self.skipTest("需要 FFmpeg、ffprobe、Huihui 与六张首尾帧")

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = root / "provider-fixture.mp4"
            completed = subprocess.run(
                [
                    engine.ffmpeg,
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-y",
                    "-f",
                    "lavfi",
                    "-i",
                    "testsrc2=size=180x320:rate=24:duration=3",
                    "-an",
                    "-c:v",
                    "libx264",
                    "-pix_fmt",
                    "yuv420p",
                    str(fixture),
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=60,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stdout)
            self.fake_server.state.video_payload = fixture.read_bytes()

            result = engine.generate(
                job_id="00000000-0000-4000-8000-000000000001",
                requested_story=HYBRID_REQUEST["story"],
                shot_duration_seconds=3,
                output_directory=root / "result",
                progress=lambda *args: None,
            )
            self.assertEqual(len(self.fake_server.state.submissions), 3)
            self.assertTrue(result.video_path.is_file())
            probe = json.loads(engine.probe_json(result.video_path))
            streams = {item["codec_type"]: item for item in probe["streams"]}
            self.assertEqual(streams["video"]["codec_name"], "h264")
            self.assertEqual(streams["video"]["width"], 720)
            self.assertEqual(streams["video"]["height"], 1280)
            self.assertEqual(streams["audio"]["codec_name"], "aac")
            self.assertGreaterEqual(float(probe["format"]["duration"]), 8.5)
            for index in range(1, 4):
                raw = root / "result" / f"shot-{index:02d}-provider.mp4"
                normalized = root / "result" / f"shot-{index:02d}.mp4"
                self.assertEqual(raw.read_bytes(), fixture.read_bytes())
                self.assertTrue(normalized.is_file())


def _write_frames(root: Path) -> tuple[Path, Path]:
    first = root / "first.png"
    last = root / "last.png"
    first.write_bytes(_rgb_png())
    last.write_bytes(_rgb_png(red=80, green=48, blue=16))
    return first, last


def _rgb_png(
    width: int = 240,
    height: int = 240,
    *,
    red: int = 0,
    green: int = 0,
    blue: int = 0,
) -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    row = bytes((0,)) + bytes((red, green, blue)) * width
    image = zlib.compress(row * height)
    return signature + _png_chunk(b"IHDR", ihdr) + _png_chunk(b"IDAT", image) + _png_chunk(b"IEND", b"")


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


if __name__ == "__main__":
    unittest.main()
