from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import threading
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from services.basic_video_server.comic_engine import ComicVideoEngine, HuihuiTtsEngine
from services.basic_video_server.model_catalog import (
    LOCAL_COMIC_IMAGE_MODEL_ID,
    LOCAL_COMIC_SCRIPT_MODEL_ID,
    LOCAL_COMIC_VIDEO_MODEL_ID,
    LOCAL_COMIC_VOICE_MODEL_ID,
    get_model_catalog,
)
from services.basic_video_server.server import (
    ComicPipelineUnavailableError,
    RequestValidationError,
    ServiceCapacityError,
    VideoLabService,
    create_server,
    parse_byte_range,
    validate_comic_job_request,
    validate_job_request,
)
from services.basic_video_server.video_engine import FfmpegVideoEngine, VideoEngineError


VALID_REQUEST = {
    "prompt": "霓虹雨夜里的月球快递员",
    "textModelId": "manual",
    "videoModelId": "local_ffmpeg_slides",
    "aspectRatio": "9:16",
    "durationSeconds": 3,
}

VALID_COMIC_REQUEST = {
    "story": "霓虹雨夜里的月球快递员",
    "textModelId": LOCAL_COMIC_SCRIPT_MODEL_ID,
    "imageModelId": LOCAL_COMIC_IMAGE_MODEL_ID,
    "videoModelId": LOCAL_COMIC_VIDEO_MODEL_ID,
    "voiceModelId": LOCAL_COMIC_VOICE_MODEL_ID,
    "aspectRatio": "9:16",
    "shotCount": 3,
    "shotDurationSeconds": 3,
}

SOURCE_ASSET_HASHES = {
    "assets/showcase/motion_comic/moon-courier-shot-01.png": (
        "D08A980877E12AF8808C564D186B4FCD9916BDDBC1CC86859EC0C65B43B65E6F"
    ),
    "assets/showcase/motion_comic/moon-courier-shot-02.png": (
        "5571043EC5F55DC1133DAF99A2AA7107F3C5F33A58BCE6783DBF2460BF6D85D1"
    ),
    "assets/showcase/motion_comic/moon-courier-shot-03.png": (
        "B2713FBED97FFE9FDCE91DC5E8627040EE1F5EB1AD9F7BBECD787381E678BCD1"
    ),
}


