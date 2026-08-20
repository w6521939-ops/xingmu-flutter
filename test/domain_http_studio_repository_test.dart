import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/data/data.dart';
import 'package:xingmu_ai_video_studio/domain/domain.dart';

const _intentKey = '11111111-2222-4333-8444-555555555555';
const _secondIntentKey = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const _planIntentKey = '$_intentKey-plan';
const _runIntentKey = '$_intentKey-run';
const _secondPlanIntentKey = '$_secondIntentKey-plan';
const _secondRunIntentKey = '$_secondIntentKey-run';
const _projectEtag = '"project-rev-7"';
const _planEtag = '"plan-rev-2"';
const _runEtag = '"run-rev-3"';
const _jobEtag = '"job-rev-4"';

String _jobIntentKey(
  String base,
  String projectId,
  String runId,
  String jobId,
) {
  final mapKey = jsonEncode([projectId, runId, jobId]);
  var hash = 0x811c9dc5;
  for (final codeUnit in mapKey.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return '$base-job-${hash.toRadixString(16).padLeft(8, '0')}';
}

void main() {
  test('listProjects parses ProjectPage.items', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects?limit=100', {
        'items': [_projectJson()],
      }),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    final projects = await repository.listProjects();

    expect(projects.single.id, 'project-1');
    expect(projects.single.title, '星幕计划');
    expect(projects.single.theme, '雨夜天台发生了一场秘密相遇');
    expect(projects.single.aspectRatio, '9:16');
    expect(projects.single.etag, isNull, reason: '分页响应没有资源 ETag');
    await harness.done;
  });

  test('listProjects follows every nextCursor with limit 100', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects?limit=100', {
        'items': [_projectJson()],
        'nextCursor': 'projects-page-2',
      }),
      _Expectation.get('/api/projects?limit=100&cursor=projects-page-2', {
        'items': [
          {..._projectJson(), 'id': 'project-2', 'name': '第二个项目'},
        ],
        'nextCursor': null,
      }),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    final projects = await repository.listProjects();

    expect(projects.map((project) => project.id), ['project-1', 'project-2']);
    await harness.done;
  });

  test('pagination rejects repeated cursors instead of truncating', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects?limit=100', const {
        'items': <Object?>[],
        'nextCursor': 'loop',
      }),
      _Expectation.get('/api/projects?limit=100&cursor=loop', const {
        'items': <Object?>[],
        'nextCursor': 'loop',
      }),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.listProjects(),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test('pagination rejects a cross-host nextCursor', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects?limit=100', const {
        'items': <Object?>[],
        'nextCursor': 'https://evil.test/api/projects?cursor=stolen',
      }),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.listProjects(),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test(
    'createProject uses contract fields and returns the strong ETag',
    () async {
      final harness = await _Harness.start([
        _Expectation.post(
          '/api/projects',
          requestBody: const {
            'name': '星幕计划',
            'description': '雨夜天台发生了一场秘密相遇',
            'aspectRatio': '9:16',
          },
          responseBody: _projectJson(),
          responseEtag: _projectEtag,
          expectedIdempotencyKey: _intentKey,
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      final project = await repository.createProject(
        theme: '雨夜天台发生了一场秘密相遇',
        title: '星幕计划',
        idempotencyKey: _intentKey,
      );

      expect(project.etag, _projectEtag);
      expect(project.revision, 7);
      await harness.done;
    },
  );

  test(
    'createProject replays an ambiguous POST with its original key',
    () async {
      const body = {
        'name': '星幕计划',
        'description': '雨夜天台发生了一场秘密相遇',
        'aspectRatio': '9:16',
      };
      final harness = await _Harness.start([
        _Expectation.post(
          '/api/projects',
          requestBody: body,
          responseBody: null,
          expectedIdempotencyKey: _intentKey,
          disconnectAfterRequest: true,
        ),
        _Expectation.post(
          '/api/projects',
          requestBody: body,
          responseBody: _projectJson(),
          responseEtag: _projectEtag,
          expectedIdempotencyKey: _intentKey,
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.createProject(
          theme: '雨夜天台发生了一场秘密相遇',
          title: '星幕计划',
          idempotencyKey: _intentKey,
        ),
        throwsA(anything),
      );
      final project = await repository.createProject(
        theme: '雨夜天台发生了一场秘密相遇',
        title: '星幕计划',
        idempotencyKey: _secondIntentKey,
      );

      expect(project.id, 'project-1');
      await harness.done;
    },
  );

  test('createProject clears its intent after a deterministic 4xx', () async {
    const body = {
      'name': '星幕计划',
      'description': '雨夜天台发生了一场秘密相遇',
      'aspectRatio': '9:16',
    };
    final harness = await _Harness.start([
      _Expectation.post(
        '/api/projects',
        requestBody: body,
        responseBody: const {'status': 422, 'title': 'invalid project'},
        expectedIdempotencyKey: _intentKey,
        statusCode: 422,
      ),
      _Expectation.post(
        '/api/projects',
        requestBody: body,
        responseBody: _projectJson(),
        responseEtag: _projectEtag,
        expectedIdempotencyKey: _secondIntentKey,
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.createProject(
        theme: '雨夜天台发生了一场秘密相遇',
        title: '星幕计划',
        idempotencyKey: _intentKey,
      ),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 422),
      ),
    );
    final project = await repository.createProject(
      theme: '雨夜天台发生了一场秘密相遇',
      title: '星幕计划',
      idempotencyKey: _secondIntentKey,
    );

    expect(project.id, 'project-1');
    await harness.done;
  });

  test(
    'createProject keeps 5xx intent without sharing it across inputs',
    () async {
      const firstBody = {
        'name': '星幕计划',
        'description': '雨夜天台发生了一场秘密相遇',
        'aspectRatio': '9:16',
      };
      const secondBody = {
        'name': '海边计划',
        'description': '海边日出',
        'aspectRatio': '9:16',
      };
      final harness = await _Harness.start([
        _Expectation.post(
          '/api/projects',
          requestBody: firstBody,
          responseBody: const {
            'status': 503,
            'title': 'temporarily unavailable',
          },
          expectedIdempotencyKey: _intentKey,
          statusCode: 503,
        ),
        _Expectation.post(
          '/api/projects',
          requestBody: secondBody,
          responseBody: {
            ..._projectJson(),
            'id': 'project-2',
            'name': '海边计划',
            'description': '海边日出',
          },
          responseEtag: '"project-2-rev-7"',
          expectedIdempotencyKey: _secondIntentKey,
        ),
        _Expectation.post(
          '/api/projects',
          requestBody: firstBody,
          responseBody: _projectJson(),
          responseEtag: _projectEtag,
          expectedIdempotencyKey: _intentKey,
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.createProject(
          theme: '雨夜天台发生了一场秘密相遇',
          title: '星幕计划',
          idempotencyKey: _intentKey,
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            503,
          ),
        ),
      );
      final second = await repository.createProject(
        theme: '海边日出',
        title: '海边计划',
        idempotencyKey: _secondIntentKey,
      );
      final first = await repository.createProject(
        theme: '雨夜天台发生了一场秘密相遇',
        title: '星幕计划',
        idempotencyKey: _secondIntentKey,
      );

      expect(second.id, 'project-2');
      expect(first.id, 'project-1');
      await harness.done;
    },
  );

  test('adoptScript creates a script job then refreshes the project', () async {
    final harness = await _Harness.start([
      _Expectation.post(
        '/api/projects/project-1/script-jobs',
        requestBody: const {
          'sourceType': 'theme',
          'sourceText': '雨夜天台发生了一场秘密相遇',
          'episodeCount': 1,
        },
        responseBody: _scriptJobJson(status: 'queued', result: null),
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _intentKey,
      ),
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(latestScriptJobId: 'script-job-1'),
        responseEtag: '"project-rev-8"',
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    final project = await repository.adoptScript(
      projectId: 'project-1',
      etag: _projectEtag,
      sourceText: '雨夜天台发生了一场秘密相遇',
      idempotencyKey: _intentKey,
    );

    expect(project.latestScriptJobId, 'script-job-1');
    expect(project.latestScriptJobStatus, StudioStatus.pending);
    expect(project.script, isNull);
    expect(project.etag, '"project-rev-8"');
    await harness.done;
  });

  test('completed script job does not invent speaker or voiceName', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects?limit=100', {
        'items': [_projectJson(latestScriptJobId: 'script-job-1')],
      }),
      _Expectation.get(
        '/api/script-jobs/script-job-1',
        _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    final project = (await repository.listProjects()).single;
    final line = project.voiceLines.single;

    expect(line.speaker, '说话人未返回');
    expect(line.voiceName, '声线未返回');
    expect(line.speaker, isNot('旁白/角色'));
    expect(line.voiceName, isNot('自动匹配'));
    await harness.done;
  });

  test('adoptScript replays an ambiguous POST with its original key', () async {
    const body = {
      'sourceType': 'theme',
      'sourceText': '雨夜天台发生了一场秘密相遇',
      'episodeCount': 1,
    };
    final harness = await _Harness.start([
      _Expectation.post(
        '/api/projects/project-1/script-jobs',
        requestBody: body,
        responseBody: null,
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _intentKey,
        disconnectAfterRequest: true,
      ),
      _Expectation.post(
        '/api/projects/project-1/script-jobs',
        requestBody: body,
        responseBody: _scriptJobJson(status: 'queued', result: null),
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _intentKey,
      ),
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(latestScriptJobId: 'script-job-1'),
        responseEtag: '"project-rev-8"',
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.adoptScript(
        projectId: 'project-1',
        etag: _projectEtag,
        sourceText: '雨夜天台发生了一场秘密相遇',
        idempotencyKey: _intentKey,
      ),
      throwsA(anything),
    );
    final project = await repository.adoptScript(
      projectId: 'project-1',
      etag: '"project-rev-8"',
      sourceText: '雨夜天台发生了一场秘密相遇',
      idempotencyKey: _secondIntentKey,
    );

    expect(project.latestScriptJobStatus, StudioStatus.pending);
    await harness.done;
  });

  test('adoptScript does not repost after its job was accepted', () async {
    const body = {
      'sourceType': 'theme',
      'sourceText': '雨夜天台发生了一场秘密相遇',
      'episodeCount': 1,
    };
    final harness = await _Harness.start([
      _Expectation.post(
        '/api/projects/project-1/script-jobs',
        requestBody: body,
        responseBody: _scriptJobJson(status: 'queued', result: null),
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _intentKey,
      ),
      _Expectation.get('/api/projects/project-1', const {
        'status': 503,
        'title': 'temporarily unavailable',
      }, statusCode: 503),
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(latestScriptJobId: 'script-job-1'),
        responseEtag: '"project-rev-8"',
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.adoptScript(
        projectId: 'project-1',
        etag: _projectEtag,
        sourceText: '雨夜天台发生了一场秘密相遇',
        idempotencyKey: _intentKey,
      ),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 503),
      ),
    );
    final project = await repository.adoptScript(
      projectId: 'project-1',
      etag: _projectEtag,
      sourceText: '雨夜天台发生了一场秘密相遇',
      idempotencyKey: _secondIntentKey,
    );

    expect(project.latestScriptJobId, 'script-job-1');
    await harness.done;
  });

  test(
    'startGeneration creates a plan, starts its run, then gets run ETag',
    () async {
      final harness = await _Harness.start([
        _Expectation.get('/api/projects?limit=100', {
          'items': [_projectJson(latestScriptJobId: 'script-job-1')],
        }),
        _Expectation.get(
          '/api/script-jobs/script-job-1',
          _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
        ),
        _Expectation.get(
          '/api/script-jobs/script-job-1',
          _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
        ),
        _Expectation.post(
          '/api/projects/project-1/generation-plans',
          requestBody: const {
            'scriptJobId': 'script-job-1',
            'providerStrategy': 'automatic',
            'shotIds': ['shot-1'],
            'regenerateExisting': false,
          },
          responseBody: _planJson(),
          responseEtag: _planEtag,
          expectedEtag: _projectEtag,
          expectedIdempotencyKey: _planIntentKey,
        ),
        _Expectation.post(
          '/api/generation-plans/plan-1/runs',
          requestBody: const {'stopOnQuotaError': true},
          responseBody: _runJson(),
          expectedEtag: _planEtag,
          expectedIdempotencyKey: _runIntentKey,
        ),
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(latestScriptJobId: 'script-job-1'),
          responseEtag: '"project-rev-9"',
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));
      await repository.listProjects();

      final project = await repository.startGeneration(
        projectId: 'project-1',
        etag: _projectEtag,
        shotIds: const ['shot-1'],
        idempotencyKey: _intentKey,
      );

      expect(project.currentRun?.id, 'run-1');
      expect(project.currentRun?.etag, _runEtag);
      expect(project.shots.map((shot) => shot.id), ['shot-1', 'shot-2']);
      await harness.done;
    },
  );

  test(
    'ambiguous run failure resumes its plan and success clears the intent key',
    () async {
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(latestScriptJobId: 'script-job-1'),
          responseEtag: _projectEtag,
        ),
        _Expectation.get(
          '/api/script-jobs/script-job-1',
          _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
        ),
        _Expectation.post(
          '/api/projects/project-1/generation-plans',
          requestBody: const {
            'scriptJobId': 'script-job-1',
            'providerStrategy': 'automatic',
            'shotIds': ['shot-1'],
            'regenerateExisting': false,
          },
          responseBody: _planJson(),
          responseEtag: _planEtag,
          expectedEtag: _projectEtag,
          expectedIdempotencyKey: _planIntentKey,
        ),
        _Expectation.post(
          '/api/generation-plans/plan-1/runs',
          requestBody: const {'stopOnQuotaError': true},
          responseBody: null,
          expectedEtag: _planEtag,
          expectedIdempotencyKey: _runIntentKey,
          disconnectAfterRequest: true,
        ),
        _Expectation.get(
          '/api/script-jobs/script-job-1',
          _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
        ),
        _Expectation.post(
          '/api/generation-plans/plan-1/runs',
          requestBody: const {'stopOnQuotaError': true},
          responseBody: _runJson(),
          expectedEtag: _planEtag,
          expectedIdempotencyKey: _runIntentKey,
        ),
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(latestScriptJobId: 'script-job-1', activeRunId: 'run-1'),
          responseEtag: '"project-rev-9"',
        ),
        _Expectation.get(
          '/api/script-jobs/script-job-1',
          _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
        ),
        _Expectation.post(
          '/api/projects/project-1/generation-plans',
          requestBody: const {
            'scriptJobId': 'script-job-1',
            'providerStrategy': 'automatic',
            'shotIds': ['shot-1'],
            'regenerateExisting': false,
          },
          responseBody: {..._planJson(), 'id': 'plan-2'},
          responseEtag: '"plan-rev-3"',
          expectedEtag: '"project-rev-9"',
          expectedIdempotencyKey: _secondPlanIntentKey,
        ),
        _Expectation.post(
          '/api/generation-plans/plan-2/runs',
          requestBody: const {'stopOnQuotaError': true},
          responseBody: {..._runJson(), 'id': 'run-2', 'planId': 'plan-2'},
          expectedEtag: '"plan-rev-3"',
          expectedIdempotencyKey: _secondRunIntentKey,
        ),
        _Expectation.get('/api/generation-runs/run-2', {
          ..._runJson(),
          'id': 'run-2',
          'planId': 'plan-2',
        }, responseEtag: '"run-rev-4"'),
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(latestScriptJobId: 'script-job-1', activeRunId: 'run-2'),
          responseEtag: '"project-rev-10"',
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.startGeneration(
          projectId: 'project-1',
          etag: _projectEtag,
          shotIds: const ['shot-1'],
          idempotencyKey: _intentKey,
        ),
        throwsA(anything),
      );

      final project = await repository.startGeneration(
        projectId: 'project-1',
        etag: _projectEtag,
        shotIds: const ['shot-1'],
        idempotencyKey: _secondIntentKey,
      );

      expect(project.currentRun?.id, 'run-1');
      final nextProject = await repository.startGeneration(
        projectId: 'project-1',
        etag: project.etag!,
        shotIds: const ['shot-1'],
        idempotencyKey: _secondIntentKey,
      );
      expect(nextProject.currentRun?.id, 'run-2');
      await harness.done;
    },
  );

  test(
    'plan response without ETag replays the plan with its original key',
    () async {
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(latestScriptJobId: 'script-job-1'),
          responseEtag: _projectEtag,
        ),
        _Expectation.get(
          '/api/script-jobs/script-job-1',
          _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
        ),
        _Expectation.post(
          '/api/projects/project-1/generation-plans',
          requestBody: const {
            'scriptJobId': 'script-job-1',
            'providerStrategy': 'automatic',
            'shotIds': ['shot-1'],
            'regenerateExisting': false,
          },
          responseBody: _planJson(),
          expectedEtag: _projectEtag,
          expectedIdempotencyKey: _planIntentKey,
        ),
        _Expectation.get(
          '/api/script-jobs/script-job-1',
          _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
        ),
        _Expectation.post(
          '/api/projects/project-1/generation-plans',
          requestBody: const {
            'scriptJobId': 'script-job-1',
            'providerStrategy': 'automatic',
            'shotIds': ['shot-1'],
            'regenerateExisting': false,
          },
          responseBody: _planJson(),
          responseEtag: _planEtag,
          expectedEtag: _projectEtag,
          expectedIdempotencyKey: _planIntentKey,
        ),
        _Expectation.post(
          '/api/generation-plans/plan-1/runs',
          requestBody: const {'stopOnQuotaError': true},
          responseBody: _runJson(),
          expectedEtag: _planEtag,
          expectedIdempotencyKey: _runIntentKey,
        ),
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(latestScriptJobId: 'script-job-1', activeRunId: 'run-1'),
          responseEtag: '"project-rev-9"',
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.startGeneration(
          projectId: 'project-1',
          etag: _projectEtag,
          shotIds: const ['shot-1'],
          idempotencyKey: _intentKey,
        ),
        throwsA(isA<ApiContractException>()),
      );
      final project = await repository.startGeneration(
        projectId: 'project-1',
        etag: _projectEtag,
        shotIds: const ['shot-1'],
        idempotencyKey: _secondIntentKey,
      );

      expect(project.currentRun?.id, 'run-1');
      await harness.done;
    },
  );

  for (final action in ['pause', 'resume', 'cancel']) {
    test(
      '$action uses generation-runs actions endpoint and exact body',
      () async {
        final nextStatus = action == 'pause'
            ? 'paused'
            : action == 'resume'
            ? 'running'
            : 'canceled';
        final harness = await _Harness.start([
          _Expectation.get(
            '/api/generation-runs/run-1',
            _runJson(),
            responseEtag: _runEtag,
          ),
          _Expectation.post(
            '/api/generation-runs/run-1/actions',
            requestBody: {'action': action},
            responseBody: _runJson(status: nextStatus),
            expectedEtag: _runEtag,
            expectedIdempotencyKey: _intentKey,
          ),
          _Expectation.get(
            '/api/generation-runs/run-1',
            _runJson(status: nextStatus, revision: 4),
            responseEtag: '"run-rev-4"',
          ),
          _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', const {
            'items': <Object?>[],
          }),
          _Expectation.get(
            '/api/projects/project-1',
            _projectJson(),
            responseEtag: _projectEtag,
          ),
        ]);
        addTearDown(harness.close);
        final repository = harness.repository();
        addTearDown(() => repository.close(force: true));

        final project = switch (action) {
          'pause' => await repository.pauseGeneration(
            projectId: 'project-1',
            runId: 'run-1',
            runEtag: _runEtag,
            idempotencyKey: _intentKey,
          ),
          'resume' => await repository.resumeGeneration(
            projectId: 'project-1',
            runId: 'run-1',
            runEtag: _runEtag,
            idempotencyKey: _intentKey,
          ),
          _ => await repository.cancelGeneration(
            projectId: 'project-1',
            runId: 'run-1',
            runEtag: _runEtag,
            idempotencyKey: _intentKey,
          ),
        };

        expect(project.currentRun?.etag, '"run-rev-4"');
        expect(project.currentRun?.status, StudioStatus.fromJson(nextStatus));
        await harness.done;
      },
    );
  }

  test(
    'retryFailedTasks gets each job ETag and posts job retry action',
    () async {
      final failedJob = _jobJson(status: 'failed');
      final queuedJob = _jobJson(status: 'queued', revision: 5);
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
          'items': [failedJob],
        }),
        _Expectation.get(
          '/api/generation-jobs/job-1',
          failedJob,
          responseEtag: _jobEtag,
        ),
        _Expectation.post(
          '/api/generation-jobs/job-1/actions',
          requestBody: const {'action': 'retry'},
          responseBody: queuedJob,
          expectedEtag: _jobEtag,
          expectedIdempotencyKey: _jobIntentKey(
            _intentKey,
            'project-1',
            'run-1',
            'job-1',
          ),
        ),
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
          'items': [queuedJob],
        }),
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(),
          responseEtag: _projectEtag,
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      final project = await repository.retryFailedTasks(
        projectId: 'project-1',
        runId: 'run-1',
        idempotencyKey: _intentKey,
      );

      expect(project.currentRun?.tasks.single.status, StudioStatus.pending);
      await harness.done;
    },
  );

  test(
    'retryTask gets a strong ETag and posts only the selected job',
    () async {
      final failedJob = _jobJson(status: 'failed');
      final queuedJob = _jobJson(status: 'queued', revision: 5);
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get(
          '/api/generation-jobs/job-1',
          failedJob,
          responseEtag: _jobEtag,
        ),
        _Expectation.post(
          '/api/generation-jobs/job-1/actions',
          requestBody: const {'action': 'retry'},
          responseBody: queuedJob,
          expectedEtag: _jobEtag,
          expectedIdempotencyKey: _jobIntentKey(
            _intentKey,
            'project-1',
            'run-1',
            'job-1',
          ),
        ),
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
          'items': [queuedJob],
        }),
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(activeRunId: 'run-1'),
          responseEtag: _projectEtag,
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      final project = await repository.retryTask(
        projectId: 'project-1',
        runId: 'run-1',
        taskId: 'job-1',
        idempotencyKey: _intentKey,
      );

      expect(project.currentRun?.tasks.single.id, 'job-1');
      expect(project.currentRun?.tasks.single.status, StudioStatus.pending);
      await harness.done;
    },
  );

  test(
    'retryTask replays an ambiguous POST with its original job key',
    () async {
      final failedJob = _jobJson(status: 'failed');
      final queuedJob = _jobJson(status: 'queued', revision: 5);
      final jobKey = _jobIntentKey(_intentKey, 'project-1', 'run-1', 'job-1');
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get(
          '/api/generation-jobs/job-1',
          failedJob,
          responseEtag: _jobEtag,
        ),
        _Expectation.post(
          '/api/generation-jobs/job-1/actions',
          requestBody: const {'action': 'retry'},
          responseBody: null,
          expectedEtag: _jobEtag,
          expectedIdempotencyKey: jobKey,
          disconnectAfterRequest: true,
        ),
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.post(
          '/api/generation-jobs/job-1/actions',
          requestBody: const {'action': 'retry'},
          responseBody: queuedJob,
          expectedEtag: _jobEtag,
          expectedIdempotencyKey: jobKey,
        ),
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
          'items': [queuedJob],
        }),
        _Expectation.get(
          '/api/projects/project-1',
          _projectJson(activeRunId: 'run-1'),
          responseEtag: _projectEtag,
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.retryTask(
          projectId: 'project-1',
          runId: 'run-1',
          taskId: 'job-1',
          idempotencyKey: _intentKey,
        ),
        throwsA(anything),
      );
      final project = await repository.retryTask(
        projectId: 'project-1',
        runId: 'run-1',
        taskId: 'job-1',
        idempotencyKey: _secondIntentKey,
      );

      expect(project.currentRun?.tasks.single.status, StudioStatus.pending);
      await harness.done;
    },
  );

  test('retryFailedTasks derives and preserves a key for each job', () async {
    final failedJob1 = _jobJson(status: 'failed');
    final failedJob2 = {
      ..._jobJson(status: 'failed'),
      'id': 'job-2',
      'shotId': 'shot-2',
    };
    final queuedJob1 = _jobJson(status: 'queued', revision: 5);
    final queuedJob2 = {
      ..._jobJson(status: 'queued', revision: 5),
      'id': 'job-2',
      'shotId': 'shot-2',
    };
    final jobKey1 = _jobIntentKey(_intentKey, 'project-1', 'run-1', 'job-1');
    final jobKey2 = _jobIntentKey(_intentKey, 'project-1', 'run-1', 'job-2');
    expect(jobKey1, isNot(jobKey2));
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/generation-runs/run-1',
        _runJson(),
        responseEtag: _runEtag,
      ),
      _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
        'items': [failedJob1, failedJob2],
      }),
      _Expectation.get(
        '/api/generation-jobs/job-1',
        failedJob1,
        responseEtag: _jobEtag,
      ),
      _Expectation.get(
        '/api/generation-jobs/job-2',
        failedJob2,
        responseEtag: '"job-2-rev-4"',
      ),
      _Expectation.post(
        '/api/generation-jobs/job-1/actions',
        requestBody: const {'action': 'retry'},
        responseBody: queuedJob1,
        expectedEtag: _jobEtag,
        expectedIdempotencyKey: jobKey1,
      ),
      _Expectation.post(
        '/api/generation-jobs/job-2/actions',
        requestBody: const {'action': 'retry'},
        responseBody: null,
        expectedEtag: '"job-2-rev-4"',
        expectedIdempotencyKey: jobKey2,
        disconnectAfterRequest: true,
      ),
      _Expectation.get(
        '/api/generation-runs/run-1',
        _runJson(),
        responseEtag: _runEtag,
      ),
      _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
        'items': [queuedJob1, failedJob2],
      }),
      _Expectation.post(
        '/api/generation-jobs/job-2/actions',
        requestBody: const {'action': 'retry'},
        responseBody: queuedJob2,
        expectedEtag: '"job-2-rev-4"',
        expectedIdempotencyKey: jobKey2,
      ),
      _Expectation.get(
        '/api/generation-runs/run-1',
        _runJson(),
        responseEtag: _runEtag,
      ),
      _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
        'items': [queuedJob1, queuedJob2],
      }),
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(activeRunId: 'run-1'),
        responseEtag: _projectEtag,
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.retryFailedTasks(
        projectId: 'project-1',
        runId: 'run-1',
        idempotencyKey: _intentKey,
      ),
      throwsA(anything),
    );
    final project = await repository.retryFailedTasks(
      projectId: 'project-1',
      runId: 'run-1',
      idempotencyKey: _secondIntentKey,
    );

    expect(project.currentRun?.tasks, hasLength(2));
    await harness.done;
  });

  test('fresh repository restores active run jobs and latest export', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects?limit=100', {
        'items': [
          _projectJson(activeRunId: 'run-1', latestExportId: 'export-1'),
        ],
      }),
      _Expectation.get(
        '/api/generation-runs/run-1',
        _runJson(status: 'canceled', revision: 4),
        responseEtag: '"run-rev-4"',
      ),
      _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
        'items': [
          _jobJson(status: 'canceled', stage: 'prop_images', revision: 5),
        ],
        'nextCursor': 'jobs-page-2',
      }),
      _Expectation.get(
        '/api/generation-runs/run-1/jobs?limit=100&cursor=jobs-page-2',
        {
          'items': [
            {..._jobJson(status: 'succeeded', revision: 6), 'id': 'job-2'},
          ],
          'nextCursor': null,
        },
      ),
      _Expectation.get('/api/projects/project-1/exports?limit=100', {
        'items': [
          {
            ..._exportJson(),
            'id': 'export-0',
            'status': 'queued',
            'progress': 0,
            'assetId': null,
          },
        ],
        'nextCursor': 'exports-page-2',
      }),
      _Expectation.get(
        '/api/projects/project-1/exports?limit=100&cursor=exports-page-2',
        {
          'items': [_exportJson()],
          'nextCursor': null,
        },
      ),
      _Expectation.get(
        '/api/assets/asset-export-1',
        _assetJson(),
        responseEtag: '"asset-rev-2"',
      ),
      _Expectation.get('/api/exports/export-1/download', {
        'url': 'https://download.test/export-1.mp4',
        'expiresAt': '2026-08-20T09:00:00Z',
        'sha256': List.filled(64, 'a').join(),
      }),
    ]);
    addTearDown(harness.close);
    final restartedRepository = harness.repository();
    addTearDown(() => restartedRepository.close(force: true));

    final project = (await restartedRepository.listProjects()).single;

    expect(project.activeRunId, 'run-1');
    expect(project.currentRun?.status, StudioStatus.canceled);
    expect(project.currentRun?.tasks, hasLength(2));
    expect(project.currentRun?.tasks.first.status, StudioStatus.canceled);
    expect(project.currentRun?.tasks.first.type, GenerationTaskType.propImage);
    expect(project.currentRun?.progress, 1);
    expect(project.latestExportId, 'export-1');
    expect(project.exports, hasLength(2));
    expect(project.exports.last.ready, isTrue);
    expect(
      project.exports.last.previewUrl,
      'https://preview.test/export-1.mp4',
    );
    expect(
      project.exports.last.downloadUrl,
      'https://download.test/export-1.mp4',
    );
    await harness.done;
  });

  test('refreshProject gets project and preserves its response ETag', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(),
        responseEtag: _projectEtag,
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    final project = await repository.refreshProject('project-1');

    expect(project.etag, _projectEtag);
    await harness.done;
  });

  test('missing access token fails before any network request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requestCount = 0;
    server.listen((request) {
      requestCount++;
      request.response.close();
    });
    final repository = HttpStudioRepository(
      baseUri: Uri.parse(
        'http://${server.address.address}:${server.port}/api/',
      ),
      accessTokenProvider: () async => null,
      allowInsecureTransport: true,
    );
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.listProjects(),
      throwsA(isA<UnauthenticatedException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(requestCount, 0);
  });

  test('plain HTTP is rejected unless development opt-in is explicit', () {
    expect(
      () => HttpStudioRepository(
        baseUri: Uri.parse('http://127.0.0.1:1234/api/'),
        accessTokenProvider: () async => 'token',
      ),
      throwsArgumentError,
    );
  });

  test(
    'problem+json maps detail, code, requestId and retryAfterSeconds',
    () async {
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/projects?limit=100',
          const {
            'type': 'https://errors.test/quota',
            'title': '请求过多',
            'status': 429,
            'code': 'rate_limited',
            'detail': '请稍后重试',
            'requestId': 'req-1',
            'retryAfterSeconds': 12,
          },
          statusCode: 429,
          contentType: 'application/problem+json',
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.listProjects(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.message, 'message', '请稍后重试')
              .having((error) => error.code, 'code', 'rate_limited')
              .having((error) => error.requestId, 'requestId', 'req-1')
              .having((error) => error.retryAfterSeconds, 'retry', 12),
        ),
      );
    },
  );

  test(
    'unknown server status is rejected instead of becoming pending',
    () async {
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.post(
          '/api/generation-runs/run-1/actions',
          requestBody: const {'action': 'pause'},
          responseBody: _runJson(status: 'paused'),
          expectedEtag: _runEtag,
          expectedIdempotencyKey: _intentKey,
        ),
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(status: 'mystery'),
          responseEtag: _runEtag,
        ),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.pauseGeneration(
          projectId: 'project-1',
          runId: 'run-1',
          runEtag: _runEtag,
          idempotencyKey: _intentKey,
        ),
        throwsA(anything),
      );
    },
  );

  for (final invalid in <(String, Map<String, Object?>)>[
    ('null id', {..._projectJson(), 'id': null}),
    ('zero revision', {..._projectJson(), 'revision': 0}),
    ('bad timestamp', {..._projectJson(), 'updatedAt': 'not-a-timestamp'}),
    ('empty nullable id', {..._projectJson(), 'activeRunId': ''}),
  ]) {
    test('Project rejects ${invalid.$1}', () async {
      final harness = await _Harness.start([
        _Expectation.get('/api/projects?limit=100', {
          'items': [invalid.$2],
        }),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.listProjects(),
        throwsA(isA<ApiContractException>()),
      );
      await harness.done;
    });
  }

  test('GenerationPlan rejects zero revision', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(latestScriptJobId: 'script-job-1'),
        responseEtag: _projectEtag,
      ),
      _Expectation.get(
        '/api/script-jobs/script-job-1',
        _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
      ),
      _Expectation.post(
        '/api/projects/project-1/generation-plans',
        requestBody: const {
          'scriptJobId': 'script-job-1',
          'providerStrategy': 'automatic',
          'shotIds': ['shot-1'],
          'regenerateExisting': false,
        },
        responseBody: {..._planJson(), 'revision': 0},
        responseEtag: _planEtag,
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _planIntentKey,
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.startGeneration(
        projectId: 'project-1',
        etag: _projectEtag,
        shotIds: const ['shot-1'],
        idempotencyKey: _intentKey,
      ),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test('GenerationRun rejects zero revision', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(latestScriptJobId: 'script-job-1'),
        responseEtag: _projectEtag,
      ),
      _Expectation.get(
        '/api/script-jobs/script-job-1',
        _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
      ),
      _Expectation.post(
        '/api/projects/project-1/generation-plans',
        requestBody: const {
          'scriptJobId': 'script-job-1',
          'providerStrategy': 'automatic',
          'shotIds': ['shot-1'],
          'regenerateExisting': false,
        },
        responseBody: _planJson(),
        responseEtag: _planEtag,
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _planIntentKey,
      ),
      _Expectation.post(
        '/api/generation-plans/plan-1/runs',
        requestBody: const {'stopOnQuotaError': true},
        responseBody: _runJson(revision: 0),
        expectedEtag: _planEtag,
        expectedIdempotencyKey: _runIntentKey,
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.startGeneration(
        projectId: 'project-1',
        etag: _projectEtag,
        shotIds: const ['shot-1'],
        idempotencyKey: _intentKey,
      ),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test('GET project rejects a resource id different from its URL', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects/project-1', {
        ..._projectJson(),
        'id': 'project-2',
      }, responseEtag: _projectEtag),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.refreshProject('project-1'),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test('GenerationPlan rejects a project association mismatch', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(latestScriptJobId: 'script-job-1'),
        responseEtag: _projectEtag,
      ),
      _Expectation.get(
        '/api/script-jobs/script-job-1',
        _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
      ),
      _Expectation.post(
        '/api/projects/project-1/generation-plans',
        requestBody: const {
          'scriptJobId': 'script-job-1',
          'providerStrategy': 'automatic',
          'shotIds': ['shot-1'],
          'regenerateExisting': false,
        },
        responseBody: {..._planJson(), 'projectId': 'project-2'},
        responseEtag: _planEtag,
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _planIntentKey,
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.startGeneration(
        projectId: 'project-1',
        etag: _projectEtag,
        shotIds: const ['shot-1'],
        idempotencyKey: _intentKey,
      ),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test('GenerationRun rejects a plan association mismatch', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(latestScriptJobId: 'script-job-1'),
        responseEtag: _projectEtag,
      ),
      _Expectation.get(
        '/api/script-jobs/script-job-1',
        _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
      ),
      _Expectation.post(
        '/api/projects/project-1/generation-plans',
        requestBody: const {
          'scriptJobId': 'script-job-1',
          'providerStrategy': 'automatic',
          'shotIds': ['shot-1'],
          'regenerateExisting': false,
        },
        responseBody: _planJson(),
        responseEtag: _planEtag,
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _planIntentKey,
      ),
      _Expectation.post(
        '/api/generation-plans/plan-1/runs',
        requestBody: const {'stopOnQuotaError': true},
        responseBody: {..._runJson(), 'planId': 'plan-2'},
        expectedEtag: _planEtag,
        expectedIdempotencyKey: _runIntentKey,
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.startGeneration(
        projectId: 'project-1',
        etag: _projectEtag,
        shotIds: const ['shot-1'],
        idempotencyKey: _intentKey,
      ),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test('job list rejects a run association mismatch', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(activeRunId: 'run-1'),
        responseEtag: _projectEtag,
      ),
      _Expectation.get(
        '/api/generation-runs/run-1',
        _runJson(),
        responseEtag: _runEtag,
      ),
      _Expectation.get('/api/generation-runs/run-1/jobs?limit=100', {
        'items': [
          {..._jobJson(status: 'queued'), 'runId': 'run-2'},
        ],
      }),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.refreshProject('project-1'),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test(
    'retryTask rejects run ownership mismatch before reading the job',
    () async {
      final harness = await _Harness.start([
        _Expectation.get('/api/generation-runs/run-1', {
          ..._runJson(),
          'projectId': 'project-2',
        }, responseEtag: _runEtag),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.retryTask(
          projectId: 'project-1',
          runId: 'run-1',
          taskId: 'job-1',
          idempotencyKey: _intentKey,
        ),
        throwsA(isA<ApiContractException>()),
      );
      await harness.done;
    },
  );

  test('null run status is rejected instead of becoming pending', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(activeRunId: 'run-1'),
        responseEtag: _projectEtag,
      ),
      _Expectation.get('/api/generation-runs/run-1', {
        ..._runJson(),
        'status': null,
      }, responseEtag: _runEtag),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.refreshProject('project-1'),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test(
    'unknown GenerationJob stage is rejected instead of becoming script',
    () async {
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get('/api/generation-jobs/job-1', {
          ..._jobJson(status: 'failed'),
          'stage': 'future_stage',
        }, responseEtag: _jobEtag),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.retryTask(
          projectId: 'project-1',
          runId: 'run-1',
          taskId: 'job-1',
          idempotencyKey: _intentKey,
        ),
        throwsA(isA<ApiContractException>()),
      );
      await harness.done;
    },
  );

  for (final legacyStage in const [
    'character_image',
    'scene_image',
    'prop_image',
    'storyboard_frame',
    'shot_video',
    'voice_line',
  ]) {
    test('HTTP rejects legacy GenerationStage alias $legacyStage', () async {
      final harness = await _Harness.start([
        _Expectation.get(
          '/api/generation-runs/run-1',
          _runJson(),
          responseEtag: _runEtag,
        ),
        _Expectation.get('/api/generation-jobs/job-1', {
          ..._jobJson(status: 'failed'),
          'stage': legacyStage,
        }, responseEtag: _jobEtag),
      ]);
      addTearDown(harness.close);
      final repository = harness.repository();
      addTearDown(() => repository.close(force: true));

      await expectLater(
        repository.retryTask(
          projectId: 'project-1',
          runId: 'run-1',
          taskId: 'job-1',
          idempotencyKey: _intentKey,
        ),
        throwsA(isA<ApiContractException>()),
      );
      await harness.done;
    });
  }

  test('HTTP rejects uppercase GenerationRun status', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/generation-runs/run-1', {
        ..._runJson(),
        'status': 'RUNNING',
      }, responseEtag: _runEtag),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.retryTask(
        projectId: 'project-1',
        runId: 'run-1',
        taskId: 'job-1',
        idempotencyKey: _intentKey,
      ),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  for (final invalidCurrentStage in <Object?>['shot_video', 'RUNNING', 42]) {
    test(
      'HTTP rejects invalid GenerationRun currentStage $invalidCurrentStage',
      () async {
        final harness = await _Harness.start([
          _Expectation.get('/api/generation-runs/run-1', {
            ..._runJson(),
            'currentStage': invalidCurrentStage,
          }, responseEtag: _runEtag),
        ]);
        addTearDown(harness.close);
        final repository = harness.repository();
        addTearDown(() => repository.close(force: true));

        await expectLater(
          repository.retryTask(
            projectId: 'project-1',
            runId: 'run-1',
            taskId: 'job-1',
            idempotencyKey: _intentKey,
          ),
          throwsA(isA<ApiContractException>()),
        );
        await harness.done;
      },
    );
  }

  test('HTTP rejects uppercase GenerationPlan providerStrategy', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(latestScriptJobId: 'script-job-1'),
        responseEtag: _projectEtag,
      ),
      _Expectation.get(
        '/api/script-jobs/script-job-1',
        _scriptJobJson(status: 'succeeded', result: _scriptDraftJson()),
      ),
      _Expectation.post(
        '/api/projects/project-1/generation-plans',
        requestBody: const {
          'scriptJobId': 'script-job-1',
          'providerStrategy': 'automatic',
          'shotIds': ['shot-1'],
          'regenerateExisting': false,
        },
        responseBody: {..._planJson(), 'providerStrategy': 'BAILIAN'},
        responseEtag: _planEtag,
        expectedEtag: _projectEtag,
        expectedIdempotencyKey: _planIntentKey,
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.startGeneration(
        projectId: 'project-1',
        etag: _projectEtag,
        shotIds: const ['shot-1'],
        idempotencyKey: _intentKey,
      ),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });

  test('weak ETag is rejected instead of being reused for mutation', () async {
    final harness = await _Harness.start([
      _Expectation.get(
        '/api/projects/project-1',
        _projectJson(),
        responseEtag: 'W/"project-rev-7"',
      ),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.refreshProject('project-1'),
      throwsA(isA<ApiContractException>()),
    );
  });

  test('response bodies over the safety limit are rejected', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects?limit=100', {
        'items': const <Object?>[],
        'padding': List.filled(2100000, 'x').join(),
      }),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.listProjects(),
      throwsA(isA<ApiContractException>()),
    );
  });

  test('pagination rejects item totals over the safety limit', () async {
    final harness = await _Harness.start([
      _Expectation.get('/api/projects?limit=100', {
        'items': List<Object?>.filled(
          HttpStudioRepository.maxPaginationItems + 1,
          _projectJson(),
        ),
      }),
    ]);
    addTearDown(harness.close);
    final repository = harness.repository();
    addTearDown(() => repository.close(force: true));

    await expectLater(
      repository.listProjects(),
      throwsA(isA<ApiContractException>()),
    );
    await harness.done;
  });
}

