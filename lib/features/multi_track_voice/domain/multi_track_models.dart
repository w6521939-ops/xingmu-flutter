import '../../../features/voice_sync/domain/subtitle_sync.dart';

enum TrackEffectKind {
  reverb,
  compressor,
  equalizer,
  noiseGate,
  deEsser;

  String get label => switch (this) {
    TrackEffectKind.reverb => '混响',
    TrackEffectKind.compressor => '压缩器',
    TrackEffectKind.equalizer => '均衡器',
    TrackEffectKind.noiseGate => '噪声门',
    TrackEffectKind.deEsser => '齿音消除',
  };

  String get icon => switch (this) {
    TrackEffectKind.reverb => 'graphic_eq',
    TrackEffectKind.compressor => 'compress',
    TrackEffectKind.equalizer => 'tune',
    TrackEffectKind.noiseGate => 'door_front',
    TrackEffectKind.deEsser => 'record_voice_over',
  };
}

class TrackEffect {
  const TrackEffect({
    required this.kind,
    this.enabled = true,
    this.parameters = const {},
  });

  final TrackEffectKind kind;
  final bool enabled;
  final Map<String, double> parameters;

  TrackEffect copyWith({
    bool? enabled,
    Map<String, double>? parameters,
  }) => TrackEffect(
    kind: kind,
    enabled: enabled ?? this.enabled,
    parameters: parameters ?? this.parameters,
  );
}

class AudioTrackConfig {
  const AudioTrackConfig({
    required this.id,
    required this.type,
    required this.name,
    this.volume = 1.0,
    this.pan = 0.0,
    this.muted = false,
    this.solo = false,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.effects = const [],
    this.audioUrl,
    this.color = 0xFF765CFF,
  });

  final String id;
  final VoiceTrackType type;
  final String name;
  final double volume;
  final double pan;
  final bool muted;
  final bool solo;
  final Duration fadeIn;
  final Duration fadeOut;
  final List<TrackEffect> effects;
  final String? audioUrl;
  final int color;

  bool get isAudible => !muted;
  double get effectiveVolume => muted ? 0.0 : volume.clamp(0.0, 2.0);
  double get panValue => pan.clamp(-1.0, 1.0);
  List<TrackEffect> get activeEffects => effects.where((e) => e.enabled).toList();

  AudioTrackConfig copyWith({
    String? id,
    VoiceTrackType? type,
    String? name,
    double? volume,
    double? pan,
    bool? muted,
    bool? solo,
    Duration? fadeIn,
    Duration? fadeOut,
    List<TrackEffect>? effects,
    String? audioUrl,
    int? color,
  }) => AudioTrackConfig(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    volume: volume ?? this.volume,
    pan: pan ?? this.pan,
    muted: muted ?? this.muted,
    solo: solo ?? this.solo,
    fadeIn: fadeIn ?? this.fadeIn,
    fadeOut: fadeOut ?? this.fadeOut,
    effects: effects ?? this.effects,
    audioUrl: audioUrl ?? this.audioUrl,
    color: color ?? this.color,
  );

  factory AudioTrackConfig.fromVoiceTrack(VoiceTrack track, {String? id, String? name}) {
    final trackName = name ?? switch (track.type) {
      VoiceTrackType.narration => '旁白轨',
      VoiceTrackType.dialogue => '对白轨',
      VoiceTrackType.soundEffect => '音效轨',
      VoiceTrackType.bgm => '背景音乐轨',
    };
    return AudioTrackConfig(
      id: id ?? 'track-${track.type.name}-${DateTime.now().millisecondsSinceEpoch}',
      type: track.type,
      name: trackName,
      volume: track.volume,
      fadeIn: track.fadeIn,
      fadeOut: track.fadeOut,
    );
  }
}

class MultiTrackMixPlan {
  const MultiTrackMixPlan({
    required this.tracks,
    this.masterVolume = 1.0,
    this.outputSampleRate = 44100,
    this.outputChannels = 2,
    this.normalizeOutput = true,
    this.headroomDb = -3.0,
  });

