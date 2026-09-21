import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import '../../records/domain/record_entity.dart';
import 'package:intl/intl.dart';

class PdfReportGenerator {
  static Future<Uint8List> generateRecordPdf(RecordEntity record, Uint8List rawImage, Uint8List calibratedImage) async {
    final pdf = pw.Document();

    // Load fonts
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final devanagariFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final devanagariTtf = pw.Font.ttf(devanagariFontData);

    final rawImagePdf = pw.MemoryImage(rawImage);
    final calibratedImagePdf = pw.MemoryImage(calibratedImage);

    // Format dates
    final timestamp = DateTime.fromMillisecondsSinceEpoch(record.fieldRecord.timestampUtcMs);
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);

    // Fusion Data
    final fusion = record.fieldRecord.fusionData;
    final classification = fusion['classification'] as String? ?? 'Unknown';
    final confidence = (fusion['confidence'] as num?)?.toDouble() ?? 0.0;
    
    // Add page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: ttf,
          fontFallback: [devanagariTtf],
        ),
        header: (context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NARCOTICS FIELD TESTING REPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Record ID: ${record.fieldRecord.recordId}', style: const pw.TextStyle(color: PdfColors.grey700)),
                ],
              ),
              pw.Divider(thickness: 2),
            ]
          );
        },
        build: (context) => [
          // Watermark
          pw.Watermark(
            pw.Transform.rotateBox(
              angle: 0.785398, // 45 degrees
              child: pw.Text(
                'PRESUMPTIVE — LAB CONFIRMATION REQUIRED',
                style: pw.TextStyle(
                  color: PdfColors.red300.shade(0.3),
                  fontSize: 40,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Operator:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(record.operatorName),
                    pw.Text('Operator ID:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(record.fieldRecord.operatorId),
                    if (record.caseNumber != null) ...[
                      pw.Text('Case Number:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(record.caseNumber!),
                    ],
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date/Time:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(formattedDate),
                    pw.Text('Location (Lat, Lng):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${record.fieldRecord.location['lat']}, ${record.fieldRecord.location['lng']}'),
                  ],
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Result Section
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Analysis Result', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Substance Detected:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(classification, style: pw.TextStyle(fontSize: 16, color: PdfColors.red800)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Confidence Score:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${(confidence * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Images
          pw.Text('Photographic Evidence', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('Raw Image'),
                    pw.SizedBox(height: 4),
                    pw.Image(rawImagePdf, height: 200),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('Calibrated Image'),
                    pw.SizedBox(height: 4),
                    pw.Image(calibratedImagePdf, height: 200),
                  ],
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Integrity
          pw.Text('Chain of Custody & Integrity', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Record Hash: ${record.fieldRecord.recordHash}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Signature: ${record.fieldRecord.signature}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Device Fingerprint: ${record.fieldRecord.deviceFingerprint}', style: const pw.TextStyle(fontSize: 8)),
          
          if (record.isDisputed) ...[
            pw.SizedBox(height: 10),
            pw.Text('DISPUTED RECORD', style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
            if (record.disputeNote != null)
              pw.Text('Dispute Note: ${record.disputeNote}', style: const pw.TextStyle(color: PdfColors.red)),
          ],
          
          pw.SizedBox(height: 30),
          
          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 150, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Operator Signature'),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 150, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Supervisor Signature'),
                ],
              ),
            ],
          ),
        ],
        footer: (context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by ForensIQ', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                ]
              ),
            ]
          );
        },
      )
    );

    return pdf.save();
  }
}
