/// Every hand-recognition threshold in one place, named and public.
///
/// WHY THIS EXISTS
///
/// These numbers decide whether a sign is recognised and what the learner is
/// told to fix. They were tuned against synthetic hands in unit tests, never
/// against a camera, so they are the first thing that will need adjusting on a
/// real device. That only works if you can see the current value while holding
/// your hand in front of the lens, which is what [entries] is for.
///
/// The camera test screen renders [entries] as a live readout. That readout
/// reads THESE values, not copies, so it cannot drift away from what the
/// recognisers actually do. If you change a number here, the screen changes
/// with it and the next build uses the new value.
///
/// To retune: change a value below, rebuild, watch the readout, and adjust
/// until the sign locks on. [entries] carries the "how to tune" note for each
/// so the panel can tell you which direction to move it.
library;

/// One tunable, described well enough to tune it from the debug panel alone.
class TuningEntry {
  /// The Dart identifier, so it can be found with a text search.
  final String name;

  /// The current value, already formatted for display.
  final String value;

  /// What the number means.
  final String meaning;

  /// Which way to move it, and what that costs.
  final String tuning;

  /// Which recogniser consumes it, as a heading in the panel.
  final String group;

  const TuningEntry({
    required this.group,
    required this.name,
    required this.value,
    required this.meaning,
    required this.tuning,
  });
}

/// The thresholds, grouped by the recogniser that reads them.
abstract final class RecognitionTuning {
  // ---------------------------------------------------------------------------
  // Feedback engine - corrective hints
  // ---------------------------------------------------------------------------

  /// How far a finger's extension may differ from the reference, as a fraction
  /// of the reference value, before a fine-tuning hint is raised.
  ///
  /// Only applied once both the attempt and the reference are in the same broad
  /// category; see [curledMax] and [extendedMin] for the category test.
  static const double extensionTolerance = 0.30;

  /// Extension ratio at or below which a finger counts as folded into the palm.
  static const double curledMax = 1.7;

  /// Extension ratio at or above which a finger counts as straight.
  static const double extendedMin = 2.6;

  /// The same, for the gaps between the thumb and the fingertips, in
  /// palm-widths. These are absolute because they are already normalized.
  static const double gapTolerance = 0.22;

  /// How many corrections to return. A learner can act on one or two hints at a
  /// time; a list of six is noise.
  static const int maxCorrections = 2;

  /// Extension above this counts as a spread-out hand.
  static const double spreadThreshold = 0.25;

  // ---------------------------------------------------------------------------
  // Everyday motion signs
  // ---------------------------------------------------------------------------

  static const Duration motionWindow = Duration(milliseconds: 1200);

  /// Frames below which no pattern can be judged. At ~20fps this is ~250ms of
  /// visible movement.
  static const int motionMinSamples = 5;

  /// Minimum direction reversals on the dominant axis to read as a wave.
  ///
  /// Lower than the greeting recogniser's 3 because these are small repeated
  /// movements (a nod, a shake) rather than large waves.
  static const int minWaveReversals = 2;

  /// Minimum net travel, in normalized frame units, to read as intentional.
  static const double minNetDisplacement = 0.06;

  /// Maximum reversals tolerated for a single sweep. More than this means it was
  /// a wave, not a sweep.
  static const int maxSweepReversals = 1;

  /// A wave on one axis must be quiet on the other. Without this a circular
  /// motion satisfies the horizontal-wave rule as well, and whichever axis
  /// pattern happened to come first in the table would swallow the circular
  /// signs - a circle read as NO instead of PLEASE.
  static const int maxWaveCrossAxisReversals = 1;

  /// How much of the movement must be on one axis for a wave to count as
  /// vertical or horizontal rather than circular. 0..1.
  static const double axisDominance = 0.65;

  /// Ceiling on the confidence a motion match may claim.
  ///
  /// Deliberately low: these scores come from a handful of normalised wrist
  /// samples with no pose model, so they cannot support the high confidence a
  /// direct handshape comparison earns.
  static const double motionConfidenceMax = 0.35;

  // ---------------------------------------------------------------------------
  // Dwell / hold-to-confirm
  // ---------------------------------------------------------------------------

  /// The hold a learner gets by default.
  ///
  /// Not a fixed threshold: the learner picks this in Settings via
  /// `HoldToConfirm` (off / 2s / 3s / 4s / 5s), and 3s is the default. It is
  /// listed here because it is the one dwell number worth knowing when a sign
  /// "does not register" - the usual cause is that the hold is turned up, not
  /// that recognition is wrong. A test pins this to `HoldToConfirm.seconds3` so
  /// the two cannot drift apart.
  static const Duration defaultHold = Duration(seconds: 3);

  /// How long a dropout may break the hold before progress resets.
  static const Duration defaultDwellGrace = Duration(milliseconds: 300);

  // ---------------------------------------------------------------------------
  // Readout
  // ---------------------------------------------------------------------------

