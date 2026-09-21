import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/security/crypto_utils.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/security/secure_storage_service.dart';
import 'package:pointycastle/export.dart';

class AuthRepository {
  final DatabaseService _dbService;
  final SecureStorageService _secureStorage;

  AuthRepository({
    DatabaseService? dbService,
    SecureStorageService? secureStorage,
  })  : _dbService = dbService ?? DatabaseService(),
        _secureStorage = secureStorage ?? SecureStorageService();

  /// Registers a new operator and performs first-run bootstrap.
  /// Returns the `wrap_key` to be kept in memory for the session.
  Future<Uint8List> registerOperator({
    required String operatorId,
    required String name,
    required String rank,
    required String jurisdiction,
    required String pin,
  }) async {
    final db = await _dbService.database;
    
    // Check if operator already exists
    final exists = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM credentials WHERE operator_id = ?', [operatorId])
    );
    if (exists != null && exists > 0) {
      throw Exception('Operator ID already exists');
    }

    // 1. Generate salts
    final pinSalt = CryptoUtils.generateSalt();
    final wrapSalt = CryptoUtils.generateSalt();
    final recoverySalt = CryptoUtils.generateSalt();

    // 2. Derive keys
    final pinHash = await CryptoUtils.deriveKey(pin, pinSalt);
    final wrapKey = await CryptoUtils.deriveKey(pin, wrapSalt);
    final recoveryKey = await CryptoUtils.deriveKey(pin, recoverySalt);

    // 3. Generate ECDSA keypair and wrap private key
    final keyPair = KeyManager.generateECDSAKeyPair();
    final privateKeyBytes = KeyManager.encodePrivateKey(keyPair.privateKey as ECPrivateKey);
    final publicKeyJwk = KeyManager.encodePublicKeyToJwk(keyPair.publicKey as ECPublicKey);

    final (wrappedPrivateKey, wrapIv) = CryptoUtils.aesGcmEncrypt(privateKeyBytes, wrapKey);

    // 4. Encrypt wrap_key with recovery_key (Escrow)
    final (encryptedWrapKey, recoveryIv) = CryptoUtils.aesGcmEncrypt(wrapKey, recoveryKey);

    // 5. Store wrapped private key in secure storage
    await _secureStorage.storeWrappedPrivateKey(
      operatorId: operatorId,
      wrappedKey: wrappedPrivateKey,
      iv: wrapIv,
    );

    // 6. DB Transaction
    await db.transaction((txn) async {
      // Write credentials
      await txn.insert('credentials', {
        'operator_id': operatorId,
        'name': name,
        'rank': rank,
        'jurisdiction': jurisdiction,
        'pin_hash': pinHash,
        'pin_salt': pinSalt,
        'wrap_salt': wrapSalt,
        'recovery_salt': recoverySalt,
        'failed_attempts': 0,
      });

      // Write public key
      await txn.insert('keys', {
        'operator_id': operatorId,
        'public_key_jwk': publicKeyJwk,
      });

      // Queue Escrow Upload
      final escrowPayload = jsonEncode({
        'operator_id': operatorId,
        'recovery_salt': base64Encode(recoverySalt),
        'recovery_iv': base64Encode(recoveryIv),
        'encrypted_wrap_key': base64Encode(encryptedWrapKey),
        'public_key_jwk': publicKeyJwk,
      });
      
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'type': 'key_escrow',
        'payload': escrowPayload,
        'queued_at': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
        'attempts': 0,
      });
    });

    // Mark escrow as not uploaded
    await _secureStorage.setEscrowUploaded(operatorId, false);

    // Return wrapKey so it can be held in memory for the current session
    return wrapKey;
  }

  /// Attempts to login an operator. 
  /// Throws an exception if failed (e.g. invalid PIN or locked out).
  /// Returns the `wrap_key` upon success.
  Future<Uint8List> login(String operatorId, String pin) async {
    final db = await _dbService.database;

    final result = await db.query(
      'credentials',
      where: 'operator_id = ?',
      whereArgs: [operatorId],
    );

    if (result.isEmpty) {
      throw Exception('Operator not found');
    }

    final creds = result.first;
    final lockedUntil = creds['locked_until'] as int?;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lockedUntil != null && lockedUntil > now) {
      final remainingMins = ((lockedUntil - now) / 60000).ceil();
      throw Exception('Account locked. Try again in \$remainingMins minutes.');
    }

    final pinSalt = creds['pin_salt'] as Uint8List;
    final wrapSalt = creds['wrap_salt'] as Uint8List;
    final storedPinHash = creds['pin_hash'] as Uint8List;
    
    final computedPinHash = await CryptoUtils.deriveKey(pin, pinSalt);

    bool isMatch = _constantTimeCompare(computedPinHash, storedPinHash);

    if (isMatch) {
      // Reset failed attempts
      await db.update(
        'credentials',
        {
          'failed_attempts': 0,
          'locked_until': null,
        },
        where: 'operator_id = ?',
        whereArgs: [operatorId],
      );

      final wrapKey = await CryptoUtils.deriveKey(pin, wrapSalt);
      return wrapKey;
    } else {
      // Handle failed attempt
      final attempts = (creds['failed_attempts'] as int? ?? 0) + 1;
      final updates = <String, dynamic>{'failed_attempts': attempts};
      
      if (attempts >= 3) {
        updates['locked_until'] = now + (30 * 60 * 1000); // Lock for 30 mins
      }

      await db.update(
        'credentials',
        updates,
        where: 'operator_id = ?',
        whereArgs: [operatorId],
      );

      if (attempts >= 3) {
        throw Exception('Account locked for 30 minutes due to multiple failed attempts.');
      } else {
        throw Exception('Invalid PIN');
      }
    }
  }

  /// Helper to prevent timing attacks when comparing hashes
  bool _constantTimeCompare(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
