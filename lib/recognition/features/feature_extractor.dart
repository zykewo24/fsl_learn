import 'dart:math';

import '../../features/ai_practice/models/detection_result.dart';
import '../../features/ai_practice/services/finger_state_detector.dart';

import 'feature_vector.dart';

class FeatureExtractor {
  FeatureExtractor._();

  static FeatureVector extract(
    DetectionResult detection,
  ) {
    final fingerState =
        FingerStateDetector.detect(detection);

    final wrist = detection.landmarks[0];

    final fingertipIndices = [4, 8, 12, 16, 20];

    final distances = fingertipIndices.map((index) {
      final tip = detection.landmarks[index];

      return sqrt(
        pow(tip.x - wrist.x, 2) +
            pow(tip.y - wrist.y, 2),
      );
    }).toList();

    return FeatureVector(
      fingerState: fingerState,
      fingertipDistances: distances,
    );
  }
}