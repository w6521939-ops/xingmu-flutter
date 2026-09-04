import 'dart:async';

class BlackboardEvent {
  const BlackboardEvent({
    required this.type,
    required this.key,
    this.oldValue,
    this.newValue,
    this.source,
    this.timestamp,
  });

  final BlackboardEventType type;
  final String key;
  final Object? oldValue;
  final Object? newValue;
  final String? source;
  final DateTime? timestamp;

  factory BlackboardEvent.now(
    BlackboardEventType type,
    String key, {
    Object? oldValue,
    Object? newValue,
    String? source,
  }) =>
      BlackboardEvent(
        type: type,
        key: key,
        oldValue: oldValue,
        newValue: newValue,
        source: source,
        timestamp: DateTime.now(),
      );
}

enum BlackboardEventType {
  write,
  update,
  delete,
  lock,
  unlock,
}

class ProjectBlackboard {
  final Map<String, dynamic> _state = {};
  final Map<String, String> _locks = {};
  final StreamController<BlackboardEvent> _eventController =
      StreamController<BlackboardEvent>.broadcast();

  Stream<BlackboardEvent> get events => _eventController.stream;

  T read<T>(String key, {T? fallback}) {
    final value = _state[key];
    if (value is T) return value;
    return fallback as T;
  }

  T? readNullable<T>(String key) {
    final value = _state[key];
    if (value is T) return value;
    return null;
  }

  void write<T>(String key, T value, {String? source}) {
    final oldValue = _state[key];
    final eventType = oldValue == null
        ? BlackboardEventType.write
        : BlackboardEventType.update;
    _state[key] = value;
    _eventController.add(BlackboardEvent.now(
      eventType,
      key,
      oldValue: oldValue,
      newValue: value,
      source: source,
    ));
  }

  void delete(String key, {String? source}) {
    final oldValue = _state.remove(key);
    _eventController.add(BlackboardEvent.now(
      BlackboardEventType.delete,
      key,
      oldValue: oldValue,
      source: source,
    ));
  }

  bool has(String key) => _state.containsKey(key);

  bool lock(String key, String owner) {
    if (_locks.containsKey(key) && _locks[key] != owner) return false;
    _locks[key] = owner;
    _eventController.add(BlackboardEvent.now(
      BlackboardEventType.lock,
      key,
      newValue: owner,
      source: owner,
    ));
    return true;
  }

  bool unlock(String key, String owner) {
    if (_locks[key] != owner) return false;
    _locks.remove(key);
    _eventController.add(BlackboardEvent.now(
      BlackboardEventType.unlock,
      key,
      source: owner,
    ));
    return true;
  }

  bool isLocked(String key) => _locks.containsKey(key);

  Map<String, dynamic> snapshot() => Map.unmodifiable(_state);

  void clear() {
    _state.clear();
    _locks.clear();
  }

  void dispose() {
    _eventController.close();
  }
}

class BlackboardKeys {
  static const String projectId = 'project.id';
  static const String projectTitle = 'project.title';
  static const String projectTheme = 'project.theme';

  static const String scriptSource = 'script.source';
  static const String scriptSummary = 'script.summary';
  static const String scriptStatus = 'script.status';

  static const String characters = 'characters.list';
  static const String characterAnchors = 'characters.anchors';
  static const String characterStatus = 'characters.status';

  static const String storyboardShots = 'storyboard.shots';
  static const String storyboardStatus = 'storyboard.status';

  static const String shotVideos = 'shots.videos';
  static const String shotStatus = 'shots.status';

  static const String voiceLines = 'voice.lines';
  static const String voiceTimeline = 'voice.timeline';
  static const String voiceStatus = 'voice.status';

  static const String composedVideo = 'compose.video';
  static const String composeStatus = 'compose.status';

  static const String publishedExport = 'publish.export';
  static const String publishStatus = 'publish.status';

  static const String pipelineStage = 'pipeline.currentStage';
  static const String pipelineProgress = 'pipeline.progress';
  static const String error = 'error.last';
}
