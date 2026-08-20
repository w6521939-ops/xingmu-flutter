enum UiLoadState { ready, loading, empty, error }

enum StudioDestination {
  home,
  creation,
  script,
  assets,
  shots,
  voice,
  tasks,
  result,
  settings,
}

enum GenerationStatus {
  draft,
  queued,
  running,
  paused,
  failed,
  canceled,
  completed,
}

enum VisualAssetType { character, scene, prop }

class ProjectCardData {
  const ProjectCardData({
    required this.id,
    required this.title,
    required this.summary,
    required this.stageLabel,
    required this.updatedLabel,
    required this.status,
    this.progress,
    this.progressLabel = '创作进度',
  });

  final String id;
  final String title;
  final String summary;
  final String stageLabel;
  final String updatedLabel;
  final double? progress;
  final String progressLabel;
  final GenerationStatus status;
}

class ScriptBeatData {
  const ScriptBeatData({
    required this.number,
    required this.title,
    required this.durationLabel,
    required this.summary,
    required this.shotCount,
  });

  final int number;
  final String title;
  final String durationLabel;
  final String summary;
  final int shotCount;
}

class VisualAssetData {
  const VisualAssetData({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.status,
    required this.colorValue,
    this.locked = false,
  });

  final String id;
  final VisualAssetType type;
  final String name;
  final String description;
  final GenerationStatus status;
  final int colorValue;
  final bool? locked;
}

class ShotData {
  const ShotData({
    required this.id,
    required this.sequence,
    required this.title,
    required this.durationLabel,
    required this.prompt,
    required this.camera,
    required this.referenceLabels,
    required this.status,
    required this.progress,
  });

  final String id;
  final int sequence;
  final String title;
  final String durationLabel;
  final String prompt;
  final String camera;
  final List<String> referenceLabels;
  final GenerationStatus status;
  final double progress;
}

class VoiceCastData {
  const VoiceCastData({
    required this.id,
    required this.character,
    required this.voiceName,
    required this.description,
    required this.sampleText,
    required this.colorValue,
  });

  final String id;
  final String character;
  final String voiceName;
  final String description;
  final String sampleText;
  final int colorValue;
}

class VoiceLineData {
  const VoiceLineData({
    required this.id,
    required this.speaker,
    required this.content,
    required this.durationLabel,
    required this.status,
  });

  final String id;
  final String speaker;
  final String content;
  final String durationLabel;
  final GenerationStatus status;
}

class TaskItemData {
  const TaskItemData({
    required this.id,
    required this.title,
    required this.detail,
    required this.stageLabel,
    required this.status,
    required this.progress,
    required this.updatedLabel,
    this.failureMessage,
    this.resultDestination,
  });

  final String id;
  final String title;
  final String detail;
  final String stageLabel;
  final GenerationStatus status;
  final double progress;
  final String updatedLabel;
  final String? failureMessage;
  final StudioDestination? resultDestination;
}

class ResultData {
  const ResultData({
    required this.title,
    required this.summary,
    required this.durationLabel,
    required this.resolutionLabel,
    required this.sizeLabel,
    required this.generatedAtLabel,
    required this.ready,
  });

  final String title;
  final String summary;
  final String durationLabel;
  final String resolutionLabel;
  final String sizeLabel;
  final String generatedAtLabel;
  final bool ready;
}

abstract final class StudioDemoData {
  static const String longStory =
      '雨夜里，被贬为废徒的少女沈星回到旧城，却发现每一盏灯都记得被人刻意抹去的名字。她必须在天亮前找到最后一盏灯，才能救回弟弟，同时也将揭开城主府隐藏十年的真相。';

