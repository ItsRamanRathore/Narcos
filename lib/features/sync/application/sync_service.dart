import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../records/domain/record_entity.dart';
import 'dart:convert';

class SyncService {
  final Dio _dio;
  final DatabaseService _dbService = DatabaseService();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  SyncService() : _dio = Dio(BaseOptions(baseUrl: 'https://narcos-api.example.com')) {
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      logPrint: print, // specify log function
      retries: 3, 
      retryDelays: const [
        Duration(seconds: 1), 
        Duration(seconds: 2), 
        Duration(seconds: 3),
      ],
    ));
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        syncPendingRecords();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncPendingRecords() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final db = await _dbService.database;
      // Get unsynced records
      final List<Map<String, dynamic>> unsynced = await db.query(
        'records',
        where: 'synced = 0',
        limit: 50
      );

      if (unsynced.isEmpty) {
        _isSyncing = false;
        return;
      }

      // Convert to payload
      final List<Map<String, dynamic>> payload = unsynced.map((row) {
        final entity = RecordEntity.fromDbMap(row);
        final fusion = entity.fieldRecord.fusionData;
        return {
          'recordId': entity.fieldRecord.recordId,
          'operatorId': entity.fieldRecord.operatorId,
          'rawJson': entity.rawJson,
          'result': fusion['final_substance'],
          'kitUsed': entity.fieldRecord.kitUsed,
          'confidence': fusion['confidence'],
          'hashRecord': entity.fieldRecord.recordHash,
          'signature': entity.fieldRecord.signature,
        };
      }).toList();

      // We should probably pass auth token here (JWT) but hardcoding for now or need AuthProvider
      final response = await _dio.post('/api/v1/records/sync', 
        data: {'records': payload},
        options: Options(
          // headers: {'Authorization': 'Bearer ...'}
        )
      );

      if (response.statusCode == 200) {
        final syncedIds = List<String>.from(response.data['syncedIds'] ?? []);
        
        final batch = db.batch();
        for (final id in syncedIds) {
          batch.update('records', {'synced': 1}, where: 'record_id = ?', whereArgs: [id]);
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
}

final syncServiceProvider = Provider((ref) => SyncService());
