import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../../../core/database/database_service.dart';
import '../../../core/security/crypto_utils.dart';
import '../../auth/providers/session_provider.dart';
import '../../analysis/domain/fusion_result.dart';
import '../domain/canonical_json.dart';
import '../domain/device_fingerprint.dart';
import '../domain/location_service.dart';
import '../domain/record_model.dart';

class KeyNotFoundException implements Exception {
  final String message;
  KeyNotFoundException(this.message);
  @override
  String toString() => 'KeyNotFoundException: $message';
}
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(this.message);
  @override
  String toString() => 'SessionExpiredException: $message';
}

class RecordService {
  final DatabaseService _dbService = DatabaseService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<FieldRecord> createAndSignRecord({
    required String operatorId,
    required String jurisdiction,
    required FusionResult fusionResult,
    required Uint8List? wrapKey,
    required String rawImagePath,
  }) async {
    if (wrapKey == null) {
      throw SessionExpiredException('Session lock cleared wrap_key. Please re-authenticate to sign this record.');
    }

    // 1. Gather Metadata
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;
    const schemaVersion = '1.0';

    final now = DateTime.now();
    final utc = now.toUtc();
    final offsetSeconds = now.timeZoneOffset.inSeconds;
    final sign = offsetSeconds >= 0 ? '+' : '-';
    final hours = (offsetSeconds.abs() ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((offsetSeconds.abs() % 3600) ~/ 60).toString().padLeft(2, '0');
    final localIso = '\${now.toIso8601String()}$sign$hours:$minutes';

    final locationData = await LocationService.captureLocation();
    final fingerprint = await DeviceFingerprint.generate();

    // 2. Hash Images
    final rawHash = await _hashImageFile(rawImagePath);
    final calHash = await _hashImageFile(fusionResult.calibratedImagePath);

    // 3. Extract and Sanitize FusionData
    final fusionDataMap = _serializeFusionResult(fusionResult);

    final db = await _dbService.database;
    FieldRecord? finalRecord;

    await db.transaction((txn) async {
      // 4. Atomic ID Generation inside transaction
      final recordId = await _generateRecordId(txn, jurisdiction, operatorId);

      // 5. Phase 1 — Build signable payload
      final phase1Map = {
        'recordId': recordId,
        'operatorId': operatorId,
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'timestampUtcMs': utc.millisecondsSinceEpoch,
        'timestampIso8601': utc.toIso8601String(),
        'timestampLocal': localIso,
        'timezone': now.timeZoneName,
        'location': locationData.toMap(),
        'deviceFingerprint': fingerprint,
        'rawImageHash': rawHash,
        'calibratedImageHash': calHash,
        'fusionData': fusionDataMap,
      };

      final canonicalBytes = CanonicalJson.encode(phase1Map);
      final hashBytes = sha256.convert(canonicalBytes).bytes;
      final recordHashHex = hex.encode(hashBytes);

      // 6. Sign
      final signatureBase64 = await _signHash(operatorId, wrapKey, Uint8List.fromList(hashBytes));

      // 7. Phase 2 — Build final stored record
      final finalMap = Map<String, dynamic>.from(phase1Map)
        ..['recordHash'] = recordHashHex
        ..['signature'] = signatureBase64;

      finalRecord = FieldRecord.fromMap(finalMap);

      // 8. Commit to DB
      final credRow = await txn.query('credentials',
        where: 'operator_id = ?',
        whereArgs: [operatorId],
      );
      final operatorName = credRow.isNotEmpty ? credRow.first['name'] as String : _getOperatorInitials(operatorId);

      await txn.insert('records', {
        'record_id': finalRecord!.recordId,
        'operator_id': finalRecord!.operatorId,
        'operator_name': operatorName,
        'raw_json': jsonEncode(finalMap),
        'result': fusionResult.finalSubstance,
        'kit_used': fusionResult.kitId,
        'confidence': (fusionResult.finalConfidence * 10000).toInt(),
        'is_inconclusive': fusionResult.isInconclusive ? 1 : 0,
        'is_unknown': fusionResult.isUnknown ? 1 : 0,
        'gps_lat': double.tryParse(locationData.lat),
        'gps_lng': double.tryParse(locationData.lng),
        'address': locationData.address,
        'case_number': null, // Set null initially, can be amended
        'raw_image_path': rawImagePath, // Keep local DB paths internal, not in JSON
        'calibrated_image_path': fusionResult.calibratedImagePath,
        'raw_image_hash': rawHash,
        'calibrated_image_hash': calHash,
        'record_hash': recordHashHex,
        'signature': signatureBase64,
        'synced': 0,
        'created_at': utc.millisecondsSinceEpoch,
      });
    });

    return finalRecord!;
  }

  Future<String> _generateRecordId(Transaction txn, String jurisdiction, String operatorId) async {
    final year = DateTime.now().toUtc().year;
    
    await txn.rawInsert('''
      INSERT INTO record_counters (jurisdiction, year, counter)
      VALUES (?, ?, 1)
      ON CONFLICT(jurisdiction) DO UPDATE SET
        counter = CASE 
          WHEN year = excluded.year THEN counter + 1
          ELSE 1 
        END,
        year = excluded.year
    ''', [jurisdiction, year]);
    
    // Note: on January 1st, the first record of the new year gets counter = 1, not 0.
    final row = await txn.query('record_counters',
      where: 'jurisdiction = ?',
      whereArgs: [jurisdiction],
    );
    
    final counter = row.first['counter'] as int;
    final initials = _getOperatorInitials(operatorId);
    
    return '$jurisdiction-$year-$initials-\${counter.toString().padLeft(6, '0')}';
  }

  String _getOperatorInitials(String operatorId) {
    if (operatorId.length >= 2) return operatorId.substring(0, 2).toUpperCase();
    return operatorId.toUpperCase();
  }

  Future<String> _hashImageFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return hex.encode(sha256.convert(bytes).bytes);
  }

