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
    const aOptions = AndroidOptions();
    final storedKey = await _storage.read(key: key, aOptions: aOptions);
    if (storedKey != null) {
      return storedKey;
    }
    
    // Create new key
    final newKey = dbKeyGenerator();
    await _storage.write(key: key, value: newKey, aOptions: aOptions);
    return newKey;
  }

  // --- Operator Keys Management ---

  Future<void> storeWrappedPrivateKey({
    required String operatorId,
    required Uint8List wrappedKey,
    required Uint8List iv,
  }) async {
    const aOptions = AndroidOptions();
    await _storage.write(
      key: 'wrapped_private_key_$operatorId',
      value: base64Encode(wrappedKey),
      aOptions: aOptions,
    );
    await _storage.write(
      key: 'wrap_iv_$operatorId',
      value: base64Encode(iv),
      aOptions: aOptions,
    );
  }

  Future<(Uint8List, Uint8List)?> getWrappedPrivateKey(String operatorId) async {
    const aOptions = AndroidOptions();
    final wrappedStr = await _storage.read(key: 'wrapped_private_key_$operatorId', aOptions: aOptions);
    final ivStr = await _storage.read(key: 'wrap_iv_$operatorId', aOptions: aOptions);
    
    if (wrappedStr == null || ivStr == null) return null;
    
    return (base64Decode(wrappedStr), base64Decode(ivStr));
  }

  // --- Biometric Wrap Key ---

  Future<bool> enrollBiometricWrapKey(String operatorId, Uint8List wrapKey) async {
    final canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canAuthenticate) return false;

    // Prompt user to verify biometrics before enrolling
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify biometrics to enable Biometric Unlock',
      );
      if (!authenticated) return false;
    } catch (e) {
      return false;
    }

    // We store the wrap key in secure storage.
    // On iOS, we gate it at the OS level using accessibility settings.
    // On Android, we gate it manually via LocalAuthentication before reading.
    await _storage.write(
      key: 'biometric_wrap_key_$operatorId',
      value: base64Encode(wrapKey),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.passcode,
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

  Future<bool> hasBiometricWrapKey(String operatorId) async {
    final keyStr = await _storage.read(
      key: 'biometric_wrap_key_$operatorId',
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.passcode,
      ),
      aOptions: const AndroidOptions(),
    );
    return keyStr != null;
  }

  Future<void> clearBiometricWrapKey(String operatorId) async {
    const aOptions = AndroidOptions();
    await _storage.delete(
      key: 'biometric_wrap_key_$operatorId',
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.passcode,
      ),
      aOptions: aOptions,
    );
  }

  // --- Escrow Status ---

  Future<void> setEscrowUploaded(String operatorId, bool status) async {
    const aOptions = AndroidOptions();
    await _storage.write(
      key: 'narcos_escrow_uploaded_$operatorId',
      value: status.toString(),
      aOptions: aOptions,
    );
  }

  Future<bool> isEscrowUploaded(String operatorId) async {
    const aOptions = AndroidOptions();
    final val = await _storage.read(key: 'narcos_escrow_uploaded_$operatorId', aOptions: aOptions);
    return val == 'true';
  }
}
