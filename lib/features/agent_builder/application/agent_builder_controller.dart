import 'package:flutter/foundation.dart';

import '../../domain/agents/custom_agent.dart';
import '../../domain/agents/agent_registry.dart';
import '../domain/agent_builder_models.dart';

class AgentBuilderController extends ChangeNotifier {
  AgentBuilderController({
    CustomAgentRegistry? registry,
  }) : _registry = registry ?? CustomAgentRegistry();

  final CustomAgentRegistry _registry;

  CustomAgentRegistry get registry => _registry;

  List<CustomAgentDefinition> get customAgents => _registry.all;

  int get customAgentCount => _registry.count;

  void createAgent(CustomAgentDefinition definition) {
    _registry.register(definition);
    notifyListeners();
  }

  void createFromTemplate(AgentTemplate template) {
    _registry.register(template.toDefinition());
    notifyListeners();
  }

  void updateAgent(CustomAgentDefinition updated) {
    _registry.register(updated);
    notifyListeners();
  }

  void deleteAgent(String id) {
    _registry.unregister(id);
    notifyListeners();
  }

  CustomAgentDefinition? getAgent(String id) => _registry.get(id);

  bool hasAgent(String id) => _registry.has(id);

  void registerAllTo(AgentRegistry agentRegistry) {
    for (final agent in _registry.buildAgents()) {
      agentRegistry.register(agent);
    }
  }
}
