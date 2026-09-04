import 'package:flutter/material.dart';

import '../../../shared/theme/xingmu_theme.dart';
import '../../../shared/widgets/studio_widgets.dart';
import '../application/multi_track_controller.dart';
import '../domain/multi_track_models.dart';
import '../../voice_sync/domain/subtitle_sync.dart';

class MultiTrackPage extends StatefulWidget {
  const MultiTrackPage({
    required this.controller,
    super.key,
  });

  final MultiTrackController controller;

  @override
  State<MultiTrackPage> createState() => _MultiTrackPageState();
}

class _MultiTrackPageState extends State<MultiTrackPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('多轨混音与 GPU 渲染'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '混音台', icon: Icon(Icons.graphic_eq_rounded)),
            Tab(text: '轨道编辑', icon: Icon(Icons.view_timeline_outlined)),
            Tab(text: 'GPU 渲染', icon: Icon(Icons.speed_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMixerView(theme),
          _buildTrackEditorView(theme),
          _buildGpuRenderView(theme),
        ],
      ),
    );
  }

  Widget _buildMixerView(ThemeData theme) {
    final tracks = widget.controller.tracks;
    if (tracks.isEmpty) {
      return _buildEmptyState(theme, '暂无音频轨道', '请先从字幕时间轴导入或添加轨道');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMasterSection(theme),
          const SizedBox(height: 24),
          Text('轨道混音器（${tracks.length} 轨）',
            style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: tracks.map((track) => _MixerChannel(
              track: track,
              onVolume: (v) => widget.controller.setTrackVolume(track.id, v),
              onPan: (v) => widget.controller.setTrackPan(track.id, v),
              onMute: () => widget.controller.toggleMute(track.id),
              onSolo: () => widget.controller.toggleSolo(track.id),
              onFadeIn: (d) => widget.controller.setTrackFadeIn(track.id, d),
              onFadeOut: (d) => widget.controller.setTrackFadeOut(track.id, d),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterSection(ThemeData theme) {
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('主输出', style: theme.textTheme.titleMedium),
              const Spacer(),
              _TimeBadge(duration: widget.controller.totalDuration),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('Master'),
              Expanded(
                child: Slider(
                  value: widget.controller.masterVolume,
                  min: 0.0,
                  max: 1.5,
                  divisions: 30,
                  label: '${(widget.controller.masterVolume * 100).round()}%',
                  onChanged: widget.controller.setMasterVolume,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${(widget.controller.masterVolume * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackEditorView(ThemeData theme) {
    final tracks = widget.controller.tracks;
    if (tracks.isEmpty) {
      return _buildEmptyState(theme, '暂无轨道', '点击下方按钮添加新轨道');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('轨道列表（${tracks.length}）',
                style: theme.textTheme.titleMedium),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _showAddTrackDialog(theme),
                icon: const Icon(Icons.add),
                label: const Text('添加轨道'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tracks.map((track) => _TrackCard(
            track: track,
            lines: widget.controller.getTrackLines(track.id) ?? [],
            onRemove: () => widget.controller.removeTrack(track.id),
            onToggleMute: () => widget.controller.toggleMute(track.id),
            onToggleSolo: () => widget.controller.toggleSolo(track.id),
            onAddEffect: () => _showEffectDialog(theme, track.id),
            onToggleEffect: (idx) => widget.controller.toggleEffect(track.id, idx),
            onRemoveEffect: (idx) => widget.controller.removeEffect(track.id, idx),
          )),
        ],
      ),
    );
  }

  Widget _buildGpuRenderView(ThemeData theme) {
    final cap = widget.controller.gpuCapability;
    final config = widget.controller.renderConfig;
    final progress = widget.controller.renderProgress;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GpuCapabilityCard(capability: cap),
          const SizedBox(height: 20),
          _buildRenderConfigSection(theme, config),
          const SizedBox(height: 20),
          _buildRenderProgressSection(theme, progress, config),
          const SizedBox(height: 24),
          if (!progress.status.isActive && !progress.status.isTerminal)
            FilledButton.icon(
              onPressed: widget.controller.hasTracks
                  ? () => widget.controller.startRender()
                  : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始 GPU 渲染'),
            ),
          if (progress.status.isActive)
            FilledButton.icon(
              onPressed: widget.controller.cancelRender,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('取消渲染'),
            ),
          if (progress.status == RenderStatus.succeeded)
            SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                    color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '渲染完成 · ${progress.outputPath ?? "输出文件已生成"}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRenderConfigSection(ThemeData theme, GpuRenderConfig config) {
    final availableEncoders = widget.controller.gpuCapability.encoders;

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('渲染配置', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 18),
          _buildConfigRow(theme, '编码器', DropdownButton<GpuEncoder>(
            value: config.encoder,
            items: availableEncoders.map((e) => DropdownMenuItem(
              value: e,
              child: Text(e.label),
            )).toList(),
            onChanged: (v) => widget.controller.setEncoder(v!),
          )),
          _buildConfigRow(theme, '质量预设', DropdownButton<GpuRenderPreset>(
            value: config.preset,
            items: GpuRenderPreset.values.map((p) => DropdownMenuItem(
              value: p,
              child: Text(p.label),
            )).toList(),
            onChanged: (v) => widget.controller.setPreset(v!),
          )),
          _buildConfigRow(theme, 'CRF 质量', Text('${config.crf}')),
          _buildConfigRow(theme, '帧率', Text('${config.fps} fps')),
          _buildConfigRow(theme, '最大码率', Text('${config.maxBitrateKbps} kbps')),
          _buildConfigRow(theme, 'GPU 加速',
            config.isGpuAccelerated
              ? const Icon(Icons.bolt_rounded, color: XingmuTheme.cyanGlow)
              : const Icon(Icons.memory, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildConfigRow(ThemeData theme, String label, Widget control) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(child: control),
        ],
      ),
    );
  }

  Widget _buildRenderProgressSection(
    ThemeData theme,
    RenderProgress progress,
    GpuRenderConfig config,
  ) {
    if (progress.status == RenderStatus.idle) {
      return SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.movie_creation_outlined,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('等待开始渲染', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              '已选择 ${config.encoder.label} · ${config.preset.label}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('渲染状态', style: theme.textTheme.titleMedium),
              const Spacer(),
              Chip(
                label: Text(progress.status.label),
                backgroundColor: progress.status.isTerminal
                    ? (progress.status == RenderStatus.succeeded
                        ? Colors.green.withValues(alpha: .2)
                        : Colors.red.withValues(alpha: .2))
                    : theme.colorScheme.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${progress.progressPercent.toStringAsFixed(1)}%',
                style: theme.textTheme.titleLarge),
              if (progress.fps > 0)
                Text('${progress.fps.toStringAsFixed(0)} fps',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          if (progress.totalFrames > 0)
            Text('帧 ${progress.currentFrame} / ${progress.totalFrames}',
              style: theme.textTheme.bodySmall),
          if (progress.estimatedRemaining > Duration.zero)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '预计剩余 ${_formatDuration(progress.estimatedRemaining)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (progress.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                progress.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.graphic_eq_outlined,
            size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () => _showAddTrackDialog(theme),
            icon: const Icon(Icons.add),
            label: const Text('添加轨道'),
          ),
        ],
      ),
    );
  }

  void _showAddTrackDialog(ThemeData theme) {
    VoiceTrackType selectedType = VoiceTrackType.dialogue;
    String name = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('添加音频轨道'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<VoiceTrackType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: '轨道类型'),
                items: VoiceTrackType.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.label),
                )).toList(),
                onChanged: (v) => setState(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: '轨道名称',
                  hintText: '留空使用默认名称',
                ),
                onChanged: (v) => name = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                widget.controller.addTrack(type: selectedType, name: name);
                Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEffectDialog(ThemeData theme, String trackId) {
    TrackEffectKind selected = TrackEffectKind.reverb;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('添加音频效果'),
          content: DropdownButtonFormField<TrackEffectKind>(
            value: selected,
            decoration: const InputDecoration(labelText: '效果类型'),
            items: TrackEffectKind.values.map((e) => DropdownMenuItem(
              value: e,
              child: Text(e.label),
            )).toList(),
            onChanged: (v) => setState(() => selected = v!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                widget.controller.addEffect(trackId, TrackEffect(kind: selected));
                Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m}m ${s}s';
  }
}

class _MixerChannel extends StatelessWidget {
  const _MixerChannel({
    required this.track,
    required this.onVolume,
    required this.onPan,
    required this.onMute,
    required this.onSolo,
    required this.onFadeIn,
    required this.onFadeOut,
  });

  final AudioTrackConfig track;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onPan;
  final VoidCallback onMute;
  final VoidCallback onSolo;
  final ValueChanged<Duration> onFadeIn;
  final ValueChanged<Duration> onFadeOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(track.color);

    return SizedBox(
      width: 220,
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: .2),
                  foregroundColor: color,
                  child: Text(track.type.label.characters.first),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(track.name,
                    style: theme.textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _VolumeSlider(
              value: track.volume,
              color: color,
              onChanged: onVolume,
            ),
            const SizedBox(height: 10),
            _PanKnob(value: track.pan, onChanged: onPan),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ToggleButton(
                  label: 'M',
                  active: track.muted,
                  activeColor: Colors.red,
                  onPressed: onMute,
                ),
                _ToggleButton(
                  label: 'S',
                  active: track.solo,
                  activeColor: Colors.amber,
                  onPressed: onSolo,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (track.fadeIn > Duration.zero || track.fadeOut > Duration.zero)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '淡入 ${track.fadeIn.inMilliseconds}ms · 淡出 ${track.fadeOut.inMilliseconds}ms',
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.volume_down_rounded, size: 18, color: color),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.5,
              divisions: 30,
              activeColor: color,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${(value * 100).round()}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _PanKnob extends StatelessWidget {
  const _PanKnob({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = value < -0.1
        ? 'L ${(value.abs() * 100).round()}'
        : value > 0.1
          ? 'R ${(value * 100).round()}'
          : 'C';

    return Row(
      children: [
        Icon(Icons.swap_horiz_rounded, size: 16,
          color: theme.colorScheme.onSurfaceVariant),
        Expanded(
          child: Slider(
            value: value,
            min: -1.0,
            max: 1.0,
            divisions: 20,
            label: label,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(label,
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 32,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: active ? activeColor : null,
          minimumSize: const Size(40, 32),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.track,
    required this.lines,
    required this.onRemove,
    required this.onToggleMute,
    required this.onToggleSolo,
    required this.onAddEffect,
    required this.onToggleEffect,
    required this.onRemoveEffect,
  });

  final AudioTrackConfig track;
  final List<SubtitleLine> lines;
  final VoidCallback onRemove;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSolo;
  final VoidCallback onAddEffect;
  final ValueChanged<int> onToggleEffect;
  final ValueChanged<int> onRemoveEffect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(track.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.name, style: theme.textTheme.titleMedium),
                      Text('${track.type.label} · ${lines.length} 条音频段',
                        style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (track.effects.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text('${track.effects.where((e) => e.enabled).length} 效果'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onRemove,
                  color: theme.colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMiniTimeline(theme, color),
            if (track.effects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('效果链', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: track.effects.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final effect = entry.value;
                  return Chip(
                    label: Text(effect.kind.label),
                    avatar: Icon(
                      effect.enabled ? Icons.check_circle : Icons.block,
                      size: 16,
                      color: effect.enabled ? Colors.green : Colors.grey,
                    ),
                    onDeleted: () => onRemoveEffect(idx),
                    deleteIconColor: Colors.red,
                    backgroundColor: effect.enabled
                        ? color.withValues(alpha: .15)
                        : theme.colorScheme.surfaceContainerHighest,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onAddEffect,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('效果'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onToggleMute,
                  child: Text(track.muted ? '取消静音' : '静音'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onToggleSolo,
                  child: Text(track.solo ? '取消独奏' : '独奏'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTimeline(ThemeData theme, Color color) {
    if (lines.isEmpty) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text('无音频段',
            style: theme.textTheme.bodySmall),
        ),
      );
    }

    final totalMs = lines.fold<int>(0, (sum, l) =>
      sum + l.endTimestamp.inMilliseconds);
    if (totalMs == 0) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: lines.map((line) {
            final leftRatio = line.startTimestamp.inMilliseconds / totalMs;
            final widthRatio = (line.endTimestamp - line.startTimestamp).inMilliseconds / totalMs;
            final w = constraints.maxWidth;
            return Positioned(
              left: leftRatio * w,
              width: widthRatio * w,
              top: 4,
              bottom: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}

class _GpuCapabilityCard extends StatelessWidget {
  const _GpuCapabilityCard({required this.capability});

  final GpuCapability capability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('GPU 能力检测', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (capability.hasGpuAcceleration)
                Chip(
                  label: const Text('GPU 加速可用'),
                  backgroundColor: Colors.green.withValues(alpha: .15),
                  avatar: const Icon(Icons.bolt_rounded,
                    color: Colors.green, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(label: '供应商', value: capability.vendor),
          _InfoRow(label: '设备', value: capability.deviceName),
          if (capability.vramMb > 0)
            _InfoRow(label: '显存', value: '${capability.vramMb ~/ 1024} GB'),
          if (capability.cudaCores > 0)
            _InfoRow(label: 'CUDA 核心', value: '${capability.cudaCores}'),
          if (capability.computeCapability != null)
            _InfoRow(label: '计算能力', value: capability.computeCapability!),
          const SizedBox(height: 10),
          Text('可用编码器', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: capability.encoders.map((e) => Chip(
              label: Text(e.label),
              avatar: Icon(
                e.isGpu ? Icons.bolt_rounded : Icons.memory,
                size: 16,
                color: e.isGpu ? Colors.green : Colors.grey,
              ),
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  const _TimeBadge({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final m = duration.inMinutes;
    final s = duration.inSeconds.remainder(60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
