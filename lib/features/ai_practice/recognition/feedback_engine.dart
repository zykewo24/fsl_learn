import 'dart:math' as math;

import '../models/landmark.dart';
import 'hand_geometry.dart';
import 'reference/reference_signs.dart';
import 'tuning.dart';

/// Which part of the hand a correction is about.
///
/// Values are suffixed `Finger` because Dart enums already have an `index`
/// member, so a bare `index` would conflict.
enum HandPart { indexFinger, middleFinger, ringFinger, pinkyFinger, thumbFinger, wholeHand }

/// The kind of correction, chosen so the UI can pick an icon and the tests can
/// assert on behaviour rather than on prose.
enum CorrectionKind {
  /// The finger should be straighter than it is.
  straightenFinger,

  /// The finger should be folded further in.
  curlFinger,

  /// The thumb is not touching / not across where it should be.
  thumbPlacement,

  /// The fingers are together in the reference but spread in the attempt.
  fingersSpread,

  /// The fingers are spread in the reference but together in the attempt.
  fingersTogether,

  /// The reference pose could not be compared against this frame at all.
  unusableFrame,
}

/// One actionable thing the learner is doing wrong.
class Correction {
  final CorrectionKind kind;
  final HandPart part;

  /// How wrong this is, `0..1`. Corrections are ranked by this so the most
  /// important one is the one shown first.
  final double severity;

  final String message;

  const Correction({
    required this.kind,
    required this.part,
    required this.severity,
    required this.message,
  });
}

/// The live verdict on one attempt at a target sign.
class SignFeedback {
  /// The sign being attempted, e.g. `RED`.
  final String label;

  /// The handshape it was compared against, e.g. `X`. Null when there is no
  /// reference to compare with.
  final String? handshape;

  /// Weighted mean of the per-check scores, `0..1`. 1 means the attempt
  /// matches the reference on every check.
  final double closeness;

  /// Ranked by severity, most important first.
  final List<Correction> corrections;

  const SignFeedback({
    required this.label,
    required this.closeness,
    required this.corrections,
    this.handshape,
  });

  static const SignFeedback unsupported = SignFeedback(
    label: '',
    closeness: 0,
    corrections: [],
  );

  bool get isPerfect => corrections.isEmpty;
}

/// Turns a live hand into specific, prioritised advice.
///
/// The app previously showed a bare correct/incorrect colour on the camera
/// overlay. A learner who is told only "wrong" cannot tell whether they forgot
/// to straighten a finger or crossed two of them, and the overwhelming
/// majority of FSL handshapes differ from each other in exactly those small
/// ways.
///
/// The approach is deliberately not machine-learned. Each reference pose is run
/// through the same [HandGeometry] the recogniser uses, and a small set of named
/// comparisons is made between the attempt and the reference. That keeps the
/// whole thing unit-testable against the same synthetic hands the recogniser
/// tests use, and it keeps every threshold a named constant that can be
/// retuned on a real device rather than a number buried in an average.
///
/// TUNING: the tolerances below have never been validated against a camera.
/// Human hands vary enormously, so these are deliberately loose; a tighter
/// tolerance makes the app nagging rather than more accurate, because a
/// learner's hand will never exactly match a canonical pose.
class FeedbackEngine {
  // The tolerances now live in RecognitionTuning so the camera test screen can
  // display the live values. They were never validated against a camera; see
  // the tuning note there and at the top of this class.
  static const double _extensionTolerance = RecognitionTuning.extensionTolerance;
  static const double _curledMax = RecognitionTuning.curledMax;
  static const double _extendedMin = RecognitionTuning.extendedMin;
  static const double _gapTolerance = RecognitionTuning.gapTolerance;
  static const int _maxCorrections = RecognitionTuning.maxCorrections;
  static const double _spreadThreshold = RecognitionTuning.spreadThreshold;

  static const Map<HandPart, String> _fingerNames = {
    HandPart.indexFinger: 'index finger',
    HandPart.middleFinger: 'middle finger',
    HandPart.ringFinger: 'ring finger',
    HandPart.pinkyFinger: 'pinky',
    HandPart.thumbFinger: 'thumb',
  };

