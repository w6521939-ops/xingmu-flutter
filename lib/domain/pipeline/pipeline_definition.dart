enum PipelineStage {
  ingestion,
  script,
  characters,
  storyboard,
  shots,
  voice,
  compose,
  publish;

  String get label => switch (this) {
    PipelineStage.ingestion => '素材导入',
    PipelineStage.script => '剧本生成',
    PipelineStage.characters => '角色设计',
    PipelineStage.storyboard => '分镜规划',
    PipelineStage.shots => '镜头生成',
    PipelineStage.voice => '配音合成',
    PipelineStage.compose => '视频合成',
    PipelineStage.publish => '导出发布',
  };

  int get stepNumber => switch (this) {
    PipelineStage.ingestion => 0,
    PipelineStage.script => 1,
    PipelineStage.characters => 2,
    PipelineStage.storyboard => 3,
    PipelineStage.shots => 4,
    PipelineStage.voice => 5,
    PipelineStage.compose => 6,
    PipelineStage.publish => 7,
  };

  String get iconName => switch (this) {
    PipelineStage.ingestion => 'inbox',
    PipelineStage.script => 'description',
    PipelineStage.characters => 'person',
    PipelineStage.storyboard => 'movie',
    PipelineStage.shots => 'video_camera_back',
    PipelineStage.voice => 'mic',
    PipelineStage.compose => 'movie_filter',
    PipelineStage.publish => 'publish',
  };
}

enum StageStatus {
  pending,
  running,
  awaitingApproval,
  completed,
  skipped,
  failed,
  paused;

  bool get isTerminal =>
      this == StageStatus.completed ||
      this == StageStatus.skipped ||
      this == StageStatus.failed;

  bool get isActive =>
      this == StageStatus.running ||
      this == StageStatus.awaitingApproval ||
      this == StageStatus.paused;

  String get label => switch (this) {
    StageStatus.pending => '待执行',
    StageStatus.running => '执行中',
    StageStatus.awaitingApproval => '待审批',
    StageStatus.completed => '已完成',
    StageStatus.skipped => '已跳过',
    StageStatus.failed => '失败',
    StageStatus.paused => '已暂停',
  };
}

class StageDefinition {
  const StageDefinition({
    required this.stage,
    required this.dependsOn,
    this.requiresApproval = false,
    this.canParallel = false,
    this.approvalLabel,
  });

  final PipelineStage stage;
  final List<PipelineStage> dependsOn;
  final bool requiresApproval;
  final bool canParallel;
  final String? approvalLabel;

  bool canExecute(Map<PipelineStage, StageStatus> statuses) {
    for (final dep in dependsOn) {
      final status = statuses[dep];
      if (status != StageStatus.completed && status != StageStatus.skipped) {
        return false;
      }
    }
    return true;
  }
}

class PipelineDefinition {
  const PipelineDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.stages,
  });

  final String id;
  final String name;
  final String description;
  final List<StageDefinition> stages;

  StageDefinition? getStage(PipelineStage stage) {
    for (final s in stages) {
      if (s.stage == stage) return s;
    }
    return null;
  }

  List<PipelineStage> get stageOrder =>
      stages.map((s) => s.stage).toList();

  static PipelineDefinition manjuDrama = PipelineDefinition(
    id: 'manju-drama',
    name: '漫剧制作',
    description: '从素材导入到成片导出的完整漫剧制作流程',
    stages: [
      const StageDefinition(
        stage: PipelineStage.ingestion,
        dependsOn: [],
        requiresApproval: true,
        approvalLabel: '确认导入素材',
      ),
      const StageDefinition(
        stage: PipelineStage.script,
        dependsOn: [PipelineStage.ingestion],
        requiresApproval: true,
        approvalLabel: '确认剧本',
      ),
      const StageDefinition(
        stage: PipelineStage.characters,
        dependsOn: [PipelineStage.script],
        requiresApproval: true,
        approvalLabel: '确认角色设计',
        canParallel: true,
      ),
      const StageDefinition(
        stage: PipelineStage.storyboard,
        dependsOn: [PipelineStage.script, PipelineStage.characters],
        requiresApproval: true,
        approvalLabel: '确认分镜规划',
      ),
      const StageDefinition(
        stage: PipelineStage.shots,
        dependsOn: [PipelineStage.storyboard],
        canParallel: true,
      ),
      const StageDefinition(
        stage: PipelineStage.voice,
        dependsOn: [PipelineStage.script, PipelineStage.characters],
        canParallel: true,
      ),
      const StageDefinition(
        stage: PipelineStage.compose,
        dependsOn: [PipelineStage.shots, PipelineStage.voice],
        requiresApproval: true,
        approvalLabel: '确认最终合成',
      ),
      const StageDefinition(
        stage: PipelineStage.publish,
        dependsOn: [PipelineStage.compose],
      ),
    ],
  );
}
