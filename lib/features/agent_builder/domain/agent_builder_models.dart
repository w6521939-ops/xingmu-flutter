import '../../domain/agents/custom_agent.dart';
import '../../domain/pipeline/pipeline_definition.dart';

class AgentTemplate {
  const AgentTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.systemPrompt,
    required this.triggerStage,
    required this.inputKeys,
    required this.outputKeys,
  });

  final String id;
  final String name;
  final String emoji;
  final String description;
  final String systemPrompt;
  final PipelineStage triggerStage;
  final Set<String> inputKeys;
  final Set<String> outputKeys;

  CustomAgentDefinition toDefinition() => CustomAgentDefinition(
    id: 'custom-$id-${DateTime.now().millisecondsSinceEpoch}',
    name: name,
    emoji: emoji,
    triggerStage: triggerStage,
    systemPrompt: systemPrompt,
    inputKeys: inputKeys,
    outputKeys: outputKeys,
    requiresApproval: false,
    description: description,
  );
}

List<AgentTemplate> get agentTemplates => [
  const AgentTemplate(
    id: 'style-enhancer',
    name: '风格增强',
    emoji: '🎨',
    description: '在剧本生成后增强文风，添加环境描写和情绪渲染',
    systemPrompt: '你是一个漫剧风格增强专家。请阅读剧本内容，在保持情节不变的前提下，增强环境描写、角色情绪和视觉提示词。输出格式保持与输入一致。',
    triggerStage: PipelineStage.script,
    inputKeys: {'script.source'},
    outputKeys: {'script.enhanced'},
  ),
  const AgentTemplate(
    id: 'shot-optimizer',
    name: '镜头优化',
    emoji: '📐',
    description: '在分镜生成后优化镜头切换节奏和运镜连贯性',
    systemPrompt: '你是一个镜头语言专家。请分析当前分镜列表，优化镜头切换节奏，确保运镜连贯。检查是否有跳切、轴线错误，并给出修正建议。',
    triggerStage: PipelineStage.storyboard,
    inputKeys: {'storyboard.shots'},
    outputKeys: {'storyboard.optimized'},
  ),
  const AgentTemplate(
    id: 'dialogue-polisher',
    name: '台词润色',
    emoji: '✨',
    description: '在配音前润色台词，使其更自然、更有角色个性',
    systemPrompt: '你是一个对白写作专家。请阅读所有角色台词，根据角色性格润色对白，使其更自然、更有个性。保持每句台词的时长不变。',
    triggerStage: PipelineStage.voice,
    inputKeys: {'voice.lines', 'characters.list'},
    outputKeys: {'voice.polished'},
  ),
  const AgentTemplate(
    id: 'music-selector',
    name: '配乐选择',
    emoji: '🎵',
    description: '根据剧本情绪自动选择合适的背景音乐风格',
    systemPrompt: '你是一个影视配乐专家。请分析剧本的情感基调，为每个场景推荐合适的背景音乐风格和节奏。输出 JSON 格式的配乐方案。',
    triggerStage: PipelineStage.compose,
    inputKeys: {'script.source', 'storyboard.shots'},
    outputKeys: {'compose.music_plan'},
  ),
];
