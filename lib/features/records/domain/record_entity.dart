import 'record_model.dart';
import 'dart:convert';

/// RecordEntity encompasses both the signed FieldRecord JSON and the 
/// DB-only fields that are allowed to be modified after capture (e.g., case_number, dispute).
class RecordEntity {
  final FieldRecord fieldRecord;
  final String rawJson; // For fast hashing checks
  final String? caseNumber;
  final bool isDisputed;
  final String? disputeNote;
  final String operatorName; // Display name pulled via join at insert
  final String? supervisorId;
  final String? supervisorSignature;

  RecordEntity({
    required this.fieldRecord,
    required this.rawJson,
    this.caseNumber,
    this.isDisputed = false,
    this.disputeNote,
    required this.operatorName,
    this.supervisorId,
    this.supervisorSignature,
  });

  factory RecordEntity.fromDbMap(Map<String, dynamic> map) {
    final rawJsonStr = map['raw_json'] as String;
    final jsonMap = jsonDecode(rawJsonStr) as Map<String, dynamic>;
    return RecordEntity(
      fieldRecord: FieldRecord.fromMap(jsonMap),
      rawJson: rawJsonStr,
      caseNumber: map['case_number'] as String?,
      isDisputed: (map['is_disputed'] as int?) == 1,
      disputeNote: map['dispute_note'] as String?,
      operatorName: map['operator_name'] as String,
      supervisorId: map['supervisor_id'] as String?,
      supervisorSignature: map['supervisor_signature'] as String?,
    );
  }
}
