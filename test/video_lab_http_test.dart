import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/features/video_lab/video_lab.dart';

void main() {
  test(
    'HTTP repository uses comic-jobs and sends the four model IDs',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Map<String, Object?>? captured;
      int? capturedContentLength;
      final requestedPaths = <String>[];
      final serving = server.forEach((request) async {
        requestedPaths.add(request.uri.path);
        if (request.uri.path == '/v1/model-catalog') {
          await _jsonResponse(request.response, 200, _catalogJson());
          return;
        }
        if (request.uri.path == '/v1/comic-jobs' && request.method == 'POST') {
          capturedContentLength = request.headers.contentLength;
          final requestBody = await utf8.decoder.bind(request).join();
          captured = Map<String, Object?>.from(jsonDecode(requestBody) as Map);
          expect(capturedContentLength, utf8.encode(requestBody).length);
          await _jsonResponse(request.response, 202, _jobJson());
          return;
        }
        if (request.uri.path == '/v1/comic-jobs/job-1') {
          await _jsonResponse(request.response, 200, _jobJson());
          return;
        }
        await _jsonResponse(request.response, 404, {'message': 'not found'});
      });
      final repository = HttpVideoLabRepository(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}/v1'),
        allowInsecureTransport: true,
      );

      final catalog = await repository.fetchCatalog();
      final job = await repository.createJob(
        story: '霓虹雨夜的月球快递员',
        textModelId: catalog.textModels.first.id,
        imageModelId: catalog.imageModels.first.id,
        videoModelId: catalog.videoModels.first.id,
        voiceModelId: catalog.voiceModels.first.id,
      );
      final refreshed = await repository.fetchJob(job.id);

      expect(refreshed.id, 'job-1');
      expect(captured, {
        'story': '霓虹雨夜的月球快递员',
        'textModelId': 'local_storyboard_template',
        'imageModelId': 'fixed_moon_courier_assets',
        'videoModelId': 'local_ffmpeg_motion_comic',
        'voiceModelId': 'windows_sapi_huihui',
        'aspectRatio': '9:16',
        'shotCount': 3,
        'shotDurationSeconds': 3,
      });
      expect(requestedPaths, contains('/v1/comic-jobs'));
      expect(requestedPaths, contains('/v1/comic-jobs/job-1'));
      expect(capturedContentLength, greaterThan(0));
      repository.close();
      await server.close(force: true);
      await serving;
    },
  );

  test('HTTP repository aborts JSON responses over 2 MiB', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.forEach((request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..contentLength = 2 * 1024 * 1024 + 1
        ..add(List<int>.filled(2 * 1024 * 1024 + 1, 0x20));
      await request.response.close();
    });
    final repository = HttpVideoLabRepository(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}/v1'),
      allowInsecureTransport: true,
    );

    await expectLater(
      repository.fetchCatalog(),
      throwsA(
        isA<VideoLabApiException>().having(
          (error) => error.message,
          'message',
          contains('2 MiB'),
        ),
      ),
    );

    repository.close();
    await server.close(force: true);
    await serving;
  });

  test('HTTP repository parses the final hybrid backend snapshot', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.forEach((request) async {
      if (request.uri.path == '/v1/comic-jobs/hybrid-job-1') {
        await _jsonResponse(request.response, 200, _backendHybridJobJson());
        return;
      }
      await _jsonResponse(request.response, 404, {'message': 'not found'});
    });
    final repository = HttpVideoLabRepository(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}/v1'),
      allowInsecureTransport: true,
    );

    final job = await repository.fetchJob('hybrid-job-1');

    expect(job.executionKind, VideoLabExecutionKind.hybrid);
    expect(job.modelExecution?.video, VideoLabExecutionSource.cloud);
    expect(job.shots.map((shot) => shot.id), [
      'E01-SH01',
      'E01-SH02',
      'E01-SH03',
    ]);
    expect(
      job.shots.first.firstFrameUrl?.path,
      '/v1/comic-jobs/hybrid-job-1/shots/E01-SH01/first-frame.png',
    );
    expect(
      job.shots.first.videoTask?.videoUrl?.path,
      '/v1/comic-jobs/hybrid-job-1/shots/E01-SH01/video.mp4',
    );
    expect(job.output?.isShotVideoComposition, isTrue);

    repository.close();
    await server.close(force: true);
    await serving;
  });
}