  /// The tunables, in the order the panel should show them.
  ///
  /// Read by the camera test screen so the numbers on screen are the numbers
  /// the recognisers use. Kept as data rather than a bespoke widget per
  /// constant so adding a tunable here is the only step needed to have it
  /// appear in the readout.
  static List<TuningEntry> get entries => [
        TuningEntry(
          group: 'Feedback (corrective hints)',
          name: 'extensionTolerance',
          value: '$extensionTolerance',
          meaning: 'Allowed drift from the reference finger '
              'extension before a hint is raised.',
          tuning: 'Raise if hints fire when the shape is right; lower to '
              'make hints more exact and more frequent.',
        ),
        TuningEntry(
          group: 'Feedback (corrective hints)',
          name: 'curledMax',
          value: '$curledMax',
          meaning: 'Extension ratio at or below which a finger counts as '
              'folded.',
          tuning: 'Raise to treat more bent fingers as folded.',
        ),
        TuningEntry(
          group: 'Feedback (corrective hints)',
          name: 'extendedMin',
          value: '$extendedMin',
          meaning: 'Extension ratio at or above which a finger counts as '
              'straight.',
          tuning: 'Lower to accept a straighter-than-expected finger.',
        ),
        TuningEntry(
          group: 'Feedback (corrective hints)',
          name: 'gapTolerance',
          value: '$gapTolerance',
          meaning: 'Allowed error in thumb-to-fingertip spacing, in '
              'palm-widths.',
          tuning: 'Raise to stop nitpicking about thumb placement.',
        ),
        TuningEntry(
          group: 'Feedback (corrective hints)',
          name: 'maxCorrections',
          value: '$maxCorrections',
          meaning: 'How many hints are listed at once.',
          tuning: 'Raise for more detail, lower to keep it actionable.',
        ),
        TuningEntry(
          group: 'Feedback (corrective hints)',
          name: 'spreadThreshold',
          value: '$spreadThreshold',
          meaning: 'Extension above which the hand counts as spread out.',
          tuning: 'Raise to flag more open hands as spread.',
        ),
        TuningEntry(
          group: 'Everyday motion signs',
          name: 'motionWindow',
          value: '${motionWindow.inMilliseconds} ms',
          meaning: 'How much recent movement a sign is judged over.',
          tuning: 'Raise for slow signers, lower to make signs snappier and '
              'easier to trigger by accident.',
        ),
        TuningEntry(
          group: 'Everyday motion signs',
          name: 'motionMinSamples',
          value: '$motionMinSamples',
          meaning: 'Frames needed before any sign can be judged.',
          tuning: 'Raise to stop one stray frame matching a sign.',
        ),
        TuningEntry(
          group: 'Everyday motion signs',
          name: 'minWaveReversals',
          value: '$minWaveReversals',
          meaning: 'Direction reversals that count as a wave.',
          tuning: 'Raise for a deliberate wave, lower to accept a small shake.',
        ),
        TuningEntry(
          group: 'Everyday motion signs',
          name: 'minNetDisplacement',
          value: '$minNetDisplacement',
          meaning: 'Minimum travel, in frame units, to count as movement.',
          tuning: 'Raise to ignore hand drift; lower to catch small nods.',
        ),
        TuningEntry(
          group: 'Everyday motion signs',
          name: 'maxSweepReversals',
          value: '$maxSweepReversals',
          meaning: 'Reversals allowed before a sweep reads as a wave.',
          tuning: 'Lower to demand a single clean sweep.',
        ),
        TuningEntry(
          group: 'Everyday motion signs',
          name: 'maxWaveCrossAxisReversals',
          value: '$maxWaveCrossAxisReversals',
          meaning: 'Movement tolerated on the axis a wave should ignore.',
          tuning: 'Lower if circles are being read as waves; this is what '
              'keeps PLEASE and NO apart.',
        ),
        TuningEntry(
          group: 'Everyday motion signs',
          name: 'axisDominance',
          value: '$axisDominance',
          meaning: 'Share of movement that must be on the dominant axis.',
          tuning: 'Raise to separate waves from circles more sharply.',
        ),
        TuningEntry(
          group: 'Everyday motion signs',
          name: 'motionConfidenceMax',
          value: '$motionConfidenceMax',
          meaning: 'Ceiling on confidence for a motion match.',
          tuning: 'Leave low. These scores come from normalised wrist '
              'samples with no pose model.',
        ),
        TuningEntry(
          group: 'Dwell (hold to confirm)',
          name: 'defaultHold',
          value: '${defaultHold.inSeconds} s',
          meaning: 'Default time a stable sign must be held. The learner '
              'changes this in Settings (off / 2 / 3 / 4 / 5 s).',
          tuning: 'If a sign will not register, check this first: a raised '
              'hold is the usual cause and it is not a recognition fault.',
        ),
        TuningEntry(
          group: 'Dwell (hold to confirm)',
          name: 'defaultDwellGrace',
          value: '${defaultDwellGrace.inMilliseconds} ms',
          meaning: 'Dropout tolerated before hold progress resets.',
          tuning: 'Raise to survive brief tracking loss; lower to require '
              'a steadier hold.',
        ),
      ];
}
