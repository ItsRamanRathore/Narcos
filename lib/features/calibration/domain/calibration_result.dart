import 'package:ml_linalg/matrix.dart';

enum CalibrationConfidenceLevel { excellent, good, poor, fail }

class CalibrationConfidence {
  static const double excellent = 2.0;   // ΔE < 2: imperceptible difference
  static const double good = 5.0;        // ΔE < 5: acceptable for field use
  static const double poor = 10.0;       // ΔE < 10: visible difference, warn operator
  static const double fail = 10.0;       // ΔE >= 10: reject calibration

  static CalibrationConfidenceLevel classify(double meanDeltaE) {
    if (meanDeltaE < excellent) return CalibrationConfidenceLevel.excellent;
    if (meanDeltaE < good)      return CalibrationConfidenceLevel.good;
    if (meanDeltaE < poor)      return CalibrationConfidenceLevel.poor;
    return CalibrationConfidenceLevel.fail;
  }
}

class CalibrationResult {
  final bool success;
  final double meanDeltaE;
  final List<double> perSwatchDeltaE;
  final Matrix? ccm;
  final String rawImagePath;
  final String calibratedImagePath;
  final CalibrationConfidenceLevel confidence;
  final String? failureReason;

  CalibrationResult({
    required this.success,
    this.meanDeltaE = 0.0,
    this.perSwatchDeltaE = const [],
    this.ccm,
    this.rawImagePath = '',
    this.calibratedImagePath = '',
    this.confidence = CalibrationConfidenceLevel.fail,
    this.failureReason,
  });
}
