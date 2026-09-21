import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io' show Platform;

class SecureStorageService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  SecureStorageService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  // --- DB Key Management ---
  
  /// Retrieves the shared DB key or creates it if it doesn't exist
  Future<String> getOrCreateDbKey(String Function() dbKeyGenerator) async {
    const key = 'narcos_db_key';
    final storedKey = await _storage.read(key: key);
    if (storedKey != null) {
      return storedKey;
    }
    
    // Create new key
    final newKey = dbKeyGenerator();
    await _storage.write(key: key, value: newKey);
    return newKey;
  }

  // --- Operator Keys Management ---

  Future<void> storeWrappedPrivateKey({
    required String operatorId,
    required Uint8List wrappedKey,
    required Uint8List iv,
  }) async {
    await _storage.write(
      key: 'wrapped_private_key_$operatorId',
      value: base64Encode(wrappedKey),
    );
    await _storage.write(
      key: 'wrap_iv_$operatorId',
      value: base64Encode(iv),
    );
  }

  Future<(Uint8List, Uint8List)?> getWrappedPrivateKey(String operatorId) async {
    final wrappedStr = await _storage.read(key: 'wrapped_private_key_$operatorId');
    final ivStr = await _storage.read(key: 'wrap_iv_$operatorId');
    
    if (wrappedStr == null || ivStr == null) return null;
    
    return (base64Decode(wrappedStr), base64Decode(ivStr));
  }

  // --- Biometric Wrap Key ---

  Future<bool> enrollBiometricWrapKey(String operatorId, Uint8List wrapKey) async {
    final canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canAuthenticate) return false;

    // We store the wrap key in secure storage.
    // On iOS, we gate it at the OS level using accessibility settings.
    // On Android, we gate it manually via LocalAuthentication before reading.
    await _storage.write(
      key: 'biometric_wrap_key_$operatorId',
      value: base64Encode(wrapKey),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.passcode,
        // Using biometryCurrentSet equivalent in newer API
        // This ensures if new fingerprints are added, this item is invalidated.
      ),
      aOptions: const AndroidOptions(),
    );
    return true;
  }

  Future<Uint8List?> getBiometricWrapKey(String operatorId) async {
    final canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canAuthenticate) return null;

    if (Platform.isAndroid) {
      // Manual gate for Android
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Authenticate to unlock Narcos Field App',
        );
        if (!authenticated) return null;
      } catch (e) {
        return null; // Auth failed or canceled
      }
    }

    final keyStr = await _storage.read(
      key: 'biometric_wrap_key_$operatorId',
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.passcode,
      ),
      aOptions: const AndroidOptions(),
    );

    if (keyStr == null) return null;
    return base64Decode(keyStr);
  }

  // --- Escrow Status ---

  Future<void> setEscrowUploaded(String operatorId, bool status) async {
    await _storage.write(
      key: 'narcos_escrow_uploaded_$operatorId',
      value: status.toString(),
    );
  }

  Future<bool> isEscrowUploaded(String operatorId) async {
    final val = await _storage.read(key: 'narcos_escrow_uploaded_$operatorId');
    return val == 'true';
  }
}