Map<String, Object?> _catalogJson() => {
  'textModels': [_localModel('text', 'local_storyboard_template')],
  'imageModels': [_localModel('image', 'fixed_moon_courier_assets')],
  'videoModels': [_localModel('video', 'local_ffmpeg_motion_comic')],
  'voiceModels': [_localModel('voice', 'windows_sapi_huihui')],
};

Map<String, Object?> _localModel(String capability, String id) => {
  'id': id,
  'capability': capability,
  'provider': 'local',
  'displayName': id,
  'description': '本地模板模式',
  'pricingType': 'free',
  'availability': 'available',
  'requiresCredential': false,
};

Map<String, Object?> _jobJson() => {
  'id': 'job-1',
  'status': 'queued',
  'progress': 0,
  'executionKind': 'template',
  'generatedForRequest': false,
  'containsAiGeneratedAssets': true,
  'assetProvenance': 'openai_imagegen_project_assets',
  'visualSource': 'fixed_project_assets',
  'stageCode': 'queued',
  'templateStoryTitle': '月背最后一单',
  'visualWarning': '不会按主题重绘',
  'error': null,
  'shots': [
    for (var index = 1; index <= 3; index++)
      {
        'id': 'shot-$index',
        'title': '镜头 $index',
        'status': 'queued',
        'progress': 0,
        'stageCode': 'queued',
      },
  ],
  'output': null,
};

Map<String, Object?> _backendHybridJobJson() {
  const modelExecution = {
    'text': 'local',
    'image': 'pre_generated',
    'video': 'cloud',
    'voice': 'local',
  };
  return {
    'id': 'hybrid-job-1',
    'status': 'succeeded',
    'progress': 100,
    'executionKind': 'hybrid',
    'generatedForRequest': true,
    'containsAiGeneratedAssets': true,
    'assetProvenance': 'openai_imagegen_project_assets',
    'visualSource': 'fixed_project_assets',
    'stageCode': 'succeeded',
    'templateStoryTitle': '月背最后一单',
    'visualWarning': '只有视频动态由 Wan 在本次任务生成。',
    'modelExecution': modelExecution,
    'error': null,
    'shots': [
      for (var index = 1; index <= 3; index++)
        {
          'id': 'E01-SH0$index',
          'title': '分镜 $index',
          'status': 'succeeded',
          'progress': 100,
          'stageCode': 'succeeded',
          'firstFrameUrl':
              '/v1/comic-jobs/hybrid-job-1/shots/E01-SH0$index/first-frame.png',
          'lastFrameUrl':
              '/v1/comic-jobs/hybrid-job-1/shots/E01-SH0$index/last-frame.png',
          'motionPrompt': '角色向前移动，镜头缓慢推进',
          'videoTask': {
            'remoteTaskId': 'wan-task-$index',
            'status': 'succeeded',
            'progress': 100,
            'videoUrl':
                '/v1/comic-jobs/hybrid-job-1/shots/E01-SH0$index/video.mp4',
            'error': null,
          },
        },
    ],
    'output': {
      'previewUrl': '/v1/comic-jobs/hybrid-job-1/preview.gif',
      'videoUrl': '/v1/comic-jobs/hybrid-job-1/video.mp4',
      'manifestUrl': '/v1/comic-jobs/hybrid-job-1/manifest.json',
      'scriptUrl': '/v1/comic-jobs/hybrid-job-1/script.json',
      'generatedForRequest': true,
      'containsAiGeneratedAssets': true,
      'assetProvenance': 'openai_imagegen_project_assets',
      'visualSource': 'fixed_project_assets',
      'modelExecution': modelExecution,
      'compositionType': 'shot_videos_concat',
      'sourceClipCount': 3,
    },
  };
}

Future<void> _jsonResponse(
  HttpResponse response,
  int status,
  Object body,
) async {
  response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await response.close();
}
