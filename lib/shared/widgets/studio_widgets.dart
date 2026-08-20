import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/models/studio_view_data.dart';

class XingmuLogo extends StatelessWidget {
  const XingmuLogo({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: Image.asset(
        'assets/branding/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                Icons.auto_awesome_motion_rounded,
                size: size * .58,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    super.key,
    this.maxWidth = 1240,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 16.0 : 28.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                horizontal,
                width < 600 ? 18 : 28,
                horizontal,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
          child: child,
        ),
      ),
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    required this.eyebrow,
    required this.title,
    required this.description,
    super.key,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 7),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (trailing == null) return text;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 16), trailing!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            const SizedBox(width: 24),
            trailing!,
          ],
        );
      },
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key, this.label});

  final GenerationStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (text, color, icon) = switch (status) {
      GenerationStatus.draft => (
        '草稿',
        scheme.onSurfaceVariant,
        Icons.edit_note,
      ),
      GenerationStatus.queued => ('排队中', scheme.secondary, Icons.schedule),
      GenerationStatus.running => ('生成中', scheme.primary, Icons.auto_awesome),
      GenerationStatus.paused => ('已暂停', Colors.orange, Icons.pause_circle),
      GenerationStatus.failed => ('失败', scheme.error, Icons.error_outline),
      GenerationStatus.canceled => (
        '已取消',
        scheme.onSurfaceVariant,
        Icons.cancel_outlined,
      ),
      GenerationStatus.completed => (
        '已完成',
        Colors.teal,
        Icons.check_circle_outline,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label ?? text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressStrip extends StatelessWidget {
  const ProgressStrip({
    required this.value,
    super.key,
    this.label,
    this.height = 8,
  });

  final double value;
  final String? label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Text('${(value.clamp(0, 1) * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: height,
            value: value.clamp(0, 1),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class StatePanel extends StatelessWidget {
  const StatePanel({
    required this.state,
    required this.child,
    super.key,
    this.emptyTitle = '暂无内容',
    this.emptyMessage = '完成上一步后，内容会出现在这里。',
    this.errorTitle = '加载失败',
    this.errorMessage = '请检查网络或稍后重试。',
    this.onRetry,
    this.onEmptyAction,
    this.emptyActionLabel = '开始创作',
  });

  final UiLoadState state;
  final Widget child;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;
  final String errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onEmptyAction;
  final String emptyActionLabel;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      UiLoadState.ready => child,
      UiLoadState.loading => const _CenteredState(
        icon: SizedBox.square(
          dimension: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        title: '正在同步项目',
        message: '正在获取最新的剧本、素材与生成任务……',
      ),
      UiLoadState.empty => _CenteredState(
        icon: Icon(
          Icons.inbox_outlined,
          size: 46,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: emptyTitle,
        message: emptyMessage,
        action: onEmptyAction == null
            ? null
            : FilledButton.icon(
                onPressed: onEmptyAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(emptyActionLabel),
              ),
      ),
      UiLoadState.error => _CenteredState(
        icon: Icon(
          Icons.cloud_off_outlined,
          size: 46,
          color: Theme.of(context).colorScheme.error,
        ),
        title: errorTitle,
        message: errorMessage,
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
      ),
    };
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Widget icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minHeight: 330),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class GeneratedArtwork extends StatelessWidget {
  const GeneratedArtwork({
    required this.title,
    required this.icon,
    required this.color,
    super.key,
    this.aspectRatio = 16 / 10,
    this.badge,
  });

  final String title;
  final IconData icon;
  final Color color;
  final double aspectRatio;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: .92),
                    Color.lerp(color, Colors.black, .55)!,
                  ],
                ),
              ),
            ),
            CustomPaint(painter: _ConstellationPainter()),
            Align(
              child: Icon(
                icon,
                size: 56,
                color: Colors.white.withValues(alpha: .85),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                right: 10,
                top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .48),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..strokeWidth = 1;
    const seeds = <Offset>[
      Offset(.12, .18),
      Offset(.32, .36),
      Offset(.57, .17),
      Offset(.81, .29),
      Offset(.68, .66),
      Offset(.24, .73),
      Offset(.9, .82),
    ];
    for (var i = 0; i < seeds.length; i++) {
      final start = Offset(seeds[i].dx * size.width, seeds[i].dy * size.height);
      final endSeed = seeds[(i + 2) % seeds.length];
      final end = Offset(endSeed.dx * size.width, endSeed.dy * size.height);
      canvas.drawLine(start, end, paint);
      canvas.drawCircle(start, 2 + math.sin(i.toDouble()).abs() * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Waveform extends StatelessWidget {
  const Waveform({super.key, this.color, this.bars = 32, this.height = 36});

  final Color? color;
  final int bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final waveColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(bars, (index) {
          final factor = .2 + (math.sin(index * 1.73).abs() * .8);
          return Expanded(
            child: Align(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: height * factor,
                decoration: BoxDecoration(
                  color: waveColor.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.tone,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action!],
          ],
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StudioStepBar extends StatelessWidget {
  const StudioStepBar({
    required this.activeDestination,
    required this.onStepTap,
    super.key,
  });

  final StudioDestination activeDestination;
  final ValueChanged<StudioDestination> onStepTap;

  static const _steps = <(StudioDestination, String)>[
    (StudioDestination.script, '剧本'),
    (StudioDestination.assets, '资产'),
    (StudioDestination.shots, '镜头'),
    (StudioDestination.voice, '配音'),
    (StudioDestination.result, '成片'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _steps.indexed.map((entry) {
          final index = entry.$1;
          final step = entry.$2;
          final selected = step.$1 == activeDestination;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  child: Text('${index + 1}'),
                ),
                label: Text(step.$2),
                onPressed: () => onStepTap(step.$1),
                side: BorderSide(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              if (index < _steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
