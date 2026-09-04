import 'dart:async';

import '../pipeline/pipeline_definition.dart';
import '../pipeline/pipeline_event.dart';
import 'agent_registry.dart';
import 'base_agent.dart';
import 'project_blackboard.dart';

class MasterDirectorAgent {
  MasterDirectorAgent({
    required this.blackboard,
    required this.registry,
    PipelineDefinition? pipeline,
    int maxParallel = 2,
  }) : _pipeline = pipeline ?? PipelineDefinition.manjuDrama,
       _maxParallel = maxParallel;

  final ProjectBlackboard blackboard;
  final AgentRegistry registry;
  final PipelineDefinition _pipeline;
  final int _maxParallel;

  final StreamController<PipelineEvent> _eventController =
      StreamController<PipelineEvent>.broadcast();

  Stream<PipelineEvent> get events => _eventController.stream;

  bool _isRunning = false;
  bool _isPaused = false;
  bool _shouldStop = false;
  final Map<PipelineStage, StageStatus> _stageStatus = {};
  final Map<PipelineStage, bool> _agentRanForStage = {};
  int _activeParallel = 0;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  double get progress {
    final total = _pipeline.stages.length;
    final done = _pipeline.stages.where((s) =>
      _stageStatus[s.stage]?.isTerminal == true
    ).length;
    return total == 0 ? 0 : done / total;
  }

  final Map<PipelineStage, StageStatus> _prevStageStatus = {};

  PipelineDefinition get pipeline => _pipeline;

  Future<void> orchestrate() async {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    _shouldStop = false;

    for (final stage in _pipeline.stageOrder) {
      _stageStatus.putIfAbsent(stage, () => StageStatus.pending);
    }

    _emit(PipelineEventType.pipelineStarted, PipelineStage.ingestion,
        message: '导演 Agent 启动管线：${_pipeline.name}');

    await _runStages();

    if (_shouldStop) {
      _emit(PipelineEventType.pipelineStopped, PipelineStage.ingestion);
    } else {
      _emit(PipelineEventType.pipelineCompleted, PipelineStage.publish,
          message: '管线完成');
    }

    _isRunning = false;
  }

  Future<void> pause() async {
    _isPaused = true;
    _emit(PipelineEventType.pipelinePaused, PipelineStage.ingestion);
  }

  Future<void> resume() async {
    _isPaused = false;
    _emit(PipelineEventType.pipelineResumed, PipelineStage.ingestion);
    await _runStages();
  }

  Future<void> stop() async {
    _shouldStop = true;
    _isPaused = false;
    for (final stage in _pipeline.stageOrder) {
      if (_stageStatus[stage]?.isActive == true) {
        _stageStatus[stage] = StageStatus.paused;
      }
    }
  }

  Future<void> approveGate(PipelineStage stage) async {
    final stageDef = _pipeline.getStage(stage);
    if (stageDef == null || !stageDef.requiresApproval) return;
    if (_stageStatus[stage] != StageStatus.awaitingApproval) return;

    _stageStatus[stage] = StageStatus.running;
    _emit(PipelineEventType.stageApproved, stage);

    await _executeAgentsForStage(stage);
  }

  Future<void> _runStages() async {
    for (final stageDef in _pipeline.stages) {
      if (_shouldStop) break;

      while (_isPaused) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_shouldStop) break;
      }

      final status = _stageStatus[stageDef.stage];
      if (status?.isTerminal == true) continue;

      if (!stageDef.canExecute(_stageStatus)) continue;

      _stageStatus[stageDef.stage] = StageStatus.running;
      _emit(PipelineEventType.stageStarted, stageDef.stage,
          message: '${stageDef.stage.label}开始');

      if (stageDef.requiresApproval) {
        _stageStatus[stageDef.stage] = StageStatus.awaitingApproval;
        _emit(PipelineEventType.stageAwaitingApproval, stageDef.stage,
            message: stageDef.approvalLabel ?? '等待确认');
        continue;
      }

      await _executeAgentsForStage(stageDef.stage);
    }
  }

  Future<void> _executeAgentsForStage(PipelineStage stage) async {
    final agents = registry.all.where((a) =>
      a.triggerStage == stage && !_agentRanForStage.containsKey(stage)
    ).toList();

    if (agents.isEmpty) {
      _stageStatus[stage] = StageStatus.completed;
      _emit(PipelineEventType.stageCompleted, stage,
          message: '${stage.label}完成（无 Agent）');
      return;
    }

    if (_canRunParallel(agents, stage)) {
      _activeParallel = agents.length;
      _emit(PipelineEventType.stageProgress, stage,
          message: '${agents.length} 个 Agent 并行执行',
          progress: progress);

      await Future.wait(
        agents.map((agent) => _executeAgent(agent)),
      );
    } else {
      for (final agent in agents) {
        if (_shouldStop) break;
        await _executeAgent(agent);
      }
    }

    _agentRanForStage[stage] = true;

    if (_stageStatus[stage] != StageStatus.failed) {
      _stageStatus[stage] = StageStatus.completed;
      _emit(PipelineEventType.stageCompleted, stage,
          message: '${stage.label}完成');
    }
  }

  bool _canRunParallel(List<BaseAgent> agents, PipelineStage stage) {
    final stageDef = _pipeline.getStage(stage);
    if (stageDef == null || !stageDef.canParallel) return false;
    if (agents.length <= 1) return false;
    if (_maxParallel <= 1) return false;
    return true;
  }

  Future<void> _executeAgent(BaseAgent agent) async {
    if (!agent.canExecute(blackboard)) {
      _emit(PipelineEventType.stageSkipped, agent.triggerStage,
          message: '${agent.name} 跳过（前置条件不满足）');
      return;
    }

    _emit(PipelineEventType.stageProgress, agent.triggerStage,
        message: '${agent.emoji} ${agent.name} 执行中',
        progress: progress);

    try {
      await agent.execute(blackboard);
    } catch (e) {
      _stageStatus[agent.triggerStage] = StageStatus.failed;
      blackboard.write(BlackboardKeys.error, e.toString(), source: agent.id);
      _emit(PipelineEventType.stageFailed, agent.triggerStage,
          message: '${agent.name} 失败：${e.toString()}');
    }
  }

  void _emit(PipelineEventType type, PipelineStage stage, {String? message}) {
    if (_eventController.isClosed) return;
    _eventController.add(PipelineEvent.now(
      type, stage, message: message, progress: progress,
    ));
  }

  void dispose() {
    _eventController.close();
  }
}
