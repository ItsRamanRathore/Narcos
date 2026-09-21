import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../../../core/constants/capture_zones.dart';

class ColorExtractor {
  List<List<double>> extractSwatches(cv.Mat dewarpedMat) {
    final extractedColors = <List<double>>[];
    
    for (final rect in CaptureZones.swatchRegions) {
      cv.Mat? swatchMat;
      try {
        swatchMat = dewarpedMat.region(rect);
        final scalar = cv.mean(swatchMat);
        // scalar.val contains [B, G, R, Alpha]
        // Store as [R, G, B] since ground truth is RGB
        extractedColors.add([scalar.val[2], scalar.val[1], scalar.val[0]]);
      } finally {
        swatchMat?.dispose();
      }
    }
    
    return extractedColors;
  }
}
