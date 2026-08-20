import 'studio_models.dart';

abstract interface class StudioRepository {
  Future<List<StudioProject>> listProjects();

  Future<StudioProject> createProject({
    required String theme,
    String? title,
    String? idempotencyKey,
  });

  Future<StudioProject> adoptScript({
    required String projectId,
    required String etag,
    required String sourceText,
    ScriptSummary? script,
    String? idempotencyKey,
  });

  Future<StudioProject> startGeneration({
    required String projectId,
    required String etag,
    bool onlyMissing = true,
    List<String>? shotIds,
    String? idempotencyKey,
  });

  Future<StudioProject> pauseGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  });

  Future<StudioProject> resumeGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  });

  Future<StudioProject> cancelGeneration({
    required String projectId,
    required String runId,
    required String runEtag,
    String? idempotencyKey,
  });

  Future<StudioProject> retryFailedTasks({
    required String projectId,
    required String runId,
    String? idempotencyKey,
  });

  Future<StudioProject> retryTask({
    required String projectId,
    required String runId,
    required String taskId,
    String? idempotencyKey,
  });

  Future<StudioProject> refreshProject(String projectId);
}

abstract interface class DemoStudioDriver {
  Future<StudioProject> advanceDemo(String projectId);
}
