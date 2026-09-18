import 'package:fsl_learn/features/ai_practice/models/landmark.dart';

import 'synthetic_hand.dart';

/// Static poses for FSL numbers 0-9.
class NumberPoses {
  static SyntheticHand _fist(SyntheticHand h) {
    h.finger('index', tip: const V(0.47, 0.52, 0.06), pip: const V(0.45, 0.50, 0.04));
    h.finger('middle', tip: const V(0.49, 0.51, 0.06), pip: const V(0.50, 0.50, 0.04));
    h.finger('ring', tip: const V(0.52, 0.52, 0.06), pip: const V(0.54, 0.51, 0.04));
    h.finger('pinky', tip: const V(0.55, 0.53, 0.05), pip: const V(0.585, 0.53, 0.035));
    return h;
  }

  /// Tight ring: thumb outlines a circle with the fingertips, all fingers
/// curled toward the thumb (a slightly tighter "O").
  static List<Landmark> zero() {
    final h = SyntheticHand();
    h.finger('index', tip: const V(0.45, 0.46, 0.065));
    h.finger('middle', tip: const V(0.50, 0.455, 0.065));
    h.finger('ring', tip: const V(0.535, 0.46, 0.065));
    h.finger('pinky', tip: const V(0.57, 0.48, 0.06));
    h.setThumbTip(0.485, 0.46, 0.07);
    return h.build();
  }

  static List<Landmark> one() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.46, 0.30, 0.06));
    h.setThumbTip(0.44, 0.54, 0.06);
    return h.build();
  }

  /// Index + middle extended and held together, thumb folded.
  static List<Landmark> two() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.46, 0.30, 0.06));
    h.finger('middle', tip: const V(0.49, 0.29, 0.06));
    h.setThumbTip(0.45, 0.54, 0.06);
    return h.build();
  }

  /// Thumb + index + middle extended and spread, ring + pinky folded.
  static List<Landmark> three() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.40, 0.30, 0.06));
    h.finger('middle', tip: const V(0.47, 0.29, 0.06));
    h.setThumbTip(0.30, 0.42, 0.06);
    return h.build();
  }

  /// Four fingers extended and WIDE apart, thumb folded across palm.
  static List<Landmark> four() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.40, 0.30, 0.06));
    h.finger('middle', tip: const V(0.48, 0.29, 0.06));
    h.finger('ring', tip: const V(0.56, 0.29, 0.06));
    h.finger('pinky', tip: const V(0.63, 0.34, 0.05));
    h.setThumbTip(0.545, 0.57, 0.05);
    return h.build();
  }

  static List<Landmark> five() {
    final h = SyntheticHand();
    h.finger('index', tip: const V(0.40, 0.30, 0.06));
    h.finger('middle', tip: const V(0.47, 0.28, 0.06));
    h.finger('ring', tip: const V(0.54, 0.29, 0.06));
    h.finger('pinky', tip: const V(0.62, 0.34, 0.05));
    h.setThumbTip(0.28, 0.40, 0.06);
    return h.build();
  }

  static List<Landmark> six() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.42, 0.30, 0.06));
    h.finger('middle', tip: const V(0.49, 0.29, 0.06));
    h.finger('ring', tip: const V(0.56, 0.295, 0.06));
    h.setThumbTip(0.57, 0.53, 0.05);
    return h.build();
  }

  static List<Landmark> seven() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.42, 0.30, 0.06));
    h.finger('middle', tip: const V(0.49, 0.29, 0.06));
    h.finger('pinky', tip: const V(0.62, 0.35, 0.05));
    h.setThumbTip(0.53, 0.48, 0.06);
    return h.build();
  }

  static List<Landmark> eight() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.42, 0.30, 0.06));
    h.finger('ring', tip: const V(0.56, 0.295, 0.06));
    h.finger('pinky', tip: const V(0.62, 0.35, 0.05));
    h.setThumbTip(0.495, 0.47, 0.06);
    return h.build();
  }

  static List<Landmark> nine() {
    final h = _fist(SyntheticHand());
    h.finger('middle', tip: const V(0.49, 0.29, 0.06));
    h.finger('ring', tip: const V(0.56, 0.295, 0.06));
    h.finger('pinky', tip: const V(0.62, 0.35, 0.05));
    h.setThumbTip(0.48, 0.53, 0.07);
    return h.build();
  }
}