  final List<AudioTrackConfig> tracks;
  final double masterVolume;
  final int outputSampleRate;
  final int outputChannels;
  final bool normalizeOutput;
  final double headroomDb;

  bool get hasSolo => tracks.any((t) => t.solo);
  List<AudioTrackConfig> get audibleTracks => hasSolo
      ? tracks.where((t) => t.solo).toList()
      : tracks.where((t) => !t.muted).toList();

  Duration get totalDuration {
    if (tracks.isEmpty) return Duration.zero;
    var maxFadeOut = Duration.zero;
    for (final track in tracks) {
      if (track.fadeOut > maxFadeOut) maxFadeOut = track.fadeOut;
    }
    return maxFadeOut;
  }

  MultiTrackMixPlan copyWith({
    List<AudioTrackConfig>? tracks,
    double? masterVolume,
    int? outputSampleRate,
    int? outputChannels,
    bool? normalizeOutput,
    double? headroomDb,
  }) => MultiTrackMixPlan(
    tracks: tracks ?? this.tracks,
    masterVolume: masterVolume ?? this.masterVolume,
    outputSampleRate: outputSampleRate ?? this.outputSampleRate,
    outputChannels: outputChannels ?? this.outputChannels,
    normalizeOutput: normalizeOutput ?? this.normalizeOutput,
    headroomDb: headroomDb ?? this.headroomDb,
  );

  Map<String, dynamic> toJson() => {
    'tracks': tracks.map((t) => _trackToJson(t)).toList(),
    'master_volume': masterVolume,
    'sample_rate': outputSampleRate,
    'channels': outputChannels,
    'normalize': normalizeOutput,
    'headroom_db': headroomDb,
  };

  Map<String, dynamic> _trackToJson(AudioTrackConfig track) => {
    'id': track.id,
    'type': track.type.name,
    'name': track.name,
    'volume': track.volume,
    'pan': track.pan,
    'muted': track.muted,
    'solo': track.solo,
    'fade_in_ms': track.fadeIn.inMilliseconds,
    'fade_out_ms': track.fadeOut.inMilliseconds,
    'effects': track.effects.map((e) => {
      'kind': e.kind.name,
      'enabled': e.enabled,
      'params': e.parameters,
    }).toList(),
    'audio_url': track.audioUrl,
    'color': track.color,
  };
}

enum GpuEncoder {
  h264Nvenc,
  h265Nvenc,
  h264Amf,
  h265Amf,
  h264Qsv,
  h264Videotoolbox,
  h265Videotoolbox,
  software264,
  software265;

  String get label => switch (this) {
    GpuEncoder.h264Nvenc => 'H.264 NVENC (NVIDIA)',
    GpuEncoder.h265Nvenc => 'H.265 NVENC (NVIDIA)',
    GpuEncoder.h264Amf => 'H.264 AMF (AMD)',
    GpuEncoder.h265Amf => 'H.265 AMF (AMD)',
    GpuEncoder.h264Qsv => 'H.264 QSV (Intel)',
    GpuEncoder.h264Videotoolbox => 'H.264 VideoToolbox (Apple)',
    GpuEncoder.h265Videotoolbox => 'H.265 VideoToolbox (Apple)',
    GpuEncoder.software264 => 'H.264 软件编码',
    GpuEncoder.software265 => 'H.265 软件编码',
  };

  bool get isGpu => this != GpuEncoder.software264 &&
      this != GpuEncoder.software265;

  String get ffmpegCodec => switch (this) {
    GpuEncoder.h264Nvenc => 'h264_nvenc',
    GpuEncoder.h265Nvenc => 'hevc_nvenc',
    GpuEncoder.h264Amf => 'h264_amf',
    GpuEncoder.h265Amf => 'hevc_amf',
    GpuEncoder.h264Qsv => 'h264_qsv',
    GpuEncoder.h264Videotoolbox => 'h264_videotoolbox',
    GpuEncoder.h265Videotoolbox => 'hevc_videotoolbox',
    GpuEncoder.software264 => 'libx264',
    GpuEncoder.software265 => 'libx265',
  };
}

