import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/agents/custom_agent.dart';
import '../../domain/pipeline/pipeline_definition.dart';
import '../application/agent_builder_controller.dart';
import '../domain/agent_builder_models.dart';

class AgentBuilderPage extends StatefulWidget {
  const AgentBuilderPage({super.key, this.controller});

  final AgentBuilderController? controller;

  @override
  State<AgentBuilderPage> createState() => _AgentBuilderPageState();
}

class _AgentBuilderPageState extends State<AgentBuilderPage>
    with SingleTickerProviderStateMixin {
  late final AgentBuilderController _controller;
  late final TabController _tabController;

  final _nameController = TextEditingController();
  final _emojiController = TextEditingController(text: '🤖');
  final _promptController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _inputKeysController = TextEditingController();
  final _outputKeysController = TextEditingController();

  PipelineStage _selectedStage = PipelineStage.script;
  String _selectedModel = 'qwen-plus';
  bool _requiresApproval = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AgentBuilderController();
    _controller.addListener(_onChanged);
    _tabController = TabController(length: 2, vsync: this);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _tabController.dispose();
    _nameController.dispose();
    _emojiController.dispose();
    _promptController.dispose();
    _descriptionController.dispose();
    _inputKeysController.dispose();
    _outputKeysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义 Agent'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '模板', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: '我的 Agent', icon: Icon(Icons.smart_toy_outlined)),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('新建 Agent'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplatesView(theme),
          _buildMyAgentsView(theme),
        ],
      ),
    );
  }

  Widget _buildTemplatesView(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agentTemplates.length,
      itemBuilder: (context, index) =>
          _buildTemplateCard(context, agentTemplates[index], theme),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    AgentTemplate template,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(template.emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(template.name),
        subtitle: Text(template.description),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(theme, '触发阶段', template.triggerStage.label),
                _buildInfoRow(theme, '输入键', template.inputKeys.join(', ')),
                _buildInfoRow(theme, '输出键', template.outputKeys.join(', ')),
                const SizedBox(height: 8),
                Text('系统提示词：', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    template.systemPrompt,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    _controller.createFromTemplate(template);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${template.name} 已添加')),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('使用此模板'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyAgentsView(ThemeData theme) {
    final agents = _controller.customAgents;

    if (agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy_outlined, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('还没有自定义 Agent', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('点击右下角按钮或从模板创建', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agents.length,
      itemBuilder: (context, index) =>
          _buildAgentCard(context, agents[index], theme),
    );
  }

  Widget _buildAgentCard(
    BuildContext context,
    CustomAgentDefinition agent,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(agent.emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(agent.name),
        subtitle: Text('${agent.triggerStage.label} · ${agent.modelId}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (agent.requiresApproval)
              Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.outline),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, agent),
            ),
          ],
        ),
        onTap: () => _showEditDialog(agent),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label：',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showCreateDialog() => _showAgentDialog(null);

  void _showEditDialog(CustomAgentDefinition agent) => _showAgentDialog(agent);

  void _showAgentDialog(CustomAgentDefinition? existing) {
    if (existing != null) {
      _nameController.text = existing.name;
      _emojiController.text = existing.emoji;
      _promptController.text = existing.systemPrompt;
      _descriptionController.text = existing.description;
      _inputKeysController.text = existing.inputKeys.join(', ');
      _outputKeysController.text = existing.outputKeys.join(', ');
      _selectedStage = existing.triggerStage;
      _selectedModel = existing.modelId;
      _requiresApproval = existing.requiresApproval;
    } else {
      _nameController.clear();
      _emojiController.text = '🤖';
      _promptController.clear();
      _descriptionController.clear();
      _inputKeysController.clear();
      _outputKeysController.clear();
      _selectedStage = PipelineStage.script;
      _selectedModel = 'qwen-plus';
      _requiresApproval = false;
    }

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? '新建 Agent' : '编辑 Agent'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            controller: _emojiController,
                            decoration: const InputDecoration(labelText: '图标'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: '名称'),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? '请输入名称' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PipelineStage>(
                      value: _selectedStage,
                      decoration: const InputDecoration(labelText: '触发阶段'),
                      items: PipelineStage.values.map((stage) {
                        return DropdownMenuItem(
                          value: stage,
                          child: Text('${stage.stepNumber + 1}. ${stage.label}'),
                        );
                      }).toList(),
                      onChanged: (stage) {
                        if (stage != null) {
                          setDialogState(() => _selectedStage = stage);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedModel,
                      decoration: const InputDecoration(labelText: '模型'),
                      items: const [
                        DropdownMenuItem(value: 'qwen-plus', child: Text('通义千问 Plus')),
                        DropdownMenuItem(value: 'qwen-max', child: Text('通义千问 Max')),
                        DropdownMenuItem(value: 'deepseek-v4', child: Text('DeepSeek V4')),
                        DropdownMenuItem(value: 'kimi-k3', child: Text('Kimi K3')),
                      ],
                      onChanged: (model) {
                        if (model != null) {
                          setDialogState(() => _selectedModel = model);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _promptController,
                      decoration: const InputDecoration(
                        labelText: '系统提示词',
                        hintText: '定义 Agent 的角色和行为规则...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入提示词' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: '描述'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _inputKeysController,
                            decoration: const InputDecoration(
                              labelText: '输入键',
                              hintText: '逗号分隔',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _outputKeysController,
                            decoration: const InputDecoration(
                              labelText: '输出键',
                              hintText: '逗号分隔',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('需要审批'),
                      value: _requiresApproval,
                      onChanged: (v) =>
                          setDialogState(() => _requiresApproval = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                _saveAgent(existing);
                Navigator.of(dialogContext).pop();
              },
              child: Text(existing == null ? '创建' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAgent(CustomAgentDefinition? existing) {
    final def = CustomAgentDefinition(
      id: existing?.id ??
          'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      emoji: _emojiController.text.trim(),
      triggerStage: _selectedStage,
      systemPrompt: _promptController.text.trim(),
      modelId: _selectedModel,
      inputKeys: _inputKeysController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet(),
      outputKeys: _outputKeysController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet(),
      requiresApproval: _requiresApproval,
      description: _descriptionController.text.trim(),
    );

    if (existing == null) {
      _controller.createAgent(def);
    } else {
      _controller.updateAgent(def);
    }
  }

  void _confirmDelete(BuildContext context, CustomAgentDefinition agent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Agent'),
        content: Text('确定删除「${agent.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              _controller.deleteAgent(agent.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
