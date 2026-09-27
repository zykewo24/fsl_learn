import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/ai_practice/models/landmark.dart';
import 'package:fsl_learn/features/ai_practice/recognition/feedback_engine.dart';
import 'package:fsl_learn/features/ai_practice/recognition/hand_geometry.dart';
import 'package:fsl_learn/features/ai_practice/recognition/reference/reference_signs.dart';

import '../support/synthetic_hand.dart';

void main() {
  final engine = FeedbackEngine();

  List<Landmark> hand() => SyntheticHand().build();

  group('reference sign coverage', () {
    test('covers the 47-sign scope of letters, numbers, colors and animals',
        () {
      // 25 letters + 10 numbers + 6 colors + 6 animals.
      expect(ReferenceSigns.handshapeByLabel, hasLength(47));
    });

    test('those 47 signs need only 35 distinct poses', () {
      // Colors and animals reuse letter and digit handshapes, which is why
      // the feedback scope needed no new pose data.
      final shapes = ReferenceSigns.handshapeByLabel.values.toSet();
      expect(shapes, hasLength(35));
    });

    test('also supports the spelled-out number words the curriculum uses', () {
      // Ten more spellings of the same ten digits, so the total set of
      // supported labels is larger than the 47-sign scope.
      expect(ReferenceSigns.supportedLabels, hasLength(57));
      expect(ReferenceSigns.isSupported('SEVEN'), isTrue);
    });

    test('includes no J, which FSL does not have', () {
      expect(ReferenceSigns.isSupported('J'), isFalse);
    });

    test('maps colors and animals onto letter handshapes', () {
      expect(ReferenceSigns.handshapeFor('RED'), 'X');
      expect(ReferenceSigns.handshapeFor('BLUE'), 'B');
      expect(ReferenceSigns.handshapeFor('FROG'), 'V');
      expect(ReferenceSigns.handshapeFor('FISH'), '5');
    });

    test('maps number words onto digits', () {
      expect(ReferenceSigns.handshapeFor('THREE'), '3');
      expect(ReferenceSigns.handshapeFor('nine'), '9');
    });

    test('has a pose for every supported sign', () {
      for (final label in ReferenceSigns.supportedLabels) {
        final pose = ReferenceSigns.landmarksFor(label);
        expect(pose, isNotNull, reason: '$label has no pose');
        expect(pose, hasLength(21), reason: '$label pose is malformed');
      }
    });

    test('rejects the motion-only everyday signs', () {
      // These have no handshape, so there is nothing to compare.
      for (final label in ['WATER', 'EAT', 'LOVE', 'YES']) {
        expect(
          ReferenceSigns.isSupported(label),
          isFalse,
          reason: '$label is motion-based and must not claim a handshape',
        );
      }
    });

    test('hands out a fresh pose each call so the reference cannot be mutated',
        () {
      final first = ReferenceSigns.landmarksFor('A')!;
      final second = ReferenceSigns.landmarksFor('A')!;
      expect(identical(first, second), isFalse);
      expect(identical(first[0], second[0]), isFalse);
    });
  });

  group('a correct attempt', () {
    test('produces no corrections for every supported sign', () {
      // This is the false-positive guard and the reason the tolerances are
      // loose. If the reference pose does not score as perfect against itself,
      // every learner would be told to fix a hand that is already right.
      for (final label in ReferenceSigns.supportedLabels) {
        final pose = ReferenceSigns.landmarksFor(label)!;
        final feedback = engine.evaluate(label, pose);
        expect(
          feedback.corrections,
          isEmpty,
          reason: '$label flagged its own correct pose: '
              '${feedback.corrections.map((c) => c.message).toList()}',
        );
        expect(feedback.closeness, closeTo(1.0, 0.001), reason: label);
      }
    });

    test('is invariant to a uniform scale of the hand', () {
      // A learner whose hand is simply further from the camera must not be
      // told to change anything.
      final pose = ReferenceSigns.landmarksFor('B')!;
      final scaled = pose
          .map((l) => Landmark(x: 0.5 + (l.x - 0.5) * 1.6, y: 0.5 + (l.y - 0.5) * 1.6, z: l.z * 1.6))
          .toList();
      expect(engine.evaluate('B', scaled).corrections, isEmpty);
    });
  });

  group('specific corrections', () {
    test('a flat open hand is told to curl its fingers in', () {
      // A vs a flat hand: every finger is out instead of folded.
      final flat = hand();
      final feedback = engine.evaluate('A', flat);
      expect(feedback.corrections, isNotEmpty);
      expect(
        feedback.corrections.map((c) => c.kind),
        anyElement(CorrectionKind.curlFinger),
      );
    });

    test('a flat hand attempting a fist is told to curl in', () {
      // 0 is a closed fist, so an open hand is curled the wrong way.
      final feedback = engine.evaluate('0', hand());
      expect(feedback.corrections, isNotEmpty);
      expect(
        feedback.corrections.map((c) => c.kind),
        anyElement(CorrectionKind.curlFinger),
      );
    });

    test('a fist attempting a flat hand is told to straighten', () {
      // The mirror image, which is where a naive "bigger number means
      // straighten" rule gives the opposite of the right advice.
      final fist = ReferenceSigns.landmarksFor('0')!;
      final feedback = engine.evaluate('5', fist);
      expect(feedback.corrections, isNotEmpty);
      expect(
        feedback.corrections.map((c) => c.kind),
        anyElement(CorrectionKind.straightenFinger),
      );
    });

    test('a category mismatch outranks a fine-tuning hint', () {
      // Curling the right way but not far enough should never bury the fact
      // that the finger needs to cross a category boundary entirely.
      final feedback = engine.evaluate('A', hand());
      final top = feedback.corrections.first;
      expect(top.severity, 1.0, reason: top.message);
      expect(
        top.kind,
        anyOf(CorrectionKind.curlFinger, CorrectionKind.fingersSpread),
      );
    });

    test('names the finger that is wrong', () {
      final feedback = engine.evaluate('A', hand());
      final named = feedback.corrections.where(
        (c) => c.message.contains('finger'),
      );
      expect(named, isNotEmpty, reason: 'the hint should name a finger');
    });

    test('caps how many corrections are shown', () {
      // A splayed hand is wrong in every way at once; the learner still needs
      // one or two actionable hints, not seven.
      final feedback = engine.evaluate('0', hand());
      expect(feedback.corrections.length, lessThanOrEqualTo(2));
    });

    test('ranks the most severe correction first', () {
      final feedback = engine.evaluate('A', hand());
      for (var i = 1; i < feedback.corrections.length; i++) {
        expect(
          feedback.corrections[i - 1].severity,
          greaterThanOrEqualTo(feedback.corrections[i].severity),
        );
      }
    });

    test('closeness falls as the hand gets further from the reference', () {
      final reference = ReferenceSigns.landmarksFor('V')!;
      final geometry = HandGeometry.fromLandmarks(reference);

      final close = engine.evaluate('V', reference).closeness;
      expect(geometry.rawPalmWidth, greaterThan(0));

      // A flat hand is much further from V than V is from itself.
      final far = engine.evaluate('V', hand()).closeness;
      expect(far, lessThan(close));
    });
  });

  group('unsupported input', () {
    test('reports unsupported for a motion-only sign', () {
      final feedback = engine.evaluate('WATER', hand());
      expect(feedback.closeness, 0);
      expect(feedback.corrections, isEmpty);
      expect(ReferenceSigns.isSupported('WATER'), isFalse);
    });

    test('asks for a better frame when there are too few landmarks', () {
      final feedback = engine.evaluate('A', [
        const Landmark(x: 0.5, y: 0.5, z: 0),
      ]);
      expect(feedback.corrections, hasLength(1));
      expect(feedback.corrections.first.kind, CorrectionKind.unusableFrame);
    });

    test('never returns a NaN closeness', () {
      for (final label in ReferenceSigns.supportedLabels) {
        final pose = ReferenceSigns.landmarksFor(label)!;
        expect(engine.evaluate(label, pose).closeness.isNaN, isFalse);
      }
    });
  });
}