Map<String, Object?> _projectJson({
  String? latestScriptJobId,
  String? activeRunId,
  String? latestExportId,
}) => {
  'id': 'project-1',
  'name': '星幕计划',
  'description': '雨夜天台发生了一场秘密相遇',
  'aspectRatio': '9:16',
  'coverAssetId': null,
  'latestScriptJobId': latestScriptJobId,
  'activeRunId': activeRunId,
  'latestExportId': latestExportId,
  'revision': 7,
  'createdAt': '2026-08-20T08:00:00Z',
  'updatedAt': '2026-08-20T08:01:00Z',
};

Map<String, Object?> _scriptJobJson({
  required String status,
  required Map<String, Object?>? result,
}) => {
  'id': 'script-job-1',
  'projectId': 'project-1',
  'status': status,
  'progress': status == 'succeeded' ? 100 : 0,
  'result': result,
  'error': null,
  'createdAt': '2026-08-20T08:02:00Z',
  'updatedAt': '2026-08-20T08:03:00Z',
};

Map<String, Object?> _scriptDraftJson() => {
  'title': '雨夜来客',
  'logline': '一场相遇改变了明天',
  'styleBible': '电影级二维漫剧',
  'characters': [
    {'id': 'character-1', 'name': '小满', 'lock': '短黑发，蓝色外套'},
  ],
  'props': const <Object?>[],
  'scenes': [
    {'id': 'scene-1', 'name': '天台', 'lock': '蓝紫霓虹雨夜'},
  ],
  'episodes': [
    {
      'id': 'episode-1',
      'title': '第一集',
      'shots': [
        {
          'id': 'shot-1',
          'sceneId': 'scene-1',
          'characterIds': ['character-1'],
          'visualPrompt': '主角走上雨夜天台',
          'motionPrompt': '镜头缓慢推进',
          'dialogue': '你终于来了。',
          'durationSeconds': 6,
        },
        {
          'id': 'shot-2',
          'sceneId': 'scene-1',
          'characterIds': ['character-1'],
          'visualPrompt': '主角望向远处亮起的灯塔',
          'motionPrompt': '镜头缓慢拉远',
          'dialogue': '',
          'durationSeconds': 5,
        },
      ],
    },
  ],
};

