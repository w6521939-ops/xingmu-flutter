import 'dart:async';

import 'pipeline_definition.dart';
import 'pipeline_event.dart';

class PipelineRunner {
  PipelineRunner({
    required PipelineDefinition definition,
    Future<void> Function(PipelineStage stage)? stageExecutor,
  }) : _definition = definition,
       _stageExecutor = stageExecutor ?? _defaultExecutor;

  final PipelineDefinition _definition;
  final Future<void> Function(PipelineStage stage) _stageExecutor;

  final Map<PipelineStage, StageStatus> _stageStatus = {};
  final StreamController<PipelineEvent> _eventController =
      StreamController<PipelineEvent>.broadcast();

  bool _isRunning = false;
  bool _isPaused = false;
  bool _shouldStop = false;
  String? _lastError;

  Stream<PipelineEvent> get events => _eventController.stream;

  Map<PipelineStage, StageStatus> get stageStatuses =>
      Map.unmodifiable(_stageStatus);

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  String? get lastError => _lastError;

  PipelineDefinition get definition => _definition;

  List<PipelineStage> get pendingStages =>
      _definition.stages
          .where((s) => _stageStatus[s.stage] == null ||
              _stageStatus[s.stage] == StageStatus.pending)
          .map((s) => s.stage)
          .toList();

  List<PipelineStage> get completedStages =>
      _definition.stages
          .where((s) => _stageStatus[s.stage] == StageStatus.completed)
          .map((s) => s.stage)
          .toList();

  List<PipelineStage> get activeStages =>
      _definition.stages
          .where((s) => _stageStatus[s.stage]?.isActive == true)
          .map((s) => s.stage)
          .toList();

  bool get isComplete => _definition.stages.every(
        (s) => _stageStatus[s.stage]?.isTerminal == true,
      );

  double get overallProgress {
    final total = _definition.stages.length;
    final done = completedStages.length;
    return total == 0 ? 0 : done / total;
  }

  void _initializeStatuses() {
    for (final stage in _definition.stageOrder) {
      _stageStatus.putIfAbsent(stage, () => StageStatus.pending);
    }
  }

  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    _shouldStop = false;
    _lastError = null;

    _initializeStatuses();

    _emit(PipelineEventType.pipelineStarted, PipelineStage.ingestion,
        message: '管线启动：${_definition.name}');

    await _runStages();

    if (_shouldStop) {
      _emit(PipelineEventType.pipelineStopped, PipelineStage.ingestion,
          message: '管线已停止');
    } else if (isComplete) {
      _emit(PipelineEventType.pipelineCompleted, PipelineStage.publish,
          message: '管线完成');
    }

    _isRunning = false;
  }

  Future<void> pause() async {
    if (!_isRunning) return;
    _isPaused = true;
    _emit(PipelineEventType.pipelinePaused, PipelineStage.ingestion,
        message: '管线已暂停');
  }

  Future<void> resume() async {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;
    _emit(PipelineEventType.pipelineResumed, PipelineStage.ingestion,
        message: '管线已恢复');
    await _runStages();
  }

  Future<void> stop() async {
    _shouldStop = true;
    _isPaused = false;
    for (final stage in activeStages) {
      _stageStatus[stage] = StageStatus.paused;
      _emit(PipelineEventType.stagePaused, stage);
    }
  }

  Future<void> approveGate(PipelineStage stage) async {
    final stageDef = _definition.getStage(stage);
    if (stageDef == null || !stageDef.requiresApproval) return;

    if (_stageStatus[stage] != StageStatus.awaitingApproval) return;

    _stageStatus[stage] = StageStatus.running;
    _emit(PipelineEventType.stageApproved, stage);

    if (!_isPaused && !_shouldStop) {
      await _executeStage(stage);
    }
  }

  Future<void> skipStage(PipelineStage stage) async {
    _stageStatus[stage] = StageStatus.skipped;
    _emit(PipelineEventType.stageSkipped, stage);
  }

  Future<void> retryStage(PipelineStage stage) async {
    _stageStatus[stage] = StageStatus.pending;
    _emit(PipelineEventType.stagePending, stage, message: '重试阶段：${stage.label}');
    if (_isRunning && !_isPaused) {
      await _runStages();
    }
  }

  Future<void> _runStages() async {
    for (final stageDef in _definition.stages) {
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
          message: '${stageDef.stage.label}开始执行');

      if (stageDef.requiresApproval) {
        _stageStatus[stageDef.stage] = StageStatus.awaitingApproval;
        _emit(PipelineEventType.stageAwaitingApproval, stageDef.stage,
            message: stageDef.approvalLabel ?? '等待确认');
        continue;
      }

      await _executeStage(stageDef.stage);
    }
  }

  Future<void> _executeStage(PipelineStage stage) async {
    try {
      _stageStatus[stage] = StageStatus.running;
      _emit(PipelineEventType.stageResumed, stage);

      await _stageExecutor(stage);

      _stageStatus[stage] = StageStatus.completed;
      _emit(PipelineEventType.stageCompleted, stage,
          message: '${stage.label}已完成');
    } catch (e) {
      _stageStatus[stage] = StageStatus.failed;
      _lastError = e.toString();
      _emit(PipelineEventType.stageFailed, stage,
          message: e.toString());
    }
  }

  void _emit(PipelineEventType type, PipelineStage stage, {String? message}) {
    if (_eventController.isClosed) return;
    final progress = overallProgress;
    _eventController.add(PipelineEvent.now(type, stage, message: message, progress: progress));
  }

  void dispose() {
    _eventController.close();
  }

  static Future<void> _defaultExecutor(PipelineStage stage) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class PipelineCheckpoint {
  const PipelineCheckpoint({
    required this.pipelineId,
    required this.projectId,
    required this.stageStatuses,
    required this.timestamp,
    this.lastError,
  });

  final String pipelineId;
  final String projectId;
  final Map<PipelineStage, StageStatus> stageStatuses;
  final DateTime timestamp;
  final String? lastError;

  Map<String, dynamic> toJson() => {
    'pipelineId': pipelineId,
    'projectId': projectId,
    'stages': stageStatuses.map((k, v) => MapEntry(k.name, v.name)),
    'timestamp': timestamp.toUtc().toIso8601String(),
    'lastError': lastError,
  };

  factory PipelineCheckpoint.fromJson(Map<String, dynamic> json) {
    final stagesJson = json['stages'] as Map<String, dynamic>? ?? {};
    final stages = <PipelineStage, StageStatus>{};
    for (final entry in stagesJson.entries) {
      final stage = PipelineStage.values
          .where((s) => s.name == entry.key)
          .firstOrNull;
      final status = StageStatus.values
          .where((s) => s.name == entry.value)
          .firstOrNull;
      if (stage != null && status != null) {
        stages[stage] = status;
      }
    }
    return PipelineCheckpoint(
      pipelineId: json['pipelineId'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      stageStatuses: stages,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      lastError: json['lastError'] as String?,
    );
  }
}
