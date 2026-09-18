import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/ai_practice/models/landmark.dart';
import 'package:fsl_learn/features/ai_practice/recognition/gesture_recognizer.dart';

import '../support/alphabet_poses.dart';
import '../support/detections.dart';
import '../support/number_poses.dart';

/// Rotates all landmarks around the wrist in the image (x,y) plane,
/// keeping z fixed. Simulates the user holding the hand rolled
/// (signed sideways) with the palm still roughly facing the camera.
List<Landmark> rotated(List<Landmark> src, double degrees) {
  final rad = degrees * math.pi / 180;
  final cosA = math.cos(rad), sinA = math.sin(rad);
  final wrist = src.first;
  return [
    for (final l in src)
      Landmark(
        x: wrist.x + (l.x - wrist.x) * cosA - (l.y - wrist.y) * sinA,
        y: wrist.y + (l.x - wrist.x) * sinA + (l.y - wrist.y) * cosA,
        z: l.z,
      ),
  ];
}

List<Landmark> _build(String name) {
  switch (name) {
    case 'a':
      return AlphabetPoses.a();
    case 'b':
      return AlphabetPoses.b();
    case 'c':
      return AlphabetPoses.c();
    case 'd':
      return AlphabetPoses.d();
    case 'e':
      return AlphabetPoses.e();
    case 'f':
      return AlphabetPoses.f();
    case 'g':
      return AlphabetPoses.g();
    case 'h':
      return AlphabetPoses.h();
    case 'i':
      return AlphabetPoses.i();
    case 'k':
      return AlphabetPoses.k();
    case 'l':
      return AlphabetPoses.l();
    case 'm':
      return AlphabetPoses.m();
    case 'n':
      return AlphabetPoses.n();
    case 'o':
      return AlphabetPoses.o();
    case 'p':
      return AlphabetPoses.p();
    case 'q':
      return AlphabetPoses.q();
    case 'r':
      return AlphabetPoses.r();
    case 's':
      return AlphabetPoses.s();
    case 't':
      return AlphabetPoses.t();
    case 'u':
      return AlphabetPoses.u();
    case 'v':
      return AlphabetPoses.v();
    case 'w':
      return AlphabetPoses.w();
    case 'x':
      return AlphabetPoses.x();
    case 'y':
      return AlphabetPoses.y();
    case 'z':
      return AlphabetPoses.z();
    case 'zero':
      return NumberPoses.zero();
    case 'one':
      return NumberPoses.one();
    case 'two':
      return NumberPoses.two();
    case 'three':
      return NumberPoses.three();
    case 'four':
      return NumberPoses.four();
    case 'five':
      return NumberPoses.five();
    case 'six':
      return NumberPoses.six();
    case 'seven':
      return NumberPoses.seven();
    case 'eight':
      return NumberPoses.eight();
    case 'nine':
      return NumberPoses.nine();
  }
  throw ArgumentError(name);
}

const _degrees = [45, 90, 135, 180, 225, 270, 315];

void main() {
  final recognizer = GestureRecognizer();

  for (final deg in _degrees) {
    group('hand rotated $deg deg (signed sideways)', () {
      for (final name in _alphabetNames) {
        test('still recognizes a sideways $name', () {
          final label = recognizer
              .recognize(detectionFrom(rotated(_build(name), deg.toDouble())))
              .label;
          expect(label, name.toUpperCase(),
              reason: '$name at $deg deg');
        });
      }

      for (final entry in _numberEntries) {
        test('still recognizes a sideways ${entry.name}', () {
          final label = recognizer
              .recognize(
                  detectionFrom(rotated(_build(entry.name), deg.toDouble())))
              .label;
          expect(
            GestureRecognizer.familyOf(label ?? ''),
            contains(entry.digit),
            reason: '${entry.name} at $deg deg',
          );
        });
      }
    });
  }
}

const _alphabetNames = [
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'k', 'l', 'm', 'n', 'o',
  'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
];

const _numberEntries = [
  _Num('zero', '0'),
  _Num('one', '1'),
  _Num('two', '2'),
  _Num('three', '3'),
  _Num('four', '4'),
  _Num('five', '5'),
  _Num('six', '6'),
  _Num('seven', '7'),
  _Num('eight', '8'),
  _Num('nine', '9'),
];

class _Num {
  final String name;
  final String digit;
  const _Num(this.name, this.digit);
}