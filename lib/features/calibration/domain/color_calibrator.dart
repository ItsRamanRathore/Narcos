import 'dart:math';
import 'package:ml_linalg/matrix.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ColorCalibrator {
  /// Computes the 3x3 Color Correction Matrix using linear least squares
  Matrix? computeCCM(Matrix s, Matrix t) {
    try {
      // CCM = pinv(S) * T
      // pinv(S) = (S^T * S)^-1 * S^T
      final st = s.transpose();
      final stS = st * s;
      final stSInv = stS.inverse(); // Throws if singular
      final pinvS = stSInv * st;
      return pinvS * t; // Result is 3x3 CCM
    } catch (_) {
      return null;
    }
  }

  /// Calculates the delta E 76 score between two Lab color arrays
  double deltaE76(List<double> lab1, List<double> lab2) {
    final dL = lab1[0] - lab2[0];
    final da = lab1[1] - lab2[1];
    final db = lab1[2] - lab2[2];
    return sqrt(dL * dL + da * da + db * db);
  }

  /// Applies the 3x3 CCM to a BGR OpenCV Mat efficiently
  cv.Mat applyCCMToMat(cv.Mat bgrMat, Matrix ccm) {
    cv.Mat? floatMat;
    cv.Mat? reshaped;
    cv.Mat? ccmMat;
    cv.Mat? result;
    cv.Mat? corrected;
    cv.Mat? ccmMatT;
    
    try {
      floatMat = bgrMat.convertTo(cv.MatType.CV_32FC3, alpha: 1.0 / 255.0);

      // Reshape to Nx3 matrix for matrix multiplication
      final rows = floatMat.rows * floatMat.cols;
      reshaped = floatMat.reshape(1, rows); // Nx3

      // Convert CCM to cv.Mat
      // The CCM from ml_linalg is a 3x3 matrix mapping RGB to RGB.
      // Since our input Mat is BGR, we need to apply the matrix carefully,
      // or we can just swap channels before and after. Let's do RGB conversion to keep math simple.
      cv.cvtColor(bgrMat, cv.COLOR_BGR2RGB, dst: bgrMat);
      floatMat = bgrMat.convertTo(cv.MatType.CV_32FC3, alpha: 1.0 / 255.0);
      reshaped = floatMat.reshape(1, rows);

      ccmMat = _ccmToOpenCVMat(ccm);
      ccmMatT = ccmMat.t();

      // Matrix multiply: result = reshaped * CCM^T
      result = cv.Mat.empty();
      cv.gemm(reshaped, ccmMatT, 1.0, cv.Mat.empty(), 0.0, dst: result);

      // Reshape back, clip, convert to uint8
      corrected = result.reshape(3, floatMat.rows);
      cv.threshold(corrected, 1.0, 1.0, cv.THRESH_TRUNC);
      
      // Convert back to BGR
      bgrMat = corrected.convertTo(cv.MatType.CV_8UC3, alpha: 255.0);
      cv.cvtColor(bgrMat, cv.COLOR_RGB2BGR, dst: bgrMat);

      return bgrMat;
    } finally {
      floatMat?.dispose();
      reshaped?.dispose();
      ccmMat?.dispose();
      ccmMatT?.dispose();
      result?.dispose();
      corrected?.dispose();
    }
  }

  cv.Mat _ccmToOpenCVMat(Matrix ccm) {
    final elements = <double>[];
    for (var row in ccm.rows) {
      elements.addAll(row);
    }
    return cv.Mat.fromList(3, 3, cv.MatType.CV_64FC1, elements);
  }
}