Map<String, Object?> _planJson() => {
  'id': 'plan-1',
  'projectId': 'project-1',
  'scriptJobId': 'script-job-1',
  'providerStrategy': 'automatic',
  'shotIds': ['shot-1'],
  'referenceAssetIds': const <Object?>[],
  'estimatedCost': null,
  'revision': 2,
  'createdAt': '2026-08-20T08:04:00Z',
};

Map<String, Object?> _runJson({String status = 'running', int revision = 3}) =>
    {
      'id': 'run-1',
      'planId': 'plan-1',
      'projectId': 'project-1',
      'status': status,
      'progress': 20,
      'completedJobs': 1,
      'totalJobs': 5,
      'currentStage': 'character_images',
      'reservedCost': {'currency': 'CNY', 'amount': '2.0000'},
      'consumedCost': {'currency': 'CNY', 'amount': '0.4000'},
      'revision': revision,
      'createdAt': '2026-08-20T08:05:00Z',
      'updatedAt': '2026-08-20T08:06:00Z',
    };

Map<String, Object?> _jobJson({
  required String status,
  String stage = 'shot_videos',
  int revision = 4,
}) => {
  'id': 'job-1',
  'runId': 'run-1',
  'stage': stage,
  'shotId': 'shot-1',
  'status': status,
  'progress': status == 'succeeded' ? 100 : 20,
  'attempt': 1,
  'outputAssetIds': const <Object?>[],
  'error': status == 'failed'
      ? {'code': 'provider_error', 'message': '供应商暂时失败', 'retryable': true}
      : null,
  'revision': revision,
  'createdAt': '2026-08-20T08:05:00Z',
  'updatedAt': '2026-08-20T08:06:00Z',
};

