import 'package:fsl_learn/features/ai_practice/models/detection_result.dart';
import 'package:fsl_learn/features/ai_practice/models/landmark.dart';

DetectionResult detectionFrom(List<Landmark> landmarks) {
  return DetectionResult(
    handCount: 1,
    handedness: 'Left',
    confidence: 0.99,
    inferenceTimeMs: 1,
    landmarks: landmarks,
  );
}