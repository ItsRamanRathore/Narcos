import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/record_filter_provider.dart';
import '../../application/record_repository.dart';
import '../../domain/record_entity.dart';
import '../../domain/integrity_verifier.dart';
import '../../reporting/application/export_service.dart';
import 'record_viewer_screen.dart';
import 'package:intl/intl.dart';

class RecordsListScreen extends ConsumerStatefulWidget {
  const RecordsListScreen({super.key});

  @override
  ConsumerState<RecordsListScreen> createState() => _RecordsListScreenState();
}

class _RecordsListScreenState extends ConsumerState<RecordsListScreen> {
  final RecordRepository _repository = RecordRepository();
  final IntegrityVerifier _verifier = IntegrityVerifier();
  
  List<RecordEntity> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    // Note 6: Bulk Selection State Must Clear on Navigation
    // Since riverpod providers are globally accessible or tied to scopes,
    // we clear it manually here when leaving the list screen.
    // Wait, ref.read is not recommended in dispose if the provider might be disposed.
    // But since it's a global provider, we can do it asynchronously.
    Future.microtask(() {
      if (mounted) {
        ref.read(recordFilterNotifierProvider.notifier).clearSelection();
      }
    });
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final filter = ref.read(recordFilterNotifierProvider).filter;
    try {
      final records = await _repository.getFilteredRecords(filter);
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading records: $e')));
      }
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Stub for complex filter UI (Date Range, Kit, Operator)
            ElevatedButton(
              onPressed: () {
                final current = ref.read(recordFilterNotifierProvider).filter;
                ref.read(recordFilterNotifierProvider.notifier).updateFilter(
                  current.copyWith(sortBy: 'proximity')
                );
                Navigator.pop(context);
                _loadRecords();
              },
              child: const Text('Sort by Proximity'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordFilterNotifierProvider);
    final isBulk = state.isBulkSelectionMode;

    return Scaffold(
      appBar: AppBar(
        title: isBulk ? Text('\${state.selectedRecordIds.length} Selected') : const Text('Records'),
        actions: [
          if (isBulk)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(recordFilterNotifierProvider.notifier).clearSelection();
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterSheet,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search records...',
                filled: true,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (val) {
                final current = ref.read(recordFilterNotifierProvider).filter;
                ref.read(recordFilterNotifierProvider.notifier).updateFilter(
                  current.copyWith(searchQuery: val)
                );
                _loadRecords();
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(child: Text('No records found.'))
              : ListView.builder(
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final isSelected = state.selectedRecordIds.contains(record.fieldRecord.recordId);
                    
                    // Fast integrity check
                    // We parse the raw JSON to check hash
                    final rawMap = jsonDecode(record.rawJson) as Map<String, dynamic>;
                    final isValid = _verifier.fastIntegrityCheck(rawMap);

                    return Card(
                      color: isSelected ? Colors.blue.withOpacity(0.2) : null,
                      child: ListTile(
                        onLongPress: () {
                          ref.read(recordFilterNotifierProvider.notifier).toggleSelection(record.fieldRecord.recordId);
                        },
                        onTap: () {
                          if (isBulk) {
                            ref.read(recordFilterNotifierProvider.notifier).toggleSelection(record.fieldRecord.recordId);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecordViewerScreen(recordId: record.fieldRecord.recordId),
                              ),
                            ).then((_) => _loadRecords());
                          }
                        },
                        leading: isValid
                            ? const Icon(Icons.verified, color: Colors.green)
                            : const Icon(Icons.warning, color: Colors.red),
                        title: Text(record.fieldRecord.recordId),
                        subtitle: Text(
                          '\${record.fieldRecord.fusionData['final_substance'] ?? 'Unknown'} • '
                          '\${record.operatorName}\\n'
                          '\${record.fieldRecord.timestampLocal}',
                        ),
                        trailing: isBulk
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) {
                                  ref.read(recordFilterNotifierProvider.notifier).toggleSelection(record.fieldRecord.recordId);
                                },
                              )
                            : (record.isDisputed 
                                ? const Icon(Icons.flag, color: Colors.orange) 
                                : const Icon(Icons.chevron_right)),
                      ),
                    );
                  },
                ),
      floatingActionButton: isBulk
          ? FloatingActionButton.extended(
              onPressed: () => _bulkExport(state.selectedRecordIds),
              icon: const Icon(Icons.archive),
              label: const Text('Export ZIP'),
            )
          : null,
    );
  }

  Future<void> _bulkExport(Set<String> selectedIds) async {
    if (selectedIds.isEmpty) return;
    
    // Fetch records by ID
    final db = await DatabaseService().database;
    final inArgs = List.filled(selectedIds.length, '?').join(',');
    final rows = await db.query(
      'records', 
      where: 'record_id IN ($inArgs)', 
      whereArgs: selectedIds.toList()
    );
    
    final records = rows.map((row) => RecordEntity.fromDbMap(row)).toList();
    
    final session = ref.read(sessionProvider);
    final operatorId = session.operatorId ?? 'UNKNOWN';

    try {
      // Assuming ExportService is imported
      await ExportService().bulkExportAsZip(records, operatorId);
      ref.read(recordFilterNotifierProvider.notifier).clearSelection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bulk export failed: $e')));
      }
    }
  }
}
