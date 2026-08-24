import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/app/app.dart';
import 'package:xingmu_ai_video_studio/application/studio_controller.dart';
import 'package:xingmu_ai_video_studio/data/demo/demo_studio_repository.dart';
import 'package:xingmu_ai_video_studio/domain/domain.dart';
import 'package:xingmu_ai_video_studio/features/assets/presentation/visual_assets_page.dart';
import 'package:xingmu_ai_video_studio/features/creation/presentation/theme_creation_page.dart';
import 'package:xingmu_ai_video_studio/features/home/presentation/home_page.dart';
import 'package:xingmu_ai_video_studio/features/result/presentation/result_page.dart';
import 'package:xingmu_ai_video_studio/features/script/presentation/script_review_page.dart';
import 'package:xingmu_ai_video_studio/features/settings/presentation/settings_page.dart';
import 'package:xingmu_ai_video_studio/features/shots/presentation/shot_workbench_page.dart';
import 'package:xingmu_ai_video_studio/features/tasks/presentation/task_center_page.dart';
import 'package:xingmu_ai_video_studio/features/voice/presentation/voice_studio_page.dart';
import 'package:xingmu_ai_video_studio/presentation/adapters/studio_presentation_mapper.dart';
import 'package:xingmu_ai_video_studio/presentation/models/studio_view_data.dart';
import 'package:xingmu_ai_video_studio/shared/theme/xingmu_theme.dart';
import 'package:xingmu_ai_video_studio/shared/widgets/studio_widgets.dart';

