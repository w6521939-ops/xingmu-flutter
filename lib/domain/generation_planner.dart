import 'studio_models.dart';
import 'studio_status.dart';

abstract final class GenerationPlanner {
  static List<GenerationTask> plan(
    StudioProject project, {
    bool onlyMissing = true,
    List<String>? shotIds,
  }) {
    final tasks = <GenerationTask>[];
    final targetShotIds = shotIds == null
        ? null
        : Set<String>.unmodifiable(
            shotIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
          );
    if (shotIds != null && targetShotIds!.isEmpty) {
      throw ArgumentError.value(shotIds, 'shotIds', '至少选择一个镜头');
    }
    if (targetShotIds != null) {
      final knownShotIds = project.shots.map((shot) => shot.id).toSet();
      final unknown = targetShotIds.difference(knownShotIds);
      if (unknown.isNotEmpty) {
        throw ArgumentError.value(
          shotIds,
          'shotIds',
          '包含未知镜头：${unknown.join(', ')}',
        );
      }
    }
    final targetShots = targetShotIds == null
        ? project.shots
        : project.shots
              .where((shot) => targetShotIds.contains(shot.id))
              .toList();
    final targetCharacterIds = targetShots
        .expand((shot) => shot.characterIds)
        .toSet();
    final targetSceneIds = targetShots
        .map((shot) => shot.sceneId)
        .whereType<String>()
        .toSet();
    final targetPropIds = targetShots.expand((shot) => shot.propIds).toSet();

    void add(
      GenerationTaskType type,
      String targetId,
      String label,
      String input,
    ) {
      final sequence = tasks.length;
      tasks.add(
        GenerationTask(
          id: '${project.id}:${type.wireName}:$targetId',
          type: type,
          sequence: sequence,
          label: label,
          targetId: targetId,
          inputHash: stableInputHash(input),
        ),
      );
    }

    if (project.script == null) {
      add(
        GenerationTaskType.script,
        project.id,
        '生成结构化剧本',
        '${project.id}|${project.theme}|script',
      );
      return List.unmodifiable(tasks);
    }

    for (final character in project.characters) {
      if (targetShotIds != null && !targetCharacterIds.contains(character.id)) {
        continue;
      }
      if (!onlyMissing || character.imageUrl == null) {
        add(
          GenerationTaskType.characterImage,
          character.id,
          '角色卡 · ${character.name}',
          '${character.id}|${character.visualLock}',
        );
      }
    }
    for (final scene in project.scenes) {
      if (targetShotIds != null && !targetSceneIds.contains(scene.id)) {
        continue;
      }
      if (!onlyMissing || scene.imageUrl == null) {
        add(
          GenerationTaskType.sceneImage,
          scene.id,
          '场景卡 · ${scene.name}',
          '${scene.id}|${scene.visualLock}',
        );
      }
    }
    for (final prop in project.props) {
      if (targetShotIds != null && !targetPropIds.contains(prop.id)) {
        continue;
      }
      if (!onlyMissing || prop.imageUrl == null) {
        add(
          GenerationTaskType.propImage,
          prop.id,
          '道具卡 · ${prop.name}',
          '${prop.id}|${prop.visualLock}',
        );
      }
    }
    for (final shot in targetShots) {
      if (!onlyMissing || !shot.hasStoryboard) {
        add(
          GenerationTaskType.storyboardFrame,
          shot.id,
          '分镜首尾帧 · ${shot.title}',
          '${shot.id}|${shot.prompt}|${shot.characterIds.join(',')}|${shot.sceneId}',
        );
      }
    }
    for (final shot in targetShots) {
      if (!onlyMissing || shot.videoUrl == null) {
        add(
          GenerationTaskType.shotVideo,
          shot.id,
          '镜头视频 · ${shot.title}',
          '${shot.id}|${shot.firstFrameUrl}|${shot.lastFrameUrl}|${shot.prompt}',
        );
      }
    }
    for (final line in project.voiceLines) {
      if (targetShotIds != null && !targetShotIds.contains(line.shotId)) {
        continue;
      }
      if (!onlyMissing || line.audioUrl == null) {
        add(
          GenerationTaskType.voiceLine,
          line.id,
          '角色配音 · ${line.speaker}',
          '${line.id}|${line.text}|${line.voiceName}',
        );
      }
    }
    if (targetShotIds == null) {
      final hasCompletedExport = project.exports.any(
        (value) =>
            value.ready ||
            (value.videoUrl != null &&
                (value.status == StudioStatus.succeeded ||
                    value.status == StudioStatus.completed)),
      );
      if (!onlyMissing || !hasCompletedExport) {
        add(
          GenerationTaskType.episodeExport,
          project.id,
          '合成完整剧集',
          '${project.id}|${project.shots.map((shot) => shot.videoUrl).join(',')}|'
              '${project.voiceLines.map((line) => line.audioUrl).join(',')}',
        );
      }
    }
    return List.unmodifiable(tasks);
  }

  static String stableInputHash(String input) {
    var hash = 0x811c9dc5;
    for (final byte in input.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
