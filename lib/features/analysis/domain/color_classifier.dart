import 'dart:math';
import 'package:fieldapp/features/calibration/domain/calibration_result.dart';
import '../data/kit_repository.dart';
import 'analysis_result.dart';

class ColorClassifier {
  AnalysisResult classify(
    String kitId,
    KitManifest kit,
    List<double> extractedHsv,
    List<double> extractedLab,
    CalibrationResult calibration,
  ) {
    if (kit.references.isEmpty) {
      return AnalysisResult(
        kitId: kitId,
        topMatches: [],
        isUnknown: true,
        classificationDeltaE: double.nan,
        extractedHSV: extractedHsv,
        extractedLab: extractedLab,
        calibrationDeltaE: calibration.meanDeltaE,
        calibrationConfidence: calibration.confidence,
        rawImagePath: calibration.rawImagePath,
        calibratedImagePath: calibration.calibratedImagePath,
      );
    }

    final standardLab = _opencvLabToStandard(extractedLab);
    final candidates = <CandidateMatch>[];

    for (final ref in kit.references) {
      final dist = _hsvDistance(extractedHsv, ref.hsv);
      final deltaE = _deltaE76(standardLab, ref.labReference);
      candidates.add(CandidateMatch(
        substance: ref.substance,
        distance: dist,
        deltaE: deltaE,
        referenceHSV: ref.hsv,
        colorHex: ref.colorHex,
      ));
    }

    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    final topMatches = candidates.take(3).toList();

    // Check unknown flag using top match
    final topMatch = topMatches.first;
    final topRef = kit.references.firstWhere((r) => r.substance == topMatch.substance);
    final isUnknown = _isUnknown(topMatch.distance, topRef);

    return AnalysisResult(
      kitId: kitId,
      topMatches: topMatches,
      isUnknown: isUnknown,
      classificationDeltaE: topMatch.deltaE,
      extractedHSV: extractedHsv,
      extractedLab: extractedLab,
      calibrationDeltaE: calibration.meanDeltaE,
      calibrationConfidence: calibration.confidence,
      rawImagePath: calibration.rawImagePath,
      calibratedImagePath: calibration.calibratedImagePath,
    );
  }

  double _hsvDistance(List<double> hsv1, List<double> hsv2) {
    // Hue is 0-180 in OpenCV
    final hDiff = (hsv1[0] - hsv2[0]).abs();
    final dH = min(hDiff, 180.0 - hDiff);
    final dS = hsv1[1] - hsv2[1];
    final dV = hsv1[2] - hsv2[2];
    return sqrt(dH * dH + dS * dS + dV * dV);
  }

  bool _isUnknown(double topDistance, KitReference topMatch) {
    final dH = topMatch.hsvToleranceNormalized[0];
    final dS = topMatch.hsvToleranceNormalized[1];
    final dV = topMatch.hsvToleranceNormalized[2];
    final maxTolerance = sqrt(dH * dH + dS * dS + dV * dV);
    return topDistance > maxTolerance;
  }

  List<double> _opencvLabToStandard(List<double> opencvLab) {
    return [
      opencvLab[0] * 100.0 / 255.0,  // L: 0-255 -> 0-100
      opencvLab[1] - 128.0,          // a: 0-255 -> -128 to 127
      opencvLab[2] - 128.0,          // b: 0-255 -> -128 to 127
    ];
  }

  double _deltaE76(List<double> lab1, List<double> lab2) {
    final dL = lab1[0] - lab2[0];
    final da = lab1[1] - lab2[1];
    final db = lab1[2] - lab2[2];
    return sqrt(dL * dL + da * da + db * db);
  }
}
