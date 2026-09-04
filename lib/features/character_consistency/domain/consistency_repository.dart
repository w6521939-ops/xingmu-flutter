import 'consistency_models.dart';

abstract interface class ConsistencyRepository {
  Future<CharacterIdentity> createAnchor(CreateAnchorRequest request);
  Future<DriftCheckResult> checkDrift(DriftCheckRequest request);
  Future<String> generateConsistent(ConsistencyGenerationRequest request);
  Future<List<CharacterIdentity>> extractCharacters(String scriptText);
  Future<Map<String, dynamic>> computeFeatures(String imageUrl);
}

class CreateAnchorRequest {
  const CreateAnchorRequest({
    required this.characterId,
    required this.name,
    this.appearanceDescription,
    this.personalityDescription,
    this.referencePrompt,
    this.aspectRatio = '9:16',
  });

  final String characterId;
  final String name;
  final String? appearanceDescription;
  final String? personalityDescription;
  final String? referencePrompt;
  final String aspectRatio;

  Map<String, dynamic> toJson() => {
    'character_id': characterId,
    'name': name,
    'appearance_description': appearanceDescription,
    'personality_description': personalityDescription,
    'reference_prompt': referencePrompt,
    'aspect_ratio': aspectRatio,
  };
}

class DriftCheckRequest {
  const DriftCheckRequest({
    required this.characterId,
    required this.imageUrl,
    this.threshold,
  });

  final String characterId;
  final String imageUrl;
  final double? threshold;

  Map<String, dynamic> toJson() => {
    'character_id': characterId,
    'image_url': imageUrl,
    if (threshold != null) 'threshold': threshold,
  };
}

class ConsistencyException implements Exception {
  const ConsistencyException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ConsistencyException: $message';
}
