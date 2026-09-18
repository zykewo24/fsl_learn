import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/lesson_model.dart';
import '../models/ai_session_state.dart';

class AiSessionController extends Notifier<AiSessionState?> {
  @override
  AiSessionState? build() {
    return null;
  }

  void initializeSession(LessonModel lesson) {
    state = AiSessionState(
      lesson: lesson,
      sessionStartedAt: DateTime.now(),
    );
  }

  void setCameraReady(bool value) {
    if (state == null) return;

    state = state!.copyWith(cameraReady: value);
  }

  void setDetecting(bool value) {
    if (state == null) return;

    if (state!.isDetecting == value) return;

    state = state!.copyWith(isDetecting: value);
  }

  void updatePrediction({
    required String? prediction,
    required double? confidence,
  }) {
    if (state == null) return;

    final labelChanged = state!.prediction != prediction;
    final resolvedConfidence = confidence ?? 0.0;

    final confidenceChanged =
        (resolvedConfidence - state!.confidence).abs() > 0.01;

    // Avoid useless rebuilds while holding the same sign.
    if (!labelChanged && !confidenceChanged) return;

    state = state!.copyWith(
      prediction: prediction,
      confidence: resolvedConfidence,
      attempts: labelChanged ? state!.attempts + 1 : state!.attempts,
    );
  }

  void incrementStreak() {
    if (state == null) return;

    final newStreak = state!.streak + 1;

    state = state!.copyWith(
      streak: newStreak,
      bestStreak: math.max(newStreak, state!.bestStreak),
    );
  }

  void resetStreak() {
    if (state == null) return;

    if (state!.streak == 0) return;

    state = state!.copyWith(streak: 0);
  }

  /// Seeds ids that were already completed in a previous session so the
  /// UI shows them as done without re-writing progress to the backend.
  void setInitialCompletedSignIds(Set<String> signIds) {
    if (state == null) return;

    final updated = {...state!.completedSignIds, ...signIds};

    state = state!.copyWith(completedSignIds: updated);
  }

  void setTotalSignCount(int count) {
    if (state == null) return;

    state = state!.copyWith(totalSignCount: count);
  }

  void markSignCompleted(String signId) {
    if (state == null) return;

    if (state!.completedSignIds.contains(signId)) return;

    final updated = {...state!.completedSignIds, signId};

    state = state!.copyWith(completedSignIds: updated);

    if (updated.length >= state!.totalSignCount) {
      state = state!.copyWith(completed: true);
    }
  }

  void completeLesson() {
    if (state == null) return;

    state = state!.copyWith(completed: true);
  }

  void setError(String? message) {
    if (state == null) return;

    state = state!.copyWith(errorMessage: message);
  }

  void resetSession() {
    if (state == null) return;

    state = AiSessionState(
      lesson: state!.lesson,
      sessionStartedAt: DateTime.now(),
    );
  }
}