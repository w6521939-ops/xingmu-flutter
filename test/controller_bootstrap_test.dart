import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/application/application.dart';
import 'package:xingmu_ai_video_studio/data/data.dart';

void main() {
  test('demo mode is the safe default', () {
    final repository = const StudioBootstrap().createRepository();
    expect(repository, isA<DemoStudioRepository>());
  });

  test('real mode never falls back when API_BASE_URL is missing', () {
    expect(
      () => const StudioBootstrap(
        demoMode: false,
        apiBaseUrl: '',
      ).createRepository(),
      throwsA(isA<StudioConfigurationException>()),
    );
  });
}
