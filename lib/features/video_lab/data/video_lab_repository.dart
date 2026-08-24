import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/video_lab_models.dart';

abstract interface class VideoLabRepository {
  Future<VideoLabCatalog> fetchCatalog();

  Future<VideoLabJob> createJob({
    required String story,
    required String textModelId,
    required String imageModelId,
    required String videoModelId,
    required String voiceModelId,
  });

  Future<VideoLabJob> fetchJob(String id);

  void close();
}

class VideoLabApiException implements Exception {
  const VideoLabApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HttpVideoLabRepository implements VideoLabRepository {
  HttpVideoLabRepository({
    required this.baseUri,
    this.allowInsecureTransport = false,
    HttpClient? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? HttpClient() {
    if (!baseUri.hasScheme || !baseUri.hasAuthority) {
      throw ArgumentError.value(baseUri, 'baseUri', '必须是完整的 HTTP(S) 地址');
    }
    if (baseUri.scheme != 'https' &&
        !(allowInsecureTransport && baseUri.scheme == 'http')) {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        '非 HTTPS 地址只允许在显式启用的本地开发环境使用',
      );
    }
  }

  final Uri baseUri;
  final bool allowInsecureTransport;
  final Duration timeout;
  final HttpClient _client;

  @override
  Future<VideoLabCatalog> fetchCatalog() async {
    final json = await _requestJson('GET', _resolve('model-catalog'));
    return VideoLabCatalog.fromJson(json);
  }

  @override
  Future<VideoLabJob> createJob({
    required String story,
    required String textModelId,
    required String imageModelId,
    required String videoModelId,
    required String voiceModelId,
  }) async {
    final json = await _requestJson(
      'POST',
      _resolve('comic-jobs'),
      body: {
        'story': story,
        'textModelId': textModelId,
        'imageModelId': imageModelId,
        'videoModelId': videoModelId,
        'voiceModelId': voiceModelId,
        'aspectRatio': '9:16',
        'shotCount': 3,
        'shotDurationSeconds': 3,
      },
    );
    return VideoLabJob.fromJson(json, baseUri);
  }

  @override
  Future<VideoLabJob> fetchJob(String id) async {
    if (id.trim().isEmpty || !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id)) {
      throw const VideoLabApiException('任务 ID 格式无效');
    }
    final json = await _requestJson(
      'GET',
      _resolve('comic-jobs/${Uri.encodeComponent(id)}'),
    );
    return VideoLabJob.fromJson(json, baseUri);
  }

  Uri _resolve(String relative) {
    final root = baseUri.path.endsWith('/')
        ? baseUri
        : baseUri.replace(path: '${baseUri.path}/');
    return root.resolve(relative);
  }

  Future<Object?> _requestJson(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    try {
      final encodedBody = body == null ? null : utf8.encode(jsonEncode(body));
      final request = await _client.openUrl(method, uri).timeout(timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, 'xingmu-ai-video-studio/0.1');
      if (encodedBody != null) {
        request.headers.contentType = ContentType.json;
        request.contentLength = encodedBody.length;
        request.add(encodedBody);
      }
      final response = await request.close().timeout(timeout);
      final bytes = <int>[];
      await response.timeout(timeout).forEach((chunk) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const VideoLabApiException('服务端响应超过 2 MiB 限制');
        }
        bytes.addAll(chunk);
      });
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } on FormatException {
        throw VideoLabApiException(
          '服务端返回了无效 JSON',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map && decoded['message'] is String
            ? decoded['message'] as String
            : '请求失败 (${response.statusCode})';
        throw VideoLabApiException(message, statusCode: response.statusCode);
      }
      return decoded;
    } on VideoLabApiException {
      rethrow;
    } on TimeoutException {
      throw const VideoLabApiException('连接漫剧生成服务超时');
    } on SocketException {
      throw const VideoLabApiException('无法连接漫剧生成服务');
    } on HttpException {
      throw const VideoLabApiException('漫剧生成服务 HTTP 通信失败');
    }
  }

  @override
  void close() => _client.close(force: true);
}
