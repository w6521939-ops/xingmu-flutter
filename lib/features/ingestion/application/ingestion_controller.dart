import 'package:flutter/foundation.dart';

import '../../domain/ingestion_models.dart';
import '../../domain/ingestion_repository.dart';
import '../../data/file_ingestion_repository.dart';

class IngestionController extends ChangeNotifier {
  IngestionController({IngestionRepository? repository})
    : _repository = repository ?? FileIngestionRepository();

  final IngestionRepository _repository;

  IngestionResult? _result;
  bool _isLoading = false;
  String? _errorMessage;

  IngestionResult? get result => _result;
  bool get isLoading => _isLoading;
  bool get hasResult => _result != null;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  Future<IngestionResult> ingestFile({
    required String fileName,
    required String content,
    int? size,
  }) async {
    final ext = fileName.contains('.') ? '.${fileName.split('.').last}' : '.txt';
    final type = IngestionSourceTypeX.fromExtension(ext) ??
        IngestionSourceTypeX.fromContentType(null) ??
        IngestionSourceType.txt;

    final source = IngestionSource(
      type: type,
      fileName: fileName,
      content: content,
      size: size ?? content.length,
    );

    return _ingest(source);
  }

  Future<IngestionResult> ingestText({
    required String text,
    IngestionSourceType type = IngestionSourceType.novel,
  }) async {
    final source = IngestionSource(
      type: type,
      fileName: type.label,
      content: text,
      size: text.length,
    );

    return _ingest(source);
  }

  Future<IngestionResult> ingestPrompt(String prompt) async {
    final source = IngestionSource(
      type: IngestionSourceType.prompt,
      fileName: 'AI 提示词',
      content: prompt,
      size: prompt.length,
    );

    return _ingest(source);
  }

  Future<IngestionResult> _ingest(IngestionSource source) async {
    _isLoading = true;
    _errorMessage = null;
    _result = null;
    notifyListeners();

    try {
      final result = await _repository.ingest(source);
      _result = result;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst(
        RegExp(r'^IngestionException:\s*'),
        '',
      );
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _result = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
