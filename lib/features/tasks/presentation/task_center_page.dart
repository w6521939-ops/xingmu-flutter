import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/widgets/studio_widgets.dart';

enum TaskFilter { all, active, failed, completed }

class TaskCenterPage extends StatefulWidget {
  const TaskCenterPage({
    required this.tasks,
    required this.onPause,
    required this.onResume,
    required this.onRetryTask,
    required this.onCancelTask,
    required this.onOpenCompleted,
    super.key,
    this.state = UiLoadState.ready,
    this.onRetryPage,
    this.onAdvance,
    this.advanceLabel = '刷新状态',
  });

  final List<TaskItemData> tasks;
  final ValueChanged<TaskItemData> onPause;
  final ValueChanged<TaskItemData> onResume;
  final ValueChanged<TaskItemData> onRetryTask;
  final ValueChanged<TaskItemData> onCancelTask;
  final ValueChanged<TaskItemData> onOpenCompleted;
  final UiLoadState state;
  final VoidCallback? onRetryPage;
  final VoidCallback? onAdvance;
  final String advanceLabel;

  @override
  State<TaskCenterPage> createState() => _TaskCenterPageState();
}

class _TaskCenterPageState extends State<TaskCenterPage> {
  TaskFilter _filter = TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final visibleTasks = widget.tasks.where(_matchesFilter).toList();
    final activeCount = widget.tasks
        .where(
          (task) =>
              task.status == GenerationStatus.running ||
              task.status == GenerationStatus.queued,
        )
        .length;
    final failedCount = widget.tasks
        .where((task) => task.status == GenerationStatus.failed)
        .length;
    return SingleChildScrollView(
      child: ResponsiveContent(
        maxWidth: 1080,
        child: StatePanel(
          state: widget.state,
          onRetry: widget.onRetryPage,
          emptyTitle: '暂无生成任务',
          emptyMessage: '从剧本、视觉资产或镜头工作台提交任务后，会在这里显示真实状态。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageIntro(
                eyebrow: '任务中心',
                title: '后台生成进度',
                description:
                    '切换页面不会重置当前状态；连接真实后端时，已受理任务由服务端继续执行。失败项会展示服务端返回的原因，并通过幂等请求安全重试。',
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(
                          status: GenerationStatus.running,
                          label: '$activeCount 进行中',
                        ),
                        StatusPill(
                          status: GenerationStatus.failed,
                          label: '$failedCount 需处理',
                        ),
                      ],
                    ),
                    if (widget.onAdvance != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: widget.onAdvance,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(widget.advanceLabel),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<TaskFilter>(
                  segments: const [
                    ButtonSegment(value: TaskFilter.all, label: Text('全部')),
                    ButtonSegment(value: TaskFilter.active, label: Text('进行中')),
                    ButtonSegment(value: TaskFilter.failed, label: Text('需处理')),
                    ButtonSegment(
                      value: TaskFilter.completed,
                      label: Text('已完成'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) =>
                      setState(() => _filter = selection.first),
                ),
              ),
              const SizedBox(height: 16),
              if (visibleTasks.isEmpty)
                SurfaceCard(
                  child: StatePanel(
                    state: UiLoadState.empty,
                    emptyTitle: '该筛选下没有任务',
                    emptyMessage: '切换到“全部”可查看其他状态。',
                    child: const SizedBox.shrink(),
                  ),
                )
              else
                ...visibleTasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TaskCard(
                      task: task,
                      onPause: () => widget.onPause(task),
                      onResume: () => widget.onResume(task),
                      onRetry: () => widget.onRetryTask(task),
                      onCancel: () => widget.onCancelTask(task),
                      onOpen: () => widget.onOpenCompleted(task),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              InfoBanner(
                icon: Icons.info_outline_rounded,
                title: '排队任务不可单独开始',
                message: '当前项目采用稳定的参考顺序，下游镜头必须等待上游资产完成。所以“排队中”操作按钮会明确禁用。',
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(TaskItemData task) => switch (_filter) {
    TaskFilter.all => true,
    TaskFilter.active =>
      task.status == GenerationStatus.running ||
          task.status == GenerationStatus.queued ||
          task.status == GenerationStatus.paused,
    TaskFilter.failed => task.status == GenerationStatus.failed,
    TaskFilter.completed => task.status == GenerationStatus.completed,
  };
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onCancel,
    required this.onOpen,
  });

  final TaskItemData task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final statusIcon = switch (task.status) {
      GenerationStatus.running => Icons.auto_awesome_rounded,
      GenerationStatus.queued => Icons.schedule_rounded,
      GenerationStatus.paused => Icons.pause_circle_outline_rounded,
      GenerationStatus.failed => Icons.error_outline_rounded,
      GenerationStatus.canceled => Icons.cancel_outlined,
      GenerationStatus.completed => Icons.check_circle_outline_rounded,
      GenerationStatus.draft => Icons.edit_note_rounded,
    };
    final tone = switch (task.status) {
      GenerationStatus.running => Theme.of(context).colorScheme.primary,
      GenerationStatus.failed => Theme.of(context).colorScheme.error,
      GenerationStatus.completed => Colors.teal,
      GenerationStatus.paused => Colors.orange,
      GenerationStatus.canceled => Theme.of(context).colorScheme.outline,
      _ => Theme.of(context).colorScheme.outline,
    };
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(statusIcon, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(status: task.status),
            ],
          ),
          if (task.status != GenerationStatus.queued &&
              task.status != GenerationStatus.canceled) ...[
            const SizedBox(height: 16),
            ProgressStrip(value: task.progress, label: task.stageLabel),
          ],
          if (task.failureMessage != null) ...[
            const SizedBox(height: 14),
            InfoBanner(
              icon: Icons.report_gmailerrorred_rounded,
              title: '失败原因',
              message: task.failureMessage!,
              tone: Theme.of(context).colorScheme.error,
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttons = _buildActions(context);
              return Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      task.updatedLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ...buttons,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) => switch (task.status) {
    GenerationStatus.running => [
      OutlinedButton.icon(
        onPressed: onPause,
        icon: const Icon(Icons.pause_rounded),
        label: const Text('暂停后续'),
      ),
      TextButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.close_rounded),
        label: const Text('取消当前队列'),
      ),
    ],
    GenerationStatus.paused => [
      FilledButton.tonalIcon(
        onPressed: onResume,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('继续任务'),
      ),
      TextButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.close_rounded),
        label: const Text('取消'),
      ),
    ],
    GenerationStatus.failed => [
      FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('安全重试'),
      ),
    ],
    GenerationStatus.completed => [
      OutlinedButton.icon(
        onPressed: task.resultDestination == null ? null : onOpen,
        icon: const Icon(Icons.open_in_new_rounded),
        label: Text(task.resultDestination == null ? '暂无可查看结果' : '查看结果'),
      ),
    ],
    GenerationStatus.canceled => const [],
    GenerationStatus.queued => [
      Tooltip(
        message: '需等待上游资产完成',
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.lock_clock_outlined),
          label: const Text('等待上游'),
        ),
      ),
      TextButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.close_rounded),
        label: const Text('取消当前队列'),
      ),
    ],
    GenerationStatus.draft => [
      OutlinedButton.icon(
        onPressed: onResume,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('提交任务'),
      ),
    ],
  };
}
