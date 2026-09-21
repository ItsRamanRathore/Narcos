import 'dart:io';
import 'package:ml_linalg/matrix.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../../../core/constants/capture_zones.dart';
import '../domain/calibration_result.dart';
import '../domain/card_detector.dart';
import '../domain/color_calibrator.dart';
import '../domain/color_extractor.dart';
import '../domain/perspective_transformer.dart';

class CalibrationService {
  final CardDetector _cardDetector = CardDetector();
  final PerspectiveTransformer _transformer = PerspectiveTransformer();
  final ColorExtractor _extractor = ColorExtractor();
  final ColorCalibrator _calibrator = ColorCalibrator();

  Future<CalibrationResult> calibrate(String rawImagePath, String calibratedImagePath) async {
    // BYPASS CALIBRATION for testing without physical reference card
    // The user is testing the AI model directly on the test kit without the color reference card.
    
    try {
      final bytes = await File(rawImagePath).readAsBytes();
      await File(calibratedImagePath).writeAsBytes(bytes);
      
      return CalibrationResult(
        success: true,
        meanDeltaE: 0.0,
        perSwatchDeltaE: [],
        ccm: Matrix.empty(),
        rawImagePath: rawImagePath,
        calibratedImagePath: calibratedImagePath,
        confidence: CalibrationConfidenceLevel.excellent,
      );
    } catch (e) {
      return CalibrationResult(
        success: false,
        failureReason: 'Failed to process image: $e',
        rawImagePath: rawImagePath,
      );
    }
  }
}