Map<String, Object?> _exportJson() => {
  'id': 'export-1',
  'projectId': 'project-1',
  'runId': 'run-1',
  'status': 'succeeded',
  'progress': 100,
  'assetId': 'asset-export-1',
  'durationSeconds': 19,
  'error': null,
  'revision': 2,
  'createdAt': '2026-08-20T08:07:00Z',
  'updatedAt': '2026-08-20T08:08:00Z',
};

Map<String, Object?> _assetJson() => {
  'id': 'asset-export-1',
  'projectId': 'project-1',
  'kind': 'export',
  'status': 'ready',
  'contentType': 'video/mp4',
  'sizeBytes': 2048,
  'width': 720,
  'height': 1280,
  'durationSeconds': 19,
  'previewUrl': 'https://preview.test/export-1.mp4',
  'previewExpiresAt': '2026-08-20T09:00:00Z',
  'revision': 2,
  'createdAt': '2026-08-20T08:07:00Z',
};

class _Expectation {
  const _Expectation({
    required this.method,
    required this.target,
    required this.responseBody,
    this.requestBody,
    this.responseEtag,
    this.expectedEtag,
    this.expectedIdempotencyKey,
    this.statusCode = 200,
    this.contentType = 'application/json',
    this.disconnectAfterRequest = false,
  });

