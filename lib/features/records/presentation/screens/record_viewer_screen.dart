import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../auth/providers/session_provider.dart';
import '../../application/record_repository.dart';
import '../../reporting/application/export_service.dart';
import '../domain/record_model.dart';
import '../domain/integrity_verifier.dart';
import '../domain/record_entity.dart';
import 'supervisor_signoff_dialog.dart';

class RecordViewerScreen extends ConsumerStatefulWidget {
  final String recordId;

  const RecordViewerScreen({super.key, required this.recordId});

  @override
  ConsumerState<RecordViewerScreen> createState() => _RecordViewerScreenState();
}

class _RecordViewerScreenState extends ConsumerState<RecordViewerScreen> {
  final RecordRepository _repository = RecordRepository();
  FieldRecord? _record;
  RecordEntity? _entity;
  Map<String, dynamic>? _rawJson;
  bool _isVerifying = true;
  bool _isCompromised = false;
  String? _caseNumber;
  
  List<RecordEntity> _relatedTests = [];
  List<Map<String, dynamic>> _amendmentLogs = [];

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    final db = await DatabaseService().database;
    final rows = await db.query('records', where: 'record_id = ?', whereArgs: [widget.recordId]);
    
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record not found')));
        Navigator.of(context).pop();
      }
      return;
    }

    final row = rows.first;
    final rawJsonStr = row['raw_json'] as String;
    final rawJson = jsonDecode(rawJsonStr) as Map<String, dynamic>;
    final record = FieldRecord.fromMap(rawJson);
    final entity = RecordEntity.fromDbMap(row);
    
    _caseNumber = entity.caseNumber;
    
    setState(() {
      _record = record;
      _entity = entity;
      _rawJson = rawJson;
    });

    final verifier = IntegrityVerifier();
    final valid = await verifier.verifyRecord(record, rawJson);

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _isCompromised = !valid;
      });
    }

    _loadRelatedTests(entity.caseNumber);
    _loadAmendmentLog();
  }

  Future<void> _loadRelatedTests(String? caseNumber) async {
    if (caseNumber != null && caseNumber.trim().isNotEmpty) {
      final related = await _repository.getRelatedTests(caseNumber: caseNumber, excludeRecordId: widget.recordId);
      if (mounted) setState(() => _relatedTests = related);
    } else {
      if (mounted) setState(() => _relatedTests = []);
    }
  }

  Future<void> _loadAmendmentLog() async {
    final db = await DatabaseService().database;
    final logs = await db.query(
      'audit_log',
      where: 'record_id = ?',
      whereArgs: [widget.recordId],
      orderBy: 'created_at ASC',
    );
    if (mounted) setState(() => _amendmentLogs = logs);
  }

  Future<void> _editCaseNumber() async {
    String tempCaseNumber = _caseNumber ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Case Number'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Case Number'),
            onChanged: (val) => tempCaseNumber = val,
            controller: TextEditingController(text: tempCaseNumber),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, tempCaseNumber), child: const Text('Save')),
          ],
        );
      }
    );

    if (result != null && result.isNotEmpty && mounted) {
      final db = await DatabaseService().database;
      await db.update(
        'records', 
        {'case_number': result}, 
        where: 'record_id = ?', 
        whereArgs: [widget.recordId]
      );
      
      final session = ref.read(sessionProvider);
      await _repository.logRecordAmendment(
        operatorId: session.operatorId ?? _record!.operatorId,
        recordId: widget.recordId,
        action: 'CASE_NUMBER_ASSIGNED',
        detail: {'case_number': result},
      );

      setState(() {
        _caseNumber = result;
      });
      _loadRelatedTests(result);
      _loadAmendmentLog();
    }
  }

  Future<void> _disputeResult() async {
    String note = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dispute Result'),
          content: TextField(
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason for dispute (min 20 chars)'),
            onChanged: (val) => note = val,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, note), 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Dispute'),
            ),
          ],
        );
      }
    );

    if (result != null && mounted) {
      final session = ref.read(sessionProvider);
      try {
        await _repository.disputeRecord(
          operatorId: session.operatorId ?? _record!.operatorId,
          recordId: widget.recordId,
          note: result,
          originalResult: _record!.fusionData['final_substance'] ?? 'Unknown',
        );
        _loadRecord(); // Reload everything to reflect changes
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final canDispute = session.operatorId == _record?.operatorId || 
                       session.role == 'SUPERVISOR' || 
                       session.role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: Text('Record \${widget.recordId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: (_isCompromised || _record == null)
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot export tampered record.')),
                  );
                }
              : () async {
                  final session = ref.read(sessionProvider);
                  try {
                    await ExportService().singleExport(_entity!, session.operatorId ?? 'UNKNOWN');
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                    }
                  }
                },
          )
        ],
      ),
      body: _record == null 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (!_isVerifying && _isCompromised)
                Container(
                  width: double.infinity,
                  color: Colors.red,
                  padding: const EdgeInsets.all(12),
                  child: const Text(
                    'WARNING: RECORD INTEGRITY COMPROMISED - DO NOT USE FOR EVIDENCE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        title: const Text('Result'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _record!.fusionData['final_substance'] ?? 'Unknown', 
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                            ),
                            if (_entity?.isDisputed == true) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                color: Colors.orange.withOpacity(0.2),
                                child: Text('DISPUTED: \${_entity?.disputeNote}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            if (_record!.fusionData['is_inconclusive'] == true) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                color: Colors.yellow.shade700.withOpacity(0.2),
                                child: Text('INCONCLUSIVE RESULT', style: TextStyle(color: Colors.yellow.shade900, fontWeight: FontWeight.bold)),
                              ),
                            ]
                          ],
                        ),
                        trailing: (_entity?.isDisputed != true && canDispute) 
                            ? IconButton(icon: const Icon(Icons.flag, color: Colors.orange), onPressed: _disputeResult)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Case Number'),
                      subtitle: Text(_caseNumber ?? 'Not Assigned'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _editCaseNumber,
                      ),
                    ),
                    if (_relatedTests.isNotEmpty) ...[
                      const Divider(),
                      const Text('Related Tests (Same Case)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._relatedTests.map((rt) => ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(rt.fieldRecord.recordId),
                        subtitle: Text(rt.fieldRecord.fusionData['final_substance'] ?? 'Unknown'),
                        onTap: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => RecordViewerScreen(recordId: rt.fieldRecord.recordId))
                        ),
                      )),
                    ],
                    const Divider(),
                    ListTile(
                      title: const Text('Captured By'),
                      subtitle: Text(_record!.operatorId),
                    ),
                    ListTile(
                      title: const Text('Timestamp (Local)'),
                      subtitle: Text(_record!.timestampLocal),
                    ),
                    ListTile(
                      title: const Text('Location'),
                      subtitle: Text(
                        _record!.location['address'] ?? '\${_record!.location['lat']}, \${_record!.location['lng']}'
                      ),
                    ),
                    ListTile(
                      title: const Text('Signature'),
                      subtitle: Text(_record!.signature, style: const TextStyle(fontFamily: 'monospace')),
                    ),
                    if (_amendmentLogs.isNotEmpty) ...[
                      const Divider(),
                      const Text('Amendment Log', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._amendmentLogs.map((log) {
                        final action = log['action'];
                        final detail = log['detail'];
                        final date = DateTime.fromMillisecondsSinceEpoch(log['created_at']);
                        return ListTile(
                          dense: true,
                          title: Text(action),
                          subtitle: Text('\${date.toIso8601String()}\\n$detail'),
                        );
                      }),
                    ],
                    const Divider(),
                    if (_entity?.supervisorSignature != null)
                      ListTile(
                        leading: const Icon(Icons.verified_user, color: Colors.blue),
                        title: const Text('Supervisor Co-signature'),
                        subtitle: Text('Signed by: \${_entity!.supervisorId}'),
                      )
                    else if (session.role == 'SUPERVISOR' || session.role == 'ADMIN')
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (_) => SupervisorSignoffDialog(recordId: widget.recordId),
                          );
                          if (result == true) {
                            _loadRecord();
                          }
                        },
                        icon: const Icon(Icons.edit_document),
                        label: const Text('Add Supervisor Sign-off'),
                      ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
