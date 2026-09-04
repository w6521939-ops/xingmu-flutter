import 'consistency_models.dart';

class CharacterExtractor {
  static List<CharacterIdentity> extract(String scriptText) {
    final identities = <String, CharacterIdentity>{};

    final dialoguePattern = RegExp(
      r'[「」（()【\[]\s*([^」」）)】\]\s]{2,10})\s*[:：]',
    );
    for (final match in dialoguePattern.allMatches(scriptText)) {
      final name = match.group(1)!.trim();
      if (_isValidName(name) && !identities.containsKey(name)) {
        identities[name] = CharacterIdentity(
          id: _generateId(name),
          name: name,
        );
      }
    }

    final narrationPattern = RegExp(
      r'([\u4e00-\u9fa5]{2,4})(说|道|问|答|笑|怒|喊|叫|叹)',
    );
    for (final match in narrationPattern.allMatches(scriptText)) {
      final name = match.group(1)!.trim();
      if (_isValidName(name) && !identities.containsKey(name)) {
        identities[name] = CharacterIdentity(
          id: _generateId(name),
          name: name,
        );
      }
    }

    final descriptionPattern = RegExp(
      r'([\u4e00-\u9fa5]{2,4})(身穿|戴着|留着|长着|穿着)',
    );
    for (final match in descriptionPattern.allMatches(scriptText)) {
      final name = match.group(1)!.trim();
      final existing = identities[name];
      if (existing != null) {
        final startIdx = match.end;
        final endIdx = scriptText.indexOf('。', startIdx);
        final description = endIdx > startIdx
            ? scriptText.substring(startIdx, endIdx)
            : scriptText.substring(startIdx, startIdx + 30);

        identities[name] = existing.copyWith(
          appearanceDescription: description.trim(),
        );
      }
    }

    return identities.values.toList();
  }

  static bool _isValidName(String name) {
    if (name.length < 2 || name.length > 10) return false;
    final blacklist = {'说道', '回答', '说道', '然后', '于是', '但是', '因为', '所以'};
    if (blacklist.contains(name)) return false;
    return RegExp(r'^[\u4e00-\u9fa5a-zA-Z]+$').hasMatch(name);
  }

  static String _generateId(String name) {
    final hash = name.hashCode.toUnsigned(32);
    return 'char_${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
