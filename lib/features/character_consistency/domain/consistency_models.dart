class CharacterIdentity {
  const CharacterIdentity({
    required this.id,
    required this.name,
    this.appearanceDescription,
    this.personalityDescription,
    this.anchorImageUrl,
    this.anchorFeatures,
    this.voiceId,
    this.driftThreshold = 0.15,
  });

  final String id;
  final String name;
  final String? appearanceDescription;
  final String? personalityDescription;
  final String? anchorImageUrl;
  final Map<String, dynamic>? anchorFeatures;
  final String? voiceId;
  final double driftThreshold;

  bool get hasAnchor => anchorImageUrl != null && anchorFeatures != null;

  CharacterIdentity copyWith({
    String? id,
    String? name,
    String? appearanceDescription,
    String? personalityDescription,
    String? anchorImageUrl,
    Map<String, dynamic>? anchorFeatures,
    String? voiceId,
    double? driftThreshold,
  }) => CharacterIdentity(
    id: id ?? this.id,
    name: name ?? this.name,
    appearanceDescription: appearanceDescription ?? this.appearanceDescription,
    personalityDescription: personalityDescription ?? this.personalityDescription,
    anchorImageUrl: anchorImageUrl ?? this.anchorImageUrl,
    anchorFeatures: anchorFeatures ?? this.anchorFeatures,
    voiceId: voiceId ?? this.voiceId,
    driftThreshold: driftThreshold ?? this.driftThreshold,
  );

  factory CharacterIdentity.fromJson(Map<String, dynamic> json) =>
      CharacterIdentity(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        appearanceDescription: json['appearance_description'] as String?,
        personalityDescription: json['personality_description'] as String?,
        anchorImageUrl: json['anchor_image_url'] as String?,
        anchorFeatures: json['anchor_features'] as Map<String, dynamic>?,
        voiceId: json['voice_id'] as String?,
        driftThreshold: (json['drift_threshold'] as num?)?.toDouble() ?? 0.15,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'appearance_description': appearanceDescription,
    'personality_description': personalityDescription,
    'anchor_image_url': anchorImageUrl,
    'anchor_features': anchorFeatures,
    'voice_id': voiceId,
    'drift_threshold': driftThreshold,
  };
}

class ConsistencyAnchor {
  const ConsistencyAnchor({
    required this.characterId,
    required this.anchorImageUrl,
    required this.createdAt,
    this.features,
    this.referencePrompt,
  });

  final String characterId;
  final String anchorImageUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? features;
  final String? referencePrompt;

  ConsistencyAnchor copyWith({
    String? characterId,
    String? anchorImageUrl,
    DateTime? createdAt,
    Map<String, dynamic>? features,
    String? referencePrompt,
  }) => ConsistencyAnchor(
    characterId: characterId ?? this.characterId,
    anchorImageUrl: anchorImageUrl ?? this.anchorImageUrl,
    createdAt: createdAt ?? this.createdAt,
    features: features ?? this.features,
    referencePrompt: referencePrompt ?? this.referencePrompt,
  );
}

class DriftCheckResult {
  const DriftCheckResult({
    required this.characterId,
    required this.imageUrl,
    required this.driftScore,
    required this.isConsistent,
    this.threshold,
    this.detail,
  });

  final String characterId;
  final String imageUrl;
  final double driftScore;
  final bool isConsistent;
  final double? threshold;
  final String? detail;

  factory DriftCheckResult.fromJson(Map<String, dynamic> json) =>
      DriftCheckResult(
        characterId: json['character_id'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        driftScore: (json['drift_score'] as num?)?.toDouble() ?? 0,
        isConsistent: json['is_consistent'] as bool? ?? true,
        threshold: (json['threshold'] as num?)?.toDouble(),
        detail: json['detail'] as String?,
      );
}

class ConsistencyGenerationRequest {
  const ConsistencyGenerationRequest({
    required this.characterId,
    required this.prompt,
    required this.sceneContext,
    this.aspectRatio = '9:16',
    this.strength = 0.85,
  });

  final String characterId;
  final String prompt;
  final String sceneContext;
  final String aspectRatio;
  final double strength;

  Map<String, dynamic> toJson() => {
    'character_id': characterId,
    'prompt': prompt,
    'scene_context': sceneContext,
    'aspect_ratio': aspectRatio,
    'strength': strength,
  };
}
