"""Model catalog exposed by the local video-lab service."""

from __future__ import annotations

from copy import deepcopy
from typing import Any


PRICING_URL = "https://help.aliyun.com/zh/model-studio/model-pricing"
BILLING_URL = (
    "https://help.aliyun.com/zh/user-center/"
    "use-alipay-online-banking-to-recharge-online"
)

LOCAL_COMIC_PIPELINE_ID = "local_moon_courier_comic"
LOCAL_COMIC_SCRIPT_MODEL_ID = "local_storyboard_template"
LOCAL_COMIC_IMAGE_MODEL_ID = "fixed_moon_courier_assets"
LOCAL_COMIC_VIDEO_MODEL_ID = "local_ffmpeg_motion_comic"
LOCAL_COMIC_VOICE_MODEL_ID = "windows_sapi_huihui"
WAN_VIDEO_MODEL_ID = "wan2.7-i2v-2026-04-25"
HYBRID_COMIC_PIPELINE_ID = "wan_fixed_frames_motion_comic"

MODEL_CATALOG: dict[str, list[dict[str, Any]]] = {
    "textModels": [
        {
            "id": "manual",
            "capability": "text",
            "provider": "local",
            "displayName": "直接使用输入文本",
            "description": "不调用大模型，直接把输入渲染为字幕卡，免费且可离线验证。",
            "pricingType": "free",
            "availability": "available",
            "requiresCredential": False,
        },
        {
            "id": LOCAL_COMIC_SCRIPT_MODEL_ID,
            "capability": "text",
            "provider": "local template",
            "displayName": "月背最后一单·固定三镜头脚本",
            "description": "固定项目样片剧本；不会根据任意输入重新创作画面。",
            "pricingType": "free",
            "availability": "requires_configuration",
            "requiresCredential": False,
        },
        {
            "id": "qwen3.6-plus",
            "capability": "text",
            "provider": "Alibaba Cloud Model Studio",
            "displayName": "通义千问 qwen3.6-plus",
            "description": "付费云端文本模型；需要由受信服务端配置凭据后才能生成。",
            "pricingType": "paid",
            "availability": "requires_configuration",
            "requiresCredential": True,
            "pricingUrl": PRICING_URL,
            "billingUrl": BILLING_URL,
        },
    ],
    "videoModels": [
        {
            "id": "local_ffmpeg_slides",
            "capability": "video",
            "provider": "local FFmpeg",
            "displayName": "本地动态字幕卡",
            "description": "使用 FFmpeg 生成真实 H.264 MP4；它是模板合成，不是 AI 文生视频。",
            "pricingType": "free",
            "availability": "available",
            "requiresCredential": False,
        },
        {
            "id": LOCAL_COMIC_VIDEO_MODEL_ID,
            "capability": "video",
            "provider": "local FFmpeg",
            "displayName": "本地三镜头漫剧模板",
            "description": "对项目固定画面执行推拉、平移、字幕与配音合成；不是 AI 视频生成。",
            "pricingType": "free",
            "availability": "requires_configuration",
            "requiresCredential": False,
        },
        {
            "id": WAN_VIDEO_MODEL_ID,
            "capability": "video",
            "provider": "Alibaba Cloud Model Studio",
            "displayName": "通义万相 Wan 2.7 I2V",
            "description": "付费云端图生视频模型；需要由受信服务端配置凭据后才能生成。",
            "pricingType": "paid",
            "availability": "requires_configuration",
            "requiresCredential": True,
            "pricingUrl": PRICING_URL,
            "billingUrl": BILLING_URL,
        },
    ],
    "imageModels": [
        {
            "id": LOCAL_COMIC_IMAGE_MODEL_ID,
            "capability": "image",
            "provider": "project assets",
            "displayName": "月球快递员固定项目画面",
            "description": "使用仓库内三张固定项目资产，不会根据输入故事重新绘制。",
            "pricingType": "free",
            "availability": "requires_configuration",
            "requiresCredential": False,
            "executionKind": "template",
            "visualSource": "fixed_project_assets",
            "generatedForRequest": False,
            "containsAiGeneratedAssets": True,
            "assetProvenance": "openai_imagegen_project_assets",
        },
        {
            "id": "wan2.7-image-pro",
            "capability": "image",
            "provider": "Alibaba Cloud Model Studio",
            "displayName": "通义万相 Wan 2.7 Image Pro",
            "description": "付费云端参考图像生成；当前本地服务尚未配置。",
            "pricingType": "paid",
            "availability": "requires_configuration",
            "requiresCredential": True,
            "pricingUrl": PRICING_URL,
            "billingUrl": BILLING_URL,
        },
    ],
    "voiceModels": [
        {
            "id": LOCAL_COMIC_VOICE_MODEL_ID,
            "capability": "voice",
            "provider": "Windows SAPI",
            "displayName": "Microsoft Huihui Desktop",
            "description": "使用 Windows 本机中文语音合成，不使用云端凭据。",
            "pricingType": "free",
            "availability": "requires_configuration",
            "requiresCredential": False,
        },
        {
            "id": "cosyvoice-v3.5-plus",
            "capability": "voice",
            "provider": "Alibaba Cloud Model Studio",
            "displayName": "CosyVoice v3.5 Plus",
            "description": "付费云端语音合成；当前本地服务尚未配置。",
            "pricingType": "paid",
            "availability": "requires_configuration",
            "requiresCredential": True,
            "pricingUrl": PRICING_URL,
            "billingUrl": BILLING_URL,
        },
    ],
    "comicPipelines": [
        {
            "id": LOCAL_COMIC_PIPELINE_ID,
            "provider": "local",
            "displayName": "月背最后一单·本地三镜头漫剧",
            "description": "固定项目资产、Huihui 中文配音与 FFmpeg 动效合成。",
            "pricingType": "free",
            "availability": "requires_configuration",
            "requiresCredential": False,
            "executionKind": "template",
            "visualSource": "fixed_project_assets",
            "generatedForRequest": False,
            "containsAiGeneratedAssets": True,
            "assetProvenance": "openai_imagegen_project_assets",
            "templateStoryTitle": "月背最后一单",
            "shotCount": 3,
            "shotDurationSeconds": 3,
            "aspectRatio": "9:16",
            "textModelId": LOCAL_COMIC_SCRIPT_MODEL_ID,
            "imageModelId": LOCAL_COMIC_IMAGE_MODEL_ID,
            "videoModelId": LOCAL_COMIC_VIDEO_MODEL_ID,
            "voiceModelId": LOCAL_COMIC_VOICE_MODEL_ID,
        },
        {
            "id": "bailian_motion_comic",
            "provider": "Alibaba Cloud Model Studio",
            "displayName": "百炼云端首尾帧漫剧",
            "description": "云端角色连续性、首尾帧、配音与视频生成；当前未接入执行。",
            "pricingType": "paid",
            "availability": "requires_configuration",
            "requiresCredential": True,
            "executionKind": "cloud_ai",
            "visualSource": "model_generated",
            "generatedForRequest": True,
            "containsAiGeneratedAssets": True,
            "assetProvenance": "model_generated_for_request",
            "textModelId": "qwen3.6-plus",
            "imageModelId": "wan2.7-image-pro",
            "videoModelId": "wan2.7-i2v-2026-04-25",
            "voiceModelId": "cosyvoice-v3.5-plus",
            "pricingUrl": PRICING_URL,
            "billingUrl": BILLING_URL,
        },
        {
            "id": HYBRID_COMIC_PIPELINE_ID,
            "provider": "local + Alibaba Cloud Model Studio",
            "displayName": "固定分镜首尾帧 · Wan 视频漫剧",
            "description": (
                "使用固定项目首尾帧调用 Wan 生成三个真实视频片段，再由本地 "
                "Huihui 配音和 FFmpeg 合片；不会按 story 重绘首尾帧。"
            ),
            "pricingType": "paid",
            "availability": "requires_configuration",
            "requiresCredential": True,
            "executionKind": "hybrid",
            "visualSource": "fixed_project_assets",
            "generatedForRequest": True,
            "containsAiGeneratedAssets": True,
            "assetProvenance": "openai_imagegen_project_assets",
            "templateStoryTitle": "月背最后一单",
            "shotCount": 3,
            "shotDurationSeconds": 3,
            "aspectRatio": "9:16",
            "textModelId": LOCAL_COMIC_SCRIPT_MODEL_ID,
            "imageModelId": LOCAL_COMIC_IMAGE_MODEL_ID,
            "videoModelId": WAN_VIDEO_MODEL_ID,
            "voiceModelId": LOCAL_COMIC_VOICE_MODEL_ID,
            "modelExecution": {
                "text": "local",
                "image": "pre_generated",
                "video": "cloud",
                "voice": "local",
            },
            "pricingUrl": PRICING_URL,
            "billingUrl": BILLING_URL,
        },
    ],
}


