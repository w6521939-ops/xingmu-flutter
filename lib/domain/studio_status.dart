enum StudioStatus {
  loading,
  empty,
  error,
  pending,
  running,
  cooldown,
  succeeded,
  failed,
  canceled,
  skipped,
  paused,
  completed;

  String get wireName => name;

  static StudioStatus fromJson(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('任务状态不能为空');
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'queued') return StudioStatus.pending;
    for (final status in StudioStatus.values) {
      if (status.wireName == normalized) return status;
    }
    throw FormatException('未知任务状态：$value');
  }

  bool get isTerminal =>
      this == StudioStatus.succeeded ||
      this == StudioStatus.failed ||
      this == StudioStatus.canceled ||
      this == StudioStatus.skipped ||
      this == StudioStatus.completed;
}

enum GenerationTaskType {
  script,
  characterImage,
  sceneImage,
  propImage,
  storyboardFrame,
  shotVideo,
  voiceLine,
  episodeExport;

  String get wireName => switch (this) {
    GenerationTaskType.script => 'script',
    GenerationTaskType.characterImage => 'character_image',
    GenerationTaskType.sceneImage => 'scene_image',
    GenerationTaskType.propImage => 'prop_image',
    GenerationTaskType.storyboardFrame => 'storyboard_frame',
    GenerationTaskType.shotVideo => 'shot_video',
    GenerationTaskType.voiceLine => 'voice_line',
    GenerationTaskType.episodeExport => 'episode_export',
  };

  static GenerationTaskType fromJson(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('生成阶段不能为空');
    }
    final normalized = value.trim().toLowerCase();
    final apiStage = switch (normalized) {
      'character_images' => GenerationTaskType.characterImage,
      'scene_images' => GenerationTaskType.sceneImage,
      'prop_images' => GenerationTaskType.propImage,
      'storyboard_images' => GenerationTaskType.storyboardFrame,
      'shot_videos' => GenerationTaskType.shotVideo,
      'voice_assignment' || 'voice_lines' => GenerationTaskType.voiceLine,
      'episode_export' => GenerationTaskType.episodeExport,
      _ => null,
    };
    if (apiStage != null) return apiStage;
    return GenerationTaskType.values.firstWhere(
      (type) => type.wireName == normalized || type.name == normalized,
      orElse: () => throw FormatException('未知生成阶段：$value'),
    );
  }
}
