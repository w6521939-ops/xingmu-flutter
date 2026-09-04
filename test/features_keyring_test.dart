import 'package:flutter_test/flutter_test.dart';
import 'package:xingmu_ai_video_studio/features/keyring/domain/keyring_models.dart';

void main() {
  group('CredentialEntry', () {
    test('fromJson and toJson round-trip', () {
      final original = CredentialEntry(
        id: 'cred-001',
        provider: CredentialProvider.dashscope,
        envKey: 'DASHSCOPE_API_KEY',
        encryptedValue: 'enc-abc123',
        displayName: '百炼主账号',
        status: CredentialStatus.valid,
        createdAt: DateTime.parse('2026-09-04T10:00:00Z'),
        updatedAt: DateTime.parse('2026-09-04T10:00:00Z'),
      );

      final json = original.toJson();
      final restored = CredentialEntry.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.provider, original.provider);
      expect(restored.envKey, original.envKey);
      expect(restored.encryptedValue, original.encryptedValue);
      expect(restored.displayName, original.displayName);
      expect(restored.status, original.status);
    });

    test('hasValue and isComplete', () {
      final entry = CredentialEntry(
        id: 'c1',
        provider: CredentialProvider.openai,
        envKey: 'OPENAI_API_KEY',
        encryptedValue: 'enc-value',
      );

      expect(entry.hasValue, isTrue);
      expect(entry.isComplete, isTrue);

      final empty = CredentialEntry(
        id: 'c2',
        provider: CredentialProvider.openai,
        envKey: '',
        encryptedValue: '',
      );

      expect(empty.hasValue, isFalse);
      expect(empty.isComplete, isFalse);
    });
  });

  group('CredentialProvider', () {
    test('all providers have labels', () {
      for (final p in CredentialProvider.values) {
        expect(p.label, isNotEmpty);
      }
    });

    test('requiredEnvKeys', () {
      expect(CredentialProvider.dashscope.requiredEnvKeys, ['DASHSCOPE_API_KEY']);
      expect(CredentialProvider.bailian.requiredEnvKeys,
          ['DASHSCOPE_API_KEY', 'BAILIAN_WORKSPACE_ID']);
      expect(CredentialProvider.custom.requiredEnvKeys, isEmpty);
    });

    test('defaultEnvKey', () {
      expect(CredentialProvider.dashscope.defaultEnvKey, 'DASHSCOPE_API_KEY');
      expect(CredentialProvider.custom.defaultEnvKey, 'CUSTOM_API_KEY');
    });
  });

  group('CredentialStatus', () {
    test('isOk only for valid', () {
      expect(CredentialStatus.valid.isOk, isTrue);
      expect(CredentialStatus.expired.isOk, isFalse);
      expect(CredentialStatus.notSet.isOk, isFalse);
    });

    test('needsAttention excludes valid and notSet', () {
      expect(CredentialStatus.expired.needsAttention, isTrue);
      expect(CredentialStatus.invalid.needsAttention, isTrue);
      expect(CredentialStatus.valid.needsAttention, isFalse);
      expect(CredentialStatus.notSet.needsAttention, isFalse);
    });
  });

  group('KeyringVault', () {
    test('isInitialized requires both hash and salt', () {
      final empty = KeyringVault(entries: []);
      expect(empty.isInitialized, isFalse);

      final initialized = KeyringVault(
        entries: [],
        masterKeyHash: 'hash',
        saltHex: 'salt',
      );
      expect(initialized.isInitialized, isTrue);
    });

    test('findByProvider returns matching entry', () {
      final vault = KeyringVault(entries: [
        CredentialEntry(
          id: 'c1',
          provider: CredentialProvider.dashscope,
          envKey: 'DASHSCOPE_API_KEY',
          encryptedValue: 'enc',
        ),
        CredentialEntry(
          id: 'c2',
          provider: CredentialProvider.openai,
          envKey: 'OPENAI_API_KEY',
          encryptedValue: 'enc2',
        ),
      ]);

      final found = vault.findByProvider(CredentialProvider.openai);
      expect(found, isNotNull);
      expect(found!.id, 'c2');

      expect(vault.findByProvider(CredentialProvider.anthropic), isNull);
    });

    test('toEnvMap decrypts all entries', () {
      final vault = KeyringVault(entries: [
        CredentialEntry(
          id: 'c1',
          provider: CredentialProvider.dashscope,
          envKey: 'DASHSCOPE_API_KEY',
          encryptedValue: 'enc1',
        ),
      ]);

      final env = vault.toEnvMap((enc) => 'decrypted-$enc');
      expect(env['DASHSCOPE_API_KEY'], 'decrypted-enc1');
    });
  });

  group('EncryptionAlgorithm', () {
    test('supportsAead', () {
      expect(EncryptionAlgorithm.aes256Gcm.supportsAead, isTrue);
      expect(EncryptionAlgorithm.chacha20Poly1305.supportsAead, isTrue);
      expect(EncryptionAlgorithm.aes256Cbc.supportsAead, isFalse);
    });
  });

  group('EncryptionResult', () {
    test('fromCombined parses 3 parts', () {
      const combined = 'cipher:nonce:tag';
      final result = EncryptionResult.fromCombined(combined);

      expect(result.ciphertext, 'cipher');
      expect(result.nonce, 'nonce');
      expect(result.tag, 'tag');
    });

    test('fromCombined parses 2 parts', () {
      const combined = 'cipher:nonce';
      final result = EncryptionResult.fromCombined(combined);

      expect(result.ciphertext, 'cipher');
      expect(result.nonce, 'nonce');
      expect(result.tag, isNull);
    });

    test('fromCombined throws on invalid format', () {
      expect(
        () => EncryptionResult.fromCombined('invalid'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('KeyringAction', () {
    test('all actions have labels', () {
      for (final action in KeyringAction.values) {
        expect(action.label, isNotEmpty);
      }
    });
  });
}
