import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/domain/agents/custom_agent.dart';
import 'package:xingmu_ai_video_studio/domain/pipeline/pipeline_definition.dart';
import 'package:xingmu_ai_video_studio/features/agent_builder/domain/agent_builder_models.dart';

void main() {
  group('agentTemplates', () {
    test('has 4 built-in templates', () {
      expect(agentTemplates.length, 4);
    });

    test('style enhancer template', () {
      final def = agentTemplates[0].toDefinition();
      expect(def.emoji, '🎨');
      expect(def.triggerStage, PipelineStage.script);
      expect(def.inputKeys, contains('script.source'));
      expect(def.outputKeys, contains('script.enhanced'));
    });

    test('shot optimizer template', () {
      final def = agentTemplates[1].toDefinition();
      expect(def.emoji, '📐');
      expect(def.triggerStage, PipelineStage.storyboard);
      expect(def.requiresApproval, isFalse);
    });

    test('dialogue polisher template', () {
      final def = agentTemplates[2].toDefinition();
      expect(def.emoji, '✨');
      expect(def.triggerStage, PipelineStage.voice);
      expect(def.inputKeys, contains('voice.lines'));
    });

    test('music selector template', () {
      final def = agentTemplates[3].toDefinition();
      expect(def.emoji, '🎵');
      expect(def.triggerStage, PipelineStage.compose);
      expect(def.outputKeys, contains('compose.music_plan'));
    });
  });

  group('CustomAgentDefinition', () {
    test('fromJson and toJson round-trip', () {
      final original = CustomAgentDefinition(
        id: 'test-agent-001',
        name: '测试 Agent',
        emoji: '🧪',
        triggerStage: PipelineStage.script,
        systemPrompt: '你是一个测试 Agent',
        inputKeys: const {'script.source'},
        outputKeys: const {'script.result'},
        requiresApproval: true,
        description: '用于测试',
      );

      final json = original.toJson();
      final restored = CustomAgentDefinition.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.emoji, original.emoji);
      expect(restored.triggerStage, original.triggerStage);
      expect(restored.systemPrompt, original.systemPrompt);
      expect(restored.inputKeys, original.inputKeys);
      expect(restored.outputKeys, original.outputKeys);
      expect(restored.requiresApproval, original.requiresApproval);
      expect(restored.description, original.description);
    });
  });

  group('CustomAgentRegistry', () {
    test('register and build agents', () {
      final registry = CustomAgentRegistry();
      final def = CustomAgentDefinition(
        id: 'test-001',
        name: '测试',
        emoji: '🧪',
        triggerStage: PipelineStage.script,
        systemPrompt: 'test',
      );

      registry.register(def);
      expect(registry.count, 1);
      expect(registry.has('test-001'), isTrue);

      final agents = registry.buildAgents();
      expect(agents, isNotEmpty);
      expect(agents.first.id, 'test-001');
    });

    test('unregister removes agent', () {
      final registry = CustomAgentRegistry();
      final def = CustomAgentDefinition(
        id: 'remove-001',
        name: '删除测试',
        emoji: '🗑️',
        triggerStage: PipelineStage.script,
        systemPrompt: 'test',
      );

      registry.register(def);
      expect(registry.count, 1);

      registry.unregister('remove-001');
      expect(registry.count, 0);
      expect(registry.has('remove-001'), isFalse);
    });

    test('getByStage filters correctly', () {
      final registry = CustomAgentRegistry()
        ..register(CustomAgentDefinition(
          id: 'a1',
          name: 'A',
          emoji: '🅰️',
          triggerStage: PipelineStage.script,
          systemPrompt: 'test',
        ))
        ..register(CustomAgentDefinition(
          id: 'a2',
          name: 'B',
          emoji: '🅱️',
          triggerStage: PipelineStage.shots,
          systemPrompt: 'test',
        ));

      expect(registry.getByStage(PipelineStage.script).length, 1);
      expect(registry.getByStage(PipelineStage.shots).length, 1);
      expect(registry.getByStage(PipelineStage.voice), isEmpty);
    });
  });
}