def get_model_catalog(
    *,
    huihui_available: bool = False,
    local_comic_available: bool = False,
    wan_video_available: bool = False,
    hybrid_comic_available: bool = False,
) -> dict[str, list[dict[str, Any]]]:
    """Return a defensive copy so request handlers cannot mutate the catalog."""

    catalog = deepcopy(MODEL_CATALOG)
    for model in catalog["voiceModels"]:
        if model["id"] == LOCAL_COMIC_VOICE_MODEL_ID:
            model["availability"] = (
                "available" if huihui_available else "requires_configuration"
            )
    local_comic_ids = {
        LOCAL_COMIC_SCRIPT_MODEL_ID,
        LOCAL_COMIC_IMAGE_MODEL_ID,
        LOCAL_COMIC_VIDEO_MODEL_ID,
    }
    for group_name in ("textModels", "imageModels", "videoModels"):
        for model in catalog[group_name]:
            if model["id"] in local_comic_ids:
                model["availability"] = (
                    "available" if local_comic_available else "requires_configuration"
                )
    for pipeline in catalog["comicPipelines"]:
        if pipeline["id"] == LOCAL_COMIC_PIPELINE_ID:
            pipeline["availability"] = (
                "available" if local_comic_available else "requires_configuration"
            )
        elif pipeline["id"] == HYBRID_COMIC_PIPELINE_ID:
            pipeline["availability"] = (
                "available" if hybrid_comic_available else "requires_configuration"
            )
    for model in catalog["videoModels"]:
        if model["id"] == WAN_VIDEO_MODEL_ID:
            model["availability"] = (
                "available" if wan_video_available else "requires_configuration"
            )
    return catalog


def available_model_ids(capability_key: str) -> frozenset[str]:
    return frozenset(
        model["id"]
        for model in MODEL_CATALOG[capability_key]
        if model["availability"] == "available"
    )
