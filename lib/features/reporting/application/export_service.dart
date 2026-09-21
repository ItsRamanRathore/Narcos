import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import '../domain/pdf_generator.dart';
import '../../records/domain/record_entity.dart';
import '../../records/application/record_repository.dart';

class ExportService {
  final RecordRepository _repository = RecordRepository();

  Future<void> singleExport(RecordEntity record, String operatorId) async {
    // 1. Audit Attempt
    await _repository.logRecordAmendment(
      operatorId: operatorId,
      recordId: record.fieldRecord.recordId,
      action: 'PDF_EXPORT_ATTEMPTED',
      detail: {},
    );

    File? tempFile;
    try {
      // 2. Pre-load resources on main isolate
      final fontLatinBytes = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final fontDevanagariBytes = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      
      Uint8List? rawImageBytes;
      if (record.fieldRecord.rawImagePath != null) {
        final f = File(record.fieldRecord.rawImagePath!);
        if (f.existsSync()) rawImageBytes = await f.readAsBytes();
      }
      
      Uint8List? calibratedImageBytes;
      if (record.fieldRecord.calibratedImagePath != null) {
        final f = File(record.fieldRecord.calibratedImagePath!);
        if (f.existsSync()) calibratedImageBytes = await f.readAsBytes();
      }

      final data = PdfGenerationData(
        record: record,
        fontLatinBytes: fontLatinBytes.buffer.asUint8List(),
        fontDevanagariBytes: fontDevanagariBytes.buffer.asUint8List(),
        rawImageBytes: rawImageBytes,
        calibratedImageBytes: calibratedImageBytes,
      );

      // 3. Generate PDF (Can be done on main isolate for single export, or isolate)
      final pdfBytes = await PdfGenerator.generateReport(data);

      // 4. Save and Share
      final dir = await getTemporaryDirectory();
      tempFile = File('\${dir.path}/\${record.fieldRecord.recordId}.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      await Share.shareXFiles([XFile(tempFile.path)]);

      // 5. Audit Success
      await _repository.logRecordAmendment(
        operatorId: operatorId,
        recordId: record.fieldRecord.recordId,
        action: 'PDF_EXPORTED',
        detail: {},
      );

    } catch (e) {
      // Audit failure
      await _repository.logRecordAmendment(
        operatorId: operatorId,
        recordId: record.fieldRecord.recordId,
        action: 'PDF_EXPORT_FAILED',
        detail: {'reason': e.toString()},
      );
      rethrow;
    } finally {
      // 6. Cleanup
      if (tempFile != null && tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> bulkExportAsZip(List<RecordEntity> records, String operatorId) async {
    final recordIds = records.map((r) => r.fieldRecord.recordId).toList();
    
    // Log Attempt
    for (var rId in recordIds) {
      await _repository.logRecordAmendment(
        operatorId: operatorId,
        recordId: rId,
        action: 'BULK_EXPORT_ATTEMPTED',
        detail: {},
      );
    }

    File? tempZip;
    try {
      // Pre-load on main isolate
      final fontLatinBytes = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final fontDevanagariBytes = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      
      List<PdfGenerationData> dtos = [];
      for (var record in records) {
        Uint8List? rawBytes;
        if (record.fieldRecord.rawImagePath != null) {
          final f = File(record.fieldRecord.rawImagePath!);
          if (f.existsSync()) rawBytes = await f.readAsBytes();
        }
        
        Uint8List? calBytes;
        if (record.fieldRecord.calibratedImagePath != null) {
          final f = File(record.fieldRecord.calibratedImagePath!);
          if (f.existsSync()) calBytes = await f.readAsBytes();
        }

        dtos.add(PdfGenerationData(
          record: record,
          fontLatinBytes: fontLatinBytes.buffer.asUint8List(),
          fontDevanagariBytes: fontDevanagariBytes.buffer.asUint8List(),
          rawImageBytes: rawBytes,
          calibratedImageBytes: calBytes,
        ));
      }

      // Run Zip generation in Isolate
      final zipBytes = await Isolate.run(() => _generateZipInIsolate(dtos));

      // Save and Share
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      tempZip = File('\${dir.path}/ForensIQ_Export_\$timestamp.zip');
      await tempZip.writeAsBytes(zipBytes);

      await Share.shareXFiles([XFile(tempZip.path)]);

      // Log Success
      for (var rId in recordIds) {
        await _repository.logRecordAmendment(
          operatorId: operatorId,
          recordId: rId,
          action: 'BULK_EXPORTED',
          detail: {},
        );
      }
    } catch (e) {
      for (var rId in recordIds) {
        await _repository.logRecordAmendment(
          operatorId: operatorId,
          recordId: rId,
          action: 'BULK_EXPORT_FAILED',
          detail: {'reason': e.toString()},
        );
      }
      rethrow;
    } finally {
      if (tempZip != null && tempZip.existsSync()) {
        await tempZip.delete();
      }
    }
  }

  // Top-level function for isolate
  static Future<Uint8List> _generateZipInIsolate(List<PdfGenerationData> dtos) async {
    final archive = Archive();

    List<List<String>> csvRows = [
      ['Record ID', 'Case Number', 'Operator', 'Timestamp', 'Result', 'Disputed', 'Tampered', 'Confidence'] // Fixed schema
    ];

    for (var data in dtos) {
      // 1. Generate PDF
      final pdfBytes = await PdfGenerator.generateReport(data);
      archive.addFile(ArchiveFile('\${data.record.fieldRecord.recordId}.pdf', pdfBytes.length, pdfBytes));

      // 2. Add raw_json
      final jsonBytes = utf8.encode(data.record.rawJson);
      archive.addFile(ArchiveFile('\${data.record.fieldRecord.recordId}.json', jsonBytes.length, jsonBytes));

      // 3. Collect CSV row
      csvRows.add([
        data.record.fieldRecord.recordId,
        data.record.caseNumber ?? '',
        data.record.operatorName,
        data.record.fieldRecord.timestampLocal,
        data.record.fieldRecord.fusionData['final_substance'] ?? '',
        data.record.isDisputed.toString(),
        'false', // If it was tampered it wouldn't be here in the bulk export list
        data.record.fieldRecord.fusionData['confidence']?.toString() ?? '',
      ]);
    }

    // Generate CSV
    final csvContent = csvRows.map((row) => row.map(_csvEncode).join(',')).join('\\n');
    final csvBytes = utf8.encode(csvContent);
    archive.addFile(ArchiveFile('summary.csv', csvBytes.length, csvBytes));

    // Encode ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive)!;
    
    return Uint8List.fromList(zipData);
  }

  static String _csvEncode(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\\n')) {
      return '"\${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
