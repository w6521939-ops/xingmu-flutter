enum VideoLabCapability { text, image, video, voice }

enum VideoLabAvailability { available, requiresConfiguration }

enum VideoLabJobStatus { queued, running, succeeded, failed }

enum VideoLabExecutionKind { template, cloudAi, hybrid }

enum VideoLabExecutionSource { local, preGenerated, cloud, notExecuted }

class VideoLabModelExecution {
  const VideoLabModelExecution({
    required this.text,
    required this.image,
    required this.video,
    required this.voice,
  });

  final VideoLabExecutionSource text;
  final VideoLabExecutionSource image;
  final VideoLabExecutionSource video;
  final VideoLabExecutionSource voice;

  bool get generatesShotVideos => video == VideoLabExecutionSource.cloud;

  factory VideoLabModelExecution.fromJson(Object? value) {
    final map = _requiredMap(value, 'modelExecution');
    return VideoLabModelExecution(
      text: _executionSource(map, 'text'),
      image: _executionSource(map, 'image'),
      video: _executionSource(map, 'video'),
      voice: _executionSource(map, 'voice'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VideoLabModelExecution &&
      other.text == text &&
      other.image == image &&
      other.video == video &&
      other.voice == voice;

  @override
  int get hashCode => Object.hash(text, image, video, voice);
}

class VideoLabModel {
  const VideoLabModel({
    required this.id,
    required this.capability,
    required this.provider,
    required this.displayName,
    required this.description,
    required this.pricingType,
    required this.availability,
    required this.requiresCredential,
    this.pricingUrl,
    this.billingUrl,
  });

  final String id;
  final VideoLabCapability capability;
  final String provider;
  final String displayName;
  final String description;
  final String pricingType;
  final VideoLabAvailability availability;
  final bool requiresCredential;
  final Uri? pricingUrl;
  final Uri? billingUrl;

  bool get canGenerate => availability == VideoLabAvailability.available;
  bool get isPaid => pricingType == 'paid';

  factory VideoLabModel.fromJson(Object? value) {
    final map = _requiredMap(value, 'model');
    final capability = switch (_requiredString(map, 'capability')) {
      'text' => VideoLabCapability.text,
      'image' => VideoLabCapability.image,
      'video' => VideoLabCapability.video,
      'voice' => VideoLabCapability.voice,
      final unsupported => throw FormatException(
        '不支持的模型 capability: $unsupported',
      ),
    };
    final availability = switch (_requiredString(map, 'availability')) {
      'available' => VideoLabAvailability.available,
      'requires_configuration' => VideoLabAvailability.requiresConfiguration,
      final unsupported => throw FormatException(
        '不支持的模型 availability: $unsupported',
      ),
    };
    final pricingType = _requiredString(map, 'pricingType');
    if (pricingType != 'free' && pricingType != 'paid') {
      throw FormatException('不支持的 pricingType: $pricingType');
    }
    return VideoLabModel(
      id: _requiredString(map, 'id'),
      capability: capability,
      provider: _requiredString(map, 'provider'),
      displayName: _requiredString(map, 'displayName'),
      description: _requiredString(map, 'description'),
      pricingType: pricingType,
      availability: availability,
      requiresCredential: _requiredBool(map, 'requiresCredential'),
      pricingUrl: _optionalOfficialHttpsUri(map, 'pricingUrl'),
      billingUrl: _optionalOfficialHttpsUri(map, 'billingUrl'),
    );
  }
}

class VideoLabPipeline {
  const VideoLabPipeline({
    required this.id,
    required this.displayName,
    required this.availability,
    required this.executionKind,
    required this.textModelId,
    required this.imageModelId,
    required this.videoModelId,
    required this.voiceModelId,
    this.modelExecution,
  });

  final String id;
  final String displayName;
  final VideoLabAvailability availability;
  final VideoLabExecutionKind executionKind;
  final String textModelId;
  final String imageModelId;
  final String videoModelId;
  final String voiceModelId;
  final VideoLabModelExecution? modelExecution;

  bool get canGenerate => availability == VideoLabAvailability.available;

  bool matches({
    required String textModelId,
    required String imageModelId,
    required String videoModelId,
    required String voiceModelId,
  }) =>
      this.textModelId == textModelId &&
      this.imageModelId == imageModelId &&
      this.videoModelId == videoModelId &&
      this.voiceModelId == voiceModelId;

  factory VideoLabPipeline.fromJson(Object? value) {
    final map = _requiredMap(value, 'comicPipeline');
    return VideoLabPipeline(
      id: _requiredString(map, 'id'),
      displayName: _requiredString(map, 'displayName'),
      availability: _availability(map, 'availability'),
      executionKind: _executionKind(map, 'executionKind'),
      textModelId: _requiredString(map, 'textModelId'),
      imageModelId: _requiredString(map, 'imageModelId'),
      videoModelId: _requiredString(map, 'videoModelId'),
      voiceModelId: _requiredString(map, 'voiceModelId'),
      modelExecution: map['modelExecution'] == null
          ? null
          : VideoLabModelExecution.fromJson(map['modelExecution']),
    );
  }
}

class VideoLabCatalog {
  const VideoLabCatalog({
    required this.textModels,
    required this.imageModels,
    required this.videoModels,
    required this.voiceModels,
    required this.comicPipelines,
  });

  final List<VideoLabModel> textModels;
  final List<VideoLabModel> imageModels;
  final List<VideoLabModel> videoModels;
  final List<VideoLabModel> voiceModels;
  final List<VideoLabPipeline> comicPipelines;

  List<List<VideoLabModel>> get groups => [
    textModels,
    imageModels,
    videoModels,
    voiceModels,
  ];

  factory VideoLabCatalog.fromJson(Object? value) {
    final map = _requiredMap(value, 'catalog');
    final textModels = _modelList(map, 'textModels');
    final imageModels = _modelList(map, 'imageModels');
    final videoModels = _modelList(map, 'videoModels');
    final voiceModels = _modelList(map, 'voiceModels');
    _requireCapability(textModels, VideoLabCapability.text, 'textModels');
    _requireCapability(imageModels, VideoLabCapability.image, 'imageModels');
    _requireCapability(videoModels, VideoLabCapability.video, 'videoModels');
    _requireCapability(voiceModels, VideoLabCapability.voice, 'voiceModels');
    final comicPipelines = map['comicPipelines'] == null
        ? _legacyPipelines(textModels, imageModels, videoModels, voiceModels)
        : _pipelineList(map, textModels, imageModels, videoModels, voiceModels);
    return VideoLabCatalog(
      textModels: textModels,
      imageModels: imageModels,
      videoModels: videoModels,
      voiceModels: voiceModels,
      comicPipelines: comicPipelines,
    );
  }

  static VideoLabCatalog fallback() => VideoLabCatalog(
    textModels: [
      const VideoLabModel(
        id: 'local_storyboard_template',
        capability: VideoLabCapability.text,
        provider: 'local template',
        displayName: '本地三镜头模板脚本',
        description: '生成固定的三镜头结构，不调用文本大模型。',
        pricingType: 'free',
        availability: VideoLabAvailability.available,
        requiresCredential: false,
      ),
      _cloudModel(
        id: 'qwen3.6-plus',
        capability: VideoLabCapability.text,
        displayName: '通义千问 qwen3.6-plus',
        description: '按故事生成漫剧脚本与连续性锁；当前后端适配器待接入。',
      ),
    ],
    imageModels: [
      const VideoLabModel(
        id: 'fixed_moon_courier_assets',
        capability: VideoLabCapability.image,
        provider: 'bundled showcase assets',
        displayName: '《月背最后一单》固定素材',
        description: '使用预生成的项目固定 ImageGen 角色与场景图，不会按输入主题重新绘制。',
        pricingType: 'free',
        availability: VideoLabAvailability.available,
        requiresCredential: false,
      ),
      _cloudModel(
        id: 'wan2.7-image-pro',
        capability: VideoLabCapability.image,
        displayName: '通义万相 Wan 2.7 Image Pro',
        description: '生成角色、道具、场景参考图并保持镜头连续性；当前后端适配器待接入。',
      ),
    ],
    videoModels: [
      const VideoLabModel(
        id: 'local_ffmpeg_motion_comic',
        capability: VideoLabCapability.video,
        provider: 'local FFmpeg',
        displayName: '本地 FFmpeg 漫剧合成',
        description: '用推拉、平移、转场和字幕合成真实 MP4，本次不调用图生视频模型。',
        pricingType: 'free',
        availability: VideoLabAvailability.available,
        requiresCredential: false,
      ),
      _cloudModel(
        id: 'wan2.7-i2v-2026-04-25',
        capability: VideoLabCapability.video,
        displayName: '通义万相 Wan 2.7 I2V',
        description: '使用每镜头首尾帧生成动态视频；当前后端适配器待接入。',
      ),
    ],
    voiceModels: [
      const VideoLabModel(
        id: 'windows_sapi_huihui',
        capability: VideoLabCapability.voice,
        provider: 'Windows system voice',
        displayName: 'Windows 慧慧女声',
        description: '由 Windows 后端生成普通话对白，本次不调用云端声音克隆。',
        pricingType: 'free',
        availability: VideoLabAvailability.available,
        requiresCredential: false,
      ),
      _cloudModel(
        id: 'cosyvoice-v3.5-plus',
        capability: VideoLabCapability.voice,
        displayName: 'CosyVoice v3.5 Plus',
        description: '云端角色配音模型；当前后端适配器待接入，手机不接收 Key。',
      ),
    ],
    comicPipelines: const [
      VideoLabPipeline(
        id: 'local_moon_courier_comic',
        displayName: '月背最后一单·本地三镜头漫剧',
        availability: VideoLabAvailability.available,
        executionKind: VideoLabExecutionKind.template,
        textModelId: 'local_storyboard_template',
        imageModelId: 'fixed_moon_courier_assets',
        videoModelId: 'local_ffmpeg_motion_comic',
        voiceModelId: 'windows_sapi_huihui',
      ),
      VideoLabPipeline(
        id: 'wan_fixed_frames_motion_comic',
        displayName: '固定分镜首尾帧 · Wan 视频漫剧',
        availability: VideoLabAvailability.requiresConfiguration,
        executionKind: VideoLabExecutionKind.hybrid,
        textModelId: 'local_storyboard_template',
        imageModelId: 'fixed_moon_courier_assets',
        videoModelId: 'wan2.7-i2v-2026-04-25',
        voiceModelId: 'windows_sapi_huihui',
      ),
    ],
  );
}

class VideoLabShot {
  const VideoLabShot({
    required this.id,
    required this.title,
    required this.status,
    required this.progress,
    required this.stageCode,
    this.firstFrameUrl,
    this.lastFrameUrl,
    this.motionPrompt,
    this.videoTask,
  });

  final String id;
  final String title;
  final VideoLabJobStatus status;
  final double progress;
  final String stageCode;
  final Uri? firstFrameUrl;
  final Uri? lastFrameUrl;
  final String? motionPrompt;
  final VideoLabShotVideoTask? videoTask;

  bool get hasFramePair => firstFrameUrl != null && lastFrameUrl != null;

  factory VideoLabShot.fromJson(Object? value, Uri baseUri) {
    final map = _requiredMap(value, 'shot');
    final firstFrameUrl = _optionalResolvedUri(map, 'firstFrameUrl', baseUri);
    final lastFrameUrl = _optionalResolvedUri(map, 'lastFrameUrl', baseUri);
    if ((firstFrameUrl == null) != (lastFrameUrl == null)) {
      throw const FormatException('镜头首帧与尾帧必须成对返回');
    }
    return VideoLabShot(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      status: _jobStatus(map, 'status'),
      progress: _progress(map, 'progress'),
      stageCode: _stageCode(map, 'stageCode'),
      firstFrameUrl: firstFrameUrl,
      lastFrameUrl: lastFrameUrl,
      motionPrompt: _optionalString(map, 'motionPrompt'),
      videoTask: map['videoTask'] == null
          ? null
          : VideoLabShotVideoTask.fromJson(map['videoTask'], baseUri),
    );
  }
}

class VideoLabShotVideoTask {
  const VideoLabShotVideoTask({
    required this.status,
    required this.progress,
    this.remoteTaskId,
    this.videoUrl,
    this.errorMessage,
  });

  final String? remoteTaskId;
  final VideoLabJobStatus status;
  final double progress;
  final Uri? videoUrl;
  final String? errorMessage;

  factory VideoLabShotVideoTask.fromJson(Object? value, Uri baseUri) {
    final map = _requiredMap(value, 'videoTask');
    final status = _jobStatus(map, 'status');
    final progress = _progress(map, 'progress');
    final videoUrl = _optionalResolvedUri(map, 'videoUrl', baseUri);
    if (status == VideoLabJobStatus.succeeded &&
        (progress != 1 || videoUrl == null)) {
      throw const FormatException('成功的分镜视频任务必须为 100% 并返回同源 MP4');
    }
    return VideoLabShotVideoTask(
      remoteTaskId: _optionalString(map, 'remoteTaskId'),
      status: status,
      progress: progress,
      videoUrl: videoUrl,
      errorMessage: _optionalString(map, 'error'),
    );
  }
}

class VideoLabOutput {
  const VideoLabOutput({
    required this.previewUrl,
    required this.videoUrl,
    required this.manifestUrl,
    required this.scriptUrl,
    required this.generatedForRequest,
    required this.containsAiGeneratedAssets,
    required this.assetProvenance,
    required this.visualSource,
    this.compositionType,
    this.sourceClipCount,
    this.modelExecution,
  });

  final Uri previewUrl;
  final Uri videoUrl;
  final Uri manifestUrl;
  final Uri scriptUrl;
  final bool generatedForRequest;
  final bool containsAiGeneratedAssets;
  final String assetProvenance;
  final String visualSource;
  final String? compositionType;
  final int? sourceClipCount;
  final VideoLabModelExecution? modelExecution;

  bool get isShotVideoComposition =>
      compositionType == 'shot_videos_concat' && sourceClipCount == 3;

  factory VideoLabOutput.fromJson(Object? value, Uri baseUri) {
    final map = _requiredMap(value, 'output');
    final compositionType = _optionalString(map, 'compositionType');
    final sourceClipCount = _optionalPositiveInt(map, 'sourceClipCount');
    if ((compositionType == null) != (sourceClipCount == null)) {
      throw const FormatException('成片合成类型与源片段数量必须同时返回');
    }
    return VideoLabOutput(
      previewUrl: _requiredResolvedUri(map, 'previewUrl', baseUri),
      videoUrl: _requiredResolvedUri(map, 'videoUrl', baseUri),
      manifestUrl: _requiredResolvedUri(map, 'manifestUrl', baseUri),
      scriptUrl: _requiredResolvedUri(map, 'scriptUrl', baseUri),
      generatedForRequest: _requiredBool(map, 'generatedForRequest'),
      containsAiGeneratedAssets: _requiredBool(
        map,
        'containsAiGeneratedAssets',
      ),
      assetProvenance: _requiredString(map, 'assetProvenance'),
      visualSource: _requiredString(map, 'visualSource'),
      compositionType: compositionType,
      sourceClipCount: sourceClipCount,
      modelExecution: map['modelExecution'] == null
          ? null
          : VideoLabModelExecution.fromJson(map['modelExecution']),
    );
  }
}

class VideoLabJob {
  const VideoLabJob({
    required this.id,
    required this.status,
    required this.progress,
    required this.executionKind,
    required this.generatedForRequest,
    required this.containsAiGeneratedAssets,
    required this.assetProvenance,
    required this.visualSource,
    required this.stageCode,
    required this.templateStoryTitle,
    required this.visualWarning,
    required this.shots,
    this.modelExecution,
    this.errorMessage,
    this.output,
  });

  final String id;
  final VideoLabJobStatus status;
  final double progress;
  final VideoLabExecutionKind executionKind;
  final bool generatedForRequest;
  final bool containsAiGeneratedAssets;
  final String assetProvenance;
  final String visualSource;
  final String stageCode;
  final String templateStoryTitle;
  final String visualWarning;
  final List<VideoLabShot> shots;
  final VideoLabModelExecution? modelExecution;
  final String? errorMessage;
  final VideoLabOutput? output;

  Uri? get previewUrl => output?.previewUrl;
  Uri? get videoUrl => output?.videoUrl;
  Uri? get manifestUrl => output?.manifestUrl;
  Uri? get scriptUrl => output?.scriptUrl;

  bool get isTerminal =>
      status == VideoLabJobStatus.succeeded ||
      status == VideoLabJobStatus.failed;

  factory VideoLabJob.fromJson(Object? value, Uri baseUri) {
    final map = _requiredMap(value, 'job');
    final status = _jobStatus(map, 'status');
    final executionKind = switch (_requiredString(map, 'executionKind')) {
      'template' => VideoLabExecutionKind.template,
      'cloud_ai' => VideoLabExecutionKind.cloudAi,
      'hybrid' => VideoLabExecutionKind.hybrid,
      final unsupported => throw FormatException(
        '不支持的 executionKind: $unsupported',
      ),
    };
    final generatedForRequest = _requiredBool(map, 'generatedForRequest');
    final containsAiGeneratedAssets = _requiredBool(
      map,
      'containsAiGeneratedAssets',
    );
    final assetProvenance = _requiredString(map, 'assetProvenance');
    final visualSource = _requiredString(map, 'visualSource');
    if (generatedForRequest && !containsAiGeneratedAssets) {
      throw const FormatException('本次调用 AI 生成的任务必须包含 AI 生成素材');
    }
    if (executionKind == VideoLabExecutionKind.template) {
      if (generatedForRequest) {
        throw const FormatException('本地模板任务不能标记为本次调用 AI 生成');
      }
      if (!containsAiGeneratedAssets) {
        throw const FormatException('本地模板任务必须披露预生成的 AI 项目素材');
      }
      if (assetProvenance != 'openai_imagegen_project_assets') {
        throw const FormatException('本地模板任务的素材来源声明不正确');
      }
      if (visualSource != 'fixed_project_assets') {
        throw const FormatException('本地模板任务的视觉来源声明不正确');
      }
    }
    if (executionKind == VideoLabExecutionKind.cloudAi &&
        !generatedForRequest) {
      throw const FormatException('云端 AI 任务必须标记为本次调用 AI 生成');
    }
    final modelExecution = map['modelExecution'] == null
        ? null
        : VideoLabModelExecution.fromJson(map['modelExecution']);
    if (executionKind == VideoLabExecutionKind.template &&
        modelExecution != null &&
        (modelExecution.text != VideoLabExecutionSource.local ||
            modelExecution.image != VideoLabExecutionSource.preGenerated ||
            modelExecution.video != VideoLabExecutionSource.local ||
            modelExecution.voice != VideoLabExecutionSource.local)) {
      throw const FormatException('本地模板任务的逐能力执行声明不正确');
    }
    if (executionKind == VideoLabExecutionKind.hybrid &&
        (!generatedForRequest ||
            visualSource != 'fixed_project_assets' ||
            (modelExecution != null &&
                (modelExecution.text != VideoLabExecutionSource.local ||
                    modelExecution.image !=
                        VideoLabExecutionSource.preGenerated ||
                    modelExecution.video != VideoLabExecutionSource.cloud ||
                    modelExecution.voice != VideoLabExecutionSource.local)))) {
      throw const FormatException('混合分镜视频任务的逐能力执行声明不正确');
    }
    final shots = _requiredList(map, 'shots')
        .map((value) => VideoLabShot.fromJson(value, baseUri))
        .toList(growable: false);
    if (shots.length != 3 || shots.map((shot) => shot.id).toSet().length != 3) {
      throw const FormatException('漫剧任务必须返回 3 个唯一镜头');
    }
    final rawOutput = map['output'];
    final output = rawOutput == null
        ? null
        : VideoLabOutput.fromJson(rawOutput, baseUri);
    if (status == VideoLabJobStatus.succeeded && output == null) {
      throw const FormatException('成功任务必须返回完整漫剧输出');
    }
    if (output != null &&
        (output.generatedForRequest != generatedForRequest ||
            output.containsAiGeneratedAssets != containsAiGeneratedAssets ||
            output.assetProvenance != assetProvenance ||
            output.visualSource != visualSource)) {
      throw const FormatException('output 真实性字段必须与任务一致');
    }
    if (output != null && output.modelExecution != modelExecution) {
      throw const FormatException('output 逐能力执行声明必须与任务一致');
    }
    if (status == VideoLabJobStatus.succeeded &&
        executionKind == VideoLabExecutionKind.hybrid) {
      if (modelExecution == null || !modelExecution.generatesShotVideos) {
        throw const FormatException('成功的混合任务必须披露云端分镜视频执行能力');
      }
      if (shots.any(
        (shot) =>
            !shot.hasFramePair ||
            shot.videoTask?.status != VideoLabJobStatus.succeeded,
      )) {
        throw const FormatException('成功的混合任务必须返回每个镜头的首尾帧与成功 MP4');
      }
      if (output?.isShotVideoComposition != true) {
        throw const FormatException('成功的混合任务必须由 3 个分镜视频合片');
      }
    }
    return VideoLabJob(
      id: _requiredString(map, 'id'),
      status: status,
      progress: _progress(map, 'progress'),
      executionKind: executionKind,
      generatedForRequest: generatedForRequest,
      containsAiGeneratedAssets: containsAiGeneratedAssets,
      assetProvenance: assetProvenance,
      visualSource: visualSource,
      stageCode: _stageCode(map, 'stageCode'),
      templateStoryTitle: _requiredString(map, 'templateStoryTitle'),
      visualWarning: _requiredString(map, 'visualWarning'),
      shots: shots,
      modelExecution: modelExecution,
      errorMessage: _optionalString(map, 'error'),
      output: output,
    );
  }
}

const String _pricingUrl =
    'https://help.aliyun.com/zh/model-studio/model-pricing';
const String _billingUrl =
    'https://help.aliyun.com/zh/user-center/'
    'use-alipay-online-banking-to-recharge-online';

VideoLabModel _cloudModel({
  required String id,
  required VideoLabCapability capability,
  required String displayName,
  required String description,
}) => VideoLabModel(
  id: id,
  capability: capability,
  provider: 'Alibaba Cloud Model Studio',
  displayName: displayName,
  description: description,
  pricingType: 'paid',
  availability: VideoLabAvailability.requiresConfiguration,
  requiresCredential: true,
  pricingUrl: Uri.parse(_pricingUrl),
  billingUrl: Uri.parse(_billingUrl),
);

List<VideoLabModel> _modelList(Map<String, Object?> map, String key) {
  final models = _requiredList(
    map,
    key,
  ).map(VideoLabModel.fromJson).toList(growable: false);
  if (models.isEmpty) throw FormatException('$key 不能为空');
  if (models.map((model) => model.id).toSet().length != models.length) {
    throw FormatException('$key 包含重复模型 ID');
  }
  return models;
}

List<VideoLabPipeline> _pipelineList(
  Map<String, Object?> map,
  List<VideoLabModel> textModels,
  List<VideoLabModel> imageModels,
  List<VideoLabModel> videoModels,
  List<VideoLabModel> voiceModels,
) {
  final pipelines = _requiredList(
    map,
    'comicPipelines',
  ).map(VideoLabPipeline.fromJson).toList(growable: false);
  if (pipelines.isEmpty) {
    throw const FormatException('comicPipelines 不能为空');
  }
  if (pipelines.map((pipeline) => pipeline.id).toSet().length !=
      pipelines.length) {
    throw const FormatException('comicPipelines 包含重复流水线 ID');
  }
  final modelIdsByCapability = {
    VideoLabCapability.text: textModels.map((model) => model.id).toSet(),
    VideoLabCapability.image: imageModels.map((model) => model.id).toSet(),
    VideoLabCapability.video: videoModels.map((model) => model.id).toSet(),
    VideoLabCapability.voice: voiceModels.map((model) => model.id).toSet(),
  };
  for (final pipeline in pipelines) {
    final references = {
      VideoLabCapability.text: pipeline.textModelId,
      VideoLabCapability.image: pipeline.imageModelId,
      VideoLabCapability.video: pipeline.videoModelId,
      VideoLabCapability.voice: pipeline.voiceModelId,
    };
    for (final entry in references.entries) {
      if (!modelIdsByCapability[entry.key]!.contains(entry.value)) {
        throw FormatException(
          '流水线 ${pipeline.id} 引用了不存在的 ${entry.key.name} 模型',
        );
      }
    }
  }
  return pipelines;
}

List<VideoLabPipeline> _legacyPipelines(
  List<VideoLabModel> textModels,
  List<VideoLabModel> imageModels,
  List<VideoLabModel> videoModels,
  List<VideoLabModel> voiceModels,
) {
  VideoLabModel? find(List<VideoLabModel> models, String id) {
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }

  VideoLabAvailability availabilityFor(List<VideoLabModel?> models) =>
      models.every((model) => model?.canGenerate == true)
      ? VideoLabAvailability.available
      : VideoLabAvailability.requiresConfiguration;

  final localModels = <VideoLabModel?>[
    find(textModels, 'local_storyboard_template'),
    find(imageModels, 'fixed_moon_courier_assets'),
    find(videoModels, 'local_ffmpeg_motion_comic'),
    find(voiceModels, 'windows_sapi_huihui'),
  ];
  final hybridModels = <VideoLabModel?>[
    find(textModels, 'local_storyboard_template'),
    find(imageModels, 'fixed_moon_courier_assets'),
    find(videoModels, 'wan2.7-i2v-2026-04-25'),
    find(voiceModels, 'windows_sapi_huihui'),
  ];
  return [
    if (localModels.every((model) => model != null))
      VideoLabPipeline(
        id: 'local_moon_courier_comic',
        displayName: '本地兼容漫剧流水线',
        availability: availabilityFor(localModels),
        executionKind: VideoLabExecutionKind.template,
        textModelId: 'local_storyboard_template',
        imageModelId: 'fixed_moon_courier_assets',
        videoModelId: 'local_ffmpeg_motion_comic',
        voiceModelId: 'windows_sapi_huihui',
      ),
    if (hybridModels.every((model) => model != null))
      VideoLabPipeline(
        id: 'wan_fixed_frames_motion_comic',
        displayName: '混合兼容分镜视频流水线',
        availability: availabilityFor(hybridModels),
        executionKind: VideoLabExecutionKind.hybrid,
        textModelId: 'local_storyboard_template',
        imageModelId: 'fixed_moon_courier_assets',
        videoModelId: 'wan2.7-i2v-2026-04-25',
        voiceModelId: 'windows_sapi_huihui',
      ),
  ];
}

VideoLabAvailability _availability(Map<String, Object?> map, String key) =>
    switch (_requiredString(map, key)) {
      'available' => VideoLabAvailability.available,
      'requires_configuration' => VideoLabAvailability.requiresConfiguration,
      final unsupported => throw FormatException('不支持的 $key: $unsupported'),
    };

VideoLabExecutionKind _executionKind(Map<String, Object?> map, String key) =>
    switch (_requiredString(map, key)) {
      'template' => VideoLabExecutionKind.template,
      'cloud_ai' => VideoLabExecutionKind.cloudAi,
      'hybrid' => VideoLabExecutionKind.hybrid,
      final unsupported => throw FormatException('不支持的 $key: $unsupported'),
    };

void _requireCapability(
  List<VideoLabModel> models,
  VideoLabCapability capability,
  String key,
) {
  if (models.any((model) => model.capability != capability)) {
    throw FormatException('$key capability 与分组不一致');
  }
}

Map<String, Object?> _requiredMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label 必须是 JSON 对象');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Object?> _requiredList(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! List) throw FormatException('$key 必须是数组');
  return value;
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 必须是非空字符串或 null');
  }
  return value.trim();
}

bool _requiredBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! bool) throw FormatException('$key 必须是布尔值');
  return value;
}

