import '../../features/ai_practice/models/finger_state.dart';

class FeatureVector {
  final FingerState fingerState;

  /// Distance from wrist to each fingertip.
  final List<double> fingertipDistances;

  const FeatureVector({
    required this.fingerState,
    required this.fingertipDistances,
  });
}