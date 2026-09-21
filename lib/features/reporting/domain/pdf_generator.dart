import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../records/domain/record_entity.dart';
import '../../../core/constants/app_constants.dart';

class PdfGenerationData {
  final RecordEntity record;
  final Uint8List fontLatinBytes;
  final Uint8List fontDevanagariBytes;
  final Uint8List? logoBytes;
  final Uint8List? rawImageBytes;
  final Uint8List? calibratedImageBytes;

  PdfGenerationData({
    required this.record,
    required this.fontLatinBytes,
    required this.fontDevanagariBytes,
    this.logoBytes,
    this.rawImageBytes,
    this.calibratedImageBytes,
  });
}

class PdfGenerator {
  static Future<Uint8List> generateReport(PdfGenerationData data) async {
    final pdf = pw.Document();
    
    final ttfLatin = pw.Font.ttf(data.fontLatinBytes.buffer.asByteData());
    final ttfDevanagari = pw.Font.ttf(data.fontDevanagariBytes.buffer.asByteData());

    final record = data.record;
    final fieldRecord = record.fieldRecord;
    
    // Create the QR Code payload (as required in PR #2)
    final qrPayload = jsonEncode({
      'id': fieldRecord.recordId,
      'hash': fieldRecord.recordHash,
      'pubkey_fp': fieldRecord.publicKeyFingerprint,
      'sig': fieldRecord.signature,
      'schema_ver': 1, // Assuming schema 1 for now
      'exported_at': DateTime.now().toUtc().toIso8601String(),
    });

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Transform.rotate(
                angle: -0.5,
                child: pw.Text(
                  'PRESUMPTIVE — LAB CONFIRMATION REQUIRED',
                  style: pw.TextStyle(
                    font: ttfLatin,
                    color: const PdfColor.fromInt(0x20FF0000), // #FF000020
                    fontSize: 36,
                  ),
                ),
              ),
            ),
          ),
        ),
        header: (context) => _buildHeader(data, ttfLatin),
        build: (context) => [
          _buildStatusBanners(record, ttfLatin),
          pw.SizedBox(height: 20),
          _buildRecordDetails(record, ttfLatin, ttfDevanagari),
          pw.SizedBox(height: 20),
          _buildImages(data, ttfLatin),
          pw.SizedBox(height: 20),
          _buildSwatchComparison(fieldRecord.fusionData, ttfLatin),
          pw.SizedBox(height: 30),
          _buildSignatureBlock(fieldRecord, record.operatorName, ttfLatin, qrPayload),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(PdfGenerationData data, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('NARCOTICS FIELD TESTING REPORT', style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('CONFIDENTIAL / CHAIN OF CUSTODY', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
          ]
        ),
        if (data.logoBytes != null)
          pw.Image(pw.MemoryImage(data.logoBytes!), width: 50, height: 50)
      ],
    );
  }

  static pw.Widget _buildStatusBanners(RecordEntity record, pw.Font font) {
    List<pw.Widget> banners = [];
    if (record.isDisputed) {
      banners.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          color: const PdfColor.fromInt(0x33FFA500),
          child: pw.Text('DISPUTED: \${record.disputeNote}', style: pw.TextStyle(font: font, color: PdfColors.orange)),
        )
      );
    }
    if (record.fieldRecord.fusionData['is_inconclusive'] == true) {
      banners.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.all(10),
          color: const PdfColor.fromInt(0x33FFFF00),
          child: pw.Text('INCONCLUSIVE RESULT', style: pw.TextStyle(font: font, color: PdfColors.orange900)),
        )
      );
    }
    return pw.Column(children: banners);
  }

  static pw.Widget _buildRecordDetails(RecordEntity record, pw.Font ttfLatin, pw.Font ttfDevanagari) {
    final fr = record.fieldRecord;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _infoRow('Record ID', fr.recordId, ttfLatin),
        _infoRow('Case Number', record.caseNumber ?? 'Not Assigned', ttfLatin),
        _infoRow('Kit Used', fr.kitUsed, ttfLatin),
        _infoRow('Result', fr.fusionData['final_substance'] ?? 'Unknown', ttfLatin),
        // Bilingual Example for Result
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 120, child: pw.Text('परिणाम (Result)', style: pw.TextStyle(font: ttfDevanagari, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text(fr.fusionData['final_substance'] ?? 'Unknown', style: pw.TextStyle(font: ttfLatin))),
          ]
        ),
        _infoRow('Timestamp', fr.timestampLocal, ttfLatin),
        _infoRow('Location', fr.location['address'] ?? '\${fr.location['lat']}, \${fr.location['lng']}', ttfLatin),
      ]
    );
  }

  static pw.Widget _infoRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: font))),
        ]
      )
    );
  }

  static pw.Widget _buildImages(PdfGenerationData data, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        if (data.rawImageBytes != null)
          pw.Column(children: [
            pw.Text('Raw Image', style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 5),
            pw.Image(pw.MemoryImage(data.rawImageBytes!), width: 150, height: 150, fit: pw.BoxFit.contain),
          ]),
        if (data.calibratedImageBytes != null)
          pw.Column(children: [
            pw.Text('Calibrated Image', style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 5),
            pw.Image(pw.MemoryImage(data.calibratedImageBytes!), width: 150, height: 150, fit: pw.BoxFit.contain),
          ]),
      ]
    );
  }

  static pw.Widget _buildSwatchComparison(Map<String, dynamic> fusionData, pw.Font font) {
    // Example extracting ΔE
    final deltaE = fusionData['color_delta_e'];
    
    // Simplified swatch drawing
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Color Analysis (ΔE = \${deltaE?.toStringAsFixed(2) ?? 'N/A'})', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Container(width: 40, height: 40, color: PdfColors.blue), // Mock detected
            pw.SizedBox(width: 10),
            pw.Text('Detected Color', style: pw.TextStyle(font: font)),
            pw.SizedBox(width: 40),
            pw.Container(width: 40, height: 40, color: PdfColors.blueAccent), // Mock reference
            pw.SizedBox(width: 10),
            pw.Text('Reference Color', style: pw.TextStyle(font: font)),
          ]
        )
      ]
    );
  }

  static pw.Widget _buildSignatureBlock(dynamic fr, String operatorName, pw.Font font, String qrPayload) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DIGITAL SIGNATURE', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                _infoRow('Operator', '\$operatorName (\${fr.operatorId})', font),
                _infoRow('Record Hash', fr.recordHash, font),
                _infoRow('Public Key (JWK)', fr.publicKeyFingerprint, font),
                _infoRow('Signature', fr.signature, font),
                pw.SizedBox(height: 10),
                pw.Text('Schema Version: 1 | Exported: \${DateTime.now().toUtc().toIso8601String()}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
              ]
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Container(
            width: 100,
            height: 100,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrPayload,
              drawText: false,
            ),
          )
        ]
      )
    );
  }
}
