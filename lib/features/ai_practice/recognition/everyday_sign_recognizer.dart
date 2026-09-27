import '../models/detection_result.dart';
import 'gesture_recognizer.dart';
import 'tuning.dart';

/// Where the hand is in the frame, as a normalized y-band.
///
/// The app has no face or pose model - MediaPipe Hand Landmarker returns only
/// 21 points on the hand - so "near the chin" can only be approximated from
/// where the wrist sits in frame. These bands assume the learner is holding
/// the phone at arm's length with a front-facing camera, which is how the
/// practice screen is actually used.
///
/// They are deliberately named, wide, and tunable. They are the first thing to
/// adjust on a real device: see the tuning note on [EverydayPattern].
class HandRegion {
  final String name;
  final double minY;
  final double maxY;

  const HandRegion(this.name, this.minY, this.maxY);

  /// Roughly the chin / cheek / mouth, upper half of a typical selfie frame.
  static const HandRegion face = HandRegion('face', 0.08, 0.54);

  /// Roughly the mouth, a tighter band inside [face].
  static const HandRegion mouth = HandRegion('mouth', 0.28, 0.52);

  /// Roughly the upper chest / shoulders, lower half of the frame.
  ///
  /// Starts above [face]'s top-of-range overlap on purpose: a hand at the
  /// boundary should be judged by whichever band it spent longer in.
  static const HandRegion chest = HandRegion('chest', 0.56, 0.94);

  bool contains(double y) => y >= minY && y <= maxY;

  @override
  String toString() => '$name(${minY.toStringAsFixed(2)}..${maxY.toStringAsFixed(2)})';
}

/// What kind of movement a sign requires.
enum EverydayMotion {
  /// No movement required - the handshape and position are enough.
  none,

  /// Repeated movement up and down along one axis, like a nod.
  verticalWave,

  /// Repeated movement side to side, like a head shake.
  horizontalWave,

  /// Movement on both axes at once - the rub-in-a-circle signs.
  circular,

  /// A single sustained sweep in one direction, with little oscillation.
  sweep,
}

/// A declarative description of one everyday sign.
///
/// The static recogniser only ever returned a single opaque confidence number,
/// and when a hard gate failed it returned nothing diagnostic at all. Describing
/// each sign as data rather than burying the rules in arithmetic is what makes
/// it possible to tell a learner *which* part of the sign was wrong, and to
/// tune the thresholds on a real device without a rebuild.
class EverydayPattern {
  /// The sign's `ai_label`, e.g. `GOOD_MORNING`.
  final String label;

  /// Static handshapes that satisfy this sign's handshape requirement. Compare
  /// against [GestureRecognizer.familyOf] so a sign that shares a handshape
  /// with a letter (WATER uses the W hand, like 3) still matches.
  final Set<String> acceptableHandshapes;

  final EverydayMotion motion;

  /// Where in frame the hand has to be, or null if the sign is position-free.
  final HandRegion? region;

  const EverydayPattern(
    this.label,
    this.acceptableHandshapes,
    this.motion, {
    this.region,
  });

  bool matchesHandshape(String? staticLabel) {
    if (staticLabel == null) return false;
    for (final shape in acceptableHandshapes) {
      if (GestureRecognizer.familyOf(shape).contains(staticLabel)) {
        return true;
      }
      // familyOf is not reflexive for every label depending on how the shared
      // table is keyed, so check both directions.
      if (GestureRecognizer.familyOf(staticLabel).contains(shape)) {
        return true;
      }
    }
    return false;
  }
}

/// Recognises the 12 "Everyday Basics" signs, none of which are aliases of a
/// letter handshape and all of which were therefore impossible to complete
/// through the camera.
///
/// These signs combine a handshape with, usually, either a movement or a
/// position. This class tracks the wrist's normalized position over a short
/// sliding window - the same approach the greeting and emergency recognisers
/// already use - and matches it against a declarative [EverydayPattern] table.
///
/// TUNING: every threshold here is a guess at real-world geometry that has not
/// been validated against a camera, because a hand-held phone's framing varies
/// enormously between learners. [EverydayPattern.acceptableHandshapes] and the
/// [HandRegion] bands are the two knobs that will need adjusting on-device.
/// They are deliberately data, not inline arithmetic, so that is a one-line
/// change rather than a rewrite.
///
/// This recogniser deliberately does not compete with the static recogniser.
/// The practice screen consults it only when the active lesson actually
/// contains an everyday sign, mirroring how the greeting and emergency
/// recognisers are used.
class EverydaySignRecognizer {
  /// Wrist landmark index in the 21-point MediaPipe hand model.
  static const int _wristIndex = 0;

  // Moved to RecognitionTuning so the camera test screen can show the live
  // values while a hand is in frame. See the tuning note on [RecognitionTuning].
  static const Duration _windowDuration = RecognitionTuning.motionWindow;

  /// Frames below which no pattern can be judged. At ~20fps this is ~250ms of
  /// visible movement.
  static const int _minSamples = RecognitionTuning.motionMinSamples;

