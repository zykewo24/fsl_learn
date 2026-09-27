import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/ai_practice/recognition/greeting_motion_recognizer.dart';

void main() {
  final start = DateTime(2024, 1, 1);
  var ms = 0;

  GreetingMotionRecognizer fresh() {
    final r = GreetingMotionRecognizer();
    ms = 0;
    r.setClock(() => start.add(Duration(milliseconds: ms += 50)));
    return r;
  }

  void wave(
    GreetingMotionRecognizer r, {
    List<double>? xs,
    List<double>? ys,
  }) {
    final n = xs?.length ?? ys!.length;
    for (var i = 0; i < n; i++) {
      r.feedRaw(xs?[i] ?? 0.5, ys?[i] ?? 0.5);
    }
  }

  test('recognizes an outward push as SALAMAT', () {
    final r = fresh();
    // y sweeps monotonically down (outward), no reversals.
    wave(r,
        ys: [0.80, 0.72, 0.64, 0.58, 0.52, 0.50]);
    expect(r.lastGreeting, 'SALAMAT');
  });

  test('recognizes a horizontal side-to-side wave as PAALAM', () {
    final r = fresh();
    wave(r,
        xs: [0.20, 0.50, 0.25, 0.52, 0.22, 0.50],
        ys: const [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
    expect(r.lastGreeting, 'PAALAM');
  });

  test('recognizes a vertical up/down wave as KUMASTA', () {
    final r = fresh();
    wave(r,
        xs: const [0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
        ys: [0.20, 0.50, 0.25, 0.52, 0.22, 0.50]);
    expect(r.lastGreeting, 'KUMASTA');
  });

  test('returns null when the hand does not move', () {
    final r = fresh();
    for (var i = 0; i < 10; i++) {
      r.feedRaw(0.5, 0.5);
    }
    expect(r.lastGreeting, isNull);
  });

  test('forgets samples that fall outside the sliding window', () {
    final r = fresh();
    // A vertical wave, then a long pause, then a single far-away sample.
    // The wave's reversals are >900ms stale by the last frame, so they must
    // have been pruned: only 1 sample remains, which is below the 4-sample
    // floor, so nothing can be classified.
    wave(r, ys: [0.20, 0.50, 0.25, 0.52, 0.22, 0.50]);
    expect(r.lastGreeting, 'KUMASTA');

    // Push the clock well past the 900ms window between frames.
    for (var i = 0; i < 20; i++) {
      r.feedRaw(0.5, 0.02);
    }
    expect(r.lastGreeting, isNull);
  });

  test('a held hand does not keep replaying a stale wave', () {
    final r = fresh();
    wave(r, ys: [0.20, 0.50, 0.25, 0.52, 0.22, 0.50]);
    expect(r.lastGreeting, 'KUMASTA');

    // Now hold perfectly still. Each call advances the test clock by 50ms but
    // contributes no sample (the near-identical-frame filter drops it), so
    // after ~18 calls the wave has aged out of the 900ms window and there is
    // nothing left to classify. Without the window being honoured this would
    // keep reporting KUMASTA forever.
    for (var i = 0; i < 20; i++) {
      r.feedRaw(0.50, 0.50);
    }
    expect(r.lastGreeting, isNull);
  });

  test('isGreetingLabel categorizes the three greetings', () {
    expect(GreetingMotionRecognizer.isGreetingLabel('Kumasta'), isTrue);
    expect(GreetingMotionRecognizer.isGreetingLabel('salamat'), isTrue);
    expect(GreetingMotionRecognizer.isGreetingLabel('PAALAM'), isTrue);
    expect(GreetingMotionRecognizer.isGreetingLabel('B'), isFalse);
    expect(GreetingMotionRecognizer.isGreetingLabel('5'), isFalse);
  });
}
