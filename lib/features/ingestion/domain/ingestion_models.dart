enum IngestionSourceType {
  txt,
  md,
  docx,
  json,
  novel,
  prompt,
}

extension IngestionSourceTypeX on IngestionSourceType {
  String get label => switch (this) {
    IngestionSourceType.txt => 'TXT 文本',
    IngestionSourceType.md => 'Markdown 文档',
    IngestionSourceType.docx => 'Word 文档',
    IngestionSourceType.json => 'JSON 结构化',
    IngestionSourceType.novel => '小说原文',
    IngestionSourceType.prompt => 'AI 提示词',
  };

  static IngestionSourceType? fromExtension(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    return switch (e) {
      'txt' => IngestionSourceType.txt,
      'md' || 'markdown' => IngestionSourceType.md,
      'docx' => IngestionSourceType.docx,
      'json' => IngestionSourceType.json,
      _ => null,
    };
  }

  static IngestionSourceType? fromContentType(String? contentType) {
    if (contentType == null) return null;
    if (contentType.contains('text/plain')) return IngestionSourceType.txt;
    if (contentType.contains('markdown')) return IngestionSourceType.md;
    if (contentType.contains('application/json')) return IngestionSourceType.json;
    if (contentType.contains('word')) return IngestionSourceType.docx;
    return null;
  }
}

class IngestionSource {
  const IngestionSource({
    required this.type,
    required this.fileName,
    required this.content,
    this.size,
  });

  final IngestionSourceType type;
  final String fileName;
  final String content;
  final int? size;

  bool get isEmpty => content.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;
}

class ChapterOutline {
  const ChapterOutline({
    required this.title,
    required this.content,
    this.shotCount = 0,
  });

  final String title;
  final String content;
  final int shotCount;
}

class CharacterEntity {
  const CharacterEntity({
    required this.name,
    this.description,
    this.appearance,
  });

  final String name;
  final String? description;
  final String? appearance;
}

class IngestionResult {
  const IngestionResult({
    required this.source,
    required this.chapters,
    this.characters = const [],
    this.suggestedTitle,
    this.suggestedLogline,
    this.suggestedStyle,
  });

  final IngestionSource source;
  final List<ChapterOutline> chapters;
  final List<CharacterEntity> characters;
  final String? suggestedTitle;
  final String? suggestedLogline;
  final String? suggestedStyle;

  String get combinedText => chapters.map((c) => c.content).join('\n\n');
  bool get hasCharacters => characters.isNotEmpty;
}
