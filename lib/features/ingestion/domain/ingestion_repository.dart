import 'ingestion_models.dart';

abstract interface class IngestionRepository {
  Future<IngestionResult> ingest(IngestionSource source);
}

class IngestionException implements Exception {
  const IngestionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'IngestionException: $message';
}

class FileSizeExceededException extends IngestionException {
  const FileSizeExceededException(int actual, int limit)
    : super('文件大小 ${actual ~/ 1024}KB 超过限制 ${limit ~/ 1024}KB');
}

class UnsupportedFormatException extends IngestionException {
  const UnsupportedFormatException(String format)
    : super('不支持的文件格式：$format');
}
