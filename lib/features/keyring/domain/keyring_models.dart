enum CredentialProvider {
  dashscope,
  bailian,
  openai,
  anthropic,
  azure,
  custom;

  String get label => switch (this) {
    CredentialProvider.dashscope => '通义千问/DashScope',
    CredentialProvider.bailian => '百炼平台',
    CredentialProvider.openai => 'OpenAI',
    CredentialProvider.anthropic => 'Anthropic',
    CredentialProvider.azure => 'Azure OpenAI',
    CredentialProvider.custom => '自定义',
  };

  String get icon => switch (this) {
    CredentialProvider.dashscope => 'smart_toy',
    CredentialProvider.bailian => 'cloud',
    CredentialProvider.openai => 'auto_awesome',
    CredentialProvider.anthropic => 'psychology',
    CredentialProvider.azure => 'microsoft',
    CredentialProvider.custom => 'settings',
  };

  List<String> get requiredEnvKeys => switch (this) {
    CredentialProvider.dashscope => ['DASHSCOPE_API_KEY'],
    CredentialProvider.bailian => ['DASHSCOPE_API_KEY', 'BAILIAN_WORKSPACE_ID'],
    CredentialProvider.openai => ['OPENAI_API_KEY'],
    CredentialProvider.anthropic => ['ANTHROPIC_API_KEY'],
    CredentialProvider.azure => ['AZURE_OPENAI_KEY', 'AZURE_OPENAI_ENDPOINT'],
    CredentialProvider.custom => [],
  };

  String get defaultEnvKey => requiredEnvKeys.isEmpty
      ? 'CUSTOM_API_KEY'
      : requiredEnvKeys.first;
}

enum CredentialStatus {
  valid,
  expired,
  invalid,
  unverified,
  notSet;

  String get label => switch (this) {
    CredentialStatus.valid => '有效',
    CredentialStatus.expired => '已过期',
    CredentialStatus.invalid => '无效',
    CredentialStatus.unverified => '未验证',
    CredentialStatus.notSet => '未设置',
  };

  bool get isOk => this == CredentialStatus.valid;
  bool get needsAttention => this != CredentialStatus.valid &&
      this != CredentialStatus.notSet;
}