  /// Minimum direction reversals on the dominant axis to read as a wave.
  ///
  /// Lower than the greeting recogniser's 3 because these are small repeated
  /// movements (a nod, a shake) rather than large waves.
  static const int _minWaveReversals = RecognitionTuning.minWaveReversals;

  /// Minimum net travel, in normalized frame units, to read as intentional.
  static const double _minNetDisplacement = RecognitionTuning.minNetDisplacement;

  /// Maximum reversals tolerated for a [EverydayMotion.sweep]. More than this
  /// means it was a wave, not a single sweep.
  static const int _maxSweepReversals = RecognitionTuning.maxSweepReversals;

  /// A wave on one axis must be quiet on the other. Without this a circular
  /// motion satisfies the horizontal-wave rule as well, and whichever axis
  /// pattern happened to come first in the table would swallow the circular
  /// signs - a circle read as NO instead of PLEASE.
  static const int _maxWaveCrossAxisReversals =
      RecognitionTuning.maxWaveCrossAxisReversals;

  /// How much of the movement must be on one axis for a wave to count as
  /// vertical or horizontal rather than circular. 0..1.
  static const double _axisDominance = RecognitionTuning.axisDominance;

  static const double _confMax = RecognitionTuning.motionConfidenceMax;

  /// Every label this recogniser can emit.
  static const Set<String> everydayLabels = {
    'YES',
    'NO',
    'PLEASE',
    'SORRY',
    'EXCUSE_ME',
    'GOOD_MORNING',
    'GOOD_NIGHT',
    'LOVE',
    'WELCOME',
    'WATER',
    'EAT',
    'DRINK',
  };

  /// LOVE is recognised only when two hands are tracked ("cross both fists
  /// over your chest"). The native pipeline is configured for a single hand, so
  /// this is declared but cannot currently be produced - see the class note on
  /// [EverydaySignRecognizer].
  static const Set<String> twoHandLabels = {'LOVE'};

  /// The declarative table. Handshapes use FSL letter/digit labels because that
  /// is the vocabulary the static recogniser already speaks.
  static const List<EverydayPattern> patterns = [
    EverydayPattern('YES', {'A', 'S', '0'}, EverydayMotion.verticalWave),
    EverydayPattern('NO', {'5', 'B', '4'}, EverydayMotion.horizontalWave),
    EverydayPattern('EXCUSE_ME', {'5', 'B', '4'}, EverydayMotion.horizontalWave),
    EverydayPattern('PLEASE', {'5', 'B', '4'}, EverydayMotion.circular,
        region: HandRegion.chest),
    EverydayPattern('SORRY', {'A', 'S', '0'}, EverydayMotion.circular,
        region: HandRegion.chest),
    EverydayPattern(
        'GOOD_MORNING', {'5', 'B', '4'}, EverydayMotion.sweep),
    EverydayPattern('WELCOME', {'5', 'B', '4'}, EverydayMotion.sweep),
    EverydayPattern('GOOD_NIGHT', {'A', 'S', '0'}, EverydayMotion.none,
        region: HandRegion.face),
    EverydayPattern('WATER', {'W', '3'}, EverydayMotion.verticalWave,
        region: HandRegion.face),
    EverydayPattern('EAT', {'O', 'C', 'F'}, EverydayMotion.verticalWave,
        region: HandRegion.mouth),
    EverydayPattern('DRINK', {'C', 'O'}, EverydayMotion.none,
        region: HandRegion.face),
  ];

  /// Canonical form of a sign label: upper case, spaces collapsed to
  /// underscores.
  ///
  /// The curriculum is not internally consistent - it stores some everyday
  /// signs as `'Excuse Me'` and others as `'EXCUSE_ME'` - and `_canonicalLabel`
  /// in the practice screen only upper-cases. Without folding whitespace here,
  /// whichever form happened to be stored would silently stop matching.
  static String normalise(String label) =>
      label.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');

  static bool isEverydayLabel(String label) =>
      everydayLabels.contains(normalise(label));

  /// True when the label needs more than one hand tracked, which the native
  /// pipeline does not currently provide.
  static bool requiresTwoHands(String label) =>
      twoHandLabels.contains(normalise(label));

  static EverydayPattern? patternFor(String label) {
    final canonical = normalise(label);
    for (final p in patterns) {
      if (p.label == canonical) return p;
    }
    return null;
  }

  List<_WristSample> _samples = [];

  /// Mean y of the current window, recomputed each frame. Only valid when
  /// [_samples] has at least [_minSamples] entries.
  double _meanY = 0;

  DateTime Function() _clock = DateTime.now;

  /// The label positively identified on the most recent feed, if any.
  String? lastMatch;

  /// Why the most recent candidate was rejected, for the debug readout.
  String? lastRejection;

  void setClock(DateTime Function() clock) => _clock = clock;

  /// Feeds one detection frame.
  ///
  /// [staticLabel] is the label the static recogniser produced for this frame,
  /// used to satisfy handshape requirements. [staticConfidence] gates how much
  /// the handshape is trusted.
  String? feed(
    DetectionResult detection, {
    String? staticLabel,
    double staticConfidence = 1.0,
  }) {
    if (detection.landmarks.length < 21) {
      reset();
      return null;
    }
    final wrist = detection.landmarks[_wristIndex];
    if (!wrist.x.isFinite || !wrist.y.isFinite) return null;
    return feedRaw(wrist.x, wrist.y,
        staticLabel: staticLabel, staticConfidence: staticConfidence);
  }

