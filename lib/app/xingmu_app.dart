import 'package:flutter/material.dart';

import '../application/application.dart';
import '../features/assets/presentation/visual_assets_page.dart';
import '../features/creation/presentation/theme_creation_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/result/presentation/result_page.dart';
import '../features/script/presentation/script_review_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/shots/presentation/shot_workbench_page.dart';
import '../features/tasks/presentation/task_center_page.dart';
import '../features/voice/presentation/voice_studio_page.dart';
import '../presentation/models/studio_view_data.dart';
import '../presentation/adapters/studio_presentation_mapper.dart';
import '../shared/theme/xingmu_theme.dart';
import '../shared/widgets/studio_widgets.dart';

const bool _environmentDemoMode = bool.fromEnvironment(
  'DEMO_MODE',
  defaultValue: true,
);
const String _environmentApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

class XingmuApp extends StatefulWidget {
  const XingmuApp({
    super.key,
    this.demoMode = _environmentDemoMode,
    this.apiBaseUrl = _environmentApiBaseUrl,
    this.controller,
  });

  final bool demoMode;
  final String apiBaseUrl;
  final StudioController? controller;

  @override
  State<XingmuApp> createState() => _XingmuAppState();
}

class _XingmuAppState extends State<XingmuApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  StudioController? _controller;
  Object? _configurationError;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    try {
      if (!widget.demoMode && widget.controller == null) {
        throw const StudioConfigurationException(
          '真实模式尚未接入手机登录与短期令牌，为避免未认证请求，请由登录层注入 StudioController。',
        );
      }
      _controller =
          widget.controller ??
          StudioController(
            repository: StudioBootstrap(
              demoMode: widget.demoMode,
              apiBaseUrl: widget.apiBaseUrl,
            ).createRepository(),
          );
      _controller!.initialize();
    } catch (error) {
      _configurationError = error;
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '星幕 AI 漫剧工作台',
      theme: XingmuTheme.light(),
      darkTheme: XingmuTheme.dark(),
      themeMode: _themeMode,
      home: _controller == null
          ? _ConfigurationFailure(error: _configurationError)
          : XingmuStudioShell(
              controller: _controller!,
              demoMode: widget.demoMode,
              apiBaseUrl: widget.apiBaseUrl,
              themeMode: _themeMode,
              onThemeChanged: (mode) => setState(() => _themeMode = mode),
            ),
    );
  }
}

class XingmuStudioShell extends StatefulWidget {
  const XingmuStudioShell({
    required this.controller,
    required this.demoMode,
    required this.apiBaseUrl,
    required this.themeMode,
    required this.onThemeChanged,
    super.key,
  });

  final StudioController controller;
  final bool demoMode;
  final String apiBaseUrl;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<XingmuStudioShell> createState() => _XingmuStudioShellState();
}

