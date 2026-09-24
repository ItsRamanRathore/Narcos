import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_service.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final db = await DatabaseService().database;
    final results = await db.query('records', orderBy: 'created_at DESC');
    if (mounted) {
      setState(() {
        _records = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return const Center(
        child: Text('No logs found.', style: TextStyle(color: Colors.white70, fontSize: 18)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detection Logs'),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecords,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: _records.length,
          itemBuilder: (context, index) {
            final record = _records[index];
            final result = record['result'] as String? ?? 'Unknown';
            final kitUsed = record['kit_used'] as String? ?? 'Unknown';
            final confidence = record['confidence'] as int? ?? 0;
            final createdAtMs = record['created_at'] as int?;
            
            final date = createdAtMs != null ? DateTime.fromMillisecondsSinceEpoch(createdAtMs) : DateTime.now();
            final dateStr = DateFormat('MMM dd, yyyy - HH:mm').format(date);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withOpacity(0.05),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getColorForConfidence(confidence),
                  child: const Icon(Icons.science, color: Colors.white),
                ),
                title: Text(result, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text('Kit: $kitUsed\nDate: $dateStr', style: const TextStyle(color: Colors.white70)),
                trailing: Text('$confidence%', style: TextStyle(color: _getColorForConfidence(confidence), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getColorForConfidence(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 50) return Colors.orange;
    return Colors.red;
  }
}
