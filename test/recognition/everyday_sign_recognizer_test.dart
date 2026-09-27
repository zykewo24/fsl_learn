import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/ai_practice/recognition/everyday_sign_recognizer.dart';

void main() {
  final start = DateTime(2024, 1, 1);
  var ms = 0;
  DateTime clock() => start.add(Duration(milliseconds: ms));
  void advance(int by) => ms += by;

  EverydaySignRecognizer fresh() {
    final r = EverydaySignRecognizer();
    ms = 0;
    r.setClock(clock);
    return r;
  }

  /// Feeds a sequence of (x, y) points, 50ms apart, matching the ~20fps
  /// detection cadence.
  String? gesture(
    EverydaySignRecognizer r,
    List<List<double>> path, {
    String? staticLabel = '5',
    double staticConfidence = 1.0,
  }) {
    String? out;
    for (final p in path) {
      advance(50);
      out = r.feedRaw(p[0], p[1],
          staticLabel: staticLabel, staticConfidence: staticConfidence);
    }
    return out;
  }

  // Representative paths, all inside the middle of the frame.
  const upDown = [
    [0.5, 0.30],
    [0.5, 0.55],
    [0.5, 0.32],
    [0.5, 0.53],
    [0.5, 0.34],
    [0.5, 0.52],
  ];
  const sideToSide = [
    [0.30, 0.5],
    [0.70, 0.5],
    [0.32, 0.5],
    [0.68, 0.5],
    [0.34, 0.5],
    [0.66, 0.5],
  ];
  const circle = [
    [0.50, 0.62],
    [0.62, 0.70],
    [0.50, 0.78],
    [0.38, 0.70],
    [0.50, 0.62],
    [0.60, 0.68],
  ];
  const sweepUp = [
    [0.5, 0.78],
    [0.5, 0.70],
    [0.5, 0.62],
    [0.5, 0.55],
    [0.5, 0.49],
    [0.5, 0.44],
  ];

  group('pattern table', () {
    test('covers every everyday label except the two-hand ones', () {
      for (final label in EverydaySignRecognizer.everydayLabels) {
        if (EverydaySignRecognizer.requiresTwoHands(label)) continue;
        expect(
          EverydaySignRecognizer.patternFor(label),
          isNotNull,
          reason: '$label has no pattern, so it can never be recognised',
        );
      }
    });

    test('every pattern label is a known everyday label', () {
      for (final p in EverydaySignRecognizer.patterns) {
        expect(EverydaySignRecognizer.isEverydayLabel(p.label), isTrue);
      }
    });

    test('every pattern is reachable by some handshape family', () {
      for (final p in EverydaySignRecognizer.patterns) {
        // A pattern with an empty handshape set could never match.
        expect(p.acceptableHandshapes, isNotEmpty, reason: p.label);
      }
    });

    test('declares LOVE as needing two hands', () {
      expect(EverydaySignRecognizer.requiresTwoHands('LOVE'), isTrue);
      expect(EverydaySignRecognizer.requiresTwoHands('YES'), isFalse);
    });
  });

  group('label helpers', () {
    test('isEverydayLabel is case and whitespace insensitive', () {
      expect(EverydaySignRecognizer.isEverydayLabel('water'), isTrue);
      expect(EverydaySignRecognizer.isEverydayLabel('  Water '), isTrue);
      expect(EverydaySignRecognizer.isEverydayLabel('B'), isFalse);
    });

    // The curriculum is inconsistent: it stores some signs with spaces and
    // some with underscores. These are the exact literals present in the seed
    // SQL, so this test fails if a form ever stops being recognised.
    test('recognises every spelling actually present in the seed data', () {
      const seedSpellings = [
        'Yes',
        'No',
        'Please',
        'Sorry',
        'Excuse Me',
        'EXCUSE_ME',
        'Good Morning',
        'GOOD_MORNING',
        'Good Night',
        'GOOD_NIGHT',
        'Love',
        'Welcome',
        'Water',
        'Eat',
        'Drink',
      ];

      for (final spelling in seedSpellings) {
        expect(
          EverydaySignRecognizer.isEverydayLabel(spelling),
          isTrue,
          reason: '"$spelling" is in the curriculum but is not an everyday '
              'label, so it can never be matched',
        );
      }
    });

    test('normalise folds both spellings onto one label', () {
      expect(
        EverydaySignRecognizer.normalise('Excuse Me'),
        EverydaySignRecognizer.normalise('EXCUSE_ME'),
      );
      expect(EverydaySignRecognizer.normalise('Good  Night'), 'GOOD_NIGHT');
    });

    test('every seed spelling resolves to a pattern where one exists', () {
      const spellings = [
        'Yes',
        'No',
        'Please',
        'Sorry',
        'Excuse Me',
        'Good Morning',
        'Good Night',
        'Welcome',
        'Water',
        'Eat',
        'Drink',
      ];
      for (final spelling in spellings) {
        expect(
          EverydaySignRecognizer.patternFor(spelling),
          isNotNull,
          reason: '"$spelling" resolves to no pattern',
        );
      }
    });
  });

  group('handshape requirement', () {
    test('requires a listed handshape', () {
      final r = fresh();
      // Vertical wave but with a handshape no vertical-wave pattern accepts.
      final result = gesture(r, upDown, staticLabel: 'Q');
      expect(result, isNull);
    });

    test('a handshape family match is enough', () {
      final r = fresh();
      // '3' is in the W family, which WATER requires.
      final result = gesture(r, upDown, staticLabel: '3');
      expect(result, isNotNull);
    });

    test('rejects a too-weak handshape', () {
      final r = fresh();
      final result =
          gesture(r, upDown, staticLabel: '5', staticConfidence: 0.2);
      expect(result, isNull);
      expect(r.lastRejection, 'handshape too weak');
    });

    test('gates a motionless pattern on handshape too', () {
      final r = fresh();
      // GOOD_NIGHT needs no movement, only a fist held at the face. An open
      // hand in the same place must not satisfy it.
      final atFace = List.generate(
        8,
        (_) => [0.5, 0.30],
      );
      expect(gesture(r, atFace, staticLabel: '5'), isNot('GOOD_NIGHT'));
      expect(gesture(r, atFace, staticLabel: 'A'), 'GOOD_NIGHT');
    });
  });

  group('motion shapes', () {
    test('recognises a vertical nod as a wave sign', () {
      final r = fresh();
      expect(gesture(r, upDown, staticLabel: 'A'), 'YES');
    });

    test('recognises a horizontal shake', () {
      final r = fresh();
      final result = gesture(r, sideToSide, staticLabel: '5');
      expect(
        result,
        anyOf('NO', 'EXCUSE_ME'),
        reason: 'NO and EXCUSE_ME share a handshape and a wave',
      );
    });

    test('a sweep is not read as a wave', () {
      final r = fresh();
      // Monotonic travel: no reversals, so no wave sign should fire.
      final result = gesture(r, sweepUp, staticLabel: '5');
      expect(result, 'GOOD_MORNING');
    });

    test('needs enough frames before deciding', () {
      final r = fresh();
      advance(50);
      final result = r.feedRaw(0.5, 0.30, staticLabel: 'A');
      expect(result, isNull);
      expect(r.lastRejection, isNull);
    });

    test('a static hand reports nothing while the window is too short', () {
      final r = fresh();
      advance(50);
      expect(r.feedRaw(0.5, 0.30, staticLabel: 'A'), isNull);
      expect(r.lastMatch, isNull);
    });
  });

  group('region requirement', () {
    test('a chest sign is rejected when the hand is up by the face', () {
      final r = fresh();
      // Circular motion, but up in the face band rather than the chest.
      final high = circle
          .map((p) => [p[0], p[1] - 0.35])
          .toList(growable: false);
      final result = gesture(r, high, staticLabel: '5');
      expect(result, isNot('PLEASE'));
    });

    test('a chest sign is accepted in the chest band', () {
      final r = fresh();
      expect(gesture(r, circle, staticLabel: '5'), 'PLEASE');
    });

    test('reports where the hand was expected to be', () {
      final r = fresh();
      final high = circle
          .map((p) => [p[0], p[1] - 0.35])
          .toList(growable: false);
      gesture(r, high, staticLabel: 'A');
      expect(r.lastRejection, contains('chest'));
    });

    test('a position-free sign ignores where the hand is', () {
      final r = fresh();
      // Low enough to be in the chest band, so a region-aware sign would
      // reject it. YES carries no region and must still match.
      final far = upDown.map((p) => [p[0], p[1] + 0.4]).toList(growable: false);
      expect(gesture(r, far, staticLabel: 'A'), 'YES');
    });
  });

  group('window behaviour', () {
    test('forgets movement that has aged out', () {
      final r = fresh();
      gesture(r, upDown, staticLabel: '3');
      expect(r.lastMatch, 'WATER', reason: 'a wave in the face band should register');

      // Idle well past the window with the same handshape but out in the chest
      // band, so a null can only mean the movement was forgotten.
      for (var i = 0; i < 40; i++) {
        advance(50);
        r.feedRaw(0.5, 0.78, staticLabel: '3');
      }
      expect(r.lastMatch, isNull);
    });

    test('a held hand accumulates no movement', () {
      final r = fresh();
      for (var i = 0; i < 20; i++) {
        advance(50);
        r.feedRaw(0.5, 0.42, staticLabel: '5');
      }
      expect(r.lastMatch, isNull);
    });

    test('reset clears the window', () {
      final r = fresh();
      gesture(r, upDown, staticLabel: 'A');
      r.reset();
      expect(r.lastMatch, isNull);
    });
  });

  group('region bands', () {
    test('are ordered so mouth sits inside face', () {
      expect(HandRegion.mouth.minY, greaterThanOrEqualTo(HandRegion.face.minY));
      expect(HandRegion.mouth.maxY, lessThanOrEqualTo(HandRegion.face.maxY));
    });

    test('chest is disjoint from face', () {
      expect(HandRegion.chest.minY, greaterThan(HandRegion.face.maxY));
    });

    test('contains respects its bounds', () {
      expect(HandRegion.face.contains(0.30), isTrue);
      expect(HandRegion.face.contains(0.90), isFalse);
    });
  });
}
