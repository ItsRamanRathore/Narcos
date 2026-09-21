import 'dart:math';
import 'analysis_result.dart';
import 'fusion_result.dart';

class FusionService {
  // Maximum possible Euclidean distance in OpenCV HSV space
  // H: max circular diff = 90 (0-180 range, circular)
  // S: max diff = 255 (0-255 range)
  // V: max diff = 255 (0-255 range)
  // sqrt(90² + 255² + 255²) ≈ 371.7
  static const double _maxHsvDistance = 371.7;

  FusionResult classify(
    AnalysisResult hsvResult,
    CnnResult? cnnResult,
    String kitVersion,
    String? modelVersion,
  ) {
    if (cnnResult == null) {
      return _buildFallback(hsvResult, kitVersion);
    }

    final hsvTop = hsvResult.topMatches.first;
    final hsvConf = _hsvDistanceToConfidence(hsvTop.distance);
    
    final cnnTopSubstance = cnnResult.topSubstance;
    final cnnConf = cnnResult.probabilities.values.reduce(max);

    bool isInconclusive = false;
    bool isUnknown = false;
    
    // Priority 1: CNN confidence < 0.4 -> INCONCLUSIVE
    if (cnnConf < 0.4) {
      isInconclusive = true;
    }
    // Priority 2: HSV isUnknown AND CNN confidence < 0.6 -> UNKNOWN
    else if (hsvResult.isUnknown && cnnConf < 0.6) {
      isUnknown = true;
    }
    // Priority 3: Top-1 substances differ AND both confident (>0.6) -> INCONCLUSIVE
    else if (hsvTop.substance != cnnTopSubstance && hsvConf > 0.6 && cnnConf > 0.6) {
      isInconclusive = true;
    }

    String finalSubstance = cnnTopSubstance;
    double finalConfidence = cnnConf;

    if (!isInconclusive && !isUnknown) {
      if (hsvTop.substance == cnnTopSubstance) {
        finalConfidence = (hsvConf * 0.4) + (cnnConf * 0.6);
        finalSubstance = cnnTopSubstance;
      } else {
        // Disagreement but not high confidence -> side with higher weight (CNN usually wins here, 
        // but since we checked >0.6 for both, one is <=0.6. The CNN is weighted 0.6, so we just use CNN as primary but lower confidence).
        finalConfidence = cnnConf * 0.6; 
      }
    } else if (isUnknown) {
      finalSubstance = 'Unknown';
      finalConfidence = 0.0;
    } else { // isInconclusive
      finalSubstance = 'Inconclusive';
      finalConfidence = 0.0;
    }

    return FusionResult(
      kitId: hsvResult.kitId,
      kitVersion: kitVersion,
      modelVersion: modelVersion,
      classifiedAt: DateTime.now(),
      hsvWeight: 0.4,
      cnnWeight: 0.6,
      calibratedImagePath: hsvResult.calibratedImagePath,
      finalSubstance: finalSubstance,
      finalConfidence: finalConfidence,
      isUnknown: isUnknown,
      isInconclusive: isInconclusive,
      hsvResult: hsvResult,
      cnnProbabilities: cnnResult.probabilities,
      isSingleLayerFallback: false,
    );
  }

  FusionResult _buildFallback(AnalysisResult hsvResult, String kitVersion) {
    final hsvTop = hsvResult.topMatches.isEmpty ? null : hsvResult.topMatches.first;
    final hsvConf = hsvTop != null ? _hsvDistanceToConfidence(hsvTop.distance) : 0.0;

    return FusionResult(
      kitId: hsvResult.kitId,
      kitVersion: kitVersion,
      modelVersion: null,
      classifiedAt: DateTime.now(),
      hsvWeight: 1.0,
      cnnWeight: 0.0,
      calibratedImagePath: hsvResult.calibratedImagePath,
      finalSubstance: hsvResult.isUnknown ? 'Unknown' : (hsvTop?.substance ?? 'Unknown'),
      finalConfidence: hsvResult.isUnknown ? 0.0 : hsvConf,
      isUnknown: hsvResult.isUnknown,
      isInconclusive: false,
      hsvResult: hsvResult,
      cnnProbabilities: null,
      isSingleLayerFallback: true,
    );
  }

  double _hsvDistanceToConfidence(double distance) {
    return (1.0 - (distance / _maxHsvDistance)).clamp(0.0, 1.0);
  }
}
