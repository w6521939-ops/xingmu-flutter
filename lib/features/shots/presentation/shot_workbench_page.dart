import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/widgets/studio_widgets.dart';

class ShotWorkbenchPage extends StatefulWidget {
  const ShotWorkbenchPage({
    required this.shots,
    required this.onGenerate,
    required this.onRegenerate,
    required this.onEditPrompt,
    required this.onPreview,
    required this.onContinue,
    required this.onNavigateStep,
    super.key,
    this.demoMode = false,
    this.state = UiLoadState.ready,
    this.onRetry,
  });

  final List<ShotData> shots;
  final ValueChanged<ShotData> onGenerate;
  final ValueChanged<ShotData> onRegenerate;
  final ValueChanged<ShotData> onEditPrompt;
  final ValueChanged<ShotData> onPreview;
  final VoidCallback onContinue;
  final ValueChanged<StudioDestination> onNavigateStep;
  final bool demoMode;
  final UiLoadState state;
  final VoidCallback? onRetry;

  @override
  State<ShotWorkbenchPage> createState() => _ShotWorkbenchPageState();
}

class _ShotWorkbenchPageState extends State<ShotWorkbenchPage> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    if (widget.shots.isEmpty) {
      return SingleChildScrollView(
        child: ResponsiveContent(
          child: StatePanel(
            state: UiLoadState.empty,
            emptyTitle: '等待剧本镜头或服务端返回',
            emptyMessage: '当前项目没有可展示的镜头；请先确认剧本，或稍后刷新服务端状态。',
            child: const SizedBox.shrink(),
          ),
        ),
      );
    }
    final safeIndex = _selectedIndex.clamp(0, widget.shots.length - 1);
    final shot = widget.shots[safeIndex];
    return SingleChildScrollView(
      child: ResponsiveContent(
        maxWidth: 1320,
        child: StatePanel(
          state: widget.state,
          onRetry: widget.onRetry,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudioStepBar(
                activeDestination: StudioDestination.shots,
                onStepTap: widget.onNavigateStep,
              ),
              const SizedBox(height: 24),
              PageIntro(
                eyebrow: '04 · 镜头工作台',
                title: '把分镜变成会动的画面',
                description: '通过角色与场景参考生成首帧、尾帧，再提交图生视频任务。生成过程可以离开本页。',
                trailing: FilledButton.icon(
                  onPressed: widget.onContinue,
                  icon: const Icon(Icons.mic_none_rounded),
                  label: const Text('进入配音'),
                ),
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ProgressStrip(
                        value:
                            widget.shots
                                .where(
                                  (item) =>
                                      item.status == GenerationStatus.completed,
                                )
                                .length /
                            widget.shots.length,
                        label: '镜头成片进度',
                      ),
                    ),
                    const SizedBox(width: 18),
                    StatusPill(status: shot.status, label: '当前镜头'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ShotSelector(
                shots: widget.shots,
                selectedIndex: safeIndex,
                onSelected: (index) => setState(() => _selectedIndex = index),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final preview = _PreviewPanel(
                    shot: shot,
                    onPreview: () => widget.onPreview(shot),
                  );
                  final editor = _ShotEditor(
                    shot: shot,
                    onEditPrompt: () => widget.onEditPrompt(shot),
                    onGenerate: () => widget.onGenerate(shot),
                    onRegenerate: () => widget.onRegenerate(shot),
                  );
                  if (constraints.maxWidth < 850) {
                    return Column(
                      children: [preview, const SizedBox(height: 14), editor],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: preview),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: editor),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _FramePair(shot: shot, demoMode: widget.demoMode),
              const SizedBox(height: 16),
              SurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    IconButton.outlined(
                      tooltip: '上一个镜头',
                      onPressed: safeIndex == 0
                          ? null
                          : () =>
                                setState(() => _selectedIndex = safeIndex - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${safeIndex + 1} / ${widget.shots.length} · ${shot.title}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      tooltip: '下一个镜头',
                      onPressed: safeIndex == widget.shots.length - 1
                          ? null
                          : () =>
                                setState(() => _selectedIndex = safeIndex + 1),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InfoBanner(
                icon: Icons.hourglass_top_rounded,
                title: '任务会在后台继续',
                message: '离开工作台不会中断生成。可在任务中心查看进度、暂停后续任务，或重试失败的镜头。',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShotSelector extends StatelessWidget {
  const _ShotSelector({
    required this.shots,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ShotData> shots;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: shots.indexed.map((entry) {
          final index = entry.$1;
          final shot = entry.$2;
          final selected = index == selectedIndex;
          final color = switch (shot.status) {
            GenerationStatus.completed => Colors.teal,
            GenerationStatus.running => Theme.of(context).colorScheme.primary,
            GenerationStatus.failed => Theme.of(context).colorScheme.error,
            _ => Theme.of(context).colorScheme.outline,
          };
          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => onSelected(index),
              avatar: Icon(
                shot.status == GenerationStatus.completed
                    ? Icons.check_circle_rounded
                    : shot.status == GenerationStatus.running
                    ? Icons.autorenew_rounded
                    : Icons.circle_outlined,
                size: 18,
                color: color,
              ),
              label: Text(
                '${shot.sequence.toString().padLeft(2, '0')} · ${shot.title}',
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.shot, required this.onPreview});

  final ShotData shot;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GeneratedArtwork(
                    title: shot.title,
                    icon: Icons.nightlight_round,
                    color: const Color(0xFF283E70),
                    aspectRatio: 9 / 16,
                    badge: shot.durationLabel,
                  ),
                  IconButton.filled(
                    tooltip: '预览镜头',
                    onPressed: shot.status == GenerationStatus.completed
                        ? onPreview
                        : null,
                    iconSize: 34,
                    padding: const EdgeInsets.all(16),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                  if (shot.status == GenerationStatus.running)
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 46,
                      child: ProgressStrip(value: shot.progress, height: 6),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '镜头 ${shot.sequence.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusPill(status: shot.status),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            shot.camera,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShotEditor extends StatelessWidget {
  const _ShotEditor({
    required this.shot,
    required this.onEditPrompt,
    required this.onGenerate,
    required this.onRegenerate,
  });

  final ShotData shot;
  final VoidCallback onEditPrompt;
  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final busy = shot.status == GenerationStatus.running;
    final complete = shot.status == GenerationStatus.completed;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: shot.title,
            subtitle: '${shot.durationLabel} · ${shot.camera}',
            action: IconButton(
              tooltip: '编辑镜头提示词',
              onPressed: busy ? null : onEditPrompt,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 18),
          Text('动态提示词', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Text(
                shot.prompt,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('稳定参考顺序', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shot.referenceLabels.indexed
                .map(
                  (entry) => Chip(
                    avatar: CircleAvatar(child: Text('${entry.$1 + 1}')),
                    label: Text(entry.$2),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: MetricTile(
                  icon: Icons.hd_outlined,
                  value: '720P',
                  label: '单镜头生成',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricTile(
                  icon: Icons.schedule_rounded,
                  value: shot.durationLabel,
                  label: '镜头时长',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (busy) ...[
            ProgressStrip(value: shot.progress, label: '正在生成视频'),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: busy
                ? null
                : complete
                ? onRegenerate
                : onGenerate,
            icon: Icon(
              complete ? Icons.refresh_rounded : Icons.auto_awesome_rounded,
            ),
            label: Text(
              busy
                  ? '任务生成中'
                  : complete
                  ? '重新生成该镜头'
                  : '生成该镜头',
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 8),
            Text(
              '暂停与取消操作请前往任务中心，避免误触。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FramePair extends StatelessWidget {
  const _FramePair({required this.shot, required this.demoMode});

  final ShotData shot;
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: demoMode ? '首尾帧演示占位' : '首尾帧位置示意',
            subtitle: demoMode
                ? '本地演示用于说明位置关系，不是模型生成帧。'
                : '服务端未返回首尾帧元数据；下方图块仅说明位置关系，不代表帧文件状态。',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final first = GeneratedArtwork(
                title: demoMode
                    ? '首帧演示占位 · ${shot.title}'
                    : '首帧位置示意 · 服务端未返回帧元数据',
                icon: Icons.first_page_rounded,
                color: const Color(0xFF345A82),
                badge: demoMode ? '演示占位' : '元数据未返回',
              );
              final last = GeneratedArtwork(
                title: demoMode ? '尾帧演示占位 · 动作落点' : '尾帧位置示意 · 服务端未返回帧元数据',
                icon: Icons.last_page_rounded,
                color: const Color(0xFF6D426E),
                badge: demoMode ? '演示占位' : '元数据未返回',
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [first, const SizedBox(height: 12), last],
                );
              }
              return Row(
                children: [
                  Expanded(child: first),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(child: last),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
