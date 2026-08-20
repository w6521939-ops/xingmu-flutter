import '../../domain/generation_planner.dart';
import '../../domain/studio_models.dart';
import '../../domain/studio_repository.dart';
import '../../domain/studio_status.dart';
import '../../domain/studio_validation.dart';

class DemoStudioRepository implements StudioRepository, DemoStudioDriver {
  DemoStudioRepository({
    this.seedDemoProject = false,
    Set<GenerationTaskType> failOnce = const {},
  }) : _failOnce = Set.unmodifiable(failOnce) {
    if (seedDemoProject) {
      final project = _newProject(
        theme: '月球快递员在最后一班飞船上拯救一只会说话的猫',
        title: '月背最后一单',
      );
      _projects[project.id] = project;
    }
  }

  final bool seedDemoProject;
  final Set<GenerationTaskType> _failOnce;
  final Set<String> _failedOnce = {};
  final Map<String, StudioProject> _projects = {};
  DateTime _clock = DateTime.utc(2026, 1, 1, 8);
  int _projectCounter = 0;
  int _runCounter = 0;

  @override
  Future<List<StudioProject>> listProjects() async => List.unmodifiable(
    _projects.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Future<StudioProject> createProject({
    required String theme,
    String? title,
    String? idempotencyKey,
  }) async {
    final normalized = ThemeValidator.validate(theme);
    final project = _newProject(
      theme: normalized,
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : '$normalized · 漫剧',
    );
    _projects[project.id] = project;
    return project;
  }

  StudioProject _newProject({required String theme, required String title}) {
    final id = 'demo-project-${(++_projectCounter).toString().padLeft(3, '0')}';
    final now = _tick();
    return StudioProject(
      id: id,
      title: title,
      theme: theme,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      etag: '"rev-1"',
    );
  }

  @override
  Future<StudioProject> adoptScript({
    required String projectId,
    required String etag,
    required String sourceText,
    ScriptSummary? script,
    String? idempotencyKey,
  }) async {
    final project = _requireProject(projectId, etag: etag);
    final prefix = project.id;
    final adoptedScript =
        script ??
        ScriptSummary(
          id: '$prefix-script',
          title: project.title.replaceFirst(' · 漫剧', ''),
          logline: '一次看似普通的选择，让主角必须在失去之前完成真正的告别。',
          styleBible: '电影级国风二维漫剧，青金与暖橙对比色，角色造型全程一致。',
          episodeSynopsis: '三段递进镜头完成相遇、危机与反转，并留下下一集悬念。',
        );
    final characters = <CharacterAsset>[
      CharacterAsset(
        id: '$prefix-character-01',
        name: '林小满',
        description: '勇敢但有点莽撞的年轻创作者',
        visualLock: '短黑发，琥珀色眼睛，靛蓝连帽外套，左肩银色徽章',
      ),
      CharacterAsset(
        id: '$prefix-character-02',
        name: '阿曜',
        description: '拥有秘密的机械伙伴',
        visualLock: '白色球形机身，青色环形灯，右侧有一道细小划痕',
      ),
    ];
    final scenes = <SceneAsset>[
      SceneAsset(
        id: '$prefix-scene-01',
        name: '雨夜天台',
        description: '城市霓虹下的高楼天台',
        visualLock: '湿润水泥地，蓝紫霓虹，左侧红色警示灯，远处高架列车',
      ),
      SceneAsset(
        id: '$prefix-scene-02',
        name: '废弃放映室',
        description: '尘封胶片与老式放映机组成的密室',
        visualLock: '暖黄投影光，木质座椅，右墙破损海报，空气中漂浮尘埃',
      ),
    ];
    final props = <PropAsset>[
      PropAsset(
        id: '$prefix-prop-01',
        name: '星纹胶片盒',
        description: '能够回放被遗忘记忆的旧胶片盒',
        visualLock: '掌心大小的黑色金属盒，银色星纹，边缘有红色封条',
      ),
    ];
    final shots = <Shot>[
      Shot(
        id: '$prefix-shot-01',
        order: 1,
        title: '雨中的来客',
        prompt: '林小满冲上雨夜天台，镜头从鞋边积水上摇，阿曜从霓虹后飞出。',
        durationSeconds: 6,
        characterIds: [characters[0].id, characters[1].id],
        sceneId: scenes[0].id,
      ),
      Shot(
        id: '$prefix-shot-02',
        order: 2,
        title: '被封存的画面',
        prompt: '两人进入放映室，林小满打开星纹胶片盒，投影映出陌生的童年。',
        durationSeconds: 7,
        characterIds: [characters[0].id, characters[1].id],
        sceneId: scenes[1].id,
        propIds: [props[0].id],
      ),
      Shot(
        id: '$prefix-shot-03',
        order: 3,
        title: '倒计时',
        prompt: '警报灯转红，阿曜的青色环灯闪烁，胶片画面突然定格在明天。',
        durationSeconds: 6,
        characterIds: [characters[0].id, characters[1].id],
        sceneId: scenes[1].id,
        propIds: [props[0].id],
      ),
    ];
    final voiceLines = <VoiceLine>[
      VoiceLine(
        id: '$prefix-line-01',
        shotId: shots[0].id,
        speaker: '林小满',
        characterId: characters[0].id,
        text: '你说的最后一次机会，就在这里？',
        voiceName: '暖调少女声',
      ),
      VoiceLine(
        id: '$prefix-line-02',
        shotId: shots[1].id,
        speaker: '阿曜',
        characterId: characters[1].id,
        text: '不是机会，是你亲手删掉的那段记忆。',
        voiceName: '清澈机械声',
      ),
      VoiceLine(
        id: '$prefix-line-03',
        shotId: shots[2].id,
        speaker: '林小满',
        characterId: characters[0].id,
        text: '画面里的人，为什么知道明天会发生什么？',
        voiceName: '暖调少女声',
      ),
    ];
    return _store(
      project.copyWith(
        latestScriptJobId: '$prefix-script-job',
        latestScriptJobStatus: StudioStatus.succeeded,
        script: adoptedScript,
        characters: characters,
        scenes: scenes,
        props: props,
        shots: shots,
        voiceLines: voiceLines,
      ),
    );
  }

  @override
  Future<StudioProject> startGeneration({
    required String projectId,
    required String etag,
    bool onlyMissing = true,
    List<String>? shotIds,
    String? idempotencyKey,
  }) async {
    final project = _requireProject(projectId, etag: etag);
    if (project.script == null) {
      throw StateError('请先采用剧本，再开始视频生成');
    }
    final planned = GenerationPlanner.plan(
      project,
      onlyMissing: onlyMissing,
      shotIds: shotIds,
    );
    final tasks = _activateFirst(planned);
    final now = _tick();
    final run = GenerationRun(
      id: 'demo-run-${(++_runCounter).toString().padLeft(3, '0')}',
      projectId: project.id,
      status: tasks.isEmpty ? StudioStatus.completed : StudioStatus.running,
      onlyMissing: onlyMissing,
      tasks: tasks,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      etag: '"rev-1"',
    );
    return _store(project.copyWith(currentRun: run, activeRunId: run.id));
  }

  @override
  Future<StudioProject> pauseGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  }) async {
    final project = _requireProject(projectId);
    final run = _requireRun(project, runId);
    _requireRunEtag(run, runEtag);
    if (run.status.isTerminal) return project;
    final tasks = run.tasks
        .map(
          (task) =>
              task.status == StudioStatus.running ||
                  task.status == StudioStatus.cooldown
              ? task.copyWith(
                  status: StudioStatus.paused,
                  revision: task.revision + 1,
                )
              : task,
        )
        .toList();
    return _store(
      project.copyWith(
        currentRun: run.copyWith(
          status: StudioStatus.paused,
          tasks: tasks,
          updatedAt: _tick(),
          revision: run.revision + 1,
          etag: '"rev-${run.revision + 1}"',
        ),
      ),
    );
  }

  @override
  Future<StudioProject> resumeGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  }) async {
    final project = _requireProject(projectId);
    final run = _requireRun(project, runId);
    _requireRunEtag(run, runEtag);
    if (run.status != StudioStatus.paused) return project;
    var resumed = false;
    final tasks = run.tasks.map((task) {
      if (!resumed && task.status == StudioStatus.paused) {
        resumed = true;
        return task.copyWith(
          status: StudioStatus.running,
          revision: task.revision + 1,
        );
      }
      return task;
    }).toList();
    final activated = resumed ? tasks : _activateFirst(tasks);
    return _store(
      project.copyWith(
        currentRun: run.copyWith(
          status: StudioStatus.running,
          tasks: activated,
          updatedAt: _tick(),
          revision: run.revision + 1,
          etag: '"rev-${run.revision + 1}"',
        ),
      ),
    );
  }

  @override
  Future<StudioProject> retryFailedTasks({
    required String projectId,
    required String runId,
    String? idempotencyKey,
  }) async {
    final project = _requireProject(projectId);
    final run = _requireRun(project, runId);
    final reset = run.tasks
        .map(
          (task) => task.status == StudioStatus.failed
              ? task.copyWith(
                  status: StudioStatus.pending,
                  errorMessage: null,
                  revision: task.revision + 1,
                )
              : task,
        )
        .toList();
    final tasks = _activateFirst(reset);
    return _store(
      project.copyWith(
        currentRun: run.copyWith(
          status: tasks.any((task) => task.status == StudioStatus.running)
              ? StudioStatus.running
              : StudioStatus.completed,
          tasks: tasks,
          updatedAt: _tick(),
          revision: run.revision + 1,
          etag: '"rev-${run.revision + 1}"',
        ),
      ),
    );
  }

  @override
  Future<StudioProject> retryTask({
    required String projectId,
    required String runId,
    required String taskId,
    String? idempotencyKey,
  }) async {
    final project = _requireProject(projectId);
    final run = _requireRun(project, runId);
    final targetIndex = run.tasks.indexWhere((task) => task.id == taskId);
    if (targetIndex < 0) throw StateError('生成任务不存在：$taskId');
    final target = run.tasks[targetIndex];
    if (target.status != StudioStatus.failed &&
        target.status != StudioStatus.canceled) {
      throw StateError('只有失败或已取消的任务可以重试');
    }
    final reset = [...run.tasks];
    reset[targetIndex] = target.copyWith(
      status: StudioStatus.pending,
      errorMessage: null,
      revision: target.revision + 1,
    );
    final tasks = _activateFirst(reset);
    return _store(
      project.copyWith(
        currentRun: run.copyWith(
          status: StudioStatus.running,
          tasks: tasks,
          updatedAt: _tick(),
          revision: run.revision + 1,
          etag: '"rev-${run.revision + 1}"',
        ),
      ),
    );
  }

  @override
  Future<StudioProject> cancelGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  }) async {
    final project = _requireProject(projectId);
    final run = _requireRun(project, runId);
    _requireRunEtag(run, runEtag);
    final tasks = run.tasks
        .map(
          (task) =>
              task.status == StudioStatus.pending ||
                  task.status == StudioStatus.running ||
                  task.status == StudioStatus.paused ||
                  task.status == StudioStatus.cooldown
              ? task.copyWith(
                  status: StudioStatus.canceled,
                  revision: task.revision + 1,
                )
              : task,
        )
        .toList();
    final nextRevision = run.revision + 1;
    return _store(
      project.copyWith(
        currentRun: run.copyWith(
          status: StudioStatus.canceled,
          tasks: tasks,
          updatedAt: _tick(),
          revision: nextRevision,
          etag: '"rev-$nextRevision"',
        ),
      ),
    );
  }

  @override
  Future<StudioProject> refreshProject(String projectId) async =>
      _requireProject(projectId);

  @override
  Future<StudioProject> advanceDemo(String projectId) async {
    var project = _requireProject(projectId);
    final run = project.currentRun;
    if (run == null ||
        run.status == StudioStatus.paused ||
        run.status.isTerminal) {
      return project;
    }
    final index = run.tasks.indexWhere(
      (task) =>
          task.status == StudioStatus.running ||
          task.status == StudioStatus.cooldown,
    );
    if (index < 0) {
      final tasks = _activateFirst(run.tasks);
      final status = tasks.any((task) => task.status == StudioStatus.running)
          ? StudioStatus.running
          : StudioStatus.completed;
      return _store(
        project.copyWith(
          currentRun: run.copyWith(
            tasks: tasks,
            status: status,
            updatedAt: _tick(),
            revision: run.revision + 1,
            etag: '"rev-${run.revision + 1}"',
          ),
        ),
      );
    }

    final task = run.tasks[index];
    final failureKey = '${task.type.wireName}:${task.targetId}';
    if (_failOnce.contains(task.type) && _failedOnce.add(failureKey)) {
      final tasks = [...run.tasks];
      tasks[index] = task.copyWith(
        status: StudioStatus.failed,
        errorMessage: '演示故障：${task.label} 暂时失败',
        revision: task.revision + 1,
      );
      return _store(
        project.copyWith(
          currentRun: run.copyWith(
            status: StudioStatus.failed,
            tasks: tasks,
            updatedAt: _tick(),
            revision: run.revision + 1,
            etag: '"rev-${run.revision + 1}"',
          ),
        ),
      );
    }

    final resultUrl = 'demo://generated/${task.type.wireName}/${task.targetId}';
    final tasks = [...run.tasks];
    tasks[index] = task.copyWith(
      status: StudioStatus.succeeded,
      resultUrl: resultUrl,
      revision: task.revision + 1,
    );
    project = _applyResult(project, task, resultUrl);
    final activated = _activateFirst(tasks);
    final completed = activated.every((item) => item.status.isTerminal);
    final updatedRun = run.copyWith(
      status: completed ? StudioStatus.completed : StudioStatus.running,
      tasks: activated,
      updatedAt: _tick(),
      revision: run.revision + 1,
      etag: '"rev-${run.revision + 1}"',
    );
    return _store(project.copyWith(currentRun: updatedRun));
  }

  StudioProject _applyResult(
    StudioProject project,
    GenerationTask task,
    String resultUrl,
  ) => switch (task.type) {
    GenerationTaskType.characterImage => project.copyWith(
      characters: project.characters
          .map(
            (asset) => asset.id == task.targetId
                ? asset.copyWith(
                    imageUrl: resultUrl,
                    status: StudioStatus.succeeded,
                    revision: asset.revision + 1,
                  )
                : asset,
          )
          .toList(),
    ),
    GenerationTaskType.sceneImage => project.copyWith(
      scenes: project.scenes
          .map(
            (asset) => asset.id == task.targetId
                ? asset.copyWith(
                    imageUrl: resultUrl,
                    status: StudioStatus.succeeded,
                    revision: asset.revision + 1,
                  )
                : asset,
          )
          .toList(),
    ),
    GenerationTaskType.propImage => project.copyWith(
      props: project.props
          .map(
            (asset) => asset.id == task.targetId
                ? asset.copyWith(
                    imageUrl: resultUrl,
                    status: StudioStatus.succeeded,
                    revision: asset.revision + 1,
                  )
                : asset,
          )
          .toList(),
    ),
    GenerationTaskType.storyboardFrame => project.copyWith(
      shots: project.shots
          .map(
            (shot) => shot.id == task.targetId
                ? shot.copyWith(
                    firstFrameUrl: '$resultUrl/first',
                    lastFrameUrl: '$resultUrl/last',
                    revision: shot.revision + 1,
                  )
                : shot,
          )
          .toList(),
    ),
    GenerationTaskType.shotVideo => project.copyWith(
      shots: project.shots
          .map(
            (shot) => shot.id == task.targetId
                ? shot.copyWith(
                    videoUrl: resultUrl,
                    status: StudioStatus.succeeded,
                    revision: shot.revision + 1,
                  )
                : shot,
          )
          .toList(),
    ),
    GenerationTaskType.voiceLine => project.copyWith(
      voiceLines: project.voiceLines
          .map(
            (line) => line.id == task.targetId
                ? line.copyWith(
                    audioUrl: resultUrl,
                    status: StudioStatus.succeeded,
                    revision: line.revision + 1,
                  )
                : line,
          )
          .toList(),
    ),
    GenerationTaskType.episodeExport => _applyExportResult(project, resultUrl),
    GenerationTaskType.script => project,
  };

  StudioProject _applyExportResult(StudioProject project, String resultUrl) {
    final export = StudioExport(
      id: '${project.id}-export-${project.exports.length + 1}',
      runId: project.currentRun?.id ?? '',
      status: StudioStatus.completed,
      createdAt: _tick(),
      videoUrl: resultUrl,
      downloadUrl: resultUrl,
      previewUrl: resultUrl,
      ready: true,
      progressPercent: 100,
      durationSeconds: project.shots.fold(
        0,
        (total, shot) => total + shot.durationSeconds,
      ),
    );
    return project.copyWith(
      exports: [...project.exports, export],
      latestExportId: export.id,
    );
  }

  List<GenerationTask> _activateFirst(List<GenerationTask> source) {
    if (source.any((task) => task.status == StudioStatus.running)) {
      return List.unmodifiable(source);
    }
    var activated = false;
    return List.unmodifiable(
      source.map((task) {
        if (!activated && task.status == StudioStatus.pending) {
          activated = true;
          return task.copyWith(
            status: StudioStatus.running,
            attempt: task.attempt + 1,
            revision: task.revision + 1,
          );
        }
        return task;
      }).toList(),
    );
  }

  StudioProject _requireProject(String projectId, {String? etag}) {
    final project = _projects[projectId];
    if (project == null) throw StateError('项目不存在：$projectId');
    if (etag != null && project.etag != etag) {
      throw StateError('项目已更新，请刷新后重试');
    }
    return project;
  }

  void _requireRunEtag(GenerationRun run, String etag) {
    if (run.etag != etag) throw StateError('生成任务已更新，请刷新后重试');
  }

  GenerationRun _requireRun(StudioProject project, String runId) {
    final run = project.currentRun;
    if (run == null || run.id != runId) {
      throw StateError('生成任务不存在：$runId');
    }
    return run;
  }

  StudioProject _store(StudioProject project) {
    final nextRevision = project.revision + 1;
    final stored = project.copyWith(
      updatedAt: _tick(),
      revision: nextRevision,
      etag: '"rev-$nextRevision"',
    );
    _projects[stored.id] = stored;
    return stored;
  }

  DateTime _tick() {
    _clock = _clock.add(const Duration(seconds: 1));
    return _clock;
  }
}
