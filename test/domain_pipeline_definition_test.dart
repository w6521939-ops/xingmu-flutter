import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/domain/pipeline/pipeline_definition.dart';

void main() {
  group('PipelineDefinition', () {
    test('all returns 4 pipelines', () {
      expect(PipelineDefinition.all.length, 4);
    });

    test('findById returns correct pipeline', () {
      final manju = PipelineDefinition.findById('manju-drama');
      expect(manju, isNotNull);
      expect(manju!.name, '漫剧制作');
      expect(manju.stages.length, 8);

      final talking = PipelineDefinition.findById('talking-head');
      expect(talking, isNotNull);
      expect(talking!.name, '口播视频');
      expect(talking.stages.length, 6);

      final screen = PipelineDefinition.findById('screen-recording');
      expect(screen, isNotNull);
      expect(screen!.name, '屏幕录制演示');
      expect(screen.stages.length, 6);

      final podcast = PipelineDefinition.findById('podcast-repurpose');
      expect(podcast, isNotNull);
      expect(podcast!.name, '播客再利用');
      expect(podcast.stages.length, 5);
    });

    test('findById returns null for unknown id', () {
      expect(PipelineDefinition.findById('nonexistent'), isNull);
    });
  });

  group('ManjuDrama pipeline', () {
    final pipeline = PipelineDefinition.manjuDrama;

    test('has 8 stages in correct order', () {
      final order = pipeline.stageOrder;
      expect(order[0], PipelineStage.ingestion);
      expect(order[1], PipelineStage.script);
      expect(order[2], PipelineStage.characters);
      expect(order[3], PipelineStage.storyboard);
      expect(order[4], PipelineStage.shots);
      expect(order[5], PipelineStage.voice);
      expect(order[6], PipelineStage.compose);
      expect(order[7], PipelineStage.publish);
    });

    test('ingestion has no dependencies', () {
      final ingestion = pipeline.getStage(PipelineStage.ingestion)!;
      expect(ingestion.dependsOn, isEmpty);
      expect(ingestion.requiresApproval, isTrue);
    });

    test('shots can parallelize', () {
      final shots = pipeline.getStage(PipelineStage.shots)!;
      expect(shots.canParallel, isTrue);
    });

    test('canExecute respects dependencies', () {
      final statuses = <PipelineStage, StageStatus>{
        PipelineStage.ingestion: StageStatus.completed,
        PipelineStage.script: StageStatus.completed,
      };
      final characters = pipeline.getStage(PipelineStage.characters)!;
      expect(characters.canExecute(statuses), isTrue);

      final storyboard = pipeline.getStage(PipelineStage.storyboard)!;
      expect(storyboard.canExecute(statuses), isFalse);
    });
  });

  group('TalkingHead pipeline', () {
    final pipeline = PipelineDefinition.talkingHead;

    test('skips characters and storyboard stages', () {
      expect(pipeline.getStage(PipelineStage.characters), isNull);
      expect(pipeline.getStage(PipelineStage.storyboard), isNull);
    });

    test('shots depends only on script', () {
      final shots = pipeline.getStage(PipelineStage.shots)!;
      expect(shots.dependsOn, [PipelineStage.script]);
      expect(shots.canParallel, isTrue);
    });

    test('voice depends only on script (no characters needed)', () {
      final voice = pipeline.getStage(PipelineStage.voice)!;
      expect(voice.dependsOn, [PipelineStage.script]);
    });
  });

  group('ScreenRecording pipeline', () {
    final pipeline = PipelineDefinition.screenRecording;

    test('has 6 stages', () {
      expect(pipeline.stages.length, 6);
    });

    test('shots and voice can run in parallel after script', () {
      final shots = pipeline.getStage(PipelineStage.shots)!;
      final voice = pipeline.getStage(PipelineStage.voice)!;
      expect(shots.canParallel, isTrue);
      expect(voice.canParallel, isTrue);
      expect(shots.dependsOn, [PipelineStage.script]);
      expect(voice.dependsOn, [PipelineStage.script]);
    });
  });

  group('PodcastRepurpose pipeline', () {
    final pipeline = PipelineDefinition.podcastRepurpose;

    test('has 5 stages (no shots, no characters)', () {
      expect(pipeline.stages.length, 5);
      expect(pipeline.getStage(PipelineStage.characters), isNull);
      expect(pipeline.getStage(PipelineStage.storyboard), isNull);
      expect(pipeline.getStage(PipelineStage.shots), isNull);
    });

    test('voice depends on script only', () {
      final voice = pipeline.getStage(PipelineStage.voice)!;
      expect(voice.dependsOn, [PipelineStage.script]);
      expect(voice.canParallel, isFalse);
    });

    test('compose depends on voice only (no shots)', () {
      final compose = pipeline.getStage(PipelineStage.compose)!;
      expect(compose.dependsOn, [PipelineStage.voice]);
    });
  });

  group('StageStatus', () {
    test('terminal statuses', () {
      expect(StageStatus.completed.isTerminal, isTrue);
      expect(StageStatus.skipped.isTerminal, isTrue);
      expect(StageStatus.failed.isTerminal, isTrue);
      expect(StageStatus.running.isTerminal, isFalse);
      expect(StageStatus.pending.isTerminal, isFalse);
    });

    test('active statuses', () {
      expect(StageStatus.running.isActive, isTrue);
      expect(StageStatus.awaitingApproval.isActive, isTrue);
      expect(StageStatus.paused.isActive, isTrue);
      expect(StageStatus.pending.isActive, isFalse);
    });
  });
}
