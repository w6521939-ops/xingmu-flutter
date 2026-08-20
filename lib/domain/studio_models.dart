import 'studio_status.dart';

const Object _notProvided = Object();

class ScriptSummary {
  const ScriptSummary({
    required this.id,
    required this.title,
    required this.logline,
    required this.styleBible,
    required this.episodeSynopsis,
    this.revision = 0,
  });

  final String id;
  final String title;
  final String logline;
  final String styleBible;
  final String episodeSynopsis;
  final int revision;

  ScriptSummary copyWith({
    String? id,
    String? title,
    String? logline,
    String? styleBible,
    String? episodeSynopsis,
    int? revision,
  }) => ScriptSummary(
    id: id ?? this.id,
    title: title ?? this.title,
    logline: logline ?? this.logline,
    styleBible: styleBible ?? this.styleBible,
    episodeSynopsis: episodeSynopsis ?? this.episodeSynopsis,
    revision: revision ?? this.revision,
  );

  factory ScriptSummary.fromJson(Map<String, Object?> json) => ScriptSummary(
    id: _string(json, 'id'),
    title: _string(json, 'title'),
    logline: _string(json, 'logline'),
    styleBible: _string(json, 'style_bible', fallbackKey: 'styleBible'),
    episodeSynopsis: _string(
      json,
      'episode_synopsis',
      fallbackKey: 'episodeSynopsis',
    ),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'logline': logline,
    'style_bible': styleBible,
    'episode_synopsis': episodeSynopsis,
    'revision': revision,
  };
}

class CharacterAsset {
  const CharacterAsset({
    required this.id,
    required this.name,
    required this.description,
    required this.visualLock,
    this.imageUrl,
    this.status = StudioStatus.pending,
    this.revision = 0,
  });

  final String id;
  final String name;
  final String description;
  final String visualLock;
  final String? imageUrl;
  final StudioStatus status;
  final int revision;

  CharacterAsset copyWith({
    String? id,
    String? name,
    String? description,
    String? visualLock,
    Object? imageUrl = _notProvided,
    StudioStatus? status,
    int? revision,
  }) => CharacterAsset(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    visualLock: visualLock ?? this.visualLock,
    imageUrl: identical(imageUrl, _notProvided)
        ? this.imageUrl
        : imageUrl as String?,
    status: status ?? this.status,
    revision: revision ?? this.revision,
  );

  factory CharacterAsset.fromJson(Map<String, Object?> json) => CharacterAsset(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    description: _string(json, 'description'),
    visualLock: _string(json, 'visual_lock', fallbackKey: 'visualLock'),
    imageUrl: _nullableString(json['image_url'] ?? json['imageUrl']),
    status: StudioStatus.fromJson(json['status']),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'visual_lock': visualLock,
    'image_url': imageUrl,
    'status': status.wireName,
    'revision': revision,
  };
}

class SceneAsset {
  const SceneAsset({
    required this.id,
    required this.name,
    required this.description,
    required this.visualLock,
    this.imageUrl,
    this.status = StudioStatus.pending,
    this.revision = 0,
  });

  final String id;
  final String name;
  final String description;
  final String visualLock;
  final String? imageUrl;
  final StudioStatus status;
  final int revision;

  SceneAsset copyWith({
    String? id,
    String? name,
    String? description,
    String? visualLock,
    Object? imageUrl = _notProvided,
    StudioStatus? status,
    int? revision,
  }) => SceneAsset(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    visualLock: visualLock ?? this.visualLock,
    imageUrl: identical(imageUrl, _notProvided)
        ? this.imageUrl
        : imageUrl as String?,
    status: status ?? this.status,
    revision: revision ?? this.revision,
  );

  factory SceneAsset.fromJson(Map<String, Object?> json) => SceneAsset(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    description: _string(json, 'description'),
    visualLock: _string(json, 'visual_lock', fallbackKey: 'visualLock'),
    imageUrl: _nullableString(json['image_url'] ?? json['imageUrl']),
    status: StudioStatus.fromJson(json['status']),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'visual_lock': visualLock,
    'image_url': imageUrl,
    'status': status.wireName,
    'revision': revision,
  };
}

