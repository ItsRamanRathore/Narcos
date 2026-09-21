import 'package:flutter/material.dart';
import '../../providers/camera_provider.dart';

class CaptureChecklist extends StatelessWidget {
  final CameraState state;

  const CaptureChecklist({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final quality = state.latestQuality;
    final hasQuality = quality != null;

    final blurPassed = hasQuality && !quality.isBlurred;
    final luminancePassed = hasQuality && quality.isBrightEnough;
    final cardPassed = hasQuality && quality.isCardDetected;
    final isLocked = state.focusState == FocusState.locked;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCheckItem('Steady / Sharp', blurPassed),
          const SizedBox(height: 4),
          _buildCheckItem('Good Lighting', luminancePassed),
          const SizedBox(height: 4),
          _buildCheckItem('Card Aligned', cardPassed),
          const SizedBox(height: 4),
          _buildCheckItem('Focus Locked', isLocked),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool passed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: passed ? Colors.green : Colors.white54,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: passed ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: passed ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
