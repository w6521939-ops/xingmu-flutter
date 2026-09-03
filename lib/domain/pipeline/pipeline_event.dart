import 'pipeline_definition.dart';

class PipelineEvent {
  const PipelineEvent({
    required this.type,
    required this.stage,
    this.message,
    this.progress,
    this.timestamp,
  });

  final PipelineEventType type;
  final PipelineStage stage;
  final String? message;
  final double? progress;
  final DateTime? timestamp;

  factory PipelineEvent.now(
    PipelineEventType type,
    PipelineStage stage, {
    String? message,
    double? progress,
  }) =>
      PipelineEvent(
        type: type,
        stage: stage,
        message: message,
        progress: progress,
        timestamp: DateTime.now(),
      );
}

enum PipelineEventType {
  pipelineStarted,
  pipelinePaused,
  pipelineResumed,
  pipelineStopped,
  pipelineCompleted,
  stagePending,
  stageStarted,
  stageProgress,
  stageAwaitingApproval,
  stageApproved,
  stageCompleted,
  stageSkipped,
  stageFailed,
  stagePaused,
  stageResumed,
}
