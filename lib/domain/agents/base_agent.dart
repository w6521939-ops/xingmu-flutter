import '../pipeline/pipeline_definition.dart';
import 'project_blackboard.dart';

abstract class BaseAgent {
  String get id;
  String get name;
  String get emoji;
  PipelineStage get triggerStage;
  bool get requiresApproval => false;
  Set<String> get inputKeys => const {};
  Set<String> get outputKeys => const {};
  String get description;

  bool canExecute(ProjectBlackboard blackboard) {
    for (final key in inputKeys) {
      if (!blackboard.has(key)) return false;
    }
    return true;
  }

  Future<void> execute(ProjectBlackboard blackboard);
}

abstract class StagedAgent extends BaseAgent {
  PipelineStage get triggerStage;

  bool shouldRunForStage(
    ProjectBlackboard blackboard,
    PipelineStage currentStage,
  Map<PipelineStage, StageStatus> stageStatuses,
  bool stageRequiresApproval,
  bool stageCanParallel,
  int activeParallelCount,
  int maxParallel,
  Set<PipelineStage> completedStagesSet,
    Map<PipelineStage, bool> agentRanForStage,
  ) {
    if (agentRanForStage[currentStage] == true) return false;
    if (!canExecute(blackboard)) return false;
    return currentStage == triggerStage;
  }
}
