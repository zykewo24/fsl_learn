import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/ai/camera_control_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/sign_asset.dart';
import '../../../models/lesson_model.dart';
import '../../../models/lesson_sign_model.dart';
import '../../../providers/lesson_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/ai_session_state.dart';
import '../models/detection_result.dart';
import '../models/recognition_result.dart';
import '../providers/ai_session_provider.dart';
import '../recognition/emergency_motion_recognizer.dart';
import '../recognition/gesture_recognizer.dart';
import '../recognition/dwell_gate.dart';
import '../recognition/greeting_motion_recognizer.dart';
import '../services/detection_stream.dart';
import '../widgets/confetti_widget.dart';
import '../widgets/hand_overlay_painter.dart';
import '../widgets/sign_tutorial_card.dart';

/// Maps a sign's AI label to the canonical static handshape that the
/// gesture recognizer emits. Number words map to their digits; the
/// Colors and Animals intermediate lessons use static signs whose frozen
/// handshape is exactly a letters/digit (e.g. RED uses the X handshape),
/// so their word labels map to that handshape for camera verification.
const Map<String, String> _shapeLabelByWord = {
  'ZERO': '0',
  'ONE': '1',
  'TWO': '2',
  'THREE': '3',
  'FOUR': '4',
  'FIVE': '5',
  'SIX': '6',
  'SEVEN': '7',
  'EIGHT': '8',
  'NINE': '9',
  // Colors (static handshapes)
  'RED': 'X',
  'BLUE': 'B',
  'GREEN': 'G',
  'ORANGE': 'C',
  'PURPLE': 'P',
  'YELLOW': 'Y',
  // Animals (static handshapes)
  'BIRD': 'G',
  'CAT': 'F',
  'COW': 'Y',
  'FROG': 'V',
  'LION': 'C',
  'FISH': '5',
};

String _canonicalLabel(String raw) {
  final value = raw.trim().toUpperCase();
  return _shapeLabelByWord[value] ?? value;
}

class _OverlayFrame {
  final DetectionResult detection;
  final bool correct;
  const _OverlayFrame(this.detection, this.correct);
}

/// Per-frame snapshot of the recognizer output for the live debug readout.
class _RecognitionDebug {
  final int handCount;
  final int namesDetected;
  final String? label;
  final double confidence;
  final bool matched;
  final List<RecognizedCandidate> candidates;

  const _RecognitionDebug({
    required this.handCount,
    required this.namesDetected,
    required this.label,
    required this.confidence,
    required this.matched,
    required this.candidates,
  });
}

class AiPracticeScreen extends ConsumerStatefulWidget {
  final LessonModel lesson;
  final String? focusSignId;

  const AiPracticeScreen({
    super.key,
    required this.lesson,
    this.focusSignId,
  });

  @override
  ConsumerState<AiPracticeScreen> createState() =>
      _AiPracticeScreenState();
}

