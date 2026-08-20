import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/widgets/studio_widgets.dart';

class VoiceStudioPage extends StatelessWidget {
  const VoiceStudioPage({
    required this.cast,
    required this.lines,
    required this.onPreviewVoice,
    required this.onChangeVoice,
    required this.onPlayLine,
    required this.onGenerateLine,
    required this.onGenerateAll,
    required this.onGenerateAllMissing,
    required this.onContinue,
    required this.onNavigateStep,
    super.key,
    this.canPreviewVoice = false,
    this.canChangeVoice = false,
    this.canPlayLine = false,
    this.canGenerateLine = false,
    this.canGenerateAll = false,
    this.state = UiLoadState.ready,
    this.onRetry,
  });

  final List<VoiceCastData> cast;
  final List<VoiceLineData> lines;
  final ValueChanged<VoiceCastData> onPreviewVoice;
  final ValueChanged<VoiceCastData> onChangeVoice;
  final ValueChanged<VoiceLineData> onPlayLine;
  final ValueChanged<VoiceLineData> onGenerateLine;
  final VoidCallback onGenerateAll;
  final VoidCallback onGenerateAllMissing;
  final VoidCallback onContinue;
  final ValueChanged<StudioDestination> onNavigateStep;
  final bool canPreviewVoice;
  final bool canChangeVoice;
  final bool canPlayLine;
  final bool canGenerateLine;
  final bool canGenerateAll;
  final UiLoadState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsiveContent(
        maxWidth: 1160,
        child: StatePanel(
          state: state,
          onRetry: onRetry,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudioStepBar(
                activeDestination: StudioDestination.voice,
                onStepTap: onNavigateStep,
              ),
              const SizedBox(height: 24),
              PageIntro(
                eyebrow: '05 · 配音工作台',
                title: '让每个角色有自己的声音',
                description:
                    '语速、情绪、停顿与逐句时长仍在规划中，客户端未读取这些参数；本页仅展示服务端明确返回的声线名与音频可用状态，未返回时标为未知。',
                trailing: FilledButton.icon(
                  onPressed: onGenerateAllMissing,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('生成项目全部缺失项'),
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(
                title: '角色声线',
                subtitle: '仅展示服务端明确声线名；未返回时显示未知，试听与更换尚未接入',
              ),
              const SizedBox(height: 12),
              _CastGrid(
                cast: cast,
                onPreview: onPreviewVoice,
                onChange: onChangeVoice,
                canPreview: canPreviewVoice,
                canChange: canChangeVoice,
              ),
              const SizedBox(height: 28),
              SectionHeader(
                title: '台词与旁白',
                subtitle: '${lines.length} 句 · 仅显示音频是否已返回，不推断时长或对齐状态',
                action: TextButton.icon(
                  onPressed: canGenerateAll ? onGenerateAll : null,
                  icon: const Icon(Icons.graphic_eq_rounded),
                  label: Text(canGenerateAll ? '批量生成' : '批量生成尚未接入'),
                ),
              ),
              const SizedBox(height: 12),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _VoiceLineCard(
                    line: line,
                    onPlay: () => onPlayLine(line),
                    onGenerate: () => onGenerateLine(line),
                    canPlay: canPlayLine,
                    canGenerate: canGenerateLine,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InfoBanner(
                icon: Icons.subtitles_outlined,
                title: '字幕时间轴尚未接入',
                message: '客户端没有逐句时长或字幕时间码字段，不会根据音频地址推断对齐状态。',
                tone: Colors.teal,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.video_file_outlined),
                label: const Text('前往任务中心'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CastGrid extends StatelessWidget {
  const _CastGrid({
    required this.cast,
    required this.onPreview,
    required this.onChange,
    required this.canPreview,
    required this.canChange,
  });

  final List<VoiceCastData> cast;
  final ValueChanged<VoiceCastData> onPreview;
  final ValueChanged<VoiceCastData> onChange;
  final bool canPreview;
  final bool canChange;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cast
              .map(
                (voice) => SizedBox(
                  width: width,
                  child: _CastCard(
                    voice: voice,
                    onPreview: () => onPreview(voice),
                    onChange: () => onChange(voice),
                    canPreview: canPreview,
                    canChange: canChange,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({
    required this.voice,
    required this.onPreview,
    required this.onChange,
    required this.canPreview,
    required this.canChange,
  });

  final VoiceCastData voice;
  final VoidCallback onPreview;
  final VoidCallback onChange;
  final bool canPreview;
  final bool canChange;

  @override
  Widget build(BuildContext context) {
    final color = Color(voice.colorValue);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: .16),
                foregroundColor: color,
                child: Text(
                  voice.character.characters.first,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voice.character,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${voice.voiceName} · ${voice.description}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: canPreview ? '试听 ${voice.character} 的声线' : '音频试听尚未接入',
                onPressed: canPreview ? onPreview : null,
                icon: Icon(
                  canPreview
                      ? Icons.play_arrow_rounded
                      : Icons.play_disabled_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Waveform(color: color),
          const SizedBox(height: 10),
          Text(
            '“${voice.sampleText}”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: canChange ? onChange : null,
            icon: const Icon(Icons.tune_rounded),
            label: Text(canChange ? '更换声线' : '更换声线尚未接入'),
          ),
        ],
      ),
    );
  }
}

class _VoiceLineCard extends StatelessWidget {
  const _VoiceLineCard({
    required this.line,
    required this.onPlay,
    required this.onGenerate,
    required this.canPlay,
    required this.canGenerate,
  });

  final VoiceLineData line;
  final VoidCallback onPlay;
  final VoidCallback onGenerate;
  final bool canPlay;
  final bool canGenerate;

  @override
  Widget build(BuildContext context) {
    final complete = line.status == GenerationStatus.completed;
    final running = line.status == GenerationStatus.running;
    final queued = line.status == GenerationStatus.queued;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
                child: Text(line.speaker.characters.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          line.speaker,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          line.durationLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      line.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (running) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '配音生成中 · 服务端未返回精确进度',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (queued) ...[
                      const SizedBox(height: 6),
                      Text(
                        '服务端任务处于排队状态',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
          final action = IconButton.filledTonal(
            tooltip: complete
                ? canPlay
                      ? '播放该句'
                      : '音频播放尚未接入'
                : running
                ? '正在生成'
                : queued
                ? '等待上游任务'
                : canGenerate
                ? '生成该句'
                : '单句生成尚未接入',
            onPressed: running || queued
                ? null
                : complete
                ? canPlay
                      ? onPlay
                      : null
                : canGenerate
                ? onGenerate
                : null,
            icon: Icon(
              complete
                  ? canPlay
                        ? Icons.play_arrow_rounded
                        : Icons.play_disabled_outlined
                  : running
                  ? Icons.autorenew_rounded
                  : queued
                  ? Icons.schedule_rounded
                  : Icons.auto_awesome_rounded,
            ),
          );
          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }
}
