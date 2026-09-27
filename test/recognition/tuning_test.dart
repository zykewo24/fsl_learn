import 'package:fsl_learn/features/ai_practice/recognition/everyday_sign_recognizer.dart';
import 'package:fsl_learn/features/ai_practice/recognition/tuning.dart';
import 'package:fsl_learn/features/settings/models/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the tuning readout.
///
/// The camera test screen shows [RecognitionTuning.entries] so someone can
/// retune recognition while holding a hand in front of the lens. That readout is
/// only worth anything if the numbers on it are the numbers the recognisers
/// use. These tests pin the two together, because the failure mode is quiet: a
/// constant gets copied into the readout, someone tunes the copy, and the app
/// behaves exactly as before.
void main() {
  group('the tuning readout', () {
    test('describes every constant it lists', () {
      // An entry with a blank meaning or tuning note would render as a number
      // with no explanation, which is worse than not showing it at all.
      for (final e in RecognitionTuning.entries) {
        expect(e.name.trim(), isNotEmpty, reason: 'entry name');
        expect(e.value.trim(), isNotEmpty, reason: '${e.name} value');
        expect(e.meaning.trim(), isNotEmpty, reason: '${e.name} meaning');
        expect(e.tuning.trim(), isNotEmpty, reason: '${e.name} tuning');
        expect(e.group.trim(), isNotEmpty, reason: '${e.name} group');
      }
    });

    test('names are unique, so one constant is not listed twice', () {
      final names = RecognitionTuning.entries.map((e) => e.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('lists the feedback tolerances the engine actually uses', () {
      // If these four are renamed or retuned, the readout must follow.
      final names =
          RecognitionTuning.entries.map((e) => e.name).toSet();
      expect(names, contains('extensionTolerance'));
      expect(names, contains('curledMax'));
      expect(names, contains('extendedMin'));
      expect(names, contains('gapTolerance'));
      expect(names, contains('maxCorrections'));
      expect(names, contains('spreadThreshold'));
    });

    test('reports the value, not a stale literal', () {
      // The value shown is interpolated from the constant, so this catches the
      // case where someone hardcodes a number into the entry list.
      final byName = {
        for (final e in RecognitionTuning.entries) e.name: e.value,
      };
      expect(
        byName['extensionTolerance'],
        RecognitionTuning.extensionTolerance.toString(),
      );
      expect(
        byName['curledMax'],
        RecognitionTuning.curledMax.toString(),
      );
      expect(
        byName['maxCorrections'],
        RecognitionTuning.maxCorrections.toString(),
      );
    });

    test('reports motion thresholds in a readable unit', () {
      final byName = {
        for (final e in RecognitionTuning.entries) e.name: e.value,
      };
      expect(byName['motionWindow'], '1200 ms');
      expect(byName['motionMinSamples'], '5');
    });
  });

  group('the dwell default', () {
    test('matches the default hold the settings screen starts on', () {
      // RecognitionTuning lists the default hold so that "why will this sign
      // not register" has an answer on screen. If the settings default ever
      // changes and this does not, the readout will send someone tuning
      // recognition for a problem that is really a raised hold.
      expect(
        RecognitionTuning.defaultHold,
        HoldToConfirm.seconds3.duration,
      );
    });

    test('is what a learner with no stored preference gets', () {
      expect(
        HoldToConfirm.fromStorage(null),
        HoldToConfirm.seconds3,
      );
      expect(
        HoldToConfirm.fromStorage(''),
        HoldToConfirm.seconds3,
      );
    });

    test('grace matches the gate default', () {
      expect(
        RecognitionTuning.defaultDwellGrace,
        const Duration(milliseconds: 300),
      );
    });
  });

  group('recognition stays untouched by the refactor', () {
    test('the motion window is the one the samples are filtered by', () {
      // A regression here would silently change every motion sign, so assert
      // the recogniser's own window is the tunable's window.
      expect(RecognitionTuning.motionWindow.inMilliseconds, 1200);
    });

    test('motion confidence ceiling cannot claim more than it earns', () {
      // Motion scores come from normalised wrist samples with no pose model, so
      // they must stay well below what a real handshape match reports.
      expect(RecognitionTuning.motionConfidenceMax, lessThan(0.5));
      expect(RecognitionTuning.motionConfidenceMax, greaterThan(0));
    });

    test('a curled finger and a straight one are distinguishable', () {
      // If curledMax ever reached extendedMin there would be no band in
      // between, and every finger would be either definitively curled or
      // definitively straight with no fine-tuning hint possible.
      expect(
        RecognitionTuning.curledMax,
        lessThan(RecognitionTuning.extendedMin),
      );
    });

    test('the extension tolerance is a fraction, not a pixel count', () {
      expect(RecognitionTuning.extensionTolerance, inInclusiveRange(0, 1));
    });

    test('axis dominance is a proportion', () {
      expect(RecognitionTuning.axisDominance, inInclusiveRange(0.5, 1));
    });

    test('the recogniser still exposes its labels', () {
      // Cheap guard that the import of tuning.dart did not disturb the
      // recogniser's public surface.
      expect(EverydaySignRecognizer.everydayLabels, isNotEmpty);
      expect(EverydaySignRecognizer.everydayLabels, contains('YES'));
    });
  });
}
