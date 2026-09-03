import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/ingestion_controller.dart';
import '../../domain/ingestion_models.dart';

class IngestionPage extends StatefulWidget {
  const IngestionPage({super.key, this.controller});

  final IngestionController? controller;

  @override
  State<IngestionPage> createState() => _IngestionPageState();
}

class _IngestionPageState extends State<IngestionPage> {
  late final IngestionController _controller;
  final _textController = TextEditingController();
  IngestionSourceType _selectedType = IngestionSourceType.novel;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? IngestionController();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入素材'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: _controller.hasResult
          ? _buildResultView(colorScheme)
          : _buildInputView(colorScheme),
    );
  }

  Widget _buildInputView(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTypeSelector(colorScheme),
        const SizedBox(height: 20),
        _buildTextInput(colorScheme),
        const SizedBox(height: 16),
        if (_controller.hasError)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _controller.errorMessage!,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _controller.isLoading ? null : _onIngest,
          icon: _controller.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_controller.isLoading ? '解析中...' : '开始解析'),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      children: IngestionSourceType.values.map((type) {
        final selected = type == _selectedType;
        return ChoiceChip(
          label: Text(type.label),
          selected: selected,
          onSelected: (_) => setState(() => _selectedType = type),
          selectedColor: colorScheme.primaryContainer,
        );
      }).toList(),
    );
  }

  Widget _buildTextInput(ColorScheme colorScheme) {
    return TextField(
      controller: _textController,
      maxLines: 12,
      decoration: InputDecoration(
        labelText: '粘贴内容',
        hintText: '在此粘贴剧本、小说文本或 AI 提示词...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _onIngest() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_selectedType == IngestionSourceType.prompt) {
      _controller.ingestPrompt(text);
    } else {
      _controller.ingestText(text: text, type: _selectedType);
    }
  }

  Widget _buildResultView(ColorScheme colorScheme) {
    final result = _controller.result!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (result.suggestedTitle != null)
          _buildInfoCard(colorScheme, '标题', result.suggestedTitle!),
        if (result.suggestedLogline != null)
          _buildInfoCard(colorScheme, '故事梗概', result.suggestedLogline!),
        if (result.suggestedStyle != null)
          _buildInfoCard(colorScheme, '建议风格', result.suggestedStyle!),
        const SizedBox(height: 16),
        Text(
          '章节大纲 (${result.chapters.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...result.chapters.map((chapter) => _buildChapterCard(colorScheme, chapter)),
        if (result.hasCharacters) ...[
          const SizedBox(height: 16),
          Text(
            '识别角色 (${result.characters.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: result.characters.map((char) {
              return Chip(
                label: Text(char.name),
                avatar: const Icon(Icons.person_outline, size: 18),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _controller.clear(),
                child: const Text('重新导入'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _onUseResult(result),
                icon: const Icon(Icons.check),
                label: const Text('使用此剧本'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label：',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterCard(ColorScheme colorScheme, ChapterOutline chapter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(chapter.title),
        subtitle: Text('预估 ${chapter.shotCount} 个镜头'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(chapter.content),
          ),
        ],
      ),
    );
  }

  void _onUseResult(IngestionResult result) {
    Navigator.of(context).pop(result);
  }
}