  factory _Expectation.get(
    String target,
    Object? responseBody, {
    String? responseEtag,
    int statusCode = 200,
    String contentType = 'application/json',
  }) => _Expectation(
    method: 'GET',
    target: target,
    responseBody: responseBody,
    responseEtag: responseEtag,
    statusCode: statusCode,
    contentType: contentType,
  );

  factory _Expectation.post(
    String target, {
    required Object? requestBody,
    required Object? responseBody,
    String? responseEtag,
    String? expectedEtag,
    String? expectedIdempotencyKey,
    int statusCode = 200,
    bool disconnectAfterRequest = false,
  }) => _Expectation(
    method: 'POST',
    target: target,
    requestBody: requestBody,
    responseBody: responseBody,
    responseEtag: responseEtag,
    expectedEtag: expectedEtag,
    expectedIdempotencyKey: expectedIdempotencyKey,
    statusCode: statusCode,
    disconnectAfterRequest: disconnectAfterRequest,
  );

  final String method;
  final String target;
  final Object? requestBody;
  final Object? responseBody;
  final String? responseEtag;
  final String? expectedEtag;
  final String? expectedIdempotencyKey;
  final int statusCode;
  final String contentType;
  final bool disconnectAfterRequest;
}

class _Harness {
  _Harness._(this.server, List<_Expectation> expectations)
    : _expectations = expectations;

