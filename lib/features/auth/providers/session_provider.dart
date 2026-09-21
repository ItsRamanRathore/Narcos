import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/database/database_service.dart';

enum SessionLockState {
  active,
  inactivityLocked,  // 15 min idle — PIN prompt, session data kept
  expired,           // 8 hours — full re-login, session cleared
  lockedOut,         // 3 failed PINs — 30 min block
  unauthenticated,
}

class SessionState {
  final SessionLockState lockState;
  final String? operatorId;
  final String? role;
  final Uint8List? wrapKey;
  final int? expiresAt;

  const SessionState({
    required this.lockState,
    this.operatorId,
    this.role,
    this.wrapKey,
    this.expiresAt,
  });

  SessionState copyWith({
    SessionLockState? lockState,
    String? operatorId,
    String? role,
    Uint8List? wrapKey,
    int? expiresAt,
  }) {
    return SessionState(
      lockState: lockState ?? this.lockState,
      operatorId: operatorId ?? this.operatorId,
      role: role ?? this.role,
      wrapKey: wrapKey ?? this.wrapKey,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    return const SessionState(lockState: SessionLockState.unauthenticated);
  }

  DatabaseService get _dbService => ref.read(databaseServiceProvider);

  Future<void> establishSession(String operatorId, Uint8List wrapKey) async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + (8 * 60 * 60 * 1000); // 8 hours from now

    // Fetch role
    final result = await db.query('credentials', where: 'operator_id = ?', whereArgs: [operatorId]);
    final role = result.isNotEmpty ? (result.first['role'] as String? ?? 'OPERATOR') : 'OPERATOR';

    await db.insert(
      'sessions',
      {
        'operator_id': operatorId,
        'last_active': now,
        'created_at': now,
        'expires_at': expiresAt,
        'inactivity_lock': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    state = SessionState(
      lockState: SessionLockState.active,
      operatorId: operatorId,
      role: role,
      wrapKey: wrapKey,
      expiresAt: expiresAt,
    );
  }

  Future<void> lockSession() async {
    if (state.operatorId == null) return;
    
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.update(
      'sessions',
      {'inactivity_lock': 1, 'last_active': now},
      where: 'operator_id = ?',
      whereArgs: [state.operatorId],
    );

    // Clear wrapKey from memory safely without affecting frozen state directly,
    // though Uint8List can be modified. Just reassigning to null is enough.
    state = state.copyWith(
      lockState: SessionLockState.inactivityLocked,
      wrapKey: null,
    );
  }

  Future<void> unlockSession(Uint8List wrapKey) async {
    if (state.operatorId == null) return;

    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'sessions',
      {'inactivity_lock': 0, 'last_active': now},
      where: 'operator_id = ?',
      whereArgs: [state.operatorId],
    );

    state = state.copyWith(
      lockState: SessionLockState.active,
      wrapKey: wrapKey,
    );
  }

  Future<void> triggerLockout() async {
    state = state.copyWith(
      lockState: SessionLockState.lockedOut,
      wrapKey: null,
    );
  }

  Future<void> logout() async {
    if (state.operatorId != null) {
      final db = await _dbService.database;
      await db.delete(
        'sessions',
        where: 'operator_id = ?',
        whereArgs: [state.operatorId],
      );
    }

    state = const SessionState(lockState: SessionLockState.unauthenticated);
  }

  Future<void> updateActivity() async {
    if (state.lockState != SessionLockState.active || state.operatorId == null) return;

    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check expiration
    if (state.expiresAt != null && now > state.expiresAt!) {
      state = state.copyWith(lockState: SessionLockState.expired, wrapKey: null);
      return;
    }

    await db.update(
      'sessions',
      {'last_active': now},
      where: 'operator_id = ?',
      whereArgs: [state.operatorId],
    );
  }

  /// Called when the app starts up to restore session state if possible
  Future<void> restoreSession() async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final results = await db.query('sessions');
    if (results.isEmpty) return;

    final session = results.first;
    final operatorId = session['operator_id'] as String;
    final expiresAt = session['expires_at'] as int;
    final inactivityLock = session['inactivity_lock'] as int? ?? 0;

    // Fetch role
    final credResult = await db.query('credentials', where: 'operator_id = ?', whereArgs: [operatorId]);
    final role = credResult.isNotEmpty ? (credResult.first['role'] as String? ?? 'OPERATOR') : 'OPERATOR';
    
    // Check locked out status
    final lockedUntil = credResult.isNotEmpty ? (credResult.first['locked_until'] as int?) : null;
    if (lockedUntil != null && lockedUntil > now) {
      state = SessionState(
        lockState: SessionLockState.lockedOut,
        operatorId: operatorId,
        role: role,
        expiresAt: expiresAt,
        wrapKey: null,
      );
      return;
    }

    if (now > expiresAt) {
      await db.delete('sessions', where: 'operator_id = ?', whereArgs: [operatorId]);
      state = const SessionState(lockState: SessionLockState.unauthenticated);
      return;
    }

    state = SessionState(
      lockState: inactivityLock == 1 ? SessionLockState.inactivityLocked : SessionLockState.inactivityLocked, 
      // Must be locked on startup because we don't have wrapKey in memory
      operatorId: operatorId,
      role: role,
      expiresAt: expiresAt,
      wrapKey: null,
    );
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(() {
  return SessionNotifier();
});
