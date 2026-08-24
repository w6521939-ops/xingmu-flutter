import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/video_lab_repository.dart';
import '../domain/video_lab_models.dart';

enum VideoLabLoadState {
  unconfigured,
  loading,
  ready,
  submitting,
  polling,
  succeeded,
  failed,
}

class VideoLabController extends ChangeNotifier {
  VideoLabController({
    this.repository,
    VideoLabCatalog? fallbackCatalog,
    this.pollInterval = const Duration(seconds: 1),
  }) : catalog = fallbackCatalog ?? VideoLabCatalog.fallback() {
    selectedTextModelId = _firstAvailable(catalog.textModels).id;
    selectedImageModelId = _firstAvailable(catalog.imageModels).id;
    selectedVideoModelId = _firstAvailable(catalog.videoModels).id;
    selectedVoiceModelId = _firstAvailable(catalog.voiceModels).id;
  }

  final VideoLabRepository? repository;
  final Duration pollInterval;
  VideoLabCatalog catalog;
  VideoLabLoadState state = VideoLabLoadState.unconfigured;
  late String selectedTextModelId;
  late String selectedImageModelId;
  late String selectedVideoModelId;
  late String selectedVoiceModelId;
  VideoLabJob? job;
  String? errorMessage;
  Timer? _pollTimer;
  bool _catalogLoaded = false;
  bool _disposed = false;

  bool get isConfigured => repository != null;
  bool get hasLoadedCatalog => _catalogLoaded;
  bool get isBusy =>
      state == VideoLabLoadState.loading ||
      state == VideoLabLoadState.submitting ||
      state == VideoLabLoadState.polling;

  VideoLabModel get selectedTextModel =>
      _selected(catalog.textModels, selectedTextModelId);

  VideoLabModel get selectedImageModel =>
      _selected(catalog.imageModels, selectedImageModelId);

  VideoLabModel get selectedVideoModel =>
      _selected(catalog.videoModels, selectedVideoModelId);

  VideoLabModel get selectedVoiceModel =>
      _selected(catalog.voiceModels, selectedVoiceModelId);

  List<VideoLabModel> get selectedModels => [
    selectedTextModel,
    selectedImageModel,
    selectedVideoModel,
    selectedVoiceModel,
  ];

  VideoLabPipeline? get selectedPipeline {
    for (final pipeline in catalog.comicPipelines) {
      if (pipeline.matches(
        textModelId: selectedTextModelId,
        imageModelId: selectedImageModelId,
        videoModelId: selectedVideoModelId,
        voiceModelId: selectedVoiceModelId,
      )) {
        return pipeline;
      }
    }
    return null;
  }

  bool get usesFixedMoonCourierAssets =>
      selectedImageModelId == 'fixed_moon_courier_assets';

  bool get usesLocalTemplatePipeline =>
      selectedTextModelId == 'local_storyboard_template' &&
      selectedImageModelId == 'fixed_moon_courier_assets' &&
      selectedVideoModelId == 'local_ffmpeg_motion_comic' &&
      selectedVoiceModelId == 'windows_sapi_huihui';

  bool get usesHybridShotVideoPipeline =>
      selectedTextModelId == 'local_storyboard_template' &&
      selectedImageModelId == 'fixed_moon_courier_assets' &&
      selectedVideoModelId == 'wan2.7-i2v-2026-04-25' &&
      selectedVoiceModelId == 'windows_sapi_huihui';

  bool get usesRunnableComicPipeline => selectedPipeline?.canGenerate == true;

  bool get canGenerate =>
      isConfigured &&
      hasLoadedCatalog &&
      !isBusy &&
      usesRunnableComicPipeline &&
      selectedModels.every((model) => model.canGenerate);

  Future<void> initialize() async {
    if (repository == null) {
      _catalogLoaded = false;
      state = VideoLabLoadState.unconfigured;
      errorMessage = null;
      _notify();
      return;
    }
    state = VideoLabLoadState.loading;
    _catalogLoaded = false;
    errorMessage = null;
    _notify();
    try {
      final remote = await repository!.fetchCatalog();
      catalog = remote;
      selectedTextModelId = _preserveOrFirst(
        remote.textModels,
        selectedTextModelId,
      );
      selectedImageModelId = _preserveOrFirst(
        remote.imageModels,
        selectedImageModelId,
      );
      selectedVideoModelId = _preserveOrFirst(
        remote.videoModels,
        selectedVideoModelId,
      );
      selectedVoiceModelId = _preserveOrFirst(
        remote.voiceModels,
        selectedVoiceModelId,
      );
      _catalogLoaded = true;
      state = VideoLabLoadState.ready;
    } catch (error) {
      _catalogLoaded = false;
      state = VideoLabLoadState.failed;
      errorMessage = _messageFor(error);
    }
    _notify();
  }

