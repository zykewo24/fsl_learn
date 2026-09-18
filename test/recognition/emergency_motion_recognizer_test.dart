import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/ai_practice/recognition/emergency_motion_recognizer.dart';

void main() {
  final start = DateTime(2024, 1, 1);
  var ms = 0;

  EmergencyMotionRecognizer fresh() {
    final r = EmergencyMotionRecognizer();
    ms = 0;
    r.setClock(() => start.add(Duration(milliseconds: ms += 50)));
    return r;
  }

  void feed(
    EmergencyMotionRecognizer r, {
    List<double>? xs,
    List<double>? ys,
  }) {
    final n = xs?.length ?? ys!.length;
    for (var i = 0; i < n; i++) {
      r.feedRaw(xs?[i] ?? 0.5, ys?[i] ?? 0.5);
    }
  }

  test('recognizes a single vertical thrust as HELP', () {
    final r = fresh();
    // Wrist sweeps monotonically downward (y dominant), no reversals.
    feed(r,
        xs: const [0.5, 0.5, 0.5, 0.5],
        ys: [0.80, 0.70, 0.60, 0.50]);
    expect(r.lastEmergency, 'HELP');
  });

  test('recognizes a single horizontal strike as DANGER', () {
    final r = fresh();
    // Wrist sweeps monotonically sideways (x dominant), no reversals.
    feed(r,
        xs: [0.20, 0.30, 0.40, 0.50],
        ys: const [0.5, 0.5, 0.5, 0.5]);
    expect(r.lastEmergency, 'DANGER');
  });

  test('recognizes a vigorous shake as FIRE', () {
    final r = fresh();
    // Rapid, high-amplitude oscillation with meaningful net movement.
    feed(r,
        xs: [0.50, 0.70, 0.50, 0.70, 0.50, 0.70],
        ys: const [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
    expect(r.lastEmergency, 'FIRE');
  });

  test('recognizes localized repeated taps as MEDICAL', () {
    final r = fresh();
    // Small back-and-forth motion that stays near the starting spot.
    feed(r,
        xs: [0.50, 0.51, 0.50, 0.51, 0.50, 0.51],
        ys: const [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
    expect(r.lastEmergency, 'MEDICAL');
  });

  test('returns null when the hand does not move', () {
    final r = fresh();
    for (var i = 0; i < 10; i++) {
      r.feedRaw(0.5, 0.5);
    }
    expect(r.lastEmergency, isNull);
  });

  test('filters out near-identical held frames (no false shake)', () {
    final r = fresh();
    // Holds mostly still with tiny sampling noise.
    feed(r,
        xs: [0.5, 0.501, 0.5, 0.501, 0.5, 0.501],
        ys: const [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
    // Movement is below the feed threshold so it should not classify.
    expect(r.lastEmergency, isNull);
  });

  test('isEmergencyLabel categorizes the four emergencies', () {
    expect(EmergencyMotionRecognizer.isEmergencyLabel('Help'), isTrue);
    expect(EmergencyMotionRecognizer.isEmergencyLabel('fire'), isTrue);
    expect(EmergencyMotionRecognizer.isEmergencyLabel('DANGER'), isTrue);
    expect(EmergencyMotionRecognizer.isEmergencyLabel('MEDICAL'), isTrue);
    expect(EmergencyMotionRecognizer.isEmergencyLabel('B'), isFalse);
    expect(EmergencyMotionRecognizer.isEmergencyLabel('KUMASTA'), isFalse);
  });
}