class CredentialEntry {
  CredentialEntry({
    required this.id,
    required this.provider,
    required this.envKey,
    required this.encryptedValue,
    this.displayName,
    this.workspaceId,
    this.endpoint,
    this.status = CredentialStatus.unverified,
    this.lastVerified,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final CredentialProvider provider;
  final String envKey;
  final String encryptedValue;
  final String? displayName;
  final String? workspaceId;
  final String? endpoint;
  final CredentialStatus status;
  final DateTime? lastVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasValue => encryptedValue.isNotEmpty;
  bool get isComplete => hasValue && envKey.isNotEmpty;

  CredentialEntry copyWith({
    String? id,
    CredentialProvider? provider,
    String? envKey,
    String? encryptedValue,
    String? displayName,
    String? workspaceId,
    String? endpoint,
    CredentialStatus? status,
    DateTime? lastVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CredentialEntry(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    envKey: envKey ?? this.envKey,
    encryptedValue: encryptedValue ?? this.encryptedValue,
    displayName: displayName ?? this.displayName,
    workspaceId: workspaceId ?? this.workspaceId,
    endpoint: endpoint ?? this.endpoint,
    status: status ?? this.status,
    lastVerified: lastVerified ?? this.lastVerified,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider.name,
    'env_key': envKey,
    'encrypted_value': encryptedValue,
    'display_name': displayName,
    'workspace_id': workspaceId,
    'endpoint': endpoint,
    'status': status.name,
    'last_verified': lastVerified?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory CredentialEntry.fromJson(Map<String, dynamic> json) {
    return CredentialEntry(
      id: json['id'] as String? ?? '',
      provider: CredentialProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => CredentialProvider.custom,
      ),
      envKey: json['env_key'] as String? ?? '',
      encryptedValue: json['encrypted_value'] as String? ?? '',
      displayName: json['display_name'] as String?,
      workspaceId: json['workspace_id'] as String?,
      endpoint: json['endpoint'] as String?,
      status: CredentialStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CredentialStatus.unverified,
      ),
      lastVerified: json['last_verified'] != null
          ? DateTime.tryParse(json['last_verified'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class KeyringVault {
  KeyringVault({
    required this.entries,
    this.masterKeyHash,
    this.saltHex,
    this.algorithm = EncryptionAlgorithm.aes256Gcm,
    this.createdAt,
    this.lastAccessed,
  });

  final List<CredentialEntry> entries;
  final String? masterKeyHash;
  final String? saltHex;
  final EncryptionAlgorithm algorithm;
  final DateTime? createdAt;
  final DateTime? lastAccessed;

  bool get isInitialized => masterKeyHash != null && saltHex != null;
  bool get hasEntries => entries.isNotEmpty;

  CredentialEntry? findByProvider(CredentialProvider provider) {
    for (final entry in entries) {
      if (entry.provider == provider && entry.hasValue) return entry;
    }
    return null;
  }

  CredentialEntry? findByEnvKey(String envKey) {
    for (final entry in entries) {
      if (entry.envKey == envKey && entry.hasValue) return entry;
    }
    return null;
  }

  Map<String, String> toEnvMap(String Function(String encrypted) decrypt) {
    final map = <String, String>{};
    for (final entry in entries) {
      if (entry.hasValue) {
        map[entry.envKey] = decrypt(entry.encryptedValue);
      }
    }
    return map;
  }

  KeyringVault copyWith({
    List<CredentialEntry>? entries,
    String? masterKeyHash,
    String? saltHex,
    EncryptionAlgorithm? algorithm,
    DateTime? createdAt,
    DateTime? lastAccessed,
  }) => KeyringVault(
    entries: entries ?? this.entries,
    masterKeyHash: masterKeyHash ?? this.masterKeyHash,
    saltHex: saltHex ?? this.saltHex,
    algorithm: algorithm ?? this.algorithm,
    createdAt: createdAt ?? this.createdAt,
    lastAccessed: lastAccessed ?? this.lastAccessed,
  );
}

enum EncryptionAlgorithm {
  aes256Gcm,
  chacha20Poly1305,
  aes256Cbc;

  String get label => switch (this) {
    EncryptionAlgorithm.aes256Gcm => 'AES-256-GCM',
    EncryptionAlgorithm.chacha20Poly1305 => 'ChaCha20-Poly1305',
    EncryptionAlgorithm.aes256Cbc => 'AES-256-CBC',
  };

  String get description => switch (this) {
    EncryptionAlgorithm.aes256Gcm => 'AES-256 GCM 模式，提供加密和完整性验证',
    EncryptionAlgorithm.chacha20Poly1305 => 'ChaCha20-Poly1305，移动端性能优异',
    EncryptionAlgorithm.aes256Cbc => 'AES-256 CBC 模式，兼容性最佳',
  };

  bool get supportsAead => this != EncryptionAlgorithm.aes256Cbc;
}

class EncryptionResult {
  const EncryptionResult({
    required this.ciphertext,
    required this.nonce,
    this.tag,
  });

  final String ciphertext;
  final String nonce;
  final String? tag;

  String get combined => tag != null
      ? '$ciphertext:$nonce:$tag'
      : '$ciphertext:$nonce';

  static EncryptionResult fromCombined(String combined) {
    final parts = combined.split(':');
    if (parts.length == 2) {
      return EncryptionResult(ciphertext: parts[0], nonce: parts[1]);
    }
    if (parts.length == 3) {
      return EncryptionResult(ciphertext: parts[0], nonce: parts[1], tag: parts[2]);
    }
    throw FormatException('无效的加密结果格式');
  }
}

class KeyringAuditLog {
  KeyringAuditLog({
    required this.action,
    required this.timestamp,
    this.entryId,
    this.provider,
    this.detail,
  });

  final KeyringAction action;
  final DateTime timestamp;
  final String? entryId;
  final CredentialProvider? provider;
  final String? detail;

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'timestamp': timestamp.toIso8601String(),
    'entry_id': entryId,
    'provider': provider?.name,
    'detail': detail,
  };
}

enum KeyringAction {
  vaultInit,
  vaultUnlock,
  vaultLock,
  credentialAdd,
  credentialUpdate,
  credentialDelete,
  credentialVerify,
  exportEnv,
  importEnv;

  String get label => switch (this) {
    KeyringAction.vaultInit => '初始化密钥库',
    KeyringAction.vaultUnlock => '解锁密钥库',
    KeyringAction.vaultLock => '锁定密钥库',
    KeyringAction.credentialAdd => '添加凭据',
    KeyringAction.credentialUpdate => '更新凭据',
    KeyringAction.credentialDelete => '删除凭据',
    KeyringAction.credentialVerify => '验证凭据',
    KeyringAction.exportEnv => '导出环境变量',
    KeyringAction.importEnv => '导入环境变量',
  };
}
