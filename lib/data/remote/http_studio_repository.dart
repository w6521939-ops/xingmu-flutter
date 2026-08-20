import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../domain/studio_models.dart';
import '../../domain/studio_repository.dart';
import '../../domain/studio_status.dart';
import 'api_exception.dart';

typedef AccessTokenProvider = Future<String?> Function();

class HttpStudioRepository implements StudioRepository {
  HttpStudioRepository({
    required this.baseUri,
    required this.accessTokenProvider,
    this.allowInsecureTransport = false,
    HttpClient? client,
  }) : _client = client ?? HttpClient() {
    if (!baseUri.hasScheme || !baseUri.hasAuthority) {
      throw ArgumentError.value(baseUri, 'baseUri', '必须是完整的 HTTP(S) 地址');
    }
    if (baseUri.scheme != 'https' &&
        !(allowInsecureTransport && baseUri.scheme == 'http')) {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        '真实模式默认只允许 HTTPS；本地开发需显式启用 allowInsecureTransport',
      );
    }
    _client.connectionTimeout = requestTimeout;
  }

  static const Duration requestTimeout = Duration(seconds: 12);
  static const int maxResponseBytes = 2 * 1024 * 1024;
  static const int maxPaginationPages = 20;
  static const int maxPaginationItems = 2000;

  final Uri baseUri;
  final AccessTokenProvider accessTokenProvider;
  final bool allowInsecureTransport;
  final HttpClient _client;
  final Random _secureRandom = Random.secure();
  final Map<String, StudioProject> _projectCache = {};
  final Map<String, _CreateProjectIntent> _createProjectIntents = {};
  final Map<String, _AdoptScriptIntent> _adoptScriptIntents = {};
  final Map<String, _StartGenerationIntent> _startGenerationIntents = {};
  final Map<String, _JobRetryIntent> _jobRetryIntents = {};

  @override
  Future<List<StudioProject>> listProjects() async {
    final rawItems = await _listAllPageItems<StudioProject>(
      'projects',
      'ProjectPage',
      (value, _) => _projectFromMap(_requireMap(value, 'Project')),
    );
    final projects = <StudioProject>[];
    for (final project in rawItems) {
      final restored = await _restoreProject(project);
      _projectCache[restored.id] = restored;
      projects.add(restored);
    }
    return List.unmodifiable(projects);
  }

  @override
  Future<StudioProject> createProject({
    required String theme,
    String? title,
    String? idempotencyKey,
  }) async {
    final normalizedTitle = title?.trim();
    final name = _truncate(
      normalizedTitle?.isNotEmpty == true ? normalizedTitle! : theme.trim(),
      80,
    );
    final body = <String, Object?>{
      'name': name,
      'description': _truncate(theme.trim(), 500),
      'aspectRatio': '9:16',
    };
    final fingerprint = jsonEncode(body);
    var intent = _createProjectIntents[fingerprint];
    if (intent == null) {
      intent = _CreateProjectIntent(
        fingerprint: fingerprint,
        idempotencyKey: _validatedIdempotencyKey(
          idempotencyKey ?? _newIdempotencyKey(),
        ),
      );
      _createProjectIntents[fingerprint] = intent;
    }

    try {
      final response = await _request(
        'POST',
        'projects',
        body: body,
        mutation: true,
        idempotencyKey: intent.idempotencyKey,
      );
      final etag = _requireStrongResponseEtag(response, 'Project');
      final project = _projectFromMap(
        _requireMap(response.data, 'Project'),
        etag: etag,
      );
      _projectCache[project.id] = project;
      if (identical(_createProjectIntents[fingerprint], intent)) {
        _createProjectIntents.remove(fingerprint);
      }
      return project;
    } catch (error) {
      if (!_isAmbiguousMutationError(error) &&
          identical(_createProjectIntents[fingerprint], intent)) {
        _createProjectIntents.remove(fingerprint);
      }
      rethrow;
    }
  }

  @override
  Future<StudioProject> adoptScript({
    required String projectId,
    required String etag,
    required String sourceText,
    ScriptSummary? script,
    String? idempotencyKey,
  }) async {
    _requireStrongEtag(etag, 'Project');
    final body = <String, Object?>{
      'sourceType': script == null ? 'theme' : 'script',
      'sourceText': sourceText,
      'episodeCount': 1,
      if (script != null && script.styleBible.trim().isNotEmpty)
        'styleHint': script.styleBible.trim(),
    };
    final fingerprint = jsonEncode([projectId, body]);
    var intent = _adoptScriptIntents[fingerprint];
    if (intent == null) {
      intent = _AdoptScriptIntent(
        fingerprint: fingerprint,
        expectedEtag: etag,
        idempotencyKey: _validatedIdempotencyKey(
          idempotencyKey ?? _newIdempotencyKey(),
        ),
      );
      _adoptScriptIntents[fingerprint] = intent;
    }

    try {
      var job = intent.acceptedJob;
      if (job == null) {
        final response = await _request(
          'POST',
          'projects/${_segment(projectId)}/script-jobs',
          body: body,
          expectedEtag: intent.expectedEtag,
          mutation: true,
          idempotencyKey: intent.idempotencyKey,
        );
        job = _scriptJobFromMap(_requireMap(response.data, 'ScriptJob'));
        if (job.projectId != projectId) {
          throw const ApiContractException('ScriptJob.projectId 与请求项目不一致');
        }
        intent.acceptedJob = job;
      }
      var project = await _getProject(projectId);
      project = project.copyWith(
        latestScriptJobId: job.id,
        latestScriptJobStatus: job.status,
      );
      project = _attachScriptJob(project, job);
      _projectCache[project.id] = project;
      if (identical(_adoptScriptIntents[fingerprint], intent)) {
        _adoptScriptIntents.remove(fingerprint);
      }
      return project;
    } catch (error) {
      if (intent.acceptedJob == null &&
          !_isAmbiguousMutationError(error) &&
          identical(_adoptScriptIntents[fingerprint], intent)) {
        _adoptScriptIntents.remove(fingerprint);
      }
      rethrow;
    }
  }

  @override
  Future<StudioProject> startGeneration({
    required String projectId,
    required String etag,
    bool onlyMissing = true,
    List<String>? shotIds,
    String? idempotencyKey,
  }) async {
    _requireStrongEtag(etag, 'Project');
    var project = _projectCache[projectId] ?? await _getProject(projectId);
    final scriptJobId = project.latestScriptJobId;
    if (scriptJobId == null || scriptJobId.isEmpty) {
      throw StateError('项目尚未创建剧本任务');
    }
    final scriptJob = await _getScriptJob(
      scriptJobId,
      expectedProjectId: projectId,
    );
    if (scriptJob.status != StudioStatus.succeeded ||
        scriptJob.result == null) {
      throw StateError('剧本生成尚未完成，请稍后刷新');
    }
    project = _attachScriptJob(project, scriptJob);
    final availableShotIds = _scriptShotIds(scriptJob.result!);
    final targetShotIds = _selectShotIds(shotIds, availableShotIds);
    final planBody = <String, Object?>{
      'scriptJobId': scriptJobId,
      'providerStrategy': 'automatic',
      'shotIds': targetShotIds,
      'regenerateExisting': !onlyMissing,
    };
    final fingerprint = jsonEncode(planBody);
    var intent = _startGenerationIntents[projectId];
    if (intent == null || intent.fingerprint != fingerprint) {
      intent = _StartGenerationIntent(
        fingerprint: fingerprint,
        baseIdempotencyKey: _validatedIdempotencyKey(
          idempotencyKey ?? _newIdempotencyKey(),
        ),
      );
      intent
        ..planIdempotencyKey = _phaseIdempotencyKey(
          intent.baseIdempotencyKey,
          'plan',
        )
        ..runIdempotencyKey = _phaseIdempotencyKey(
          intent.baseIdempotencyKey,
          'run',
        );
      _startGenerationIntents[projectId] = intent;
    }

    try {
      if (intent.planId == null) {
        final planResponse = await _request(
          'POST',
          'projects/${_segment(projectId)}/generation-plans',
          body: planBody,
          expectedEtag: etag,
          mutation: true,
          idempotencyKey: intent.planIdempotencyKey,
        );
        final planEtag = _requireStrongResponseEtag(
          planResponse,
          'GenerationPlan',
        );
        final plan = _generationPlanFromMap(
          _requireMap(planResponse.data, 'GenerationPlan'),
        );
        _requireStringMatch(plan, 'projectId', projectId, 'GenerationPlan');
        _requireStringMatch(plan, 'scriptJobId', scriptJobId, 'GenerationPlan');
        _requireSameStringItems(
          _requiredStringList(plan, 'shotIds', 'GenerationPlan', minItems: 1),
          targetShotIds,
          'GenerationPlan.shotIds',
        );
        intent
          ..planId = _requiredString(plan, 'id', 'GenerationPlan')
          ..planEtag = planEtag;
      }

      if (intent.runId == null) {
        final runResponse = await _request(
          'POST',
          'generation-plans/${_segment(intent.planId!)}/runs',
          body: const {'stopOnQuotaError': true},
          expectedEtag: intent.planEtag,
          mutation: true,
          idempotencyKey: intent.runIdempotencyKey,
        );
        final acceptedRunMap = _requireMap(runResponse.data, 'GenerationRun');
        _requireStringMatch(
          acceptedRunMap,
          'planId',
          intent.planId!,
          'GenerationRun',
        );
        _requireStringMatch(
          acceptedRunMap,
          'projectId',
          projectId,
          'GenerationRun',
        );
        final acceptedRun = _runFromMap(acceptedRunMap);
        intent.runId = acceptedRun.id;
      }

      final run = await _getRun(
        intent.runId!,
        expectedProjectId: projectId,
        expectedPlanId: intent.planId,
      );
      project = await _getProject(projectId);
      project = _attachScriptJob(
        project,
        scriptJob,
      ).copyWith(currentRun: run, activeRunId: run.id);
      _projectCache[projectId] = project;
      if (identical(_startGenerationIntents[projectId], intent)) {
        _startGenerationIntents.remove(projectId);
      }
      return project;
    } catch (error) {
      if (!_shouldRetainStartIntent(error, intent) &&
          identical(_startGenerationIntents[projectId], intent)) {
        _startGenerationIntents.remove(projectId);
      }
      rethrow;
    }
  }

  @override
  Future<StudioProject> pauseGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  }) => _changeRunState(
    projectId: projectId,
    runId: runId,
    runEtag: runEtag,
    action: 'pause',
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<StudioProject> resumeGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  }) => _changeRunState(
    projectId: projectId,
    runId: runId,
    runEtag: runEtag,
    action: 'resume',
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<StudioProject> cancelGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  }) => _changeRunState(
    projectId: projectId,
    runId: runId,
    runEtag: runEtag,
    action: 'cancel',
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<StudioProject> retryFailedTasks({
    required String projectId,
    required String runId,
    String? idempotencyKey,
  }) async {
    await _getRun(runId, expectedProjectId: projectId);
    final jobs = await _listJobs(runId);
    final intents = _jobRetryIntents.values
        .where(
          (intent) => intent.projectId == projectId && intent.runId == runId,
        )
        .toList();
    for (final failed in jobs.where(
      (task) => task.status == StudioStatus.failed,
    )) {
      final intent = await _getOrCreateJobRetryIntent(
        projectId: projectId,
        runId: runId,
        jobId: failed.id,
        idempotencyKey: idempotencyKey,
      );
      if (!intents.contains(intent)) intents.add(intent);
    }
    for (final intent in intents) {
      await _postJobRetry(intent);
    }
    final project = await _refreshRunProject(projectId, runId);
    _clearJobRetryIntents(projectId, runId);
    return project;
  }

  @override
  Future<StudioProject> retryTask({
    required String projectId,
    required String runId,
    required String taskId,
    String? idempotencyKey,
  }) async {
    await _getRun(runId, expectedProjectId: projectId);
    final intent = await _getOrCreateJobRetryIntent(
      projectId: projectId,
      runId: runId,
      jobId: taskId,
      idempotencyKey: idempotencyKey,
    );
    await _postJobRetry(intent);
    final project = await _refreshRunProject(projectId, runId);
    if (identical(_jobRetryIntents[intent.mapKey], intent)) {
      _jobRetryIntents.remove(intent.mapKey);
    }
    return project;
  }

  Future<StudioProject> _refreshRunProject(
    String projectId,
    String runId,
  ) async {
    final run = (await _getRun(
      runId,
      expectedProjectId: projectId,
    )).copyWith(tasks: await _listJobs(runId));
    final project = (await _getProject(
      projectId,
    )).copyWith(currentRun: run, activeRunId: run.id);
    _projectCache[projectId] = project;
    return project;
  }

  @override
  Future<StudioProject> refreshProject(String projectId) async {
    final project = await _restoreProject(await _getProject(projectId));
    _projectCache[projectId] = project;
    return project;
  }

  Future<StudioProject> _changeRunState({
    required String projectId,
    required String runId,
    required String runEtag,
    required String action,
    String? idempotencyKey,
  }) async {
    _requireStrongEtag(runEtag, 'GenerationRun');
    final current = await _getRun(runId, expectedProjectId: projectId);
    if (current.etag != runEtag) {
      throw StateError('生成运行版本已变化，请刷新后重试');
    }
    await _request(
      'POST',
      'generation-runs/${_segment(runId)}/actions',
      body: {'action': action},
      expectedEtag: runEtag,
      mutation: true,
      idempotencyKey: idempotencyKey,
    );
    final run = (await _getRun(
      runId,
      expectedProjectId: projectId,
    )).copyWith(tasks: await _listJobs(runId));
    final project = (await _getProject(
      projectId,
    )).copyWith(currentRun: run, activeRunId: run.id);
    _projectCache[projectId] = project;
    return project;
  }

  Future<StudioProject> _getProject(String projectId) async {
    final response = await _request('GET', 'projects/${_segment(projectId)}');
    final etag = _requireStrongResponseEtag(response, 'Project');
    var project = _projectFromMap(
      _requireMap(response.data, 'Project'),
      etag: etag,
    );
    if (project.id != projectId) {
      throw const ApiContractException('Project.id 与请求资源不一致');
    }
    final cached = _projectCache[projectId];
    if (cached != null) {
      final sameScript = cached.latestScriptJobId == project.latestScriptJobId;
      final sameRun = cached.activeRunId == project.activeRunId;
      final sameExport = cached.latestExportId == project.latestExportId;
      project = project.copyWith(
        script: sameScript ? cached.script : null,
        characters: sameScript ? cached.characters : const [],
        scenes: sameScript ? cached.scenes : const [],
        props: sameScript ? cached.props : const [],
        shots: sameScript ? cached.shots : const [],
        voiceLines: sameScript ? cached.voiceLines : const [],
        latestScriptJobStatus: sameScript ? cached.latestScriptJobStatus : null,
        currentRun: sameRun ? cached.currentRun : null,
        exports: sameExport ? cached.exports : const [],
      );
    }
    _projectCache[projectId] = project;
    return project;
  }

  Future<_ScriptJobPayload> _getScriptJob(
    String scriptJobId, {
    String? expectedProjectId,
  }) async {
    final response = await _request(
      'GET',
      'script-jobs/${_segment(scriptJobId)}',
    );
    final job = _scriptJobFromMap(_requireMap(response.data, 'ScriptJob'));
    if (job.id != scriptJobId) {
      throw const ApiContractException('ScriptJob.id 与请求资源不一致');
    }
    if (expectedProjectId != null && job.projectId != expectedProjectId) {
      throw const ApiContractException('ScriptJob.projectId 与请求项目不一致');
    }
    return job;
  }

  Future<GenerationRun> _getRun(
    String runId, {
    String? expectedProjectId,
    String? expectedPlanId,
  }) async {
    final response = await _request(
      'GET',
      'generation-runs/${_segment(runId)}',
    );
    final etag = _requireStrongResponseEtag(response, 'GenerationRun');
    final run = _runFromMap(
      _requireMap(response.data, 'GenerationRun'),
      etag: etag,
    );
    if (run.id != runId) {
      throw const ApiContractException('GenerationRun.id 与请求资源不一致');
    }
    if (expectedProjectId != null && run.projectId != expectedProjectId) {
      throw const ApiContractException('GenerationRun.projectId 与请求项目不一致');
    }
    if (expectedPlanId != null && run.planId != expectedPlanId) {
      throw const ApiContractException('GenerationRun.planId 与生成计划不一致');
    }
    return run;
  }

  Future<List<GenerationTask>> _listJobs(String runId) async {
    final items = await _listAllPageItems<GenerationTask>(
      'generation-runs/${_segment(runId)}/jobs',
      'GenerationJobPage',
      (value, sequence) {
        final map = _requireMap(value, 'GenerationJob');
        _requireStringMatch(map, 'runId', runId, 'GenerationJob');
        return _taskFromMap(map).copyWith(sequence: sequence);
      },
    );
    return List.unmodifiable(items);
  }

  Future<GenerationTask> _getJob(String jobId, {String? expectedRunId}) async {
    final response = await _request(
      'GET',
      'generation-jobs/${_segment(jobId)}',
    );
    final etag = _requireStrongResponseEtag(response, 'GenerationJob');
    final map = _requireMap(response.data, 'GenerationJob');
    _requireStringMatch(map, 'id', jobId, 'GenerationJob');
    if (expectedRunId != null) {
      _requireStringMatch(map, 'runId', expectedRunId, 'GenerationJob');
    }
    return _taskFromMap(map, etag: etag);
  }

  Future<_JobRetryIntent> _getOrCreateJobRetryIntent({
    required String projectId,
    required String runId,
    required String jobId,
    String? idempotencyKey,
  }) async {
    final mapKey = jsonEncode([projectId, runId, jobId]);
    final existing = _jobRetryIntents[mapKey];
    if (existing != null) return existing;

    final baseKey = _validatedIdempotencyKey(
      idempotencyKey ?? _newIdempotencyKey(),
    );
    final current = await _getJob(jobId, expectedRunId: runId);
    final jobEtag = current.etag;
    if (jobEtag == null) {
      throw const ApiContractException('GenerationJob GET 未返回强 ETag');
    }
    final intent = _JobRetryIntent(
      mapKey: mapKey,
      projectId: projectId,
      runId: runId,
      jobId: jobId,
      expectedEtag: jobEtag,
      idempotencyKey: _phaseIdempotencyKey(
        baseKey,
        'job-${_stableKeyHash(mapKey)}',
      ),
    );
    _jobRetryIntents[mapKey] = intent;
    return intent;
  }

  Future<void> _postJobRetry(_JobRetryIntent intent) async {
    if (intent.accepted) return;
    try {
      final response = await _request(
        'POST',
        'generation-jobs/${_segment(intent.jobId)}/actions',
        body: const {'action': 'retry'},
        expectedEtag: intent.expectedEtag,
        mutation: true,
        idempotencyKey: intent.idempotencyKey,
      );
      final acceptedMap = _requireMap(response.data, 'GenerationJob');
      _requireStringMatch(acceptedMap, 'id', intent.jobId, 'GenerationJob');
      _requireStringMatch(acceptedMap, 'runId', intent.runId, 'GenerationJob');
      _taskFromMap(acceptedMap);
      intent.accepted = true;
    } catch (error) {
      if (!_isAmbiguousMutationError(error) &&
          identical(_jobRetryIntents[intent.mapKey], intent)) {
        _jobRetryIntents.remove(intent.mapKey);
      }
      rethrow;
    }
  }

  void _clearJobRetryIntents(String projectId, String runId) {
    _jobRetryIntents.removeWhere(
      (_, intent) => intent.projectId == projectId && intent.runId == runId,
    );
  }

  Future<StudioProject> _restoreProject(StudioProject project) async {
    var restored = project;
    final scriptJobId = restored.latestScriptJobId;
    if (scriptJobId != null && scriptJobId.isNotEmpty) {
      restored = _attachScriptJob(
        restored,
        await _getScriptJob(scriptJobId, expectedProjectId: restored.id),
      );
    }

    final activeRunId = restored.activeRunId;
    if (activeRunId != null && activeRunId.isNotEmpty) {
      final run = (await _getRun(
        activeRunId,
        expectedProjectId: restored.id,
      )).copyWith(tasks: await _listJobs(activeRunId));
      restored = restored.copyWith(currentRun: run);
    }

    final latestExportId = restored.latestExportId;
    if (latestExportId != null && latestExportId.isNotEmpty) {
      final exports = (await _listExports(restored.id)).toList();
      if (!exports.any((export) => export.id == latestExportId)) {
        exports.add(
          await _getExport(latestExportId, expectedProjectId: restored.id),
        );
      }
      final hydrated = <StudioExport>[];
      for (final export in exports) {
        hydrated.add(
          await _hydrateExport(export, expectedProjectId: restored.id),
        );
      }
      restored = restored.copyWith(exports: hydrated);
    }
    return restored;
  }

  Future<List<StudioExport>> _listExports(String projectId) async {
    final items = await _listAllPageItems<StudioExport>(
      'projects/${_segment(projectId)}/exports',
      'ExportPage',
      (value, _) {
        final map = _requireMap(value, 'Export');
        _requireStringMatch(map, 'projectId', projectId, 'Export');
        return _exportFromMap(map);
      },
    );
    return List.unmodifiable(items);
  }

  Future<List<T>> _listAllPageItems<T>(
    String basePath,
    String schema,
    T Function(Object? value, int index) parseItem,
  ) async {
    final items = <T>[];
    final seenCursors = <String>{};
    String? cursor;
    for (var pageCount = 0; pageCount < maxPaginationPages; pageCount++) {
      final response = await _request('GET', _pagePath(basePath, cursor));
      final page = _requireMap(response.data, schema);
      final rawItems = page['items'];
      if (rawItems is! List) {
        throw ApiContractException('$schema.items 缺失或格式无效');
      }
      if (items.length + rawItems.length > maxPaginationItems) {
        throw ApiContractException('$schema.items 超过安全上限');
      }
      for (final value in rawItems) {
        items.add(parseItem(value, items.length));
      }
      final next = _nextCursor(
        page['nextCursor'],
        basePath: basePath,
        schema: schema,
      );
      if (next == null) return List.unmodifiable(items);
      if (!seenCursors.add(next)) {
        throw ApiContractException('$schema.nextCursor 出现循环');
      }
      cursor = next;
    }
    throw ApiContractException('$schema 分页超过安全上限');
  }

  String _pagePath(String basePath, String? cursor) =>
      '$basePath?limit=100'
      '${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}';

  String? _nextCursor(
    Object? value, {
    required String basePath,
    required String schema,
  }) {
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw ApiContractException('$schema.nextCursor 格式无效');
    }
    var cursor = value.trim();
    final parsed = Uri.tryParse(cursor);
    final isHttpUri =
        parsed != null &&
        (parsed.hasAuthority ||
            parsed.scheme.toLowerCase() == 'http' ||
            parsed.scheme.toLowerCase() == 'https');
    if (isHttpUri) {
      final candidate = parsed;
      final absolute = candidate.hasScheme
          ? candidate
          : baseUri.resolveUri(candidate);
      if (!_sameOrigin(absolute, baseUri)) {
        throw ApiContractException('$schema.nextCursor 不得跨主机');
      }
      final expectedPath = _resolve(basePath).path;
      if (absolute.path != expectedPath) {
        throw ApiContractException('$schema.nextCursor 路径无效');
      }
      cursor = absolute.queryParameters['cursor']?.trim() ?? '';
      if (cursor.isEmpty) {
        throw ApiContractException('$schema.nextCursor 缺少 cursor 参数');
      }
    }
    return cursor;
  }

  bool _sameOrigin(Uri left, Uri right) =>
      left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
      left.host.toLowerCase() == right.host.toLowerCase() &&
      left.port == right.port;

  Future<StudioExport> _getExport(
    String exportId, {
    String? expectedProjectId,
  }) async {
    final response = await _request('GET', 'exports/${_segment(exportId)}');
    _requireStrongResponseEtag(response, 'Export');
    final map = _requireMap(response.data, 'Export');
    _requireStringMatch(map, 'id', exportId, 'Export');
    if (expectedProjectId != null) {
      _requireStringMatch(map, 'projectId', expectedProjectId, 'Export');
    }
    return _exportFromMap(map);
  }

  Future<StudioExport> _hydrateExport(
    StudioExport export, {
    required String expectedProjectId,
  }) async {
    var previewUrl = export.previewUrl;
    var assetReady = export.assetId == null;
    final assetId = export.assetId;
    if (assetId != null && assetId.isNotEmpty) {
      final response = await _request('GET', 'assets/${_segment(assetId)}');
      _requireStrongResponseEtag(response, 'Asset');
      final asset = _requireMap(response.data, 'Asset');
      _validateAssetMap(asset);
      _requireStringMatch(asset, 'id', assetId, 'Asset');
      _requireStringMatch(asset, 'projectId', expectedProjectId, 'Asset');
      previewUrl = _nullableString(asset['previewUrl'] ?? asset['preview_url']);
      assetReady = asset['status']?.toString().toLowerCase() == 'ready';
    }

    var downloadUrl = export.downloadUrl;
    final completed =
        export.status == StudioStatus.succeeded ||
        export.status == StudioStatus.completed;
    if (completed) {
      final response = await _request(
        'GET',
        'exports/${_segment(export.id)}/download',
      );
      final ticket = _requireMap(response.data, 'DownloadTicket');
      _validateDownloadTicket(ticket);
      downloadUrl = _requiredString(ticket, 'url', 'DownloadTicket');
    }
    final ready = completed && assetReady && downloadUrl != null;
    return export.copyWith(
      videoUrl: previewUrl ?? downloadUrl,
      previewUrl: previewUrl,
      downloadUrl: downloadUrl,
      ready: ready,
    );
  }

  StudioProject _projectFromMap(Map<String, Object?> map, {String? etag}) {
    for (final key in [
      'id',
      'name',
      'aspectRatio',
      'latestScriptJobId',
      'activeRunId',
      'latestExportId',
      'revision',
      'createdAt',
      'updatedAt',
    ]) {
      if (!map.containsKey(key)) throw ApiContractException('Project.$key 缺失');
    }
    _requiredString(map, 'id', 'Project');
    _requiredString(map, 'name', 'Project');
    _requiredString(map, 'aspectRatio', 'Project');
    _nullableId(map, 'activeRunId', 'Project');
    _nullableId(map, 'latestExportId', 'Project');
    _nullableId(map, 'latestScriptJobId', 'Project');
    _requiredRevision(map, 'revision', 'Project');
    _requiredTimestamp(map, 'createdAt', 'Project');
    _requiredTimestamp(map, 'updatedAt', 'Project');
    return StudioProject.fromJson({...map, if (etag != null) 'etag': etag});
  }

  Map<String, Object?> _generationPlanFromMap(Map<String, Object?> map) {
    for (final key in [
      'id',
      'projectId',
      'scriptJobId',
      'providerStrategy',
      'shotIds',
      'revision',
      'createdAt',
    ]) {
      if (!map.containsKey(key)) {
        throw ApiContractException('GenerationPlan.$key 缺失');
      }
    }
    _requiredString(map, 'id', 'GenerationPlan');
    _requiredString(map, 'projectId', 'GenerationPlan');
    _requiredString(map, 'scriptJobId', 'GenerationPlan');
    _requiredEnumString(map, 'providerStrategy', 'GenerationPlan', const {
      'bailian',
      'wan22',
      'automatic',
    });
    _requiredStringList(map, 'shotIds', 'GenerationPlan', minItems: 1);
    _requiredRevision(map, 'revision', 'GenerationPlan');
    _requiredTimestamp(map, 'createdAt', 'GenerationPlan');
    return map;
  }

  GenerationRun _runFromMap(Map<String, Object?> map, {String? etag}) {
    for (final key in [
      'id',
      'planId',
      'projectId',
      'status',
      'progress',
      'completedJobs',
      'totalJobs',
      'revision',
      'createdAt',
      'updatedAt',
    ]) {
      if (!map.containsKey(key)) {
        throw ApiContractException('GenerationRun.$key 缺失');
      }
    }
    _requiredString(map, 'id', 'GenerationRun');
    _requiredString(map, 'planId', 'GenerationRun');
    _requiredString(map, 'projectId', 'GenerationRun');
    _requiredJobStatus(map, 'status', 'GenerationRun');
    if (map['currentStage'] != null) {
      _requiredGenerationTaskType(map, 'currentStage', 'GenerationRun');
    }
    _requiredIntInRange(map, 'progress', 'GenerationRun', min: 0, max: 100);
    _requiredIntInRange(map, 'completedJobs', 'GenerationRun', min: 0);
    _requiredIntInRange(map, 'totalJobs', 'GenerationRun', min: 0);
    _requiredRevision(map, 'revision', 'GenerationRun');
    _requiredTimestamp(map, 'createdAt', 'GenerationRun');
    _requiredTimestamp(map, 'updatedAt', 'GenerationRun');
    return GenerationRun.fromJson({...map, if (etag != null) 'etag': etag});
  }

  GenerationTask _taskFromMap(Map<String, Object?> map, {String? etag}) {
    for (final key in [
      'id',
      'runId',
      'stage',
      'status',
      'progress',
      'attempt',
      'revision',
      'createdAt',
      'updatedAt',
    ]) {
      if (!map.containsKey(key)) {
        throw ApiContractException('GenerationJob.$key 缺失');
      }
    }
    _requiredString(map, 'id', 'GenerationJob');
    _requiredString(map, 'runId', 'GenerationJob');
    _requiredGenerationTaskType(map, 'stage', 'GenerationJob');
    _requiredJobStatus(map, 'status', 'GenerationJob');
    _requiredIntInRange(map, 'progress', 'GenerationJob', min: 0, max: 100);
    _requiredIntInRange(map, 'attempt', 'GenerationJob', min: 1);
    _requiredRevision(map, 'revision', 'GenerationJob');
    _requiredTimestamp(map, 'createdAt', 'GenerationJob');
    _requiredTimestamp(map, 'updatedAt', 'GenerationJob');
    if (map.containsKey('shotId')) {
      _nullableId(map, 'shotId', 'GenerationJob');
    }
    return GenerationTask.fromJson({...map, if (etag != null) 'etag': etag});
  }

  StudioExport _exportFromMap(Map<String, Object?> map) {
    for (final key in [
      'id',
      'projectId',
      'runId',
      'status',
      'progress',
      'revision',
      'createdAt',
      'updatedAt',
    ]) {
      if (!map.containsKey(key)) {
        throw ApiContractException('Export.$key 缺失');
      }
    }
    _requiredString(map, 'id', 'Export');
    _requiredString(map, 'projectId', 'Export');
    _requiredString(map, 'runId', 'Export');
    _requiredJobStatus(map, 'status', 'Export');
    _requiredIntInRange(map, 'progress', 'Export', min: 0, max: 100);
    _requiredRevision(map, 'revision', 'Export');
    _requiredTimestamp(map, 'createdAt', 'Export');
    _requiredTimestamp(map, 'updatedAt', 'Export');
    if (map.containsKey('assetId')) {
      _nullableId(map, 'assetId', 'Export');
    }
    return StudioExport.fromJson(map);
  }

  _ScriptJobPayload _scriptJobFromMap(Map<String, Object?> map) {
    for (final key in [
      'id',
      'projectId',
      'status',
      'progress',
      'createdAt',
      'updatedAt',
    ]) {
      if (!map.containsKey(key)) {
        throw ApiContractException('ScriptJob.$key 缺失');
      }
    }
    _requiredString(map, 'id', 'ScriptJob');
    _requiredString(map, 'projectId', 'ScriptJob');
    _requiredJobStatus(map, 'status', 'ScriptJob');
    _requiredIntInRange(map, 'progress', 'ScriptJob', min: 0, max: 100);
    _requiredTimestamp(map, 'createdAt', 'ScriptJob');
    _requiredTimestamp(map, 'updatedAt', 'ScriptJob');
    final rawResult = map['result'];
    if (rawResult != null) {
      final result = _nullableMap(rawResult);
      if (result == null) {
        throw const ApiContractException('ScriptJob.result 格式无效');
      }
      _validateScriptDraft(result);
    }
    return _ScriptJobPayload(
      id: _requiredString(map, 'id', 'ScriptJob'),
      projectId: _requiredString(map, 'projectId', 'ScriptJob'),
      status: StudioStatus.fromJson(map['status']),
      progress: _requiredInt(map, 'progress', 'ScriptJob'),
      result: _nullableMap(map['result']),
    );
  }

  void _validateScriptDraft(Map<String, Object?> draft) {
    for (final key in [
      'title',
      'logline',
      'styleBible',
      'characters',
      'scenes',
      'episodes',
    ]) {
      if (!draft.containsKey(key)) {
        throw ApiContractException('ScriptDraft.$key 缺失');
      }
    }
    _requiredString(draft, 'title', 'ScriptDraft');
    _requiredString(draft, 'logline', 'ScriptDraft');
    _requiredString(draft, 'styleBible', 'ScriptDraft');
    for (final field in ['characters', 'scenes', 'props']) {
      if (field == 'props' && !draft.containsKey(field)) continue;
      final entities = _requiredMapList(draft, field, 'ScriptDraft');
      for (final entity in entities) {
        _requiredString(entity, 'id', 'CanonicalEntity');
        _requiredString(entity, 'name', 'CanonicalEntity');
        _requiredString(entity, 'lock', 'CanonicalEntity');
      }
    }
    final episodes = _requiredMapList(draft, 'episodes', 'ScriptDraft');
    for (final episode in episodes) {
      _requiredString(episode, 'id', 'Episode');
      _requiredString(episode, 'title', 'Episode');
      final shots = _requiredMapList(episode, 'shots', 'Episode', minItems: 1);
      for (final shot in shots) {
        _requiredString(shot, 'id', 'Shot');
        _requiredString(shot, 'sceneId', 'Shot');
        _requiredString(shot, 'visualPrompt', 'Shot');
        final duration = _requiredDouble(shot, 'durationSeconds', 'Shot');
        if (duration < 1 || duration > 15) {
          throw const ApiContractException(
            'Shot.durationSeconds 必须在 1 到 15 之间',
          );
        }
        if (shot.containsKey('characterIds')) {
          _requiredStringList(shot, 'characterIds', 'Shot');
        }
      }
    }
  }

  void _validateAssetMap(Map<String, Object?> asset) {
    for (final key in [
      'id',
      'projectId',
      'kind',
      'status',
      'contentType',
      'sizeBytes',
      'revision',
      'createdAt',
    ]) {
      if (!asset.containsKey(key)) throw ApiContractException('Asset.$key 缺失');
    }
    _requiredString(asset, 'id', 'Asset');
    _requiredString(asset, 'projectId', 'Asset');
    _requiredEnumString(asset, 'kind', 'Asset', const {
      'character',
      'scene',
      'prop',
      'storyboard',
      'video',
      'voice',
      'music',
      'subtitle',
      'export',
    });
    _requiredEnumString(asset, 'status', 'Asset', const {
      'uploading',
      'validating',
      'ready',
      'rejected',
      'deleted',
    });
    _requiredString(asset, 'contentType', 'Asset');
    _requiredIntInRange(asset, 'sizeBytes', 'Asset', min: 0);
    _requiredRevision(asset, 'revision', 'Asset');
    _requiredTimestamp(asset, 'createdAt', 'Asset');
  }

  void _validateDownloadTicket(Map<String, Object?> ticket) {
    _requiredUriString(ticket, 'url', 'DownloadTicket');
    _requiredTimestamp(ticket, 'expiresAt', 'DownloadTicket');
    final sha256 = _requiredString(ticket, 'sha256', 'DownloadTicket');
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const ApiContractException('DownloadTicket.sha256 格式无效');
    }
  }

  StudioProject _attachScriptJob(StudioProject project, _ScriptJobPayload job) {
    final draft = job.result;
    var updated = project.copyWith(
      latestScriptJobId: job.id,
      latestScriptJobStatus: job.status,
    );
    if (draft == null) return updated;
    final episodes = _listOfMaps(draft['episodes']);
    final rawShots = <Map<String, Object?>>[];
    for (final episode in episodes) {
      rawShots.addAll(_listOfMaps(episode['shots']));
    }
    final existingCharacters = {
      for (final asset in project.characters) asset.id: asset,
    };
    final existingScenes = {
      for (final asset in project.scenes) asset.id: asset,
    };
    final existingProps = {for (final asset in project.props) asset.id: asset};
    final existingShots = {for (final shot in project.shots) shot.id: shot};
    final existingVoiceLines = {
      for (final line in project.voiceLines) line.id: line,
    };
    final characters = _listOfMaps(draft['characters']).map((entity) {
      final id = _requiredString(entity, 'id', 'CanonicalEntity');
      final existing = existingCharacters[id];
      return CharacterAsset(
        id: id,
        name: _requiredString(entity, 'name', 'CanonicalEntity'),
        description: existing?.description ?? '',
        visualLock: _requiredString(entity, 'lock', 'CanonicalEntity'),
        imageUrl: existing?.imageUrl,
        status: existing?.status ?? StudioStatus.pending,
        revision: existing?.revision ?? 0,
      );
    }).toList();
    final scenes = _listOfMaps(draft['scenes']).map((entity) {
      final id = _requiredString(entity, 'id', 'CanonicalEntity');
      final existing = existingScenes[id];
      return SceneAsset(
        id: id,
        name: _requiredString(entity, 'name', 'CanonicalEntity'),
        description: existing?.description ?? '',
        visualLock: _requiredString(entity, 'lock', 'CanonicalEntity'),
        imageUrl: existing?.imageUrl,
        status: existing?.status ?? StudioStatus.pending,
        revision: existing?.revision ?? 0,
      );
    }).toList();
    final props = _listOfMaps(draft['props']).map((entity) {
      final id = _requiredString(entity, 'id', 'CanonicalEntity');
      final existing = existingProps[id];
      return PropAsset(
        id: id,
        name: _requiredString(entity, 'name', 'CanonicalEntity'),
        description: existing?.description ?? '',
        visualLock: _requiredString(entity, 'lock', 'CanonicalEntity'),
        imageUrl: existing?.imageUrl,
        status: existing?.status ?? StudioStatus.pending,
        revision: existing?.revision ?? 0,
      );
    }).toList();
    final shots = rawShots.indexed.map((entry) {
      final shot = entry.$2;
      final id = _requiredString(shot, 'id', 'Shot');
      final existing = existingShots[id];
      return Shot(
        id: id,
        order: entry.$1 + 1,
        title: '镜头 ${entry.$1 + 1}',
        prompt: _requiredString(shot, 'visualPrompt', 'Shot'),
        durationSeconds: _requiredDouble(shot, 'durationSeconds', 'Shot'),
        sceneId: _requiredString(shot, 'sceneId', 'Shot'),
        characterIds: _stringList(shot['characterIds']),
        propIds: _stringList(shot['propIds']),
        firstFrameUrl: existing?.firstFrameUrl,
        lastFrameUrl: existing?.lastFrameUrl,
        videoUrl: existing?.videoUrl,
        status: existing?.status ?? StudioStatus.pending,
        revision: existing?.revision ?? 0,
      );
    }).toList();
    final voiceLines = <VoiceLine>[];
    for (final entry in rawShots.indexed) {
      final dialogue = entry.$2['dialogue']?.toString().trim();
      if (dialogue != null && dialogue.isNotEmpty) {
        final shotId = _requiredString(entry.$2, 'id', 'Shot');
        final id = '$shotId-dialogue';
        final existing = existingVoiceLines[id];
        voiceLines.add(
          VoiceLine(
            id: id,
            shotId: shotId,
            speaker: existing?.speaker ?? '说话人未返回',
            text: dialogue,
            voiceName: existing?.voiceName ?? '声线未返回',
            characterId: existing?.characterId,
            audioUrl: existing?.audioUrl,
            status: existing?.status ?? StudioStatus.pending,
            revision: existing?.revision ?? 0,
          ),
        );
      }
    }
    final script = ScriptSummary(
      id: job.id,
      title: _requiredString(draft, 'title', 'ScriptDraft'),
      logline: _requiredString(draft, 'logline', 'ScriptDraft'),
      styleBible: _requiredString(draft, 'styleBible', 'ScriptDraft'),
      episodeSynopsis: episodes
          .map((episode) => episode['title']?.toString() ?? '')
          .where((title) => title.isNotEmpty)
          .join(' · '),
    );
    updated = updated.copyWith(
      script: script,
      characters: characters,
      scenes: scenes,
      props: props,
      shots: shots,
      voiceLines: voiceLines,
    );
    return updated;
  }

  List<String> _scriptShotIds(Map<String, Object?> draft) =>
      _listOfMaps(
        draft['episodes'],
      ).expand((episode) => _listOfMaps(episode['shots'])).map((shot) {
        return _requiredString(shot, 'id', 'Shot');
      }).toList();

  List<String> _selectShotIds(
    List<String>? requestedShotIds,
    List<String> availableShotIds,
  ) {
    if (availableShotIds.isEmpty) {
      throw StateError('剧本结果没有可生成的镜头');
    }
    if (requestedShotIds == null) return List.unmodifiable(availableShotIds);
    final selected = <String>[];
    for (final rawId in requestedShotIds) {
      final id = rawId.trim();
      if (id.isEmpty) {
        throw ArgumentError.value(requestedShotIds, 'shotIds', '镜头 ID 不能为空');
      }
      if (!selected.contains(id)) selected.add(id);
    }
    if (selected.isEmpty) {
      throw ArgumentError.value(requestedShotIds, 'shotIds', '至少选择一个镜头');
    }
    final available = availableShotIds.toSet();
    final unknown = selected.where((id) => !available.contains(id)).toList();
    if (unknown.isNotEmpty) {
      throw ArgumentError.value(
        requestedShotIds,
        'shotIds',
        '包含未知镜头：${unknown.join(', ')}',
      );
    }
    return List.unmodifiable(selected);
  }

  Future<_HttpPayload> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? expectedEtag,
    bool mutation = false,
    String? idempotencyKey,
  }) async {
    if (expectedEtag != null) _requireStrongEtag(expectedEtag, 'If-Match');
    final token = await accessTokenProvider().timeout(requestTimeout);
    if (token == null || token.trim().isEmpty) {
      throw const UnauthenticatedException();
    }
    final key = mutation
        ? _validatedIdempotencyKey(idempotencyKey ?? _newIdempotencyKey())
        : null;
    final request = await _client
        .openUrl(method, _resolve(path))
        .timeout(requestTimeout);
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, application/problem+json',
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${token.trim()}',
    );
    if (expectedEtag != null) {
      request.headers.set(HttpHeaders.ifMatchHeader, expectedEtag);
    }
    if (key != null) request.headers.set('Idempotency-Key', key);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close().timeout(requestTimeout);
    final bytes = await _readResponse(response);
    final text = utf8.decode(bytes, allowMalformed: true);
    Object? decoded;
    if (text.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw const ApiContractException('服务端返回了无效 JSON');
        }
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response.statusCode, decoded, text);
    }
    return _HttpPayload(
      data: decoded,
      etag: response.headers.value(HttpHeaders.etagHeader),
    );
  }

  Future<List<int>> _readResponse(HttpClientResponse response) async {
    if (response.contentLength > maxResponseBytes) {
      throw const ApiContractException('响应体超过 2 MiB 安全上限');
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(requestTimeout)) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const ApiContractException('响应体超过 2 MiB 安全上限');
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }

  ApiException _apiException(int statusCode, Object? decoded, String rawText) {
    final root = _nullableMap(decoded);
    final detail = root?['detail']?.toString().trim();
    final title = root?['title']?.toString().trim();
    final trimmed = rawText.trim();
    final fallback = trimmed.isEmpty
        ? '请求失败'
        : trimmed.substring(0, trimmed.length > 300 ? 300 : trimmed.length);
    return ApiException(
      statusCode: statusCode,
      message: detail?.isNotEmpty == true
          ? detail!
          : title?.isNotEmpty == true
          ? title!
          : fallback,
      code: root?['code']?.toString(),
      details: root,
      requestId:
          root?['requestId']?.toString() ?? root?['request_id']?.toString(),
      retryAfterSeconds: _nullableInt(root?['retryAfterSeconds']),
    );
  }

  String _requireStrongResponseEtag(_HttpPayload response, String resource) {
    final value = response.etag;
    if (value == null) throw ApiContractException('$resource 响应缺少 ETag');
    _requireStrongEtag(value, resource);
    return value;
  }

  void _requireStrongEtag(String value, String resource) {
    final trimmed = value.trim();
    if (trimmed.startsWith('W/') ||
        trimmed.length < 3 ||
        !trimmed.startsWith('"') ||
        !trimmed.endsWith('"')) {
      throw ApiContractException('$resource 必须使用服务端返回的强 ETag');
    }
  }

  String _validatedIdempotencyKey(String value) {
    if (value.length < 16 || value.length > 128) {
      throw const ApiContractException('Idempotency-Key 长度必须为 16 到 128');
    }
    return value;
  }

  String _phaseIdempotencyKey(String base, String phase) {
    final suffix = '-$phase';
    final candidate = '$base$suffix';
    if (candidate.length <= 128) return candidate;
    final hash = _stableKeyHash(base);
    final prefixLength = 128 - suffix.length - hash.length - 1;
    return '${base.substring(0, prefixLength)}-$hash$suffix';
  }

  String _stableKeyHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
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

  Uri _resolve(String path) {
    final text = baseUri.toString();
    final normalized = text.endsWith('/') ? baseUri : Uri.parse('$text/');
    return normalized.resolve(path);
  }

  String _segment(String value) => Uri.encodeComponent(value);

  String _truncate(String value, int maxRunes) =>
      String.fromCharCodes(value.runes.take(maxRunes));

  bool _shouldRetainStartIntent(Object error, _StartGenerationIntent intent) {
    if (intent.planId != null || intent.runId != null) return true;
    return _isAmbiguousMutationError(error);
  }

  bool _isAmbiguousMutationError(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is ApiContractException ||
        error is FormatException) {
      return true;
    }
    return error is ApiException &&
        (error.statusCode == HttpStatus.requestTimeout ||
            error.statusCode >= HttpStatus.internalServerError);
  }

  Map<String, Object?> _requireMap(Object? value, String schema) {
    final map = _nullableMap(value);
    if (map == null) throw ApiContractException('$schema 响应格式无效');
    return map;
  }

  Map<String, Object?>? _nullableMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  void _requireStringMatch(
    Map<String, Object?> map,
    String key,
    String expected,
    String schema,
  ) {
    if (_requiredString(map, key, schema) != expected) {
      throw ApiContractException('$schema.$key 与请求资源不一致');
    }
  }

  void _requireSameStringItems(
    List<String> actual,
    List<String> expected,
    String field,
  ) {
    if (actual.length != expected.length ||
        actual.toSet().length != expected.toSet().length ||
        !actual.toSet().containsAll(expected)) {
      throw ApiContractException('$field 与请求内容不一致');
    }
  }

  List<Map<String, Object?>> _listOfMaps(Object? value) => value is List
      ? value.map(_nullableMap).whereType<Map<String, Object?>>().toList()
      : const [];

  List<String> _stringList(Object? value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];

  String _requiredString(Map<String, Object?> map, String key, String schema) {
    final raw = map[key];
    if (raw is! String || raw.trim().isEmpty) {
      throw ApiContractException('$schema.$key 缺失或格式无效');
    }
    return raw.trim();
  }

  int _requiredInt(Map<String, Object?> map, String key, String schema) {
    final value = map[key];
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) {
      return value.toInt();
    }
    throw ApiContractException('$schema.$key 缺失或格式无效');
  }

  double _requiredDouble(Map<String, Object?> map, String key, String schema) {
    final value = map[key];
    if (value is num && value.isFinite) return value.toDouble();
    throw ApiContractException('$schema.$key 缺失或格式无效');
  }

  int _requiredIntInRange(
    Map<String, Object?> map,
    String key,
    String schema, {
    required int min,
    int? max,
  }) {
    final value = _requiredInt(map, key, schema);
    if (value < min || (max != null && value > max)) {
      throw ApiContractException('$schema.$key 超出允许范围');
    }
    return value;
  }

  int _requiredRevision(Map<String, Object?> map, String key, String schema) =>
      _requiredIntInRange(map, key, schema, min: 1);

  DateTime _requiredTimestamp(
    Map<String, Object?> map,
    String key,
    String schema,
  ) {
    final raw = map[key];
    if (raw is! String || raw.trim().isEmpty) {
      throw ApiContractException('$schema.$key 缺失或格式无效');
    }
    final value = DateTime.tryParse(raw);
    if (value == null || !raw.contains('T')) {
      throw ApiContractException('$schema.$key 缺失或格式无效');
    }
    return value;
  }

  String? _nullableId(Map<String, Object?> map, String key, String schema) {
    final raw = map[key];
    if (raw == null) return null;
    if (raw is! String || raw.trim().isEmpty) {
      throw ApiContractException('$schema.$key 格式无效');
    }
    return raw.trim();
  }

  StudioStatus _requiredJobStatus(
    Map<String, Object?> map,
    String key,
    String schema,
  ) {
    final value = _requiredEnumString(map, key, schema, const {
      'queued',
      'running',
      'paused',
      'succeeded',
      'failed',
      'canceled',
    });
    return StudioStatus.fromJson(value);
  }

  GenerationTaskType _requiredGenerationTaskType(
    Map<String, Object?> map,
    String key,
    String schema,
  ) {
    final value = _requiredEnumString(map, key, schema, const {
      'script',
      'character_images',
      'scene_images',
      'prop_images',
      'storyboard_images',
      'shot_videos',
      'voice_assignment',
      'voice_lines',
      'episode_export',
    });
    return GenerationTaskType.fromJson(value);
  }

  String _requiredEnumString(
    Map<String, Object?> map,
    String key,
    String schema,
    Set<String> allowed,
  ) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw ApiContractException('$schema.$key 缺失或格式无效');
    }
    if (!allowed.contains(value)) {
      throw ApiContractException('$schema.$key 值无效：$value');
    }
    return value;
  }

  List<String> _requiredStringList(
    Map<String, Object?> map,
    String key,
    String schema, {
    int minItems = 0,
  }) {
    final raw = map[key];
    if (raw is! List || raw.length < minItems) {
      throw ApiContractException('$schema.$key 缺失或格式无效');
    }
    final result = <String>[];
    for (final item in raw) {
      if (item is! String || item.trim().isEmpty) {
        throw ApiContractException('$schema.$key 包含无效值');
      }
      result.add(item.trim());
    }
    return List.unmodifiable(result);
  }

  List<Map<String, Object?>> _requiredMapList(
    Map<String, Object?> map,
    String key,
    String schema, {
    int minItems = 0,
  }) {
    final raw = map[key];
    if (raw is! List || raw.length < minItems) {
      throw ApiContractException('$schema.$key 缺失或格式无效');
    }
    final result = <Map<String, Object?>>[];
    for (final item in raw) {
      final mapped = _nullableMap(item);
      if (mapped == null) {
        throw ApiContractException('$schema.$key 包含无效对象');
      }
      result.add(mapped);
    }
    return List.unmodifiable(result);
  }

  Uri _requiredUriString(Map<String, Object?> map, String key, String schema) {
    final raw = _requiredString(map, key, schema);
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ApiContractException('$schema.$key 格式无效');
    }
    return uri;
  }

  int? _nullableInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void close({bool force = false}) => _client.close(force: force);
}

