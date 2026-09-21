import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class CryptoUtils {
  static final Random _random = Random.secure();

  /// Generates cryptographically secure random bytes
  static Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Generates a 32-byte salt
  static Uint8List generateSalt() {
    return generateRandomBytes(32);
  }

  /// Derives a key from a PIN and salt using PBKDF2 with HMAC-SHA256
  static Future<Uint8List> deriveKey(String pin, Uint8List salt, {int iterations = 600000}) async {
    return await Isolate.run(() {
      final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
      
      // Convert pin to bytes (UTF-8)
      final pinBytes = Uint8List.fromList(pin.codeUnits);
      
      derivator.init(Pbkdf2Parameters(salt, iterations, 32)); // 32 bytes = 256 bits output
      
      return derivator.process(pinBytes);
    });
  }

  /// Encrypts data using AES-256-GCM
  /// Returns a tuple of (ciphertext, iv)
  static (Uint8List, Uint8List) aesGcmEncrypt(Uint8List plaintext, Uint8List key) {
    final iv = generateRandomBytes(12); // 96-bit IV is standard for GCM
    
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // true = encrypt
        AEADParameters(
          KeyParameter(key),
          128, // macSize in bits
          iv,
          Uint8List(0), // empty AAD
        ),
      );
      
    final ciphertext = cipher.process(plaintext);
    return (ciphertext, iv);
  }

  /// Decrypts data using AES-256-GCM
  static Uint8List aesGcmDecrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false, // false = decrypt
        AEADParameters(
          KeyParameter(key),
          128, // macSize in bits
          iv,
          Uint8List(0), // empty AAD
        ),
      );
      
    return cipher.process(ciphertext);
  }
}