class PropAsset {
  const PropAsset({
    required this.id,
    required this.name,
    required this.description,
    required this.visualLock,
    this.imageUrl,
    this.status = StudioStatus.pending,
    this.revision = 0,
  });

  final String id;
  final String name;
  final String description;
  final String visualLock;
  final String? imageUrl;
  final StudioStatus status;
  final int revision;

  PropAsset copyWith({
    String? id,
    String? name,
    String? description,
    String? visualLock,
    Object? imageUrl = _notProvided,
    StudioStatus? status,
    int? revision,
  }) => PropAsset(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    visualLock: visualLock ?? this.visualLock,
    imageUrl: identical(imageUrl, _notProvided)
        ? this.imageUrl
        : imageUrl as String?,
    status: status ?? this.status,
    revision: revision ?? this.revision,
  );

  factory PropAsset.fromJson(Map<String, Object?> json) => PropAsset(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    description: _string(json, 'description'),
    visualLock: _string(json, 'visual_lock', fallbackKey: 'visualLock'),
    imageUrl: _nullableString(json['image_url'] ?? json['imageUrl']),
    status: StudioStatus.fromJson(json['status']),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'visual_lock': visualLock,
    'image_url': imageUrl,
    'status': status.wireName,
    'revision': revision,
  };
}

class Shot {
  const Shot({
    required this.id,
    required this.order,
    required this.title,
    required this.prompt,
    required this.durationSeconds,
    this.characterIds = const [],
    this.sceneId,
    this.propIds = const [],
    this.firstFrameUrl,
    this.lastFrameUrl,
    this.videoUrl,
    this.status = StudioStatus.pending,
    this.revision = 0,
  });

  final String id;
  final int order;
  final String title;
  final String prompt;
  final double durationSeconds;
  final List<String> characterIds;
  final String? sceneId;
  final List<String> propIds;
  final String? firstFrameUrl;
  final String? lastFrameUrl;
  final String? videoUrl;
  final StudioStatus status;
  final int revision;

  bool get hasStoryboard => firstFrameUrl != null && lastFrameUrl != null;

  Shot copyWith({
    String? id,
    int? order,
    String? title,
    String? prompt,
    double? durationSeconds,
    List<String>? characterIds,
    Object? sceneId = _notProvided,
    List<String>? propIds,
    Object? firstFrameUrl = _notProvided,
    Object? lastFrameUrl = _notProvided,
    Object? videoUrl = _notProvided,
    StudioStatus? status,
    int? revision,
  }) => Shot(
    id: id ?? this.id,
    order: order ?? this.order,
    title: title ?? this.title,
    prompt: prompt ?? this.prompt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    characterIds: List.unmodifiable(characterIds ?? this.characterIds),
    sceneId: identical(sceneId, _notProvided)
        ? this.sceneId
        : sceneId as String?,
    propIds: List.unmodifiable(propIds ?? this.propIds),
    firstFrameUrl: identical(firstFrameUrl, _notProvided)
        ? this.firstFrameUrl
        : firstFrameUrl as String?,
    lastFrameUrl: identical(lastFrameUrl, _notProvided)
        ? this.lastFrameUrl
        : lastFrameUrl as String?,
    videoUrl: identical(videoUrl, _notProvided)
        ? this.videoUrl
        : videoUrl as String?,
    status: status ?? this.status,
    revision: revision ?? this.revision,
  );

  factory Shot.fromJson(Map<String, Object?> json) => Shot(
    id: _string(json, 'id'),
    order: _integer(json['order']),
    title: _string(json, 'title'),
    prompt: _string(json, 'prompt'),
    durationSeconds: _decimal(
      json['duration_seconds'] ?? json['durationSeconds'],
    ),
    characterIds: _stringList(json['character_ids'] ?? json['characterIds']),
    sceneId: _nullableString(json['scene_id'] ?? json['sceneId']),
    propIds: _stringList(json['prop_ids'] ?? json['propIds']),
    firstFrameUrl: _nullableString(
      json['first_frame_url'] ?? json['firstFrameUrl'],
    ),
    lastFrameUrl: _nullableString(
      json['last_frame_url'] ?? json['lastFrameUrl'],
    ),
    videoUrl: _nullableString(json['video_url'] ?? json['videoUrl']),
    status: StudioStatus.fromJson(json['status']),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'order': order,
    'title': title,
    'prompt': prompt,
    'duration_seconds': durationSeconds,
    'character_ids': characterIds,
    'scene_id': sceneId,
    'prop_ids': propIds,
    'first_frame_url': firstFrameUrl,
    'last_frame_url': lastFrameUrl,
    'video_url': videoUrl,
    'status': status.wireName,
    'revision': revision,
  };
}

