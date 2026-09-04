import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../voice_sync/domain/subtitle_sync.dart';
import '../domain/multi_track_models.dart';

class MultiTrackController extends ChangeNotifier {
  MultiTrackController({GpuCapability? gpuCapability})
    : _gpuCapability = gpuCapability ?? _detectGpuCapability();

  final GpuCapability _gpuCapability;
  final List<AudioTrackConfig> _tracks = [];
  final Map<String, List<TrackEffect>> _trackEffects = {};
  MultiTrackMixPlan? _mixPlan;
  GpuRenderConfig _renderConfig = const GpuRenderConfig();
  RenderProgress _renderProgress = const RenderProgress();
  Timer? _progressTimer;
  bool _disposed = false;

  GpuCapability get gpuCapability => _gpuCapability;
  List<AudioTrackConfig> get tracks => List.unmodifiable(_tracks);
  MultiTrackMixPlan? get mixPlan => _mixPlan;
  GpuRenderConfig get renderConfig => _renderConfig;
  RenderProgress get renderProgress => _renderProgress;
  double get masterVolume => _mixPlan?.masterVolume ?? 1.0;
  bool get hasTracks => _tracks.isNotEmpty;
  bool get isRendering => _renderProgress.status.isActive;
  bool get hasGpuAcceleration => _gpuCapability.hasGpuAcceleration;

  Duration get totalDuration {
    if (_mixPlan != null) return _mixPlan!.totalDuration;
    if (_tracks.isEmpty) return Duration.zero;
    var maxEnd = Duration.zero;
    for (final track in _tracks) {
      final lines = _trackLines[track.id];
      if (lines != null && lines.isNotEmpty) {
        final last = lines.last;
        final end = last.endTimestamp + last.pauseAfter + track.fadeOut;
        if (end > maxEnd) maxEnd = end;
      }
    }
    return maxEnd;
  }

  final Map<String, List<SubtitleLine>> _trackLines = {};

  void loadFromTimeline(VoiceTimeline timeline) {
    _tracks.clear();
    _trackLines.clear();
    _trackEffects.clear();

    for (final track in timeline.tracks) {
      final config = AudioTrackConfig.fromVoiceTrack(track);
      _tracks.add(config);
      _trackLines[config.id] = List.of(track.lines);
      _trackEffects[config.id] = [];
    }

    _rebuildMixPlan();
    notifyListeners();
  }

  void addTrack({
    required VoiceTrackType type,
    String? name,
    String? audioUrl,
    List<SubtitleLine>? lines,
  }) {
    final trackName = name ?? switch (type) {
      VoiceTrackType.narration => '旁白轨 ${_tracks.length + 1}',
      VoiceTrackType.dialogue => '对白轨 ${_tracks.length + 1}',
      VoiceTrackType.soundEffect => '音效轨 ${_tracks.length + 1}',
      VoiceTrackType.bgm => '背景音乐轨 ${_tracks.length + 1}',
    };
    final track = AudioTrackConfig(
      id: 'track-${type.name}-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      name: trackName,
      audioUrl: audioUrl,
      color: _colorForType(type),
    );
    _tracks.add(track);
    _trackLines[track.id] = lines ?? [];
    _trackEffects[track.id] = [];
    _rebuildMixPlan();
    notifyListeners();
  }

  void updateTrack(String trackId, AudioTrackConfig Function(AudioTrackConfig) updater) {
    final idx = _tracks.indexWhere((t) => t.id == trackId);
    if (idx < 0) return;
    _tracks[idx] = updater(_tracks[idx]);
    _rebuildMixPlan();
    notifyListeners();
  }

  void removeTrack(String trackId) {
    _tracks.removeWhere((t) => t.id == trackId);
    _trackLines.remove(trackId);
    _trackEffects.remove(trackId);
    _rebuildMixPlan();
    notifyListeners();
  }

  void setTrackVolume(String trackId, double volume) {
    updateTrack(trackId, (t) => t.copyWith(volume: volume));
  }

  void setTrackPan(String trackId, double pan) {
    updateTrack(trackId, (t) => t.copyWith(pan: pan));
  }

  void toggleMute(String trackId) {
    updateTrack(trackId, (t) => t.copyWith(muted: !t.muted));
  }

  void toggleSolo(String trackId) {
    final track = _tracks.firstWhere((t) => t.id == trackId);
    updateTrack(trackId, (t) => t.copyWith(solo: !track.solo));
  }

  void setTrackFadeIn(String trackId, Duration duration) {
    updateTrack(trackId, (t) => t.copyWith(fadeIn: duration));
  }

  void setTrackFadeOut(String trackId, Duration duration) {
    updateTrack(trackId, (t) => t.copyWith(fadeOut: duration));
  }

  void addEffect(String trackId, TrackEffect effect) {
    _trackEffects[trackId] ??= [];
    _trackEffects[trackId]!.add(effect);
    final idx = _tracks.indexWhere((t) => t.id == trackId);
    if (idx >= 0) {
      _tracks[idx] = _tracks[idx].copyWith(effects: _trackEffects[trackId]);
    }
    notifyListeners();
  }

  void toggleEffect(String trackId, int effectIndex) {
    final effects = _trackEffects[trackId];
    if (effects == null || effectIndex >= effects.length) return;
    final e = effects[effectIndex];
    effects[effectIndex] = e.copyWith(enabled: !e.enabled);
    final idx = _tracks.indexWhere((t) => t.id == trackId);
    if (idx >= 0) {
      _tracks[idx] = _tracks[idx].copyWith(effects: List.of(effects));
    }
    notifyListeners();
  }

