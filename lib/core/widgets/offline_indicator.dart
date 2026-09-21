import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity_service.dart';
import '../database/database_service.dart';

// Provides a stream of sync stats
final syncStatsStreamProvider = StreamProvider.autoDispose<Map<String, int>>((ref) async* {
  final dbService = DatabaseService();
  
  while (true) {
    // Only query if app is not paused/inactive
    final binding = WidgetsBinding.instance;
    final state = binding.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      try {
      final db = await dbService.database;
      final result = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending,
          SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed
        FROM sync_queue
      ''');
      
      int pending = 0;
      int failed = 0;
      if (result.isNotEmpty) {
        pending = result.first['pending'] as int? ?? 0;
        failed = result.first['failed'] as int? ?? 0;
      }
      
      yield {'pending': pending, 'failed': failed};
    } catch (e) {
      yield {'pending': 0, 'failed': 0};
    }
    }
    
    // Poll every 10 seconds
    await Future.delayed(const Duration(seconds: 10));
  }
});

class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachabilityState = ref.watch(reachabilityStateProvider);

    if (reachabilityState == ReachabilityState.unknown || reachabilityState == ReachabilityState.online) {
      return const SizedBox.shrink(); // Show nothing
    }

    final syncStats = ref.watch(syncStatsStreamProvider);

    return Container(
      color: Colors.orange.shade800,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Offline Mode',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            syncStats.when(
              data: (stats) {
                final pending = stats['pending']!;
                final failed = stats['failed']!;
                final parts = <String>[];
                
                if (pending > 0) parts.add('↑ \$pending pending');
                if (failed > 0) parts.add('⚠ \$failed failed');
                
                if (parts.isEmpty) return const SizedBox.shrink();
                
                return Text(
                  '[ \${parts.join('  ')} ]',
                  style: const TextStyle(color: Colors.white),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
