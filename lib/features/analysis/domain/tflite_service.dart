import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  Interpreter? _interpreter;
  String? _loadedKitId;
  
  Future<Interpreter?> getInterpreter(String kitId) async {
    // Reuse if same kit
    if (_loadedKitId == kitId && _interpreter != null) {
      return _interpreter;
    }
    
    // Close previous interpreter if switching kits
    _interpreter?.close();
    _interpreter = null;
    _loadedKitId = null;
    
    try {
      final options = InterpreterOptions();
      // Try GPU delegate first, fall back to CPU
      try {
        if (Platform.isAndroid) {
          options.addDelegate(GpuDelegateV2());
        } else if (Platform.isIOS) {
          options.addDelegate(GpuDelegate());
        }
      } catch (_) {
        // GPU not available, use CPU
      }
      
      _interpreter = await Interpreter.fromAsset(
        'assets/models/$kitId.tflite',
        options: options,
      );
      _loadedKitId = kitId;
      return _interpreter;
    } on Exception catch (e) {
      if (e.toString().contains('FlatBuffers') || e.toString().contains('Unable to create interpreter')) {
        return null;  // invalid model file or not found
      }
      return null;
    } catch (_) {
      return null;  // model not found → single layer fallback
    }
  }
  
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loadedKitId = null;
  }
}
