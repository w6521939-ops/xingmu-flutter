class SubtitleLine {
  const SubtitleLine({
    required this.id,
    required this.text,
    required this.speaker,
    this.characterId,
    this.startTimestamp = Duration.zero,
    this.endTimestamp = Duration.zero,
    this.audioDuration = Duration.zero,
    this.audioUrl,
    this.speed = 1.0,
    this.emotion,
    this.pauseAfter = Duration.zero,
    this.status = SubtitleStatus.pending,
  });

  final String id;
  final String text;
  final String speaker;
  final String? characterId;
  final Duration startTimestamp;
  final Duration endTimestamp;
  final Duration audioDuration;
  final String? audioUrl;
  final double speed;
  final String? emotion;
  final Duration pauseAfter;
  final SubtitleStatus status;

  bool get hasAudio => audioUrl != null;
  bool get isTimed => endTimestamp > startTimestamp;
  Duration get displayDuration => endTimestamp - startTimestamp;

  SubtitleLine copyWith({
    String? id,
    String? text,
    String? speaker,
    String? characterId,
    Duration? startTimestamp,
    Duration? endTimestamp,
    Duration? audioDuration,
    String? audioUrl,
    double? speed,
    String? emotion,
    Duration? pauseAfter,
    SubtitleStatus? status,
  }) => SubtitleLine(
    id: id ?? this.id,
    text: text ?? this.text,
    speaker: speaker ?? this.speaker,
    characterId: characterId ?? this.characterId,
    startTimestamp: startTimestamp ?? this.startTimestamp,
    endTimestamp: endTimestamp ?? this.endTimestamp,
    audioDuration: audioDuration ?? this.audioDuration,
    audioUrl: audioUrl ?? this.audioUrl,
    speed: speed ?? this.speed,
    emotion: emotion ?? this.emotion,
    pauseAfter: pauseAfter ?? this.pauseAfter,
    status: status ?? this.status,
  );

  factory SubtitleLine.fromJson(Map<String, dynamic> json) {
    return SubtitleLine(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      speaker: json['speaker'] as String? ?? '',
      characterId: json['character_id'] as String?,
      startTimestamp: _parseDuration(json['start_ms']),
      endTimestamp: _parseDuration(json['end_ms']),
      audioDuration: _parseDuration(json['audio_duration_ms']),
      audioUrl: json['audio_url'] as String?,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      emotion: json['emotion'] as String?,
      pauseAfter: _parseDuration(json['pause_after_ms']),
      status: SubtitleStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SubtitleStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'speaker': speaker,
    'character_id': characterId,
    'start_ms': startTimestamp.inMilliseconds,
    'end_ms': endTimestamp.inMilliseconds,
    'audio_duration_ms': audioDuration.inMilliseconds,
    'audio_url': audioUrl,
    'speed': speed,
    'emotion': emotion,
    'pause_after_ms': pauseAfter.inMilliseconds,
    'status': status.name,
  };
}

enum SubtitleStatus {
  pending,
  generating,
  generated,
  synced,
  failed;

  String get label => switch (this) {
    SubtitleStatus.pending => '待生成',
    SubtitleStatus.generating => '生成中',
    SubtitleStatus.generated => '已生成',
    SubtitleStatus.synced => '已同步',
    SubtitleStatus.failed => '失败',
  };

  bool get isTerminal => this == SubtitleStatus.synced ||
      this == SubtitleStatus.failed;
}

enum VoiceTrackType {
  narration,
  dialogue,
  soundEffect,
  bgm;

  String get label => switch (this) {
    VoiceTrackType.narration => '旁白',
    VoiceTrackType.dialogue => '对话',
    VoiceTrackType.soundEffect => '音效',
    VoiceTrackType.bgm => '背景音乐',
  };
}

class VoiceTrack {
  const VoiceTrack({
    required this.type,
    required this.lines,
    this.volume = 1.0,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
  });

  final VoiceTrackType type;
  final List<SubtitleLine> lines;
  final double volume;
  final Duration fadeIn;
  final Duration fadeOut;

  Duration get totalDuration {
    if (lines.isEmpty) return Duration.zero;
    final last = lines.last;
    return last.endTimestamp + last.pauseAfter;
  }

  VoiceTrack copyWith({
    VoiceTrackType? type,
    List<SubtitleLine>? lines,
    double? volume,
    Duration? fadeIn,
    Duration? fadeOut,
  }) => VoiceTrack(
    type: type ?? this.type,
    lines: List.unmodifiable(lines ?? this.lines),
    volume: volume ?? this.volume,
    fadeIn: fadeIn ?? this.fadeIn,
    fadeOut: fadeOut ?? this.fadeOut,
  );
}

class VoiceTimeline {
  const VoiceTimeline({
    required this.tracks,
    required this.totalDuration,
    this.sampleRate = 44100,
  });

  final List<VoiceTrack> tracks;
  final Duration totalDuration;
  final int sampleRate;

  List<SubtitleLine> get allLines =>
      tracks.expand((track) => track.lines).toList()
        ..sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));

  factory VoiceTimeline.empty() => const VoiceTimeline(
    tracks: [],
    totalDuration: Duration.zero,
  );

  String toSRT() {
    final buffer = StringBuffer();
    final sorted = allLines;
    var index = 1;

    for (final line in sorted) {
      if (!line.isTimed) continue;
      buffer.writeln(index);
      buffer.writeln('${_formatSrtTime(line.startTimestamp)} --> ${_formatSrtTime(line.endTimestamp)}');
      buffer.writeln(line.text);
      buffer.writeln();
      index++;
    }

    return buffer.toString();
  }

  String toASS() {
    final buffer = StringBuffer();
    buffer.writeln('[Script Info]');
    buffer.writeln('ScriptType: v4.00+');
    buffer.writeln('PlayResX: 1080');
    buffer.writeln('PlayResY: 1920');
    buffer.writeln();
    buffer.writeln('[V4+ Styles]');
    buffer.writeln('Format: Name, Fontname, Fontsize, PrimaryColour, BackColour, Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    buffer.writeln('Style: Default,Microsoft YaHei,48,&H00FFFFFF,&H80000000,-1,0,1,2,0,2,60,60,120,1');
    buffer.writeln();
    buffer.writeln('[Events]');
    buffer.writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (final line in allLines) {
      if (!line.isTimed) continue;
      final text = line.text.replaceAll('\n', '\\N');
      buffer.writeln(
        'Dialogue: 0,${_formatSrtTime(line.startTimestamp)},${_formatSrtTime(line.endTimestamp)},Default,${line.speaker},0,0,0,,${text}',
      );
    }

    return buffer.toString();
  }

  static String _formatSrtTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final millis = duration.inMilliseconds.remainder(1000);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
  }
}

Duration _parseDuration(dynamic value) {
  if (value == null) return Duration.zero;
  if (value is int) return Duration(milliseconds: value);
  if (value is num) return Duration(milliseconds: value.toInt());
  return Duration.zero;
}
