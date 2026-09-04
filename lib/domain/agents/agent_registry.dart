import 'base_agent.dart';

class AgentRegistry {
  final Map<String, BaseAgent> _agents = {};
  final List<String> _order = [];

  void register(BaseAgent agent) {
    _agents[agent.id] = agent;
    if (!_order.contains(agent.id)) _order.add(agent.id);
  }

  void unregister(String agentId) {
    _agents.remove(agentId);
    _order.remove(agentId);
  }

  BaseAgent? get(String id) => _agents[id];

  List<BaseAgent> get all =>
      _order.map((id) => _agents[id]).whereType<BaseAgent>().toList();

  List<BaseAgent> getByStage(String stageName) =>
      _agents.values.where((a) => a.triggerStage.name == stageName).toList();

  bool has(String id) => _agents.containsKey(id);

  int get count => _agents.length;

  void clear() {
    _agents.clear();
    _order.clear();
  }
}