enum GpuRenderPreset {
  ultrafast,
  fast,
  medium,
  slow,
  lossless;

  String get label => switch (this) {
    GpuRenderPreset.ultrafast => '极速',
    GpuRenderPreset.fast => '快速',
    GpuRenderPreset.medium => '标准',
    GpuRenderPreset.slow => '高质量',
    GpuRenderPreset.lossless => '无损',
  };

  String get ffmpegValue => switch (this) {
    GpuRenderPreset.ultrafast => 'ultrafast',
    GpuRenderPreset.fast => 'fast',
    GpuRenderPreset.medium => 'medium',
    GpuRenderPreset.slow => 'slow',
    GpuRenderPreset.lossless => 'lossless',
  };
}

class GpuRenderConfig {
  const GpuRenderConfig({
    this.encoder = GpuEncoder.h264Nvenc,
    this.preset = GpuRenderPreset.fast,
    this.crf = 20,
    this.maxBitrateKbps = 8000,
    this.gopSize = 250,
    this.bFrames = 3,
    this.useBFrames = true,
    this.resolutionScale = 1.0,
    this.fps = 30,
    this.enableHdr = false,
  });

  final GpuEncoder encoder;
  final GpuRenderPreset preset;
  final int crf;
  final int maxBitrateKbps;
  final int gopSize;
  final int bFrames;
  final bool useBFrames;
  final double resolutionScale;
  final int fps;
  final bool enableHdr;

  bool get isGpuAccelerated => encoder.isGpu;

  Map<String, dynamic> toCommandArgs() {
    final args = <String>[];
    args.addAll(['-c:v', encoder.ffmpegCodec]);
    args.addAll(['-preset', preset.ffmpegValue]);
    args.addAll(['-crf', crf.toString()]);
    args.addAll(['-maxrate', '${maxBitrateKbps}k']);
    args.addAll(['-bufsize', '${maxBitrateKbps * 2}k']);
    args.addAll(['-g', gopSize.toString()]);
    if (useBFrames && encoder.isGpu) {
      args.addAll(['-bf', bFrames.toString()]);
    }
    if (encoder.isGpu) {
      args.addAll(['-spatial-aq', '1']);
      args.addAll(['-temporal-aq', '1']);
    }
    return {'args': args, 'encoder': encoder.name, 'preset': preset.name};
  }

  GpuRenderConfig copyWith({
    GpuEncoder? encoder,
    GpuRenderPreset? preset,
    int? crf,
    int? maxBitrateKbps,
    int? gopSize,
    int? bFrames,
    bool? useBFrames,
    double? resolutionScale,
    int? fps,
    bool? enableHdr,
  }) => GpuRenderConfig(
    encoder: encoder ?? this.encoder,
    preset: preset ?? this.preset,
    crf: crf ?? this.crf,
    maxBitrateKbps: maxBitrateKbps ?? this.maxBitrateKbps,
    gopSize: gopSize ?? this.gopSize,
    bFrames: bFrames ?? this.bFrames,
    useBFrames: useBFrames ?? this.useBFrames,
    resolutionScale: resolutionScale ?? this.resolutionScale,
    fps: fps ?? this.fps,
    enableHdr: enableHdr ?? this.enableHdr,
  );
}

enum RenderStatus {
  idle,
  preparing,
  rendering,
  muxing,
  succeeded,
  failed,
  cancelled;

  bool get isTerminal => this == RenderStatus.succeeded ||
      this == RenderStatus.failed ||
      this == RenderStatus.cancelled;

  bool get isActive => this == RenderStatus.preparing ||
      this == RenderStatus.rendering ||
      this == RenderStatus.muxing;