  static const List<ProjectCardData> projects = <ProjectCardData>[
    ProjectCardData(
      id: 'project-001',
      title: '长夜拾灯人',
      summary: '国风悬疑漫剧 · 第 1 集',
      stageLabel: '生成镜头 08/12',
      updatedLabel: '2 分钟前',
      progress: 0.68,
      status: GenerationStatus.running,
    ),
    ProjectCardData(
      id: 'project-002',
      title: '月球便利店',
      summary: '轻科幻治愈 · 45 秒',
      stageLabel: '等待确认剧本',
      updatedLabel: '昨天',
      progress: 0.22,
      status: GenerationStatus.paused,
    ),
    ProjectCardData(
      id: 'project-003',
      title: '最后一班地铁',
      summary: '都市奇谭 · 60 秒',
      stageLabel: '成片已完成',
      updatedLabel: '8 月 18 日',
      progress: 1,
      status: GenerationStatus.completed,
    ),
  ];

  static const List<ScriptBeatData> scriptBeats = <ScriptBeatData>[
    ScriptBeatData(
      number: 1,
      title: '雨巷归人',
      durationLabel: '0–15 秒',
      summary: '沈星冒雨走进被封锁的旧城，手中的青铜灯突然自行点亮。',
      shotCount: 3,
    ),
    ScriptBeatData(
      number: 2,
      title: '会说话的灯火',
      durationLabel: '15–40 秒',
      summary: '灯火显出弟弟的倒影，并警告她不要回头，追兵的脚步声却在身后逼近。',
      shotCount: 5,
    ),
    ScriptBeatData(
      number: 3,
      title: '城门下的名字',
      durationLabel: '40–65 秒',
      summary: '沈星在城门砖缝中找到自己的名字，真相与倒计时同时开始。',
      shotCount: 4,
    ),
  ];

  static const List<VisualAssetData> visualAssets = <VisualAssetData>[
    VisualAssetData(
      id: 'character-shenxing',
      type: VisualAssetType.character,
      name: '沈星',
      description: '19 岁，黑发高马尾，青色短打，眼神坚定；全片保持衣领的银色火焰纹。',
      status: GenerationStatus.completed,
      colorValue: 0xFF315CA8,
      locked: true,
    ),
    VisualAssetData(
      id: 'character-lin',
      type: VisualAssetType.character,
      name: '林砉',
      description: '12 岁，白色披风，只出现在灯火投影中，边缘有金色颗粒感。',
      status: GenerationStatus.completed,
      colorValue: 0xFF7960A8,
      locked: true,
    ),
    VisualAssetData(
      id: 'scene-old-city',
      type: VisualAssetType.scene,
      name: '雨夜旧城',
      description: '宋式长街、潮湿青石板、远处微弱暖灯，主色为墨蓝与琥珀金。',
      status: GenerationStatus.completed,
      colorValue: 0xFF24445F,
      locked: true,
    ),
    VisualAssetData(
      id: 'scene-gate',
      type: VisualAssetType.scene,
      name: '北城门',
      description: '巨大木门布满刀痕，门楼的红灯笼在雨中一明一暗。',
      status: GenerationStatus.running,
      colorValue: 0xFF754042,
    ),
  ];

  static const List<ShotData> shots = <ShotData>[
    ShotData(
      id: 'shot-01',
      sequence: 1,
      title: '雨幕中的旧城',
      durationLabel: '5.0 秒',
      prompt:
          '超广角建立镜头，深夜暴雨笼罩宋式旧城长街，青石板反射零星暖色灯火，孤独少女从画面远端向镜头走来，衣摆被风雨吹动，电影感光影，国风厚涂动画。',
      camera: '慢速推近 · 24mm · 低机位',
      referenceLabels: <String>['沈星', '雨夜旧城'],
      status: GenerationStatus.completed,
      progress: 1,
    ),
    ShotData(
      id: 'shot-02',
      sequence: 2,
      title: '灯火初醒',
      durationLabel: '4.5 秒',
      prompt: '特写少女掌心的青铜灯，熄灭的灯芯突然自行点亮，金色光芒照亮她惊讶的侧脸，雨滴在灯罩上凝结又滑落。',
      camera: '微距环绕 · 85mm · 浅景深',
      referenceLabels: <String>['沈星', '青铜灯'],
      status: GenerationStatus.running,
      progress: 0.56,
    ),
    ShotData(
      id: 'shot-03',
      sequence: 3,
      title: '影子开口',
      durationLabel: '5.5 秒',
      prompt: '灯火投射在雨巷白墙上，少年的半透明影子逐渐清晰，张口向画外的姐姐发出警告。',
      camera: '固定镜头 · 50mm · 侧逆光',
      referenceLabels: <String>['林砉', '雨夜旧城'],
      status: GenerationStatus.queued,
      progress: 0,
    ),
  ];

