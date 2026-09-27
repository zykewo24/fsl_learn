import 'dart:math' as math;

import '../models/landmark.dart';

class P3 {
  final double x;
  final double y;
  final double z;

  const P3(this.x, this.y, this.z);

  P3 mid(P3 other) =>
      P3((x + other.x) / 2, (y + other.y) / 2, (z + other.z) / 2);
}

double _dist(P3 a, P3 b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  final dz = a.z - b.z;
  return math.sqrt(dx * dx + dy * dy + dz * dz);
}

/// Extracts a compact set of rotation-invariant, palm-size-normalized
/// features from a single MediaPipe hand detection.
///
/// All distances are normalized by the palm width
/// (distance between the index and pinky metacarpals) so the values are
/// comparable across hands of different sizes and camera distances.
class HandGeometry {
  final List<P3> _p;
  final double palmWidth;

  factory HandGeometry.fromLandmarks(
    List<Landmark> landmarks,
  ) {
    final p = landmarks
        .map((l) => P3(l.x, l.y, l.z))
        .toList();
    final pw = p.length > 17 ? _dist(p[5], p[17]) : 0.0;
    return HandGeometry._(p, pw <= 0 ? 0.0001 : pw);
  }

  HandGeometry._(this._p, this.palmWidth);

  double get rawPalmWidth => palmWidth == 0.0001 ? 0.0 : palmWidth;

  double _toWrist(int i) => _dist(_p[i], _p[0]) / palmWidth;

  bool _isExtended(int tip, int joint) {
    final tipDist = _toWrist(tip);
    final jointDist = _toWrist(joint);
    if (jointDist == 0) return false;
    return tipDist > jointDist * 1.08;
  }

  P3 _delta(int tip) {
    return P3(
      (_p[tip].x - _p[0].x) / palmWidth,
      (_p[tip].y - _p[0].y) / palmWidth,
      (_p[tip].z - _p[0].z) / palmWidth,
    );
  }

  P3 _unit(P3 v) {
    final n = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    if (n < 1e-4) return P3(0, 0, 0);
    return P3(v.x / n, v.y / n, v.z / n);
  }

