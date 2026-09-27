import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/ai_practice/recognition/dwell_gate.dart';

void main() {
  final start = DateTime(2024, 1, 1);
  var ms = 0;

  /// Manually advanced clock. The gate must never read wall time, or the
  /// timing behaviour is untestable and, as the motion recognisers showed,
  /// silently untested.
  DateTime clock() => start.add(Duration(milliseconds: ms));

  void advance(int by) => ms += by;

  DwellGate gate({
    Duration hold = const Duration(seconds: 2),
    Duration? grace,
  }) =>
      DwellGate(
        requiredHold: hold,
        grace: grace,
        clock: clock,
      );

  setUp(() => ms = 0);

  group('completing a hold', () {
    test('does not complete before the required time', () {
      final g = gate();
      expect(g.feed(signId: 'a').justCompleted, isFalse);

      advance(1999);
      final u = g.feed(signId: 'a');
      expect(u.justCompleted, isFalse);
      expect(u.progress, closeTo(0.9995, 0.001));
    });

    test('completes once the required time is reached', () {
      final g = gate();
      g.feed(signId: 'a');

      advance(2000);
      final u = g.feed(signId: 'a');
      expect(u.justCompleted, isTrue);
      expect(u.stage, DwellStage.holding);
      expect(u.progress, 1.0);
    });

    test('reports justCompleted exactly once, not on every later frame', () {
      final g = gate();
      g.feed(signId: 'a');
      advance(2000);
      expect(g.feed(signId: 'a').justCompleted, isTrue);

      for (var i = 0; i < 5; i++) {
        advance(50);
        final u = g.feed(signId: 'a');
        expect(u.justCompleted, isFalse, reason: 'must not re-fire');
        expect(u.progress, 1.0);
      }
      expect(g.isLatchedComplete, isTrue);
    });

    test('accumulates across many short frames, not just two', () {
      final g = gate();
      g.feed(signId: 'a');
      // 40 frames of 50ms, the real detection cadence, is 2000ms.
      var completed = false;
      for (var i = 0; i < 40; i++) {
        advance(50);
        if (g.feed(signId: 'a').justCompleted) completed = true;
      }
      expect(completed, isTrue);
    });

    test('clamps progress to 1 rather than overshooting', () {
      final g = gate();
      g.feed(signId: 'a');
      advance(5000);
      expect(g.feed(signId: 'a').progress, 1.0);
      expect(g.feed(signId: 'a').progress, lessThanOrEqualTo(1.0));
    });
  });

  group('off', () {
    test('completes on the first frame, restoring the old behaviour', () {
      final g = gate(hold: Duration.zero);
      final u = g.feed(signId: 'a');
      expect(g.isInstant, isTrue);
      expect(u.justCompleted, isTrue);
      expect(u.progress, 1.0);
    });

    test('reports nothing held when there is no match', () {
      final g = gate(hold: Duration.zero);
      final u = g.feed(signId: null);
      expect(u.justCompleted, isFalse);
      expect(u.stage, DwellStage.idle);
    });
  });

  group('losing the match', () {
    test('pauses on a short dropout and resumes where it left off', () {
      final g = gate(grace: const Duration(milliseconds: 300));
      g.feed(signId: 'a');
      advance(1000);
      expect(g.feed(signId: 'a').progress, closeTo(0.5, 0.001));

      // 200ms blackout, inside the 300ms grace.
      advance(200);
      final paused = g.feed(signId: null);
      expect(paused.stage, DwellStage.paused);
      expect(paused.justCompleted, isFalse);
      expect(paused.progress, closeTo(0.6, 0.001));

      advance(100);
      final resumed = g.feed(signId: 'a');
      expect(resumed.stage, DwellStage.holding);
      expect(resumed.progress, closeTo(0.6, 0.001));
    });

    test('does not credit the paused span to the hold', () {
      final g = gate(grace: const Duration(milliseconds: 300));
      g.feed(signId: 'a');
      advance(1000);
      g.feed(signId: 'a');

      // Black out for 200ms.
      advance(200);
      g.feed(signId: null);
      advance(200);
      g.feed(signId: 'a');

      // 1000ms held + 200ms held again = 1200ms, not 1400ms.
      expect(g.progress, closeTo(0.6, 0.001));
    });

    test('still completes when a single bad frame interrupts the hold', () {
      final g = gate(grace: const Duration(milliseconds: 300));
      g.feed(signId: 'a');
      var completed = false;
      for (var i = 0; i < 60; i++) {
        advance(50);
        // Drop one frame every ten, as a real tracker would.
        final u = g.feed(signId: i % 10 == 9 ? null : 'a');
        if (u.justCompleted) completed = true;
      }
      expect(completed, isTrue, reason: 'dropouts must not restart the hold');
    });

    test('resets to zero when the dropout outlives the grace window', () {
      final g = gate(grace: const Duration(milliseconds: 300));
      g.feed(signId: 'a');
      advance(1000);
      g.feed(signId: 'a');
      expect(g.progress, closeTo(0.5, 0.001));

      advance(200);
      expect(g.feed(signId: null).stage, DwellStage.paused);

      // Still inside grace.
      advance(99);
      expect(g.feed(signId: null).stage, DwellStage.paused);
      expect(g.progress, closeTo(0.6, 0.001));

      // Crosses it.
      advance(201);
      final dead = g.feed(signId: null);
      expect(dead.stage, DwellStage.idle);
      expect(dead.progress, 0.0);
      expect(g.heldSignId, isNull);
    });

    test('a hold interrupted past the grace window restarts from zero', () {
      final g = gate(hold: const Duration(seconds: 4));
      g.feed(signId: 'a');
      advance(1000);
      g.feed(signId: 'a');
      expect(g.progress, closeTo(0.25, 0.001));

      advance(200);
      expect(g.feed(signId: null).stage, DwellStage.paused);

      advance(400);
      expect(g.feed(signId: null).stage, DwellStage.idle);
      expect(g.feed(signId: 'a').progress, 0.0);
    });

    test('a hold that reached the duration across a dropout still commits', () {
      // The gate credits time on the frame the match is lost, so held time can
      // cross the threshold without a live frame to report it on. Completion
      // must be checked on the resuming frame too, not a frame late.
      final g = gate(hold: const Duration(seconds: 2));
      g.feed(signId: 'a');
      advance(2000);
      expect(g.feed(signId: null).stage, DwellStage.paused);

      advance(100);
      final resumed = g.feed(signId: 'a');
      expect(resumed.justCompleted, isTrue);
      expect(resumed.progress, 1.0);
    });
  });

  group('switching signs', () {
    test('a different sign voids the hold in progress', () {
      final g = gate();
      g.feed(signId: 'a');
      advance(1500);
      expect(g.feed(signId: 'a').progress, closeTo(0.75, 0.001));

      final switched = g.feed(signId: 'b');
      expect(switched.progress, 0.0);
      expect(g.heldSignId, 'b');
    });

    test('does not let a new sign inherit the old sign completion', () {
      final g = gate();
      g.feed(signId: 'a');
      advance(2000);
      expect(g.feed(signId: 'a').justCompleted, isTrue);

      final b = g.feed(signId: 'b');
      expect(b.justCompleted, isFalse);
      expect(b.progress, 0.0);
    });
  });

  group('reconfiguration and reset', () {
    test('changing the hold time drops the hold in progress', () {
      final g = gate(hold: const Duration(seconds: 2));
      g.feed(signId: 'a');
      advance(1500);
      g.feed(signId: 'a');
      expect(g.progress, closeTo(0.75, 0.001));

      g.setRequiredHold(const Duration(seconds: 5));
      expect(g.heldSignId, isNull);
      expect(g.progress, 0.0);
      expect(g.requiredHold, const Duration(seconds: 5));
    });

    test('setting the same hold time is a no-op', () {
      final g = gate(hold: const Duration(seconds: 2));
      g.feed(signId: 'a');
      advance(1000);
      g.feed(signId: 'a');
      expect(g.progress, closeTo(0.5, 0.001));

      g.setRequiredHold(const Duration(seconds: 2));
      expect(g.progress, closeTo(0.5, 0.001), reason: 'must not reset');
    });

    test('reset clears everything', () {
      final g = gate();
      g.feed(signId: 'a');
      advance(2000);
      g.feed(signId: 'a');
      g.reset();

      expect(g.heldSignId, isNull);
      expect(g.progress, 0.0);
      expect(g.isLatchedComplete, isFalse);
    });
  });

  group('progress reporting', () {
    test('is zero before anything is held', () {
      expect(gate().progress, 0.0);
    });

    test('rises monotonically across a clean hold', () {
      final g = gate();
      final seen = <double>[];
      g.feed(signId: 'a');
      for (var i = 0; i < 10; i++) {
        advance(100);
        seen.add(g.feed(signId: 'a').progress);
      }
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });
  });
}
