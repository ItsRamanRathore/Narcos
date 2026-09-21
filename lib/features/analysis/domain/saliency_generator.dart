import 'dart:io';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'tflite_service.dart';
import 'cnn_classifier.dart';

class SaliencyGenerator {
  final CnnClassifier _classifier;

  SaliencyGenerator(this._classifier);

  Future<String?> generate(cv.Mat calibratedMat, String kitId) async {
    // 1. Get base confidence for top class
    final baseResult = await _classifier.classify(calibratedMat, kitId);
    if (baseResult == null) return null;
    
    final targetClass = baseResult.topSubstance;
    final baseConf = baseResult.probabilities[targetClass] ?? 0.0;
    
    final heatmap = List<double>.filled(16, 0.0);
    
    // 2. Run 16 occlusion passes
    for (int i = 0; i < 16; i++) {
      cv.Mat? occluded;
      try {
        occluded = calibratedMat.clone();
        _occludeRegion(occluded, i);
        
        final maskedResult = await _classifier.classify(occluded, kitId);
        final maskedConf = maskedResult?.probabilities[targetClass] ?? 0.0;
        
        heatmap[i] = baseConf - maskedConf; // Confidence drop
      } finally {
        occluded?.dispose();
      }
    }
    
    // 3. Render and save heatmap
    return _renderAndSaveHeatmap(heatmap, calibratedMat);
  }

  void _occludeRegion(cv.Mat mat, int regionIndex) {
    final w = mat.cols;
    final h = mat.rows;
    
    final cellW = w ~/ 4;
    final cellH = h ~/ 4;
    
    final row = regionIndex ~/ 4;
    final col = regionIndex % 4;
    
    final x = col * cellW;
    final y = row * cellH;
    
    // Blackout the region
    final rect = cv.Rect(x, y, cellW, cellH);
    final sub = mat.region(rect);
    sub.setTo(cv.Scalar.all(0)); // black
    sub.dispose(); // only disposes the Mat header, not data
  }

  Future<String> _renderAndSaveHeatmap(List<double> heatmap, cv.Mat original) async {
    // Normalize heatmap
    var minVal = heatmap[0];
    var maxVal = heatmap[0];
    for (var v in heatmap) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }
    
    final range = maxVal - minVal;
    
    cv.Mat? overlay;
    cv.Mat? blended;
    try {
      overlay = original.clone();
      
      final cellW = original.cols ~/ 4;
      final cellH = original.rows ~/ 4;
      
      for (int i = 0; i < 16; i++) {
        var intensity = 0.0;
        if (range > 0) {
          intensity = ((heatmap[i] - minVal) / range).clamp(0.0, 1.0);
        }
        
        if (intensity > 0.5) { // Only highlight top dropping regions
          final row = i ~/ 4;
          final col = i % 4;
          final x = col * cellW;
          final y = row * cellH;
          
          final rect = cv.Rect(x, y, cellW, cellH);
          cv.rectangle(overlay, rect, cv.Scalar(0, 0, 255), thickness: -1); // Red overlay
        }
      }
      
      // Blend 30% overlay with original
      blended = cv.Mat.empty();
      cv.addWeighted(overlay, 0.3, original, 0.7, 0.0, dst: blended);
      
      // Save to temp dir
      final tempDir = await getTemporaryDirectory();
      final uuid = const Uuid().v4();
      final path = '\${tempDir.path}/gradcam_$uuid.png';
      
      cv.imwrite(path, blended);
      return path;
    } finally {
      overlay?.dispose();
      blended?.dispose();
    }
  }
}