  /// Compares [landmarks] against the reference pose for [label].
  ///
  /// Returns [SignFeedback.unsupported] for signs with no handshape reference
  /// - the everyday motion signs, which are scored on movement and position
  /// rather than handshape, and so have nothing to compare here.
  SignFeedback evaluate(String label, List<Landmark> landmarks) {
    final handshape = ReferenceSigns.handshapeFor(label);
    if (handshape == null) return SignFeedback.unsupported;

    final reference = ReferenceSigns.landmarksFor(label);
    if (reference == null) return SignFeedback.unsupported;

    if (landmarks.length < 21 || reference.length < 21) {
      return SignFeedback(
        label: label,
        handshape: handshape,
        closeness: 0,
        corrections: [
          const Correction(
            kind: CorrectionKind.unusableFrame,
            part: HandPart.wholeHand,
            severity: 1,
            message: 'Keep your whole hand in view',
          ),
        ],
      );
    }

    final actual = HandGeometry.fromLandmarks(landmarks);
    final expected = HandGeometry.fromLandmarks(reference);

    final scores = <double>[];
    final corrections = <Correction>[];

    _compareFinger(
      scores,
      corrections,
      HandPart.indexFinger,
      actual.indexExtensionRatio,
      expected.indexExtensionRatio,
    );
    _compareFinger(
      scores,
      corrections,
      HandPart.middleFinger,
      actual.middleExtensionRatio,
      expected.middleExtensionRatio,
    );
    _compareFinger(
      scores,
      corrections,
      HandPart.ringFinger,
      actual.ringExtensionRatio,
      expected.ringExtensionRatio,
    );
    _compareFinger(
      scores,
      corrections,
      HandPart.pinkyFinger,
      actual.pinkyExtensionRatio,
      expected.pinkyExtensionRatio,
    );
    _compareFinger(
      scores,
      corrections,
      HandPart.thumbFinger,
      actual.thumbExtensionRatio,
      expected.thumbExtensionRatio,
    );

    // The thumb is the other half of most FSL handshapes, and a thumb in the
    // wrong place changes the letter while every finger looks right - so it is
    // compared on where it sits, not just how far it is out.
    _compareGap(
      scores,
      corrections,
      actual.thumbToIndexTip,
      expected.thumbToIndexTip,
      'Bring your thumb to your index finger',
      'Move your thumb away from your index finger',
    );
    _compareGap(
      scores,
      corrections,
      actual.thumbToPinkyTip,
      expected.thumbToPinkyTip,
      'Bring your thumb across to your pinky',
      'Move your thumb away from your pinky',
    );

    if (scores.isEmpty) {
      return SignFeedback(
        label: label,
        handshape: handshape,
        closeness: 0,
        corrections: [
          const Correction(
            kind: CorrectionKind.unusableFrame,
            part: HandPart.wholeHand,
            severity: 1,
            message: 'Keep your whole hand in view',
          ),
        ],
      );
    }

    // A hand that is fully splayed, or a hand whose fingers are pressed
    // together when the sign needs them apart, is a common beginner mistake.
    // This is recorded as one whole-hand correction *alongside* the per-finger
    // ones rather than replacing them: for a flat hand attempting a fist, "curl
    // your fingers in" is the useful instruction, and throwing it away to say
    // only "bring your fingers together" is strictly less helpful. Ranking and
    // the cap below decide what the learner actually sees.
    final actualSpread = actual.thumbToPinkyTip;
    final expectedSpread = expected.thumbToPinkyTip;
    final spreadDelta = actualSpread - expectedSpread;

    if (expectedSpread < _spreadThreshold &&
        spreadDelta > _gapTolerance) {
      corrections.add(
        Correction(
          kind: CorrectionKind.fingersSpread,
          part: HandPart.wholeHand,
          severity: (spreadDelta / _gapTolerance - 1).clamp(0.0, 1.0),
          message: 'Bring your fingers together',
        ),
      );
    } else if (-spreadDelta > _gapTolerance) {
      corrections.add(
        Correction(
          kind: CorrectionKind.fingersTogether,
          part: HandPart.wholeHand,
          severity: (-spreadDelta / _gapTolerance - 1).clamp(0.0, 1.0),
          message: 'Spread your fingers apart',
        ),
      );
    }

    corrections.sort(
      (a, b) => b.severity.compareTo(a.severity),
    );

    final closeness = scores.reduce((a, b) => a + b) / scores.length;

    return SignFeedback(
      label: label,
      handshape: handshape,
      closeness: closeness.clamp(0.0, 1.0),
      corrections: corrections.take(_maxCorrections).toList(),
    );
  }

