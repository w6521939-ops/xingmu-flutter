import '../data/demo/demo_studio_repository.dart';
import '../data/remote/http_studio_repository.dart';
import '../domain/studio_repository.dart';

class StudioConfigurationException implements Exception {
  const StudioConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StudioBootstrap {
  const StudioBootstrap({
    this.demoMode = const bool.fromEnvironment('DEMO_MODE', defaultValue: true),
    this.apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
    this.allowInsecureTransport = const bool.fromEnvironment(
      'ALLOW_INSECURE_TRANSPORT',
      defaultValue: false,
    ),
  });

  final bool demoMode;
  final String apiBaseUrl;
  final bool allowInsecureTransport;

  StudioRepository createRepository({
    AccessTokenProvider? accessTokenProvider,
  }) {
    if (demoMode) return DemoStudioRepository();
    final rawUrl = apiBaseUrl.trim();
    if (rawUrl.isEmpty) {
      throw const StudioConfigurationException(
        '真实模式缺少 API_BASE_URL，请通过 --dart-define 配置可信后端地址',
      );
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const StudioConfigurationException(
        'API_BASE_URL 必须是完整的 HTTP(S) 地址',
      );
    }
    return HttpStudioRepository(
      baseUri: uri,
      accessTokenProvider: accessTokenProvider ?? () async => null,
      allowInsecureTransport: allowInsecureTransport,
    );
  }
}
