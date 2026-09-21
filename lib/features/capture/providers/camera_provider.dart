import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../domain/quality_gate_service.dart';

enum FocusState { hunting, locking, locked, lost }

class CameraState {
  final CameraController? controller;
  final bool isInitialized;
  final bool hasPermission;
  final FocusState focusState;
  final QualityGateResult? latestQuality;
  final bool isProcessingFrame;

  CameraState({
    this.controller,
    this.isInitialized = false,
    this.hasPermission = false,
    this.focusState = FocusState.hunting,
    this.latestQuality,
    this.isProcessingFrame = false,
  });

  CameraState copyWith({
    CameraController? controller,
    bool? isInitialized,
    bool? hasPermission,
    FocusState? focusState,
    QualityGateResult? latestQuality,
    bool? isProcessingFrame,
  }) {
    return CameraState(
      controller: controller ?? this.controller,
      isInitialized: isInitialized ?? this.isInitialized,
      hasPermission: hasPermission ?? this.hasPermission,
      focusState: focusState ?? this.focusState,
      latestQuality: latestQuality ?? this.latestQuality,
      isProcessingFrame: isProcessingFrame ?? this.isProcessingFrame,
    );
  }
}

class CameraNotifier extends Notifier<CameraState> {
  final CvIsolate _cvIsolate = CvIsolate();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  @override
  CameraState build() {
    _initCamera();
    return CameraState();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        // Handle no cameras
        return;
      }
      
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      
      // Initialize CV isolate
      await _cvIsolate.init();

      state = state.copyWith(
        controller: controller,
        isInitialized: true,
        hasPermission: true,
      );

      _startImageStream();
    } catch (e) {
      if (e is CameraException) {
        if (e.code == 'CameraAccessDenied') {
          state = state.copyWith(hasPermission: false);
        }
      }
    }
  }

  void _startImageStream() {
    state.controller?.startImageStream((CameraImage image) {
      _processFrame(image);
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (state.isProcessingFrame) return; // Drop frame if already processing
    state = state.copyWith(isProcessingFrame: true);

    try {
      // 1. Flatten the planes based on platform to send across isolate
      // We send raw bytes so the isolate can parse it using the same dimensions.
      // For NV21 we just append U/V to Y if needed, but for grayscale CV only Y is needed.
      // So let's extract Y plane (Android) or full BGRA bytes (iOS).
      
      Uint8List bytes;
      if (Platform.isAndroid) {
         // Y plane is enough for blur and luminance and card detection (grayscale)
         bytes = image.planes[0].bytes;
      } else {
         bytes = image.planes[0].bytes;
      }

      final message = FrameMessage(
        bytes: bytes,
        width: image.width,
        height: image.height,
        platform: Platform.isAndroid ? 'android' : 'ios',
        blurThreshold: 100.0, // Should be fetched from preferences
        minLuminance: 40.0,   // Should be fetched from preferences
        cardMinArea: 0.15,    // Should be fetched from preferences
      );

      final result = await _cvIsolate.processFrame(message);
      
      _updateFocusState(result);

      state = state.copyWith(
        latestQuality: result,
        isProcessingFrame: false,
      );
    } catch (e) {
      // Handle error
      state = state.copyWith(isProcessingFrame: false);
    }
  }
  
  void _updateFocusState(QualityGateResult result) {
    // Focus State Machine:
    // HUNTING -> LOCKING (if quality gates pass)
    // LOCKING -> LOCKED (after a delay of stable quality)
    // LOCKED -> LOST (if quality gates fail)
    
    bool allGatesPassed = result.isBlurred == false && 
                          result.isBrightEnough == true && 
                          result.isCardDetected == true;
                          
    if (!allGatesPassed) {
      if (state.focusState != FocusState.lost && state.focusState != FocusState.hunting) {
         // Focus lost
         state = state.copyWith(focusState: FocusState.lost);
         // Also reset camera focus if possible
         state.controller?.setFocusMode(FocusMode.auto);
      } else {
         state = state.copyWith(focusState: FocusState.hunting);
      }
      return;
    }

    if (state.focusState == FocusState.hunting || state.focusState == FocusState.lost) {
      state = state.copyWith(focusState: FocusState.locking);
      // Wait for focus to stabilize. (Simplified state machine for now)
      Future.delayed(const Duration(milliseconds: 500), () async {
        // Lock focus
        try {
          await state.controller?.setFocusMode(FocusMode.locked);
          state = state.copyWith(focusState: FocusState.locked);
        } catch (_) {}
      });
  }
  }
  
  void resetFocusState() {
    state = state.copyWith(focusState: FocusState.hunting);
  }

  Future<String?> takePicture() async {
    if (state.controller == null || !state.controller!.value.isInitialized) return null;
    if (state.controller!.value.isTakingPicture) return null;

    try {
      // Preload shutter sound
      try {
        await _audioPlayer.setAsset('assets/sounds/shutter.mp3');
        await _audioPlayer.play();
      } catch (e) {
        debugPrint('Failed to load shutter sound: $e');
      }

      final xFile = await state.controller!.takePicture();
      return xFile.path;
    } catch (e) {
      return null;
    }
  }

  void disposeCamera() {
    _audioPlayer.dispose();
    state.controller?.dispose();
  }
}

final cameraProvider = NotifierProvider<CameraNotifier, CameraState>(() {
  return CameraNotifier();
});