class VoiceLine {
  const VoiceLine({
    required this.id,
    required this.shotId,
    required this.speaker,
    required this.text,
    required this.voiceName,
    this.characterId,
    this.audioUrl,
    this.status = StudioStatus.pending,
    this.revision = 0,
  });

  final String id;
  final String shotId;
  final String speaker;
  final String text;
  final String voiceName;
  final String? characterId;
  final String? audioUrl;
  final StudioStatus status;
  final int revision;

  VoiceLine copyWith({
    String? id,
    String? shotId,
    String? speaker,
    String? text,
    String? voiceName,
    Object? characterId = _notProvided,
    Object? audioUrl = _notProvided,
    StudioStatus? status,
    int? revision,
  }) => VoiceLine(
    id: id ?? this.id,
    shotId: shotId ?? this.shotId,
    speaker: speaker ?? this.speaker,
    text: text ?? this.text,
    voiceName: voiceName ?? this.voiceName,
    characterId: identical(characterId, _notProvided)
        ? this.characterId
        : characterId as String?,
    audioUrl: identical(audioUrl, _notProvided)
        ? this.audioUrl
        : audioUrl as String?,
    status: status ?? this.status,
    revision: revision ?? this.revision,
  );

  factory VoiceLine.fromJson(Map<String, Object?> json) => VoiceLine(
    id: _string(json, 'id'),
    shotId: _string(json, 'shot_id', fallbackKey: 'shotId'),
    speaker: _string(json, 'speaker'),
    text: _string(json, 'text'),
    voiceName: _string(json, 'voice_name', fallbackKey: 'voiceName'),
    characterId: _nullableString(json['character_id'] ?? json['characterId']),
    audioUrl: _nullableString(json['audio_url'] ?? json['audioUrl']),
    status: StudioStatus.fromJson(json['status']),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'shot_id': shotId,
    'speaker': speaker,
    'text': text,
    'voice_name': voiceName,
    'character_id': characterId,
    'audio_url': audioUrl,
    'status': status.wireName,
    'revision': revision,
  };
}

class GenerationTask {
  const GenerationTask({
    required this.id,
    required this.type,
    required this.sequence,
    required this.label,
    required this.targetId,
    required this.inputHash,
    this.status = StudioStatus.pending,
    this.attempt = 0,
    this.errorMessage,
    this.resultUrl,
    this.outputAssetIds = const [],
    this.progressPercent = 0,
    this.etag,
    this.revision = 0,
  });

  final String id;
  final GenerationTaskType type;
  final int sequence;
  final String label;
  final String targetId;
  final String inputHash;
  final StudioStatus status;
  final int attempt;
  final String? errorMessage;
  final String? resultUrl;
  final List<String> outputAssetIds;
  final int progressPercent;
  final String? etag;
  final int revision;

  GenerationTask copyWith({
    String? id,
    GenerationTaskType? type,
    int? sequence,
    String? label,
    String? targetId,
    String? inputHash,
    StudioStatus? status,
    int? attempt,
    Object? errorMessage = _notProvided,
    Object? resultUrl = _notProvided,
    List<String>? outputAssetIds,
    int? progressPercent,
    Object? etag = _notProvided,
    int? revision,
  }) => GenerationTask(
    id: id ?? this.id,
    type: type ?? this.type,
    sequence: sequence ?? this.sequence,
    label: label ?? this.label,
    targetId: targetId ?? this.targetId,
    inputHash: inputHash ?? this.inputHash,
    status: status ?? this.status,
    attempt: attempt ?? this.attempt,
    errorMessage: identical(errorMessage, _notProvided)
        ? this.errorMessage
        : errorMessage as String?,
    resultUrl: identical(resultUrl, _notProvided)
        ? this.resultUrl
        : resultUrl as String?,
    outputAssetIds: List.unmodifiable(outputAssetIds ?? this.outputAssetIds),
    progressPercent: progressPercent ?? this.progressPercent,
    etag: identical(etag, _notProvided) ? this.etag : etag as String?,
    revision: revision ?? this.revision,
  );

