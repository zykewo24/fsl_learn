import '../models/detection_result.dart';
import '../models/finger_state.dart';

class FingerStateDetector {
  FingerStateDetector._();

  static FingerState detect(DetectionResult detection) {
    final landmarks = detection.landmarks;

    if (landmarks.length != 21) {
      return const FingerState(
        thumbOpen: false,
        indexOpen: false,
        middleOpen: false,
        ringOpen: false,
        pinkyOpen: false,
      );
    }

    // For the four fingers, a simple heuristic:
    // If the fingertip is higher (smaller y) than the PIP joint,
    // we consider that finger open.
    final indexOpen = landmarks[8].y < landmarks[6].y;
    final middleOpen = landmarks[12].y < landmarks[10].y;
    final ringOpen = landmarks[16].y < landmarks[14].y;
    final pinkyOpen = landmarks[20].y < landmarks[18].y;

    // Thumb is more complex because it depends on handedness.
    // We'll improve this in the next step.
    final thumbOpen = false;

    return FingerState(
      thumbOpen: thumbOpen,
      indexOpen: indexOpen,
      middleOpen: middleOpen,
      ringOpen: ringOpen,
      pinkyOpen: pinkyOpen,
    );
  }
}