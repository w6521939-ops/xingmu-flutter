import 'camera_motion.dart';

class StoryboardPlanner {
  static List<CameraMotion> planMotions({
    required int shotCount,
    List<CameraMotionType>? preferredTypes,
    bool varyMotions = true,
  }) {
    final types = preferredTypes ?? [
      CameraMotionType.zoomIn,
      CameraMotionType.panRight,
      CameraMotionType.zoomOut,
      CameraMotionType.panLeft,
      CameraMotionType.tiltUp,
      CameraMotionType.kenBurns,
    ];

    final motions = <CameraMotion>[];
    for (var i = 0; i < shotCount; i++) {
      final type = varyMotions
          ? types[i % types.length]
          : types.first;

      motions.add(_createMotion(type, intensity: 0.3 + (i % 3) * 0.15));
    }
    return motions;
  }

  static CameraMotion _createMotion(
    CameraMotionType type, {
    double intensity = 0.4,
    double duration = 5.0,
  }) => switch (type) {
    CameraMotionType.zoomIn => CameraMotion.zoomIn(intensity: intensity, duration: duration),
    CameraMotionType.zoomOut => CameraMotion.zoomOut(intensity: intensity, duration: duration),
    CameraMotionType.panLeft => CameraMotion.panLeft(distance: intensity * 200, duration: duration),
    CameraMotionType.panRight => CameraMotion.panRight(distance: intensity * 200, duration: duration),
    CameraMotionType.tiltUp => CameraMotion.tiltUp(distance: intensity * 150, duration: duration),
    CameraMotionType.tiltDown => CameraMotion.tiltDown(distance: intensity * 150, duration: duration),
    CameraMotionType.kenBurns => CameraMotion.kenBurns(intensity: intensity, duration: duration),
    CameraMotionType.staticShot => CameraMotion.static,
  };

  static List<StoryboardShot> applyMotions(
    List<StoryboardShot> shots,
    List<CameraMotion> motions,
  ) {
    final result = <StoryboardShot>[];
    for (var i = 0; i < shots.length; i++) {
      final shot = shots[i];
      final motion = i < motions.length ? motions[i] : null;
      result.add(shot.copyWith(motion: motion));
    }
    return result;
  }

  static CameraMotion autoDetect(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('特写') || lower.contains('close') || lower.contains('聚焦')) {
      return CameraMotion.zoomIn();
    }
    if (lower.contains('全景') || lower.contains('wide') || lower.contains('远')) {
      return CameraMotion.zoomOut();
    }
    if (lower.contains('左') || lower.contains('left')) {
      return CameraMotion.panLeft();
    }
    if (lower.contains('右') || lower.contains('right')) {
      return CameraMotion.panRight();
    }
    if (lower.contains('上') || lower.contains('up') || lower.contains('仰望')) {
      return CameraMotion.tiltUp();
    }
    if (lower.contains('下') || lower.contains('down') || lower.contains('俯瞰')) {
      return CameraMotion.tiltDown();
    }
    if (lower.contains('缓慢') || lower.contains('smooth') || lower.contains('ken')) {
      return CameraMotion.kenBurns();
    }
    return CameraMotion.zoomIn(intensity: 0.3);
  }

  static List<StoryboardShot> autoPlan(List<StoryboardShot> shots) {
    final planned = <StoryboardShot>[];
    for (var i = 0; i < shots.length; i++) {
      final shot = shots[i];
      final motion = autoDetect(shot.prompt);
      planned.add(shot.copyWith(
        motion: motion,
        order: i + 1,
      ));
    }
    return planned;
  }

  static double estimateRenderTime(List<StoryboardShot> shots) {
    var total = 0.0;
    for (final shot in shots) {
      total += shot.durationSeconds;
    }
    return total;
  }

  static String formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).round();
    return '${mins}分${secs}秒';
  }
}
