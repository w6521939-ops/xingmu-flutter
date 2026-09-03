import 'dart:convert';

import '../domain/ingestion_models.dart';
import '../domain/ingestion_repository.dart';

class FileIngestionRepository implements IngestionRepository {
  static const int maxSize = 1024 * 1024;
  static const int _minContentLength = 20;

  @override
  Future<IngestionResult> ingest(IngestionSource source) async {
    if (source.content.isEmpty) {
      throw const IngestionException('文件内容为空');
    }

    if (source.size != null && source.size! > maxSize) {
      throw FileSizeExceededException(source.size!, maxSize);
    }

    return switch (source.type) {
      IngestionSourceType.txt => _parseTxt(source),
      IngestionSourceType.md => _parseMd(source),
      IngestionSourceType.json => _parseJson(source),
      IngestionSourceType.docx => _parseDocx(source),
      IngestionSourceType.novel => _parseNovel(source),
      IngestionSourceType.prompt => _parsePrompt(source),
    };
  }

  IngestionResult _parseTxt(IngestionSource source) {
    final paragraphs = source.content
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      throw const IngestionException('TXT 文件中没有有效内容');
    }

    final chapters = <ChapterOutline>[];
    String? title;
    var chapterIdx = 0;

    for (final para in paragraphs) {
      final isChapterTitle = _looksLikeChapterTitle(para);
      if (isChapterTitle && title == null) {
        title = para;
        continue;
      }
      if (isChapterTitle) {
        chapters.add(ChapterOutline(
          title: title ?? '第${chapters.length + 1}章',
          content: para,
          shotCount: _estimateShotCount(para),
        ));
        chapterIdx++;
        title = para;
      } else if (title != null && chapters.isNotEmpty) {
        final last = chapters.last;
        chapters[last.shotCount == 0 ? 0 : chapters.length - 1] = ChapterOutline(
          title: last.title,
          content: '${last.content}\n\n$para',
          shotCount: _estimateShotCount('${last.content}\n\n$para'),
        );
      } else {
        chapters.add(ChapterOutline(
          title: title ?? '第${chapters.length + 1}章',
          content: para,
          shotCount: _estimateShotCount(para),
        ));
        title = null;
      }
    }

