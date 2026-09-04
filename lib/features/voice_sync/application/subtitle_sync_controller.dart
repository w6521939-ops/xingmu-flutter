import 'package:flutter/foundation.dart';

import '../domain/subtitle_sync.dart';

class SubtitleSyncController extends ChangeNotifier {
  final List<SubtitleLine> _lines = [];
  final List<VoiceTrack> _tracks = [];
  VoiceTimeline _timeline = VoiceTimeline.empty();

  bool _isProcessing = false;
  String? _errorMessage;

  List<SubtitleLine> get lines => List.unmodifiable(_lines);
  List<VoiceTrack> get tracks => List.unmodifiable(_tracks);
  VoiceTimeline get timeline => _timeline;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  Duration get totalDuration => _timeline.totalDuration;

  void setLines(List<SubtitleLine> lines) {
    _lines
      ..clear()
      ..addAll(lines);
    _rebuildTimeline();
    notifyListeners();
  }

  void addLine(SubtitleLine line) {
    _lines.add(line);
    _rebuildTimeline();
    notifyListeners();
  }

  void updateLine(String id, SubtitleLine Function(SubtitleLine) updater) {
    final idx = _lines.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    _lines[idx] = updater(_lines[idx]);
    _rebuildTimeline();
    notifyListeners();
  }

  Future<SubtitleLine> generateLineTiming(SubtitleLine line, Duration audioDuration) async {
    final actualDuration = Duration(
      milliseconds: (audioDuration.inMilliseconds / line.speed).round(),
    );

    final lastEnd = _lines.isEmpty
        ? Duration.zero
        : _lines.last.endTimestamp + _lines.last.pauseAfter;

    final start = lastEnd;
    final end = start + actualDuration;

    final updated = line.copyWith(
      startTimestamp: start,
      endTimestamp: end,
      audioDuration: actualDuration,
      status: SubtitleStatus.synced,
    );

    return updated;
  }

  Future<VoiceTimeline> generateFullTimeline() async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var currentTime = Duration.zero;
      final synced = <SubtitleLine>[];

    for (final line in _lines) {
        Duration audioDuration = line.audioDuration;
        if (audioDuration == Duration.zero && line.text.isNotEmpty) {
          audioDuration = _estimateDuration(line.text, line.speed);
        }

        final adjustedDuration = Duration(
          milliseconds: (audioDuration.inMilliseconds / line.speed).round(),
        );

        final start = currentTime;
        final end = start + adjustedDuration;
        final pause = line.pauseAfter;

        synced.add(line.copyWith(
          startTimestamp: start,
          endTimestamp: end,
          audioDuration: adjustedDuration,
          status: SubtitleStatus.synced,
        ));

        currentTime = end + pause;
      }

      final track = VoiceTrack(
        type: VoiceTrackType.dialogue,
        lines: synced,
      );
      _tracks
        ..clear()
        ..add(track);
      _timeline = VoiceTimeline(
        tracks: _tracks,
        totalDuration: currentTime,
      );

      _isProcessing = false;
      notifyListeners();
      return _timeline;
    } catch (e) {
      _errorMessage = e.toString();
      _isProcessing = false;
      notifyListeners();
      rethrow;
    }
  }

  Duration _estimateDuration(String text, double speed) {
    final charCount = text.length;
    final charsPerSecond = 5.0;
    final seconds = charCount / charsPerSecond / speed;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  void _rebuildTimeline() {
    if (_lines.isEmpty) {
      _timeline = VoiceTimeline.empty();
      return;
    }

    final track = VoiceTrack(
      type: VoiceTrackType.dialogue,
      lines: List.of(_lines),
    );
    _timeline = VoiceTimeline(
      tracks: [track],
      totalDuration: track.totalDuration,
    );
  }

  String exportSRT() => _timeline.toSRT();

  String exportASS() => _timeline.toASS();

  void clear() {
    _lines.clear();
    _tracks.clear();
    _timeline = VoiceTimeline.empty();
    _errorMessage = null;
    _isProcessing = false;
    notifyListeners();
  }
}
