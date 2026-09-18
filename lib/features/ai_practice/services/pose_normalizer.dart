import '../models/detection_result.dart';
import '../models/normalized_landmark.dart';
import '../models/normalized_pose.dart';

class PoseNormalizer {
  PoseNormalizer._();

  /// Translates the hand so that the wrist (landmark 0)
  /// becomes the origin (0,0,0).
  static NormalizedPose normalize(
    DetectionResult detection,
  ) {
    if (detection.landmarks.length != 21) {
      return const NormalizedPose(
        landmarks: [],
      );
    }

    final wrist = detection.landmarks.first;

    final normalized = detection.landmarks.map((landmark) {
      return NormalizedLandmark(
        x: landmark.x - wrist.x,
        y: landmark.y - wrist.y,
        z: landmark.z - wrist.z,
      );
    }).toList();

    return NormalizedPose(
      landmarks: normalized,
    );
  }
}