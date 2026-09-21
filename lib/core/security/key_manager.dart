import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class KeyManager {
  static final _random = Random.secure();

  /// Generates a new ECDSA P-256 keypair
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateECDSAKeyPair() {
    final domainParams = ECDomainParameters('prime256v1');
    final secureRandom = SecureRandom('Fortuna')
      ..seed(KeyParameter(
          Uint8List.fromList(List.generate(32, (_) => _random.nextInt(256)))));

    final keyParams = ECKeyGeneratorParameters(domainParams);
    final params = ParametersWithRandom(keyParams, secureRandom);

    final keyGenerator = ECKeyGenerator()..init(params);

    return keyGenerator.generateKeyPair();
  }

  /// Encodes ECPublicKey to JWK format (JSON string)
  static String encodePublicKeyToJwk(ECPublicKey publicKey) {
    final q = publicKey.Q;
    if (q == null) throw Exception('Public key point Q is null');
    
    final x = q.x!.toBigInteger()!;
    final y = q.y!.toBigInteger()!;

    final jwk = {
      'kty': 'EC',
      'crv': 'P-256',
      'x': _base64UrlEncode(x),
      'y': _base64UrlEncode(y),
    };

    return jsonEncode(jwk);
  }

  /// Decodes ECPublicKey from JWK format
  static ECPublicKey decodePublicKeyFromJwk(String jwkJson) {
    final jwk = jsonDecode(jwkJson) as Map<String, dynamic>;
    if (jwk['kty'] != 'EC' || jwk['crv'] != 'P-256') {
      throw Exception('Invalid JWK format');
    }

    final x = _base64UrlDecode(jwk['x'] as String);
    final y = _base64UrlDecode(jwk['y'] as String);

    final domainParams = ECDomainParameters('prime256v1');
    final q = domainParams.curve.createPoint(x, y);

    return ECPublicKey(q, domainParams);
  }

  /// Encodes ECPrivateKey to raw bytes
  static Uint8List encodePrivateKey(ECPrivateKey privateKey) {
    final d = privateKey.d;
    if (d == null) throw Exception('Private key d is null');
    final bytes = _bigIntToBytes(d);
    // Pad to 32 bytes for P-256
    final paddedBytes = Uint8List(32);
    final offset = 32 - bytes.length;
    for (int i = 0; i < bytes.length; i++) {
      if (i + offset >= 0 && i + offset < 32) {
        paddedBytes[i + offset] = bytes[i];
      }
    }
    return paddedBytes;
  }

  /// Decodes ECPrivateKey from raw bytes
  static ECPrivateKey decodePrivateKey(Uint8List bytes) {
    final d = _bytesToBigInt(bytes);
    final domainParams = ECDomainParameters('prime256v1');
    return ECPrivateKey(d, domainParams);
  }

  // --- Helper Methods ---

  static String _base64UrlEncode(BigInt number) {
    final bytes = _bigIntToBytes(number);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static BigInt _base64UrlDecode(String base64UrlString) {
    var padded = base64UrlString;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    final bytes = base64Url.decode(padded);
    return _bytesToBigInt(bytes);
  }

  static Uint8List _bigIntToBytes(BigInt number) {
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }
    final len = hex.length ~/ 2;
    final result = Uint8List(len);
    for (int i = 0; i < len; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var hex = '';
    for (final b in bytes) {
      hex += b.toRadixString(16).padLeft(2, '0');
    }
    return BigInt.parse(hex, radix: 16);
  }
}