  Map<String, dynamic> _serializeFusionResult(FusionResult result) {
    return {
      'kit_id': result.kitId,
      'kit_version': result.kitVersion,
      'model_version': result.modelVersion,
      'final_substance': result.finalSubstance,
      'final_confidence': (result.finalConfidence * 10000).toInt(),
      'is_unknown': result.isUnknown,
      'is_inconclusive': result.isInconclusive,
      'is_single_layer_fallback': result.isSingleLayerFallback,
      'hsv_weight': (result.hsvWeight * 10000).toInt(),
      'cnn_weight': (result.cnnWeight * 10000).toInt(),
      'cnn_probabilities': result.cnnProbabilities?.map(
        (k, v) => MapEntry(k, (v * 10000).toInt()),
      ),
      // NO gradCamImagePath
      // NO full file paths
    };
  }

  Future<String> _signHash(String operatorId, Uint8List wrapKey, Uint8List hashBytes) async {
    final wrappedBase64 = await _secureStorage.read(
      key: 'wrapped_private_key_$operatorId',
    );
    final ivBase64 = await _secureStorage.read(
      key: 'wrap_iv_$operatorId',
    );
    
    if (wrappedBase64 == null || ivBase64 == null) {
      throw KeyNotFoundException('Private key not found for operator $operatorId');
    }
    
    final wrapped = base64.decode(wrappedBase64);
    final iv = base64.decode(ivBase64);
    
    final pkcs8Bytes = CryptoUtils.aesGcmDecrypt(wrapped, wrapKey, iv);
    
    final privateKey = CryptoUtils.parseECPrivateKeyFromPKCS8(pkcs8Bytes);
    
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(true, PrivateKeyParameter(privateKey));
    final sig = signer.generateSignature(hashBytes) as ECSignature;

    final derBytes = _encodeDER(sig.r, sig.s);
    final signatureBase64 = base64.encode(derBytes);

    pkcs8Bytes.fillRange(0, pkcs8Bytes.length, 0);

    return signatureBase64;
  }

  Uint8List _encodeDER(BigInt r, BigInt s) {
    // Basic DER encoding for ECDSA signature
    List<int> encodeInteger(BigInt i) {
      var bytes = _bigIntToBytes(i);
      if (bytes.isNotEmpty && (bytes[0] & 0x80) != 0) {
        bytes = [0x00, ...bytes];
      }
      return [0x02, bytes.length, ...bytes];
    }
    final rBytes = encodeInteger(r);
    final sBytes = encodeInteger(s);
    final seq = [...rBytes, ...sBytes];
    return Uint8List.fromList([0x30, seq.length, ...seq]);
  }

  List<int> _bigIntToBytes(BigInt number) {
    var hexStr = number.toRadixString(16);
    if (hexStr.length % 2 != 0) hexStr = '0$hexStr';
    return hex.decode(hexStr);
  }
}
