import 'package:opencv_dart/opencv_dart.dart' as cv;

class CardDetector {
  Future<List<cv.Point2f>?> detectCard(cv.Mat bgrMat) async {
    cv.Mat? grayMat;
    cv.Mat? blurMat;
    cv.Mat? edges;
    try {
      grayMat = cv.cvtColor(bgrMat, cv.COLOR_BGR2GRAY);
      blurMat = cv.gaussianBlur(grayMat, (5, 5), 0);
      edges = cv.canny(blurMat, 50, 150);

      final contours = cv.findContours(edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
      if (contours.$1.isEmpty) return null;

      final validContours = contours.$1.toList()
        ..sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

      for (var contour in validContours) {
        final perimeter = cv.arcLength(contour, true);
        final approx = cv.approxPolyDP(contour, 0.02 * perimeter, true);

        if (approx.length == 4) {
          final points = approx.toList().map((p) => cv.Point2f(p.x.toDouble(), p.y.toDouble())).toList();
          return _orderCorners(points);
        }
      }

      return null;
    } finally {
      grayMat?.dispose();
      blurMat?.dispose();
      edges?.dispose();
    }
  }

  List<cv.Point2f> _orderCorners(List<cv.Point2f> points) {
    // Sort by sum of coordinates: top-left has smallest sum, bottom-right has largest
    points.sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final topLeft = points[0];
    final bottomRight = points[3];
    
    // Sort remaining two by difference: top-right has smallest diff, bottom-left largest
    final remaining = [points[1], points[2]];
    remaining.sort((a, b) => (a.x - a.y).compareTo(b.x - b.y));
    final topRight = remaining[0];
    final bottomLeft = remaining[1];
    
    return [topLeft, topRight, bottomRight, bottomLeft];
  }
}
