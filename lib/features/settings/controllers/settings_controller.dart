import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_state.dart';

/// Loads and persists [SettingsState] to SharedPreferences.
class SettingsController extends Notifier<SettingsState> {
  static const _kHaptic = 'settings.hapticFeedback';
  static const _kSound = 'settings.soundEffects';
  static const _kAutoAdvance = 'settings.autoAdvance';
  static const _kCameraLens = 'settings.cameraLens';

  bool _loaded = false;
  SharedPreferences? _prefs;

  @override
  SettingsState build() {
    // Start with sensible defaults; prefs are loaded once in read().
    return const SettingsState();
  }

  /// Loads persisted settings from SharedPreferences and updates the state.
  /// Call once at app/dashboard startup. Idempotent: subsequent calls replay
  /// the already-loaded state instead of reloading (reloading on every
  /// rebuild would notify watchers in an infinite loop).
  Future<void> read() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;

      final haptic = prefs.getBool(_kHaptic) ?? true;
      final sound = prefs.getBool(_kSound) ?? true;
      final autoAdvance = prefs.getBool(_kAutoAdvance) ?? true;

      final lensRaw = prefs.getString(_kCameraLens) ?? 'front';
      final lens = lensRaw == 'back'
          ? CameraLens.back
          : CameraLens.front;

      state = SettingsState(
        hapticFeedback: haptic,
        soundEffects: sound,
        autoAdvance: autoAdvance,
        cameraLens: lens,
      );
    } catch (_) {
      _loaded = false;
      // Ignore load errors; keep defaults and allow a later retry.
    }
  }

  Future<SharedPreferences> _cachedPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> setHapticFeedback(bool value) async {
    state = state.copyWith(hapticFeedback: value);
    final prefs = await _cachedPrefs();
    await prefs.setBool(_kHaptic, value);
  }

  Future<void> setSoundEffects(bool value) async {
    state = state.copyWith(soundEffects: value);
    final prefs = await _cachedPrefs();
    await prefs.setBool(_kSound, value);
  }

  Future<void> setAutoAdvance(bool value) async {
    state = state.copyWith(autoAdvance: value);
    final prefs = await _cachedPrefs();
    await prefs.setBool(_kAutoAdvance, value);
  }

  Future<void> setCameraLens(CameraLens lens) async {
    state = state.copyWith(cameraLens: lens);
    final prefs = await _cachedPrefs();
    await prefs.setString(_kCameraLens, lens == CameraLens.back ? 'back' : 'front');
  }
}