class _XingmuStudioShellState extends State<XingmuStudioShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StudioDestination _destination = StudioDestination.home;

  void _go(StudioDestination destination) {
    setState(() => _destination = destination);
  }

  void _message(
    String message, {
    IconData icon = Icons.check_circle_outline_rounded,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          return Scaffold(
            key: _scaffoldKey,
            appBar: _StudioAppBar(
              compact: compact,
              destination: _destination,
              demoMode: widget.demoMode,
              onOpenNavigation: () => _scaffoldKey.currentState?.openDrawer(),
              onOpenTasks: () => _go(StudioDestination.tasks),
            ),
            drawer: compact
                ? _StudioDrawer(
                    selected: _destination,
                    demoMode: widget.demoMode,
                    onSelected: (destination) {
                      Navigator.of(context).pop();
                      _go(destination);
                    },
                  )
                : null,
            body: Row(
              children: [
                if (!compact)
                  _DesktopNavigation(
                    selected: _destination,
                    demoMode: widget.demoMode,
                    onSelected: _go,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (widget.controller.hasError)
                        _ControllerErrorBanner(
                          message: widget.controller.errorMessage ?? '未知错误',
                          onDismiss: widget.controller.clearError,
                          onRetry: widget.controller.currentProject == null
                              ? widget.controller.initialize
                              : widget.controller.refresh,
                        ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: KeyedSubtree(
                            key: ValueKey(_destination),
                            child: _buildPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: compact
                ? SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: NavigationBar(
                            selectedIndex: _mobileIndex(_destination),
                            onDestinationSelected: (index) =>
                                _go(_mobileDestination(index)),
                            destinations: const [
                              NavigationDestination(
                                icon: Icon(Icons.home_outlined),
                                selectedIcon: Icon(Icons.home_rounded),
                                label: '首页',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.auto_stories_outlined),
                                selectedIcon: Icon(Icons.auto_stories_rounded),
                                label: '创作',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.movie_creation_outlined),
                                selectedIcon: Icon(
                                  Icons.movie_creation_rounded,
                                ),
                                label: '工作台',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.task_alt_outlined),
                                selectedIcon: Icon(Icons.task_alt_rounded),
                                label: '任务',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.person_outline_rounded),
                                selectedIcon: Icon(Icons.person_rounded),
                                label: '我的',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildPage() {
    final controller = widget.controller;
    final project = controller.currentProject;
    final mappedProjects = StudioPresentationMapper.projects(
      controller.projects,
      demoMode: widget.demoMode,
    );
    final mappedShots = StudioPresentationMapper.shots(project);
    final mappedResult = StudioPresentationMapper.result(project);
    return switch (_destination) {
      StudioDestination.home => HomePage(
        projects: mappedProjects,
        demoMode: widget.demoMode,
        state: controller.isLoading
            ? UiLoadState.loading
            : controller.hasError
            ? UiLoadState.error
            : mappedProjects.isEmpty
            ? UiLoadState.empty
            : UiLoadState.ready,
        onRetry: controller.initialize,
        onCreateProject: () => _go(StudioDestination.creation),
        onOpenProject: (card) {
          controller.selectProject(card.id);
          final selected = controller.currentProject;
          final selectedResult = StudioPresentationMapper.result(selected);
          _go(
            selectedResult.ready
                ? StudioDestination.result
                : selected?.currentRun != null
                ? StudioDestination.tasks
                : selected?.script != null
                ? StudioDestination.script
                : StudioDestination.creation,
          );
        },
        onNavigate: _go,
      ),
      StudioDestination.creation => ThemeCreationPage(
        state: controller.isLoading ? UiLoadState.loading : UiLoadState.ready,
        onRetry: controller.initialize,
        initialTitle: widget.demoMode ? '长夜拾灯人' : '',
        initialIdea: widget.demoMode ? StudioDemoData.longStory : '',
        onSaveDraft: _saveDraft,
        onGenerateScript: _generateScript,
      ),
      StudioDestination.script => ScriptReviewPage(
        projectTitle: project?.script?.title ?? project?.title ?? '未生成剧本',
        projectSummary:
            project?.script?.episodeSynopsis ?? project?.theme ?? '请先输入故事主题。',
        projectMeta:
            '${mappedShots.length} 个镜头 · ${project?.script?.styleBible ?? '风格待确认'}',
        beats: StudioPresentationMapper.scriptBeats(project),
        state: controller.isLoading
            ? UiLoadState.loading
            : project?.script == null
            ? UiLoadState.empty
            : UiLoadState.ready,
        onRetry: controller.refresh,
        onEditSummary: () => _showEditDialog(
          title: '编辑故事概要',
          initialValue:
              project?.script?.episodeSynopsis ?? project?.theme ?? '',
        ),
        onEditBeat: (beat) => _showEditDialog(
          title: '编辑「${beat.title}」',
          initialValue: beat.summary,
        ),
        onRegenerate: _adoptScript,
        onConfirm: () async {
          if (project?.script == null) await _adoptScript();
          if (!controller.hasError && controller.isScriptReady) {
            _go(StudioDestination.assets);
          }
        },
        onNavigateStep: _go,
      ),
      StudioDestination.assets => VisualAssetsPage(
        assets: StudioPresentationMapper.visualAssets(project),
        state: controller.isLoading
            ? UiLoadState.loading
            : project?.script == null
            ? UiLoadState.empty
            : UiLoadState.ready,
        onRetry: controller.refresh,
        onRegenerate: (asset) => _message(
          '尚未接入单资产重生成接口，「${asset.name}」本次未提交任务。',
          icon: Icons.info_outline_rounded,
        ),
        onToggleLock: (asset) => _message(
          '首版尚未接入资产锁定变更，「${asset.name}」状态未改变。',
          icon: Icons.info_outline_rounded,
        ),
        onGenerateMissing: (type) => _message(
          '尚未接入精准的${_assetTypeLabel(type)}资产创建接口，本次未提交任何生成任务。',
          icon: Icons.info_outline_rounded,
        ),
        onContinue: () => _go(StudioDestination.shots),
        onNavigateStep: _go,
      ),
      StudioDestination.shots => ShotWorkbenchPage(
        shots: mappedShots,
        demoMode: widget.demoMode,
        state: controller.isLoading ? UiLoadState.loading : UiLoadState.ready,
        onRetry: controller.refresh,
        onGenerate: (shot) => _startGeneration(shotIds: [shot.id]),
        onRegenerate: (shot) =>
            _startGeneration(onlyMissing: false, shotIds: [shot.id]),
        onEditPrompt: (shot) => _showEditDialog(
          title: '编辑镜头 ${shot.sequence} 提示词',
          initialValue: shot.prompt,
        ),
        onPreview: (shot) => _showPreviewDialog(shot.title),
        onContinue: () => _go(StudioDestination.voice),
        onNavigateStep: _go,
      ),
      StudioDestination.voice => VoiceStudioPage(
        cast: StudioPresentationMapper.voiceCast(project),
        lines: StudioPresentationMapper.voiceLines(project),
        state: controller.isLoading
            ? UiLoadState.loading
            : (project?.voiceLines.isEmpty ?? true)
            ? UiLoadState.empty
            : UiLoadState.ready,
        onRetry: controller.refresh,
        onPreviewVoice: (voice) => _message(
          '首版尚未接入音频试听，未播放「${voice.voiceName}」。',
          icon: Icons.info_outline_rounded,
        ),
        onChangeVoice: _showVoicePicker,
        onPlayLine: (line) => _message(
          '首版尚未接入音频播放，未播放 ${line.speaker} 的台词。',
          icon: Icons.info_outline_rounded,
        ),
        onGenerateLine: (line) => _message(
          '尚未接入单句配音生成接口，${line.speaker} 的这句台词本次未提交任务。',
          icon: Icons.info_outline_rounded,
        ),
        onGenerateAll: () => _message(
          '尚未接入精准的全配音生成接口，本次未提交任何生成任务。',
          icon: Icons.info_outline_rounded,
        ),
        onGenerateAllMissing: _startGeneration,
        onContinue: () => _go(StudioDestination.tasks),
        onNavigateStep: _go,
      ),
      StudioDestination.tasks => TaskCenterPage(
        tasks: StudioPresentationMapper.tasks(project),
        state: controller.isLoading
            ? UiLoadState.loading
            : project?.currentRun == null
            ? UiLoadState.empty
            : UiLoadState.ready,
        onRetryPage: controller.refresh,
        onAdvance: widget.demoMode
            ? controller.advanceDemo
            : controller.refresh,
        advanceLabel: widget.demoMode ? '推进一步演示任务' : '刷新服务端状态',
        onPause: (task) => controller.pauseGeneration(),
        onResume: (task) => controller.resumeGeneration(),
        onRetryTask: (task) => controller.retryTask(task.id),
        onCancelTask: _confirmCancelTask,
        onOpenCompleted: (task) {
          final destination = task.resultDestination;
          if (destination == null) {
            _message('服务端尚未返回可查看的结果类型。', icon: Icons.info_outline_rounded);
            return;
          }
          _go(destination);
        },
      ),
      StudioDestination.result => ResultPage(
        result: mappedResult,
        demoMode: widget.demoMode,
        canPreview: false,
        canDownload: false,
        canShare: false,
        canConfigureExportOptions: false,
        state: controller.isLoading
            ? UiLoadState.loading
            : project == null
            ? UiLoadState.empty
            : UiLoadState.ready,
        onRetry: controller.refresh,
        onPlay: () => _showPreviewDialog(mappedResult.title),
        onDownload: (options) =>
            _message('首版尚未接入文件下载，成片未保存到本机。', icon: Icons.info_outline_rounded),
        onShare: () =>
            _message('首版尚未接入系统分享，未发送任何文件。', icon: Icons.info_outline_rounded),
        onRegenerate: () => _go(StudioDestination.shots),
        onBackHome: () => _go(StudioDestination.home),
        onNavigateStep: _go,
      ),
      StudioDestination.settings => SettingsPage(
        data: SettingsViewData(
          demoMode: widget.demoMode,
          apiBaseUrl: widget.apiBaseUrl,
          cacheSizeLabel: '未统计',
        ),
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onTestConnection: () async {
          await controller.initialize();
          if (!controller.hasError) {
            _message('服务端连接正常', icon: Icons.cloud_done_outlined);
          }
        },
        onOpenPrivacy: _showPrivacySheet,
        onOpenLicenses: () => showLicensePage(
          context: context,
          applicationName: '星幕 AI 漫剧工作台',
          applicationVersion: '0.1.0',
          applicationIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: XingmuLogo(size: 64),
          ),
        ),
        onClearCache: _confirmClearCache,
      ),
    };
  }

  Future<void> _saveDraft(CreationDraft draft) async {
    await widget.controller.createProject(draft.idea, title: draft.title);
    if (!widget.controller.hasError) _message('已保存《${draft.title}》项目草稿');
  }

  Future<void> _generateScript(CreationDraft draft) async {
    final current = widget.controller.currentProject;
    if (current == null ||
        current.theme != draft.idea ||
        current.title != draft.title) {
      await widget.controller.createProject(draft.idea, title: draft.title);
    }
    if (widget.controller.hasError) return;
    await widget.controller.adoptScript();
    if (widget.controller.hasError || !mounted) return;
    if (widget.controller.isScriptReady) {
      _message(widget.demoMode ? '已生成演示剧本' : '剧本已由服务端生成');
      _go(StudioDestination.script);
    } else {
      _message('剧本任务已提交，可稍后刷新', icon: Icons.schedule_rounded);
      if (widget.controller.currentProject?.currentRun != null) {
        _go(StudioDestination.tasks);
      }
    }
  }

  Future<void> _adoptScript() async {
    await widget.controller.adoptScript();
    if (widget.controller.hasError || !mounted) return;
    if (widget.controller.isScriptReady) {
      _message('剧本已采用并更新资产清单');
    } else {
      _message('剧本任务已提交，可稍后刷新', icon: Icons.schedule_rounded);
      if (widget.controller.currentProject?.currentRun != null) {
        _go(StudioDestination.tasks);
      }
    }
  }

  Future<void> _startGeneration({
    bool onlyMissing = true,
    List<String>? shotIds,
  }) async {
    await widget.controller.startGeneration(
      onlyMissing: onlyMissing,
      shotIds: shotIds,
    );
    if (!widget.controller.hasError && mounted) {
      _message(shotIds?.isNotEmpty == true ? '已提交选中镜头的生成任务' : '项目全部缺失项已加入生成队列');
      _go(StudioDestination.tasks);
    }
  }

  String _assetTypeLabel(VisualAssetType type) => switch (type) {
    VisualAssetType.character => '角色',
    VisualAssetType.scene => '场景',
    VisualAssetType.prop => '道具',
  };

  int _mobileIndex(StudioDestination destination) => switch (destination) {
    StudioDestination.home => 0,
    StudioDestination.creation ||
    StudioDestination.script ||
    StudioDestination.assets => 1,
    StudioDestination.shots || StudioDestination.voice => 2,
    StudioDestination.tasks || StudioDestination.result => 3,
    StudioDestination.settings => 4,
  };

  StudioDestination _mobileDestination(int index) => switch (index) {
    0 => StudioDestination.home,
    1 => StudioDestination.creation,
    2 => StudioDestination.shots,
    3 => StudioDestination.tasks,
    _ => StudioDestination.settings,
  };

  Future<void> _showEditDialog({
    required String title,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            maxLength: 1200,
            decoration: const InputDecoration(labelText: '内容'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('预览输入'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == true && mounted) {
      _message('首版尚未接入编辑持久化，本次修改未提交服务端。', icon: Icons.info_outline_rounded);
    }
  }

  Future<void> _showPreviewDialog(String title) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.play_disabled_outlined),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: const Text('首版尚未接入真实视频播放器，本次未播放或下载视频。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showVoicePicker(VoiceCastData voice) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '为 ${voice.character} 更换声线',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final name in ['青岚', '玲珑', '小竹'])
                ListTile(
                  leading: Icon(
                    name == voice.voiceName
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                  ),
                  onTap: () => Navigator.of(context).pop(name),
                  title: Text(name),
                  subtitle: Text(
                    name == '青岚'
                        ? '清冷坚定'
                        : name == '玲珑'
                        ? '温柔沉稳'
                        : '少年感、轻快',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      _message(
        '首版尚未接入声线修改，${voice.character} 仍使用原声线。',
        icon: Icons.info_outline_rounded,
      );
    }
  }

  Future<void> _confirmCancelTask(TaskItemData task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('取消当前生成队列？'),
        content: Text('将取消「${task.title}」所在的当前生成队列。已经完成的素材不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续等待'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.controller.cancelGeneration();
    if (!widget.controller.hasError && mounted) {
      _message('生成队列已取消', icon: Icons.cancel_outlined);
    }
  }

  Future<void> _confirmClearCache() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded),
        title: const Text('缓存清理尚未接入'),
        content: const Text('首版尚未接入本地文件清理服务，本次不会删除任何文件。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacySheet() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('隐私与数据边界', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              const Text(
                '当前版本不持久化项目摘要或用户偏好，也尚未接入成片与预览文件下载。模型 API 密钥、Provider Key 和服务端凭据不会下发到手机。项目与任务状态以受信服务端为准。',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigurationFailure extends StatelessWidget {
  const _ConfigurationFailure({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const XingmuLogo(size: 72),
                  const SizedBox(height: 24),
                  Text(
                    '生成服务配置无效',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    error?.toString() ?? '无法创建项目数据源。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '请使用 --dart-define=DEMO_MODE=true 启动演示模式；远程模式需先完成登录，并由登录层注入带短期 Token 的 StudioController。API_BASE_URL 只是连接配置的一部分。',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControllerErrorBanner extends StatelessWidget {
  const _ControllerErrorBanner({
    required this.message,
    required this.onDismiss,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('重试')),
              IconButton(
                tooltip: '关闭错误提示',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StudioAppBar({
    required this.compact,
    required this.destination,
    required this.demoMode,
    required this.onOpenNavigation,
    required this.onOpenTasks,
  });

  final bool compact;
  final StudioDestination destination;
  final bool demoMode;
  final VoidCallback onOpenNavigation;
  final VoidCallback onOpenTasks;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      leadingWidth: compact ? 46 : null,
      leading: compact
          ? IconButton(
              tooltip: '打开全部页面',
              onPressed: onOpenNavigation,
              icon: const XingmuLogo(size: 30),
            )
          : null,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          if (!compact) ...[
            const XingmuLogo(size: 34),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              compact ? '星幕' : '星幕 AI 漫剧工作台 · ${destination.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 1),
          child: _ServiceModePill(demoMode: demoMode, compact: compact),
        ),
        IconButton(
          tooltip: '任务中心',
          onPressed: onOpenTasks,
          icon: Badge(
            isLabelVisible: destination != StudioDestination.tasks,
            smallSize: 7,
            backgroundColor: const Color(0xFFFF5C72),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        const SizedBox(width: 3),
      ],
    );
  }
}

class _ServiceModePill extends StatelessWidget {
  const _ServiceModePill({required this.demoMode, required this.compact});

  final bool demoMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = demoMode
        ? const [Color(0xFF744BFF), Color(0xFF4330B8)]
        : const [Color(0xFF0A9EC0), Color(0xFF126D91)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .42)),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: .35), blurRadius: 12),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 6 : 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              demoMode
                  ? Icons.play_circle_fill_rounded
                  : Icons.cloud_done_rounded,
              size: compact ? 14 : 16,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              compact
                  ? demoMode
                        ? '演示'
                        : '远程'
                  : demoMode
                  ? '演示模式'
                  : '远程服务',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selected,
    required this.demoMode,
    required this.onSelected,
  });

  final StudioDestination selected;
  final bool demoMode;
  final ValueChanged<StudioDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              children:
                  [
                    for (final destination in StudioDestination.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: NavigationDrawerDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                      ),
                  ].indexed.map((entry) {
                    final index = entry.$1;
                    final child = entry.$2;
                    final destination = StudioDestination.values[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => onSelected(destination),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected == destination
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: child,
                      ),
                    );
                  }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: InfoBanner(
              icon: demoMode
                  ? Icons.science_outlined
                  : Icons.cloud_done_outlined,
              title: demoMode ? '演示模式' : '远程服务',
              message: demoMode ? '展示完整交互，不提交生成请求。' : '生成任务由受信后端处理。',
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioDrawer extends StatelessWidget {
  const _StudioDrawer({
    required this.selected,
    required this.demoMode,
    required this.onSelected,
  });

  final StudioDestination selected;
  final bool demoMode;
  final ValueChanged<StudioDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: StudioDestination.values.indexOf(selected),
      onDestinationSelected: (index) =>
          onSelected(StudioDestination.values[index]),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 18, 18),
          child: Row(
            children: [
              const XingmuLogo(size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '星幕工作台',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      demoMode ? '演示模式' : '远程服务',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 20, endIndent: 20),
        const SizedBox(height: 8),
        for (final destination in StudioDestination.values)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
        const SizedBox(height: 18),
      ],
    );
  }
}

extension on StudioDestination {
  String get label => switch (this) {
    StudioDestination.home => '项目首页',
    StudioDestination.creation => '主题创作',
    StudioDestination.script => '剧本确认',
    StudioDestination.assets => '视觉资产',
    StudioDestination.shots => '镜头工作台',
    StudioDestination.voice => '配音工作台',
    StudioDestination.tasks => '任务中心',
    StudioDestination.result => '成片结果',
    StudioDestination.settings => '设置',
  };

  IconData get icon => switch (this) {
    StudioDestination.home => Icons.home_outlined,
    StudioDestination.creation => Icons.lightbulb_outline_rounded,
    StudioDestination.script => Icons.description_outlined,
    StudioDestination.assets => Icons.collections_outlined,
    StudioDestination.shots => Icons.movie_creation_outlined,
    StudioDestination.voice => Icons.graphic_eq_rounded,
    StudioDestination.tasks => Icons.task_alt_outlined,
    StudioDestination.result => Icons.video_file_outlined,
    StudioDestination.settings => Icons.settings_outlined,
  };

  IconData get selectedIcon => switch (this) {
    StudioDestination.home => Icons.home_rounded,
    StudioDestination.creation => Icons.lightbulb_rounded,
    StudioDestination.script => Icons.description_rounded,
    StudioDestination.assets => Icons.collections_rounded,
    StudioDestination.shots => Icons.movie_creation_rounded,
    StudioDestination.voice => Icons.graphic_eq_rounded,
    StudioDestination.tasks => Icons.task_alt_rounded,
    StudioDestination.result => Icons.video_file_rounded,
    StudioDestination.settings => Icons.settings_rounded,
  };
}
