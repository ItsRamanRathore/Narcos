import 'dart:isolate';
import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class FrameMessage {
  final Uint8List bytes;
  final int width;
  final int height;
  final String platform;
  final double blurThreshold;
  final double minLuminance;
  final double cardMinArea;

  FrameMessage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.platform,
    required this.blurThreshold,
    required this.minLuminance,
    required this.cardMinArea,
  });
}

class QualityGateResult {
  final bool isBlurred;
  final bool isBrightEnough;
  final bool isCardDetected;
  final double blurScore;
  final double luminanceScore;
  final double cardAreaFraction;

  QualityGateResult({
    required this.isBlurred,
    required this.isBrightEnough,
    required this.isCardDetected,
    required this.blurScore,
    required this.luminanceScore,
    required this.cardAreaFraction,
  });
}

class CvIsolate {
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _isReady = false;

  Future<void> init() async {
    if (_isReady) return;
    await Isolate.spawn(_isolateEntry, _receivePort.sendPort);
    _sendPort = await _receivePort.first as SendPort;
    _isReady = true;
  }

  Future<QualityGateResult> processFrame(FrameMessage message) async {
    if (!_isReady) await init();
    final responsePort = ReceivePort();
    _sendPort!.send([message, responsePort.sendPort]);
    return await responsePort.first as QualityGateResult;
  }

  static void _isolateEntry(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      final frameMessage = message[0] as FrameMessage;
      final replyPort = message[1] as SendPort;

      final result = _process(frameMessage);
      replyPort.send(result);
    });
  }

  static QualityGateResult _process(FrameMessage msg) {
    cv.Mat grayscaleMat;
    if (msg.platform == 'android') {
      grayscaleMat = cv.Mat.fromList(msg.height, msg.width, cv.MatType.CV_8UC1, msg.bytes);
    } else {
      final bgraMat = cv.Mat.fromList(msg.height, msg.width, cv.MatType.CV_8UC4, msg.bytes);
      grayscaleMat = cv.cvtColor(bgraMat, cv.COLOR_BGRA2GRAY);
    }

    final luminanceScore = computeLuminance(grayscaleMat);
    final blurScore = computeBlurScore(grayscaleMat);
    final cardAreaFraction = detectCard(grayscaleMat);

    final isBlurred = blurScore < msg.blurThreshold;
    final isBrightEnough = luminanceScore >= msg.minLuminance;
    final isCardDetected = cardAreaFraction >= msg.cardMinArea;

    return QualityGateResult(
      isBlurred: isBlurred,
      isBrightEnough: isBrightEnough,
      isCardDetected: isCardDetected,
      blurScore: blurScore,
      luminanceScore: luminanceScore,
      cardAreaFraction: cardAreaFraction,
    );
  }

  static double computeLuminance(cv.Mat grayscaleMat) {
    final roi = cv.Rect(
      grayscaleMat.width ~/ 4,
      grayscaleMat.height ~/ 4,
      grayscaleMat.width ~/ 2,
      grayscaleMat.height ~/ 2,
    );
    final center = grayscaleMat.region(roi);
    return cv.mean(center).val[0];
  }

  // CALIBRATION NOTE:
  // Laplacian variance threshold of 100 was determined empirically
  // on a mid-range Android device at 1080p.
  // High-resolution sensors (48MP+) produce higher variance scores
  // for the same sharpness level.
  // If operators report false blur rejections on specific devices,
  // increase this value in app_preferences without an app update.
  // Suggested range: 80-150 depending on sensor resolution.
  static double computeBlurScore(cv.Mat grayscaleMat) {
    final laplacian = cv.laplacian(grayscaleMat, cv.MatType.CV_64F);
    final meanStdDev = cv.meanStdDev(laplacian);
    final stdDev = meanStdDev.$2.val[0];
    return stdDev * stdDev; 
  }

  static double detectCard(cv.Mat grayscaleMat) {
    final blurred = cv.gaussianBlur(grayscaleMat, (5, 5), 0, sigmaY: 0);
    final edges = cv.canny(blurred, 30, 100);
    
    final kernel = cv.getStructuringElement(cv.MORPH_RECT, (5, 5));
    final closedEdges = cv.dilate(edges, kernel);

    final contoursAndHierarchy = cv.findContours(
      closedEdges, 
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );
    final contours = contoursAndHierarchy.$1;
    
    final frameArea = grayscaleMat.width * grayscaleMat.height;
    double maxCardArea = 0.0;

    for (final contour in contours) {
      final area = cv.contourArea(contour);
      final fraction = area / frameArea;
      
      if (fraction > maxCardArea) {
        final rect = cv.boundingRect(contour);
        final rectArea = rect.width * rect.height;
        
        if (rectArea > 0) {
          final fillRatio = area / rectArea;
          if (fillRatio > 0.5) {
            maxCardArea = fraction;
          }
        }
      }
    }
    return maxCardArea;
  }
}
