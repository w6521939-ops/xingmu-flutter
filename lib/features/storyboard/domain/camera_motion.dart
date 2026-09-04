import 'dart:ui';

enum CameraMotionType {
  zoomIn,
  zoomOut,
  panLeft,
  panRight,
  tiltUp,
  tiltDown,
  staticShot,
  kenBurns;

  String get label => switch (this) {
    CameraMotionType.zoomIn => '推近',
    CameraMotionType.zoomOut => '拉远',
    CameraMotionType.panLeft => '左移',
    CameraMotionType.panRight => '右移',
    CameraMotionType.tiltUp => '上移',
    CameraMotionType.tiltDown => '下移',
    CameraMotionType.staticShot => '静止',
    CameraMotionType.kenBurns => 'Ken Burns',
  };

  String get description => switch (this) {
    CameraMotionType.zoomIn => '镜头缓慢推近，聚焦主体',
    CameraMotionType.zoomOut => '镜头缓慢拉远，展示全景',
    CameraMotionType.panLeft => '镜头向左平移',
    CameraMotionType.panRight => '镜头向右平移',
    CameraMotionType.tiltUp => '镜头向上移动',
    CameraMotionType.tiltDown => '镜头向下移动',
    CameraMotionType.staticShot => '固定镜头，无运动',
    CameraMotionType.kenBurns => '综合运动：缩放+平移',
  };
}

class CameraMotion {
  const CameraMotion({
    required this.type,
    this.startScale = 1.0,
    this.endScale = 1.0,
    this.startOffset = Offset.zero,
    this.endOffset = Offset.zero,
    this.easing = MotionEasing.easeInOut,
    this.durationSeconds = 5.0,
  });

  final CameraMotionType type;
  final double startScale;
  final double endScale;
  final Offset startOffset;
  final Offset endOffset;
  final MotionEasing easing;
  final double durationSeconds;

  CameraMotion copyWith({
    CameraMotionType? type,
    double? startScale,
    double? endScale,
    Offset? startOffset,
    Offset? endOffset,
    MotionEasing? easing,
    double? durationSeconds,
  }) => CameraMotion(
    type: type ?? this.type,
    startScale: startScale ?? this.startScale,
    endScale: endScale ?? this.endScale,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    easing: easing ?? this.easing,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'start_scale': startScale,
    'end_scale': endScale,
    'start_offset': {'dx': startOffset.dx, 'dy': startOffset.dy},
    'end_offset': {'dx': endOffset.dx, 'dy': endOffset.dy},
    'easing': easing.name,
    'duration_seconds': durationSeconds,
  };

  static CameraMotion zoomIn({double? intensity, double? duration}) =>
      CameraMotion(
        type: CameraMotionType.zoomIn,
        startScale: 1.0,
        endScale: 1.0 + (intensity ?? 0.5),
        easing: MotionEasing.easeInOut,
        durationSeconds: duration ?? 5.0,
      );

  static CameraMotion zoomOut({double? intensity, double? duration}) =>
      CameraMotion(
        type: CameraMotionType.zoomOut,
        startScale: 1.0 + (intensity ?? 0.5),
        endScale: 1.0,
        easing: MotionEasing.easeOut,
        durationSeconds: duration ?? 5.0,
      );

  static CameraMotion panLeft({double? distance, double? duration}) =>
      CameraMotion(
        type: CameraMotionType.panLeft,
        startOffset: Offset.zero,
        endOffset: Offset(-(distance ?? 100), 0),
        easing: MotionEasing.easeInOut,
        durationSeconds: duration ?? 5.0,
      );

  static CameraMotion panRight({double? distance, double? duration}) =>
      CameraMotion(
        type: CameraMotionType.panRight,
        startOffset: Offset.zero,
        endOffset: Offset(distance ?? 100, 0),
        easing: MotionEasing.easeInOut,
        durationSeconds: duration ?? 5.0,
      );

  static CameraMotion tiltUp({double? distance, double? duration}) =>
      CameraMotion(
        type: CameraMotionType.tiltUp,
        startOffset: Offset.zero,
        endOffset: Offset(0, -(distance ?? 100)),
        easing: MotionEasing.easeInOut,
        durationSeconds: duration ?? 5.0,
      );

  static CameraMotion tiltDown({double? distance, double? duration}) =>
      CameraMotion(
        type: CameraMotionType.tiltDown,
        startOffset: Offset.zero,
        endOffset: Offset(0, distance ?? 100),
        easing: MotionEasing.easeInOut,
        durationSeconds: duration ?? 5.0,
      );

  static CameraMotion kenBurns({double? intensity, double? duration}) =>
      CameraMotion(
        type: CameraMotionType.kenBurns,
        startScale: 1.0,
        endScale: 1.0 + (intensity ?? 0.3),
        startOffset: const Offset(-20, -10),
        endOffset: Offset(20 + (intensity ?? 0.3) * 40, 10),
        easing: MotionEasing.easeInOut,
        durationSeconds: duration ?? 6.0,
      );

