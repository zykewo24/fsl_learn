import '../models/detection_result.dart';

/// Basic temporal (motion) recognizer for FSL greetings that cannot be
/// distinguished by static handshape alone (all three greetings use an
/// open hand, matching the letters B / 4 / 5).
///
/// It tracks the wrist landmark's normalized position over a short sliding
/// window and classifies the dominant movement:
///
///  * KUMASTA (hello) - a primarily vertical (up/down) wave / nod.
///  * SALAMAT  (thank you) - a single strong outward push-away sweep with
///    little oscillation.
///  * PAALAM   (goodbye) - a primarily horizontal (side-to-side) wave.
///
/// Because all of these follow a deliberate, larger-than-normal motion, the
/// recognizer only reports a match once enough movement has accumulated and
/// the dominant pattern is clear. It never competes with static A-Z/0-9
/// recognition - it is consulted by the practice screen only when the lesson
/// actually contains a greeting sign.
class GreetingMotionRecognizer {
  /// Wrist landmark index in the 21-point MediaPipe hand model.
  static const int _wristIndex = 0;

  /// How long of a movement history we keep when classifying.
  static const Duration _windowDuration = Duration(milliseconds: 900);

  /// Minimum number of direction reversals on an axis to count as a wave.
  static const int _waveMinReversals = 3;

  /// Minimum net (signed) displacement that must be travelled for the
  /// dominant axis before we treat the movement as an intentional gesture.
  static const double _minNetDisplacement = 0.18;

  /// Confidence scale clamp used to turn raw features into [0,1].
  static const double _confMax = 0.6;

  /// Labels emitted by this recognizer.
  static const Set<String> greetingLabels = {
    'KUMASTA',
    'SALAMAT',
    'PAALAM',
  };

  /// Returns true when [label] (uppercased) is a motion-recognized greeting.
  static bool isGreetingLabel(String label) =>
      greetingLabels.contains(label.trim().toUpperCase());

  List<_MotionSample> _samples = [];
  double _lastX = 0;
  double _lastY = 0;
  bool _hasLast = false;

  /// Injectable clock for deterministic tests.
  DateTime Function() _clock = DateTime.now;

  /// A greeting that was positively identified on the most recent feed.
  String? lastGreeting;

  /// Feeds one detection frame (wrist position) into the tracker. Returns the
  /// greeting label just detected, or null if no motion match is (yet) clear.
  String? feed(DetectionResult detection) {
    lastGreeting = null;

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
    lastGreeting = null;

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

    lastGreeting = _classify();
    return lastGreeting;
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
    var prevDx = 0.0;
    var prevDy = 0.0;

    for (var i = 1; i < _samples.length; i++) {
      final dx = (_samples[i].x - _samples[i - 1].x) / 0.10;
      final dy = (_samples[i].y - _samples[i - 1].y) / 0.10;

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

    String? label;
    var strength = 0.0;

    // --- SALAMAT: single strong outward push with little oscillation.
    if ((absNetX >= _minNetDisplacement || absNetY >= _minNetDisplacement) &&
        xReversals <= 1 &&
        yReversals <= 1) {
      final dominant =
          absNetX >= absNetY ? absNetX : absNetY;
      strength = (dominant / _confMax).clamp(0.5, 1.0);
      label = 'SALAMAT';
    }

    // --- PAALAM vs KUMASTA: waves distinguished by dominant axis.
    if (label == null) {
      final xIsWave =
          xReversals >= _waveMinReversals &&
          absNetX >= _minNetDisplacement * 0.6;
      final yIsWave =
          yReversals >= _waveMinReversals &&
          absNetY >= _minNetDisplacement * 0.6;

      if (xIsWave && !yIsWave) {
        label = 'PAALAM';
        strength = (absNetX / _confMax).clamp(0.5, 1.0);
      } else if (yIsWave && !xIsWave) {
        label = 'KUMASTA';
        strength = (absNetY / _confMax).clamp(0.5, 1.0);
      } else if (xIsWave && yIsWave) {
        // Ambiguous two-axis wave; prefer the higher-amplitude axis.
        if (absNetX >= absNetY) {
          label = 'PAALAM';
          strength = (absNetX / _confMax).clamp(0.5, 1.0);
        } else {
          label = 'KUMASTA';
          strength = (absNetY / _confMax).clamp(0.5, 1.0);
        }
      }
    }

    if (label == null) {
      return null;
    }

    // Require a confident, sustained gesture before reporting a match.
    if (strength < 0.5) {
      return null;
    }

    return label;
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
    lastGreeting = null;
  }
}

class _MotionSample {
  final double x;
  final double y;
  final DateTime t;

  _MotionSample({required this.x, required this.y})
      : t = DateTime.now();
}