  factory GenerationTask.fromJson(Map<String, Object?> json) => GenerationTask(
    id: _string(json, 'id'),
    type: GenerationTaskType.fromJson(json['stage'] ?? json['type']),
    sequence: _integer(json['sequence']),
    label:
        _nullableString(json['label']) ??
        _taskLabel(GenerationTaskType.fromJson(json['stage'] ?? json['type'])),
    targetId:
        _nullableString(
          json['shotId'] ?? json['target_id'] ?? json['targetId'],
        ) ??
        _string(json, 'id'),
    inputHash: _string(json, 'input_hash', fallbackKey: 'inputHash'),
    status: StudioStatus.fromJson(json['status']),
    attempt: _integer(json['attempt']),
    errorMessage:
        _nullableString(json['error_message'] ?? json['errorMessage']) ??
        _nullableString(_nullableMap(json['error'])?['message']),
    resultUrl: _nullableString(json['result_url'] ?? json['resultUrl']),
    outputAssetIds: _stringList(
      json['outputAssetIds'] ?? json['output_asset_ids'],
    ),
    progressPercent: _integer(json['progress']),
    etag: _nullableString(json['etag']),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'stage': type.wireName,
    'sequence': sequence,
    'label': label,
    'target_id': targetId,
    'input_hash': inputHash,
    'status': status.wireName,
    'attempt': attempt,
    'error_message': errorMessage,
    'result_url': resultUrl,
    'outputAssetIds': outputAssetIds,
    'progress': progressPercent,
    'revision': revision,
  };
}

class GenerationRun {
  const GenerationRun({
    required this.id,
    required this.projectId,
    required this.status,
    required this.onlyMissing,
    required this.tasks,
    required this.createdAt,
    required this.updatedAt,
    this.planId = '',
    this.remoteProgressPercent = 0,
    this.completedJobs = 0,
    this.totalJobs = 0,
    this.currentStage,
    this.etag,
    this.revision = 0,
  });

  final String id;
  final String projectId;
  final StudioStatus status;
  final bool onlyMissing;
  final List<GenerationTask> tasks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String planId;
  final int remoteProgressPercent;
  final int completedJobs;
  final int totalJobs;
  final String? currentStage;
  final String? etag;
  final int revision;

  int get completedTaskCount => tasks
      .where(
        (task) =>
            task.status == StudioStatus.succeeded ||
            task.status == StudioStatus.skipped ||
            task.status == StudioStatus.completed,
      )
      .length;

  int get canceledTaskCount =>
      tasks.where((task) => task.status == StudioStatus.canceled).length;

  int get terminalTaskCount =>
      tasks.where((task) => task.status.isTerminal).length;

  double get progress => tasks.isEmpty
      ? remoteProgressPercent.clamp(0, 100) / 100
      : terminalTaskCount / tasks.length;

  GenerationRun copyWith({
    String? id,
    String? projectId,
    StudioStatus? status,
    bool? onlyMissing,
    List<GenerationTask>? tasks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? planId,
    int? remoteProgressPercent,
    int? completedJobs,
    int? totalJobs,
    Object? currentStage = _notProvided,
    Object? etag = _notProvided,
    int? revision,
  }) => GenerationRun(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    status: status ?? this.status,
    onlyMissing: onlyMissing ?? this.onlyMissing,
    tasks: List.unmodifiable(tasks ?? this.tasks),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    planId: planId ?? this.planId,
    remoteProgressPercent: remoteProgressPercent ?? this.remoteProgressPercent,
    completedJobs: completedJobs ?? this.completedJobs,
    totalJobs: totalJobs ?? this.totalJobs,
    currentStage: identical(currentStage, _notProvided)
        ? this.currentStage
        : currentStage as String?,
    etag: identical(etag, _notProvided) ? this.etag : etag as String?,
    revision: revision ?? this.revision,
  );

