import 'package:flutter/foundation.dart';

import '../domain/consistency_models.dart';
import '../domain/consistency_repository.dart';
import '../domain/character_extractor.dart';

class ConsistencyController extends ChangeNotifier {
  ConsistencyController({ConsistencyRepository? repository})
    : _repository = repository;

  final ConsistencyRepository? _repository;

  final Map<String, CharacterIdentity> _identities = {};
  final Map<String, ConsistencyAnchor> _anchors = {};
  final Map<String, DriftCheckResult> _driftResults = {};

  bool _isProcessing = false;
  String? _errorMessage;

  List<CharacterIdentity> get identities => _identities.values.toList();
  List<ConsistencyAnchor> get anchors => _anchors.values.toList();
  List<DriftCheckResult> get driftResults => _driftResults.values.toList();
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  CharacterIdentity? getIdentity(String characterId) =>
      _identities[characterId];

  ConsistencyAnchor? getAnchor(String characterId) =>
      _anchors[characterId];

  DriftCheckResult? getDriftResult(String imageKey) =>
      _driftResults[imageKey];

  List<CharacterIdentity> extractFromScript(String scriptText) {
    final extracted = CharacterExtractor.extract(scriptText);
    for (final identity in extracted) {
      _identities[identity.id] = identity;
    }
    notifyListeners();
    return extracted;
  }

  Future<CharacterIdentity?> createAnchor(CreateAnchorRequest request) async {
    final repo = _repository;
    if (repo == null) {
      _errorMessage = '未配置一致性服务后端';
      notifyListeners();
      return null;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final identity = await repo.createAnchor(request);
      _identities[identity.id] = identity;
      _anchors[identity.id] = ConsistencyAnchor(
        characterId: identity.id,
        anchorImageUrl: identity.anchorImageUrl!,
        createdAt: DateTime.now(),
        features: identity.anchorFeatures,
        referencePrompt: request.referencePrompt,
      );
      _isProcessing = false;
      notifyListeners();
      return identity;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst(
        RegExp(r'^ConsistencyException:\s*'),
        '',
      );
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<DriftCheckResult?> checkDrift(DriftCheckRequest request) async {
    final repo = _repository;
    if (repo == null) {
      _errorMessage = '未配置一致性服务后端';
      notifyListeners();
      return null;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await repo.checkDrift(request);
      _driftResults[request.imageUrl] = result;
      _isProcessing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst(
        RegExp(r'^ConsistencyException:\s*'),
        '',
      );
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> generateConsistent(
    ConsistencyGenerationRequest request,
  ) async {
    final repo = _repository;
    if (repo == null) {
      _errorMessage = '未配置一致性服务后端';
      notifyListeners();
      return null;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final imageUrl = await repo.generateConsistent(request);
      final drift = await repo.checkDrift(DriftCheckRequest(
        characterId: request.characterId,
        imageUrl: imageUrl,
      ));
      _driftResults[imageUrl] = drift;
      _isProcessing = false;
      notifyListeners();
      return imageUrl;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst(
        RegExp(r'^ConsistencyException:\s*'),
        '',
      );
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  void bindVoice(String characterId, String voiceId) {
    final identity = _identities[characterId];
    if (identity == null) return;
    _identities[characterId] = identity.copyWith(voiceId: voiceId);
    notifyListeners();
  }

  void clear() {
    _identities.clear();
    _anchors.clear();
    _driftResults.clear();
    _errorMessage = null;
    _isProcessing = false;
    notifyListeners();
  }
}
