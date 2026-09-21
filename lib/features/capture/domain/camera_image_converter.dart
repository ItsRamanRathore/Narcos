import 'dart:io';
import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class CameraImageConverter {
  /// Converts CameraImage to OpenCV-compatible grayscale Mat
  /// Handles platform differences automatically
  static cv.Mat toGrayscaleMat(CameraImage image) {
    if (Platform.isAndroid) {
      // Android: NV21 YUV — Y plane is index 0, already grayscale
      final yPlane = image.planes[0];
      return cv.Mat.fromList(
        image.height,
        image.width,
        cv.MatType.CV_8UC1,
        yPlane.bytes,
      );
    } else if (Platform.isIOS) {
      // iOS: BGRA8888 — convert to grayscale
      final bytes = image.planes[0].bytes;
      final mat = cv.Mat.fromList(
        image.height,
        image.width,
        cv.MatType.CV_8UC4,
        bytes,
      );
      return cv.cvtColor(mat, cv.COLOR_BGRA2GRAY);
    }
    throw UnsupportedError('Platform not supported');
  }

  /// Converts CameraImage to BGR Mat for color analysis
  /// Used by Part 04 calibration, not quality gates
  static cv.Mat toBGRMat(CameraImage image) {
    if (Platform.isAndroid) {
      final yPlane = image.planes[0];
      final vPlane = image.planes[2];
      
      // Combine YUV planes and convert to BGR
      // NV21 interleaves V and U, so we just take Y and VU planes.
      final yuv = cv.Mat.fromList(
        image.height + (image.height ~/ 2),
        image.width,
        cv.MatType.CV_8UC1,
        [...yPlane.bytes, ...vPlane.bytes], // Simple concatenation for NV21
      );
      return cv.cvtColor(yuv, cv.COLOR_YUV2BGR_NV21);
    } else if (Platform.isIOS) {
      final bytes = image.planes[0].bytes;
      final mat = cv.Mat.fromList(
        image.height,
        image.width,
        cv.MatType.CV_8UC4,
        bytes,
      );
      return cv.cvtColor(mat, cv.COLOR_BGRA2BGR);
    }
    throw UnsupportedError('Platform not supported');
  }
}