  factory GenerationRun.fromJson(Map<String, Object?> json) => GenerationRun(
    id: _string(json, 'id'),
    projectId: _string(json, 'project_id', fallbackKey: 'projectId'),
    planId: _string(json, 'planId', fallbackKey: 'plan_id'),
    status: StudioStatus.fromJson(json['status']),
    onlyMissing: _boolean(
      json['only_missing'] ?? json['onlyMissing'],
      fallback: true,
    ),
    tasks: _mapList(json['tasks']).map(GenerationTask.fromJson).toList(),
    remoteProgressPercent: _integer(json['progress']),
    completedJobs: _integer(json['completedJobs'] ?? json['completed_jobs']),
    totalJobs: _integer(json['totalJobs'] ?? json['total_jobs']),
    currentStage: _nullableString(
      json['currentStage'] ?? json['current_stage'],
    ),
    etag: _nullableString(json['etag']),
    createdAt: _dateTime(json['created_at'] ?? json['createdAt']),
    updatedAt: _dateTime(json['updated_at'] ?? json['updatedAt']),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'planId': planId,
    'status': status.wireName,
    'onlyMissing': onlyMissing,
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'progress': (progress * 100).round(),
    'completedJobs': completedJobs,
    'totalJobs': totalJobs,
    'currentStage': currentStage,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
  };
}

class StudioExport {
  const StudioExport({
    required this.id,
    required this.runId,
    required this.status,
    required this.createdAt,
    this.videoUrl,
    this.downloadUrl,
    this.previewUrl,
    this.ready = false,
    this.assetId,
    this.progressPercent = 0,
    this.updatedAt,
    this.durationSeconds = 0,
    this.revision = 0,
  });

  final String id;
  final String runId;
  final StudioStatus status;
  final DateTime createdAt;
  final String? videoUrl;
  final String? downloadUrl;
  final String? previewUrl;
  final bool ready;
  final String? assetId;
  final int progressPercent;
  final DateTime? updatedAt;
  final double durationSeconds;
  final int revision;

  StudioExport copyWith({
    String? id,
    String? runId,
    StudioStatus? status,
    DateTime? createdAt,
    Object? videoUrl = _notProvided,
    Object? downloadUrl = _notProvided,
    Object? previewUrl = _notProvided,
    bool? ready,
    Object? assetId = _notProvided,
    int? progressPercent,
    Object? updatedAt = _notProvided,
    double? durationSeconds,
    int? revision,
  }) => StudioExport(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    videoUrl: identical(videoUrl, _notProvided)
        ? this.videoUrl
        : videoUrl as String?,
    downloadUrl: identical(downloadUrl, _notProvided)
        ? this.downloadUrl
        : downloadUrl as String?,
    previewUrl: identical(previewUrl, _notProvided)
        ? this.previewUrl
        : previewUrl as String?,
    ready: ready ?? this.ready,
    assetId: identical(assetId, _notProvided)
        ? this.assetId
        : assetId as String?,
    progressPercent: progressPercent ?? this.progressPercent,
    updatedAt: identical(updatedAt, _notProvided)
        ? this.updatedAt
        : updatedAt as DateTime?,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    revision: revision ?? this.revision,
  );

