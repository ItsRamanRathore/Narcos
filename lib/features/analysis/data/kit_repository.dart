import 'dart:convert';
import 'package:flutter/services.dart';

class KitReference {
  final String substance;
  final List<double> hsv;
  final List<double> hsvToleranceNormalized;
  final List<double> labReference;
  final String colorHex;

  KitReference({
    required this.substance,
    required this.hsv,
    required this.hsvToleranceNormalized,
    required this.labReference,
    required this.colorHex,
  });
}

class KitManifest {
  final String kitId;
  final String kitName;
  final String version;
  final DateTime lastUpdated;
  final List<KitReference> references;

  KitManifest({
    required this.kitId,
    required this.kitName,
    required this.version,
    required this.lastUpdated,
    required this.references,
  });
}

class KitRepository {
  static const List<String> _kitFiles = [
    'assets/kits/marquis.json',
    'assets/kits/scott.json',
    'assets/kits/mecke.json',
    'assets/kits/duquenois_levine.json',
  ];

  Future<List<KitManifest>> loadAllKits() async {
    final kits = <KitManifest>[];
    for (final path in _kitFiles) {
      try {
        final jsonString = await rootBundle.loadString(path);
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        
        final kitId = data['kit_id'] as String;
        final kitName = data['kit_name'] as String;
        final version = data['version'] as String;
        final lastUpdated = DateTime.parse(data['last_updated'] as String);
        final referencesList = data['references'] as List<dynamic>? ?? [];
        
        final scale = data['hsv_scale'] as String?;
        final isConventional = scale == 'conventional_360_100_100';
        
        final references = <KitReference>[];
        for (final refData in referencesList) {
          final hsvRaw = List<double>.from((refData['color_hsv'] as List).map((e) => e is num ? e.toDouble() : 0.0));
          final toleranceRaw = refData['hsv_tolerance'] != null 
              ? List<double>.from((refData['hsv_tolerance'] as List).map((e) => e is num ? e.toDouble() : 0.0))
              : <double>[15, 10, 15]; // fallback
          
          final labRaw = refData['lab_reference'] != null
              ? List<double>.from((refData['lab_reference'] as List).map((e) => e is num ? e.toDouble() : 0.0))
              : <double>[0, 0, 0];
              
          final hex = refData['color_hex'] as String? ?? '#000000';

          List<double> normalizedHsv = hsvRaw;
          List<double> normalizedTolerance = toleranceRaw;
          
          if (isConventional) {
            normalizedHsv = [
              hsvRaw[0] / 2.0,
              hsvRaw[1] * 255.0 / 100.0,
              hsvRaw[2] * 255.0 / 100.0,
            ];
            normalizedTolerance = [
              toleranceRaw[0] / 2.0,
              toleranceRaw[1] * 255.0 / 100.0,
              toleranceRaw[2] * 255.0 / 100.0,
            ];
          }

          references.add(KitReference(
            substance: refData['substance'] as String,
            hsv: normalizedHsv,
            hsvToleranceNormalized: normalizedTolerance,
            labReference: labRaw,
            colorHex: hex,
          ));
        }

        kits.add(KitManifest(
          kitId: kitId,
          kitName: kitName,
          version: version,
          lastUpdated: lastUpdated,
          references: references,
        ));
      } catch (e) {
        // If file missing or parsing error, just continue
        print('Error loading kit $path: $e');
      }
    }
    return kits;
  }
}
