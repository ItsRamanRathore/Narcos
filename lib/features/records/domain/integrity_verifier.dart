import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../../../core/database/database_service.dart';
import '../../../core/security/crypto_utils.dart';
import 'canonical_json.dart';
import 'record_model.dart';

class IntegrityVerifier {
  final DatabaseService _dbService = DatabaseService();

  // Fast check for list view — detects DB-level tampering
  bool fastIntegrityCheck(Map<String, dynamic> row) {
    final storedRecordHash = row['record_hash'] as String;
    final rawJson = row['raw_json'] as String;
    
    // Parse raw_json, remove signature and recordHash, re-canonicalize
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    map.remove('signature');
    map.remove('recordHash');
    
    final canonicalBytes = CanonicalJson.encode(map);
    final derivedHash = hex.encode(sha256.convert(canonicalBytes).bytes);
    
    return derivedHash == storedRecordHash;
  }

  Future<bool> verifyRecord(FieldRecord record, Map<String, dynamic> rawJson) async {
    final db = await _dbService.database;
    
    // 1. Get public key from SQLite keys table
    final keyRow = await db.query('keys',
      where: 'operator_id = ?',
      whereArgs: [record.operatorId],
    );
    
    if (keyRow.isEmpty) return false;
    
    final publicKeyJwk = keyRow.first['public_key_jwk'] as String;
    final publicKey = CryptoUtils.parseECPublicKeyFromJWK(publicKeyJwk);
    
    // 2. Re-canonicalize the record WITHOUT the signature and hash fields
    final recordWithoutSig = Map<String, dynamic>.from(rawJson)
      ..remove('signature')
      ..remove('recordHash'); // Note: Make sure case matches the JSON keys (recordHash vs record_hash)
    
    final canonicalBytes = CanonicalJson.encode(recordWithoutSig);
    
    // 3. Re-hash
    final hashBytes = sha256.convert(canonicalBytes).bytes;
    final derivedHash = hex.encode(hashBytes);
    
    // 4. Compare stored hash
    if (derivedHash != record.recordHash) return false;
    
    // 5. Verify ECDSA signature
    final derBytes = base64.decode(record.signature);
    final sig = _decodeDER(derBytes);
    if (sig == null) return false;

    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(false, PublicKeyParameter(publicKey));
    final valid = signer.verifySignature(Uint8List.fromList(hashBytes), sig);

    return valid;
  }

  ECSignature? _decodeDER(Uint8List der) {
    try {
      if (der[0] != 0x30) return null;
      var offset = 2; // skip 0x30 and length
      
      BigInt readInteger() {
        if (der[offset] != 0x02) throw Exception('Invalid DER integer');
        final len = der[offset + 1];
        offset += 2;
        final intBytes = der.sublist(offset, offset + len);
        offset += len;
        
        final hexStr = hex.encode(intBytes);
        return BigInt.parse(hexStr, radix: 16);
      }
      
      final r = readInteger();
      final s = readInteger();
      return ECSignature(r, s);
    } catch (_) {
      return null;
    }
  }
}
