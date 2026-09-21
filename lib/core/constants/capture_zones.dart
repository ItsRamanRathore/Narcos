import 'dart:ui';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class CaptureZones {
  // Reference card zone — top 40% of frame
  static const referenceCardZone = Rect.fromLTWH(0.05, 0.02, 0.90, 0.38);
  
  // Test kit zone — bottom 40% of frame  
  static const testKitZone = Rect.fromLTWH(0.05, 0.55, 0.90, 0.38);
  
  // All values are fractions of frame dimensions (0.0 to 1.0)
  // Part 04 imports these same constants for its crop calculations

  // Dewarped card dimensions
  static const int dewarpedWidth = 800;
  static const int dewarpedHeight = 500;
  
  // Swatch regions on dewarped card (x, y, width, height in pixels)
  static final List<cv.Rect> swatchRegions = [
    cv.Rect(50,  200, 80, 80),  // black
    cv.Rect(180, 200, 80, 80),  // white
    cv.Rect(310, 200, 80, 80),  // red
    cv.Rect(440, 200, 80, 80),  // green
    cv.Rect(570, 200, 80, 80),  // blue
    cv.Rect(670, 200, 80, 80),  // gray
  ];
  
  // Minimum viable set for CCM: 6 patches (Option B)
  static const List<List<double>> customCardGroundTruth = [
    [0, 0, 0],        // black
    [255, 255, 255],  // white
    [255, 0, 0],      // red
    [0, 255, 0],      // green
    [0, 0, 255],      // blue
    [128, 128, 128],  // mid gray
  ];
  
  // Test kit zone on dewarped card
  static final cv.Rect testKitRegion = cv.Rect(100, 50, 600, 120);

  // ROI for HSV sampling — center 40% of the test kit region
  // Avoids cassette borders and edge artifacts
  static const double hsvSampleRoiFraction = 0.4;
}
