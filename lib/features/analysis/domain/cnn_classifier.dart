import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tflite_service.dart';
import 'fusion_result.dart';

class CnnClassifier {
  final TFLiteService _tfliteService;

  CnnClassifier(this._tfliteService);

  Future<CnnResult?> classify(cv.Mat calibratedMat, String kitId) async {
    final interpreter = await _tfliteService.getInterpreter(kitId);
    if (interpreter == null) {
      return null; // Fallback to HSV
    }

    final labelsData = await _loadLabels(kitId);
    if (labelsData == null) {
      return null;
    }

    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    // 1. Resize to 224x224
    cv.Mat? resized;
    cv.Mat? rgbMat;
    try {
      resized = cv.resize(calibratedMat, (224, 224));
      
      // 2. Convert BGR to RGB
      rgbMat = cv.cvtColor(resized, cv.COLOR_BGR2RGB);

      // 3. Preprocess based on input type
      Object input;
      if (inputTensor.type == TensorType.uint8) {
        input = rgbMat.data.reshape([1, 224, 224, 3]);
      } else if (inputTensor.type == TensorType.float32) {
        final floatData = Float32List(224 * 224 * 3);
        final bytes = rgbMat.data;
        for (int i = 0; i < bytes.length; i++) {
          floatData[i] = bytes[i] / 255.0; // Standard 0-1 normalization
        }
        input = floatData.reshape([1, 224, 224, 3]);
      } else {
        return null; // Unsupported type
      }

      // 4. Run inference
      final outputShape = outputTensor.shape;
      final numClasses = outputShape.last;
      
      var outputBuffer = List<double>.filled(numClasses, 0.0).reshape([1, numClasses]);
      
      if (outputTensor.type == TensorType.uint8) {
        var uint8Output = List<int>.filled(numClasses, 0).reshape([1, numClasses]);
        interpreter.run(input, uint8Output);
        
        final scale = outputTensor.params.scale;
        final zeroPoint = outputTensor.params.zeroPoint;
        if (scale > 0) {
           for(int i=0; i<numClasses; i++) {
              (outputBuffer[0] as List<double>)[i] = ((uint8Output[0] as List<int>)[i] - zeroPoint) * scale;
           }
        }
      } else {
        interpreter.run(input, outputBuffer);
      }

      // 5. Parse output
      final probs = outputBuffer[0] as List<double>;
      
      double maxProb = -1;
      int maxIndex = -1;
      final probabilities = <String, double>{};
      
      final classes = labelsData['classes'] as List<dynamic>;
      for (int i = 0; i < numClasses && i < classes.length; i++) {
        final className = classes[i]['substance'] as String;
        probabilities[className] = probs[i];
        if (probs[i] > maxProb) {
          maxProb = probs[i];
          maxIndex = i;
        }
      }
      
      if (maxIndex == -1) return null;
      
      final topSubstance = classes[maxIndex]['substance'] as String;

      return CnnResult(
        topSubstance: topSubstance,
        probabilities: probabilities,
      );
      
    } finally {
      resized?.dispose();
      rgbMat?.dispose();
    }
  }

  Future<Map<String, dynamic>?> _loadLabels(String kitId) async {
    try {
      final jsonString = await rootBundle.loadString('assets/models/\${kitId}_labels.json');
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