  P3 _cross(P3 a, P3 b) => P3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
      );

  double _dot(P3 a, P3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

  /// Hand-local orthonormal frame so directional features are invariant to
  /// how the hand is rotated in the camera frame:
  /// [handFwd]  = wrist -> middle MCP (points along the fingers),
  /// [handSide] = across the palm toward the thumb,
  /// [handOut]  = out of the palm (toward the viewer in the canonical pose).
  late final P3 handFwd = _unit(P3(
    _p[9].x - _p[0].x,
    _p[9].y - _p[0].y,
    _p[9].z - _p[0].z,
  ));
  late final P3 handOut = _unit(_cross(P3(
    _p[5].x - _p[17].x,
    _p[5].y - _p[17].y,
    _p[5].z - _p[17].z,
  ), handFwd));
  late final P3 handSide = _unit(_cross(handFwd, handOut));

  /// Index of the hand-local axis with the largest absolute projection of
  /// [d]: 0 = fingers direction, 1 = across the palm, 2 = out of the palm.
  int _dominantAxis(P3 d) {
    final af = _dot(d, handFwd).abs();
    final as = _dot(d, handSide).abs();
    final ao = _dot(d, handOut).abs();
    if (af >= as && af >= ao) return 0;
    if (as >= af && as >= ao) return 1;
    return 2;
  }

  /// True when [d]'s dominant hand-local axis is [axis] with a projection
  /// of at least 0.30 palm-widths (matching the legacy camera-frame
  /// threshold). [sense] selects the direction along the axis:
  /// positive = along it, negative = against it, either = either way.
  bool _matchesDirection(P3 d, int axis,
      {bool positive = false, bool negative = false}) {
    if (_dominantAxis(d) != axis) return false;
    final c = _dot(d, axis == 0 ? handFwd : (axis == 1 ? handSide : handOut));
    if (negative) return c <= -0.30;
    return positive ? c >= 0.30 : c.abs() >= 0.30;
  }

  /// Directional predicates are computed in the hand-local frame, so a sign
  /// keeps matching no matter how the user rotates/holds the hand sideways.
  bool get indexUp => _matchesDirection(indexDelta, 0, positive: true);
  bool get indexDown => _matchesDirection(indexDelta, 0, negative: true);
  bool get indexForward => _matchesDirection(indexDelta, 2);
  bool get indexSideways => _matchesDirection(indexDelta, 1);

  bool get middleUp => _matchesDirection(middleDelta, 0, positive: true);
  bool get middleDown => _matchesDirection(middleDelta, 0, negative: true);

  bool get thumbUp => _matchesDirection(thumbDelta, 0, positive: true);
  bool get thumbDown => _matchesDirection(thumbDelta, 0, negative: true);
  bool get thumbForward => _matchesDirection(thumbDelta, 2);
  bool get thumbSideways => _matchesDirection(thumbDelta, 1);

  bool get indexMiddleCrossed {
    // Compare the lateral (palm-plane) order of the fingertips against the
    // MCP bases projected onto the hand's own side axis. Using the hand
    // frame keeps the crossing test correct for both hands and any rotation.
    final tipDiff = _dot(
      P3(_p[8].x - _p[12].x, _p[8].y - _p[12].y, _p[8].z - _p[12].z),
      handSide,
    );
    final baseDiff = _dot(
      P3(_p[5].x - _p[9].x, _p[5].y - _p[9].y, _p[5].z - _p[9].z),
      handSide,
    );
    if (tipDiff.abs() < 1e-4 || baseDiff.abs() < 1e-4) {
      return false;
    }
    return (tipDiff < 0) != (baseDiff < 0);
  }

  late final bool thumbExtended = _isExtended(4, 3);
  late final bool indexExtended = _isExtended(8, 6);
  late final bool middleExtended = _isExtended(12, 10);
  late final bool ringExtended = _isExtended(16, 14);
  late final bool pinkyExtended = _isExtended(20, 18);

  bool get allFourExtended =>
      indexExtended &&
      middleExtended &&
      ringExtended &&
      pinkyExtended;

  /// How far a finger is extended, as a continuous ratio of its tip-to-wrist
  /// distance to its knuckle-to-wrist distance.
  ///
  /// The existing [indexExtended] family is boolean, which is enough to decide
  /// *whether* a finger is out but not *how far off* it is. Corrective feedback
  /// needs the magnitude to rank which mistake matters most and to phrase the
  /// hint, so this exposes the underlying ratio.
  ///
  /// Roughly 1.0 when a finger is folded flat into the palm and 2.0 or more
  /// when it is straight. Being a ratio of palm-normalized distances, it is
  /// invariant to hand size, camera distance and hand rotation, like the rest
  /// of this class.
  double extensionRatio(int tipIndex, int knuckleIndex) {
    final knuckleDist = _toWrist(knuckleIndex);
    if (knuckleDist == 0) return 0;
    return _toWrist(tipIndex) / knuckleDist;
  }

  double get indexExtensionRatio => extensionRatio(8, 5);
  double get middleExtensionRatio => extensionRatio(12, 9);
  double get ringExtensionRatio => extensionRatio(16, 13);
  double get pinkyExtensionRatio => extensionRatio(20, 17);
  double get thumbExtensionRatio => extensionRatio(4, 1);

  late final double thumbTipDist = _toWrist(4);
  late final double indexTipDist = _toWrist(8);
  late final double middleTipDist = _toWrist(12);
  late final double ringTipDist = _toWrist(16);
  late final double pinkyTipDist = _toWrist(20);

  late final double indexPipDist = _toWrist(6);
  late final double middlePipDist = _toWrist(10);
  late final double ringPipDist = _toWrist(14);
  late final double pinkyPipDist = _toWrist(18);

  double get averageFingerTipDist =>
      (indexTipDist +
          middleTipDist +
          ringTipDist +
          pinkyTipDist) /
      4;

  double _tipGap(int a, int b) => _dist(_p[a], _p[b]) / palmWidth;

  late final double indexMiddleGap = _tipGap(8, 12);
  late final double middleRingGap = _tipGap(12, 16);
  late final double ringPinkyGap = _tipGap(16, 20);

  double get thumbToIndexTip => _tipGap(4, 8);
  double get thumbToMiddleTip => _tipGap(4, 12);
  double get thumbToRingTip => _tipGap(4, 16);
  double get thumbToPinkyTip => _tipGap(4, 20);
  double get thumbToIndexPip => _tipGap(4, 6);
  double get thumbToMiddlePip => _tipGap(4, 10);
  double get thumbToIndexMcp => _tipGap(4, 5);
  double get thumbToPinkyMcp => _tipGap(4, 17);

  double get thumbToIndexMiddlePipMid =>
      _dist(_p[4], _p[6].mid(_p[10])) / palmWidth;

  double get thumbToMidPalm =>
      _dist(_p[4], _p[9].mid(_p[5])) / palmWidth;

  P3 get palmCenter => _p[5].mid(_p[17]);

  double get thumbToPalmCenter =>
      _dist(_p[4], palmCenter) / palmWidth;

  double get indexTipToPalmCenter =>
      _dist(_p[8], palmCenter) / palmWidth;

  double get middleTipToPalmCenter =>
      _dist(_p[12], palmCenter) / palmWidth;

  double get ringTipToPalmCenter =>
      _dist(_p[16], palmCenter) / palmWidth;

  double get pinkyTipToPalmCenter =>
      _dist(_p[20], palmCenter) / palmWidth;

  double get indexBendRatio =>
      indexPipDist == 0 ? 99 : indexTipDist / indexPipDist;

  P3 get thumbDelta => _delta(4);
  P3 get indexDelta => _delta(8);
  P3 get middleDelta => _delta(12);
}