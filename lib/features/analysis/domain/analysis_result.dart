import '../../calibration/domain/calibration_result.dart';

class CandidateMatch {
  final String substance;
  final double distance;         // Euclidean distance in HSV space
  final double deltaE;           // Lab ΔE against this substance
  final List<double> referenceHSV;
  final String colorHex;         // for swatch display in UI

  CandidateMatch({
    required this.substance,
    required this.distance,
    required this.deltaE,
    required this.referenceHSV,
    required this.colorHex,
  });
}

class AnalysisResult {
  // Classification output
  final String kitId;
  final List<CandidateMatch> topMatches;      // top 3, sorted by distance
  final bool isUnknown;                       // true if all distances > tolerance
  final double classificationDeltaE;          // ΔE against top match lab_reference
  
  // Raw extracted values (for fusion layer in Part 06)
  final List<double> extractedHSV;            // OpenCV scale
  final List<double> extractedLab;            // for fusion comparison
  
  // From Part 04 (passed through, not recomputed)
  final double calibrationDeltaE;             // overall calibration quality
  final CalibrationConfidenceLevel calibrationConfidence;
  
  // Paths
  final String rawImagePath;
  final String calibratedImagePath;

  AnalysisResult({
    required this.kitId,
    required this.topMatches,
    required this.isUnknown,
    required this.classificationDeltaE,
    required this.extractedHSV,
    required this.extractedLab,
    required this.calibrationDeltaE,
    required this.calibrationConfidence,
    required this.rawImagePath,
    required this.calibratedImagePath,
  });
}
