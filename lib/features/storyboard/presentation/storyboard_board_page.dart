import 'package:flutter/material.dart';

import '../domain/camera_motion.dart';
import '../domain/storyboard_planner.dart';

class StoryboardBoardPage extends StatefulWidget {
  const StoryboardBoardPage({
    super.key,
    this.shots = const [],
    this.onMotionChanged,
  });

  final List<StoryboardShot> shots;
  final void Function(int index, CameraMotion motion)? onMotionChanged;

  @override
  State<StoryboardBoardPage> createState() => _StoryboardBoardPageState();
}

class _StoryboardBoardPageState extends State<StoryboardBoardPage> {
  late List<StoryboardShot> _shots;

  @override
  void initState() {
    super.initState();
    _shots = StoryboardPlanner.autoPlan(widget.shots);
  }

  @override
  void didUpdateWidget(StoryboardBoardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shots != widget.shots) {
      _shots = StoryboardPlanner.autoPlan(widget.shots);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalDuration = StoryboardPlanner.estimateRenderTime(_shots);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分镜画幅大盘'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                StoryboardPlanner.formatDuration(totalDuration),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: _shots.isEmpty
          ? const Center(child: Text('暂无分镜数据'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _shots.length,
              itemBuilder: (context, index) => _buildShotCard(context, index, theme),
            ),
    );
  }

  Widget _buildShotCard(BuildContext context, int index, ThemeData theme) {
    final shot = _shots[index];
    final motion = shot.motion;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${shot.order}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shot.title,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                _buildStatusChip(theme, shot.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildThreeColumnBoard(context, shot, theme),
            const SizedBox(height: 12),
            if (motion != null) _buildMotionEditor(context, index, motion, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildThreeColumnBoard(
    BuildContext context,
    StoryboardShot shot,
    ThemeData theme,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildFrameColumn(
              theme,
              '首帧',
              shot.firstFrameUrl,
              Icons.image_outlined,
            ),
          ),
          Container(
            width: 80,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _motionIcon(shot.motion?.type),
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  shot.motion?.type.label ?? '静止',
                  style: theme.textTheme.labelSmall,
                ),
                if (shot.motion != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${shot.durationSeconds.toStringAsFixed(0)}s',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _buildFrameColumn(
              theme,
              '尾帧',
              shot.lastFrameUrl,
              Icons.image_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameColumn(
    ThemeData theme,
    String label,
    String? url,
    IconData placeholder,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: url != null
                  ? Image.network(url, fit: BoxFit.cover)
                  : Container(
                      color: theme.colorScheme.surfaceContainer,
                      child: Icon(placeholder, size: 32, color: theme.colorScheme.outline),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotionEditor(
    BuildContext context,
    int index,
    CameraMotion motion,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('运镜：', style: theme.textTheme.labelMedium),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<CameraMotionType>(
              value: motion.type,
              isExpanded: true,
              items: CameraMotionType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
              onChanged: (type) {
                if (type == null) return;
                final newMotion = StoryboardPlanner.autoDetect(type.name);
                setState(() {
                  _shots[index] = _shots[index].copyWith(motion: newMotion);
                });
                widget.onMotionChanged?.call(index, newMotion);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              motion.durationSeconds.toStringAsFixed(0) + 's',
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, ShotStatus status) {
    final color = switch (status) {
      ShotStatus.pending => theme.colorScheme.outline,
      ShotStatus.generating => Colors.orange,
      ShotStatus.completed => Colors.green,
      ShotStatus.failed => theme.colorScheme.error,
      ShotStatus.skipped => theme.colorScheme.outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }

  IconData _motionIcon(CameraMotionType? type) => switch (type) {
    CameraMotionType.zoomIn => Icons.zoom_in,
    CameraMotionType.zoomOut => Icons.zoom_out,
    CameraMotionType.panLeft => Icons.arrow_back,
    CameraMotionType.panRight => Icons.arrow_forward,
    CameraMotionType.tiltUp => Icons.arrow_upward,
    CameraMotionType.tiltDown => Icons.arrow_downward,
    CameraMotionType.staticShot => Icons.pan_tool,
    CameraMotionType.kenBurns => Icons.auto_awesome,
    null => Icons.pan_tool,
  };
}