  /// Scores one finger's extension against the reference and records a
  /// correction when it is out of tolerance.
  ///
  /// The direction of the hint comes from which way the finger is *curled*, not
  /// from which of the two numbers is larger. Comparing the raw ratios gets
  /// this backwards: the reference ratio for a curled finger is small and for a
  /// straight one is large, so a learner holding a flat hand while attempting a
  /// fist - far and away the most common beginner error - would be told to
  /// straighten fingers that are already straight. Both values are first
  /// classified as curled, mid or extended, and the hint points at the
  /// reference's category.
  void _compareFinger(
    List<double> scores,
    List<Correction> corrections,
    HandPart part,
    double actual,
    double expected,
  ) {
    final name = _fingerNames[part]!;

    final expectedCurled = expected <= _curledMax;
    final actualCurled = actual <= _curledMax;
    final expectedStraight = expected >= _extendedMin;
    final actualStraight = actual >= _extendedMin;

    // Clear category mismatch: the learner is on the other side of folded vs
    // straight. This is the mistake worth leading with, so it always outranks
    // the fine-tuning hints below.
    if (expectedCurled && actualStraight) {
      scores.add(0);
      corrections.add(
        Correction(
          kind: CorrectionKind.curlFinger,
          part: part,
          severity: 1,
          message: 'Curl your $name in more',
        ),
      );
      return;
    }

    if (expectedStraight && actualCurled) {
      scores.add(0);
      corrections.add(
        Correction(
          kind: CorrectionKind.straightenFinger,
          part: part,
          severity: 1,
          message: 'Straighten your $name',
        ),
      );
      return;
    }

    // Same broad category, so this is about degree, not direction. A
    // percentage of the reference keeps the tolerance proportionate for both a
    // near-1 curled finger and a far larger extended one.
    final tolerance = math.max(0.05, expected.abs() * _extensionTolerance);
    final delta = (actual - expected).abs();
    final score = (1 - delta / tolerance).clamp(0.0, 1.0);
    scores.add(score);

    if (delta <= tolerance) return;

    corrections.add(
      Correction(
        kind: actual > expected
            ? CorrectionKind.straightenFinger
            : CorrectionKind.curlFinger,
        part: part,
        // Halved so a fine-tuning hint can never outrank a category mismatch,
        // which is the difference between "your finger is bent the wrong way"
        // and "your finger is nearly right".
        severity: (delta / tolerance - 1).clamp(0.0, 1.0) * 0.5,
        message: actual > expected
            ? 'Straighten your $name a little more'
            : 'Curl your $name in a little more',
      ),
    );
  }

  /// Scores one thumb-to-fingertip gap and records a correction when it is out
  /// of tolerance.
  void _compareGap(
    List<double> scores,
    List<Correction> corrections,
    double actual,
    double expected,
    String closerMessage,
    String fartherMessage,
  ) {
    final delta = (actual - expected).abs();
    final score = (1 - delta / _gapTolerance).clamp(0.0, 1.0);
    scores.add(score);

    if (delta <= _gapTolerance) return;

    corrections.add(
      Correction(
        kind: CorrectionKind.thumbPlacement,
        part: HandPart.thumbFinger,
        severity: (delta / _gapTolerance - 1).clamp(0.0, 1.0),
        message: actual > expected ? closerMessage : fartherMessage,
      ),
    );
  }
}