  static CameraMotion get static => const CameraMotion(
    type: CameraMotionType.staticShot,
  );

  static CameraMotion random({double? seed}) {
    final values = CameraMotionType.values
        .where((t) => t != CameraMotionType.staticShot)
        .toList();
    final idx = ((seed ?? DateTime.now().millisecond) % values.length).toInt();
    final type = values[idx];
    return switch (type) {
      CameraMotionType.zoomIn => CameraMotion.zoomIn(),
      CameraMotionType.zoomOut => CameraMotion.zoomOut(),
      CameraMotionType.panLeft => CameraMotion.panLeft(),
      CameraMotionType.panRight => CameraMotion.panRight(),
      CameraMotionType.tiltUp => CameraMotion.tiltUp(),
      CameraMotionType.tiltDown => CameraMotion.tiltDown(),
      CameraMotionType.kenBurns => CameraMotion.kenBurns(),
      CameraMotionType.staticShot => CameraMotion.static,
    };
  }
}

enum MotionEasing {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  easeInOutCubic,
  easeInOutQuart;

  String get name => switch (this) {
    MotionEasing.linear => 'linear',
    MotionEasing.easeIn => 'ease_in',
    MotionEasing.easeOut => 'ease_out',
    MotionEasing.easeInOut => 'ease_in_out',
    MotionEasing.easeInOutCubic => 'ease_in_out_cubic',
    MotionEasing.easeInOutQuart => 'ease_in_out_quart',
  };

  double transform(double t) => switch (this) {
    MotionEasing.linear => t,
    MotionEasing.easeIn => t * t,
    MotionEasing.easeOut => t * (2 - t),
    MotionEasing.easeInOut => t < 0.5
        ? 2 * t * t
        : -1 + (4 - 2 * t) * t,
    MotionEasing.easeInOutCubic => t < 0.5
        ? 4 * t * t * t
        : 1 - pow(1 - t, 3).toDouble(),
    MotionEasing.easeInOutQuart => t < 0.5
        ? 8 * t * t * t * t
        : 1 - pow(1 - t, 4).toDouble(),
  };

  double pow(double x, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= x;
    }
    return result;
  }
}

class StoryboardShot {
  const StoryboardShot({
    required this.id,
    required this.order,
    required this.title,
    required this.prompt,
    this.firstFrameUrl,
    this.lastFrameUrl,
    this.videoUrl,
    this.motion,
    this.durationSeconds = 5.0,
    this.status = ShotStatus.pending,
  });

  final String id;
  final int order;
  final String title;
  final String prompt;
  final String? firstFrameUrl;
  final String? lastFrameUrl;
  final String? videoUrl;
  final CameraMotion? motion;
  final double durationSeconds;
  final ShotStatus status;

  bool get hasMotion => motion != null && motion!.type != CameraMotionType.staticShot;
  bool get hasStoryboard => firstFrameUrl != null && lastFrameUrl != null;

  StoryboardShot copyWith({
    String? id,
    int? order,
    String? title,
    String? prompt,
    String? firstFrameUrl,
    String? lastFrameUrl,
    String? videoUrl,
    CameraMotion? motion,
    double? durationSeconds,
    ShotStatus? status,
  }) => StoryboardShot(
    id: id ?? this.id,
    order: order ?? this.order,
    title: title ?? this.title,
    prompt: prompt ?? this.prompt,
    firstFrameUrl: firstFrameUrl ?? this.firstFrameUrl,
    lastFrameUrl: lastFrameUrl ?? this.lastFrameUrl,
    videoUrl: videoUrl ?? this.videoUrl,
    motion: motion ?? this.motion,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    status: status ?? this.status,
  );

  factory StoryboardShot.fromJson(Map<String, dynamic> json) => StoryboardShot(
    id: json['id'] as String? ?? '',
    order: json['order'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    prompt: json['prompt'] as String? ?? '',
    firstFrameUrl: json['first_frame_url'] as String?,
    lastFrameUrl: json['last_frame_url'] as String?,
    videoUrl: json['video_url'] as String?,
    durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 5.0,
    status: ShotStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => ShotStatus.pending,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'title': title,
    'prompt': prompt,
    'first_frame_url': firstFrameUrl,
    'last_frame_url': lastFrameUrl,
    'video_url': videoUrl,
    'motion': motion?.toJson(),
    'duration_seconds': durationSeconds,
    'status': status.name,
  };
}

enum ShotStatus {
  pending,
  generating,
  completed,
  failed,
  skipped;

  String get label => switch (this) {
    ShotStatus.pending => '待生成',
    ShotStatus.generating => '生成中',
    ShotStatus.completed => '已完成',
    ShotStatus.failed => '失败',
    ShotStatus.skipped => '已跳过',
  };

  bool get isTerminal => this == ShotStatus.completed ||
      this == ShotStatus.failed ||
      this == ShotStatus.skipped;
}
