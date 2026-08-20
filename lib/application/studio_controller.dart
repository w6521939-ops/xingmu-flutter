import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/studio_models.dart';
import '../domain/studio_repository.dart';
import '../domain/studio_status.dart';
import '../domain/studio_validation.dart';

class StudioController extends ChangeNotifier {
  StudioController({required StudioRepository repository})
    : _repository = repository;

  final StudioRepository _repository;
  final List<StudioProject> _projects = [];
  StudioStatus _status = StudioStatus.empty;
  String? _selectedProjectId;
  String? _errorMessage;
  bool _disposed = false;
  final Random _secureRandom = Random.secure();

  StudioStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isLoading => _status == StudioStatus.loading;
  UnmodifiableListView<StudioProject> get projects =>
      UnmodifiableListView(_projects);
  String? get selectedProjectId => _selectedProjectId;

  StudioProject? get currentProject {
    if (_projects.isEmpty) return null;
    return _projects.cast<StudioProject?>().firstWhere(
      (project) => project?.id == _selectedProjectId,
      orElse: () => _projects.first,
    );
  }

  GenerationRun? get currentRun => currentProject?.currentRun;
  StudioStatus? get scriptStatus => currentProject?.latestScriptJobStatus;
  bool get isScriptReady {
    final project = currentProject;
    if (project?.script == null) return false;
    final status = project?.latestScriptJobStatus;
    return status == null ||
        status == StudioStatus.succeeded ||
        status == StudioStatus.completed;
  }

  Future<void> initialize() async {
    _setStatus(StudioStatus.loading, clearError: true);
    try {
      final loaded = await _repository.listProjects();
      _projects
        ..clear()
        ..addAll(loaded);
      _selectedProjectId = loaded.isEmpty ? null : loaded.first.id;
      _setStatus(
        loaded.isEmpty ? StudioStatus.empty : _statusForProject(loaded.first),
      );
    } catch (error) {
      _setError(error);
    }
  }

  Future<void> createProject(String theme, {String? title}) async {
    String normalized;
    try {
      normalized = ThemeValidator.validate(theme);
    } catch (error) {
      _setError(error);
      return;
    }
    _setStatus(StudioStatus.loading, clearError: true);
    try {
      final project = await _repository.createProject(
        theme: normalized,
        title: title,
        idempotencyKey: _newIdempotencyKey(),
      );
      _replaceProject(project, moveToFront: true);
      _selectedProjectId = project.id;
      _setStatus(StudioStatus.succeeded);
    } catch (error) {
      _setError(error);
    }
  }

  void selectProject(String projectId) {
    if (!_projects.any((project) => project.id == projectId)) return;
    _selectedProjectId = projectId;
    _setStatus(_statusForProject(currentProject!));
  }

  Future<void> adoptScript({ScriptSummary? script}) async {
    final project = await _ensureProjectEtag();
    if (project == null) return;
    await _mutate(
      () => _repository.adoptScript(
        projectId: project.id,
        etag: project.etag!,
        sourceText: script == null
            ? project.theme
            : jsonEncode(script.toJson()),
        script: script,
        idempotencyKey: _newIdempotencyKey(),
      ),
    );
  }

  Future<void> startGeneration({
    bool onlyMissing = true,
    List<String>? shotIds,
  }) async {
    final project = await _ensureProjectEtag();
    if (project == null) return;
    final scriptJobStatus = project.latestScriptJobStatus;
    if (project.script == null ||
        (scriptJobStatus != null &&
            scriptJobStatus != StudioStatus.succeeded &&
            scriptJobStatus != StudioStatus.completed)) {
      _setError(StateError('剧本生成尚未完成，请稍后刷新'));
      return;
    }
    await _mutate(
      () => _repository.startGeneration(
        projectId: project.id,
        etag: project.etag!,
        onlyMissing: onlyMissing,
        shotIds: shotIds,
        idempotencyKey: _newIdempotencyKey(),
      ),
    );
  }

  Future<void> pauseGeneration() async {
    final project = await _ensureRunEtag();
    final run = project?.currentRun;
    if (project == null || run == null) {
      _setError(StateError('当前没有可暂停的生成任务'));
      return;
    }
    await _mutate(
      () => _repository.pauseGeneration(
        projectId: project.id,
        runId: run.id,
        runEtag: run.etag!,
        idempotencyKey: _newIdempotencyKey(),
      ),
    );
  }

  Future<void> resumeGeneration() async {
    final project = await _ensureRunEtag();
    final run = project?.currentRun;
    if (project == null || run == null) {
      _setError(StateError('当前没有可继续的生成任务'));
      return;
    }
    await _mutate(
      () => _repository.resumeGeneration(
        projectId: project.id,
        runId: run.id,
        runEtag: run.etag!,
        idempotencyKey: _newIdempotencyKey(),
      ),
    );
  }