  void removeEffect(String trackId, int effectIndex) {
    final effects = _trackEffects[trackId];
    if (effects == null || effectIndex >= effects.length) return;
    effects.removeAt(effectIndex);
    final idx = _tracks.indexWhere((t) => t.id == trackId);
    if (idx >= 0) {
      _tracks[idx] = _tracks[idx].copyWith(effects: List.of(effects));
    }
    notifyListeners();
  }

  List<SubtitleLine>? getTrackLines(String trackId) =>
      _trackLines[trackId];

  void setMasterVolume(double volume) {
    if (_mixPlan == null) return;
    _mixPlan = _mixPlan!.copyWith(masterVolume: volume);
    notifyListeners();
  }

  void updateRenderConfig(GpuRenderConfig Function(GpuRenderConfig) updater) {
    _renderConfig = updater(_renderConfig);
    notifyListeners();
  }

  void setEncoder(GpuEncoder encoder) {
    updateRenderConfig((c) => c.copyWith(encoder: encoder));
  }

  void setPreset(GpuRenderPreset preset) {
    updateRenderConfig((c) => c.copyWith(preset: preset));
  }

  RenderProgress startRender({String? outputPath}) {
    if (_tracks.isEmpty) {
      _renderProgress = const RenderProgress(
        status: RenderStatus.failed,
        errorMessage: '没有可渲染的音频轨道',
      );
      notifyListeners();
      return _renderProgress;
    }

    _progressTimer?.cancel();
    _renderProgress = RenderProgress(
      status: RenderStatus.preparing,
      outputPath: outputPath,
      totalFrames: _estimateTotalFrames(),
    );
    notifyListeners();

    _simulateRenderProgress();
    return _renderProgress;
  }

  void cancelRender() {
    _progressTimer?.cancel();
    _renderProgress = _renderProgress.copyWith(status: RenderStatus.cancelled);
    notifyListeners();
  }

  void _simulateRenderProgress() {
    final total = _renderProgress.totalFrames;
    if (total == 0) return;

    var currentFrame = 0;
    final startTime = DateTime.now();
    final fps = _renderConfig.encoder.isGpu ? 120.0 : 45.0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      currentFrame += (fps * 0.1).round();
      if (currentFrame >= total) {
        currentFrame = total;
        timer.cancel();
        _renderProgress = _renderProgress.copyWith(
          status: RenderStatus.muxing,
          progress: 0.95,
          currentFrame: currentFrame,
        );
        notifyListeners();

        Future.delayed(const Duration(seconds: 1), () {
          if (_disposed) return;
          _renderProgress = _renderProgress.copyWith(
            status: RenderStatus.succeeded,
            progress: 1.0,
            currentFrame: total,
            elapsedTime: DateTime.now().difference(startTime),
            estimatedRemaining: Duration.zero,
            fps: fps,
          );
          notifyListeners();
        });
        return;
      }

      final progress = currentFrame / total;
      final elapsed = DateTime.now().difference(startTime);
      final remainingFrames = total - currentFrame;
      final estimatedRemaining = Duration(
        milliseconds: (remainingFrames / fps * 1000).round(),
      );

      _renderProgress = _renderProgress.copyWith(
        status: RenderStatus.rendering,
        progress: progress,
        currentFrame: currentFrame,
        elapsedTime: elapsed,
        estimatedRemaining: estimatedRemaining,
        fps: fps,
      );
      notifyListeners();
    });
  }

  int _estimateTotalFrames() {
    final durationSec = totalDuration.inMilliseconds / 1000.0;
    return (durationSec * _renderConfig.fps).ceil();
  }

  Map<String, dynamic> buildRenderCommand({required String inputPath, required String outputPath}) {
    final mixArgs = _mixPlan?.toJson() ?? {};
    final renderArgs = _renderConfig.toCommandArgs();

    return {
      'input': inputPath,
      'output': outputPath,
      'mix_plan': mixArgs,
      'render_config': renderArgs,
      'command': [
        'ffmpeg',
        '-i', inputPath,
        ...renderArgs['args'] as List,
        '-c:a', 'aac',
        '-b:a', '192k',
        outputPath,
      ],
    };
  }

  void _rebuildMixPlan() {
    if (_tracks.isEmpty) {
      _mixPlan = null;
      return;
    }
    _mixPlan = MultiTrackMixPlan(tracks: List.of(_tracks));
  }

  int _colorForType(VoiceTrackType type) => switch (type) {
    VoiceTrackType.narration => 0xFF39D7F5,
    VoiceTrackType.dialogue => 0xFF765CFF,
    VoiceTrackType.soundEffect => 0xFFFFB74D,
    VoiceTrackType.bgm => 0xFF66BB6A,
  };

  static GpuCapability _detectGpuCapability() {
    if (kIsWeb) return GpuCapability.fallback();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return const GpuCapability(
        vendor: 'NVIDIA',
        deviceName: 'Detected GPU (NVENC)',
        encoders: [GpuEncoder.h264Nvenc, GpuEncoder.h265Nvenc],
        vramMb: 8192,
        cudaCores: 3072,
        computeCapability: '8.6',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return GpuCapability.apple(deviceName: 'Apple GPU (VideoToolbox)');
    }
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.fuchsia) {
      return const GpuCapability(
        vendor: 'ARM',
        deviceName: 'Mobile GPU',
        encoders: [GpuEncoder.software264, GpuEncoder.software265],
      );
    }
    return GpuCapability.fallback();
  }

  @override
  void dispose() {
    _disposed = true;
    _progressTimer?.cancel();
    super.dispose();
  }
}