  factory StudioExport.fromJson(Map<String, Object?> json) {
    final status = StudioStatus.fromJson(json['status']);
    final downloadUrl = _nullableString(
      json['download_url'] ?? json['downloadUrl'],
    );
    final previewUrl = _nullableString(
      json['preview_url'] ?? json['previewUrl'],
    );
    final videoUrl =
        _nullableString(json['video_url'] ?? json['videoUrl']) ??
        previewUrl ??
        downloadUrl;
    return StudioExport(
      id: _string(json, 'id'),
      runId: _string(json, 'run_id', fallbackKey: 'runId'),
      status: status,
      createdAt: _dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _nullableDateTime(json['updated_at'] ?? json['updatedAt']),
      videoUrl: videoUrl,
      downloadUrl: downloadUrl,
      previewUrl: previewUrl,
      ready: _boolean(
        json['ready'],
        fallback:
            status == StudioStatus.succeeded ||
            status == StudioStatus.completed,
      ),
      assetId: _nullableString(json['asset_id'] ?? json['assetId']),
      progressPercent: _integer(
        json['progress'] ?? json['progress_percent'] ?? json['progressPercent'],
      ),
      durationSeconds: _decimal(
        json['duration_seconds'] ?? json['durationSeconds'],
      ),
      revision: _integer(json['revision']),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'run_id': runId,
    'status': status.wireName,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
    'video_url': videoUrl,
    'download_url': downloadUrl,
    'preview_url': previewUrl,
    'ready': ready,
    'asset_id': assetId,
    'progress': progressPercent,
    'duration_seconds': durationSeconds,
    'revision': revision,
  };
}

class StudioProject {
  const StudioProject({
    required this.id,
    required this.title,
    required this.theme,
    required this.createdAt,
    required this.updatedAt,
    this.script,
    this.characters = const [],
    this.scenes = const [],
    this.props = const [],
    this.shots = const [],
    this.voiceLines = const [],
    this.currentRun,
    this.exports = const [],
    this.aspectRatio = '9:16',
    this.coverAssetId,
    this.latestScriptJobId,
    this.latestScriptJobStatus,
    this.activeRunId,
    this.latestExportId,
    this.etag,
    this.revision = 0,
  });

  final String id;
  final String title;
  final String theme;
  final ScriptSummary? script;
  final List<CharacterAsset> characters;
  final List<SceneAsset> scenes;
  final List<PropAsset> props;
  final List<Shot> shots;
  final List<VoiceLine> voiceLines;
  final GenerationRun? currentRun;
  final List<StudioExport> exports;
  final String aspectRatio;
  final String? coverAssetId;
  final String? latestScriptJobId;
  final StudioStatus? latestScriptJobStatus;
  final String? activeRunId;
  final String? latestExportId;
  final String? etag;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  StudioProject copyWith({
    String? id,
    String? title,
    String? theme,
    Object? script = _notProvided,
    List<CharacterAsset>? characters,
    List<SceneAsset>? scenes,
    List<PropAsset>? props,
    List<Shot>? shots,
    List<VoiceLine>? voiceLines,
    Object? currentRun = _notProvided,
    List<StudioExport>? exports,
    String? aspectRatio,
    Object? coverAssetId = _notProvided,
    Object? latestScriptJobId = _notProvided,
    Object? latestScriptJobStatus = _notProvided,
    Object? activeRunId = _notProvided,
    Object? latestExportId = _notProvided,
    Object? etag = _notProvided,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? revision,
  }) => StudioProject(
    id: id ?? this.id,
    title: title ?? this.title,
    theme: theme ?? this.theme,
    script: identical(script, _notProvided)
        ? this.script
        : script as ScriptSummary?,
    characters: List.unmodifiable(characters ?? this.characters),
    scenes: List.unmodifiable(scenes ?? this.scenes),
    props: List.unmodifiable(props ?? this.props),
    shots: List.unmodifiable(shots ?? this.shots),
    voiceLines: List.unmodifiable(voiceLines ?? this.voiceLines),
    currentRun: identical(currentRun, _notProvided)
        ? this.currentRun
        : currentRun as GenerationRun?,
    exports: List.unmodifiable(exports ?? this.exports),
    aspectRatio: aspectRatio ?? this.aspectRatio,
    coverAssetId: identical(coverAssetId, _notProvided)
        ? this.coverAssetId
        : coverAssetId as String?,
    latestScriptJobId: identical(latestScriptJobId, _notProvided)
        ? this.latestScriptJobId
        : latestScriptJobId as String?,
    latestScriptJobStatus: identical(latestScriptJobStatus, _notProvided)
        ? this.latestScriptJobStatus
        : latestScriptJobStatus as StudioStatus?,
    activeRunId: identical(activeRunId, _notProvided)
        ? this.activeRunId
        : activeRunId as String?,
    latestExportId: identical(latestExportId, _notProvided)
        ? this.latestExportId
        : latestExportId as String?,
    etag: identical(etag, _notProvided) ? this.etag : etag as String?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revision: revision ?? this.revision,
  );

