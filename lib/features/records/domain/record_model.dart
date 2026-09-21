class FieldRecord {
  final String recordId;               // Jurisdiction-prefixed sequential ID
  final String operatorId;
  final String schemaVersion;          // '1.0'
  final String appVersion;             // e.g. '1.0.0'
  
  // Timestamps
  final int timestampUtcMs;
  final String timestampIso8601;
  final String timestampLocal;
  final String timezone;
  
  final Map<String, dynamic> location; // lat, lng, accuracy, source (gps/last_known)
  final String deviceFingerprint;
  
  // Image hashes
  final String rawImageHash;           
  final String calibratedImageHash;    
  
  // Embedded Fusion 
  final Map<String, dynamic> fusionData; // Serialized FusionResult
  
  // Cryptography
  final String recordHash;             // SHA-256 of canonical JSON (everything above)
  final String signature;              // ECDSA-P256 signature (Base64)

  FieldRecord({
    required this.recordId,
    required this.operatorId,
    required this.schemaVersion,
    required this.appVersion,
    required this.timestampUtcMs,
    required this.timestampIso8601,
    required this.timestampLocal,
    required this.timezone,
    required this.location,
    required this.deviceFingerprint,
    required this.rawImageHash,
    required this.calibratedImageHash,
    required this.fusionData,
    required this.recordHash,
    required this.signature,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'operatorId': operatorId,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'timestampUtcMs': timestampUtcMs,
      'timestampIso8601': timestampIso8601,
      'timestampLocal': timestampLocal,
      'timezone': timezone,
      'location': location,
      'deviceFingerprint': deviceFingerprint,
      'rawImageHash': rawImageHash,
      'calibratedImageHash': calibratedImageHash,
      'fusionData': fusionData,
      'recordHash': recordHash,
      'signature': signature,
    };
  }

  factory FieldRecord.fromMap(Map<String, dynamic> map) {
    return FieldRecord(
      recordId: map['recordId'] as String,
      operatorId: map['operatorId'] as String,
      schemaVersion: map['schemaVersion'] as String,
      appVersion: map['appVersion'] as String,
      timestampUtcMs: map['timestampUtcMs'] as int,
      timestampIso8601: map['timestampIso8601'] as String,
      timestampLocal: map['timestampLocal'] as String,
      timezone: map['timezone'] as String,
      location: map['location'] as Map<String, dynamic>,
      deviceFingerprint: map['deviceFingerprint'] as String,
      rawImageHash: map['rawImageHash'] as String,
      calibratedImageHash: map['calibratedImageHash'] as String,
      fusionData: map['fusionData'] as Map<String, dynamic>,
      recordHash: map['recordHash'] as String,
      signature: map['signature'] as String,
    );
  }
}