  /// Same as [feed] but takes a raw normalized wrist position, so tests can
  /// drive it without constructing a [DetectionResult].
  String? feedRaw(
    double x,
    double y, {
    String? staticLabel,
    double staticConfidence = 1.0,
  }) {
    lastMatch = null;
    lastRejection = null;

    final now = _clock();

    // Every frame is recorded, including a held one. Deduplicating stationary
    // frames looks tempting, but it is what would stop the two motionless
    // signs (GOOD_NIGHT, DRINK) from ever matching: a pose held for the full
    // window would contribute a single sample. A held pose is already rejected
    // downstream, because zero displacement yields zero reversals and zero
    // travel.
    _samples.add(_WristSample(x: x, y: y, t: now));

    _samples =
        _samples.where((s) => now.difference(s.t) <= _windowDuration).toList();

    if (_samples.length < _minSamples) return null;

    _meanY = _samples.map((s) => s.y).reduce((a, b) => a + b) / _samples.length;

    if (staticConfidence < GestureRecognizer.minConfidence) {
      lastRejection = 'handshape too weak';
      return null;
    }

    // A handshape can only be judged on the current frame, so the most recent
    // static label stands in for the whole window. It gates every pattern, not
    // just the moving ones: GOOD_NIGHT is a fist at the cheek, so without this
    // an open hand held to the face would satisfy it.
    for (final pattern in patterns) {
      if (!pattern.matchesHandshape(staticLabel)) continue;

      // Region is judged on where the hand *spent* the window, not on where it
      // happened to be on the final frame. A sign waved through the face band
      // ends at a random point in that band, so a last-frame test would
      // reject signs whose handshape and movement were both correct.
      final region = pattern.region;
      if (region != null && !region.contains(_meanY)) {
        lastRejection = '${pattern.label}: hand not in the ${region.name} area';
        continue;
      }

      final match = _motionScore(pattern);
      if (match != null) {
        lastMatch = pattern.label;
        return pattern.label;
      }
    }
    return null;
  }

  /// Returns a confidence if the window's movement satisfies [pattern]'s
  /// motion requirement, or null if it does not.
  double? _motionScore(EverydayPattern pattern) {
    final first = _samples.first;
    final last = _samples.last;

    final netX = last.x - first.x;
    final netY = last.y - first.y;
    final absNetX = netX.abs();
    final absNetY = netY.abs();

    final xReversals = _reversals((a, b) => b.x - a.x);
    final yReversals = _reversals((a, b) => b.y - a.y);

    switch (pattern.motion) {
      case EverydayMotion.none:
        return _confMax;

      case EverydayMotion.verticalWave:
        if (yReversals < _minWaveReversals) return null;
        // A nod does not swing sideways. Requiring the cross axis to stay
        // quiet is what separates a nod from a circle.
        if (xReversals > _maxWaveCrossAxisReversals) return null;
        // Vertical only if the movement is dominated by y.
        if (absNetY < absNetX * _axisDominance) return null;
        return (absNetY / _confMax).clamp(0.5, 1.0);

      case EverydayMotion.horizontalWave:
        if (xReversals < _minWaveReversals) return null;
        if (yReversals > _maxWaveCrossAxisReversals) return null;
        if (absNetX < absNetY * _axisDominance) return null;
        return (absNetX / _confMax).clamp(0.5, 1.0);

      case EverydayMotion.circular:
        // Both axes must oscillate; neither may dominate.
        if (xReversals < _minWaveReversals) return null;
        if (yReversals < _minWaveReversals) return null;
        final total = absNetX + absNetY;
        if (total < _minNetDisplacement) return null;
        return (total / _confMax).clamp(0.5, 1.0);

      case EverydayMotion.sweep:
        // One deliberate travel, not an oscillation.
        if (xReversals > _maxSweepReversals) return null;
        if (yReversals > _maxSweepReversals) return null;
        final travel =
            absNetX > absNetY ? absNetX : absNetY;
        if (travel < _minNetDisplacement) return null;
        return (travel / _confMax).clamp(0.5, 1.0);
    }
  }

  /// Counts direction reversals of a per-sample delta.
  int _reversals(double Function(_WristSample, _WristSample) delta) {
    var reversals = 0;
    var prev = 0.0;
    for (var i = 1; i < _samples.length; i++) {
      final d = delta(_samples[i - 1], _samples[i]);
      if (prev != 0 && (d > 0) != (prev > 0)) reversals++;
      if (d != 0) prev = d;
    }
    return reversals;
  }

  void reset() {
    _samples = [];
    _meanY = 0;
    lastMatch = null;
    lastRejection = null;
  }
}

class _WristSample {
  final double x;
  final double y;
  final DateTime t;

  _WristSample({required this.x, required this.y, required this.t});
}