class _HttpPayload {
  const _HttpPayload({required this.data, this.etag});

  final Object? data;
  final String? etag;
}

class _ScriptJobPayload {
  const _ScriptJobPayload({
    required this.id,
    required this.projectId,
    required this.status,
    required this.progress,
    this.result,
  });

  final String id;
  final String projectId;
  final StudioStatus status;
  final int progress;
  final Map<String, Object?>? result;
}

class _StartGenerationIntent {
  _StartGenerationIntent({
    required this.fingerprint,
    required this.baseIdempotencyKey,
  });

  final String fingerprint;
  final String baseIdempotencyKey;
  late final String planIdempotencyKey;
  late final String runIdempotencyKey;
  String? planId;
  String? planEtag;
  String? runId;
}

class _CreateProjectIntent {
  const _CreateProjectIntent({
    required this.fingerprint,
    required this.idempotencyKey,
  });

  final String fingerprint;
  final String idempotencyKey;
}

class _AdoptScriptIntent {
  _AdoptScriptIntent({
    required this.fingerprint,
    required this.expectedEtag,
    required this.idempotencyKey,
  });

  final String fingerprint;
  final String expectedEtag;
  final String idempotencyKey;
  _ScriptJobPayload? acceptedJob;
}

class _JobRetryIntent {
  _JobRetryIntent({
    required this.mapKey,
    required this.projectId,
    required this.runId,
    required this.jobId,
    required this.expectedEtag,
    required this.idempotencyKey,
  });

  final String mapKey;
  final String projectId;
  final String runId;
  final String jobId;
  final String expectedEtag;
  final String idempotencyKey;
  bool accepted = false;
}