class CatalogAndValidationTests(unittest.TestCase):
    def test_catalog_has_available_local_models_and_config_only_paid_models(self) -> None:
        catalog = get_model_catalog()
        self.assertEqual(catalog["textModels"][0]["id"], "manual")
        self.assertEqual(catalog["videoModels"][0]["id"], "local_ffmpeg_slides")
        for group in catalog.values():
            for model in group:
                self.assertIn(model["pricingType"], {"free", "paid"})
                self.assertIn(
                    model["availability"],
                    {"available", "requires_configuration"},
                )
                if model["pricingType"] == "paid":
                    self.assertEqual(model["availability"], "requires_configuration")
                    self.assertTrue(model["pricingUrl"].startswith("https://"))
                    self.assertTrue(model["billingUrl"].startswith("https://"))

    def test_catalog_exposes_comic_models_and_dynamic_local_availability(self) -> None:
        unavailable = get_model_catalog()
        self.assertIn("imageModels", unavailable)
        self.assertIn("voiceModels", unavailable)
        self.assertIn("comicPipelines", unavailable)
        self.assertEqual(
            unavailable["voiceModels"][0]["availability"],
            "requires_configuration",
        )
        self.assertEqual(
            unavailable["comicPipelines"][0]["availability"],
            "requires_configuration",
        )

        available = get_model_catalog(
            huihui_available=True,
            local_comic_available=True,
        )
        self.assertEqual(
            available["imageModels"][0]["id"],
            LOCAL_COMIC_IMAGE_MODEL_ID,
        )
        self.assertEqual(
            available["voiceModels"][0]["id"],
            LOCAL_COMIC_VOICE_MODEL_ID,
        )
        self.assertEqual(available["voiceModels"][0]["availability"], "available")
        pipeline = available["comicPipelines"][0]
        self.assertEqual(pipeline["availability"], "available")
        self.assertEqual(pipeline["executionKind"], "template")
        self.assertEqual(pipeline["visualSource"], "fixed_project_assets")
        self.assertFalse(pipeline["generatedForRequest"])
        self.assertTrue(pipeline["containsAiGeneratedAssets"])
        self.assertEqual(
            pipeline["assetProvenance"],
            "openai_imagegen_project_assets",
        )
        self.assertNotIn("isAiGenerated", pipeline)
        self.assertEqual(pipeline["shotCount"], 3)
        self.assertEqual(pipeline["shotDurationSeconds"], 3)

        cloud_image = available["imageModels"][1]
        cloud_voice = available["voiceModels"][1]
        self.assertEqual(cloud_image["id"], "wan2.7-image-pro")
        self.assertEqual(cloud_voice["id"], "cosyvoice-v3.5-plus")
        self.assertEqual(cloud_image["availability"], "requires_configuration")
        self.assertEqual(cloud_voice["availability"], "requires_configuration")
        cloud_pipeline = available["comicPipelines"][1]
        self.assertEqual(cloud_pipeline["executionKind"], "cloud_ai")
        self.assertTrue(cloud_pipeline["generatedForRequest"])
        self.assertTrue(cloud_pipeline["containsAiGeneratedAssets"])
        self.assertEqual(
            cloud_pipeline["assetProvenance"],
            "model_generated_for_request",
        )

    def test_validation_accepts_only_minimum_local_contract(self) -> None:
        validated = validate_job_request(dict(VALID_REQUEST))
        self.assertEqual(validated["duration_seconds"], 3)

        invalid_variants = [
            {**VALID_REQUEST, "prompt": "短"},
            {**VALID_REQUEST, "prompt": "a" * 109},
            {**VALID_REQUEST, "aspectRatio": "16:9"},
            {**VALID_REQUEST, "durationSeconds": 9},
            {**VALID_REQUEST, "durationSeconds": True},
            {**VALID_REQUEST, "textModelId": "qwen3.6-plus"},
            {**VALID_REQUEST, "textModelId": LOCAL_COMIC_SCRIPT_MODEL_ID},
            {**VALID_REQUEST, "videoModelId": "wan2.7-i2v-2026-04-25"},
            {**VALID_REQUEST, "videoModelId": LOCAL_COMIC_VIDEO_MODEL_ID},
            {**VALID_REQUEST, "extra": "not-allowed"},
        ]
        for payload in invalid_variants:
            with self.subTest(payload=payload), self.assertRaises(RequestValidationError):
                validate_job_request(payload)

    def test_comic_validation_accepts_only_complete_local_template(self) -> None:
        validated = validate_comic_job_request(dict(VALID_COMIC_REQUEST))
        self.assertEqual(validated["shot_count"], 3)
        self.assertEqual(validated["shot_duration_seconds"], 3)
        self.assertEqual(validated["story"], VALID_COMIC_REQUEST["story"])

        invalid_variants = [
            {**VALID_COMIC_REQUEST, "story": "短"},
            {**VALID_COMIC_REQUEST, "story": "甲" * 501},
            {**VALID_COMIC_REQUEST, "textModelId": "qwen3.6-plus"},
            {**VALID_COMIC_REQUEST, "imageModelId": "wan2.7-image-pro"},
            {**VALID_COMIC_REQUEST, "videoModelId": "local_ffmpeg_slides"},
            {**VALID_COMIC_REQUEST, "voiceModelId": "cosyvoice-v3.5-plus"},
            {**VALID_COMIC_REQUEST, "aspectRatio": "16:9"},
            {**VALID_COMIC_REQUEST, "shotCount": 4},
            {**VALID_COMIC_REQUEST, "shotCount": True},
            {**VALID_COMIC_REQUEST, "shotDurationSeconds": 4},
            {**VALID_COMIC_REQUEST, "extra": "not-allowed"},
        ]
        for payload in invalid_variants:
            with self.subTest(payload=payload), self.assertRaises(
                RequestValidationError
            ):
                validate_comic_job_request(payload)

        missing = dict(VALID_COMIC_REQUEST)
        missing.pop("imageModelId")
        with self.assertRaises(RequestValidationError):
            validate_comic_job_request(missing)

    def test_caption_preserves_108_chars_and_rejects_109(self) -> None:
        prompt = "甲" * 108
        caption = FfmpegVideoEngine._caption(prompt)
        self.assertEqual(caption.replace("\n", ""), prompt)
        with self.assertRaises(VideoEngineError):
            FfmpegVideoEngine._caption("甲" * 109)

    def test_comic_subtitle_wrap_does_not_orphan_terminal_punctuation(self) -> None:
        wrapped = ComicVideoEngine._wrap_subtitle(
            "最后一单送达，月光重新亮起。"
        ).splitlines()
        self.assertEqual(len(wrapped), 2)
        self.assertGreater(len(wrapped[1]), 1)
        self.assertTrue(wrapped[1].endswith("。"))

    def test_comic_source_asset_hashes_match_third_party_notice(self) -> None:
        repository_root = Path(__file__).resolve().parents[3]
        for relative_path, expected_hash in SOURCE_ASSET_HASHES.items():
            with self.subTest(relative_path=relative_path):
                asset_path = repository_root / relative_path
                actual_hash = hashlib.sha256(asset_path.read_bytes()).hexdigest().upper()
                self.assertEqual(actual_hash, expected_hash)

    def test_huihui_uses_argument_array_and_text_file_not_user_shell_text(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script_path = root / "huihui_tts.ps1"
            script_path.write_text("# fixed test script\n", encoding="utf-8")
            output_path = root / "voice.wav"
            dangerous_text = '你好"; Remove-Item C:\\\\NeverRun -Recurse; #'
            captured: dict[str, object] = {}

            def fake_run(command, **kwargs):
                captured["command"] = command
                captured["kwargs"] = kwargs
                destination = Path(command[command.index("-OutputPath") + 1])
                destination.write_bytes(b"RIFF" + b"w" * 64)
                return SimpleNamespace(returncode=0, stdout="")

            tts = HuihuiTtsEngine(
                powershell="powershell.exe",
                script_path=script_path,
            )
            tts._available = True
            with patch(
                "services.basic_video_server.comic_engine.subprocess.run",
                side_effect=fake_run,
            ):
                tts.synthesize(dangerous_text, output_path)

            command = captured["command"]
            kwargs = captured["kwargs"]
            self.assertIsInstance(command, list)
            self.assertNotIn(dangerous_text, command)
            self.assertFalse(kwargs["shell"])
            self.assertFalse(output_path.with_suffix(".txt").exists())
            self.assertTrue(output_path.exists())

    def test_range_parser_supports_common_single_ranges(self) -> None:
        self.assertEqual(parse_byte_range(None, 100), (0, 99))
        self.assertEqual(parse_byte_range("bytes=0-9", 100), (0, 9))
        self.assertEqual(parse_byte_range("bytes=90-", 100), (90, 99))
        self.assertEqual(parse_byte_range("bytes=-10", 100), (90, 99))

    def test_server_close_without_serve_forever_returns(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            server = create_server(
                host="127.0.0.1",
                port=0,
                output_root=Path(directory),
            )
            started = time.monotonic()
            server.server_close()
            self.assertLess(time.monotonic() - started, 2)

    def test_service_retains_at_most_20_jobs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            service = VideoLabService(Path(directory), engine=_InstantEngine())
            try:
                for _ in range(20):
                    job = service.create_job(dict(VALID_REQUEST))
                    self._wait_for_terminal(service, job["id"])
                with self.assertRaises(ServiceCapacityError):
                    service.create_job(dict(VALID_REQUEST))
            finally:
                service.shutdown()

    @staticmethod
    def _wait_for_terminal(service: VideoLabService, job_id: str) -> None:
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            job = service.get_job(job_id)
            if job and job["status"] in {"succeeded", "failed"}:
                return
            time.sleep(0.01)
        raise AssertionError("fake job did not finish")


class ComicServiceTests(unittest.TestCase):
    def test_missing_huihui_marks_pipeline_unavailable_and_rejects_job(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            service = VideoLabService(
                Path(directory),
                engine=_InstantEngine(),
                comic_engine=_UnavailableComicEngine(),
            )
            try:
                catalog = service.catalog()
                self.assertEqual(
                    catalog["voiceModels"][0]["availability"],
                    "requires_configuration",
                )
                self.assertEqual(
                    catalog["comicPipelines"][0]["availability"],
                    "requires_configuration",
                )
                with self.assertRaises(ComicPipelineUnavailableError):
                    service.create_comic_job(dict(VALID_COMIC_REQUEST))
            finally:
                service.shutdown()

    def test_comic_job_has_three_shot_progress_and_template_truth_fields(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            service = VideoLabService(
                Path(directory),
                engine=_InstantEngine(),
                comic_engine=_InstantComicEngine(),
            )
            try:
                created = service.create_comic_job(dict(VALID_COMIC_REQUEST))
                job = self._wait_for_terminal(service, created["id"])
                self.assertEqual(job["status"], "succeeded")
                self.assertEqual(job["stageCode"], "succeeded")
                self.assertEqual(job["executionKind"], "template")
                self.assertEqual(job["visualSource"], "fixed_project_assets")
                self.assertFalse(job["generatedForRequest"])
                self.assertTrue(job["containsAiGeneratedAssets"])
                self.assertEqual(
                    job["assetProvenance"],
                    "openai_imagegen_project_assets",
                )
                self.assertNotIn("isAiGenerated", job)
                self.assertEqual(job["templateStoryTitle"], "月背最后一单")
                self.assertIn("本次请求未调用 AI", job["visualWarning"])
                self.assertIn("未按 story 重新绘制", job["visualWarning"])
                self.assertIn("ImageGen 项目素材", job["visualWarning"])
                self.assertEqual(len(job["shots"]), 3)
                self.assertTrue(
                    all(
                        shot["status"] == "succeeded" and shot["progress"] == 100
                        for shot in job["shots"]
                    )
                )
                output = job["output"]
                self.assertEqual(output["executionKind"], "template")
                self.assertEqual(output["visualSource"], job["visualSource"])
                self.assertFalse(output["generatedForRequest"])
                self.assertTrue(output["containsAiGeneratedAssets"])
                self.assertEqual(
                    output["assetProvenance"],
                    "openai_imagegen_project_assets",
                )
                self.assertNotIn("isAiGenerated", output)
                for key in ("previewUrl", "videoUrl", "manifestUrl", "scriptUrl"):
                    self.assertTrue(output[key].startswith("/v1/comic-jobs/"))
            finally:
                service.shutdown()

    def test_active_capacity_is_shared_between_video_and_comic_jobs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            engine = _BlockingEngine()
            service = VideoLabService(
                Path(directory),
                engine=engine,
                comic_engine=_InstantComicEngine(),
            )
            try:
                service.create_job(dict(VALID_REQUEST))
                self.assertTrue(engine.started.wait(timeout=3))
                service.create_comic_job(dict(VALID_COMIC_REQUEST))
                with self.assertRaises(ServiceCapacityError):
                    service.create_job(dict(VALID_REQUEST))
            finally:
                engine.release.set()
                service.shutdown()

    @staticmethod
    def _wait_for_terminal(service: VideoLabService, job_id: str) -> dict[str, object]:
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            job = service.get_comic_job(job_id)
            if job and job["status"] in {"succeeded", "failed"}:
                return job
            time.sleep(0.01)
        raise AssertionError("fake comic job did not finish")


class ActualHttpAndFfmpegTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp_directory = tempfile.TemporaryDirectory()
        cls.output_root = Path(cls.temp_directory.name)
        cls.engine = FfmpegVideoEngine()
        if not cls.engine.available:
            raise unittest.SkipTest("ffmpeg/ffprobe are not installed")
        cls.server = create_server(
            host="127.0.0.1",
            port=0,
            output_root=cls.output_root,
            engine=cls.engine,
        )
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)
        cls.temp_directory.cleanup()

    def test_http_job_produces_probeable_mp4_gif_and_range_response(self) -> None:
        status, health, _ = self._json("GET", "/health")
        self.assertEqual(status, 200)
        self.assertEqual(health["status"], "ok")

        _, _, health_headers = self._json("GET", "/health")
        self.assertNotIn("Access-Control-Allow-Origin", health_headers)
        options = Request(f"{self.base_url}/v1/video-jobs", method="OPTIONS")
        with self.assertRaises(HTTPError) as options_error:
            urlopen(options, timeout=10)
        self.assertEqual(options_error.exception.code, 501)
        self.assertIsNone(
            options_error.exception.headers.get("Access-Control-Allow-Origin")
        )

        status, catalog, _ = self._json("GET", "/v1/model-catalog")
        self.assertEqual(status, 200)
        self.assertEqual(catalog["videoModels"][0]["id"], "local_ffmpeg_slides")

        status, job, _ = self._json("POST", "/v1/video-jobs", VALID_REQUEST)
        self.assertEqual(status, 202)
        self.assertIn(job["status"], {"queued", "running"})
        job_id = job["id"]

        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            _, job, _ = self._json("GET", f"/v1/video-jobs/{job_id}")
            if job["status"] in {"succeeded", "failed"}:
                break
            time.sleep(0.15)
        self.assertEqual(job["status"], "succeeded", job.get("error"))
        self.assertEqual(job["progress"], 100)
        self.assertEqual(
            job["output"]["videoUrl"],
            f"/v1/video-jobs/{job_id}/video.mp4",
        )

        video_path = self.output_root / job_id / "video.mp4"
        preview_path = self.output_root / job_id / "preview.gif"
        probe = json.loads(self.engine.probe_json(video_path))
        streams = {stream["codec_type"]: stream for stream in probe["streams"]}
        self.assertEqual(streams["video"]["codec_name"], "h264")
        self.assertEqual(streams["video"]["width"], 720)
        self.assertEqual(streams["video"]["height"], 1280)
        self.assertEqual(streams["video"]["pix_fmt"], "yuv420p")
        self.assertEqual(streams["audio"]["codec_name"], "aac")
        self.assertGreaterEqual(float(probe["format"]["duration"]), 2.8)
        self.assertTrue(preview_path.read_bytes().startswith((b"GIF87a", b"GIF89a")))

        with urlopen(
            f"{self.base_url}/v1/video-jobs/{job_id}/preview.gif",
            timeout=10,
        ) as response:
            self.assertEqual(response.status, 200)
            self.assertTrue(response.read(6).startswith((b"GIF87a", b"GIF89a")))

        request = Request(
            f"{self.base_url}/v1/video-jobs/{job_id}/video.mp4",
            headers={"Range": "bytes=0-31"},
        )
        with urlopen(request, timeout=10) as response:
            body = response.read()
            self.assertEqual(response.status, 206)
            self.assertEqual(len(body), 32)
            self.assertTrue(response.headers["Content-Range"].startswith("bytes 0-31/"))
            self.assertIn(b"ftyp", body)

        invalid_request = Request(
            f"{self.base_url}/v1/video-jobs/{job_id}/video.mp4",
            headers={"Range": "bytes=999999999-"},
        )
        with self.assertRaises(HTTPError) as caught:
            urlopen(invalid_request, timeout=10)
        self.assertEqual(caught.exception.code, 416)

    def test_real_comic_job_produces_three_shot_huihui_mp4_and_manifest(self) -> None:
        comic_engine = self.server.service.comic_engine
        if not comic_engine.available:
            raise unittest.SkipTest(
                "FFmpeg, fixed assets, or Microsoft Huihui Desktop are unavailable"
            )

        status, created, _ = self._json(
            "POST",
            "/v1/comic-jobs",
            VALID_COMIC_REQUEST,
        )
        self.assertEqual(status, 202)
        self.assertEqual(created["executionKind"], "template")
        self.assertFalse(created["generatedForRequest"])
        self.assertTrue(created["containsAiGeneratedAssets"])
        self.assertEqual(
            created["assetProvenance"],
            "openai_imagegen_project_assets",
        )
        self.assertNotIn("isAiGenerated", created)
        self.assertEqual(len(created["shots"]), 3)
        job_id = created["id"]

        deadline = time.monotonic() + 240
        observed_stages: set[str] = set()
        while time.monotonic() < deadline:
            _, job, _ = self._json("GET", f"/v1/comic-jobs/{job_id}")
            observed_stages.add(job["stageCode"])
            if job["status"] in {"succeeded", "failed"}:
                break
            time.sleep(0.15)
        self.assertEqual(job["status"], "succeeded", job.get("error"))
        self.assertEqual(job["progress"], 100)
        self.assertEqual(job["stageCode"], "succeeded")
        self.assertEqual(len(job["shots"]), 3)
        self.assertTrue(all(shot["status"] == "succeeded" for shot in job["shots"]))
        self.assertTrue(
            observed_stages
            & {
                "synthesizing_voice",
                "rendering_shot",
                "composing",
                "generating_preview",
                "verifying",
            }
        )

        video_path = self.output_root / job_id / "video.mp4"
        preview_path = self.output_root / job_id / "preview.gif"
        probe = json.loads(comic_engine.probe_json(video_path))
        streams = {stream["codec_type"]: stream for stream in probe["streams"]}
        self.assertEqual(streams["video"]["codec_name"], "h264")
        self.assertEqual(streams["video"]["width"], 720)
        self.assertEqual(streams["video"]["height"], 1280)
        self.assertEqual(streams["video"]["pix_fmt"], "yuv420p")
        self.assertEqual(streams["audio"]["codec_name"], "aac")
        self.assertGreaterEqual(float(probe["format"]["duration"]), 8.5)
        self.assertTrue(preview_path.read_bytes().startswith((b"GIF87a", b"GIF89a")))

        status, manifest, headers = self._json(
            "GET",
            f"/v1/comic-jobs/{job_id}/manifest.json",
        )
        self.assertEqual(status, 200)
        self.assertNotIn("Accept-Ranges", headers)
        self.assertEqual(manifest["shotCount"], 3)
        self.assertEqual(manifest["executionKind"], "template")
        self.assertEqual(manifest["visualSource"], "fixed_project_assets")
        self.assertFalse(manifest["generatedForRequest"])
        self.assertTrue(manifest["containsAiGeneratedAssets"])
        self.assertEqual(
            manifest["assetProvenance"],
            "openai_imagegen_project_assets",
        )
        self.assertNotIn("isAiGenerated", manifest)
        self.assertEqual(manifest["requestedStory"], VALID_COMIC_REQUEST["story"])
        self.assertEqual(manifest["templateStoryTitle"], "月背最后一单")
        self.assertEqual(len(manifest["shots"]), 3)
        self.assertEqual(
            [shot["sourceAsset"] for shot in manifest["shots"]],
            list(SOURCE_ASSET_HASHES),
        )
        for shot in manifest["shots"]:
            source_hash = shot["sourceAssetSha256"]
            self.assertRegex(source_hash, r"^[0-9A-F]{64}$")
            self.assertEqual(
                source_hash,
                SOURCE_ASSET_HASHES[shot["sourceAsset"]],
            )
        self.assertTrue(
            all(
                1.0 <= shot["voiceTempo"] <= 2.0
                and shot["voiceSourceDurationSeconds"] > 0
                for shot in manifest["shots"]
            )
        )

        status, script, _ = self._json(
            "GET",
            f"/v1/comic-jobs/{job_id}/script.json",
        )
        self.assertEqual(status, 200)
        self.assertEqual(script["title"], "月背最后一单")
        self.assertEqual(script["requestedStory"], VALID_COMIC_REQUEST["story"])
        self.assertEqual(script["executionKind"], "template")
        self.assertEqual(script["visualSource"], "fixed_project_assets")
        self.assertFalse(script["generatedForRequest"])
        self.assertTrue(script["containsAiGeneratedAssets"])
        self.assertEqual(
            script["assetProvenance"],
            "openai_imagegen_project_assets",
        )
        self.assertNotIn("isAiGenerated", script)
        self.assertEqual(
            [shot["title"] for shot in script["shots"]],
            ["抵达月背", "打开来信", "望向地球"],
        )

        for file_name in ("video.mp4", "preview.gif"):
            request = Request(
                f"{self.base_url}/v1/comic-jobs/{job_id}/{file_name}",
                headers={"Range": "bytes=0-31"},
            )
            with urlopen(request, timeout=10) as response:
                self.assertEqual(response.status, 206)
                self.assertEqual(len(response.read()), 32)
                self.assertTrue(response.headers["Content-Range"].startswith("bytes 0-31/"))

    def _json(
        self,
        method: str,
        path: str,
        payload: dict[str, object] | None = None,
    ) -> tuple[int, object, dict[str, str]]:
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        headers = {"Accept": "application/json"}
        if data is not None:
            headers["Content-Type"] = "application/json"
        request = Request(
            f"{self.base_url}{path}",
            method=method,
            data=data,
            headers=headers,
        )
        with urlopen(request, timeout=125) as response:
            return (
                response.status,
                json.loads(response.read().decode("utf-8")),
                dict(response.headers),
            )


class ComicHttpContractTests(unittest.TestCase):
    def test_unavailable_huihui_returns_503_before_queuing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            server = create_server(
                host="127.0.0.1",
                port=0,
                output_root=Path(directory),
                engine=_InstantEngine(),
                comic_engine=_UnavailableComicEngine(),
            )
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            base_url = f"http://127.0.0.1:{server.server_port}"
            try:
                with urlopen(f"{base_url}/v1/model-catalog", timeout=10) as response:
                    catalog = json.loads(response.read().decode("utf-8"))
                self.assertEqual(
                    catalog["comicPipelines"][0]["availability"],
                    "requires_configuration",
                )
                request = Request(
                    f"{base_url}/v1/comic-jobs",
                    method="POST",
                    data=json.dumps(VALID_COMIC_REQUEST).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                )
                with self.assertRaises(HTTPError) as caught:
                    urlopen(request, timeout=10)
                self.assertEqual(caught.exception.code, 503)
                error = json.loads(caught.exception.read().decode("utf-8"))
                self.assertIn("Microsoft Huihui Desktop", error["message"])
                self.assertEqual(len(server.service._comic_jobs), 0)
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)

    def test_comic_routes_have_no_cors_and_range_only_for_media(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            server = create_server(
                host="127.0.0.1",
                port=0,
                output_root=Path(directory),
                engine=_InstantEngine(),
                comic_engine=_InstantComicEngine(),
            )
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            base_url = f"http://127.0.0.1:{server.server_port}"
            try:
                options = Request(f"{base_url}/v1/comic-jobs", method="OPTIONS")
                with self.assertRaises(HTTPError) as options_error:
                    urlopen(options, timeout=10)
                self.assertEqual(options_error.exception.code, 501)
                self.assertIsNone(
                    options_error.exception.headers.get("Access-Control-Allow-Origin")
                )

                request = Request(
                    f"{base_url}/v1/comic-jobs",
                    method="POST",
                    data=json.dumps(VALID_COMIC_REQUEST).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                )
                with urlopen(request, timeout=10) as response:
                    self.assertEqual(response.status, 202)
                    self.assertIsNone(
                        response.headers.get("Access-Control-Allow-Origin")
                    )
                    created = json.loads(response.read().decode("utf-8"))
                job_id = created["id"]

                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    with urlopen(
                        f"{base_url}/v1/comic-jobs/{job_id}",
                        timeout=10,
                    ) as response:
                        job = json.loads(response.read().decode("utf-8"))
                    if job["status"] in {"succeeded", "failed"}:
                        break
                    time.sleep(0.01)
                self.assertEqual(job["status"], "succeeded", job.get("error"))

                for file_name in ("video.mp4", "preview.gif"):
                    ranged = Request(
                        f"{base_url}/v1/comic-jobs/{job_id}/{file_name}",
                        headers={"Range": "bytes=0-15"},
                    )
                    with urlopen(ranged, timeout=10) as response:
                        self.assertEqual(response.status, 206)
                        self.assertEqual(len(response.read()), 16)
                        self.assertEqual(response.headers["Accept-Ranges"], "bytes")

                for file_name in ("manifest.json", "script.json"):
                    ranged_json = Request(
                        f"{base_url}/v1/comic-jobs/{job_id}/{file_name}",
                        headers={"Range": "bytes=0-15"},
                    )
                    with urlopen(ranged_json, timeout=10) as response:
                        self.assertEqual(response.status, 200)
                        self.assertIsNone(response.headers.get("Accept-Ranges"))
                        payload = json.loads(response.read().decode("utf-8"))
                    self.assertEqual(
                        payload.get("requestedStory"),
                        VALID_COMIC_REQUEST["story"],
                    )
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)


class ActiveCapacityHttpTests(unittest.TestCase):
    def test_third_active_job_gets_429_without_entering_the_queue(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            engine = _BlockingEngine()
            server = create_server(
                host="127.0.0.1",
                port=0,
                output_root=Path(directory),
                engine=engine,
            )
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            base_url = f"http://127.0.0.1:{server.server_port}"
            try:
                first = self._post_job(base_url)
                self.assertTrue(engine.started.wait(timeout=3))
                second = self._post_job(base_url)
                with self.assertRaises(HTTPError) as caught:
                    self._post_job(base_url)
                self.assertEqual(caught.exception.code, 429)
                error = json.loads(caught.exception.read().decode("utf-8"))
                self.assertIn("最多同时接收 2 个", error["message"])
                self.assertIsNotNone(server.service.get_job(first["id"]))
                self.assertIsNotNone(server.service.get_job(second["id"]))
            finally:
                engine.release.set()
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)

    @staticmethod
    def _post_job(base_url: str) -> dict[str, object]:
        request = Request(
            f"{base_url}/v1/video-jobs",
            method="POST",
            data=json.dumps(VALID_REQUEST).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        with urlopen(request, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))


class _InstantEngine:
    available = True

    def generate(self, prompt, duration_seconds, output_directory, progress):
        progress(96, "fake")
        return output_directory / "video.mp4", output_directory / "preview.gif"


class _InstantComicEngine:
    available = True
    tts_available = True

    def generate(
        self,
        *,
        job_id,
        requested_story,
        shot_duration_seconds,
        output_directory,
        progress,
    ):
        output_directory.mkdir(parents=True, exist_ok=True)
        shot_titles = ["抵达月背", "打开来信", "望向地球"]
        for index, title in enumerate(shot_titles, start=1):
            shot_id = f"E01-SH{index:02d}"
            progress(
                10 + index * 20,
                f"fake {title}",
                "rendering_shot",
                shot_id,
                50,
                "running",
            )
            progress(
                20 + index * 20,
                f"fake {title} done",
                "rendering_shot",
                shot_id,
                100,
                "succeeded",
            )
        (output_directory / "video.mp4").write_bytes(
            b"\x00\x00\x00\x18ftypisom" + b"v" * 2048
        )
        (output_directory / "preview.gif").write_bytes(b"GIF89a" + b"g" * 2048)
        (output_directory / "manifest.json").write_text(
            json.dumps(
                {
                    "jobId": job_id,
                    "requestedStory": requested_story,
                    "executionKind": "template",
                    "visualSource": "fixed_project_assets",
                    "generatedForRequest": False,
                    "containsAiGeneratedAssets": True,
                    "assetProvenance": "openai_imagegen_project_assets",
                    "templateStoryTitle": "月背最后一单",
                    "visualWarning": (
                        "本次请求未调用 AI，也未按 story 重新绘制；"
                        "画面是预先生成且有来源记录的 OpenAI ImageGen 项目素材。"
                    ),
                    "shotCount": 3,
                    "shotDurationSeconds": shot_duration_seconds,
                    "shots": [
                        {
                            "id": f"E01-SH{index:02d}",
                            "title": title,
                            "sourceAsset": source_asset,
                            "sourceAssetSha256": SOURCE_ASSET_HASHES[source_asset],
                        }
                        for index, (title, source_asset) in enumerate(
                            zip(shot_titles, SOURCE_ASSET_HASHES, strict=True),
                            start=1,
                        )
                    ],
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        (output_directory / "script.json").write_text(
            json.dumps(
                {
                    "title": "月背最后一单",
                    "requestedStory": requested_story,
                    "executionKind": "template",
                    "visualSource": "fixed_project_assets",
                    "generatedForRequest": False,
                    "containsAiGeneratedAssets": True,
                    "assetProvenance": "openai_imagegen_project_assets",
                    "shots": [
                        {"id": f"E01-SH{index:02d}", "title": title}
                        for index, title in enumerate(shot_titles, start=1)
                    ],
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )


class _UnavailableComicEngine(_InstantComicEngine):
    available = False
    tts_available = False


class _BlockingEngine(_InstantEngine):
    def __init__(self) -> None:
        self.started = threading.Event()
        self.release = threading.Event()

    def generate(self, prompt, duration_seconds, output_directory, progress):
        self.started.set()
        if not self.release.wait(timeout=10):
            raise RuntimeError("blocking engine timeout")
        return super().generate(prompt, duration_seconds, output_directory, progress)


if __name__ == "__main__":
    unittest.main()
