import '../../domain/domain.dart';
import '../models/studio_view_data.dart';

abstract final class StudioPresentationMapper {
  static List<ProjectCardData> projects(
    Iterable<StudioProject> source, {
    bool demoMode = false,
  }) => source
      .map((item) => project(item, demoMode: demoMode))
      .toList(growable: false);

  static ProjectCardData project(
    StudioProject project, {
    bool demoMode = false,
  }) {
    final run = project.currentRun;
    final latestExport = _latestExport(project);
    final runCanOwnCompletedExport =
        run == null ||
        run.status == StudioStatus.succeeded ||
        run.status == StudioStatus.completed;
    final completedExport =
        latestExport?.ready == true &&
        runCanOwnCompletedExport &&
        (run == null || latestExport!.runId == run.id);
    final remoteProgressPercent = run?.remoteProgressPercent ?? 0;
    final useDemoTaskProgress =
        demoMode && run != null && remoteProgressPercent <= 0;
    final progress = remoteProgressPercent > 0
        ? remoteProgressPercent.clamp(0, 100) / 100
        : useDemoTaskProgress
        ? run.progress
        : completedExport
        ? 1.0
        : null;
    final stage = completedExport
        ? '成片已完成'
        : run == null
        ? project.script == null
              ? '等待生成剧本'
              : '剧本已确认'
        : _runStage(run);
    return ProjectCardData(
      id: project.id,
      title: project.title,
      summary: project.script?.logline ?? _shorten(project.theme, 44),
      stageLabel: stage,
      updatedLabel: _dateLabel(project.updatedAt),
      progress: progress,
      progressLabel: demoMode
          ? useDemoTaskProgress
                ? '演示任务终态比例'
                : '演示项目进度'
          : completedExport && remoteProgressPercent <= 0
          ? '服务端成片状态'
          : '服务端生成进度',
      status: completedExport
          ? GenerationStatus.completed
          : _generationStatus(run?.status ?? StudioStatus.pending),
    );
  }

  static List<ScriptBeatData> scriptBeats(StudioProject? project) {
    if (project == null) return const [];
    if (project.shots.isEmpty) {
      final script = project.script;
      if (script == null) return const [];
      return [
        ScriptBeatData(
          number: 1,
          title: script.title,
          durationLabel: '待拆分',
          summary: script.episodeSynopsis,
          shotCount: 0,
        ),
      ];
    }
    var elapsed = 0.0;
    return project.shots
        .map((shot) {
          final start = elapsed;
          elapsed += shot.durationSeconds;
          return ScriptBeatData(
            number: shot.order,
            title: shot.title,
            durationLabel: '${start.round()}–${elapsed.round()} 秒',
            summary: shot.prompt,
            shotCount: 1,
          );
        })
        .toList(growable: false);
  }

  static List<VisualAssetData> visualAssets(StudioProject? project) {
    if (project == null) return const [];
    final output = <VisualAssetData>[];
    for (final (index, asset) in project.characters.indexed) {
      output.add(
        VisualAssetData(
          id: asset.id,
          type: VisualAssetType.character,
          name: asset.name,
          description: _assetDescription(asset.description, asset.visualLock),
          status: _generationStatus(asset.status),
          colorValue: _palette[index % _palette.length],
          locked: null,
        ),
      );
    }
    for (final (index, asset) in project.scenes.indexed) {
      output.add(
        VisualAssetData(
          id: asset.id,
          type: VisualAssetType.scene,
          name: asset.name,
          description: _assetDescription(asset.description, asset.visualLock),
          status: _generationStatus(asset.status),
          colorValue: _scenePalette[index % _scenePalette.length],
          locked: null,
        ),
      );
    }
    for (final (index, asset) in project.props.indexed) {
      output.add(
        VisualAssetData(
          id: asset.id,
          type: VisualAssetType.prop,
          name: asset.name,
          description: _assetDescription(asset.description, asset.visualLock),
          status: _generationStatus(asset.status),
          colorValue: _propPalette[index % _propPalette.length],
          locked: null,
        ),
      );
    }
    return List.unmodifiable(output);
  }

