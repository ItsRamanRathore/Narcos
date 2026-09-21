import 'dart:convert';
import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../domain/record_entity.dart';
import '../domain/record_filter.dart';
import '../domain/location_service.dart';

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}

class RecordRepository {
  final DatabaseService _dbService = DatabaseService();

  Future<List<RecordEntity>> getFilteredRecords(RecordFilter filter) async {
    final db = await _dbService.database;

    final conditions = <String>[];
    final args = <dynamic>[];
    
    String baseQuery = '''
      SELECT r.* FROM records r
    ''';
    
    // FTS5 join
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      baseQuery += '''
        INNER JOIN records_fts fts ON r.id = fts.rowid
      ''';
      conditions.add('fts MATCH ?');
      args.add(FtsQueryBuilder.prefix(filter.searchQuery!));
    }
    
    // Filters
    if (filter.resultType != null) {
      conditions.add('r.result = ?');
      args.add(filter.resultType);
    }
    if (filter.kitUsed != null) {
      conditions.add('r.kit_used = ?');
      args.add(filter.kitUsed);
    }
    if (filter.dateFrom != null) {
      conditions.add('r.created_at >= ?');
      args.add(filter.dateFrom!.millisecondsSinceEpoch);
    }
    if (filter.dateTo != null) {
      conditions.add('r.created_at <= ?');
      args.add(filter.dateTo!.millisecondsSinceEpoch);
    }
    if (filter.operatorId != null) {
      conditions.add('r.operator_id = ?');
      args.add(filter.operatorId);
    }
    if (filter.minConfidence != null) {
      conditions.add('r.confidence >= ?');
      args.add((filter.minConfidence! * 10000).toInt());
    }

    if (conditions.isNotEmpty) {
      baseQuery += ' WHERE \${conditions.join(' AND ')}';
    }

    // SQL Sorting (Except for proximity)
    if (filter.sortBy == 'newest') {
      baseQuery += ' ORDER BY r.created_at DESC';
    } else if (filter.sortBy == 'oldest') {
      baseQuery += ' ORDER BY r.created_at ASC';
    } else if (filter.sortBy == 'confidence') {
      baseQuery += ' ORDER BY r.confidence DESC';
    }

    final rows = await db.rawQuery(baseQuery, args);
    
    List<RecordEntity> records = rows.map((row) => RecordEntity.fromDbMap(row)).toList();

    // Proximity Sorting in Dart Memory
    if (filter.sortBy == 'proximity') {
      final locData = await LocationService.captureLocation(); // Note: Uses cached if possible due to timeout fallback
      final currentLat = double.tryParse(locData.lat) ?? 0.0;
      final currentLng = double.tryParse(locData.lng) ?? 0.0;
      
      records.sort((a, b) {
        final aLat = a.fieldRecord.location['lat'];
        final aLng = a.fieldRecord.location['lng'];
        final bLat = b.fieldRecord.location['lat'];
        final bLng = b.fieldRecord.location['lng'];

        final double? latA = aLat != null ? double.tryParse(aLat.toString()) : null;
        final double? lngA = aLng != null ? double.tryParse(aLng.toString()) : null;
        final double? latB = bLat != null ? double.tryParse(bLat.toString()) : null;
        final double? lngB = bLng != null ? double.tryParse(bLng.toString()) : null;
        
        if (latA == null || lngA == null) return 1;
        if (latB == null || lngB == null) return -1;
        
        final distA = _haversineKm(currentLat, currentLng, latA, lngA);
        final distB = _haversineKm(currentLat, currentLng, latB, lngB);
        return distA.compareTo(distB);
      });
    }

    return records;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat/2)*sin(dLat/2) +
               cos(lat1 * pi / 180.0)*cos(lat2 * pi / 180.0)*sin(dLon/2)*sin(dLon/2);
    return R * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  Future<List<RecordEntity>> getRelatedTests({required String caseNumber, required String excludeRecordId}) async {
    if (caseNumber.trim().isEmpty) return [];
    
    final db = await _dbService.database;
    final rows = await db.query(
      'records', 
      where: 'case_number = ? AND record_id != ?',
      whereArgs: [caseNumber, excludeRecordId],
    );
    return rows.map((row) => RecordEntity.fromDbMap(row)).toList();
  }

  Future<void> logRecordAmendment({
    required String operatorId,
    required String recordId,
    required String action,
    required Map<String, dynamic> detail,
  }) async {
    final db = await _dbService.database;
    await db.insert('audit_log', {
      'operator_id': operatorId,
      'record_id': recordId,
      'action': action,
      'detail': jsonEncode(detail),
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
  }

  Future<void> disputeRecord({
    required String operatorId,
    required String recordId,
    required String note,
    required String originalResult,
  }) async {
    const int minDisputeNoteLength = 20;
    if (note.trim().length < minDisputeNoteLength) {
      throw ValidationException('Dispute note must be at least $minDisputeNoteLength characters. Provide a clear reason for disputing this result.');
    }

    final db = await _dbService.database;
    
    await db.transaction((txn) async {
      await txn.update(
        'records',
        {
          'is_disputed': 1,
          'dispute_note': note.trim(),
        },
        where: 'record_id = ?',
        whereArgs: [recordId],
      );

      await txn.insert('audit_log', {
        'operator_id': operatorId,
        'record_id': recordId,
        'action': 'RESULT_DISPUTED',
        'detail': jsonEncode({
          'dispute_note': note.trim(),
          'original_result': originalResult,
        }),
        'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
    });
  }
}
