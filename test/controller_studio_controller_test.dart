import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/application/application.dart';
import 'package:xingmu_ai_video_studio/data/data.dart';
import 'package:xingmu_ai_video_studio/domain/domain.dart';

void main() {
  test('controller exposes validation errors and can clear them', () async {
    final controller = StudioController(repository: DemoStudioRepository());
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.status, StudioStatus.empty);
    await controller.createProject('猫咪');
    expect(controller.status, StudioStatus.error);
    expect(controller.errorMessage, contains('至少'));

    controller.clearError();
    expect(controller.status, StudioStatus.empty);
    expect(controller.errorMessage, isNull);
  });

  test('generation can pause and resume without changing task order', () async {
    final controller = await _startedController(DemoStudioRepository());
    addTearDown(controller.dispose);
    final taskIds = controller.currentRun!.tasks
        .map((task) => task.id)
        .toList();

    await controller.pauseGeneration();
    expect(controller.status, StudioStatus.paused);
    expect(
      controller.currentRun!.tasks.where(
        (task) => task.status == StudioStatus.paused,
      ),
      hasLength(1),
    );

    await controller.resumeGeneration();
    expect(controller.status, StudioStatus.running);
    expect(controller.currentRun!.tasks.map((task) => task.id), taskIds);
    expect(
      controller.currentRun!.tasks.where(
        (task) => task.status == StudioStatus.running,
      ),
      hasLength(1),
    );
  });

  test(
    'failed demo task retries only the selected task with a new attempt',
    () async {
      final controller = await _startedController(
        DemoStudioRepository(failOnce: {GenerationTaskType.characterImage}),
      );
      addTearDown(controller.dispose);

      await controller.advanceDemo();
      expect(controller.status, StudioStatus.failed);
      final failed = controller.currentRun!.tasks.singleWhere(
        (task) => task.status == StudioStatus.failed,
      );
      expect(failed.attempt, 1);

      await controller.retryTask(failed.id);
      expect(controller.status, StudioStatus.running);
      final retried = controller.currentRun!.tasks.singleWhere(
        (task) => task.id == failed.id,
      );
      expect(retried.status, StudioStatus.running);
      expect(retried.attempt, 2);
      expect(retried.errorMessage, isNull);
    },
  );

  test(
    'targeted generation plans only work related to the selected shot',
    () async {
      final controller = StudioController(repository: DemoStudioRepository());
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.createProject('雨夜天台发生了一场秘密相遇');
      await controller.adoptScript();
      final targetShot = controller.currentProject!.shots[1];

      await controller.startGeneration(
        onlyMissing: false,
        shotIds: [targetShot.id],
      );

      final tasks = controller.currentRun!.tasks;
      expect(
        tasks
            .where(
              (task) =>
                  task.type == GenerationTaskType.storyboardFrame ||
                  task.type == GenerationTaskType.shotVideo,
            )
            .map((task) => task.targetId)
            .toSet(),
        {targetShot.id},
      );
      expect(
        tasks
            .where((task) => task.type == GenerationTaskType.voiceLine)
            .map((task) => task.targetId),
        [controller.currentProject!.voiceLines[1].id],
      );
      expect(
        tasks.any((task) => task.type == GenerationTaskType.episodeExport),
        isFalse,
      );
    },
  );

  test('cancel keeps a canceled terminal state instead of skipped', () async {
    final controller = await _startedController(DemoStudioRepository());
    addTearDown(controller.dispose);

    await controller.cancelGeneration();

    expect(controller.status, StudioStatus.canceled);
    expect(controller.currentRun!.status, StudioStatus.canceled);
    expect(
      controller.currentRun!.tasks.where(
        (task) => task.status == StudioStatus.canceled,
      ),
      isNotEmpty,
    );
    expect(controller.currentRun!.progress, 1);
  });

  test('queued script job stays pending and is not exposed as ready', () async {
    final controller = StudioController(
      repository: _QueuedScriptDemoRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.createProject('雨夜天台发生了一场秘密相遇');

    await controller.adoptScript();

    expect(controller.status, StudioStatus.pending);
    expect(controller.scriptStatus, StudioStatus.pending);
    expect(controller.isScriptReady, isFalse);

    await controller.startGeneration();
    expect(controller.status, StudioStatus.error);
    expect(controller.errorMessage, contains('剧本生成尚未完成'));
    expect(controller.currentRun, isNull);
  });

  test('demo run advances to a completed video export', () async {
    final controller = await _startedController(DemoStudioRepository());
    addTearDown(controller.dispose);

    for (
      var step = 0;
      step < 100 && controller.status != StudioStatus.completed;
      step++
    ) {
      await controller.advanceDemo();
    }

    expect(controller.status, StudioStatus.completed);
    expect(controller.currentRun!.progress, 1);
    expect(
      controller.currentRun!.tasks.every(
        (task) => task.status == StudioStatus.succeeded,
      ),
      isTrue,
    );
    expect(controller.currentProject!.exports, hasLength(1));
    expect(controller.currentProject!.exports.single.videoUrl, isNotNull);
    expect(
      controller.currentProject!.shots.every((shot) => shot.videoUrl != null),
      isTrue,
    );
    expect(
      controller.currentProject!.voiceLines.every(
        (line) => line.audioUrl != null,
      ),
      isTrue,
    );
  });
}

class _QueuedScriptDemoRepository extends DemoStudioRepository {
  @override
  Future<StudioProject> adoptScript({
    required String projectId,
    required String etag,
    required String sourceText,
    ScriptSummary? script,
    String? idempotencyKey,
  }) async {
    final project = await super.adoptScript(
      projectId: projectId,
      etag: etag,
      sourceText: sourceText,
      script: script,
      idempotencyKey: idempotencyKey,
    );
    return project.copyWith(
      script: null,
      latestScriptJobStatus: StudioStatus.pending,
    );
  }
}

Future<StudioController> _startedController(
  DemoStudioRepository repository,
) async {
  final controller = StudioController(repository: repository);
  await controller.initialize();
  await controller.createProject('雨夜天台发生了一场秘密相遇');
  await controller.adoptScript();
  await controller.startGeneration();
  return controller;
}