  static const List<VoiceCastData> voiceCast = <VoiceCastData>[
    VoiceCastData(
      id: 'voice-shenxing',
      character: '沈星',
      voiceName: '青岚',
      description: '年轻女声 · 清冷坚定 · 语速 0.95x',
      sampleText: '这盏灯，为什么记得我的名字？',
      colorValue: 0xFF315CA8,
    ),
    VoiceCastData(
      id: 'voice-lin',
      character: '林砉',
      voiceName: '小竹',
      description: '少年音 · 轻微气声 · 语速 1.05x',
      sampleText: '姐，别回头。他们已经来了。',
      colorValue: 0xFF7960A8,
    ),
  ];

  static const List<VoiceLineData> voiceLines = <VoiceLineData>[
    VoiceLineData(
      id: 'line-01',
      speaker: '沈星',
      content: '十年了，这座城还是不肯忘记那个雨夜。',
      durationLabel: '3.8 秒',
      status: GenerationStatus.completed,
    ),
    VoiceLineData(
      id: 'line-02',
      speaker: '林砉',
      content: '姐，别回头。他们已经来了。',
      durationLabel: '3.1 秒',
      status: GenerationStatus.running,
    ),
    VoiceLineData(
      id: 'line-03',
      speaker: '沈星',
      content: '等我。这一次，我会把你带回家。',
      durationLabel: '3.5 秒',
      status: GenerationStatus.queued,
    ),
  ];

  static const List<TaskItemData> tasks = <TaskItemData>[
    TaskItemData(
      id: 'task-video-02',
      title: '镜头 02 · 灯火初醒',
      detail: '首尾帧生成视频，预计还需约 1 分 20 秒。',
      stageLabel: '图生视频',
      status: GenerationStatus.running,
      progress: 0.56,
      updatedLabel: '刚刚',
    ),
    TaskItemData(
      id: 'task-video-03',
      title: '镜头 03 · 影子开口',
      detail: '等待镜头 02 完成后提交，以避免角色参考顺序变化。',
      stageLabel: '等待上游',
      status: GenerationStatus.queued,
      progress: 0,
      updatedLabel: '排队中',
    ),
    TaskItemData(
      id: 'task-scene-gate',
      title: '场景卡 · 北城门',
      detail: '重试后仍未获取到有效图像。',
      stageLabel: '文生图',
      status: GenerationStatus.failed,
      progress: 0.31,
      updatedLabel: '5 分钟前',
      failureMessage: '生成服务返回限流，建议 60 秒后重试。',
    ),
    TaskItemData(
      id: 'task-character',
      title: '角色卡 · 沈星',
      detail: '已生成正面、侧面与表情参考。',
      stageLabel: '文生图',
      status: GenerationStatus.completed,
      progress: 1,
      updatedLabel: '12 分钟前',
      resultDestination: StudioDestination.assets,
    ),
    TaskItemData(
      id: 'task-canceled-example',
      title: '镜头 04 · 城门下的名字',
      detail: '用户已取消该任务，未产生可查看的结果。',
      stageLabel: '图生视频',
      status: GenerationStatus.canceled,
      progress: 0,
      updatedLabel: '18 分钟前',
    ),
  ];

  static const ResultData result = ResultData(
    title: '长夜拾灯人 · 第 1 集',
    summary: '沈星在雨夜回到旧城，一盏会记得名字的青铜灯将她引向一段被抹去的真相。',
    durationLabel: '01:05',
    resolutionLabel: '1080 × 1920',
    sizeLabel: '86.4 MB',
    generatedAtLabel: '今天 14:36',
    ready: true,
  );
}
