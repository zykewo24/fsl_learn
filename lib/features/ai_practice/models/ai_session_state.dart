import '../../../models/lesson_model.dart';

class AiSessionState {
  final LessonModel lesson;

  final bool cameraReady;
  final bool isDetecting;

  final String? prediction;
  final double confidence;

  final int attempts;
  final bool completed;

  final Set<String> completedSignIds;
  final int totalSignCount;

  final String? errorMessage;

  /// Consecutive correct detections of any target sign.
  final int streak;

  /// Longest streak achieved during this session.
  final int bestStreak;

  /// When this practice session started (for elapsed-time display).
  final DateTime? sessionStartedAt;

  const AiSessionState({
    required this.lesson,
    this.cameraReady = false,
    this.isDetecting = false,
    this.prediction,
    this.confidence = 0,
    this.attempts = 0,
    this.completed = false,
    this.completedSignIds = const {},
    this.totalSignCount = 0,
    this.errorMessage,
    this.streak = 0,
    this.bestStreak = 0,
    this.sessionStartedAt,
  });

  int get completedSignCount => completedSignIds.length;

  bool get allSignsCompleted =>
      totalSignCount > 0 &&
      completedSignIds.length >= totalSignCount;

  static const _unset = Object();

  AiSessionState copyWith({
    LessonModel? lesson,
    bool? cameraReady,
    bool? isDetecting,
    Object? prediction = _unset,
    double? confidence,
    int? attempts,
    bool? completed,
    Set<String>? completedSignIds,
    int? totalSignCount,
    Object? errorMessage = _unset,
    int? streak,
    int? bestStreak,
    Object? sessionStartedAt = _unset,
  }) {
    return AiSessionState(
      lesson: lesson ?? this.lesson,
      cameraReady: cameraReady ?? this.cameraReady,
      isDetecting: isDetecting ?? this.isDetecting,
      prediction: identical(prediction, _unset)
          ? this.prediction
          : prediction as String?,
      confidence: confidence ?? this.confidence,
      attempts: attempts ?? this.attempts,
      completed: completed ?? this.completed,
      completedSignIds: completedSignIds ?? this.completedSignIds,
      totalSignCount: totalSignCount ?? this.totalSignCount,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      sessionStartedAt: identical(sessionStartedAt, _unset)
          ? this.sessionStartedAt
          : sessionStartedAt as DateTime?,
    );
  }
}