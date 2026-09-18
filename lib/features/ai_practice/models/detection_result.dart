import 'landmark.dart';

class DetectionResult {
  final int handCount;
  final String? handedness;
  final double confidence;
  final int inferenceTimeMs;
  final List<Landmark> landmarks;

  const DetectionResult({
    required this.handCount,
    required this.handedness,
    required this.confidence,
    required this.inferenceTimeMs,
    required this.landmarks,
  });

  factory DetectionResult.fromMap(
    Map<dynamic, dynamic> map,
  ) {
    final landmarkList =
        (map['landmarks'] as List<dynamic>)
            .cast<Map<dynamic, dynamic>>();

    return DetectionResult(
      handCount: map['handCount'] as int,
      handedness: map['handedness'] as String?,
      confidence:
          (map['confidence'] as num).toDouble(),
      inferenceTimeMs:
          map['inferenceTimeMs'] as int,
      landmarks: landmarkList
          .map(Landmark.fromMap)
          .toList(),
    );
  }
}