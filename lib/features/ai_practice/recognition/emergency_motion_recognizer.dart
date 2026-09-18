import 'dart:math' show sqrt;

import '../models/detection_result.dart';

/// Temporal (motion) recognizer for FSL emergency signs that cannot be told
/// apart by static handshape alone.
///
/// It tracks the wrist landmark's normalized position over a short sliding
/// window (the same approach as [GreetingMotionRecognizer]) and classifies
/// the dominant movement into one of four emergency labels:
///
///  * HELP    - a single strong vertical thrust (pumping the fist upward to
///              ask for help).
///  * FIRE    - a vigorous shake / tremor of the hand.
///  * DANGER  - a single hard horizontal strike (a sharp sideways snap).
///  * MEDICAL - short repeated taps that stay close to the starting spot.
///
/// The classifier separates the four by a combination of the dominant axis,
/// the number of direction reversals, the net displacement, and the
/// accumulated path length (travel ratio) over the window:
///
///  * FIRE   -> very high reversal count and a high travel ratio (moves a lot
///              while ending near where it started).
///  * MEDICAL-> several reversals but stays localized (low net displacement).
///  * HELP   -> low reversals, vertically dominant, meaningful net upward move.
///  * DANGER -> low reversals, horizontally dominant, meaningful net outward
///              move.
///
/// Like the greeting recognizer, this never competes with static A-Z/0-9
/// recognition. It is consulted by the practice screen only when the active
/// lesson contains an emergency sign.
class EmergencyMotionRecognizer {
  /// Wrist landmark index in the 21-point MediaPipe hand model.
  static const int _wristIndex = 0;

  /// How long of a movement history we keep when classifying.
  static const Duration _windowDuration = Duration(milliseconds: 900);

  /// Minimum net (signed) displacement for HELP / DANGER to count as a real
  /// thrust or strike rather than camera jitter.
  static const double _minNetDisplacement = 0.15;

  /// Localized movement is only clustered as MEDICAL if it stays near the
  /// starting spot (below this net displacement).
  static const double _maxLocalizedNet = 0.10;

  /// Reversal count at or above which the motion is treated as shaking.
  static const int _shakeMinReversals = 4;

  /// Minimum net displacement for FIRE so micro-jitter (MEDICAL taps) does
  /// not get mistaken for a vigorous shake.
  static const double _fireMinNet = 0.10;

  /// Minimum travel ratio (accumulated path / net displacement) for FIRE.
  static const double _fireMinTravelRatio = 3.0;

  /// Labels emitted by this recognizer.
  static const Set<String> emergencyLabels = {
    'HELP',
    'FIRE',
    'DANGER',
    'MEDICAL',
  };

  /// Returns true when [label] (uppercased) is a motion-recognized emergency.
  static bool isEmergencyLabel(String label) =>
      emergencyLabels.contains(label.trim().toUpperCase());

  List<_MotionSample> _samples = [];
  double _lastX = 0;
  double _lastY = 0;
  bool _hasLast = false;

  /// Injectable clock for deterministic tests.
  DateTime Function() _clock = DateTime.now;

  /// An emergency sign that was positively identified on the most recent feed.
  String? lastEmergency;

  /// Feeds one detection frame (wrist position) into the tracker. Returns the
  /// emergency label just detected, or null if no motion match is (yet) clear.
  String? feed(DetectionResult detection) {
    lastEmergency = null;

    if (detection.handCount != 1 || detection.landmarks.length < 21) {
      _samples = [];
      _hasLast = false;
      return null;
    }

    final wrist = detection.landmarks[_wristIndex];
    if (!wrist.x.isFinite || !wrist.y.isFinite) {
      return null;
    }

    return feedRaw(wrist.x, wrist.y);
  }

  /// Same as [feed] but takes a raw normalized (x, y) wrist position. Exposed
  /// so tests can drive the recognizer without constructing DetectionResults.
  String? feedRaw(double x, double y) {
    lastEmergency = null;

    final now = _clock();
    final sample = _MotionSample(x: x, y: y);

    if (_hasLast) {
      // Skip near-identical consecutive frames so a held pose does not
      // accumulate movement.
      final dx = (sample.x - _lastX).abs();
      final dy = (sample.y - _lastY).abs();
      final moved = (dx > 0.004) || (dy > 0.004);
      if (moved) {
        _samples.add(sample);
      }
    } else {
      _samples.add(sample);
    }

    _lastX = sample.x;
    _lastY = sample.y;
    _hasLast = true;

    // Prune samples older than the window.
    _samples = _samples
        .where((s) => now.difference(s.t) <= _windowDuration)
        .toList();

    if (_samples.length < 4) {
      return null;
    }

    lastEmergency = _classify();
    return lastEmergency;
  }

  String? _classify() {
    final first = _samples.first;
    final last = _samples.last;

    final netX = last.x - first.x;
    final netY = last.y - first.y;

    // Direction reversals: count how many times the per-frame dx/dy flips
    // sign across the window.
    var xReversals = 0;
    var yReversals = 0;
    var totalPath = 0.0;
    var prevDx = 0.0;
    var prevDy = 0.0;

    for (var i = 1; i < _samples.length; i++) {
      final dx = _samples[i].x - _samples[i - 1].x;
      final dy = _samples[i].y - _samples[i - 1].y;

      totalPath += (dx.abs() + dy.abs());

      if (prevDx != 0 && (dx > 0) != (prevDx > 0)) {
        xReversals++;
      }
      if (prevDy != 0 && (dy > 0) != (prevDy > 0)) {
        yReversals++;
      }
      if (dx != 0) prevDx = dx;
      if (dy != 0) prevDy = dy;
    }

    final absNetX = netX.abs();
    final absNetY = netY.abs();
    final netMagnitude = sqrt(absNetX * absNetX + absNetY * absNetY);
    final totalReversals = xReversals + yReversals;
    final travelRatio =
        netMagnitude > 1e-9 ? totalPath / netMagnitude : 999.0;

    final xDominant = absNetX >= absNetY;
    final yDominant = !xDominant;

    // --- FIRE: vigorous shake — lots of reversals, lots of accumulated
    //     path relative to the net move, and a real net displacement (so
    //     micro-taps are not mistaken for a shake).
    if (totalReversals >= _shakeMinReversals &&
        netMagnitude >= _fireMinNet &&
        travelRatio >= _fireMinTravelRatio) {
      return 'FIRE';
    }

    // --- MEDICAL: repeated taps in place — several reversals but the hand
    //     stays close to its starting spot (localized).
    if (totalReversals >= 3 && netMagnitude < _maxLocalizedNet) {
      return 'MEDICAL';
    }

    // --- HELP: strong single vertical thrust — little horizontal motion.
    if (yDominant &&
        absNetY >= _minNetDisplacement &&
        yReversals <= 1) {
      return 'HELP';
    }

    // --- DANGER: strong single horizontal strike — little vertical motion.
    if (xDominant &&
        absNetX >= _minNetDisplacement &&
        xReversals <= 2) {
      return 'DANGER';
    }

    return null;
  }

  /// Sets the internal clock to a fixed advancing source so tests can
  /// control sample timing deterministically.
  void setClock(DateTime Function() clock) {
    _clock = clock;
  }

  /// Clears accumulated motion history (e.g. when switching focus mode).
  void reset() {
    _samples = [];
    _hasLast = false;
    lastEmergency = null;
  }
}

class _MotionSample {
  final double x;
  final double y;
  final DateTime t;

  _MotionSample({required this.x, required this.y})
      : t = DateTime.now();
}