void main() {
  testWidgets('小屏可从空项目首页进入主题创作', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const XingmuApp(demoMode: true));
    await tester.pumpAndSettle();

    expect(find.text('还没有漫剧项目'), findsOneWidget);
    expect(find.text('月背最后一单'), findsOneWidget);
    expect(find.text('AI 创作工具'), findsOneWidget);
    expect(find.text('主题成剧'), findsOneWidget);
    expect(find.text('视频生成'), findsOneWidget);
    expect(find.text('开始创作'), findsOneWidget);
    expect(find.text('演示'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('月背最后一单'))).brightness,
      Brightness.dark,
    );

    await tester.ensureVisible(find.text('开始创作'));
    await tester.tap(find.text('开始创作'));
    await tester.pumpAndSettle();

    expect(find.text('从一个好故事开始'), findsOneWidget);
    expect(find.text('生成漫剧剧本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页工具网格可从首帧极窄宽度恢复到手机宽度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: XingmuTheme.light(),
        darkTheme: XingmuTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: HomePage(
            projects: const [],
            demoMode: true,
            onCreateProject: () {},
            onOpenProject: (_) {},
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-tool-主题成剧')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tool-视频生成')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主题创作页不承诺未接入的草稿保存或编辑持久化', (tester) async {
    await _pumpPage(
      tester,
      ThemeCreationPage(
        initialTitle: '远程漫剧项目',
        initialIdea: '一名信使在风暴中寻找最后的收件人，并逐步发现自己遗失的身份。',
        onSaveDraft: (_) {},
        onGenerateScript: (_) {},
      ),
    );

    expect(find.text('保存草稿（未接入）'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('保存草稿（未接入）'),
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('信息已足够。本版生成后可审核；编辑持久化与镜头数量调整待接入。'), findsOneWidget);
    expect(find.textContaining('生成后仍可以修改'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主题页未入契约的类型风格画幅时长只读展示', (tester) async {
    await _pumpPage(
      tester,
      ThemeCreationPage(
        initialTitle: '远程漫剧项目',
        initialIdea: '一名信使在风暴中寻找最后的收件人，并逐步发现自己遗失的身份。',
        onSaveDraft: (_) {},
        onGenerateScript: (_) {},
      ),
    );

    expect(find.text('故事类型（规划预览）'), findsOneWidget);
    expect(find.text('视觉风格（规划预览）'), findsOneWidget);
    expect(find.text('成片规格（规划预览）'), findsOneWidget);
    expect(find.text('规格选择尚未提交'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '科幻'))
          .onSelected,
      isNull,
    );
    expect(
      tester
          .widget<SegmentedButton<String>>(
            find.byWidgetPredicate(
              (widget) => widget is SegmentedButton<String>,
            ),
          )
          .onSelectionChanged,
      isNull,
    );
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(find.textContaining('首发版支持'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('剧本确认只继续查看而不伪装生成或锁定', (tester) async {
    await _pumpPage(
      tester,
      ScriptReviewPage(
        projectTitle: '远程漫剧项目',
        projectSummary: '服务端返回的剧本概要',
        projectMeta: '1 个节拍',
        beats: const [
          ScriptBeatData(
            number: 1,
            title: '风暴开场',
            durationLabel: '5 秒',
            summary: '信使进入风暴区域。',
            shotCount: 1,
          ),
        ],
        onEditSummary: () {},
        onEditBeat: (_) {},
        onRegenerate: () {},
        onConfirm: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.textContaining('确认操作只会继续查看视觉资产'), findsOneWidget);
    expect(find.text('后续流程（待接入）'), findsOneWidget);
    expect(find.text('继续查看'), findsOneWidget);
    expect(find.text('确认并查看视觉资产'), findsOneWidget);
    expect(find.textContaining('确认并生成视觉资产'), findsNothing);
    expect(find.textContaining('锁定剧本后将生成'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程空项目只展示明确概念示例且没有伪进度', (tester) async {
    await _pumpPage(
      tester,
      HomePage(
        projects: const [],
        demoMode: false,
        onCreateProject: () {},
        onOpenProject: (_) {},
        onNavigate: (_) {},
      ),
    );

    expect(find.text('项目封面位置示意'), findsOneWidget);
    expect(find.textContaining('服务端尚未返回项目封面'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-demo-cover-hero')), findsNothing);
    expect(find.text('项目尚未创建，不展示占位生成进度。'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程项目没有生成 run 时不展示启发式百分比', (tester) async {
    await _pumpPage(
      tester,
      HomePage(
        projects: const [
          ProjectCardData(
            id: 'project-no-run',
            title: '刚创建的远程项目',
            summary: '服务端尚未建立生成任务',
            stageLabel: '等待生成剧本',
            updatedLabel: '刚刚',
            status: GenerationStatus.queued,
          ),
        ],
        onCreateProject: () {},
        onOpenProject: (_) {},
        onNavigate: (_) {},
      ),
    );

    expect(find.text('服务端尚未返回生成进度。'), findsOneWidget);
    expect(find.textContaining('服务端未返回封面'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-demo-cover-hero')), findsNothing);
    expect(find.byKey(const ValueKey('home-demo-cover-recent')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-remote-cover-hero')),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程 run 未返回聚合进度时首页只展示服务端阶段', (tester) async {
    final now = DateTime.utc(2026, 8, 20, 10);
    final mapped = StudioPresentationMapper.project(
      StudioProject(
        id: 'project-run-without-progress',
        title: '远程生成项目',
        theme: '服务端有任务但未返回聚合进度',
        createdAt: now,
        updatedAt: now,
        currentRun: GenerationRun(
          id: 'run-without-progress',
          projectId: 'project-run-without-progress',
          status: StudioStatus.running,
          onlyMissing: true,
          tasks: const [
            GenerationTask(
              id: 'task-completed',
              type: GenerationTaskType.script,
              sequence: 0,
              label: '剧本已完成',
              targetId: 'project-run-without-progress',
              inputHash: 'hash-completed',
              status: StudioStatus.succeeded,
              progressPercent: 100,
            ),
            GenerationTask(
              id: 'task-running',
              type: GenerationTaskType.shotVideo,
              sequence: 1,
              label: '服务端当前阶段',
              targetId: 'shot-running',
              inputHash: 'hash-running',
              status: StudioStatus.running,
              progressPercent: 25,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );

    expect(mapped.progress, isNull);
    await _pumpPage(
      tester,
      HomePage(
        projects: [mapped],
        onCreateProject: () {},
        onOpenProject: (_) {},
        onNavigate: (_) {},
      ),
    );

    expect(find.text('服务端当前阶段'), findsWidgets);
    expect(find.text('服务端尚未返回生成进度。'), findsOneWidget);
    expect(find.textContaining('50%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程 91% 进度不推断剧本角色或分镜已完成', (tester) async {
    await _pumpPage(
      tester,
      HomePage(
        projects: const [
          ProjectCardData(
            id: 'remote-high-progress',
            title: '远程高进度项目',
            summary: '服务端只返回聚合进度',
            stageLabel: '服务端生成中',
            updatedLabel: '刚刚',
            progress: .91,
            progressLabel: '服务端生成进度',
            status: GenerationStatus.running,
          ),
        ],
        demoMode: false,
        onCreateProject: () {},
        onOpenProject: (_) {},
        onNavigate: (_) {},
      ),
    );

    final flow = find.byKey(const ValueKey('home-production-flow'));
    expect(flow, findsOneWidget);
    expect(
      find.descendant(of: flow, matching: find.byIcon(Icons.check_rounded)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('演示任务聚合进度明确标注来源并随推进增长', (tester) async {
    final controller = StudioController(
      repository: DemoStudioRepository(seedDemoProject: true),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.adoptScript();
    await controller.startGeneration();

    final beforeRun = controller.currentRun!;
    final before = StudioPresentationMapper.project(
      controller.currentProject!,
      demoMode: true,
    );
    expect(beforeRun.remoteProgressPercent, 0);
    expect(before.progressLabel, '演示任务终态比例');

    await controller.advanceDemo();
    final after = StudioPresentationMapper.project(
      controller.currentProject!,
      demoMode: true,
    );

    expect(after.progress, greaterThan(before.progress!));
    expect(after.progressLabel, '演示任务终态比例');
    await _pumpPage(
      tester,
      HomePage(
        projects: [after],
        demoMode: true,
        onCreateProject: () {},
        onOpenProject: (_) {},
        onNavigate: (_) {},
      ),
    );

    expect(find.text('演示任务终态比例'), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('390x844 与 1.4 倍字号下长中文项目首页无溢出', (tester) async {
    await _pumpPage(
      tester,
      HomePage(
        projects: const [
          ProjectCardData(
            id: 'long-project',
            title: '月背最后一单：一名失忆信使穿越废弃月球城市寻找最后的收件人',
            summary: '科幻悬疑漫剧 · 这是用于验证小屏长中文换行与布局边界的真实项目摘要',
            stageLabel: '正在生成第十二个电影感分镜视频',
            updatedLabel: '刚刚',
            progress: .72,
            status: GenerationStatus.running,
          ),
        ],
        onCreateProject: () {},
        onOpenProject: (_) {},
        onNavigate: (_) {},
      ),
      size: const Size(390, 844),
    );

    expect(find.textContaining('月背最后一单'), findsWidgets);
    expect(find.text('72%'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('home-tool-主题成剧'))).width,
      lessThan(90),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('390x844 演示首页首屏比例紧凑且最近项目不被底栏遮挡', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = StudioController(
      repository: DemoStudioRepository(seedDemoProject: true),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.adoptScript();
    await controller.startGeneration();
    while (true) {
      final run = controller.currentRun;
      if (run == null || run.status.isTerminal || run.progress >= .68) break;
      await controller.advanceDemo();
    }

    await tester.pumpWidget(XingmuApp(demoMode: true, controller: controller));
    await tester.pumpAndSettle();

    final heroSize = tester.getSize(
      find.byKey(const ValueKey('home-featured-hero')),
    );
    final flowSize = tester.getSize(
      find.byKey(const ValueKey('home-production-flow')),
    );
    final recentCard = find.byKey(
      ValueKey('home-recent-${controller.currentProject!.id}'),
    );
    final navigationBar = find.byType(NavigationBar);

    expect(heroSize.height, inInclusiveRange(280, 300));
    expect(flowSize.height, inInclusiveRange(80, 105));
    expect(find.text('最近项目'), findsOneWidget);
    expect(recentCard, findsOneWidget);
    expect(
      tester.getRect(recentCard).bottom,
      lessThanOrEqualTo(tester.getRect(navigationBar).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏首页保留封面、流程、工具与最近项目', (tester) async {
    await _pumpPage(
      tester,
      HomePage(
        projects: StudioDemoData.projects,
        demoMode: true,
        onCreateProject: () {},
        onOpenProject: (_) {},
        onNavigate: (_) {},
      ),
      size: const Size(1200, 800),
      textScale: 1,
    );

    expect(find.text('长夜拾灯人'), findsWidgets);
    expect(find.text('剧本'), findsWidgets);
    expect(find.text('AI 创作工具'), findsOneWidget);
    expect(find.text('最近项目'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('状态面板明确展示加载和错误操作', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatePanel(
            state: UiLoadState.error,
            onRetry: () => retried = true,
            errorMessage: '测试服务暂时不可用，请稍后再试。',
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text('加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });

  testWidgets('远程模式缺少认证 Controller 时提示完整登录前置条件', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const XingmuApp(
        demoMode: false,
        apiBaseUrl: 'https://studio.example.com',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('生成服务配置无效'), findsOneWidget);
    expect(
      find.textContaining('登录层注入带短期 Token 的 StudioController'),
      findsOneWidget,
    );
    expect(find.textContaining('API_BASE_URL 只是连接配置的一部分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320x700 与 1.4 倍字号下任务页无溢出并正确展示取消', (tester) async {
    await _pumpPage(
      tester,
      TaskCenterPage(
        tasks: const [
          TaskItemData(
            id: 'task-canceled',
            title: '镜头 04 · 城门下的名字',
            detail: '用户已取消该任务，未产生可查看的结果。',
            stageLabel: '图生视频',
            status: GenerationStatus.canceled,
            progress: 0,
            updatedLabel: '刚刚',
          ),
        ],
        onPause: (_) {},
        onResume: (_) {},
        onRetryTask: (_) {},
        onCancelTask: (_) {},
        onOpenCompleted: (_) {},
      ),
    );

    expect(find.text('已取消'), findsOneWidget);
    expect(find.text('查看结果'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程镜头空态等待剧本镜头或服务端返回', (tester) async {
    await _pumpPage(
      tester,
      ShotWorkbenchPage(
        shots: const [],
        onGenerate: (_) {},
        onRegenerate: (_) {},
        onEditPrompt: (_) {},
        onPreview: (_) {},
        onContinue: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('等待剧本镜头或服务端返回'), findsOneWidget);
    expect(find.text('当前项目没有可展示的镜头；请先确认剧本，或稍后刷新服务端状态。'), findsOneWidget);
    expect(find.textContaining('先锁定'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final status in [GenerationStatus.queued, GenerationStatus.running]) {
    testWidgets('远程 ${status.name} 镜头不把首尾帧位置示意标成已锁定', (tester) async {
      await _pumpPage(
        tester,
        ShotWorkbenchPage(
          shots: [
            ShotData(
              id: 'shot-${status.name}',
              sequence: 1,
              title: '远程镜头',
              durationLabel: '4.0 秒',
              prompt: '服务端返回的镜头提示词',
              camera: '服务端未返回运镜参数',
              referenceLabels: const [],
              status: status,
              progress: status == GenerationStatus.running ? .37 : 0,
            ),
          ],
          onGenerate: (_) {},
          onRegenerate: (_) {},
          onEditPrompt: (_) {},
          onPreview: (_) {},
          onContinue: () {},
          onNavigateStep: (_) {},
        ),
      );

      expect(find.text('首帧位置示意 · 服务端未返回帧元数据'), findsOneWidget);
      expect(find.text('尾帧位置示意 · 服务端未返回帧元数据'), findsOneWidget);
      expect(find.text('元数据未返回'), findsNWidgets(2));
      expect(find.textContaining('已锁定'), findsNothing);
      expect(find.textContaining('演示占位'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('演示镜头首尾帧明确标为演示占位', (tester) async {
    await _pumpPage(
      tester,
      ShotWorkbenchPage(
        demoMode: true,
        shots: const [
          ShotData(
            id: 'shot-demo-frame',
            sequence: 1,
            title: '演示镜头',
            durationLabel: '4.0 秒',
            prompt: '本地演示提示词',
            camera: '演示运镜说明',
            referenceLabels: [],
            status: GenerationStatus.queued,
            progress: 0,
          ),
        ],
        onGenerate: (_) {},
        onRegenerate: (_) {},
        onEditPrompt: (_) {},
        onPreview: (_) {},
        onContinue: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('首尾帧演示占位'), findsOneWidget);
    expect(find.text('演示占位'), findsNWidgets(2));
    expect(find.textContaining('已锁定'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320x700 与 1.4 倍字号下结果页明示演示占位', (tester) async {
    await _pumpPage(
      tester,
      ResultPage(
        result: StudioDemoData.result,
        demoMode: true,
        onPlay: () {},
        onDownload: (_) {},
        onShare: () {},
        onRegenerate: () {},
        onBackHome: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('演示占位成片'), findsOneWidget);
    expect(find.text('演示占位不可下载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程成片就绪但客户端能力未接入时所有相关操作禁用', (tester) async {
    await _pumpPage(
      tester,
      ResultPage(
        result: const ResultData(
          title: '服务端成片记录',
          summary: '服务端已完成合成，但客户端能力仍需单独接入。',
          durationLabel: '服务端未返回',
          resolutionLabel: '服务端未返回',
          sizeLabel: '服务端未返回',
          generatedAtLabel: '8 月 20 日 18:00',
          ready: true,
        ),
        onPlay: () {},
        onDownload: (_) {},
        onShare: () {},
        onRegenerate: () {},
        onBackHome: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('服务端已就绪'), findsOneWidget);
    expect(find.text('文件下载尚未接入'), findsOneWidget);
    expect(find.text('系统分享尚未接入'), findsOneWidget);
    expect(find.text('字幕导出选项（未接入）'), findsOneWidget);
    expect(find.text('水印导出选项（未接入）'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('视频播放器尚未接入'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '文件下载尚未接入'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程项目没有 export 时不虚构合成阶段或百分比', (tester) async {
    final now = DateTime.utc(2026, 8, 20, 10);
    final mapped = StudioPresentationMapper.result(
      StudioProject(
        id: 'project-no-export',
        title: '尚无成片的项目',
        theme: '服务端尚未返回 export',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _pumpPage(
      tester,
      ResultPage(
        result: mapped,
        onPlay: () {},
        onDownload: (_) {},
        onShare: () {},
        onRegenerate: () {},
        onBackHome: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('尚无可用成片'), findsOneWidget);
    expect(find.text('未返回成片'), findsOneWidget);
    expect(find.text('服务端尚未返回可用成片'), findsOneWidget);
    expect(find.textContaining('本页不会推测合成阶段'), findsOneWidget);
    expect(find.textContaining('正在混合配音与字幕'), findsNothing);
    expect(find.textContaining('76%'), findsNothing);
    expect(find.textContaining('合成中'), findsNothing);
    expect(mapped.generatedAtLabel, '服务端未返回');
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程失败 export 未就绪时同样不推测当前合成进度', (tester) async {
    final now = DateTime.utc(2026, 8, 20, 10);
    final mapped = StudioPresentationMapper.result(
      StudioProject(
        id: 'project-failed-export',
        title: '失败成片记录',
        theme: '服务端 export 失败',
        createdAt: now,
        updatedAt: now,
        latestExportId: 'export-failed',
        exports: [
          StudioExport(
            id: 'export-failed',
            runId: 'run-failed',
            status: StudioStatus.failed,
            createdAt: now,
          ),
        ],
      ),
    );
    await _pumpPage(
      tester,
      ResultPage(
        result: mapped,
        onPlay: () {},
        onDownload: (_) {},
        onShare: () {},
        onRegenerate: () {},
        onBackHome: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(mapped.ready, isFalse);
    expect(find.text('服务端尚未返回可用成片'), findsOneWidget);
    expect(find.textContaining('正在混合配音与字幕'), findsNothing);
    expect(find.textContaining('76%'), findsNothing);
    expect(find.textContaining('合成中'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('视觉资产生成中只显示状态而不显示伪百分比', (tester) async {
    await _pumpPage(
      tester,
      VisualAssetsPage(
        assets: const [
          VisualAssetData(
            id: 'character-running',
            type: VisualAssetType.character,
            name: '林小满',
            description: '服务端正在生成角色参考图',
            status: GenerationStatus.running,
            colorValue: 0xFF315CA8,
          ),
        ],
        onRegenerate: (_) {},
        onToggleLock: (_) {},
        onGenerateMissing: (_) {},
        onContinue: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('生成参考图中 · 服务端未返回精确进度'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空角色与场景资产使用类型匹配的远程中性文案', (tester) async {
    VisualAssetType? requestedType;
    await _pumpPage(
      tester,
      VisualAssetsPage(
        assets: const [],
        onRegenerate: (_) {},
        onToggleLock: (_) {},
        onGenerateMissing: (type) => requestedType = type,
        onContinue: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('服务端尚未返回角色卡'), findsOneWidget);
    expect(find.text('请求生成角色卡'), findsOneWidget);
    expect(find.textContaining('青铜灯'), findsNothing);

    await tester.ensureVisible(find.text('场景'));
    await tester.tap(find.text('场景'));
    await tester.pumpAndSettle();

    expect(find.text('服务端尚未返回场景卡'), findsOneWidget);
    expect(find.text('请求生成场景卡'), findsOneWidget);
    expect(find.textContaining('青铜灯'), findsNothing);
    await tester.ensureVisible(find.text('请求生成场景卡'));
    await tester.tap(find.text('请求生成场景卡'));
    await tester.pump();
    expect(requestedType, VisualAssetType.scene);
    expect(tester.takeException(), isNull);
  });

  testWidgets('参考图 URL 不冒充资产锁定状态', (tester) async {
    final now = DateTime.utc(2026, 8, 20, 10);
    final assets = StudioPresentationMapper.visualAssets(
      StudioProject(
        id: 'project-asset-lock-unknown',
        title: '锁定状态验证',
        theme: '图片已返回但服务端没有锁定字段',
        createdAt: now,
        updatedAt: now,
        characters: const [
          CharacterAsset(
            id: 'character-with-image',
            name: '林小满',
            description: '短发、蓝色工作服',
            visualLock: '保持发型与服装颜色一致',
            imageUrl: 'https://studio.example.com/character.png',
            status: StudioStatus.succeeded,
          ),
        ],
      ),
    );

    expect(assets.single.locked, isNull);
    expect(assets.single.description, contains('视觉一致性要求：'));
    expect(assets.single.description, isNot(contains('一致性锁定')));

    await _pumpPage(
      tester,
      VisualAssetsPage(
        assets: assets,
        onRegenerate: (_) {},
        onToggleLock: (_) {},
        onGenerateMissing: (_) {},
        onContinue: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('1 个参考的锁定状态未知'), findsOneWidget);
    expect(find.text('锁定状态未知'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.help_outline_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('配音生成中只显示状态而不显示伪百分比', (tester) async {
    await _pumpPage(
      tester,
      VoiceStudioPage(
        cast: const [],
        lines: const [
          VoiceLineData(
            id: 'line-running',
            speaker: '林小满',
            content: '请等我把最后一单送完。',
            durationLabel: '音频未返回',
            status: GenerationStatus.running,
          ),
        ],
        onPreviewVoice: (_) {},
        onChangeVoice: (_) {},
        onPlayLine: (_) {},
        onGenerateLine: (_) {},
        onGenerateAll: () {},
        onGenerateAllMissing: () {},
        onContinue: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.text('配音生成中 · 服务端未返回精确进度'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程配音页只展示服务端声线名与音频可用状态', (tester) async {
    await _pumpPage(
      tester,
      VoiceStudioPage(
        cast: const [
          VoiceCastData(
            id: 'voice-remote',
            character: '林小满',
            voiceName: '服务端声线 A',
            description: '角色关联状态未返回 · 语速参数未返回',
            sampleText: '请等我把最后一单送完。',
            colorValue: 0xFF315CA8,
          ),
        ],
        lines: const [
          VoiceLineData(
            id: 'line-audio-ready',
            speaker: '林小满',
            content: '请等我把最后一单送完。',
            durationLabel: '音频已返回',
            status: GenerationStatus.completed,
          ),
        ],
        onPreviewVoice: (_) {},
        onChangeVoice: (_) {},
        onPlayLine: (_) {},
        onGenerateLine: (_) {},
        onGenerateAll: () {},
        onGenerateAllMissing: () {},
        onContinue: () {},
        onNavigateStep: (_) {},
      ),
    );

    expect(find.textContaining('语速、情绪、停顿与逐句时长仍在规划中'), findsOneWidget);
    expect(find.textContaining('仅展示服务端明确返回的声线名与音频可用状态'), findsOneWidget);
    expect(find.text('音频已返回'), findsOneWidget);
    expect(find.text('批量生成尚未接入'), findsOneWidget);
    expect(find.text('更换声线尚未接入'), findsOneWidget);
    expect(find.text('字幕时间轴尚未接入'), findsOneWidget);
    expect(find.textContaining('字幕将使用同一份真实时间轴'), findsNothing);
    expect(find.textContaining('写入真实时长'), findsNothing);
    expect(find.textContaining('字幕将自动对齐'), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('批量生成尚未接入'),
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('更换声线尚未接入'),
              matching: find.byWidgetPredicate(
                (widget) => widget is OutlinedButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320x700 与 1.4 倍字号下设置页无溢出且不声称已持久化', (tester) async {
    await _pumpPage(
      tester,
      SettingsPage(
        data: const SettingsViewData(
          demoMode: true,
          apiBaseUrl: '',
          cacheSizeLabel: '未统计',
        ),
        themeMode: ThemeMode.system,
        onThemeChanged: (_) {},
        onTestConnection: () {},
        onOpenPrivacy: () {},
        onOpenLicenses: () {},
        onClearCache: () {},
      ),
    );

    expect(find.text('选项尚未持久化'), findsOneWidget);
    expect(find.textContaining('关闭应用后不会保留'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远程设置页不猜测具体 Provider 配置', (tester) async {
    await _pumpPage(
      tester,
      SettingsPage(
        data: const SettingsViewData(
          demoMode: false,
          apiBaseUrl: 'https://studio.example.com',
          cacheSizeLabel: '未统计',
        ),
        themeMode: ThemeMode.dark,
        onThemeChanged: (_) {},
        onTestConnection: () {},
        onOpenPrivacy: () {},
        onOpenLicenses: () {},
        onClearCache: () {},
      ),
    );

    expect(find.text('服务端自动编排；客户端未读取具体 Provider 配置'), findsOneWidget);
    expect(find.textContaining('状态未知：客户端未读取服务端 Provider 配置'), findsOneWidget);
    expect(find.text('百炼云生成'), findsNothing);
    expect(find.text('Wan2.2 自托管'), findsNothing);
    expect(find.text('开源组件许可'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('succeeded 生成 run 映射为已完成而不是已建立队列', () {
    final now = DateTime.utc(2026, 8, 20, 10);
    final project = StudioProject(
      id: 'project-succeeded',
      title: '已完成项目',
      theme: '测试成功终态映射',
      createdAt: now,
      updatedAt: now,
      currentRun: GenerationRun(
        id: 'run-succeeded',
        projectId: 'project-succeeded',
        status: StudioStatus.succeeded,
        onlyMissing: true,
        tasks: const [],
        remoteProgressPercent: 100,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final mapped = StudioPresentationMapper.project(project);

    expect(mapped.stageLabel, '生成任务已完成');
    expect(mapped.status, GenerationStatus.completed);
    expect(mapped.progress, 1);
  });

  test('项目卡优先使用服务端聚合进度而不是终态任务占比', () {
    final now = DateTime.utc(2026, 8, 20, 10);
    final run = GenerationRun(
      id: 'run-authoritative-progress',
      projectId: 'project-authoritative-progress',
      status: StudioStatus.running,
      onlyMissing: true,
      tasks: const [
        GenerationTask(
          id: 'task-terminal',
          type: GenerationTaskType.script,
          sequence: 0,
          label: '剧本',
          targetId: 'project-authoritative-progress',
          inputHash: 'hash-terminal',
          status: StudioStatus.succeeded,
          progressPercent: 100,
        ),
        GenerationTask(
          id: 'task-active',
          type: GenerationTaskType.shotVideo,
          sequence: 1,
          label: '镜头',
          targetId: 'shot-active',
          inputHash: 'hash-active',
          status: StudioStatus.running,
          progressPercent: 91,
        ),
      ],
      remoteProgressPercent: 7,
      createdAt: now,
      updatedAt: now,
    );
    final mapped = StudioPresentationMapper.project(
      StudioProject(
        id: 'project-authoritative-progress',
        title: '聚合进度验证',
        theme: '以 API 聚合进度为准',
        createdAt: now,
        updatedAt: now,
        currentRun: run,
      ),
    );

    expect(run.progress, .5);
    expect(mapped.progress, closeTo(.07, .0001));
  });

  test('历史 ready export 不覆盖当前 running run', () {
    final now = DateTime.utc(2026, 8, 20, 10);
    final project = StudioProject(
      id: 'project-new-run',
      title: '新一轮生成',
      theme: '旧成片不应覆盖新进度',
      createdAt: now,
      updatedAt: now,
      latestExportId: 'export-old',
      exports: [
        StudioExport(
          id: 'export-old',
          runId: 'run-old',
          status: StudioStatus.succeeded,
          createdAt: now.subtract(const Duration(days: 1)),
          ready: true,
          videoUrl: 'https://studio.example.com/old.mp4',
        ),
      ],
      currentRun: GenerationRun(
        id: 'run-new',
        projectId: 'project-new-run',
        status: StudioStatus.running,
        onlyMissing: true,
        tasks: const [],
        remoteProgressPercent: 7,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final card = StudioPresentationMapper.project(project);
    final result = StudioPresentationMapper.result(project);

    expect(card.progress, closeTo(.07, .0001));
    expect(card.status, GenerationStatus.running);
    expect(card.stageLabel, isNot('成片已完成'));
    expect(result.ready, isFalse);
  });

  test('latestExportId 与当前失败 run 优先于旧 ready export', () {
    final now = DateTime.utc(2026, 8, 20, 10);
    final project = StudioProject(
      id: 'project-failed-export',
      title: '最新导出失败',
      theme: '按服务端 latestExportId 选择',
      createdAt: now,
      updatedAt: now,
      latestExportId: 'export-failed',
      exports: [
        StudioExport(
          id: 'export-old-ready',
          runId: 'run-old',
          status: StudioStatus.succeeded,
          createdAt: now.subtract(const Duration(days: 1)),
          ready: true,
        ),
        StudioExport(
          id: 'export-failed',
          runId: 'run-new',
          status: StudioStatus.failed,
          createdAt: now,
          ready: false,
          progressPercent: 91,
        ),
      ],
      currentRun: GenerationRun(
        id: 'run-new',
        projectId: 'project-failed-export',
        status: StudioStatus.failed,
        onlyMissing: true,
        tasks: const [],
        remoteProgressPercent: 91,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final card = StudioPresentationMapper.project(project);
    final result = StudioPresentationMapper.result(project);

    expect(card.status, GenerationStatus.failed);
    expect(card.stageLabel, '生成任务需处理');
    expect(result.ready, isFalse);
  });

  testWidgets('完成 job-123 按任务类型路由且空 hash 不伪装输入快照', (tester) async {
    final now = DateTime.utc(2026, 8, 20, 10);
    final tasks = StudioPresentationMapper.tasks(
      StudioProject(
        id: 'project-opaque-job',
        title: '不透明任务 ID',
        theme: '路由不依赖 ID 字符串',
        createdAt: now,
        updatedAt: now,
        currentRun: GenerationRun(
          id: 'run-opaque-job',
          projectId: 'project-opaque-job',
          status: StudioStatus.succeeded,
          onlyMissing: true,
          tasks: const [
            GenerationTask(
              id: 'job-123',
              type: GenerationTaskType.episodeExport,
              sequence: 0,
              label: '成片导出',
              targetId: 'project-opaque-job',
              inputHash: '',
              status: StudioStatus.succeeded,
              progressPercent: 100,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    var opened = false;

    expect(tasks.single.resultDestination, StudioDestination.result);
    expect(tasks.single.detail, isNot(contains('输入快照')));
    await _pumpPage(
      tester,
      TaskCenterPage(
        tasks: tasks,
        onPause: (_) {},
        onResume: (_) {},
        onRetryTask: (_) {},
        onCancelTask: (_) {},
        onOpenCompleted: (_) => opened = true,
      ),
    );

    expect(find.textContaining('失败任务保留原因和输入快照'), findsNothing);
    await tester.tap(find.text('查看结果'));
    await tester.pump();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('镜头与配音映射不虚构运镜关联语速或音画对齐信息', () {
    final now = DateTime.utc(2026, 8, 20, 10);
    final project = StudioProject(
      id: 'project-neutral-metadata',
      title: '中性元数据验证',
      theme: '只展示服务端可证明字段',
      createdAt: now,
      updatedAt: now,
      shots: const [
        Shot(
          id: 'shot-neutral',
          order: 1,
          title: '未返回运镜的镜头',
          prompt: '角色走入房间',
          durationSeconds: 4,
        ),
      ],
      voiceLines: const [
        VoiceLine(
          id: 'voice-neutral',
          shotId: 'shot-neutral',
          speaker: '旁白',
          text: '门缓缓打开。',
          voiceName: '服务端声线 A',
          audioUrl: 'https://studio.example.com/voice.mp3',
          status: StudioStatus.succeeded,
        ),
      ],
    );

    final shot = StudioPresentationMapper.shots(project).single;
    final cast = StudioPresentationMapper.voiceCast(project).single;
    final line = StudioPresentationMapper.voiceLines(project).single;

    expect(shot.camera, '服务端未返回运镜参数');
    expect(shot.camera, isNot(contains('电影感')));
    expect(cast.description, '角色关联状态未返回 · 语速参数未返回');
    expect(cast.description, isNot(contains('已与角色卡关联')));
    expect(cast.description, isNot(contains('1.0x')));
    expect(line.durationLabel, '音频已返回');
    expect(line.durationLabel, isNot(contains('已对齐')));
  });

  test('任务与镜头进度直接映射服务端返回的 7% 和 91%', () {
    final now = DateTime.utc(2026, 8, 20, 10);
    final project = StudioProject(
      id: 'project-progress',
      title: '服务端进度',
      theme: '验证精确进度映射',
      createdAt: now,
      updatedAt: now,
      shots: const [
        Shot(
          id: 'shot-7',
          order: 1,
          title: '镜头一',
          prompt: '测试镜头一',
          durationSeconds: 5,
          status: StudioStatus.running,
        ),
        Shot(
          id: 'shot-91',
          order: 2,
          title: '镜头二',
          prompt: '测试镜头二',
          durationSeconds: 5,
          status: StudioStatus.failed,
        ),
      ],
      currentRun: GenerationRun(
        id: 'run-progress',
        projectId: 'project-progress',
        status: StudioStatus.running,
        onlyMissing: true,
        tasks: const [
          GenerationTask(
            id: 'task-running-7',
            type: GenerationTaskType.shotVideo,
            sequence: 0,
            label: '镜头一',
            targetId: 'shot-7',
            inputHash: 'hash-7',
            status: StudioStatus.running,
            progressPercent: 7,
          ),
          GenerationTask(
            id: 'task-failed-91',
            type: GenerationTaskType.shotVideo,
            sequence: 1,
            label: '镜头二',
            targetId: 'shot-91',
            inputHash: 'hash-91',
            status: StudioStatus.failed,
            progressPercent: 91,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final mappedTasks = StudioPresentationMapper.tasks(project);
    final mappedShots = StudioPresentationMapper.shots(project);

    expect(mappedTasks[0].progress, closeTo(.07, .0001));
    expect(mappedTasks[1].progress, closeTo(.91, .0001));
    expect(mappedShots[0].progress, closeTo(.07, .0001));
    expect(mappedShots[1].progress, closeTo(.91, .0001));
  });

  test('没有 generation run 的项目卡不映射启发式进度', () {
    final now = DateTime.utc(2026, 8, 20, 10);
    final mapped = StudioPresentationMapper.project(
      StudioProject(
        id: 'project-without-run',
        title: '尚未生成',
        theme: '验证空进度',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(mapped.progress, isNull);
  });

  test('成片映射不把未返回的时长分辨率和大小伪装成服务端元数据', () {
    final now = DateTime.utc(2026, 8, 20, 10);
    final mapped = StudioPresentationMapper.result(
      StudioProject(
        id: 'project-export',
        title: '远程成片',
        theme: '验证服务端元数据边界',
        createdAt: now,
        updatedAt: now,
        latestExportId: 'export-ready',
        exports: [
          StudioExport(
            id: 'export-ready',
            runId: 'run-ready',
            status: StudioStatus.succeeded,
            createdAt: now,
            ready: true,
            downloadUrl: 'https://studio.example.com/download/export-ready',
          ),
        ],
      ),
    );

    expect(mapped.ready, isTrue);
    expect(mapped.durationLabel, '服务端未返回');
    expect(mapped.resolutionLabel, '服务端未返回');
    expect(mapped.sizeLabel, '服务端未返回');
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(320, 700),
  double textScale = 1.4,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: XingmuTheme.dark(),
      darkTheme: XingmuTheme.dark(),
      themeMode: ThemeMode.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
