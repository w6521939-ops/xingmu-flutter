import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/features/video_lab/video_lab.dart';

void main() {
  testWidgets(
    'MP4 player loads on demand without autoplay and supports every control',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final initialization = Completer<void>();
      final controller = _FakeMp4PlaybackController(
        initialization: initialization.future,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Mp4PlayerPage(
            videoUrl: Uri.parse('https://media.example/shot-1.mp4'),
            controllerFactory: (_) => controller,
          ),
        ),
      );

      expect(controller.initializeCalls, 1);
      expect(controller.playCalls, 0);
      expect(find.byKey(const ValueKey('mp4-player-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('mp4-player-surface')), findsNothing);

      initialization.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mp4-player-surface')), findsOneWidget);
      expect(find.byKey(const ValueKey('fake-mp4-video')), findsOneWidget);
      expect(find.text('0:00 / 0:09'), findsOneWidget);
      expect(controller.playCalls, 0);

      await tester.tap(find.byKey(const ValueKey('mp4-play-pause')));
      await tester.pump();
      expect(controller.playCalls, 1);
      expect(find.text('暂停'), findsOneWidget);

      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('mp4-seek-slider')),
      );
      slider.onChanged!(4500);
      await tester.pump();
      expect(find.text('0:04 / 0:09'), findsOneWidget);
      slider.onChangeEnd!(4500);
      await tester.pump();
      expect(controller.seekCalls.last, const Duration(milliseconds: 4500));

      await tester.tap(find.byKey(const ValueKey('mp4-play-pause')));
      await tester.pump();
      expect(controller.pauseCalls, 1);
      expect(find.text('播放'), findsOneWidget);

      controller.setPlayback(
        position: const Duration(seconds: 9),
        isPlaying: false,
      );
      await tester.pump();
      expect(find.text('重新播放'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mp4-replay')));
      await tester.pump();
      expect(controller.seekCalls.last, Duration.zero);
      expect(controller.playCalls, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(controller.pauseCalls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(controller.disposeCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('MP4 player exposes initialization failures', (tester) async {
    final controller = _FakeMp4PlaybackController(
      initializationError: StateError('视频网络连接失败'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Mp4PlayerPage(
          videoUrl: Uri.parse('https://media.example/broken.mp4'),
          controllerFactory: (_) => controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mp4-player-error')), findsOneWidget);
    expect(find.text('MP4 加载失败'), findsOneWidget);
    expect(find.textContaining('视频网络连接失败'), findsOneWidget);
    expect(find.byKey(const ValueKey('mp4-play-pause')), findsNothing);
    expect(controller.playCalls, 0);
    expect(tester.takeException(), isNull);
  });
}

class _FakeMp4PlaybackController implements Mp4PlaybackController {
  _FakeMp4PlaybackController({this.initialization, this.initializationError});

  final Future<void>? initialization;
  final Object? initializationError;
  final List<VoidCallback> _listeners = [];
  final List<Duration> seekCalls = [];
  int initializeCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
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
    if (initializationError case final error?) throw error;
    await initialization;
    _value = const Mp4PlaybackValue(
      isInitialized: true,
      isPlaying: false,
      hasError: false,
      duration: Duration(seconds: 9),
      position: Duration.zero,
      aspectRatio: 16 / 9,
    );
    _notify();
  }

  @override
  Future<void> play() async {
    playCalls++;
    setPlayback(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    setPlayback(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    seekCalls.add(position);
    setPlayback(position: position);
  }

  void setPlayback({Duration? position, bool? isPlaying}) {
    _value = Mp4PlaybackValue(
      isInitialized: _value.isInitialized,
      isPlaying: isPlaying ?? _value.isPlaying,
      hasError: _value.hasError,
      duration: _value.duration,
      position: position ?? _value.position,
      aspectRatio: _value.aspectRatio,
      errorDescription: _value.errorDescription,
    );
    _notify();
  }

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  @override
  Widget buildVideo() =>
      const ColoredBox(key: ValueKey('fake-mp4-video'), color: Colors.black);

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