int? _optionalPositiveInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! int || value <= 0) {
    throw FormatException('$key 必须是正整数或 null');
  }
  return value;
}

VideoLabExecutionSource _executionSource(
  Map<String, Object?> map,
  String key,
) => switch (_requiredString(map, key)) {
  'local' => VideoLabExecutionSource.local,
  'pre_generated' => VideoLabExecutionSource.preGenerated,
  'cloud' => VideoLabExecutionSource.cloud,
  'not_executed' => VideoLabExecutionSource.notExecuted,
  final unsupported => throw FormatException(
    '不支持的 modelExecution.$key: $unsupported',
  ),
};

VideoLabJobStatus _jobStatus(Map<String, Object?> map, String key) =>
    switch (_requiredString(map, key)) {
      'queued' => VideoLabJobStatus.queued,
      'running' => VideoLabJobStatus.running,
      'succeeded' => VideoLabJobStatus.succeeded,
      'failed' => VideoLabJobStatus.failed,
      final unsupported => throw FormatException('不支持的 $key: $unsupported'),
    };

double _progress(Map<String, Object?> map, String key) {
  final raw = map[key];
  if (raw is! num || !raw.isFinite || raw < 0 || raw > 100) {
    throw FormatException('$key 必须是 0 到 100 的数字');
  }
  return raw.toDouble() / 100;
}

String _stageCode(Map<String, Object?> map, String key) {
  final value = _requiredString(map, key);
  if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(value)) {
    throw FormatException('$key 必须是合法 snake_case 阶段代码');
  }
  return value;
}

Uri? _optionalOfficialHttpsUri(Map<String, Object?> map, String key) {
  final raw = _optionalString(map, key);
  if (raw == null) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      uri.host.toLowerCase() != 'help.aliyun.com') {
    throw FormatException('$key 必须是允许的阿里云官方 HTTPS 地址');
  }
  return uri;
}

Uri _requiredResolvedUri(Map<String, Object?> map, String key, Uri baseUri) {
  final raw = _requiredString(map, key);
  final uri = baseUri.resolve(raw);
  if ((uri.scheme != 'http' && uri.scheme != 'https') ||
      !uri.hasAuthority ||
      uri.scheme != baseUri.scheme ||
      uri.authority != baseUri.authority) {
    throw FormatException('$key 必须是漫剧服务同源 HTTP(S) 地址');
  }
  return uri;
}

Uri? _optionalResolvedUri(Map<String, Object?> map, String key, Uri baseUri) {
  if (map[key] == null) return null;
  return _requiredResolvedUri(map, key, baseUri);
}