class _AiPracticeScreenState
    extends ConsumerState<AiPracticeScreen>
    with SingleTickerProviderStateMixin {
  final GestureRecognizer _gestureRecognizer = GestureRecognizer();

  final GreetingMotionRecognizer _greetingRecognizer =
      GreetingMotionRecognizer();

  final EmergencyMotionRecognizer _emergencyRecognizer =
      EmergencyMotionRecognizer();

  StreamSubscription<DetectionResult>? _subscription;

  List<LessonSignModel>? _signs;
  String? _lastMatchLabel;
  bool _loading = true;

  // When true, the camera permission dialog was declined so the native
  // preview is never mounted; an explanatory screen is shown instead.
  bool _permissionDenied = false;

  static const double _completionThreshold =
      GestureRecognizer.minConfidence;

  /// Confidence at or above which completing a sign is celebrated with a
  /// "Sign completed!" banner (85%+).
  static const double _celebrationThreshold = 0.85;

  bool _showSignComplete = false;
  Timer? _signCompleteTimer;

  /// Requires a recognised sign to be held steady before it is recorded as
  /// completed, so a sign that merely flashed past during a hand transition
  /// cannot mark itself mastered. Configured via Settings > Hold to confirm.
  final DwellGate _dwellGate = DwellGate(
    requiredHold: const Duration(seconds: 3),
  );

  /// Hold progress for the on-screen indicator, republished every detection
  /// frame by [_feedDwell].
  final ValueNotifier<double> _holdProgress = ValueNotifier(0);

  final Set<String> _knownCompletedIds = {};
  final ValueNotifier<_OverlayFrame?> _overlay = ValueNotifier(null);

  // Live per-frame recognition readout for debugging. Populated on every
  // detection event and rendered on top of the camera preview.
  final ValueNotifier<_RecognitionDebug?> _recognitionDebug =
      ValueNotifier(null);
  bool _showDebugReadout = false;

  // Per-sign focus mode: practice one sign at a time, advancing to the next
  // after "Nailed it!".
  bool _focusMode = false;
  int _focusedIndex = 0;

  // Collapsible progress grid showing every sign's status.
  bool _showProgressPanel = false;

  // Shown briefly after a focused sign is mastered ("Nailed it!").
  bool _showNailedIt = false;
  Timer? _nailedItTimer;

  // Completion animation.
  late final AnimationController _completionAnim;
  late final Animation<double> _completionScale;
  late final Animation<double> _completionFade;

  @override
  void initState() {
    super.initState();

    _completionAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _completionScale = CurvedAnimation(
      parent: _completionAnim,
      curve: Curves.elasticOut,
    );

    _completionFade = CurvedAnimation(
      parent: _completionAnim,
      curve: const Interval(0, 0.4, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // The AndroidView opens the camera as soon as it mounts, so the runtime
      // permission must be granted first. Without it CameraX binds to nothing
      // and the preview stays black.
      var cameraPermission = await Permission.camera.status;
      if (!cameraPermission.isGranted) {
        cameraPermission = await Permission.camera.request();
      }
      if (!cameraPermission.isGranted) {
        if (!mounted) return;
        ref
            .read(aiSessionProvider.notifier)
            .initializeSession(widget.lesson);
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }

      // Defer provider mutation out of initState (Riverpod forbids
      // modifying a provider during a widget lifecycle method).
      ref
          .read(aiSessionProvider.notifier)
          .initializeSession(widget.lesson);

      ref.read(aiSessionProvider.notifier).setCameraReady(true);

      // If lesson signs are already cached (second+ open), hydrate _signs
      // immediately so the feedback pill and target badge show the right
      // label from the first frame.
      if (_signs == null) {
        final cached = ref.read(lessonSignsProvider(widget.lesson.id));
        cached.whenData((signs) {
          if (_signs == null && mounted) {
            var s = signs;
            final focusSignId = widget.focusSignId;
            if (focusSignId != null) {
              final focused =
                  s.where((sign) => sign.id == focusSignId).toList();
              if (focused.isNotEmpty) s = focused;
            }
            _signs = s;
            ref
                .read(aiSessionProvider.notifier)
                .setTotalSignCount(s.length);
          }
        });
      }

      // Load persisted settings and apply the chosen camera lens before the
      // native preview mounts (it mounts as soon as _loading flips false).
      await ref.read(settingsProvider.notifier).read();
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      await CameraControlService.setLensFacing(settings.cameraLens);
      _dwellGate.setRequiredHold(settings.holdToConfirm.duration);

      // Keep the gate in step if the user changes the setting without leaving
      // practice. setRequiredHold drops any hold in progress, which is the
      // right behaviour: partial progress measured against a different
      // duration would be meaningless.
      ref.listen(settingsProvider.select((s) => s.holdToConfirm), (_, next) {
        _dwellGate.setRequiredHold(next.duration);
      });

      // The native camera_preview platform view owns the camera and the
      // hand-landmarker, so there is nothing else to await here. Clear
      // loading so the Stack (and the AndroidView) can mount and start
      // detecting.
      setState(() {
        _loading = false;
      });

      // Subscribe to detection events unconditionally (mirrors the native
      // camera test screen) so the hand landmarker's output is captured even
      // before the lesson signs have finished loading.
      _startDetection();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _signCompleteTimer?.cancel();
    _nailedItTimer?.cancel();
    _overlay.dispose();
    _holdProgress.dispose();
    _recognitionDebug.dispose();
    _completionAnim.dispose();
    // Drop the previous lesson's session state so the next screen (or the
    // next practice session) never reads a stale `completed` snapshot.
    ref.invalidate(aiSessionProvider);
    super.dispose();
  }

  /// Re-mounts the native camera view after an error by toggling the
  /// loading state that gates the [AndroidView] in the widget tree. Also
  /// re-requests camera access when permission was the blocker.
  Future<void> _retry() async {
    if (_permissionDenied) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }
    }

    setState(() {
      _permissionDenied = false;
      _loading = true;
    });

    ref.read(aiSessionProvider.notifier).setError(null);
    ref.read(aiSessionProvider.notifier).setCameraReady(false);

    // Let the frame commit so the AndroidView is unmounted before the
    // loading flag flips back and remounts a fresh view.
    await Future<void>.delayed(Duration.zero);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    ref.read(aiSessionProvider.notifier).setCameraReady(true);
  }

  List<LessonSignModel> get _activeSigns {
    final all = _signs ?? const <LessonSignModel>[];
    if (all.isEmpty) return const [];
    if (!_focusMode) return all;
    return [all[_focusedIndex.clamp(0, all.length - 1)]];
  }

  LessonSignModel? get _currentTarget {
    final all = _signs;
    if (all == null || all.isEmpty) return null;
    if (_focusMode) return all[_focusedIndex.clamp(0, all.length - 1)];
    return all.length == 1 ? all.first : null;
  }

  void _startDetection() {
    _subscription?.cancel();

    _subscription = DetectionStream.stream.listen(
      _onDetection,
      onError: (Object error) {
        debugPrint('Detection stream error: $error');
      },
    );
  }

  void _onDetection(DetectionResult result) {
    if (!mounted) return;

    final controller = ref.read(aiSessionProvider.notifier);
    final recognition = _gestureRecognizer.recognize(result);
    final greeting = _greetingRecognizer.feed(result);
    final emergency = _emergencyRecognizer.feed(result);

    controller.setDetecting(result.handCount > 0);

    final motionLabel = greeting ?? emergency;

    _recognitionDebug.value = _RecognitionDebug(
      handCount: result.handCount,
      namesDetected: result.landmarks.length,
      label: motionLabel ?? recognition.label,
      confidence:
          motionLabel != null ? 1.0 : recognition.confidence,
      matched: recognition.matched || motionLabel != null,
      candidates: recognition.candidates,
    );

    final signs = _activeSigns;

    // Resolve which active sign (if any) matches. Statically-posed signs
    // (letters/numbers) match via the static recognizer; greeting signs
    // (open-hand, motion-only) and emergency signs match via their motion
    // recognizers.
    String? matchedLabel;
    double matchConfidence = recognition.confidence;
    bool staticallyMatched = recognition.matched;

    if (signs.isNotEmpty) {
      for (final sign in signs) {
        final canonical = _canonicalLabel(sign.aiLabel);
        if (GreetingMotionRecognizer.isGreetingLabel(canonical)) {
          if (greeting != null && canonical == greeting) {
            matchedLabel = greeting;
            matchConfidence = 1.0;
            staticallyMatched = true;
            break;
          }
        } else if (EmergencyMotionRecognizer.isEmergencyLabel(canonical)) {
          if (emergency != null && canonical == emergency) {
            matchedLabel = emergency;
            matchConfidence = 1.0;
            staticallyMatched = true;
            break;
          }
        } else if (recognition.matched &&
            (canonical == recognition.label ||
                GestureRecognizer
                    .familyOf(canonical)
                    .contains(recognition.label!))) {
          matchedLabel = recognition.label;
          break;
        }
      }
    }

    final isCorrect = staticallyMatched && matchedLabel != null;

    _overlay.value = result.handCount > 0
        ? _OverlayFrame(result, isCorrect)
        : null;

    // Streak tracking.
    if (result.handCount > 0) {
      if (isCorrect) {
        controller.incrementStreak();
      } else {
        controller.resetStreak();
      }
    }

    if (matchedLabel == null) {
      _lastMatchLabel = null;
      _feedDwell(null);
      return;
    }

    final label = matchedLabel;

    controller.updatePrediction(
      prediction: label,
      confidence: matchConfidence,
    );

    if (signs.isEmpty) {
      _lastMatchLabel = null;
      _feedDwell(null);
      return;
    }

    if (matchConfidence < _completionThreshold) {
      _lastMatchLabel = null;
      _feedDwell(null);
      return;
    }

    LessonSignModel? matchedSign;

    for (final sign in signs) {
      final canonical = _canonicalLabel(sign.aiLabel);
      if (canonical == label ||
          GestureRecognizer.familyOf(canonical).contains(label)) {
        matchedSign = sign;
        break;
      }
    }

    if (matchedSign == null) {
      _lastMatchLabel = null;
      _feedDwell(null);
      return;
    }

    // Two-frame debounce, as before. This is a noise filter over the
    // ~20fps detection stream, not a hold - the dwell below is what makes a
    // sign count as completed.
    if (_lastMatchLabel != label) {
      _lastMatchLabel = label;
      _feedDwell(null);
      return;
    }

    final alreadyCompleted = ref
            .read(aiSessionProvider)
            ?.completedSignIds
            .contains(matchedSign.id) ??
        false;

    if (alreadyCompleted) {
      _lastMatchLabel = null;
      _feedDwell(null);
      return;
    }

    // The match is stable and confident, so start (or continue) the hold. The
    // commit below only runs on the frame the hold completes.
    final update = _feedDwell(matchedSign.id);

    if (!update.justCompleted) return;

    if (!_knownCompletedIds.contains(matchedSign.id)) {
      _knownCompletedIds.add(matchedSign.id);
      unawaited(_persistCompletion(matchedSign, matchConfidence));
    }

    controller.markSignCompleted(matchedSign.id);

    if (matchConfidence >= _celebrationThreshold) {
      _celebrateSignComplete();
    }

    _playCompletionFeedback();

    _onFocusedSignMastered(matchedSign);
  }

  /// Advances the dwell gate for this frame and republishes its progress for
  /// the on-screen hold indicator.
  ///
  /// Passing a null [signId] is what makes the hold pause: it is called from
  /// every path where the match is lost, so the hold cannot quietly accumulate
  /// while the learner is mid-transition.
  DwellUpdate _feedDwell(String? signId) {
    final update = _dwellGate.feed(signId: signId);
    _holdProgress.value = signId == null ? 0.0 : update.progress;
    return update;
  }

  /// Persists a sign completion to Supabase, then refreshes the derived
  /// progress providers. Failures are surfaced to the user instead of
  /// dying as unhandled async errors.
  Future<void> _persistCompletion(
    LessonSignModel sign,
    double confidence,
  ) async {
    try {
      await ref
          .read(lessonServiceProvider)
          .completeSign(signId: sign.id, score: confidence);

      if (!mounted) return;

      ref.invalidate(progressSnapshotProvider);
      ref.invalidate(lessonProgressProvider(widget.lesson.id));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save your progress: $error'),
        ),
      );
    }
  }

  /// In focus mode, after the current sign is mastered, briefly show a
  /// "Nailed it!" banner. If auto-advance is enabled, move on to the next
  /// sign automatically; otherwise the user advances via the arrow buttons.
  void _onFocusedSignMastered(LessonSignModel mastered) {
    if (!_focusMode) return;

    final all = _signs;
    if (all == null || all.isEmpty) return;

    final hasNext = _focusedIndex < all.length - 1;
    final thisIsLast = _focusedIndex == all.length - 1;

    _nailedItTimer?.cancel();
    setState(() {
      _showNailedIt = true;
    });

    // Respect the user's auto-advance preference.
    final autoAdvance = ref.read(settingsProvider).autoAdvance;

    if (!autoAdvance) {
      // Keep the "Nailed it!" banner up so the user can review the mastered
      // sign; no timer to auto-advance. Banner dismissed on next navigation.
      return;
    }

    _nailedItTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() {
        _showNailedIt = false;
        if (hasNext) {
          _focusedIndex += 1;
          _lastMatchLabel = null;
        } else if (thisIsLast) {
          // All signs in focus mode mastered: celebrate completion.
          final session = ref.read(aiSessionProvider);
          final controller = ref.read(aiSessionProvider.notifier);
          if (session != null && session.allSignsCompleted) {
            controller.completeLesson();
          }
        }
      });
    });
  }

  /// Applies haptic and/or sound feedback on a sign completion, gated by the
  /// user's settings.
  Future<void> _playCompletionFeedback() async {
    final settings = ref.read(settingsProvider);
    if (settings.hapticFeedback) {
      await HapticFeedback.mediumImpact();
    }
    if (settings.soundEffects) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Shows a short "Sign completed!" banner when the user nails a sign at
  /// 85%+ confidence, then auto-hides.
  void _celebrateSignComplete() {
    _signCompleteTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _showSignComplete = true;
    });

    _signCompleteTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _showSignComplete = false;
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Focus mode bar + progress strip
  // ---------------------------------------------------------------------------

  void _setFocusedIndex(int index) {
    final all = _signs;
    if (all == null || all.isEmpty) return;
    final clamped = index.clamp(0, all.length - 1);
    setState(() {
      _focusedIndex = clamped;
      _lastMatchLabel = null;
      _showNailedIt = false;
    });
    _greetingRecognizer.reset();
    _emergencyRecognizer.reset();
  }

  /// Compact controls for focus mode (one-sign-at-a-time), the progress
  /// strip toggle, and the debug readout toggle. Always visible at the bottom
  /// of the screen above the feedback pill.
  Widget _buildModeBar(AiSessionState session) {
    final all = _signs ?? const <LessonSignModel>[];
    final total = all.length;
    final hasMultiple = total > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress strip toggle
            _ModeChip(
              icon: Icons.grid_view,
              label: 'Progress',
              active: _showProgressPanel,
              onTap: () => setState(() {
                _showProgressPanel = !_showProgressPanel;
              }),
            ),
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 18,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 6),
            // Debug readout toggle
            _ModeChip(
              icon: Icons.insights,
              label: 'Debug',
              active: _showDebugReadout,
              onTap: () => setState(() {
                _showDebugReadout = !_showDebugReadout;
              }),
            ),
            if (hasMultiple) ...[
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 18,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 6),
              // Focus prev
              _ModeChip(
                icon: Icons.chevron_left,
                label: null,
                active: false,
                onTap: _focusMode
                    ? () => _setFocusedIndex(_focusedIndex - 1)
                    : null,
              ),
              // Focus mode toggle + position indicator
              _ModeChip(
                icon: Icons.track_changes,
                label: hasMultiple
                    ? (_focusMode
                        ? '${_focusedIndex + 1}/$total'
                        : 'Free')
                    : 'Focus',
                active: _focusMode,
                onTap: hasMultiple
                    ? () => setState(() {
                          _focusMode = !_focusMode;
                          _lastMatchLabel = null;
                        })
                    : null,
              ),
              // Focus next
              _ModeChip(
                icon: Icons.chevron_right,
                label: null,
                active: false,
                onTap: _focusMode
                    ? () => _setFocusedIndex(_focusedIndex + 1)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Horizontal strip of every sign showing its status: done (filled check),
  /// current focus (highlighted ring), or remaining (dimmed). Tap to jump in
  /// focus mode. Replaces the mode bar when the progress panel is open.
  Widget _buildProgressStrip(AiSessionState session) {
    final all = _signs ?? const <LessonSignModel>[];
    if (all.isEmpty) return const SizedBox.shrink();

    final completed = session.completedSignIds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: all.length + 1, // +1 for close button
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == all.length) {
                return GestureDetector(
                  onTap: () => setState(() {
                    _showProgressPanel = false;
                  }),
                  child: Container(
                    width: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white70),
                  ),
                );
              }
              final sign = all[index];
              final done = completed.contains(sign.id);
              final isCurrent = _focusMode && index == _focusedIndex;
              final label = _canonicalLabel(sign.aiLabel);

              return GestureDetector(
                onTap: _focusMode
                    ? () => _setFocusedIndex(index)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFF16A34A)
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFFF59E0B)
                          : Colors.white.withValues(alpha: 0.2),
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Full-screen "Nailed it!" banner shown briefly after mastering the
  /// focused sign in focus mode.
  Widget _buildNailedItBanner() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 44),
                    SizedBox(height: 6),
                    Text(
                      'Nailed it!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Floating "Sign completed!" pill shown when a sign is matched at 85%+.
  Widget _buildSignCompleteBanner() {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 70, 16, 0),
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Sign completed!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(aiSessionProvider);
    final signsAsync = ref.watch(lessonSignsProvider(widget.lesson.id));

    ref.listen(lessonSignsProvider(widget.lesson.id), (prev, next) {
      if (next.hasValue && _signs == null) {
        var signs = next.value!;

        final focusSignId = widget.focusSignId;

        if (focusSignId != null) {
          final focused =
              signs.where((sign) => sign.id == focusSignId).toList();
          if (focused.isNotEmpty) signs = focused;
        }

        _signs = signs;

        ref
            .read(aiSessionProvider.notifier)
            .setTotalSignCount(signs.length);
      }
    });

    ref.listen(lessonProgressProvider(widget.lesson.id), (prev, next) {
      if (next.hasValue) {
        final progress =
            next.value!['progress'] as Map<String, Map<String, dynamic>>?;

        if (progress == null) return;

        _knownCompletedIds
          ..clear()
          ..addAll(
            progress.entries
                .where((entry) => entry.value['completed'] == true)
                .map((entry) => entry.key),
          );

        ref
            .read(aiSessionProvider.notifier)
            .setInitialCompletedSignIds(_knownCompletedIds);
      }
    });

    ref.listen(aiSessionProvider, (prev, next) {
      if (next != null &&
          next.completed &&
          (prev == null || !prev.completed)) {
        _completionAnim.forward(from: 0);
      }
    });

    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final targetSign = _currentTarget;

    final tutorialTitle = targetSign?.title ?? session.lesson.title;
    final tutorialLabel =
        targetSign != null ? _canonicalLabel(targetSign.aiLabel) : null;
    final tutorialDescription =
        (targetSign?.description.isNotEmpty ?? false)
            ? targetSign!.description
            : session.lesson.description;

    return PopScope(
      canPop: !session.completed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && session.completed) {
          if (context.canPop()) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            tutorialTitle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: _permissionDenied
            ? _buildPermissionDenied()
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraLayer(),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child:
                            _buildTopOverlayCard(session, tutorialLabel, signsAsync: signsAsync),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _showProgressPanel
                              ? _buildProgressStrip(session)
                              : _buildModeBar(session),
                          _buildFeedbackPill(session, tutorialLabel),
                          SignTutorialCard(
                            title: tutorialTitle,
                            label: tutorialLabel,
                            description: tutorialDescription,
                            image: _resolveSignImage(targetSign),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildDebugReadout(),
                  if (_showSignComplete) _buildSignCompleteBanner(),
                  if (_showNailedIt) _buildNailedItBanner(),
                  if (session.completed)
                    Positioned.fill(
                      child: _buildCompletionOverlay(session),
                    ),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Camera layer
  // ---------------------------------------------------------------------------

  Widget _buildPermissionDenied() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off,
                size: 56,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera access required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Grant camera permission in Settings so the '
                'practice screen can detect your hand signs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open Settings'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraLayer() {    return Stack(
      fit: StackFit.expand,
      children: [
        // Native camera preview + hand-landmarker. This platform view runs
        // the MediaPipe detector and pushes results on the detection
        // EventChannel, which _onDetection already listens to.
        if (Platform.isAndroid)
          const AndroidView(
            viewType: 'camera_preview',
          )
        else
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Text(
                'Native camera preview is only supported on Android.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        // Hand-skeleton overlay aligned to the native preview.
        ValueListenableBuilder<_OverlayFrame?>(
          valueListenable: _overlay,
          builder: (context, frame, _) {
            return IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                painter: HandOverlayPainter(
                  detection: frame?.detection,
                  color: frame == null
                      ? AppColors.danger
                      : frame.correct
                          ? AppColors.success
                          : AppColors.danger,
                ),
              ),
            );
          },
        ),
        // Hold-to-confirm ring. Fills as the learner keeps the sign steady, so
        // the wait is legible rather than mysterious. Hidden when nothing is
        // being held.
        ValueListenableBuilder<double>(
          valueListenable: _holdProgress,
          builder: (context, progress, _) {
            if (progress <= 0) return const SizedBox.shrink();

            return IgnorePointer(
              ignoring: true,
              child: Align(
                alignment: const Alignment(0, 0.62),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.success),
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black87),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Debug readout
  // ---------------------------------------------------------------------------

  /// Live recognition debug panel (top candidates + confidence) shown on top
  /// of the camera preview. Non-interactive so it never blocks the camera.
  Widget _buildDebugReadout() {
    if (!_showDebugReadout) return const SizedBox.shrink();

    return ValueListenableBuilder<_RecognitionDebug?>(
      valueListenable: _recognitionDebug,
      builder: (context, debug, _) {
        if (debug == null) return const SizedBox.shrink();

        final bestLabel = debug.label ?? '--';
        final bestConf = debug.confidence;

        return IgnorePointer(
          ignoring: true,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 70, right: 8),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debug.matched
                            ? '$bestLabel ${(bestConf * 100).round()}%'
                            : 'NO MATCH',
                        style: TextStyle(
                          color: debug.matched
                              ? AppColors.success
                              : const Color(0xFFF87171),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...debug.candidates.take(3).map((c) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  c.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: c.confidence,
                                  minHeight: 3,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    c.confidence >=
                                            GestureRecognizer.minConfidence
                                        ? AppColors.success
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${(c.confidence * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Top overlay card (glassmorphism)
  // ---------------------------------------------------------------------------

  Widget _buildTopOverlayCard(
    AiSessionState session,
    String? targetLabel, {
    required AsyncValue<List<LessonSignModel>> signsAsync,
  }) {
    final total = session.totalSignCount;
    final completed = session.completedSignCount;
    final progressValue = total == 0 ? 0.0 : completed / total;
    final confidence = session.confidence;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: target badge + title + streak
              Row(
                children: [
                  if (targetLabel != null)
                    _TargetBadge(label: targetLabel),
                  if (targetLabel != null) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.lesson.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          total == 0
                              ? 'Loading signs...'
                              : '$completed / $total completed',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (session.streak > 0)
                    _StreakBadge(streak: session.streak),
                ],
              ),

              const SizedBox(height: 10),

              // Row 2: progress bar
              if (total > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4ADE80),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Row 3: confidence bar
              _ConfidenceBar(confidence: confidence),

              const SizedBox(height: 6),

              // Camera status dot
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: session.cameraReady
                        ? AppColors.success
                        : AppColors.subtitle,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    session.cameraReady ? 'Camera ready' : 'Starting camera...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              if (session.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  session.errorMessage!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: _retry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Retry',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (signsAsync.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  'Could not load signs',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    ref.invalidate(lessonSignsProvider(widget.lesson.id));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Feedback pill
  // ---------------------------------------------------------------------------

  Widget _buildFeedbackPill(
    AiSessionState session,
    String? targetLabel,
  ) {
    return ValueListenableBuilder<_OverlayFrame?>(
      valueListenable: _overlay,
      builder: (context, frame, _) {
        String message;
        Color color;
        IconData icon;
        bool pulse;

        if (frame == null) {
          message = 'Position your hand in the frame';
          color = Colors.white.withValues(alpha: 0.15);
          icon = Icons.back_hand;
          pulse = false;
        } else if (frame.correct) {
          final label = session.prediction ?? targetLabel ?? '';
          message = label.isEmpty
              ? 'Correct! Great signing'
              : "Correct: '$label'";
          color = AppColors.success;
          icon = Icons.check_circle;
          pulse = true;
        } else {
          final label = targetLabel ?? '';
          message = label.isEmpty
              ? 'Adjust your hand'
              : "Form the '$label' sign";
          color = AppColors.danger;
          icon = Icons.adjust;
          pulse = false;
        }

        return TweenAnimationBuilder<double>(
          key: ValueKey('${frame?.correct}-${frame != null}'),
          tween: Tween(begin: 1.0, end: pulse ? 1.08 : 1.0),
          duration: Duration(milliseconds: pulse ? 200 : 150),
          curve: Curves.easeOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: frame != null
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        message,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Completion overlay
  // ---------------------------------------------------------------------------

  Widget _buildCompletionOverlay(AiSessionState session) {
    return FadeTransition(
      opacity: _completionFade,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Stack(
          children: [
            // Confetti behind the card
            const Positioned.fill(child: ConfettiWidget()),

            Center(
              child: ScaleTransition(
                scale: _completionScale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _CompletionCard(session: session),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveSignImage(LessonSignModel? sign) {
    if (sign == null) return null;

    if (sign.imageUrl != null && sign.imageUrl!.isNotEmpty) {
      return sign.imageUrl;
    }

    return resolveSignAssetPath(sign.aiLabel);
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _TargetBadge extends StatelessWidget {
  final String label;
  const _TargetBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label.isEmpty ? '?' : label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final VoidCallback? onTap;
  const _ModeChip({
    required this.icon,
    this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final base = active
        ? const Color(0xFF3B82F6)
        : Colors.white.withValues(alpha: 0.1);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF3B82F6).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
            ),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  const _ConfidenceBar({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.signal_cellular_alt,
          size: 14,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: confidence),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _confidenceColor(value),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: confidence),
          duration: const Duration(milliseconds: 150),
          builder: (context, value, _) {
            return Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: _confidenceColor(value),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
      ],
    );
  }

  static Color _confidenceColor(double value) {
    if (value >= 0.8) return AppColors.success;
    if (value >= 0.5) return const Color(0xFFF59E0B);
    if (value >= 0.2) return const Color(0xFFF97316);
    return AppColors.subtitle;
  }
}

// Completion card

class _CompletionCard extends StatelessWidget {
  final AiSessionState session;
  const _CompletionCard({required this.session});

  int get _stars {
    final s = session.bestStreak;
    if (s >= 10) return 5;
    if (s >= 7) return 4;
    if (s >= 5) return 3;
    if (s >= 3) return 2;
    return 1;
  }

  String get _elapsed {
    final start = session.sessionStartedAt;
    if (start == null) return '0:00';
    final secs = DateTime.now().difference(start).inSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trophy icon with glow
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  const Color(0xFFF59E0B).withValues(alpha: 0.0),
                ],
              ),
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 52,
              color: Color(0xFFF59E0B),
            ),
          ),

          const SizedBox(height: 12),

          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < _stars ? Icons.star : Icons.star_border,
                  size: 28,
                  color: i < _stars
                      ? const Color(0xFFF59E0B)
                      : Colors.white.withValues(alpha: 0.25),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),

          Text(
            session.totalSignCount <= 1
                ? 'Sign Mastered!'
                : 'Lesson Complete!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            session.totalSignCount <= 1
                ? "You nailed the '${session.lesson.title}' sign."
                : 'You mastered all ${session.totalSignCount} signs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                icon: Icons.check_circle,
                value: '${session.completedSignCount}/${session.totalSignCount}',
                label: 'Signs',
              ),
              _StatItem(
                icon: Icons.local_fire_department,
                value: '${session.bestStreak}',
                label: 'Best streak',
              ),
              _StatItem(
                icon: Icons.timer_outlined,
                value: _elapsed,
                label: 'Time',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Buttons
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (context.canPop()) context.pop();
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.6)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}