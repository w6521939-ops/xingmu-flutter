class StudioValidationException implements Exception {
  const StudioValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class ThemeValidator {
  static const int minLength = 4;
  static const int maxLength = 300;

  static String validate(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      throw const StudioValidationException('请输入漫剧主题');
    }
    if (normalized.runes.length < minLength) {
      throw const StudioValidationException('主题至少需要 4 个字符');
    }
    if (normalized.runes.length > maxLength) {
      throw const StudioValidationException('主题不能超过 300 个字符');
    }
    return normalized;
  }
}
