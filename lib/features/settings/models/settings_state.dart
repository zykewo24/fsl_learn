/// Camera lens preference. Mirrors Android CameraSelector lens facing.
enum CameraLens { front, back }

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

  const SettingsState({
    this.hapticFeedback = true,
    this.soundEffects = true,
    this.autoAdvance = true,
    this.cameraLens = CameraLens.front,
  });

  SettingsState copyWith({
    bool? hapticFeedback,
    bool? soundEffects,
    bool? autoAdvance,
    CameraLens? cameraLens,
  }) {
    return SettingsState(
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      soundEffects: soundEffects ?? this.soundEffects,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      cameraLens: cameraLens ?? this.cameraLens,
    );
  }
}
