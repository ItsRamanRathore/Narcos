import '../../analysis/domain/analysis_result.dart';

class CnnResult {
  final String topSubstance;
  final Map<String, double> probabilities;
  
  CnnResult({
    required this.topSubstance,
    required this.probabilities,
  });
}

class FusionResult {
  final String kitId;
  final String kitVersion;           // which JSON version was used
  final String? modelVersion;        // tflite model version (from labels JSON)
  final DateTime classifiedAt;       // timestamp of classification
  final double hsvWeight;            // 0.4 - stored for audit trail
  final double cnnWeight;            // 0.6 - stored for audit trail
  final String calibratedImagePath;  // path to image that was classified

  final String finalSubstance;       // The decided substance string
  final double finalConfidence;      // 0.0 to 1.0
  final bool isUnknown;              // True if truly unknown substance
  final bool isInconclusive;         // True if CNN and HSV heavily conflict

  // Traceability for Part 07
  final AnalysisResult hsvResult;
  final Map<String, double>? cnnProbabilities;
  final bool isSingleLayerFallback;  // True if CNN was missing (HSV only)

  FusionResult({
    required this.kitId,
    required this.kitVersion,
    this.modelVersion,
    required this.classifiedAt,
    required this.hsvWeight,
    required this.cnnWeight,
    required this.calibratedImagePath,
    required this.finalSubstance,
    required this.finalConfidence,
    required this.isUnknown,
    required this.isInconclusive,
    required this.hsvResult,
    this.cnnProbabilities,
    required this.isSingleLayerFallback,
  });
}
