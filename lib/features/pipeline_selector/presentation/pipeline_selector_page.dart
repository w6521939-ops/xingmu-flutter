import 'package:flutter/material.dart';

import '../../../domain/pipeline/pipeline_definition.dart';

class PipelineSelectorPage extends StatelessWidget {
  const PipelineSelectorPage({
    super.key,
    required this.onSelected,
    this.currentPipelineId,
  });

  final ValueChanged<PipelineDefinition> onSelected;
  final String? currentPipelineId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pipelines = PipelineDefinition.all;

    return Scaffold(
      appBar: AppBar(title: const Text('选择制作管线')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pipelines.length,
        itemBuilder: (context, index) {
          final pipeline = pipelines[index];
          final isSelected = pipeline.id == currentPipelineId;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                onSelected(pipeline);
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _iconForPipeline(pipeline.id),
                          size: 28,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pipeline.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : null,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pipeline.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: pipeline.stageOrder.map((stage) {
                        return Chip(
                          label: Text(stage.label),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconForPipeline(String id) {
    return switch (id) {
      'manju-drama' => Icons.auto_stories,
      'talking-head' => Icons.record_voice_over,
      'screen-recording' => Icons.screen_record,
      'podcast-repurpose' => Icons.podcasts,
      _ => Icons.movie,
    };
  }
}
