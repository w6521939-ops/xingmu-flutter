import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/features/multi_track_voice/domain/multi_track_models.dart';
import 'package:xingmu_ai_video_studio/features/voice_sync/domain/subtitle_sync.dart';

void main() {
  group('AudioTrackConfig', () {
    test('default values', () {
      final track = AudioTrackConfig(
        id: 'track-001',
        type: VoiceTrackType.narration,
        name: '旁白轨',
      );

      expect(track.volume, 1.0);
      expect(track.pan, 0.0);
      expect(track.muted, isFalse);
      expect(track.solo, isFalse);
      expect(track.effects, isEmpty);
      expect(track.isAudible, isTrue);
    });

    test('copyWith updates fields', () {
      final track = AudioTrackConfig(
        id: 'track-001',
        type: VoiceTrackType.narration,
        name: '旁白轨',
      );

      final updated = track.copyWith(
        volume: 0.5,
        pan: -0.3,
        muted: true,
      );

      expect(updated.volume, 0.5);
      expect(updated.pan, -0.3);
      expect(updated.muted, isTrue);
      expect(updated.name, '旁白轨');
      expect(updated.id, 'track-001');
      expect(updated.isAudible, isFalse);
    });

    test('effectiveVolume is 0 when muted', () {
      final track = AudioTrackConfig(
        id: 't1',
        type: VoiceTrackType.bgm,
        name: 'BGM',
        volume: 0.8,
        muted: true,
      );

      expect(track.effectiveVolume, 0.0);
    });

    test('fadeIn/out Duration', () {
      final track = AudioTrackConfig(
        id: 'track-001',
        type: VoiceTrackType.bgm,
        name: 'BGM',
        fadeIn: const Duration(seconds: 2),
        fadeOut: const Duration(milliseconds: 500),
      );

      expect(track.fadeIn.inSeconds, 2);
      expect(track.fadeOut.inMilliseconds, 500);
    });

    test('activeEffects filters enabled only', () {
      final track = AudioTrackConfig(
        id: 't1',
        type: VoiceTrackType.dialogue,
        name: '对白',
        effects: [
          const TrackEffect(kind: TrackEffectKind.reverb, enabled: true),
          const TrackEffect(kind: TrackEffectKind.compressor, enabled: false),
        ],
      );

      expect(track.activeEffects.length, 1);
      expect(track.activeEffects.first.kind, TrackEffectKind.reverb);
    });
  });

  group('MultiTrackMixPlan', () {
    test('audibleTracks respects solo', () {
      final plan = MultiTrackMixPlan(
        tracks: [
          AudioTrackConfig(id: 't1', type: VoiceTrackType.narration, name: 'A', solo: true),
          AudioTrackConfig(id: 't2', type: VoiceTrackType.dialogue, name: 'B'),
          AudioTrackConfig(id: 't3', type: VoiceTrackType.bgm, name: 'C'),
        ],
      );

      expect(plan.hasSolo, isTrue);
      expect(plan.audibleTracks.length, 1);
      expect(plan.audibleTracks.first.id, 't1');
    });

    test('audibleTracks filters muted when no solo', () {
      final plan = MultiTrackMixPlan(
        tracks: [
          AudioTrackConfig(id: 't1', type: VoiceTrackType.narration, name: 'A'),
          AudioTrackConfig(id: 't2', type: VoiceTrackType.dialogue, name: 'B', muted: true),
        ],
      );

      expect(plan.hasSolo, isFalse);
      expect(plan.audibleTracks.length, 1);
      expect(plan.audibleTracks.first.id, 't1');
    });

    test('toJson contains track data', () {
      final plan = MultiTrackMixPlan(
        tracks: [
          AudioTrackConfig(id: 't1', type: VoiceTrackType.narration, name: 'A'),
        ],
      );

      final json = plan.toJson();
      expect(json['tracks'], isList);
      expect((json['tracks'] as List).length, 1);
      expect(json['master_volume'], 1.0);
    });
  });

  group('GpuEncoder', () {
    test('isGpu distinguishes hardware from software', () {
      expect(GpuEncoder.h264Nvenc.isGpu, isTrue);
      expect(GpuEncoder.h265Amf.isGpu, isTrue);
      expect(GpuEncoder.software264.isGpu, isFalse);
      expect(GpuEncoder.software265.isGpu, isFalse);
    });

    test('ffmpegCodec returns correct codec string', () {
      expect(GpuEncoder.h264Nvenc.ffmpegCodec, 'h264_nvenc');
      expect(GpuEncoder.h264Amf.ffmpegCodec, 'h264_amf');
      expect(GpuEncoder.software264.ffmpegCodec, 'libx264');
    });
  });

  group('GpuRenderConfig', () {
    test('default config', () {
      const config = GpuRenderConfig();

      expect(config.encoder, GpuEncoder.h264Nvenc);
      expect(config.preset, GpuRenderPreset.fast);
      expect(config.crf, 20);
      expect(config.bFrames, 3);
      expect(config.isGpuAccelerated, isTrue);
    });

    test('toCommandArgs contains codec and preset', () {
      const config = GpuRenderConfig();
      final result = config.toCommandArgs();

      expect(result['args'], isList);
      expect(result['encoder'], 'h264Nvenc');
      expect(result['preset'], 'fast');
    });

    test('software encoder is not gpu accelerated', () {
      const config = GpuRenderConfig(encoder: GpuEncoder.software264);
      expect(config.isGpuAccelerated, isFalse);
    });
  });

  group('GpuCapability', () {
    test('nvidia factory', () {
      final cap = GpuCapability.nvidia(
        deviceName: 'RTX 4090',
        vramMb: 24576,
        cudaCores: 16384,
      );

      expect(cap.vendor, 'NVIDIA');
      expect(cap.encoders, contains(GpuEncoder.h264Nvenc));
      expect(cap.encoders, contains(GpuEncoder.h265Nvenc));
      expect(cap.hasGpuAcceleration, isTrue);
      expect(cap.supportsEncoder(GpuEncoder.h264Nvenc), isTrue);
      expect(cap.supportsEncoder(GpuEncoder.software264), isFalse);
    });

    test('fallback has no GPU acceleration', () {
      final cap = GpuCapability.fallback();

      expect(cap.vendor, 'Generic');
      expect(cap.hasGpuAcceleration, isFalse);
    });
  });

  group('RenderProgress', () {
    test('progressPercent clamps to 100', () {
      const progress = RenderProgress(progress: 1.5);
      expect(progress.progressPercent, 100.0);
    });

    test('terminal statuses', () {
      expect(RenderStatus.succeeded.isTerminal, isTrue);
      expect(RenderStatus.failed.isTerminal, isTrue);
      expect(RenderStatus.cancelled.isTerminal, isTrue);
      expect(RenderStatus.rendering.isTerminal, isFalse);
    });
  });
}