  static List<ShotData> shots(StudioProject? project) {
    if (project == null) return const [];
    final tasks = project.currentRun?.tasks ?? const <GenerationTask>[];
    return project.shots
        .map((shot) {
          GenerationTask? task;
          for (final item in tasks) {
            if (item.targetId == shot.id &&
                item.type == GenerationTaskType.shotVideo) {
              task = item;
              break;
            }
          }
          final referenceLabels = <String>[
            for (final id in shot.characterIds)
              for (final asset in project.characters)
                if (asset.id == id) asset.name,
            for (final asset in project.scenes)
              if (asset.id == shot.sceneId) asset.name,
            for (final id in shot.propIds)
              for (final asset in project.props)
                if (asset.id == id) asset.name,
          ];
          final status = shot.videoUrl != null
              ? GenerationStatus.completed
              : _generationStatus(task?.status ?? shot.status);
          return ShotData(
            id: shot.id,
            sequence: shot.order,
            title: shot.title,
            durationLabel: '${shot.durationSeconds.toStringAsFixed(1)} 秒',
            prompt: shot.prompt,
            camera: '服务端未返回运镜参数',
            referenceLabels: referenceLabels,
            status: status,
            progress: status == GenerationStatus.completed
                ? 1
                : (task?.progressPercent ?? 0).clamp(0, 100) / 100,
          );
        })
        .toList(growable: false);
  }

  static List<VoiceCastData> voiceCast(StudioProject? project) {
    if (project == null) return const [];
    final unique = <String, VoiceLine>{};
    for (final line in project.voiceLines) {
      unique.putIfAbsent(line.speaker, () => line);
    }
    return unique.values.indexed
        .map((entry) {
          final line = entry.$2;
          return VoiceCastData(
            id: line.characterId ?? line.speaker,
            character: line.speaker,
            voiceName: line.voiceName,
            description: line.characterId == null
                ? '角色关联状态未返回 · 语速参数未返回'
                : '已返回角色关联标识 · 语速参数未返回',
            sampleText: line.text,
            colorValue: _palette[entry.$1 % _palette.length],
          );
        })
        .toList(growable: false);
  }

  static List<VoiceLineData> voiceLines(StudioProject? project) {
    if (project == null) return const [];
    final taskByTarget = <String, GenerationTask>{
      for (final task in project.currentRun?.tasks ?? const <GenerationTask>[])
        if (task.type == GenerationTaskType.voiceLine) task.targetId: task,
    };
    return project.voiceLines
        .map((line) {
          final status = line.audioUrl != null
              ? GenerationStatus.completed
              : _generationStatus(taskByTarget[line.id]?.status ?? line.status);
          return VoiceLineData(
            id: line.id,
            speaker: line.speaker,
            content: line.text,
            durationLabel: line.audioUrl == null ? '音频未返回' : '音频已返回',
            status: status,
          );
        })
        .toList(growable: false);
  }

  static List<TaskItemData> tasks(StudioProject? project) {
    final run = project?.currentRun;
    if (run == null) return const [];
    return run.tasks
        .map((task) {
          final status = _generationStatus(task.status);
          final detailParts = <String>[
            '第 ${task.sequence + 1} 步',
            '尝试 ${task.attempt} 次',
            if (task.inputHash.trim().isNotEmpty) '输入快照 ${task.inputHash}',
          ];
          return TaskItemData(
            id: task.id,
            title: task.label,
            detail: detailParts.join(' · '),
            stageLabel: _taskTypeLabel(task.type),
            status: status,
            progress: status == GenerationStatus.completed
                ? 1
                : task.progressPercent.clamp(0, 100) / 100,
            updatedLabel: _dateLabel(run.updatedAt),
            failureMessage: task.errorMessage,
            resultDestination: _taskDestination(task.type),
          );
        })
        .toList(growable: false);
  }

  static ResultData result(StudioProject? project) {
    if (project == null) {
      return const ResultData(
        title: '未选择项目',
        summary: '请先创建或打开一个漫剧项目。',
        durationLabel: '服务端未返回',
        resolutionLabel: '服务端未返回',
        sizeLabel: '服务端未返回',
        generatedAtLabel: '服务端未返回',
        ready: false,
      );
    }
    var export = _latestExport(project);
    final run = project.currentRun;
    if (run != null && export?.runId != run.id) {
      export = null;
    }
    final ready =
        export?.ready == true &&
        (run == null ||
            run.status == StudioStatus.succeeded ||
            run.status == StudioStatus.completed);
    final duration = export?.durationSeconds ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration.round() % 60;
    return ResultData(
      title: project.title,
      summary: project.script?.episodeSynopsis ?? project.theme,
      durationLabel: duration > 0
          ? '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
          : '服务端未返回',
      resolutionLabel: '服务端未返回',
      sizeLabel: '服务端未返回',
      generatedAtLabel: export == null
          ? '服务端未返回'
          : _dateLabel(export.createdAt),
      ready: ready,
    );
  }

