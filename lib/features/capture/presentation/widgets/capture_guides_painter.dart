import 'package:flutter/material.dart';
import '../../../../core/constants/capture_zones.dart';
import '../../providers/camera_provider.dart';

class CaptureGuidesPainter extends CustomPainter {
  final FocusState focusState;
  
  CaptureGuidesPainter({required this.focusState});

  @override
  void paint(Canvas canvas, Size size) {
    final isLocked = focusState == FocusState.locked;
    final isLocking = focusState == FocusState.locking;

    final paint = Paint()
      ..color = isLocked 
          ? Colors.green 
          : (isLocking ? Colors.yellow : Colors.white)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Convert fractional rects to actual size rects
    final refRect = _fractionToRect(CaptureZones.referenceCardZone, size);
    final kitRect = _fractionToRect(CaptureZones.testKitZone, size);

    // Draw reference card zone
    _drawCornerBrackets(canvas, refRect, paint);
    
    // Draw test kit zone
    _drawCornerBrackets(canvas, kitRect, paint);

    // Optional: add text labels for the zones
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    _drawText(canvas, textPainter, 'Reference Card', refRect, paint.color);
    _drawText(canvas, textPainter, 'Test Kit', kitRect, paint.color);
  }

  Rect _fractionToRect(Rect fraction, Size size) {
    return Rect.fromLTWH(
      fraction.left * size.width,
      fraction.top * size.height,
      fraction.width * size.width,
      fraction.height * size.height,
    );
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Paint paint) {
    final double length = 20.0;
    
    // Top Left
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(length, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, length), paint);

    // Top Right
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-length, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, length), paint);

    // Bottom Left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(length, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -length), paint);

    // Bottom Right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-length, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -length), paint);
  }

  void _drawText(Canvas canvas, TextPainter painter, String text, Rect rect, Color color) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withOpacity(0.7),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 3.0,
            color: Colors.black.withOpacity(0.8),
          ),
        ],
      ),
    );
    painter.layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top - 20,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CaptureGuidesPainter oldDelegate) {
    return oldDelegate.focusState != focusState;
  }
}