  Future<void> retryFailedTasks() async {
    final project = _requireCurrentProject();
    final run = project?.currentRun;
    if (project == null || run == null) {
      _setError(StateError('当前没有可重试的失败任务'));
      return;
    }
    await _mutate(
      () => _repository.retryFailedTasks(
        projectId: project.id,
        runId: run.id,
        idempotencyKey: _newIdempotencyKey(),
      ),
    );
  }

  Future<void> retryTask(String taskId) async {
    final project = _requireCurrentProject();
    final run = project?.currentRun;
    if (project == null || run == null) {
      _setError(StateError('当前没有可重试的失败任务'));
      return;
    }
    if (!run.tasks.any((task) => task.id == taskId)) {
      _setError(StateError('生成任务不存在：$taskId'));
      return;
    }
    await _mutate(
      () => _repository.retryTask(
        projectId: project.id,
        runId: run.id,
        taskId: taskId,
        idempotencyKey: _newIdempotencyKey(),
      ),
    );
  }

  Future<void> refresh() async {
    final project = _requireCurrentProject();
    if (project == null) return;
    await _mutate(() => _repository.refreshProject(project.id));
  }

  Future<void> cancelGeneration() async {
    final project = await _ensureRunEtag();
    final run = project?.currentRun;
    if (project == null || run == null) {
      _setError(StateError('当前没有可取消的生成任务'));
      return;
    }
    await _mutate(
      () => _repository.cancelGeneration(
        projectId: project.id,
        runId: run.id,
        runEtag: run.etag!,
        idempotencyKey: _newIdempotencyKey(),
      ),
    );
  }

  Future<void> advanceDemo() async {
    final project = _requireCurrentProject();
    if (project == null) return;
    final repository = _repository;
    if (repository is! DemoStudioDriver) {
      _setError(UnsupportedError('真实后端任务会自动推进，请使用刷新获取状态'));
      return;
    }
    await _mutate(
      () => (repository as DemoStudioDriver).advanceDemo(project.id),
    );
  }

  void clearError() {
    _errorMessage = null;
    _status = _deriveStatus();
    _notify();
  }

  Future<void> _mutate(
    Future<StudioProject> Function() action, {
    StudioStatus? successStatus,
  }) async {
    _setStatus(StudioStatus.loading, clearError: true);
    try {
      final project = await action();
      _replaceProject(project);
      _selectedProjectId = project.id;
      _setStatus(successStatus ?? _statusForProject(project));
    } catch (error) {
      _setError(error);
    }
  }

  StudioProject? _requireCurrentProject() {
    final project = currentProject;
    if (project == null) {
      _setError(StateError('请先创建漫剧项目'));
    }
    return project;
  }

  Future<StudioProject?> _ensureProjectEtag() async {
    final project = _requireCurrentProject();
    if (project == null || project.etag != null) return project;
    _setStatus(StudioStatus.loading, clearError: true);
    try {
      final refreshed = await _repository.refreshProject(project.id);
      _replaceProject(refreshed);
      if (refreshed.etag == null) {
        throw StateError('服务端未返回项目 ETag，不能安全修改');
      }
      return refreshed;
    } catch (error) {
      _setError(error);
      return null;
    }
  }

  Future<StudioProject?> _ensureRunEtag() async {
    var project = _requireCurrentProject();
    if (project == null) return null;
    if (project.currentRun?.etag != null) return project;
    _setStatus(StudioStatus.loading, clearError: true);
    try {
      project = await _repository.refreshProject(project.id);
      _replaceProject(project);
      if (project.currentRun?.etag == null) {
        throw StateError('服务端未返回生成运行 ETag，不能安全变更状态');
      }
      return project;
    } catch (error) {
      _setError(error);
      return null;
    }
  }

  void _replaceProject(StudioProject project, {bool moveToFront = false}) {
    final index = _projects.indexWhere((item) => item.id == project.id);
    if (index >= 0) _projects.removeAt(index);
    if (moveToFront) {
      _projects.insert(0, project);
    } else if (index >= 0 && index <= _projects.length) {
      _projects.insert(index, project);
    } else {
      _projects.add(project);
    }
  }

  StudioStatus _deriveStatus() {
    final project = currentProject;
    if (project == null) return StudioStatus.empty;
    return _statusForProject(project);
  }

  StudioStatus _statusForProject(StudioProject project) =>
      project.currentRun?.status ??
      project.latestScriptJobStatus ??
      StudioStatus.succeeded;

  void _setStatus(StudioStatus value, {bool clearError = false}) {
    _status = value;
    if (clearError) _errorMessage = null;
    _notify();
  }

  void _setError(Object error) {
    _errorMessage = _readableError(error);
    _status = StudioStatus.error;
    _notify();
  }

  String _readableError(Object error) {
    if (error is StudioValidationException) return error.message;
    final text = error.toString();
    return text
        .replaceFirst(RegExp(r'^(StateError|Unsupported operation):\s*'), '')
        .trim();
  }

  String _newIdempotencyKey() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