  String get label => switch (this) {
    RenderStatus.idle => '空闲',
    RenderStatus.preparing => '准备中',
    RenderStatus.rendering => '渲染中',
    RenderStatus.muxing => '封装中',
    RenderStatus.succeeded => '成功',
    RenderStatus.failed => '失败',
    RenderStatus.cancelled => '已取消',
  };
}

class RenderProgress {
  const RenderProgress({
    this.status = RenderStatus.idle,
    this.progress = 0.0,
    this.currentFrame = 0,
    this.totalFrames = 0,
    this.elapsedTime = Duration.zero,
    this.estimatedRemaining = Duration.zero,
    this.fps = 0.0,
    this.errorMessage,
    this.outputPath,
  });

  final RenderStatus status;
  final double progress;
  final int currentFrame;
  final int totalFrames;
  final Duration elapsedTime;
  final Duration estimatedRemaining;
  final double fps;
  final String? errorMessage;
  final String? outputPath;

  double get progressPercent => (progress * 100).clamp(0, 100);

  RenderProgress copyWith({
    RenderStatus? status,
    double? progress,
    int? currentFrame,
    int? totalFrames,
    Duration? elapsedTime,
    Duration? estimatedRemaining,
    double? fps,
    String? errorMessage,
    String? outputPath,
  }) => RenderProgress(
    status: status ?? this.status,
    progress: progress ?? this.progress,
    currentFrame: currentFrame ?? this.currentFrame,
    totalFrames: totalFrames ?? this.totalFrames,
    elapsedTime: elapsedTime ?? this.elapsedTime,
    estimatedRemaining: estimatedRemaining ?? this.estimatedRemaining,
    fps: fps ?? this.fps,
    errorMessage: errorMessage ?? this.errorMessage,
    outputPath: outputPath ?? this.outputPath,
  );
}

class GpuCapability {
  const GpuCapability({
    required this.vendor,
    required this.deviceName,
    required this.encoders,
    this.vramMb = 0,
    this.cudaCores = 0,
    this.computeCapability,
  });

  final String vendor;
  final String deviceName;
  final List<GpuEncoder> encoders;
  final int vramMb;
  final int cudaCores;
  final String? computeCapability;

  bool get hasGpuAcceleration => encoders.any((e) => e.isGpu);
  bool supportsEncoder(GpuEncoder encoder) => encoders.contains(encoder);

  factory GpuCapability.fallback() => const GpuCapability(
    vendor: 'Generic',
    deviceName: 'CPU Software Encoding',
    encoders: [GpuEncoder.software264, GpuEncoder.software265],
    vramMb: 0,
    cudaCores: 0,
  );

  factory GpuCapability.nvidia({
    required String deviceName,
    required int vramMb,
    int cudaCores = 0,
    String? computeCapability,
  }) => GpuCapability(
    vendor: 'NVIDIA',
    deviceName: deviceName,
    encoders: [GpuEncoder.h264Nvenc, GpuEncoder.h265Nvenc],
    vramMb: vramMb,
    cudaCores: cudaCores,
    computeCapability: computeCapability,
  );

  factory GpuCapability.amd({
    required String deviceName,
    required int vramMb,
  }) => GpuCapability(
    vendor: 'AMD',
    deviceName: deviceName,
    encoders: [GpuEncoder.h264Amf, GpuEncoder.h265Amf],
    vramMb: vramMb,
  );

  factory GpuCapability.intel({
    required String deviceName,
  }) => const GpuCapability(
    vendor: 'Intel',
    deviceName: 'Intel QSV',
    encoders: [GpuEncoder.h264Qsv],
  );

  factory GpuCapability.apple({
    required String deviceName,
  }) => GpuCapability(
    vendor: 'Apple',
    deviceName: deviceName,
    encoders: [GpuEncoder.h264Videotoolbox, GpuEncoder.h265Videotoolbox],
  );

  Map<String, dynamic> toJson() => {
    'vendor': vendor,
    'device_name': deviceName,
    'encoders': encoders.map((e) => e.name).toList(),
    'vram_mb': vramMb,
    'cuda_cores': cudaCores,
    'compute_capability': computeCapability,
  };
}