  factory StudioProject.fromJson(Map<String, Object?> json) => StudioProject(
    id: _string(json, 'id'),
    title: _nullableString(json['name']) ?? _string(json, 'title'),
    theme: _nullableString(json['description']) ?? _string(json, 'theme'),
    script: _scriptSummary(json['script']),
    characters: _mapList(
      json['characters'],
    ).map(CharacterAsset.fromJson).toList(),
    scenes: _mapList(json['scenes']).map(SceneAsset.fromJson).toList(),
    props: _mapList(json['props']).map(PropAsset.fromJson).toList(),
    shots: _mapList(json['shots']).map(Shot.fromJson).toList(),
    voiceLines: _mapList(
      json['voice_lines'] ?? json['voiceLines'],
    ).map(VoiceLine.fromJson).toList(),
    currentRun: _generationRun(json['current_run'] ?? json['currentRun']),
    exports: _mapList(json['exports']).map(StudioExport.fromJson).toList(),
    aspectRatio:
        _nullableString(json['aspectRatio'] ?? json['aspect_ratio']) ?? '9:16',
    coverAssetId: _nullableString(
      json['coverAssetId'] ?? json['cover_asset_id'],
    ),
    latestScriptJobId: _nullableString(
      json['latestScriptJobId'] ?? json['latest_script_job_id'],
    ),
    latestScriptJobStatus: _nullableStudioStatus(
      json['latestScriptJobStatus'] ?? json['latest_script_job_status'],
    ),
    activeRunId: _nullableString(json['activeRunId'] ?? json['active_run_id']),
    latestExportId: _nullableString(
      json['latestExportId'] ?? json['latest_export_id'],
    ),
    etag: _nullableString(json['etag']),
    createdAt: _dateTime(json['created_at'] ?? json['createdAt']),
    updatedAt: _dateTime(json['updated_at'] ?? json['updatedAt']),
    revision: _integer(json['revision']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': title,
    'description': theme,
    'aspectRatio': aspectRatio,
    'coverAssetId': coverAssetId,
    'latestScriptJobId': latestScriptJobId,
    'latestScriptJobStatus': latestScriptJobStatus?.wireName,
    'activeRunId': activeRunId,
    'latestExportId': latestExportId,
    'script': script?.toJson(),
    'characters': characters.map((asset) => asset.toJson()).toList(),
    'scenes': scenes.map((asset) => asset.toJson()).toList(),
    'props': props.map((asset) => asset.toJson()).toList(),
    'shots': shots.map((shot) => shot.toJson()).toList(),
    'voiceLines': voiceLines.map((line) => line.toJson()).toList(),
    'currentRun': currentRun?.toJson(),
    'exports': exports.map((value) => value.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
  };
}

String _string(Map<String, Object?> json, String key, {String? fallbackKey}) =>
    _nullableString(
      json[key] ?? (fallbackKey == null ? null : json[fallbackKey]),
    ) ??
    '';

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolean(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (value?.toString().toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => fallback,
  };
}

DateTime _dateTime(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

DateTime? _nullableDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}

StudioStatus? _nullableStudioStatus(Object? value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return StudioStatus.fromJson(value);
}

List<String> _stringList(Object? value) => value is List
    ? List.unmodifiable(value.map((item) => item.toString()))
    : const [];

List<Map<String, Object?>> _mapList(Object? value) => value is List
    ? value.map(_nullableMap).whereType<Map<String, Object?>>().toList()
    : const [];

Map<String, Object?>? _nullableMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, item) => MapEntry(key.toString(), item));
}

ScriptSummary? _scriptSummary(Object? value) {
  final map = _nullableMap(value);
  return map == null ? null : ScriptSummary.fromJson(map);
}

GenerationRun? _generationRun(Object? value) {
  final map = _nullableMap(value);
  return map == null ? null : GenerationRun.fromJson(map);
}

String _taskLabel(GenerationTaskType type) => switch (type) {
  GenerationTaskType.script => '剧本生成',
  GenerationTaskType.characterImage => '角色图生成',
  GenerationTaskType.sceneImage => '场景图生成',
  GenerationTaskType.propImage => '道具图生成',
  GenerationTaskType.storyboardFrame => '分镜图生成',
  GenerationTaskType.shotVideo => '镜头视频生成',
  GenerationTaskType.voiceLine => '配音生成',
  GenerationTaskType.episodeExport => '剧集导出',
};
