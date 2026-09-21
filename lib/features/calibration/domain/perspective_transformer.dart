import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../../../core/constants/capture_zones.dart';

class PerspectiveTransformer {
  cv.Mat dewarp(cv.Mat src, List<cv.Point2f> corners) {
    // Destination points mapped to the standardized 800x500 card size
    final dstPoints = [
      cv.Point2f(0, 0),
      cv.Point2f(CaptureZones.dewarpedWidth.toDouble(), 0),
      cv.Point2f(CaptureZones.dewarpedWidth.toDouble(), CaptureZones.dewarpedHeight.toDouble()),
      cv.Point2f(0, CaptureZones.dewarpedHeight.toDouble()),
    ];

    final srcVec = cv.VecPoint2f.fromList(corners);
    final dstVec = cv.VecPoint2f.fromList(dstPoints);
    cv.Mat? transformMatrix;
    
    try {
      transformMatrix = cv.getPerspectiveTransform2f(srcVec, dstVec);
      final dewarped = cv.warpPerspective(
        src,
        transformMatrix,
        (CaptureZones.dewarpedWidth, CaptureZones.dewarpedHeight),
      );
      return dewarped;
    } finally {
      srcVec.dispose();
      dstVec.dispose();
      transformMatrix?.dispose();
    }
  }
}
