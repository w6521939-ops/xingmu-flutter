import 'dart:convert';

import 'keyring_models.dart';

abstract interface class KeyringRepository {
  Future<bool> isVaultInitialized();

  Future<void> initializeVault({
    required String masterPassword,
    EncryptionAlgorithm algorithm = EncryptionAlgorithm.aes256Gcm,
  });

  Future<bool> unlockVault(String masterPassword);

  Future<void> lockVault();

  bool get isUnlocked;

  Future<List<CredentialEntry>> listCredentials();

  Future<CredentialEntry> saveCredential(CredentialEntry entry);

  Future<void> deleteCredential(String id);

  Future<CredentialEntry?> getCredential(String id);

  Future<CredentialStatus> verifyCredential(String id);

  Future<String> decryptValue(String encryptedValue);

  Future<String> encryptValue(String plaintext);

  Future<Map<String, String>> exportEnvMap();

  Future<String> exportEnvFile();

  Future<int> importFromEnvFile(String content);

  Future<List<KeyringAuditLog>> getAuditLogs();

  Future<void> clearAll();
}

class InMemoryKeyringRepository implements KeyringRepository {
  InMemoryKeyringRepository();

  KeyringVault _vault = KeyringVault(entries: []);
  bool _unlocked = false;
  String? _masterPassword;
  final List<KeyringAuditLog> _auditLogs = [];
  int _idCounter = 0;

  @override
  bool get isUnlocked => _unlocked;

  @override
  Future<bool> isVaultInitialized() async => _vault.isInitialized;

