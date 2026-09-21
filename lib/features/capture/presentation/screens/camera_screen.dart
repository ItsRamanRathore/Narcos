import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/camera_provider.dart';
import '../widgets/capture_checklist.dart';
import '../widgets/capture_guides_painter.dart';
import '../../../calibration/application/calibration_service.dart';
import 'package:go_router/go_router.dart';

class CameraScreen extends ConsumerWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraProvider);
    final notifier = ref.read(cameraProvider.notifier);

    if (!cameraState.isInitialized || cameraState.controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!cameraState.hasPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Camera permission required', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final controller = cameraState.controller!;

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    Widget preview = Transform.scale(
      scale: scale,
      child: Center(
        child: GestureDetector(
          onTapDown: (details) {
            final offset = Offset(
              details.localPosition.dx / size.width,
              details.localPosition.dy / size.height,
            );
            controller.setFocusPoint(offset);
            controller.setFocusMode(FocusMode.auto);
            notifier.resetFocusState();
          },
          child: CameraPreview(controller),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Viewfinder
          preview,

          // Overlays
          Positioned.fill(
            child: CustomPaint(
              painter: CaptureGuidesPainter(focusState: cameraState.focusState),
            ),
          ),

          // Quality Gates Checklist
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            child: CaptureChecklist(state: cameraState),
          ),

          // Flash Control
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: IconButton(
              icon: Icon(
                controller.value.flashMode == FlashMode.torch || 
                controller.value.flashMode == FlashMode.always 
                    ? Icons.flash_on 
                    : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () {
                if (controller.value.flashMode == FlashMode.off) {
                  controller.setFlashMode(FlashMode.torch);
                } else {
                  controller.setFlashMode(FlashMode.off);
                }
              },
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: (cameraState.focusState == FocusState.locked || kDebugMode)
                    ? () async {
                        final rawPath = await notifier.takePicture();
                        if (rawPath != null && context.mounted) {
                          // Show loading indicator in a dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(child: CircularProgressIndicator()),
                          );

                          // Calibrate
                          final calibratedPath = rawPath.replaceAll('.jpg', '_calibrated.png');
                          final calibService = CalibrationService();
                          final result = await calibService.calibrate(rawPath, calibratedPath);
                          
                          if (context.mounted) {
                            Navigator.of(context).pop(); // dismiss loading dialog
                            if (result.success) {
                              context.go('/analysis', extra: result);
                            } else {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Calibration Failed'),
                                  content: Text(result.failureReason ?? 'Unknown error'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('OK'),
                                    )
                                  ],
                                ),
                              );
                            }
                          }
                        }
                      }
                    : null,
                backgroundColor: (cameraState.focusState == FocusState.locked || kDebugMode)
                    ? Colors.green
                    : Colors.grey,
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
