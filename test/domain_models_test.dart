import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/domain/domain.dart';

void main() {
  group('ThemeValidator', () {
    test('normalizes a valid theme', () {
      expect(ThemeValidator.validate('  雨夜   天台的秘密  '), '雨夜 天台的秘密');
    });

    test('rejects empty, too short and too long themes', () {
      expect(
        () => ThemeValidator.validate('   '),
        throwsA(isA<StudioValidationException>()),
      );
      expect(
        () => ThemeValidator.validate('猫咪'),
        throwsA(isA<StudioValidationException>()),
      );
      expect(
        () => ThemeValidator.validate(List.filled(301, '漫').join()),
        throwsA(isA<StudioValidationException>()),
      );
    });
  });

  test('project JSON round-trip preserves nested revisions and statuses', () {
    final now = DateTime.utc(2026, 8, 20, 12);
    final project = StudioProject(
      id: 'p1',
      title: '星幕',
      theme: '雨夜天台的秘密',
      revision: 7,
      createdAt: now,
      updatedAt: now,
      script: const ScriptSummary(
        id: 's1',
        title: '第一集',
        logline: '一句话',
        styleBible: '青金配色',
        episodeSynopsis: '相遇与反转',
        revision: 2,
      ),
      currentRun: GenerationRun(
        id: 'r1',
        projectId: 'p1',
        status: StudioStatus.cooldown,
        onlyMissing: true,
        tasks: const [
          GenerationTask(
            id: 't1',
            type: GenerationTaskType.shotVideo,
            sequence: 0,
            label: '镜头视频',
            targetId: 'shot1',
            inputHash: 'abc12345',
            status: StudioStatus.cooldown,
            revision: 3,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        revision: 4,
      ),
    );

    final decoded = StudioProject.fromJson(project.toJson());
    expect(decoded.revision, 7);
    expect(decoded.script?.revision, 2);
    expect(decoded.currentRun?.status, StudioStatus.cooldown);
    expect(decoded.currentRun?.tasks.single.revision, 3);
    expect(decoded.toJson(), project.toJson());
  });

  test(
    'canceled stays distinct, is terminal, and prop_images is recognized',
    () {
      expect(StudioStatus.fromJson('canceled'), StudioStatus.canceled);
      expect(StudioStatus.canceled.isTerminal, isTrue);
      expect(StudioStatus.canceled, isNot(StudioStatus.skipped));
      expect(
        GenerationTaskType.fromJson('prop_images'),
        GenerationTaskType.propImage,
      );
    },
  );

  test('missing statuses and unknown generation stages fail closed', () {
    expect(() => StudioStatus.fromJson(null), throwsFormatException);
    expect(() => StudioStatus.fromJson(''), throwsFormatException);
    expect(
      () => GenerationTaskType.fromJson('future_unknown_stage'),
      throwsFormatException,
    );
  });

  test(
    'run progress counts canceled terminal work without calling it completed',
    () {
      final now = DateTime.utc(2026, 8, 20, 12);
      final run = GenerationRun(
        id: 'run-1',
        projectId: 'project-1',
        status: StudioStatus.canceled,
        onlyMissing: true,
        tasks: const [
          GenerationTask(
            id: 'done',
            type: GenerationTaskType.shotVideo,
            sequence: 0,
            label: '已完成',
            targetId: 'shot-1',
            inputHash: 'done',
            status: StudioStatus.succeeded,
          ),
          GenerationTask(
            id: 'canceled',
            type: GenerationTaskType.voiceLine,
            sequence: 1,
            label: '已取消',
            targetId: 'line-1',
            inputHash: 'canceled',
            status: StudioStatus.canceled,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(run.completedTaskCount, 1);
      expect(run.canceledTaskCount, 1);
      expect(run.terminalTaskCount, 2);
      expect(run.progress, 1);
    },
  );
}
