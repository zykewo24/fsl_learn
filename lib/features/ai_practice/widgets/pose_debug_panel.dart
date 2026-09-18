import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import '../models/normalized_pose.dart';

class PoseDebugPanel extends StatelessWidget {
  final DetectionResult? detection;
  final NormalizedPose? normalizedPose;

  const PoseDebugPanel({
    super.key,
    required this.detection,
    required this.normalizedPose,
  });

  @override
  Widget build(BuildContext context) {
    if (detection == null || normalizedPose == null) {
      return const SizedBox.shrink();
    }

    final wrist = normalizedPose!.landmarks.first;
    final indexTip = normalizedPose!.landmarks[8];

    return Card(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hands: ${detection!.handCount}'),
              Text('Hand: ${detection!.handedness}'),
              const SizedBox(height: 8),

              const Text('Normalized'),

              Text(
                'Wrist: '
                '(${wrist.x.toStringAsFixed(3)}, '
                '${wrist.y.toStringAsFixed(3)}, '
                '${wrist.z.toStringAsFixed(3)})',
              ),

              Text(
                'Index Tip: '
                '(${indexTip.x.toStringAsFixed(3)}, '
                '${indexTip.y.toStringAsFixed(3)}, '
                '${indexTip.z.toStringAsFixed(3)})',
              ),
            ],
          ),
        ),
      ),
    );
  }
}