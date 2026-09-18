import 'package:fsl_learn/features/ai_practice/models/landmark.dart';

import 'synthetic_hand.dart';

/// Static poses used to synthesize 21 landmark hands for each letter.
/// Positions are curated so the palm-size-normalized features match the
/// recognizer thresholds.
class AlphabetPoses {
  static SyntheticHand _fist(SyntheticHand h) {
    h.finger('index', tip: const V(0.47, 0.52, 0.06), pip: const V(0.45, 0.50, 0.04));
    h.finger('middle', tip: const V(0.49, 0.51, 0.06), pip: const V(0.50, 0.50, 0.04));
    h.finger('ring', tip: const V(0.52, 0.52, 0.06), pip: const V(0.54, 0.51, 0.04));
    h.finger('pinky', tip: const V(0.55, 0.53, 0.05), pip: const V(0.585, 0.53, 0.035));
    return h;
  }

  static SyntheticHand _straight(SyntheticHand h) {
    h.finger('index', tip: const V(0.46, 0.30, 0.06));
    h.finger('middle', tip: const V(0.51, 0.29, 0.06));
    h.finger('ring', tip: const V(0.56, 0.295, 0.06));
    h.finger('pinky', tip: const V(0.60, 0.35, 0.05));
    return h;
  }

  static SyntheticHand _curved(SyntheticHand h) {
    h.finger('index', tip: const V(0.46, 0.465, 0.05));
    h.finger('middle', tip: const V(0.51, 0.455, 0.05));
    h.finger('ring', tip: const V(0.56, 0.46, 0.05));
    h.finger('pinky', tip: const V(0.595, 0.48, 0.05));
    return h;
  }

  static SyntheticHand _deepTuck(SyntheticHand h) {
    h.finger('index',
        tip: const V(0.48, 0.53, 0.06), pip: const V(0.46, 0.50, 0.04));
    h.finger('middle',
        tip: const V(0.51, 0.53, 0.05), pip: const V(0.51, 0.50, 0.04));
    h.finger('ring',
        tip: const V(0.54, 0.54, 0.05), pip: const V(0.55, 0.51, 0.04));
    h.finger('pinky',
        tip: const V(0.57, 0.56, 0.05), pip: const V(0.58, 0.53, 0.035));
    return h;
  }

  static SyntheticHand _overThumb(SyntheticHand h, {bool ringTucked = false}) {
    h.finger('index', tip: const V(0.45, 0.47, 0.06));
    h.finger('middle', tip: const V(0.50, 0.46, 0.06));
    h.finger(
      'ring',
      tip: ringTucked ? const V(0.56, 0.53, 0.05) : const V(0.54, 0.47, 0.06),
    );
    h.finger(
      'pinky',
      tip: const V(0.57, 0.53, 0.05),
      pip: const V(0.585, 0.53, 0.035),
    );
    return h;
  }

  static SyntheticHand _tuckThumb(SyntheticHand h, {double x = 0.48, double y = 0.545}) {
    h.setThumbTip(x, y, 0.06);
    return h;
  }

  static List<Landmark> a() {
    final h = _fist(SyntheticHand());
    h.setThumbTip(0.46, 0.44, 0.06);
    return h.build();
  }

  static List<Landmark> b() {
    final h = _straight(SyntheticHand());
    h.finger('index', tip: const V(0.451, 0.30, 0.06));
    h.finger('middle', tip: const V(0.50, 0.29, 0.06));
    h.finger('ring', tip: const V(0.55, 0.295, 0.06));
    h.setThumbTip(0.50, 0.56, 0.05);
    return h.build();
  }

  static List<Landmark> c() {
    final h = _curved(SyntheticHand());
    h.setThumbTip(0.30, 0.47, 0.08);
    return h.build();
  }

