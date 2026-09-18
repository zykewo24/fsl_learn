import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/ai_practice/models/detection_result.dart';
import 'package:fsl_learn/features/ai_practice/models/landmark.dart';
import 'package:fsl_learn/features/ai_practice/recognition/gesture_recognizer.dart';

import '../support/alphabet_poses.dart';
import '../support/detections.dart';
import '../support/number_poses.dart';

void main() {
  final recognizer = GestureRecognizer();

  test('recognizes every static letter pose', () {
    expect(recognize(AlphabetPoses.a()), 'A');
    expect(recognize(AlphabetPoses.b()), 'B');
    expect(recognize(AlphabetPoses.c()), 'C');
    expect(recognize(AlphabetPoses.d()), 'D');
    expect(recognize(AlphabetPoses.e()), 'E');
    expect(recognize(AlphabetPoses.f()), 'F');
    expect(recognize(AlphabetPoses.g()), 'G');
    expect(recognize(AlphabetPoses.h()), 'H');
    expect(recognize(AlphabetPoses.i()), 'I');
    expect(recognize(AlphabetPoses.k()), 'K');
    expect(recognize(AlphabetPoses.l()), 'L');
    expect(recognize(AlphabetPoses.m()), 'M');
    expect(recognize(AlphabetPoses.n()), 'N');
    expect(recognize(AlphabetPoses.o()), 'O');
    expect(recognize(AlphabetPoses.p()), 'P');
    expect(recognize(AlphabetPoses.q()), 'Q');
    expect(recognize(AlphabetPoses.r()), 'R');
    expect(recognize(AlphabetPoses.s()), 'S');
    expect(recognize(AlphabetPoses.t()), 'T');
    expect(recognize(AlphabetPoses.u()), 'U');
    expect(recognize(AlphabetPoses.v()), 'V');
    expect(recognize(AlphabetPoses.w()), 'W');
    expect(recognize(AlphabetPoses.x()), 'X');
    expect(recognize(AlphabetPoses.y()), 'Y');
    expect(recognize(AlphabetPoses.z()), 'Z');
  });

  test('recognizes every number pose', () {
    // 0/2/3/4 share their handshape with O/S, U/V, W, B respectively, so
    // claim a match from the shared handshape family.
    expect(family(recognize(NumberPoses.zero())), contains('0'));
    expect(recognize(NumberPoses.one()), '1');
    expect(family(recognize(NumberPoses.two())), contains('2'));
    expect(family(recognize(NumberPoses.three())), contains('3'));
    expect(family(recognize(NumberPoses.four())), contains('4'));
    expect(recognize(NumberPoses.five()), '5');
    expect(recognize(NumberPoses.six()), '6');
    expect(recognize(NumberPoses.seven()), '7');
    expect(recognize(NumberPoses.eight()), '8');
    // 9 shares its handshape with F, so claim a match from the shared family.
    expect(family(recognize(NumberPoses.nine())), contains('9'));
  });

  test('returns no match when no hand is present', () {
    final result = recognizer.recognize(
      const DetectionResult(
        handCount: 0,
        handedness: 'Left',
        confidence: 0.99,
        inferenceTimeMs: 1,
        landmarks: <Landmark>[],
      ),
    );
    expect(result.matched, isFalse);
    expect(result.label, isNull);
  });

  test('returns no match when landmark count is not 21', () {
    final landmarks = <Landmark>[
      for (var i = 0; i < 5; i++)
        Landmark(x: 0.5, y: 0.5, z: 0.0),
    ];
    final result = recognizer.recognize(
      DetectionResult(
        handCount: 1,
        handedness: 'Left',
        confidence: 0.99,
        inferenceTimeMs: 1,
        landmarks: landmarks,
      ),
    );

    expect(result.matched, isFalse);
    expect(result.label, isNull);
  });

  test('does not match a relaxed open hand to a letter', () {
    final open = DetectionResult(
      handCount: 1,
      handedness: 'Left',
      confidence: 0.99,
      inferenceTimeMs: 1,
      landmarks: _openPalm(),
    );

    final result = recognizer.recognize(open);

    expect(result.matched, isFalse);
  });

  test('exposes A calibration debug data', () {
    recognizer.recognize(detectionFrom(AlphabetPoses.a()));

    final debug = recognizer.lastDebugData;
    expect(debug, isNotNull);
    expect(debug!.thumbOpen, isTrue);
    expect(debug.matchesA, isTrue);
  });
}

String? recognize(List<Landmark> landmarks) {
  final recognizer = GestureRecognizer();
  return recognizer.recognize(detectionFrom(landmarks)).label;
}

Set<String> family(String? label) =>
    GestureRecognizer.familyOf(label ?? '');

List<Landmark> _openPalm() {
  final hand = [
    const Landmark(x: 0.50, y: 0.63, z: 0.00), // 0 wrist
    const Landmark(x: 0.41, y: 0.56, z: 0.00),
    const Landmark(x: 0.43, y: 0.52, z: 0.02),
    const Landmark(x: 0.44, y: 0.48, z: 0.04),
    const Landmark(x: 0.28, y: 0.35, z: 0.08), // 4 thumb tip
    const Landmark(x: 0.46, y: 0.55, z: 0.03), // 5 index mcp
    const Landmark(x: 0.46, y: 0.45, z: 0.04),
    const Landmark(x: 0.46, y: 0.37, z: 0.05),
    const Landmark(x: 0.46, y: 0.30, z: 0.06), // 8 index tip
    const Landmark(x: 0.51, y: 0.54, z: 0.03),
    const Landmark(x: 0.51, y: 0.44, z: 0.04),
    const Landmark(x: 0.51, y: 0.36, z: 0.05),
    const Landmark(x: 0.51, y: 0.29, z: 0.06),
    const Landmark(x: 0.56, y: 0.545, z: 0.03),
    const Landmark(x: 0.56, y: 0.44, z: 0.04),
    const Landmark(x: 0.56, y: 0.36, z: 0.05),
    const Landmark(x: 0.56, y: 0.295, z: 0.06),
    const Landmark(x: 0.60, y: 0.56, z: 0.025),
    const Landmark(x: 0.60, y: 0.47, z: 0.03),
    const Landmark(x: 0.60, y: 0.40, z: 0.04),
    const Landmark(x: 0.60, y: 0.35, z: 0.05),
  ];
  return hand;
}