  @override
  Future<void> initializeVault({
    required String masterPassword,
    EncryptionAlgorithm algorithm = EncryptionAlgorithm.aes256Gcm,
  }) async {
    if (_vault.isInitialized) {
      throw StateError('密钥库已初始化');
    }
    if (masterPassword.length < 8) {
      throw ArgumentError('主密码至少 8 位');
    }

    final salt = _generateSalt();
    final hash = _hashPassword(masterPassword, salt);

    _vault = KeyringVault(
      entries: [],
      masterKeyHash: hash,
      saltHex: salt,
      algorithm: algorithm,
      createdAt: DateTime.now(),
      lastAccessed: DateTime.now(),
    );
    _masterPassword = masterPassword;
    _unlocked = true;

    _auditLogs.add(KeyringAuditLog(
      action: KeyringAction.vaultInit,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<bool> unlockVault(String masterPassword) async {
    if (!_vault.isInitialized) {
      throw StateError('密钥库尚未初始化');
    }

    final hash = _hashPassword(masterPassword, _vault.saltHex!);
    if (hash != _vault.masterKeyHash) {
      return false;
    }

    _masterPassword = masterPassword;
    _unlocked = true;
    _vault = _vault.copyWith(lastAccessed: DateTime.now());

    _auditLogs.add(KeyringAuditLog(
      action: KeyringAction.vaultUnlock,
      timestamp: DateTime.now(),
    ));

    return true;
  }

  @override
  Future<void> lockVault() async {
    _unlocked = false;
    _masterPassword = null;

    _auditLogs.add(KeyringAuditLog(
      action: KeyringAction.vaultLock,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<List<CredentialEntry>> listCredentials() async {
    _ensureUnlocked();
    return List.unmodifiable(_vault.entries);
  }

  @override
  Future<CredentialEntry> saveCredential(CredentialEntry entry) async {
    _ensureUnlocked();

    final now = DateTime.now();
    final encrypted = await encryptValue(entry.encryptedValue);

    final saved = entry.copyWith(
      encryptedValue: encrypted,
      createdAt: entry.createdAt ?? now,
      updatedAt: now,
    );

    final idx = _vault.entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _vault.entries[idx] = saved;
      _auditLogs.add(KeyringAuditLog(
        action: KeyringAction.credentialUpdate,
        timestamp: now,
        entryId: entry.id,
        provider: entry.provider,
      ));
    } else {
      final newEntry = saved.copyWith(
        id: entry.id.isEmpty ? 'cred-${_idCounter++}' : entry.id,
      );
      _vault.entries.add(newEntry);
      _auditLogs.add(KeyringAuditLog(
        action: KeyringAction.credentialAdd,
        timestamp: now,
        entryId: newEntry.id,
        provider: entry.provider,
      ));
    }

    return saved;
  }

  @override
  Future<void> deleteCredential(String id) async {
    _ensureUnlocked();
    final entry = _vault.entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw StateError('凭据不存在: $id'),
    );
    _vault.entries.removeWhere((e) => e.id == id);
    _auditLogs.add(KeyringAuditLog(
      action: KeyringAction.credentialDelete,
      timestamp: DateTime.now(),
      entryId: id,
      provider: entry.provider,
    ));
  }

  @override
  Future<CredentialEntry?> getCredential(String id) async {
    _ensureUnlocked();
    for (final entry in _vault.entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<CredentialStatus> verifyCredential(String id) async {
    _ensureUnlocked();
    final entry = await getCredential(id);
    if (entry == null) return CredentialStatus.notSet;

    try {
      final decrypted = await decryptValue(entry.encryptedValue);
      if (decrypted.isEmpty) {
        final updated = entry.copyWith(
          status: CredentialStatus.invalid,
          lastVerified: DateTime.now(),
        );
        _updateEntry(updated);
        return CredentialStatus.invalid;
      }

      final updated = entry.copyWith(
        status: CredentialStatus.valid,
        lastVerified: DateTime.now(),
      );
      _updateEntry(updated);

      _auditLogs.add(KeyringAuditLog(
        action: KeyringAction.credentialVerify,
        timestamp: DateTime.now(),
        entryId: id,
        provider: entry.provider,
      ));

      return CredentialStatus.valid;
    } catch (_) {
      final updated = entry.copyWith(
        status: CredentialStatus.invalid,
        lastVerified: DateTime.now(),
      );
      _updateEntry(updated);
      return CredentialStatus.invalid;
    }
  }

  @override
  Future<String> decryptValue(String encryptedValue) async {
    _ensureUnlocked();
    if (encryptedValue.isEmpty) return '';

    try {
      final result = EncryptionResult.fromCombined(encryptedValue);
      return _simpleDecrypt(result.ciphertext, result.nonce);
    } catch (_) {
      return encryptedValue;
    }
  }

  @override
  Future<String> encryptValue(String plaintext) async {
    _ensureUnlocked();
    if (plaintext.isEmpty) return '';

    final nonce = _generateNonce();
    final ciphertext = _simpleEncrypt(plaintext, nonce);
    return EncryptionResult(ciphertext: ciphertext, nonce: nonce).combined;
  }

  @override
  Future<Map<String, String>> exportEnvMap() async {
    _ensureUnlocked();
    final map = <String, String>{};
    for (final entry in _vault.entries) {
      if (entry.hasValue) {
        final decrypted = await decryptValue(entry.encryptedValue);
        map[entry.envKey] = decrypted;
      }
    }
    _auditLogs.add(KeyringAuditLog(
      action: KeyringAction.exportEnv,
      timestamp: DateTime.now(),
    ));
    return map;
  }

  @override
  Future<String> exportEnvFile() async {
    final envMap = await exportEnvMap();
    final buffer = StringBuffer();
    buffer.writeln('# 星幕工坊 API 密钥配置');
    buffer.writeln('# 由 Keyring 加密存储生成');
    buffer.writeln('# 请勿提交到版本控制');
    buffer.writeln();
    for (final entry in envMap.entries) {
      buffer.writeln('${entry.key}=${entry.value}');
    }
    return buffer.toString();
  }

  @override
  Future<int> importFromEnvFile(String content) async {
    _ensureUnlocked();
    var count = 0;
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx < 0) continue;
      final key = trimmed.substring(0, eqIdx).trim();
      final value = trimmed.substring(eqIdx + 1).trim();
      if (value.isEmpty) continue;

      final existing = _vault.entries
          .where((e) => e.envKey == key)
          .firstOrNull;

      if (existing != null) {
        final encrypted = await encryptValue(value);
        _updateEntry(existing.copyWith(
          encryptedValue: encrypted,
          status: CredentialStatus.unverified,
          updatedAt: DateTime.now(),
        ));
      } else {
        final encrypted = await encryptValue(value);
        final entry = CredentialEntry(
          id: 'cred-${_idCounter++}',
          provider: _guessProvider(key),
          envKey: key,
          encryptedValue: encrypted,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _vault.entries.add(entry);
      }
      count++;
    }

    _auditLogs.add(KeyringAuditLog(
      action: KeyringAction.importEnv,
      timestamp: DateTime.now(),
      detail: '导入了 $count 条凭据',
    ));

    return count;
  }

  @override
  Future<List<KeyringAuditLog>> getAuditLogs() async {
    return List.unmodifiable(_auditLogs);
  }

  @override
  Future<void> clearAll() async {
    _vault = KeyringVault(entries: []);
    _masterPassword = null;
    _unlocked = false;
    _auditLogs.clear();
  }

  void _ensureUnlocked() {
    if (!_unlocked) {
      throw StateError('密钥库已锁定，请先解锁');
    }
  }

  void _updateEntry(CredentialEntry updated) {
    final idx = _vault.entries.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      _vault.entries[idx] = updated;
    }
  }

  CredentialProvider _guessProvider(String envKey) {
    final upper = envKey.toUpperCase();
    if (upper.contains('DASHSCOPE') || upper.contains('BAILIAN')) {
      return CredentialProvider.dashscope;
    }
    if (upper.contains('OPENAI') && !upper.contains('AZURE')) {
      return CredentialProvider.openai;
    }
    if (upper.contains('ANTHROPIC')) {
      return CredentialProvider.anthropic;
    }
    if (upper.contains('AZURE')) {
      return CredentialProvider.azure;
    }
    return CredentialProvider.custom;
  }

  String _generateSalt() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return random.toRadixString(16).padLeft(16, '0');
  }

  String _generateNonce() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = (now * 31 + 7) % 0xFFFFFFFF;
    return random.toRadixString(16).padLeft(8, '0');
  }

  String _hashPassword(String password, String salt) {
    var hash = 0x811c9dc5;
    final combined = '$password:$salt';
    for (final char in combined.codeUnits) {
      hash ^= char;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _simpleEncrypt(String plaintext, String nonce) {
    final key = _masterPassword ?? '';
    final keyBytes = key.codeUnits;
    final nonceBytes = nonce.codeUnits;
    final result = StringBuffer();

    for (var i = 0; i < plaintext.length; i++) {
      final keyByte = keyBytes[i % keyBytes.length];
      final nonceByte = nonceBytes[i % nonceBytes.length];
      result.write(plaintext.codeUnitAt(i) ^ keyByte ^ nonceByte ^ 0x55);
      result.write('|');
    }

    return base64Encode(result.toString().codeUnits);
  }

  String _simpleDecrypt(String ciphertext, String nonce) {
    final key = _masterPassword ?? '';
    final nonceBytes = nonce.codeUnits;
    final decoded = String.fromCharCodes(base64Decode(ciphertext).toList());
    final parts = decoded.split('|').where((s) => s.isNotEmpty).toList();
    final keyBytes = key.codeUnits;
    final result = StringBuffer();

    for (var i = 0; i < parts.length; i++) {
      final value = int.tryParse(parts[i]);
      if (value == null) continue;
      final keyByte = keyBytes[i % keyBytes.length];
      final nonceByte = nonceBytes[i % nonceBytes.length];
      result.writeCharCode(value ^ keyByte ^ nonceByte ^ 0x55);
    }

    return result.toString();
  }
}
