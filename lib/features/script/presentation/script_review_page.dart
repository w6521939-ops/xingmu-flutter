import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/widgets/studio_widgets.dart';

class ScriptReviewPage extends StatelessWidget {
  const ScriptReviewPage({
    required this.projectTitle,
    required this.projectSummary,
    required this.projectMeta,
    required this.beats,
    required this.onEditSummary,
    required this.onEditBeat,
    required this.onRegenerate,
    required this.onConfirm,
    required this.onNavigateStep,
    super.key,
    this.state = UiLoadState.ready,
    this.onRetry,
  });

  final String projectTitle;
  final String projectSummary;
  final String projectMeta;
  final List<ScriptBeatData> beats;
  final VoidCallback onEditSummary;
  final ValueChanged<ScriptBeatData> onEditBeat;
  final VoidCallback onRegenerate;
  final VoidCallback onConfirm;
  final ValueChanged<StudioDestination> onNavigateStep;
  final UiLoadState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsiveContent(
        maxWidth: 1060,
        child: StatePanel(
          state: state,
          onRetry: onRetry,
          emptyTitle: '还没有剧本',
          emptyMessage: '先在主题创作页输入故事，再生成可审核的剧本。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudioStepBar(
                activeDestination: StudioDestination.script,
                onStepTap: onNavigateStep,
              ),
              const SizedBox(height: 24),
              PageIntro(
                eyebrow: '02 · 剧本确认',
                title: '确认故事节奏与镜头分配',
                description: '本页用于审核服务端返回的剧本。确认操作只会继续查看视觉资产，不会提交锁定或生成请求。',
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重新生成'),
                    ),
                    FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('继续查看'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: projectTitle,
                      subtitle: projectMeta,
                      action: IconButton(
                        tooltip: '编辑概要',
                        onPressed: onEditSummary,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      projectSummary,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        Chip(
                          avatar: Icon(Icons.person_outline, size: 18),
                          label: Text('角色与目标已结构化'),
                        ),
                        Chip(
                          avatar: Icon(Icons.bolt_outlined, size: 18),
                          label: Text('冲突与反转可审核'),
                        ),
                        Chip(
                          avatar: Icon(Icons.favorite_border, size: 18),
                          label: Text('情绪节拍已标注'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: '剧情节拍', subtitle: '展开可查看该段的镜头建议和台词要点'),
              const SizedBox(height: 12),
              ...beats.map(
                (beat) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BeatCard(beat: beat, onEdit: () => onEditBeat(beat)),
                ),
              ),
              InfoBanner(
                icon: Icons.rule_folder_outlined,
                title: '后续流程（待接入）',
                message: '确认后可查看服务端已返回的角色、场景与道具卡；资产生成、锁定变更和首尾帧请求尚未接入。',
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('确认并查看视觉资产'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeatCard extends StatelessWidget {
  const _BeatCard({required this.beat, required this.onEdit});

  final ScriptBeatData beat;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: Text('${beat.number}'),
        ),
        title: Text(beat.title),
        subtitle: Text('${beat.durationLabel} · ${beat.shotCount} 个镜头'),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 14),
          Text(beat.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '镜头建议：先用建立镜头交代空间，再转入人物中景与关键道具特写，结尾保留动作钩子。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('编辑该段'),
            ),
          ),
        ],
      ),
    );
  }
}
