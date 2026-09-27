/// Camera lens preference. Mirrors Android CameraSelector lens facing.
enum CameraLens { front, back }

/// How long a sign must be held before it counts as completed.
///
/// Off restores the original behaviour, where a sign completed as soon as two
/// consecutive frames agreed (~50-100ms at the ~20fps detection rate). That is
/// fast but means a sign that flashed past during a hand transition could mark
/// itself mastered.
enum HoldToConfirm {
  off(Duration.zero),
  seconds2(Duration(seconds: 2)),
  seconds3(Duration(seconds: 3)),
  seconds4(Duration(seconds: 4)),
  seconds5(Duration(seconds: 5));

  const HoldToConfirm(this.duration);

  final Duration duration;

  String get label => switch (this) {
        HoldToConfirm.off => 'Off',
        HoldToConfirm.seconds2 => '2 seconds',
        HoldToConfirm.seconds3 => '3 seconds',
        HoldToConfirm.seconds4 => '4 seconds',
        HoldToConfirm.seconds5 => '5 seconds',
      };

  /// Stored form. Off is the empty string so a zero-valued preference never
  /// has to be distinguished from "never set".
  String get storageValue => duration.inMilliseconds == 0 ? '' : name;

  static HoldToConfirm fromStorage(String? raw) {
    for (final option in HoldToConfirm.values) {
      if (option.name == raw) return option;
    }
    // Anything unrecognised falls back to a middle default rather than Off, so
    // a corrupted preference cannot silently disable the hold.
    return HoldToConfirm.seconds3;
  }
}

/// User-adjustable app settings. Persisted via SharedPreferences.
class SettingsState {
  /// Vibrate on a successful sign completion during practice.
  final bool hapticFeedback;

  /// Play a sound on a successful sign completion during practice.
  final bool soundEffects;

  /// In focus mode, automatically advance to the next sign after mastering
  /// the current one instead of waiting for the user.
  final bool autoAdvance;

  /// Camera lens used by the native practice camera preview.
  final CameraLens cameraLens;

  /// How long a recognised sign must be held steady before it is recorded as
  /// completed. See [HoldToConfirm].
  final HoldToConfirm holdToConfirm;

  /// Show specific, per-finger corrections while practising, e.g. "straighten
  /// your index finger", instead of only a pass/fail indication.
  final bool correctionFeedback;

  const SettingsState({
    this.hapticFeedback = true,
    this.soundEffects = true,
    this.autoAdvance = true,
    this.cameraLens = CameraLens.front,
    this.holdToConfirm = HoldToConfirm.seconds3,
    this.correctionFeedback = true,
  });

  SettingsState copyWith({
    bool? hapticFeedback,
    bool? soundEffects,
    bool? autoAdvance,
    CameraLens? cameraLens,
    HoldToConfirm? holdToConfirm,
    bool? correctionFeedback,
  }) {
    return SettingsState(
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      soundEffects: soundEffects ?? this.soundEffects,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      cameraLens: cameraLens ?? this.cameraLens,
      holdToConfirm: holdToConfirm ?? this.holdToConfirm,
      correctionFeedback: correctionFeedback ?? this.correctionFeedback,
    );
  }
}
