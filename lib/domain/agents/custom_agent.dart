import 'base_agent.dart';
import 'project_blackboard.dart';
import '../pipeline/pipeline_definition.dart';

class CustomAgentDefinition {
  const CustomAgentDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.triggerStage,
    required this.systemPrompt,
    this.modelId = 'qwen-plus',
    this.inputKeys = const {},
    this.outputKeys = const {},
    this.requiresApproval = false,
    this.description = '',
  });

  final String id;
  final String name;
  final String emoji;
  final PipelineStage triggerStage;
  final String systemPrompt;
  final String modelId;
  final Set<String> inputKeys;
  final Set<String> outputKeys;
  final bool requiresApproval;
  final String description;

  CustomAgentDefinition copyWith({
    String? id,
    String? name,
    String? emoji,
    PipelineStage? triggerStage,
    String? systemPrompt,
    String? modelId,
    Set<String>? inputKeys,
    Set<String>? outputKeys,
    bool? requiresApproval,
    String? description,
  }) => CustomAgentDefinition(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    triggerStage: triggerStage ?? this.triggerStage,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    modelId: modelId ?? this.modelId,
    inputKeys: inputKeys ?? this.inputKeys,
    outputKeys: outputKeys ?? this.outputKeys,
    requiresApproval: requiresApproval ?? this.requiresApproval,
    description: description ?? this.description,
  );

  factory CustomAgentDefinition.fromJson(Map<String, dynamic> json) =>
      CustomAgentDefinition(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🤖',
        triggerStage: PipelineStage.values.firstWhere(
          (s) => s.name == json['trigger_stage'],
          orElse: () => PipelineStage.script,
        ),
        systemPrompt: json['system_prompt'] as String? ?? '',
        modelId: json['model_id'] as String? ?? 'qwen-plus',
        inputKeys: (json['input_keys'] as List? ?? [])
            .map((e) => e.toString())
            .toSet(),
        outputKeys: (json['output_keys'] as List? ?? [])
            .map((e) => e.toString())
            .toSet(),
        requiresApproval: json['requires_approval'] as bool? ?? false,
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'trigger_stage': triggerStage.name,
    'system_prompt': systemPrompt,
    'model_id': modelId,
    'input_keys': inputKeys.toList(),
    'output_keys': outputKeys.toList(),
    'requires_approval': requiresApproval,
    'description': description,
  };
}

class CustomAgent extends BaseAgent {
  CustomAgent(this.definition);

  final CustomAgentDefinition definition;

  @override
  String get id => definition.id;

  @override
  String get name => definition.name;

  @override
  String get emoji => definition.emoji;

  @override
  PipelineStage get triggerStage => definition.triggerStage;

  @override
  bool get requiresApproval => definition.requiresApproval;

  @override
  Set<String> get inputKeys => definition.inputKeys;

  @override
  Set<String> get outputKeys => definition.outputKeys;

  @override
  String get description => definition.description;

  @override
  Future<void> execute(ProjectBlackboard blackboard) async {
    final inputs = <String, dynamic>{};
    for (final key in inputKeys) {
      inputs[key] = blackboard.readNullable<dynamic>(key);
    }

    final result = await _callLLM(definition.systemPrompt, inputs);

    for (final key in outputKeys) {
      blackboard.write(key, result[key] ?? '', source: id);
    }
  }

  Future<Map<String, dynamic>> _callLLM(
    String systemPrompt,
    Map<String, dynamic> inputs,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {for (final key in outputKeys) key: 'custom_agent_output'};
  }
}

class CustomAgentRegistry {
  final Map<String, CustomAgentDefinition> _definitions = {};

  void register(CustomAgentDefinition def) {
    _definitions[def.id] = def;
  }

  void unregister(String id) => _definitions.remove(id);

  CustomAgentDefinition? get(String id) => _definitions[id];

  List<CustomAgentDefinition> get all => _definitions.values.toList();

  List<CustomAgentDefinition> getByStage(PipelineStage stage) =>
      _definitions.values
          .where((d) => d.triggerStage == stage)
          .toList();

  bool has(String id) => _definitions.containsKey(id);

  int get count => _definitions.length;

  void clear() => _definitions.clear();

  List<CustomAgent> buildAgents() =>
      _definitions.values.map((d) => CustomAgent(d)).toList();
}