    return IngestionResult(
      source: source,
      chapters: chapters,
      suggestedTitle: title ?? _extractTitle(paragraphs.first),
      characters: _extractCharacters(paragraphs),
      suggestedStyle: _guessStyle(source.content),
    );
  }

  IngestionResult _parseMd(IngestionSource source) {
    final lines = source.content.split('\n');
    final chapters = <ChapterOutline>[];
    var currentTitle = '引言';
    final currentContent = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      final isHeader = trimmed.startsWith('#');

      if (isHeader) {
        if (currentContent.isNotEmpty) {
          chapters.add(ChapterOutline(
            title: currentTitle,
            content: currentContent.toString().trim(),
            shotCount: _estimateShotCount(currentContent.toString()),
          ));
          currentContent.clear();
        }
        currentTitle = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
      } else {
        currentContent.writeln(line);
      }
    }

    if (currentContent.isNotEmpty) {
      chapters.add(ChapterOutline(
        title: currentTitle,
        content: currentContent.toString().trim(),
        shotCount: _estimateShotCount(currentContent.toString()),
      ));
    }

    if (chapters.isEmpty) {
      throw const IngestionException('Markdown 文件中没有有效内容');
    }

    return IngestionResult(
      source: source,
      chapters: chapters,
      suggestedTitle: chapters.first.title,
      characters: _extractCharacters([source.content]),
      suggestedStyle: _guessStyle(source.content),
    );
  }

  IngestionResult _parseJson(IngestionSource source) {
    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(source.content) as Map<String, dynamic>;
    } catch (e) {
      throw IngestionException('JSON 解析失败：${e.toString()}', cause: e);
    }

    final title = data['title']?.toString() ?? '';
    final logline = data['logline']?.toString();
    final styleBible = data['style_bible']?.toString() ?? data['styleBible']?.toString();
    final synopsis = data['episode_synopsis']?.toString() ?? data['episodeSynopsis']?.toString() ?? '';

    final chapters = <ChapterOutline>[];
    final scenesList = data['scenes'] as List? ?? data['chapters'] as List?;
    if (scenesList != null) {
      for (final scene in scenesList) {
        if (scene is! Map) continue;
        chapters.add(ChapterOutline(
          title: scene['title']?.toString() ?? '第${chapters.length + 1}场',
          content: scene['content']?.toString() ?? scene['description']?.toString() ?? '',
          shotCount: _estimateShotCount(scene['content']?.toString() ?? ''),
        ));
      }
    }

    if (chapters.isEmpty && synopsis.isNotEmpty) {
      chapters.add(ChapterOutline(
        title: title.isNotEmpty ? title : '第1章',
        content: synopsis,
        shotCount: _estimateShotCount(synopsis),
      ));
    }

    if (chapters.isEmpty) {
      throw const IngestionException('JSON 文件中没有可用的剧本数据');
    }

    final characters = <CharacterEntity>[];
    final charList = data['characters'] as List?;
    if (charList != null) {
      for (final char in charList) {
        if (char is! Map) continue;
        characters.add(CharacterEntity(
          name: char['name']?.toString() ?? '',
          description: char['description']?.toString(),
          appearance: char['appearance']?.toString(),
        ));
      }
    }

    return IngestionResult(
      source: source,
      chapters: chapters,
      characters: characters,
      suggestedTitle: title,
      suggestedLogline: logline,
      suggestedStyle: styleBible,
    );
  }

  IngestionResult _parseDocx(IngestionSource source) {
    throw const UnsupportedFormatException('docx 需要后端解析，请在设置中配置服务器地址');
  }

  IngestionResult _parseNovel(IngestionSource source) {
    final paragraphs = source.content
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      throw const IngestionException('小说内容为空');
    }

    final chapters = <ChapterOutline>[];
    var currentChapter = StringBuffer();
    var chapterTitle = '第1章';

    for (final para in paragraphs) {
      if (_looksLikeChapterTitle(para)) {
        if (currentChapter.isNotEmpty) {
          chapters.add(ChapterOutline(
            title: chapterTitle,
            content: currentChapter.toString().trim(),
            shotCount: _estimateShotCount(currentChapter.toString()),
          ));
          currentChapter.clear();
        }
        chapterTitle = para;
      } else {
        currentChapter.writeln(para);
      }
    }

    if (currentChapter.isNotEmpty) {
      chapters.add(ChapterOutline(
        title: chapterTitle,
        content: currentChapter.toString().trim(),
        shotCount: _estimateShotCount(currentChapter.toString()),
      ));
    }

    return IngestionResult(
      source: source,
      chapters: chapters,
      characters: _extractCharacters(paragraphs),
      suggestedTitle: chapterTitle,
      suggestedStyle: '小说改编',
    );
  }

  IngestionResult _parsePrompt(IngestionSource source) {
    if (source.content.trim().length < _minContentLength) {
      throw const IngestionException('提示词过短，至少需要 20 个字符');
    }

    return IngestionResult(
      source: source,
      chapters: [
        ChapterOutline(
          title: 'AI 提示词',
          content: source.content,
          shotCount: _estimateShotCount(source.content),
        ),
      ],
      suggestedTitle: _extractTitle(source.content),
    );
  }

  bool _looksLikeChapterTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.length > 50) return false;
    return RegExp(r'^(第[一二三四五六七八九十\d]+[章节回])').hasMatch(trimmed) ||
        RegExp(r'^#+\s').hasMatch(trimmed) ||
        RegExp(r'^Chapter\s+\d+', caseSensitive: false).hasMatch(trimmed);
  }

  String _extractTitle(String text) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.length <= 30) return firstLine;
    return firstLine.substring(0, 30);
  }

  List<CharacterEntity> _extractCharacters(List<String> paragraphs) {
    final characters = <String, CharacterEntity>{};
    final dialoguePattern = RegExp(r'[「」（()【\[]\s*([^」」）)】\]]{2,10})\s*[:：]');

    for (final para in paragraphs) {
      for (final match in dialoguePattern.allMatches(para)) {
        final name = match.group(1)!.trim();
        if (name.length >= 2 && name.length <= 10 && !characters.containsKey(name)) {
          characters[name] = CharacterEntity(name: name);
        }
      }
    }

    return characters.values.toList();
  }

  int _estimateShotCount(String content) {
    final length = content.length;
    if (length < 100) return 2;
    if (length < 300) return 4;
    if (length < 600) return 6;
    return (length / 100).ceil().clamp(2, 20);
  }

  String _guessStyle(String content) {
    if (RegExp(r'[剑侠江湖武林]').hasMatch(content)) return '国风厚涂';
    if (RegExp(r'[宇宙星际飞船太空]').hasMatch(content)) return '科幻赛博';
    if (RegExp(r'[校园青春教室]').hasMatch(content)) return '日系清新';
    return '国风厚涂';
  }
}
