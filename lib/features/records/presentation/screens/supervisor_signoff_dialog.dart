import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../auth/providers/session_provider.dart';

class SupervisorSignoffDialog extends ConsumerStatefulWidget {
  final String recordId;
  const SupervisorSignoffDialog({super.key, required this.recordId});

  @override
  ConsumerState<SupervisorSignoffDialog> createState() => _SupervisorSignoffDialogState();
}

class _SupervisorSignoffDialogState extends ConsumerState<SupervisorSignoffDialog> {
  final _pinController = TextEditingController();
  final _operatorIdController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _signOff() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final operatorId = _operatorIdController.text.trim();
    final pin = _pinController.text.trim();

    try {
      final db = await DatabaseService().database;
      
      // Basic check (in reality would verify PIN hash)
      final rows = await db.query(
        'credentials',
        where: 'operator_id = ? AND role = ?',
        whereArgs: [operatorId, 'SUPERVISOR']
      );

      if (rows.isEmpty) {
        throw Exception('Invalid Supervisor credentials');
      }

      // Record sign-off
      await db.update(
        'records',
        {
          'supervisor_id': operatorId,
          'supervisor_signature': 'SIG_${DateTime.now().millisecondsSinceEpoch}' // Mock signature
        },
        where: 'record_id = ?',
        whereArgs: [widget.recordId]
      );

      // Audit log
      await db.insert('audit_log', {
        'operator_id': operatorId,
        'action': 'SUPERVISOR_SIGNOFF',
        'record_id': widget.recordId,
        'detail': '{"note":"Sign-off completed"}',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Supervisor Sign-off'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) 
            Text(_error!, style: const TextStyle(color: Colors.red)),
          TextField(
            controller: _operatorIdController,
            decoration: const InputDecoration(labelText: 'Supervisor ID'),
          ),
          TextField(
            controller: _pinController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _signOff, 
          child: _isLoading ? const CircularProgressIndicator() : const Text('Sign Off')
        ),
      ],
    );
  }
}
