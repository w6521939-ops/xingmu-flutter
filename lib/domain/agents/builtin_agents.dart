import '../pipeline/pipeline_definition.dart';
import 'base_agent.dart';
import 'project_blackboard.dart';

class ScriptIngestionAgent extends BaseAgent {
  @override
  String get id => 'script-ingestion';

  @override
  String get name => '剧本识别';

  @override
  String get emoji => '📄';

  @override
  PipelineStage get triggerStage => PipelineStage.ingestion;

  @override
  bool get requiresApproval => true;

  @override
  Set<String> get inputKeys => {BlackboardKeys.projectTheme};

  @override
  Set<String> get outputKeys => {
    BlackboardKeys.scriptSource,
    BlackboardKeys.scriptStatus,
  };

  @override
  String get description => '识别剧本文件、小说文本与 AI 提示词，提取章节大纲和角色实体';

  @override
  Future<void> execute(ProjectBlackboard blackboard) async {
    final theme = blackboard.read<String>(BlackboardKeys.projectTheme, fallback: '');
    blackboard.write(BlackboardKeys.scriptSource, theme, source: id);
    blackboard.write(BlackboardKeys.scriptStatus, 'ingested', source: id);
  }
}

class CharacterDesignerAgent extends BaseAgent {
  @override
  String get id => 'character-designer';

  @override
  String get name => '角色设计';

  @override
  String get emoji => '👤';

  @override
  PipelineStage get triggerStage => PipelineStage.characters;

  @override
  bool get requiresApproval => true;

  @override
  Set<String> get inputKeys => {BlackboardKeys.scriptSource};

  @override
  Set<String> get outputKeys => {
    BlackboardKeys.characters,
    BlackboardKeys.characterAnchors,
    BlackboardKeys.characterStatus,
  };

  @override
  String get description => '从剧本提取角色实体，创建一致性锚点，绑定 TTS 音色';

  @override
  Future<void> execute(ProjectBlackboard blackboard) async {
    blackboard.write(BlackboardKeys.characters, <Map<String, dynamic>>[], source: id);
    blackboard.write(BlackboardKeys.characterStatus, 'designed', source: id);
  }
}

class StoryboardArtistAgent extends BaseAgent {
  @override
  String get id => 'storyboard-artist';

  @override
  String get name => '分镜运镜';

  @override
  String get emoji => '🎬';

  @override
  PipelineStage get triggerStage => PipelineStage.storyboard;

  @override
  bool get requiresApproval => true;

  @override
  Set<String> get inputKeys => {
    BlackboardKeys.scriptSource,
    BlackboardKeys.characters,
  };

  @override
  Set<String> get outputKeys => {
    BlackboardKeys.storyboardShots,
    BlackboardKeys.storyboardStatus,
  };

  @override
  String get description => '规划分镜首尾帧，自动检测运镜（Zoom/Tilt/Pan），生成 3 栏画幅大盘';

  @override
  Future<void> execute(ProjectBlackboard blackboard) async {
    blackboard.write(BlackboardKeys.storyboardShots, <Map<String, dynamic>>[], source: id);
    blackboard.write(BlackboardKeys.storyboardStatus, 'planned', source: id);
  }
}

class SoundEngineerAgent extends BaseAgent {
  @override
  String get id => 'sound-engineer';

  @override
  String get name => '音效配音';

  @override
  String get emoji => '🎙️';

  @override
  PipelineStage get triggerStage => PipelineStage.voice;

  @override
  Set<String> get inputKeys => {
    BlackboardKeys.scriptSource,
    BlackboardKeys.characters,
  };

  @override
  Set<String> get outputKeys => {
    BlackboardKeys.voiceLines,
    BlackboardKeys.voiceTimeline,
    BlackboardKeys.voiceStatus,
  };

  @override
  String get description => '多轨道 TTS 生成，毫秒级字幕卡点计算，SRT/ASS 字幕导出';

  @override
  Future<void> execute(ProjectBlackboard blackboard) async {
    blackboard.write(BlackboardKeys.voiceLines, <Map<String, dynamic>>[], source: id);
    blackboard.write(BlackboardKeys.voiceTimeline, {}, source: id);
    blackboard.write(BlackboardKeys.voiceStatus, 'synced', source: id);
  }
}

class VideoEditorAgent extends BaseAgent {
  @override
  String get id => 'video-editor';

  @override
  String get name => '视频压制';

  @override
  String get emoji => '🎞️';

  @override
  PipelineStage get triggerStage => PipelineStage.compose;

  @override
  bool get requiresApproval => true;

  @override
  Set<String> get inputKeys => {
    BlackboardKeys.shotVideos,
    BlackboardKeys.voiceTimeline,
  };

  @override
  Set<String> get outputKeys => {
    BlackboardKeys.composedVideo,
    BlackboardKeys.composeStatus,
  };

  @override
  String get description => 'GPU 加速视频合成，多轨道混音，字幕烧录，4K 输出';

  @override
  Future<void> execute(ProjectBlackboard blackboard) async {
    blackboard.write(BlackboardKeys.composedVideo, '', source: id);
    blackboard.write(BlackboardKeys.composeStatus, 'composed', source: id);
  }
}

class PublishingAgent extends BaseAgent {
  @override
  String get id => 'publisher';

  @override
  String get name => '导出发布';

  @override
  String get emoji => '📤';

  @override
  PipelineStage get triggerStage => PipelineStage.publish;

  @override
  Set<String> get inputKeys => {BlackboardKeys.composedVideo};

  @override
  Set<String> get outputKeys => {
    BlackboardKeys.publishedExport,
    BlackboardKeys.publishStatus,
  };

  @override
  String get description => '导出最终视频文件，生成下载链接和预览页面';

  @override
  Future<void> execute(ProjectBlackboard blackboard) async {
    final video = blackboard.read<String>(BlackboardKeys.composedVideo, fallback: '');
    blackboard.write(BlackboardKeys.publishedExport, video, source: id);
    blackboard.write(BlackboardKeys.publishStatus, 'published', source: id);
  }
}

List<BaseAgent> get builtinAgents => [
  ScriptIngestionAgent(),
  CharacterDesignerAgent(),
  StoryboardArtistAgent(),
  SoundEngineerAgent(),
  VideoEditorAgent(),
  PublishingAgent(),
];
