import 'package:flutter/foundation.dart';

import '../domain/keyring_models.dart';
import '../domain/keyring_repository.dart';

class KeyringController extends ChangeNotifier {
  KeyringController({required KeyringRepository repository})
    : _repository = repository;

  final KeyringRepository _repository;
  bool _disposed = false;

  bool _isInitialized = false;
  bool _isUnlocked = false;
  bool _isBusy = false;
  String? _errorMessage;
  List<CredentialEntry> _entries = [];
  List<KeyringAuditLog> _auditLogs = [];
  EncryptionAlgorithm _algorithm = EncryptionAlgorithm.aes256Gcm;

  bool get isInitialized => _isInitialized;
  bool get isUnlocked => _isUnlocked;
  bool get isBusy => _isBusy;
  bool get hasEntries => _entries.isNotEmpty;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  List<CredentialEntry> get entries => List.unmodifiable(_entries);
  List<KeyringAuditLog> get auditLogs => List.unmodifiable(_auditLogs);
  EncryptionAlgorithm get algorithm => _algorithm;

  Future<void> checkStatus() async {
    _setBusy(true);
    try {
      _isInitialized = await _repository.isVaultInitialized();
      _isUnlocked = _repository.isUnlocked;
      if (_isUnlocked) {
        _entries = await _repository.listCredentials();
        _auditLogs = await _repository.getAuditLogs();
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setBusy(false);
  }

  Future<bool> initializeVault(String masterPassword) async {
    _setBusy(true);
    try {
      await _repository.initializeVault(
        masterPassword: masterPassword,
        algorithm: _algorithm,
      );
      _isInitialized = true;
      _isUnlocked = true;
      _entries = await _repository.listCredentials();
      _auditLogs = await _repository.getAuditLogs();
      _errorMessage = null;
      _notify();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setBusy(false);
      return false;
    }
  }

  Future<bool> unlockVault(String masterPassword) async {
    _setBusy(true);
    try {
      final success = await _repository.unlockVault(masterPassword);
      if (success) {
        _isUnlocked = true;
        _entries = await _repository.listCredentials();
        _auditLogs = await _repository.getAuditLogs();
        _errorMessage = null;
      } else {
        _errorMessage = '主密码不正确';
      }
      _setBusy(false);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _setBusy(false);
      return false;
    }
  }

  Future<void> lockVault() async {
    try {
      await _repository.lockVault();
      _isUnlocked = false;
      _entries = [];
      _errorMessage = null;
      _notify();
    } catch (e) {
      _errorMessage = e.toString();
      _notify();
    }
  }

  Future<bool> addCredential({
    required CredentialProvider provider,
    required String envKey,
    required String apiKey,
    String? displayName,
    String? workspaceId,
    String? endpoint,
  }) async {
    _setBusy(true);
    try {
      final entry = CredentialEntry(
        id: '',
        provider: provider,
        envKey: envKey,
        encryptedValue: apiKey,
        displayName: displayName,
        workspaceId: workspaceId,
        endpoint: endpoint,
      );
      await _repository.saveCredential(entry);
      _entries = await _repository.listCredentials();
      _auditLogs = await _repository.getAuditLogs();
      _errorMessage = null;
      _setBusy(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setBusy(false);
      return false;
    }
  }

  Future<bool> updateCredential(CredentialEntry entry) async {
    _setBusy(true);
    try {
      await _repository.saveCredential(entry);
      _entries = await _repository.listCredentials();
      _auditLogs = await _repository.getAuditLogs();
      _errorMessage = null;
      _setBusy(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setBusy(false);
      return false;
    }
  }

  Future<bool> deleteCredential(String id) async {
    _setBusy(true);
    try {
      await _repository.deleteCredential(id);
      _entries = await _repository.listCredentials();
      _auditLogs = await _repository.getAuditLogs();
      _errorMessage = null;
      _setBusy(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setBusy(false);
      return false;
    }
  }

  Future<CredentialStatus> verifyCredential(String id) async {
    _setBusy(true);
    try {
      final status = await _repository.verifyCredential(id);
      _entries = await _repository.listCredentials();
      _auditLogs = await _repository.getAuditLogs();
      _errorMessage = null;
      _setBusy(false);
      return status;
    } catch (e) {
      _errorMessage = e.toString();
      _setBusy(false);
      return CredentialStatus.invalid;
    }
  }

  Future<String> exportEnvFile() async {
    try {
      _auditLogs = await _repository.getAuditLogs();
      _notify();
      return await _repository.exportEnvFile();
    } catch (e) {
      _errorMessage = e.toString();
      _notify();
      rethrow;
    }
  }

  Future<int> importFromEnvFile(String content) async {
    _setBusy(true);
    try {
      final count = await _repository.importFromEnvFile(content);
      _entries = await _repository.listCredentials();
      _auditLogs = await _repository.getAuditLogs();
      _errorMessage = null;
      _setBusy(false);
      return count;
    } catch (e) {
      _errorMessage = e.toString();
      _setBusy(false);
      return 0;
    }
  }

  void setAlgorithm(EncryptionAlgorithm algorithm) {
    _algorithm = algorithm;
    _notify();
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  void _setBusy(bool busy) {
    _isBusy = busy;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
