import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fieldapp/core/security/crypto_utils.dart';

void main() {
  group('CryptoUtils Tests', () {
    test('generateRandomBytes should return bytes of correct length', () {
      final bytes = CryptoUtils.generateRandomBytes(32);
      expect(bytes.length, 32);
    });

    test('generateSalt should return 32 bytes', () {
      final salt = CryptoUtils.generateSalt();
      expect(salt.length, 32);
    });

    test('deriveKey should produce consistent keys for same PIN and salt', () {
      final pin = '123456';
      final salt = CryptoUtils.generateSalt();
      
      final key1 = CryptoUtils.deriveKey(pin, salt);
      final key2 = CryptoUtils.deriveKey(pin, salt);
      
      expect(key1, equals(key2));
      expect(key1.length, 32);
    });

    test('aesGcmEncrypt and aesGcmDecrypt should work symmetrically', () {
      final key = CryptoUtils.generateSalt(); // 32 bytes
      final plaintext = Uint8List.fromList('secret_data'.codeUnits);
      
      final (ciphertext, iv) = CryptoUtils.aesGcmEncrypt(plaintext, key);
      expect(ciphertext, isNot(equals(plaintext)));
      
      final decrypted = CryptoUtils.aesGcmDecrypt(ciphertext, key, iv);
      expect(decrypted, equals(plaintext));
    });
  });
}
