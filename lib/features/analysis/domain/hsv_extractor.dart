import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../../../core/constants/capture_zones.dart';

class HsvExtractorResult {
  final List<double> hsv;
  final List<double> lab;
  HsvExtractorResult(this.hsv, this.lab);
}

class HsvExtractor {
  HsvExtractorResult extract(cv.Mat calibratedBgrCrop) {
    cv.Mat? roi;
    cv.Mat? hsvMat;
    cv.Mat? labMat;
    
    try {
      final w = calibratedBgrCrop.cols;
      final h = calibratedBgrCrop.rows;
      final fraction = CaptureZones.hsvSampleRoiFraction;
      
      final rect = cv.Rect(
        (w * (1 - fraction) / 2).toInt(),
        (h * (1 - fraction) / 2).toInt(),
        (w * fraction).toInt(),
        (h * fraction).toInt(),
      );
      
      roi = calibratedBgrCrop.region(rect);
      
      labMat = cv.cvtColor(roi!, cv.COLOR_BGR2Lab);
      hsvMat = cv.cvtColor(roi!, cv.COLOR_BGR2HSV);
      
      final hsvMean = cv.mean(hsvMat);
      final labMean = cv.mean(labMat);
      
      final hsv = [hsvMean.val[0], hsvMean.val[1], hsvMean.val[2]];
      final lab = [labMean.val[0], labMean.val[1], labMean.val[2]];
      
      return HsvExtractorResult(hsv, lab);
    } finally {
      roi?.dispose();
      hsvMat?.dispose();
      labMat?.dispose();
    }
  }
}
