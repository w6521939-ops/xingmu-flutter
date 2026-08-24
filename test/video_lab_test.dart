import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/app/xingmu_app.dart';
import 'package:xingmu_ai_video_studio/features/video_lab/video_lab.dart';

void main() {
  group('VideoLabCatalog', () {
    test('parses four model groups and gates every cloud adapter', () {
      final catalog = VideoLabCatalog.fromJson(_catalogJson());

      expect(catalog.groups, hasLength(4));
      expect(catalog.textModels.first.id, 'local_storyboard_template');
      expect(catalog.imageModels.first.id, 'fixed_moon_courier_assets');
      expect(catalog.videoModels.first.id, 'local_ffmpeg_motion_comic');
      expect(catalog.voiceModels.first.id, 'windows_sapi_huihui');
      expect(
        catalog.groups
            .expand((models) => models)
            .where((model) => model.isPaid),
        everyElement(
          isA<VideoLabModel>().having(
            (model) => model.canGenerate,
            'canGenerate',
            isFalse,
          ),
        ),
      );
    });

    test('uses backend availability as the cloud video gate', () {
      final catalog = VideoLabCatalog.fromJson(
        _catalogJson(cloudVideoAvailable: true),
      );

      expect(catalog.videoModels.last.canGenerate, isTrue);
      expect(catalog.textModels.last.canGenerate, isFalse);
      expect(catalog.imageModels.last.canGenerate, isFalse);
      expect(catalog.voiceModels.last.canGenerate, isFalse);
    });

    test(
      'keeps an available model blocked when its pipeline is unavailable',
      () {
        final catalog = VideoLabCatalog.fromJson(
          _catalogJson(
            cloudVideoAvailable: true,
            includePipelines: true,
            hybridPipelineAvailable: false,
          ),
        );

        expect(catalog.videoModels.last.canGenerate, isTrue);
        expect(
          catalog.comicPipelines
              .firstWhere(
                (pipeline) =>
                    pipeline.executionKind == VideoLabExecutionKind.hybrid,
              )
              .canGenerate,
          isFalse,
        );
      },
    );

    test(
      'rejects missing groups, mismatched capabilities and duplicate IDs',
      () {
        final missing = _catalogJson()..remove('voiceModels');
        final mismatched = _catalogJson();
        (mismatched['imageModels']! as List).first['capability'] = 'video';
        final duplicate = _catalogJson();
        final textModels = duplicate['textModels']! as List;
        textModels.add(Map<String, Object?>.from(textModels.first as Map));

        for (final invalid in [missing, mismatched, duplicate]) {
          expect(
            () => VideoLabCatalog.fromJson(invalid),
            throwsA(isA<FormatException>()),
          );
        }
      },
    );

    test('rejects non-official billing links', () {
      for (final billingUrl in [
        'http://help.aliyun.com/pay',
        'https://example.com/pay',
      ]) {
        final json = _catalogJson();
        final paid = Map<String, Object?>.from(
          (json['voiceModels']! as List).last as Map,
        )..['billingUrl'] = billingUrl;
        (json['voiceModels']! as List).last = paid;

        expect(
          () => VideoLabCatalog.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });

  group('VideoLabJob', () {
    test('strictly parses three shots and four same-origin outputs', () {
      final job = VideoLabJob.fromJson(
        _jobJson(succeeded: true),
        Uri.parse('http://localhost/v1/'),
      );

      expect(job.executionKind, VideoLabExecutionKind.template);
      expect(job.generatedForRequest, isFalse);
      expect(job.containsAiGeneratedAssets, isTrue);
      expect(job.assetProvenance, 'openai_imagegen_project_assets');
      expect(job.visualSource, 'fixed_project_assets');
      expect(job.output?.generatedForRequest, isFalse);
      expect(job.output?.containsAiGeneratedAssets, isTrue);
      expect(job.output?.visualSource, 'fixed_project_assets');
      expect(job.shots, hasLength(3));
      expect(job.manifestUrl.toString(), 'http://localhost/manifest.json');
      expect(job.scriptUrl.toString(), 'http://localhost/script.json');
    });

    test('parses truthful hybrid shot videos and concat output', () {
      final job = VideoLabJob.fromJson(
        _hybridJobJson(),
        Uri.parse('http://localhost/v1/'),
      );

      expect(job.executionKind, VideoLabExecutionKind.hybrid);
      expect(job.modelExecution?.text, VideoLabExecutionSource.local);
      expect(job.modelExecution?.image, VideoLabExecutionSource.preGenerated);
      expect(job.modelExecution?.video, VideoLabExecutionSource.cloud);
      expect(job.modelExecution?.voice, VideoLabExecutionSource.local);
      expect(job.shots, everyElement(isA<VideoLabShot>()));
      expect(
        job.shots,
        everyElement(predicate<VideoLabShot>((s) => s.hasFramePair)),
      );
      expect(
        job.shots.map((shot) => shot.videoTask?.videoUrl?.path),
        everyElement(endsWith('.mp4')),
      );
      expect(job.output?.compositionType, 'shot_videos_concat');
      expect(job.output?.sourceClipCount, 3);
      expect(job.output?.isShotVideoComposition, isTrue);
    });

    test('rejects unsafe or incomplete hybrid shot-video evidence', () {
      final unsafeFrame = _hybridJobJson();
      (unsafeFrame['shots']! as List).first['firstFrameUrl'] =
          'https://evil.example/first.png';
      final unsafeVideo = _hybridJobJson();
      (((unsafeVideo['shots']! as List).first as Map)['videoTask']
              as Map)['videoUrl'] =
          'https://evil.example/shot.mp4';
      final noLastFrame = _hybridJobJson();
      ((noLastFrame['shots']! as List).first as Map).remove('lastFrameUrl');
      final fakeConcat = _hybridJobJson();
      (fakeConcat['output']! as Map)['compositionType'] =
          'template_pan_zoom_concat';
      final missingOutputExecution = _hybridJobJson();
      (missingOutputExecution['output']! as Map).remove('modelExecution');

      for (final invalid in [
        unsafeFrame,
        unsafeVideo,
        noLastFrame,
        fakeConcat,
        missingOutputExecution,
      ]) {
        expect(
          () =>
              VideoLabJob.fromJson(invalid, Uri.parse('http://localhost/v1/')),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects incomplete output, cross-origin URLs and invalid shots', () {
      final incomplete = _jobJson(succeeded: true);
      (incomplete['output']! as Map<String, Object?>).remove('scriptUrl');
      final crossOrigin = _jobJson(succeeded: true);
      (crossOrigin['output']! as Map<String, Object?>)['manifestUrl'] =
          'https://evil.example/manifest.json';
      final twoShots = _jobJson();
      (twoShots['shots']! as List).removeLast();
      final invalidStage = _jobJson();
      invalidStage['stageCode'] = '../export';

      for (final invalid in [incomplete, crossOrigin, twoShots, invalidStage]) {
        expect(
          () =>
              VideoLabJob.fromJson(invalid, Uri.parse('http://localhost/v1/')),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects contradictory authenticity fields', () {
      final templateGeneratedForRequest = _jobJson()
        ..['generatedForRequest'] = true;
      final templateWithoutAiAssets = _jobJson()
        ..['containsAiGeneratedAssets'] = false;
      final templateWithWrongProvenance = _jobJson()
        ..['assetProvenance'] = 'unknown_assets';
      final templateWithWrongVisualSource = _jobJson()
        ..['visualSource'] = 'story_generated_assets';
      final cloudNotGeneratedForRequest = _jobJson()
        ..['executionKind'] = 'cloud_ai'
        ..['generatedForRequest'] = false;
      final generatedWithoutAiAssets = _jobJson()
        ..['executionKind'] = 'cloud_ai'
        ..['generatedForRequest'] = true
        ..['containsAiGeneratedAssets'] = false
        ..['assetProvenance'] = 'model_generated_for_request';
      final outputProvenanceMismatch = _jobJson(succeeded: true);
      (outputProvenanceMismatch['output']!
              as Map<String, Object?>)['assetProvenance'] =
          'model_generated_for_request';
      final outputVisualSourceMismatch = _jobJson(succeeded: true);
      (outputVisualSourceMismatch['output']!
              as Map<String, Object?>)['visualSource'] =
          'story_generated_assets';

      for (final invalid in [
        templateGeneratedForRequest,
        templateWithoutAiAssets,
        templateWithWrongProvenance,
        templateWithWrongVisualSource,
        cloudNotGeneratedForRequest,
        generatedWithoutAiAssets,
        outputProvenanceMismatch,
        outputVisualSourceMismatch,
      ]) {
        expect(
          () =>
              VideoLabJob.fromJson(invalid, Uri.parse('http://localhost/v1/')),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('requires authenticity fields on jobs and successful outputs', () {
      for (final field in [
        'generatedForRequest',
        'containsAiGeneratedAssets',
        'assetProvenance',
        'visualSource',
      ]) {
        final missingFromJob = _jobJson()..remove(field);
        final missingFromOutput = _jobJson(succeeded: true);
        (missingFromOutput['output']! as Map<String, Object?>).remove(field);

        expect(
          () => VideoLabJob.fromJson(
            missingFromJob,
            Uri.parse('http://localhost/v1/'),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => VideoLabJob.fromJson(
            missingFromOutput,
            Uri.parse('http://localhost/v1/'),
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });

  test(
    'controller requires four available models and polls comic job',
    () async {
      final repository = _FakeVideoLabRepository();
      final controller = VideoLabController(
        repository: repository,
        pollInterval: const Duration(days: 1),
      );
      await controller.initialize();

      controller.selectImageModel('wan2.7-image-pro');
      expect(controller.selectedImageModelId, 'fixed_moon_courier_assets');
      expect(controller.canGenerate, isTrue);
      expect(repository.createCalls, 0);

      await controller.generate(List.filled(501, '字').join());
      expect(controller.state, VideoLabLoadState.failed);
      expect(repository.createCalls, 0);

      await controller.generate('霓虹雨夜的月球快递员');
      expect(controller.state, VideoLabLoadState.polling);
      expect(repository.lastTextModelId, 'local_storyboard_template');
      expect(repository.lastImageModelId, 'fixed_moon_courier_assets');
      expect(repository.lastVideoModelId, 'local_ffmpeg_motion_comic');
      expect(repository.lastVoiceModelId, 'windows_sapi_huihui');

      await controller.refreshJob();
      expect(controller.state, VideoLabLoadState.succeeded);
      expect(controller.job?.shots, hasLength(3));
      expect(controller.job?.generatedForRequest, isFalse);
      expect(controller.job?.containsAiGeneratedAssets, isTrue);
      controller.dispose();
    },
  );

  test('catalog load failure keeps generation disabled', () async {
    final repository = _FakeVideoLabRepository(failCatalog: true);
    final controller = VideoLabController(repository: repository);
    addTearDown(controller.dispose);

    expect(controller.hasLoadedCatalog, isFalse);
    await controller.initialize();

    expect(controller.state, VideoLabLoadState.failed);
    expect(controller.hasLoadedCatalog, isFalse);
    expect(controller.canGenerate, isFalse);
    expect(controller.errorMessage, '模型目录加载失败');

    await controller.generate('月背基地的最后一封信');
    expect(controller.errorMessage, contains('模型目录尚未成功加载'));
    expect(repository.createCalls, 0);
  });

  test(
    'controller rejects available legacy models outside comic pipeline',
    () async {
      final catalogJson = _catalogJson();
      (catalogJson['textModels']! as List).insert(0, {
        'id': 'manual',
        'capability': 'text',
        'provider': 'legacy local',
        'displayName': '旧字幕卡文本',
        'description': '仅用于旧视频接口',
        'pricingType': 'free',
        'availability': 'available',
        'requiresCredential': false,
      });
      final repository = _FakeVideoLabRepository(catalogJson: catalogJson);
      final controller = VideoLabController(
        repository: repository,
        fallbackCatalog: VideoLabCatalog.fromJson(catalogJson),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.selectTextModel('manual');
      expect(controller.canGenerate, isFalse);
      await controller.generate('月背基地的最后一封信');

      expect(controller.state, VideoLabLoadState.failed);
      expect(controller.errorMessage, contains('不能组成'));
      expect(repository.createCalls, 0);
    },
  );

  test(
    'controller runs hybrid shot video only when backend marks Wan available',
    () async {
      final catalogJson = _catalogJson(
        cloudVideoAvailable: true,
        includePipelines: true,
        hybridPipelineAvailable: true,
      );
      final repository = _FakeVideoLabRepository(
        catalogJson: catalogJson,
        jobJson: _hybridJobJson(),
      );
      final controller = VideoLabController(
        repository: repository,
        fallbackCatalog: VideoLabCatalog.fromJson(catalogJson),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      controller.selectImageModel('wan2.7-image-pro');
      expect(controller.selectedImageModelId, 'fixed_moon_courier_assets');

      controller.selectVideoModel('wan2.7-i2v-2026-04-25');
      expect(controller.usesHybridShotVideoPipeline, isTrue);
      expect(controller.canGenerate, isTrue);

      await controller.generate('月球快递员穿过风暴完成最后一单');

      expect(repository.createCalls, 1);
      expect(repository.lastVideoModelId, 'wan2.7-i2v-2026-04-25');
      expect(controller.state, VideoLabLoadState.succeeded);
      expect(controller.job?.output?.isShotVideoComposition, isTrue);
    },
  );

  test('controller refuses a hybrid pipeline marked unavailable', () async {
    final catalogJson = _catalogJson(
      cloudVideoAvailable: true,
      includePipelines: true,
      hybridPipelineAvailable: false,
    );
    final repository = _FakeVideoLabRepository(catalogJson: catalogJson);
    final controller = VideoLabController(
      repository: repository,
      fallbackCatalog: VideoLabCatalog.fromJson(catalogJson),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    controller.selectVideoModel('wan2.7-i2v-2026-04-25');
    expect(controller.selectedVideoModel.canGenerate, isTrue);
    expect(controller.selectedPipeline?.canGenerate, isFalse);
    expect(controller.canGenerate, isFalse);

    await controller.generate('月球快递员穿过风暴完成最后一单');

    expect(controller.errorMessage, contains('流水线的后端尚未就绪'));
    expect(repository.createCalls, 0);
  });

  testWidgets(
    'motion comic page works at 320px with four pickers and truthful result',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _FakeVideoLabRepository(succeedImmediately: true);
      final controller = VideoLabController(repository: repository);
      Uri? copiedOfficialUrl;
      await controller.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: VideoLabPage(
              controller: controller,
              baseUrlLabel: 'http://127.0.0.1:8787/v1',
              onCopyOfficialUrl: (uri, label) async {
                copiedOfficialUrl = uri;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('3 分镜视频漫剧'), findsOneWidget);
      for (final key in [
        'model-picker-text-local_storyboard_template',
        'model-picker-image-fixed_moon_courier_assets',
        'model-picker-video-local_ffmpeg_motion_comic',
        'model-picker-voice-windows_sapi_huihui',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(find.text('固定图片运镜模板，不是分镜图生视频'), findsOneWidget);
      expect(find.textContaining('角色 → 道具 → 场景'), findsOneWidget);

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      final cloudText = find.byKey(
        const ValueKey('model-option-text-qwen3.6-plus'),
      );
      await tester.ensureVisible(cloudText);
      await tester.tap(cloudText);
      await tester.pump();
      expect(controller.selectedTextModelId, 'local_storyboard_template');
      expect(controller.canGenerate, isTrue);
      final billing = find.byKey(const ValueKey('billing-qwen3.6-plus'));
      await tester.ensureVisible(billing);
      await tester.tap(billing);
      await tester.pump();
      expect(
        copiedOfficialUrl.toString(),
        contains('help.aliyun.com/zh/user-center'),
      );
      final localText = find.byKey(
        const ValueKey('model-option-text-local_storyboard_template'),
      );
      await tester.ensureVisible(localText);
      await tester.tap(localText);
      await tester.pump();
      expect(controller.selectedTextModelId, 'local_storyboard_template');
      expect(controller.canGenerate, isTrue);

      final generate = find.byKey(const ValueKey('video-lab-generate'));
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pump();

      expect(repository.createCalls, 1);
      expect(find.byKey(const ValueKey('execution-kind')), findsOneWidget);
      expect(find.text('本地模板 · 固定项目素材 · story未重绘'), findsOneWidget);
      expect(find.text('本次任务未调用AI · 使用预生成的项目固定ImageGen素材'), findsWidgets);
      expect(find.textContaining('未按story重绘'), findsWidgets);
      expect(
        find.textContaining('openai_imagegen_project_assets'),
        findsWidgets,
      );
      expect(find.textContaining('fixed_project_assets'), findsWidgets);
      expect(find.textContaining('非AI生成'), findsNothing);
      expect(find.textContaining('非 AI 生成'), findsNothing);
      for (var index = 1; index <= 3; index++) {
        expect(
          find.byKey(ValueKey('shot-progress-shot-$index')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('copy-video-url')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hybrid result shows frame pairs remote MP4 progress and concat at 320px',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final catalogJson = _catalogJson(cloudVideoAvailable: true);
      final controller = VideoLabController(
        repository: _FakeVideoLabRepository(
          catalogJson: catalogJson,
          jobJson: _hybridJobJson(),
        ),
        fallbackCatalog: VideoLabCatalog.fromJson(catalogJson),
      );
      Uri? openedVideo;
      await controller.initialize();
      controller.selectVideoModel('wan2.7-i2v-2026-04-25');
      await controller.generate('月球快递员穿过风暴完成最后一单');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: VideoLabPage(
              controller: controller,
              baseUrlLabel: 'http://127.0.0.1:8787/v1',
              onOpenMediaUrl: (uri) async => openedVideo = uri,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('仅分镜视频在本次任务中由云模型生成'), findsOneWidget);
      expect(find.text('视频 · 本次云端生成'), findsOneWidget);
      expect(find.text('画面 · 预生成固定素材'), findsOneWidget);
      expect(find.text('3 个分镜视频'), findsOneWidget);
      for (var index = 1; index <= 3; index++) {
        expect(
          find.byKey(ValueKey('shot-first-frame-shot-$index')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('shot-last-frame-shot-$index')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('shot-video-task-shot-$index')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('copy-shot-video-shot-$index')),
          findsOneWidget,
        );
      }
      expect(find.text('分镜视频合片 MP4'), findsOneWidget);
      expect(find.text('播放 MP4'), findsNWidgets(4));
      expect(find.byKey(const ValueKey('video-lab-preview')), findsNothing);
      final openFirstShot = find.byKey(
        const ValueKey('open-shot-video-shot-1'),
      );
      await tester.ensureVisible(openFirstShot);
      await tester.tap(openFirstShot);
      await tester.pump();
      expect(openedVideo?.path, '/jobs/hybrid-job-1/shot-1.mp4');
      final openFinal = find.byKey(const ValueKey('open-video-url'));
      await tester.ensureVisible(openFinal);
      await tester.tap(openFinal);
      await tester.pump();
      expect(openedVideo?.path, '/final.mp4');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed remote shot video exposes the provider-safe error', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalogJson = _catalogJson(cloudVideoAvailable: true);
    final controller = VideoLabController(
      repository: _FakeVideoLabRepository(
        catalogJson: catalogJson,
        jobJson: _hybridJobJson(failedShot: 2),
      ),
      fallbackCatalog: VideoLabCatalog.fromJson(catalogJson),
    );
    await controller.initialize();
    controller.selectVideoModel('wan2.7-i2v-2026-04-25');
    await controller.generate('月球快递员穿过风暴完成最后一单');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoLabPage(
            controller: controller,
            baseUrlLabel: 'http://127.0.0.1:8787/v1',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('video-lab-error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shot-video-error-shot-2')),
      findsOneWidget,
    );
    expect(find.text('供应商拒绝了第 2 个分镜'), findsOneWidget);
    expect(find.byKey(const ValueKey('final-mp4-result')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('model choices stay inline and do not push a route', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = VideoLabController(
      repository: _FakeVideoLabRepository(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoLabPage(
            controller: controller,
            baseUrlLabel: 'http://127.0.0.1:8787/v1',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    final pageContext = tester.element(find.byType(VideoLabPage));
    expect(Navigator.of(pageContext).canPop(), isFalse);

    final cloudImage = find.byKey(
      const ValueKey('model-option-image-wan2.7-image-pro'),
    );
    await tester.ensureVisible(cloudImage);
    await tester.tap(cloudImage);
    await tester.pump();

    expect(controller.selectedImageModelId, 'fixed_moon_courier_assets');
    expect(Navigator.of(pageContext).canPop(), isFalse);

    final localImage = find.byKey(
      const ValueKey('model-option-image-fixed_moon_courier_assets'),
    );
    await tester.ensureVisible(localImage);
    await tester.tap(localImage);
    await tester.pump();

    expect(controller.selectedImageModelId, 'fixed_moon_courier_assets');
    expect(Navigator.of(pageContext).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home video tool opens the motion comic page', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = VideoLabController(
      repository: _FakeVideoLabRepository(succeedImmediately: true),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(XingmuApp(videoLabController: controller));
    await tester.pumpAndSettle();
    final entry = find.text('视频生成');
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('3 分镜视频漫剧'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app opens shot and final MP4 routes without autoplay', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalogJson = _catalogJson(cloudVideoAvailable: true);
    final controller = VideoLabController(
      repository: _FakeVideoLabRepository(
        catalogJson: catalogJson,
        jobJson: _hybridJobJson(),
      ),
      fallbackCatalog: VideoLabCatalog.fromJson(catalogJson),
    );
    await controller.initialize();
    controller.selectVideoModel('wan2.7-i2v-2026-04-25');
    await controller.generate('月球快递员穿过风暴完成最后一单');
    addTearDown(controller.dispose);
    final openedUris = <Uri>[];
    final players = <_RouteMp4PlaybackController>[];

    await tester.pumpWidget(
      XingmuApp(
        videoLabController: controller,
        mp4PlaybackControllerFactory: (uri) {
          openedUris.add(uri);
          final player = _RouteMp4PlaybackController();
          players.add(player);
          return player;
        },
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.text('视频生成');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    final openShot = find.byKey(const ValueKey('open-shot-video-shot-1'));
    await tester.ensureVisible(openShot);
    await tester.tap(openShot);
    await tester.pumpAndSettle();
    expect(find.byType(Mp4PlayerPage), findsOneWidget);
    expect(openedUris.single.path, '/jobs/hybrid-job-1/shot-1.mp4');
    expect(players.single.initializeCalls, 1);
    expect(players.single.playCalls, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(players.first.disposeCalls, 1);

    final openFinal = find.byKey(const ValueKey('open-video-url'));
    await tester.ensureVisible(openFinal);
    await tester.tap(openFinal);
    await tester.pumpAndSettle();
    expect(find.byType(Mp4PlayerPage), findsOneWidget);
    expect(openedUris.last.path, '/final.mp4');
    expect(players.last.initializeCalls, 1);
    expect(players.last.playCalls, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(players.last.disposeCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cold-start menu closes before switching destinations', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const XingmuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开全部页面'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-navigation-panel')),
      findsOneWidget,
    );
    await tester.tap(find.text('主题创作').last);
    await tester.pumpAndSettle();

    expect(find.text('从一个好故事开始'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-navigation-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Map<String, Object?> _catalogJson({
  bool cloudVideoAvailable = false,
  bool includePipelines = false,
  bool hybridPipelineAvailable = false,
}) => {
  'textModels': _modelPair(
    capability: 'text',
    localId: 'local_storyboard_template',
    localName: '本地模板脚本',
    cloudId: 'qwen3.6-plus',
    cloudName: '通义千问',
  ),
  'imageModels': _modelPair(
    capability: 'image',
    localId: 'fixed_moon_courier_assets',
    localName: '固定月球快递素材',
    cloudId: 'wan2.7-image-pro',
    cloudName: '通义万相图片',
  ),
  'videoModels': _modelPair(
    capability: 'video',
    localId: 'local_ffmpeg_motion_comic',
    localName: '本地漫剧合成',
    cloudId: 'wan2.7-i2v-2026-04-25',
    cloudName: '通义万相视频',
    cloudAvailability: cloudVideoAvailable
        ? 'available'
        : 'requires_configuration',
  ),
  'voiceModels': _modelPair(
    capability: 'voice',
    localId: 'windows_sapi_huihui',
    localName: 'Windows 慧慧',
    cloudId: 'cosyvoice-v3.5-plus',
    cloudName: 'CosyVoice',
  ),
  if (includePipelines)
    'comicPipelines': [
      {
        'id': 'local_moon_courier_comic',
        'displayName': '月背最后一单·本地三镜头漫剧',
        'availability': 'available',
        'executionKind': 'template',
        'textModelId': 'local_storyboard_template',
        'imageModelId': 'fixed_moon_courier_assets',
        'videoModelId': 'local_ffmpeg_motion_comic',
        'voiceModelId': 'windows_sapi_huihui',
      },
      {
        'id': 'wan_fixed_frames_motion_comic',
        'displayName': '固定分镜首尾帧 · Wan 视频漫剧',
        'availability': hybridPipelineAvailable
            ? 'available'
            : 'requires_configuration',
        'executionKind': 'hybrid',
        'textModelId': 'local_storyboard_template',
        'imageModelId': 'fixed_moon_courier_assets',
        'videoModelId': 'wan2.7-i2v-2026-04-25',
        'voiceModelId': 'windows_sapi_huihui',
        'modelExecution': {
          'text': 'local',
          'image': 'pre_generated',
          'video': 'cloud',
          'voice': 'local',
        },
      },
    ],
};

List<Map<String, Object?>> _modelPair({
  required String capability,
  required String localId,
  required String localName,
  required String cloudId,
  required String cloudName,
  String cloudAvailability = 'requires_configuration',
}) => [
  {
    'id': localId,
    'capability': capability,
    'provider': 'local',
    'displayName': localName,
    'description': '免费本地模板模式',
    'pricingType': 'free',
    'availability': 'available',
    'requiresCredential': false,
  },
  {
    'id': cloudId,
    'capability': capability,
    'provider': 'Alibaba Cloud Model Studio',
    'displayName': cloudName,
    'description': '付费云模型，后端适配器待接入',
    'pricingType': 'paid',
    'availability': cloudAvailability,
    'requiresCredential': true,
    'pricingUrl': 'https://help.aliyun.com/zh/model-studio/model-pricing',
    'billingUrl':
        'https://help.aliyun.com/zh/user-center/use-alipay-online-banking-to-recharge-online',
  },
];

Map<String, Object?> _jobJson({bool succeeded = false}) => {
  'id': 'job-1',
  'status': succeeded ? 'succeeded' : 'queued',
  'progress': succeeded ? 100 : 0,
  'executionKind': 'template',
  'generatedForRequest': false,
  'containsAiGeneratedAssets': true,
  'assetProvenance': 'openai_imagegen_project_assets',
  'visualSource': 'fixed_project_assets',
  'stageCode': succeeded ? 'completed' : 'queued',
  'templateStoryTitle': '月背最后一单',
  'visualWarning': '画面不会按任意主题重绘。',
  'error': null,
  'shots': [
    for (var index = 1; index <= 3; index++)
      {
        'id': 'shot-$index',
        'title': '镜头 $index',
        'status': succeeded ? 'succeeded' : 'queued',
        'progress': succeeded ? 100 : 0,
        'stageCode': succeeded ? 'completed' : 'queued',
      },
  ],
  'output': succeeded
      ? {
          'previewUrl': 'http://localhost/preview.gif',
          'videoUrl': 'http://localhost/video.mp4',
          'manifestUrl': 'http://localhost/manifest.json',
          'scriptUrl': 'http://localhost/script.json',
          'generatedForRequest': false,
          'containsAiGeneratedAssets': true,
          'assetProvenance': 'openai_imagegen_project_assets',
          'visualSource': 'fixed_project_assets',
        }
      : null,
};

Map<String, Object?> _hybridJobJson({int? failedShot}) {
  const modelExecution = {
    'text': 'local',
    'image': 'pre_generated',
    'video': 'cloud',
    'voice': 'local',
  };
  final succeeded = failedShot == null;
  return {
    'id': 'hybrid-job-1',
    'status': succeeded ? 'succeeded' : 'failed',
    'progress': succeeded ? 100 : 58,
    'executionKind': 'hybrid',
    'generatedForRequest': true,
    'containsAiGeneratedAssets': true,
    'assetProvenance': 'fixed_project_assets+alibaba_wan_video',
    'visualSource': 'fixed_project_assets',
    'modelExecution': modelExecution,
    'stageCode': succeeded ? 'completed' : 'failed',
    'templateStoryTitle': '月背最后一单',
    'visualWarning': '视频动态按本次任务生成；脚本、首尾帧与配音不是云生成。',
    'error': succeeded ? null : '第 $failedShot 个分镜视频生成失败',
    'shots': [
      for (var index = 1; index <= 3; index++)
        {
          'id': 'shot-$index',
          'title': '镜头 $index',
          'status': succeeded
              ? 'succeeded'
              : index == failedShot
              ? 'failed'
              : index < failedShot
              ? 'succeeded'
              : 'queued',
          'progress': succeeded
              ? 100
              : index == failedShot
              ? 64
              : index < failedShot
              ? 100
              : 0,
          'stageCode': succeeded
              ? 'completed'
              : index == failedShot
              ? 'failed'
              : index < failedShot
              ? 'completed'
              : 'queued',
          'firstFrameUrl': '/jobs/hybrid-job-1/shot-$index-first.png',
          'lastFrameUrl': '/jobs/hybrid-job-1/shot-$index-last.png',
          'motionPrompt': '人物向前一步，镜头缓慢推进',
          'videoTask': {
            'remoteTaskId': 'wan-task-$index',
            'status': succeeded
                ? 'succeeded'
                : index == failedShot
                ? 'failed'
                : index < failedShot
                ? 'succeeded'
                : 'queued',
            'progress': succeeded
                ? 100
                : index == failedShot
                ? 64
                : index < failedShot
                ? 100
                : 0,
            'videoUrl': succeeded || index < failedShot
                ? '/jobs/hybrid-job-1/shot-$index.mp4'
                : null,
            'error': index == failedShot ? '供应商拒绝了第 $index 个分镜' : null,
          },
        },
    ],
    'output': succeeded
        ? {
            'previewUrl': '/preview.gif',
            'videoUrl': '/final.mp4',
            'manifestUrl': '/manifest.json',
            'scriptUrl': '/script.json',
            'generatedForRequest': true,
            'containsAiGeneratedAssets': true,
            'assetProvenance': 'fixed_project_assets+alibaba_wan_video',
            'visualSource': 'fixed_project_assets',
            'compositionType': 'shot_videos_concat',
            'sourceClipCount': 3,
            'modelExecution': modelExecution,
          }
        : null,
  };
}

class _FakeVideoLabRepository implements VideoLabRepository {
  _FakeVideoLabRepository({
    this.succeedImmediately = false,
    this.failCatalog = false,
    this.catalogJson,
    this.jobJson,
  });

  final bool succeedImmediately;
  final bool failCatalog;
  final Map<String, Object?>? catalogJson;
  final Map<String, Object?>? jobJson;
  int createCalls = 0;
  String? lastTextModelId;
  String? lastImageModelId;
  String? lastVideoModelId;
  String? lastVoiceModelId;

  @override
  Future<VideoLabCatalog> fetchCatalog() async {
    if (failCatalog) {
      throw const VideoLabApiException('模型目录加载失败');
    }
    return VideoLabCatalog.fromJson(catalogJson ?? _catalogJson());
  }

  @override
  Future<VideoLabJob> createJob({
    required String story,
    required String textModelId,
    required String imageModelId,
    required String videoModelId,
    required String voiceModelId,
  }) async {
    createCalls++;
    lastTextModelId = textModelId;
    lastImageModelId = imageModelId;
    lastVideoModelId = videoModelId;
    lastVoiceModelId = voiceModelId;
    return VideoLabJob.fromJson(
      jobJson ?? _jobJson(succeeded: succeedImmediately),
      Uri.parse('http://localhost/v1/'),
    );
  }

  @override
  Future<VideoLabJob> fetchJob(String id) async => VideoLabJob.fromJson(
    jobJson ?? _jobJson(succeeded: true),
    Uri.parse('http://localhost/v1/'),
  );

  @override
  void close() {}
}

class _RouteMp4PlaybackController implements Mp4PlaybackController {
  final List<VoidCallback> _listeners = [];
  int initializeCalls = 0;
  int playCalls = 0;
  int disposeCalls = 0;
  Mp4PlaybackValue _value = const Mp4PlaybackValue(
    isInitialized: false,
    isPlaying: false,
    hasError: false,
    duration: Duration.zero,
    position: Duration.zero,
    aspectRatio: 16 / 9,
  );

  @override
  Mp4PlaybackValue get value => _value;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> initialize() async {
    initializeCalls++;
    _value = const Mp4PlaybackValue(
      isInitialized: true,
      isPlaying: false,
      hasError: false,
      duration: Duration(seconds: 8),
      position: Duration.zero,
      aspectRatio: 16 / 9,
    );
    _notify();
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Widget buildVideo() => const ColoredBox(color: Colors.black);

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}
