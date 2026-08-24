import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

typedef Mp4PlaybackControllerFactory = Mp4PlaybackController Function(Uri uri);

class Mp4PlaybackValue {
  const Mp4PlaybackValue({
    required this.isInitialized,
    required this.isPlaying,
    required this.hasError,
    required this.duration,
    required this.position,
    required this.aspectRatio,
    this.errorDescription,
  });

  final bool isInitialized;
  final bool isPlaying;
  final bool hasError;
  final Duration duration;
  final Duration position;
  final double aspectRatio;
  final String? errorDescription;
}

abstract interface class Mp4PlaybackController {
  Mp4PlaybackValue get value;

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);

  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Widget buildVideo();

  Future<void> dispose();
}

class VideoPlayerMp4Controller implements Mp4PlaybackController {
  VideoPlayerMp4Controller(Uri uri)
    : _delegate = VideoPlayerController.networkUrl(uri);

  final VideoPlayerController _delegate;

  @override
  Mp4PlaybackValue get value {
    final current = _delegate.value;
    final aspectRatio = current.aspectRatio;
    return Mp4PlaybackValue(
      isInitialized: current.isInitialized,
      isPlaying: current.isPlaying,
      hasError: current.hasError,
      duration: current.duration,
      position: current.position,
      aspectRatio: aspectRatio.isFinite && aspectRatio > 0
          ? aspectRatio
          : 9 / 16,
      errorDescription: current.errorDescription,
    );
  }

  @override
  void addListener(VoidCallback listener) => _delegate.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _delegate.removeListener(listener);

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Future<void> play() => _delegate.play();

  @override
  Future<void> pause() => _delegate.pause();

  @override
  Future<void> seekTo(Duration position) => _delegate.seekTo(position);

  @override
  Widget buildVideo() => VideoPlayer(_delegate);

  @override
  Future<void> dispose() => _delegate.dispose();
}

class Mp4PlayerPage extends StatefulWidget {
  const Mp4PlayerPage({
    required this.videoUrl,
    super.key,
    this.title = 'MP4 视频播放',
    this.controllerFactory,
  });

  final Uri videoUrl;
  final String title;
  final Mp4PlaybackControllerFactory? controllerFactory;

  @override
  State<Mp4PlayerPage> createState() => _Mp4PlayerPageState();
}

class _Mp4PlayerPageState extends State<Mp4PlayerPage>
    with WidgetsBindingObserver {
  late final Mp4PlaybackController _controller;
  bool _initializing = true;
  Object? _initializationError;
  Duration? _dragPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = (widget.controllerFactory ?? VideoPlayerMp4Controller.new)(
      widget.videoUrl,
    );
    _controller.addListener(_onControllerChanged);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
    } catch (error) {
      _initializationError = error;
    }
    if (!mounted) return;
    setState(() => _initializing = false);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _controller.value.isPlaying) {
      unawaited(_controller.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    final error =
        _initializationError ??
        (value.hasError ? value.errorDescription ?? '视频播放器初始化失败' : null);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: error != null
                      ? _PlayerError(message: error.toString())
                      : _initializing || !value.isInitialized
                      ? const _PlayerLoading()
                      : _PlayerSurface(
                          controller: _controller,
                          aspectRatio: value.aspectRatio,
                        ),
                ),
              ),
              if (error == null && value.isInitialized) ...[
                const SizedBox(height: 16),
                _PlaybackControls(
                  value: value,
                  dragPosition: _dragPosition,
                  onPlayPause: _togglePlayback,
                  onReplay: _replay,
                  onDragChanged: (position) =>
                      setState(() => _dragPosition = position),
                  onDragEnded: _seekFromDrag,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                widget.videoUrl.toString(),
                key: const ValueKey('mp4-player-url'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePlayback() async {
    final value = _controller.value;
    if (value.isPlaying) {
      await _controller.pause();
      return;
    }
    if (_isCompleted(value)) await _controller.seekTo(Duration.zero);
    await _controller.play();
  }

  Future<void> _replay() async {
    await _controller.seekTo(Duration.zero);
    await _controller.play();
  }

  Future<void> _seekFromDrag(Duration position) async {
    await _controller.seekTo(position);
    if (!mounted) return;
    setState(() => _dragPosition = null);
  }
}

class _PlayerLoading extends StatelessWidget {
  const _PlayerLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: ValueKey('mp4-player-loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 14),
        Text('正在加载 MP4，不会自动播放…'),
      ],
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('mp4-player-error'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        const Text('MP4 加载失败'),
        const SizedBox(height: 7),
        Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}

class _PlayerSurface extends StatelessWidget {
  const _PlayerSurface({required this.controller, required this.aspectRatio});

  final Mp4PlaybackController controller;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ColoredBox(
            key: const ValueKey('mp4-player-surface'),
            color: Colors.black,
            child: controller.buildVideo(),
          ),
        ),
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.value,
    required this.dragPosition,
    required this.onPlayPause,
    required this.onReplay,
    required this.onDragChanged,
    required this.onDragEnded,
  });

  final Mp4PlaybackValue value;
  final Duration? dragPosition;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onReplay;
  final ValueChanged<Duration> onDragChanged;
  final ValueChanged<Duration> onDragEnded;

  @override
  Widget build(BuildContext context) {
    final durationMilliseconds = value.duration.inMilliseconds < 1
        ? 1
        : value.duration.inMilliseconds;
    final shownPosition = dragPosition ?? value.position;
    final positionMilliseconds = shownPosition.inMilliseconds
        .clamp(0, durationMilliseconds)
        .toDouble();
    final completed = _isCompleted(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Slider(
          key: const ValueKey('mp4-seek-slider'),
          value: positionMilliseconds,
          max: durationMilliseconds.toDouble(),
          onChanged: (milliseconds) =>
              onDragChanged(Duration(milliseconds: milliseconds.round())),
          onChangeEnd: (milliseconds) =>
              onDragEnded(Duration(milliseconds: milliseconds.round())),
        ),
        Text(
          '${_formatDuration(shownPosition)} / ${_formatDuration(value.duration)}',
          key: const ValueKey('mp4-time-label'),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('mp4-replay'),
              onPressed: onReplay,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('重播'),
            ),
            FilledButton.icon(
              key: const ValueKey('mp4-play-pause'),
              onPressed: onPlayPause,
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_rounded
                    : completed
                    ? Icons.replay_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                value.isPlaying
                    ? '暂停'
                    : completed
                    ? '重新播放'
                    : '播放',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

bool _isCompleted(Mp4PlaybackValue value) =>
    value.duration > Duration.zero && value.position >= value.duration;

String _formatDuration(Duration value) {
  final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final minuteText = hours > 0
      ? minutes.toString().padLeft(2, '0')
      : minutes.toString();
  final secondText = seconds.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:$minuteText:$secondText'
      : '$minuteText:$secondText';
}
