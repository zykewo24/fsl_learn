import 'gesture.dart';

class RecognitionResult {
  final Gesture? gesture;
  final double confidence;
  final bool matched;

  const RecognitionResult({
    required this.gesture,
    required this.confidence,
    required this.matched,
  });

  const RecognitionResult.noMatch()
      : gesture = null,
        confidence = 0,
        matched = false;
}