  final HttpServer server;
  final List<_Expectation> _expectations;
  final Completer<void> _done = Completer<void>();
  StreamSubscription<HttpRequest>? _subscription;

  static Future<_Harness> start(List<_Expectation> expectations) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _Harness._(server, [...expectations]);
    harness._subscription = server.listen(harness._handle);
    return harness;
  }

  Future<void> get done => _done.future;

  HttpStudioRepository repository() => HttpStudioRepository(
    baseUri: Uri.parse('http://${server.address.address}:${server.port}/api/'),
    accessTokenProvider: () async => 'token-123',
    allowInsecureTransport: true,
  );

  Future<void> _handle(HttpRequest request) async {
    Object? failure;
    StackTrace? failureStack;
    var responseDetached = false;
    try {
      if (_expectations.isEmpty) {
        throw TestFailure('收到未预期请求：${request.method} ${request.uri}');
      }
      final expected = _expectations.removeAt(0);
      final target = request.uri.hasQuery
          ? '${request.uri.path}?${request.uri.query}'
          : request.uri.path;
      expect(request.method, expected.method);
      expect(target, expected.target);
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer token-123',
      );
      if (expected.expectedEtag != null) {
        expect(
          request.headers.value(HttpHeaders.ifMatchHeader),
          expected.expectedEtag,
        );
      }
      if (expected.expectedIdempotencyKey != null) {
        expect(
          request.headers.value('Idempotency-Key'),
          expected.expectedIdempotencyKey,
        );
      }
      final rawBody = await utf8.decoder.bind(request).join();
      if (expected.requestBody != null) {
        expect(jsonDecode(rawBody), expected.requestBody);
      } else {
        expect(rawBody, isEmpty);
      }
      if (expected.disconnectAfterRequest) {
        final socket = await request.response.detachSocket(writeHeaders: false);
        responseDetached = true;
        socket.destroy();
        return;
      }
      request.response.statusCode = expected.statusCode;
      request.response.headers.contentType = ContentType.parse(
        expected.contentType,
      );
      if (expected.responseEtag != null) {
        request.response.headers.set(
          HttpHeaders.etagHeader,
          expected.responseEtag!,
        );
      }
      if (expected.responseBody != null) {
        request.response.add(utf8.encode(jsonEncode(expected.responseBody)));
      }
    } catch (error, stackTrace) {
      failure = error;
      failureStack = stackTrace;
      request.response.statusCode = 500;
      request.response.add(utf8.encode('expectation failed: $error'));
    } finally {
      if (!responseDetached) await request.response.close();
      if (failure != null && !_done.isCompleted) {
        _done.completeError(failure, failureStack);
      } else if (_expectations.isEmpty && !_done.isCompleted) {
        _done.complete();
      }
    }
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await server.close(force: true);
  }
}