  static List<Landmark> d() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.46, 0.30, 0.06));
    h.setThumbTip(0.43, 0.38, 0.05);
    return h.build();
  }

  static List<Landmark> e() {
    final h = _deepTuck(SyntheticHand());
    h.setThumbTip(0.49, 0.55, 0.06);
    return h.build();
  }

  static List<Landmark> f() {
    final h = _straight(SyntheticHand());
    h.setThumbTip(0.46, 0.30, 0.07);
    return h.build();
  }

  static List<Landmark> g() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.50, 0.545, -0.20));
    h.setThumbTip(0.47, 0.55, -0.18);
    return h.build();
  }

  static List<Landmark> h() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.50, 0.545, -0.20));
    h.finger('middle', tip: const V(0.515, 0.54, -0.20));
    _tuckThumb(h);
    return h.build();
  }

  static List<Landmark> i() {
    final h = _fist(SyntheticHand());
    h.finger('pinky', tip: const V(0.60, 0.35, 0.05));
    _tuckThumb(h, y: 0.54);
    return h.build();
  }

  static List<Landmark> k() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.42, 0.30, 0.06));
    h.finger('middle', tip: const V(0.55, 0.29, 0.06));
    h.setThumbTip(0.47, 0.40, 0.06);
    return h.build();
  }

  static List<Landmark> l() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.46, 0.30, 0.06));
    h.setThumbTip(0.26, 0.44, 0.05);
    return h.build();
  }

  static List<Landmark> m() {
    final h = _overThumb(SyntheticHand());
    h.setThumbTip(0.485, 0.54, 0.06);
    return h.build();
  }

  static List<Landmark> n() {
    final h = _overThumb(SyntheticHand(), ringTucked: true);
    h.setThumbTip(0.485, 0.54, 0.06);
    return h.build();
  }

  static List<Landmark> o() {
    final h = SyntheticHand();
    h.finger('index', tip: const V(0.45, 0.46, 0.065));
    h.finger('middle', tip: const V(0.50, 0.455, 0.065));
    h.finger('ring', tip: const V(0.535, 0.46, 0.065));
    h.finger('pinky', tip: const V(0.57, 0.48, 0.06));
    h.setThumbTip(0.485, 0.46, 0.07);
    return h.build();
  }

  static List<Landmark> p() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.47, 0.80, 0.05));
    h.finger('middle', tip: const V(0.52, 0.80, 0.05));
    h.setThumbTip(0.44, 0.66, 0.06);
    return h.build();
  }

  static List<Landmark> q() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.47, 0.80, 0.05));
    h.setThumbTip(0.45, 0.70, 0.06);
    return h.build();
  }

  static List<Landmark> r() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.54, 0.30, 0.06));
    h.finger('middle', tip: const V(0.49, 0.32, 0.06));
    _tuckThumb(h);
    return h.build();
  }

  static List<Landmark> s() {
    final h = _fist(SyntheticHand());
    h.setThumbTip(0.48, 0.54, 0.07);
    return h.build();
  }

  static List<Landmark> t() {
    final h = _fist(SyntheticHand());
    h.setThumbTip(0.485, 0.47, 0.03);
    return h.build();
  }

  static List<Landmark> u() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.465, 0.30, 0.06));
    h.finger('middle', tip: const V(0.475, 0.295, 0.06));
    _tuckThumb(h);
    return h.build();
  }

  static List<Landmark> v() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.42, 0.30, 0.06));
    h.finger('middle', tip: const V(0.55, 0.29, 0.06));
    _tuckThumb(h);
    return h.build();
  }

  static List<Landmark> w() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.42, 0.30, 0.06));
    h.finger('middle', tip: const V(0.49, 0.29, 0.06));
    h.finger('ring', tip: const V(0.56, 0.295, 0.06));
    _tuckThumb(h);
    return h.build();
  }

  static List<Landmark> x() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.475, 0.46, 0.02), pip: const V(0.46, 0.46, 0.04));
    _tuckThumb(h, y: 0.53);
    return h.build();
  }

  static List<Landmark> y() {
    final h = _fist(SyntheticHand());
    h.finger('pinky', tip: const V(0.60, 0.35, 0.05));
    h.setThumbTip(0.30, 0.42, 0.05);
    return h.build();
  }

  static List<Landmark> z() {
    final h = _fist(SyntheticHand());
    h.finger('index', tip: const V(0.50, 0.545, -0.20));
    _tuckThumb(h);
    return h.build();
  }
}