  static StudioExport? _latestExport(StudioProject project) {
    final latestExportId = project.latestExportId;
    if (latestExportId == null) return null;
    for (final export in project.exports) {
      if (export.id == latestExportId) return export;
    }
    return null;
  }

  static StudioDestination _taskDestination(GenerationTaskType type) =>
      switch (type) {
        GenerationTaskType.script => StudioDestination.script,
        GenerationTaskType.characterImage ||
        GenerationTaskType.sceneImage ||
        GenerationTaskType.propImage => StudioDestination.assets,
        GenerationTaskType.storyboardFrame ||
        GenerationTaskType.shotVideo => StudioDestination.shots,
        GenerationTaskType.voiceLine => StudioDestination.voice,
        GenerationTaskType.episodeExport => StudioDestination.result,
      };

  static GenerationStatus _generationStatus(StudioStatus status) =>
      switch (status) {
        StudioStatus.loading ||
        StudioStatus.running ||
        StudioStatus.cooldown => GenerationStatus.running,
        StudioStatus.paused => GenerationStatus.paused,
        StudioStatus.error || StudioStatus.failed => GenerationStatus.failed,
        StudioStatus.canceled => GenerationStatus.canceled,
        StudioStatus.succeeded ||
        StudioStatus.skipped ||
        StudioStatus.completed => GenerationStatus.completed,
        StudioStatus.empty || StudioStatus.pending => GenerationStatus.queued,
      };

  static String _runStage(GenerationRun run) {
    if (run.status == StudioStatus.failed || run.status == StudioStatus.error) {
      return '生成任务需处理';
    }
    if (run.status == StudioStatus.paused) return '生成已暂停';
    if (run.status == StudioStatus.canceled) return '生成已取消';
    if (run.status == StudioStatus.succeeded ||
        run.status == StudioStatus.completed) {
      return '生成任务已完成';
    }
    if (run.status == StudioStatus.skipped) return '无需生成，已跳过';
    GenerationTask? active;
    for (final task in run.tasks) {
      if (task.status == StudioStatus.running ||
          task.status == StudioStatus.cooldown) {
        active = task;
        break;
      }
    }
    return active?.label ?? '生成队列已建立';
  }

  static String _taskTypeLabel(GenerationTaskType type) => switch (type) {
    GenerationTaskType.script => '结构化剧本',
    GenerationTaskType.characterImage => '角色卡',
    GenerationTaskType.sceneImage => '场景卡',
    GenerationTaskType.propImage => '道具卡',
    GenerationTaskType.storyboardFrame => '首尾帧',
    GenerationTaskType.shotVideo => '图生视频',
    GenerationTaskType.voiceLine => '角色配音',
    GenerationTaskType.episodeExport => '成片合成',
  };

  static String _dateLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month} 月 ${local.day} 日 $hour:$minute';
  }

  static String _shorten(String input, int maxLength) =>
      input.length <= maxLength ? input : '${input.substring(0, maxLength)}…';

  static String _assetDescription(String description, String visualLock) {
    final details = <String>[];
    if (description.trim().isNotEmpty) details.add(description.trim());
    details.add(
      visualLock.trim().isEmpty ? '视觉一致性要求未返回' : '视觉一致性要求：${visualLock.trim()}',
    );
    return details.join('；');
  }

  static const _palette = <int>[0xFF315CA8, 0xFF7960A8, 0xFF2F7B75, 0xFFA85F4D];
  static const _scenePalette = <int>[
    0xFF24445F,
    0xFF754042,
    0xFF405A3E,
    0xFF6A556E,
  ];
  static const _propPalette = <int>[
    0xFF8A6A28,
    0xFF656565,
    0xFF7B4E66,
    0xFF286D75,
  ];
}
