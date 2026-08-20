import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/theme/xingmu_theme.dart';
import '../../../shared/widgets/studio_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.projects,
    required this.onCreateProject,
    required this.onOpenProject,
    required this.onNavigate,
    super.key,
    this.demoMode = false,
    this.state = UiLoadState.ready,
    this.onRetry,
  });

  final List<ProjectCardData> projects;
  final VoidCallback onCreateProject;
  final ValueChanged<ProjectCardData> onOpenProject;
  final ValueChanged<StudioDestination> onNavigate;
  final bool demoMode;
  final UiLoadState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final featured = projects.isEmpty ? null : projects.first;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final visibleState = state == UiLoadState.empty ? UiLoadState.ready : state;
    return Stack(
      children: [
        const Positioned.fill(child: _HomeAtmosphere()),
        SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 1180,
            child: StatePanel(
              state: visibleState,
              onRetry: onRetry,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FeaturedProjectHero(
                    project: featured,
                    demoMode: demoMode,
                    onPressed: featured == null
                        ? onCreateProject
                        : () => onOpenProject(featured),
                  ),
                  SizedBox(height: compact ? 8 : 16),
                  _ProductionFlow(
                    progress: demoMode ? featured?.progress : null,
                    onNavigate: onNavigate,
                  ),
                  SizedBox(height: compact ? 12 : 28),
                  _HomeSectionTitle(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI 创作工具',
                    subtitle: '从一句灵感到会动的漫剧',
                  ),
                  SizedBox(height: compact ? 6 : 13),
                  _CreationToolGrid(onNavigate: onNavigate),
                  SizedBox(height: compact ? 12 : 28),
                  SectionHeader(
                    title: '最近项目',
                    subtitle: projects.isEmpty ? '真实项目会在这里显示' : '继续上次的创作进度',
                    action: TextButton.icon(
                      onPressed: projects.isEmpty
                          ? onCreateProject
                          : () => onNavigate(StudioDestination.tasks),
                      icon: Icon(
                        projects.isEmpty
                            ? Icons.add_rounded
                            : Icons.chevron_right_rounded,
                        size: 19,
                      ),
                      label: Text(projects.isEmpty ? '新建' : '查看任务'),
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 13),
                  if (projects.isEmpty)
                    _EmptyRecentProjects(onCreateProject: onCreateProject)
                  else
                    _RecentProjectGrid(
                      projects: projects,
                      demoMode: demoMode,
                      onOpen: onOpenProject,
                    ),
                  const SizedBox(height: 12),
                  InfoBanner(
                    icon: Icons.security_rounded,
                    title: '模型密钥不进入手机端',
                    message: demoMode
                        ? '当前是演示模式，所有进度和封面都是本地展示，不会提交模型请求。'
                        : '手机端只提交创作意图并查看结果；百炼和自托管 Provider 凭据留在受信服务端。',
                    tone: XingmuTheme.cyanGlow,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeAtmosphere extends StatelessWidget {
  const _HomeAtmosphere();

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.82, -.76),
            radius: 1.12,
            colors: [Color(0x282F5FFF), Color(0x00050A16)],
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.86, .18),
              radius: .92,
              colors: [Color(0x1F00D7FF), Color(0x00050A16)],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedProjectHero extends StatelessWidget {
  const _FeaturedProjectHero({
    required this.project,
    required this.demoMode,
    required this.onPressed,
  });

  final ProjectCardData? project;
  final bool demoMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final title = project?.title ?? (demoMode ? '月背最后一单' : '开始新的漫剧项目');
    final progress = project?.progress;
    final progressPercent = ((progress ?? 0).clamp(0, 1) * 100).round();
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Semantics(
      key: const ValueKey('home-featured-hero'),
      button: true,
      label: '${project == null ? '开始' : '继续'}创作 $title',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 24 : 30),
          border: Border.all(color: const Color(0x66516B9C)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332B57FF),
              blurRadius: 38,
              offset: Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: demoMode
                  ? Image.asset(
                      'assets/showcase/moon-courier-hero.png',
                      key: const ValueKey('home-demo-cover-hero'),
                      fit: BoxFit.cover,
                      alignment: compact
                          ? const Alignment(.58, 0)
                          : Alignment.center,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: XingmuTheme.deepNavy,
                            child: Center(
                              child: Icon(
                                Icons.public_rounded,
                                size: 92,
                                color: XingmuTheme.cyanGlow,
                              ),
                            ),
                          ),
                    )
                  : const _RemoteHeroPlaceholder(),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [.0, .48, 1],
                    colors: [
                      Color(0xF2050A16),
                      Color(0xC2091020),
                      Color(0x1A07101E),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x18000000),
                      Color(0x10000000),
                      Color(0xD9050913),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 16 : 36),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: compact ? 258 : 358,
                    maxWidth: 440,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroBadge(
                        label: demoMode
                            ? project == null
                                  ? '视觉概念示例 · 非生成结果'
                                  : project!.stageLabel
                            : project == null
                            ? '项目封面位置示意'
                            : '服务端未返回封面 · ${project!.stageLabel}',
                      ),
                      SizedBox(height: compact ? 8 : 15),
                      Text(
                        title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: compact ? 28 : 40,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.8,
                            ),
                      ),
                      SizedBox(height: compact ? 4 : 9),
                      Text(
                        project?.summary ??
                            (demoMode
                                ? '示例封面 · 创建项目后才会显示真实生成进度'
                                : '服务端尚未返回项目封面；创建项目后这里显示服务端阶段。'),
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .72),
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 62),
                      if (project != null && progress != null) ...[
                        if (compact)
                          Row(
                            children: [
                              Text(
                                project!.progressLabel,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: .7),
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                '$progressPercent%',
                                style: const TextStyle(
                                  color: XingmuTheme.cyanGlow,
                                  fontSize: 24,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          Text(
                            project!.progressLabel,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: .7),
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$progressPercent',
                                  style: const TextStyle(
                                    color: XingmuTheme.cyanGlow,
                                    fontSize: 43,
                                    height: 1.08,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const TextSpan(
                                  text: '%',
                                  style: TextStyle(
                                    color: XingmuTheme.cyanGlow,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: compact ? 5 : 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 7,
                            value: progress,
                            backgroundColor: Colors.black.withValues(
                              alpha: .42,
                            ),
                            valueColor: const AlwaysStoppedAnimation(
                              XingmuTheme.cyanGlow,
                            ),
                          ),
                        ),
                      ] else if (project != null)
                        Text(
                          '服务端尚未返回生成进度。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: .74),
                              ),
                        )
                      else
                        Text(
                          '项目尚未创建，不展示占位生成进度。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: .74),
                              ),
                        ),
                      SizedBox(height: compact ? 12 : 18),
                      _GradientActionButton(
                        label: project == null ? '开始创作' : '继续创作',
                        onPressed: onPressed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: IconButton.filledTonal(
                tooltip: project == null ? '开始创作' : '打开项目',
                onPressed: onPressed,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xB3172036),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB0231A52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x996E5CFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 190),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [XingmuTheme.purpleGlow, Color(0xFF397EFF)],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(color: Color(0x55705CFF), blurRadius: 20),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(label, textAlign: TextAlign.center)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductionFlow extends StatelessWidget {
  const _ProductionFlow({required this.progress, required this.onNavigate});

  final double? progress;
  final ValueChanged<StudioDestination> onNavigate;

  static const _steps = <(StudioDestination, IconData, String)>[
    (StudioDestination.script, Icons.description_rounded, '剧本'),
    (StudioDestination.assets, Icons.face_retouching_natural, '角色'),
    (StudioDestination.shots, Icons.grid_view_rounded, '分镜'),
    (StudioDestination.result, Icons.movie_filter_rounded, '成片'),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final activeIndex = progress == null
        ? -1
        : progress! >= .95
        ? 3
        : progress! >= .45
        ? 2
        : progress! >= .22
        ? 1
        : 0;
    return KeyedSubtree(
      key: const ValueKey('home-production-flow'),
      child: _GlassPanel(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 16,
          vertical: compact ? 10 : 18,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stepWidth = compact ? 58.0 : 96.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final entry in _steps.indexed) ...[
                      SizedBox(
                        width: stepWidth,
                        child: _FlowStep(
                          icon: entry.$2.$2,
                          label: entry.$2.$3,
                          completed: entry.$1 < activeIndex,
                          active: entry.$1 == activeIndex,
                          compact: compact,
                          onTap: () => onNavigate(entry.$2.$1),
                        ),
                      ),
                      if (entry.$1 < _steps.length - 1)
                        _FlowConnector(
                          completed: entry.$1 < activeIndex,
                          compact: compact,
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.label,
    required this.completed,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool completed;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? XingmuTheme.purpleGlow
        : completed
        ? XingmuTheme.cyanGlow
        : Theme.of(context).colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: compact ? 44 : 58,
                  height: compact ? 44 : 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: active ? .2 : .11),
                    border: Border.all(
                      color: color.withValues(alpha: active ? 1 : .48),
                      width: active ? 2 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: .48),
                              blurRadius: 20,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(icon, color: color, size: compact ? 21 : 27),
                ),
                if (completed)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: compact ? 8 : 10,
                      backgroundColor: XingmuTheme.cyanGlow,
                      foregroundColor: Color(0xFF04101B),
                      child: Icon(Icons.check_rounded, size: compact ? 11 : 14),
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              label,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelMedium
                          : Theme.of(context).textTheme.labelLarge)
                      ?.copyWith(
                        color: active ? color : null,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowConnector extends StatelessWidget {
  const _FlowConnector({required this.completed, required this.compact});

  final bool completed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 16 : 26,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: completed
              ? [XingmuTheme.cyanGlow, XingmuTheme.purpleGlow]
              : [
                  Theme.of(context).colorScheme.outline.withValues(alpha: .28),
                  Theme.of(context).colorScheme.outline.withValues(alpha: .12),
                ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [XingmuTheme.cyanGlow, XingmuTheme.purpleGlow],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: const Color(0xFF07101E), size: 19),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _CreationToolGrid extends StatelessWidget {
  const _CreationToolGrid({required this.onNavigate});

  final ValueChanged<StudioDestination> onNavigate;

  static const _tools = <(StudioDestination, IconData, String, String, Color)>[
    (
      StudioDestination.creation,
      Icons.auto_awesome_rounded,
      '主题成剧',
      '从灵感生成结构化漫剧',
      Color(0xFFA45CFF),
    ),
    (
      StudioDestination.assets,
      Icons.face_retouching_natural,
      '角色设定',
      '统一角色、场景与道具',
      Color(0xFF43E1E7),
    ),
    (
      StudioDestination.shots,
      Icons.grid_view_rounded,
      '分镜生成',
      '管理首尾帧与运镜提示',
      Color(0xFFC55CFF),
    ),
    (
      StudioDestination.shots,
      Icons.movie_creation_outlined,
      '视频生成',
      '按镜头提交图生视频任务',
      Color(0xFF4C9FFF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final columns = compact || constraints.maxWidth >= 900 ? 4 : 2;
        final gap = compact ? 8.0 : 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: _tools
              .map(
                (tool) => SizedBox(
                  width: width,
                  child: _CreationToolCard(
                    compact: compact,
                    icon: tool.$2,
                    title: tool.$3,
                    description: tool.$4,
                    color: tool.$5,
                    onTap: () => onNavigate(tool.$1),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _CreationToolCard extends StatelessWidget {
  const _CreationToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('home-tool-$title'),
      child: _GlassPanel(
        onTap: onTap,
        padding: EdgeInsets.all(compact ? 8 : 16),
        child: Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 34 : 48,
              height: compact ? 34 : 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(compact ? 11 : 16),
                border: Border.all(color: color.withValues(alpha: .44)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .24),
                    blurRadius: compact ? 12 : 18,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: compact ? 20 : 26),
            ),
            SizedBox(height: compact ? 6 : 14),
            Text(
              title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelMedium
                          : Theme.of(context).textTheme.titleMedium)
                      ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (!compact) ...[
              const SizedBox(height: 5),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white.withValues(alpha: .07),
                  foregroundColor: color,
                  child: const Icon(Icons.arrow_forward_rounded, size: 17),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentProjectGrid extends StatelessWidget {
  const _RecentProjectGrid({
    required this.projects,
    required this.demoMode,
    required this.onOpen,
  });

  final List<ProjectCardData> projects;
  final bool demoMode;
  final ValueChanged<ProjectCardData> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 2 : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: projects
              .take(4)
              .map(
                (project) => SizedBox(
                  width: width,
                  child: _RecentProjectCard(
                    project: project,
                    showCover: demoMode && project == projects.first,
                    onTap: () => onOpen(project),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _RecentProjectCard extends StatelessWidget {
  const _RecentProjectCard({
    required this.project,
    required this.showCover,
    required this.onTap,
  });

  final ProjectCardData project;
  final bool showCover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final tone = _statusTone(project.status, Theme.of(context).colorScheme);
    return KeyedSubtree(
      key: ValueKey('home-recent-${project.id}'),
      child: _GlassPanel(
        onTap: onTap,
        padding: EdgeInsets.all(compact ? 8 : 11),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
              child: SizedBox(
                width: compact ? 80 : 104,
                height: compact ? 74 : 86,
                child: showCover
                    ? Image.asset(
                        'assets/showcase/moon-courier-hero.png',
                        key: const ValueKey('home-demo-cover-recent'),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _ProjectFallback(color: tone),
                      )
                    : _ProjectFallback(color: tone),
              ),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 8),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          project.stageLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: tone),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: '打开 ${project.title}',
              onPressed: onTap,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectFallback extends StatelessWidget {
  const _ProjectFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .62), const Color(0xFF0A1020)],
        ),
      ),
      child: Icon(
        Icons.auto_awesome_motion_rounded,
        color: Colors.white.withValues(alpha: .78),
      ),
    );
  }
}

class _RemoteHeroPlaceholder extends StatelessWidget {
  const _RemoteHeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      key: ValueKey('home-remote-cover-hero'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF131D35), Color(0xFF08101F)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_motion_rounded,
          size: 96,
          color: Color(0x665CE7E2),
        ),
      ),
    );
  }
}

class _EmptyRecentProjects extends StatelessWidget {
  const _EmptyRecentProjects({required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final message = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('还没有漫剧项目', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(
                '上方「月背最后一单」是视觉概念展示。创建项目后，这里才会显示真实进度。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add_rounded),
            label: const Text('创建第一个项目'),
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [message, const SizedBox(height: 14), button],
            );
          }
          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: dark
          ? const Color(0xB512192B)
          : Colors.white.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: dark
            ? const Color(0x88404C73)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      boxShadow: dark
          ? const [BoxShadow(color: Color(0x220B7CFF), blurRadius: 22)]
          : null,
    );
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

Color _statusTone(GenerationStatus status, ColorScheme scheme) =>
    switch (status) {
      GenerationStatus.completed => XingmuTheme.cyanGlow,
      GenerationStatus.running => const Color(0xFF6D8CFF),
      GenerationStatus.paused => const Color(0xFFFFB45C),
      GenerationStatus.failed => scheme.error,
      GenerationStatus.canceled => scheme.outline,
      GenerationStatus.draft ||
      GenerationStatus.queued => XingmuTheme.purpleGlow,
    };
