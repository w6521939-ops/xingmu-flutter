import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/domain/domain.dart';

void main() {
  test('only-missing plan is deterministic and dependency ordered', () {
    final project = _projectWithPartialOutputs();

    final first = GenerationPlanner.plan(project);
    final second = GenerationPlanner.plan(project);

    expect(first.map((task) => task.type), [
      GenerationTaskType.characterImage,
      GenerationTaskType.sceneImage,
      GenerationTaskType.storyboardFrame,
      GenerationTaskType.shotVideo,
      GenerationTaskType.voiceLine,
      GenerationTaskType.episodeExport,
    ]);
    expect(first.map((task) => task.sequence), [0, 1, 2, 3, 4, 5]);
    expect(
      first.map((task) => task.toJson()).toList(),
      second.map((task) => task.toJson()).toList(),
    );
  });

  test('project without an adopted script plans only the script task', () {
    final now = DateTime.utc(2026, 1, 1);
    final project = StudioProject(
      id: 'p',
      title: '测试',
      theme: '一个足够长的主题',
      createdAt: now,
      updatedAt: now,
    );
    final tasks = GenerationPlanner.plan(project);
    expect(tasks, hasLength(1));
    expect(tasks.single.type, GenerationTaskType.script);
  });

  test(
    'targeted plan includes only assets and work related to selected shots',
    () {
      final project = _projectWithPartialOutputs();

      final tasks = GenerationPlanner.plan(
        project,
        onlyMissing: false,
        shotIds: const ['shot1'],
      );

      expect(tasks.map((task) => task.type), [
        GenerationTaskType.characterImage,
        GenerationTaskType.sceneImage,
        GenerationTaskType.propImage,
        GenerationTaskType.storyboardFrame,
        GenerationTaskType.shotVideo,
        GenerationTaskType.voiceLine,
      ]);
      expect(tasks.map((task) => task.targetId), [
        'c1',
        'scene1',
        'prop1',
        'shot1',
        'shot1',
        'line1',
      ]);
      expect(
        tasks.any((task) => task.type == GenerationTaskType.episodeExport),
        isFalse,
      );
    },
  );

  test('targeted plan rejects empty and unknown shot selections', () {
    final project = _projectWithPartialOutputs();

    expect(
      () => GenerationPlanner.plan(project, shotIds: const []),
      throwsArgumentError,
    );
    expect(
      () => GenerationPlanner.plan(project, shotIds: const ['missing-shot']),
      throwsArgumentError,
    );
  });
}

StudioProject _projectWithPartialOutputs() {
  final now = DateTime.utc(2026, 1, 1);
  return StudioProject(
    id: 'p1',
    title: '测试',
    theme: '一个足够长的主题',
    createdAt: now,
    updatedAt: now,
    script: const ScriptSummary(
      id: 'script',
      title: '第一集',
      logline: '测试',
      styleBible: '测试风格',
      episodeSynopsis: '测试摘要',
    ),
    characters: const [
      CharacterAsset(
        id: 'c1',
        name: '已有角色',
        description: '已有角色',
        visualLock: '红衣',
        imageUrl: 'https://cdn.test/c1.png',
        status: StudioStatus.succeeded,
      ),
      CharacterAsset(
        id: 'c2',
        name: '缺失角色',
        description: '缺图',
        visualLock: '蓝衣',
      ),
    ],
    scenes: const [
      SceneAsset(id: 'scene1', name: '天台', description: '缺图', visualLock: '雨夜'),
    ],
    props: const [
      PropAsset(
        id: 'prop1',
        name: '胶片盒',
        description: '已有图',
        visualLock: '黑色',
        imageUrl: 'https://cdn.test/prop.png',
        status: StudioStatus.succeeded,
      ),
    ],
    shots: const [
      Shot(
        id: 'shot1',
        order: 1,
        title: '已有分镜',
        prompt: '测试',
        durationSeconds: 5,
        characterIds: ['c1'],
        sceneId: 'scene1',
        propIds: ['prop1'],
        firstFrameUrl: 'https://cdn.test/first.png',
        lastFrameUrl: 'https://cdn.test/last.png',
      ),
      Shot(
        id: 'shot2',
        order: 2,
        title: '缺失分镜',
        prompt: '测试',
        durationSeconds: 5,
        characterIds: ['c2'],
        videoUrl: 'https://cdn.test/shot2.mp4',
        status: StudioStatus.succeeded,
      ),
    ],
    voiceLines: const [
      VoiceLine(
        id: 'line1',
        shotId: 'shot1',
        speaker: '主角',
        text: '测试台词',
        voiceName: '测试音色',
      ),
    ],
  );
}