  void selectTextModel(String id) =>
      _select(catalog.textModels, id, (value) => selectedTextModelId = value);

  void selectImageModel(String id) =>
      _select(catalog.imageModels, id, (value) => selectedImageModelId = value);

  void selectVideoModel(String id) =>
      _select(catalog.videoModels, id, (value) => selectedVideoModelId = value);

  void selectVoiceModel(String id) =>
      _select(catalog.voiceModels, id, (value) => selectedVoiceModelId = value);

  Future<void> generate(String story) async {
    final normalized = story.trim();
    final length = normalized.runes.length;
    if (length < 4 || length > 500) {
      state = VideoLabLoadState.failed;
      errorMessage = '故事设定需为 4–500 个字符';
      _notify();
      return;
    }
    if (!canGenerate) {
      state = VideoLabLoadState.failed;
      errorMessage = !isConfigured
          ? '请先配置 VIDEO_LAB_URL 并启动本地漫剧服务'
          : !hasLoadedCatalog
          ? '模型目录尚未成功加载，请检查本地漫剧服务后重试'
          : selectedModels.every((model) => model.canGenerate) &&
                selectedPipeline != null &&
                !usesRunnableComicPipeline
          ? '所选漫剧流水线的后端尚未就绪'
          : selectedModels.every((model) => model.canGenerate) &&
                selectedPipeline == null
          ? '所选模型不能组成当前服务支持的漫剧流水线'
          : '所选云模型的后端适配器待接入，当前不能提交生成任务';
      _notify();
      return;
    }
    _pollTimer?.cancel();
    state = VideoLabLoadState.submitting;
    errorMessage = null;
    job = null;
    _notify();
    try {
      job = await repository!.createJob(
        story: normalized,
        textModelId: selectedTextModelId,
        imageModelId: selectedImageModelId,
        videoModelId: selectedVideoModelId,
        voiceModelId: selectedVoiceModelId,
      );
      _applyJobState();
      if (job?.isTerminal != true) _schedulePoll();
    } catch (error) {
      state = VideoLabLoadState.failed;
      errorMessage = _messageFor(error);
      _notify();
    }
  }

  Future<void> refreshJob() async {
    final current = job;
    if (repository == null || current == null || current.isTerminal) return;
    try {
      job = await repository!.fetchJob(current.id);
      _applyJobState();
      if (job?.isTerminal != true) _schedulePoll();
    } catch (error) {
      _pollTimer?.cancel();
      state = VideoLabLoadState.failed;
      errorMessage = _messageFor(error);
      _notify();
    }
  }

  void _select(
    List<VideoLabModel> models,
    String id,
    ValueChanged<String> assign,
  ) {
    if (isBusy || !models.any((model) => model.id == id && model.canGenerate)) {
      return;
    }
    assign(id);
    errorMessage = null;
    _notify();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    state = VideoLabLoadState.polling;
    _notify();
    _pollTimer = Timer(pollInterval, refreshJob);
  }

  void _applyJobState() {
    final current = job;
    if (current == null) return;
    _pollTimer?.cancel();
    state = switch (current.status) {
      VideoLabJobStatus.queued ||
      VideoLabJobStatus.running => VideoLabLoadState.polling,
      VideoLabJobStatus.succeeded => VideoLabLoadState.succeeded,
      VideoLabJobStatus.failed => VideoLabLoadState.failed,
    };
    errorMessage = current.status == VideoLabJobStatus.failed
        ? current.errorMessage ?? '漫剧生成失败'
        : null;
    _notify();
  }

  static VideoLabModel _selected(List<VideoLabModel> models, String id) =>
      models.firstWhere((model) => model.id == id);

  static VideoLabModel _firstAvailable(List<VideoLabModel> models) => models
      .firstWhere((model) => model.canGenerate, orElse: () => models.first);

  static String _preserveOrFirst(List<VideoLabModel> models, String previous) =>
      models.any((model) => model.id == previous && model.canGenerate)
      ? previous
      : _firstAvailable(models).id;

  String _messageFor(Object error) => switch (error) {
    VideoLabApiException() => error.message,
    FormatException() => '漫剧服务契约错误：${error.message}',
    _ => '漫剧快制发生未知错误',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    repository?.close();
    super.dispose();
  }
}
