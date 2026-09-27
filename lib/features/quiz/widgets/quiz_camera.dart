import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/ai/camera_control_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../ai_practice/models/detection_result.dart';
import '../../ai_practice/recognition/dwell_gate.dart';
import '../../ai_practice/recognition/emergency_motion_recognizer.dart';
import '../../ai_practice/recognition/everyday_sign_recognizer.dart';
import '../../ai_practice/recognition/gesture_recognizer.dart';
import '../../ai_practice/recognition/greeting_motion_recognizer.dart';
import '../../ai_practice/recognition/sign_label.dart';
import '../../ai_practice/services/detection_stream.dart';
import '../../ai_practice/widgets/hand_overlay_painter.dart';
import '../../settings/providers/settings_provider.dart';

/// The camera surface used by the "Sign it" quiz mode.
///
/// This deliberately runs the same recogniser stack as the practice screen -
/// the static recogniser, the greeting, emergency and everyday motion
/// recognisers, and the hold-to-confirm gate - rather than a simplified copy.
/// A quiz that graded against different criteria than practice would certify
/// signs the learner was never actually taught to produce correctly.
///
/// It reports the label it currently believes the learner is making, plus how
/// far through the hold they are, and leaves all scoring and progression to
/// the [QuizController].
class QuizCamera extends ConsumerStatefulWidget {
  /// Invoked once per detection frame with the recognised label, or null when
  /// nothing is recognised.
  final void Function(String? label) onRecognised;

  const QuizCamera({super.key, required this.onRecognised});

  @override
  ConsumerState<QuizCamera> createState() => _QuizCameraState();
}

class _QuizCameraState extends ConsumerState<QuizCamera> {
  final GestureRecognizer _gestures = GestureRecognizer();
  final GreetingMotionRecognizer _greeting = GreetingMotionRecognizer();
  final EmergencyMotionRecognizer _emergency = EmergencyMotionRecognizer();
  final EverydaySignRecognizer _everyday = EverydaySignRecognizer();
  final DwellGate _dwell =
      DwellGate(requiredHold: const Duration(seconds: 2));

  StreamSubscription<DetectionResult>? _subscription;
  final ValueNotifier<DetectionResult?> _detection = ValueNotifier(null);
  final ValueNotifier<double> _holdProgress = ValueNotifier(0);
  final ValueNotifier<String?> _label = ValueNotifier(null);

  bool _loading = true;
  bool _permissionDenied = false;

  /// The last label reported upward, so a steady hand does not fire
  /// `onRecognised` on every one of ~20 frames a second.
  String? _lastReported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;

    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
      }
      return;
    }

    await ref.read(settingsProvider.notifier).read();
    if (!mounted) return;
    await CameraControlService.setLensFacing(
      ref.read(settingsProvider).cameraLens,
    );
    _dwell.setRequiredHold(
      ref.read(settingsProvider).holdToConfirm.duration,
    );

    if (mounted) setState(() => _loading = false);
    _startDetection();
  }

  void _startDetection() {
    _subscription?.cancel();
    _subscription = DetectionStream.stream.listen(
      _onDetection,
      onError: (_) {},
    );
  }

  void _onDetection(DetectionResult result) {
    if (!mounted) return;

    _detection.value = result.landmarks.isEmpty ? null : result;

    final staticResult = _gestures.recognize(result);
    final greeting = _greeting.feed(result);
    final emergency = _emergency.feed(result);
    final everyday = _everyday.feed(
      result,
      staticLabel: staticResult.label,
      staticConfidence: staticResult.confidence,
    );

    // A motion sign is reported verbatim; a static sign is reported by its
    // canonical label so a colour sign is matched by the letter it uses.
    String? label;
    if (greeting != null || emergency != null || everyday != null) {
      label = greeting ?? emergency ?? everyday;
    } else if (staticResult.matched && staticResult.label != null) {
      label = staticResult.label;
    }

    _label.value = label;

    // A sign has to be held before it counts, exactly as in practice, so a sign
    // that merely flashes past cannot pass a quiz question.
    final hold = _dwell.feed(signId: label);
    _holdProgress.value = label == null ? 0 : hold.progress;

    if (hold.justCompleted && _lastReported != label) {
      _lastReported = label;
      widget.onRecognised(label);
    }
    if (label == null) {
      _lastReported = null;
      _dwell.reset();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _detection.dispose();
    _holdProgress.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Camera access is needed for this quiz mode',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: openAppSettings,
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (Platform.isAndroid)
              const AndroidView(viewType: 'camera_preview')
            else
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Text(
                    'Camera quizzes are only supported on Android.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),

            ValueListenableBuilder<DetectionResult?>(
              valueListenable: _detection,
              builder: (context, detection, _) {
                return IgnorePointer(
                  child: CustomPaint(
                    painter: HandOverlayPainter(
                      detection: detection,
                      color: detection == null
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                  ),
                );
              },
            ),

            // Hold-to-confirm ring, matching the practice screen.
            ValueListenableBuilder<double>(
              valueListenable: _holdProgress,
              builder: (context, progress, _) {
                if (progress <= 0) return const SizedBox.shrink();
                return IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 5,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.success,
                              ),
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
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

            // What the app currently thinks the learner is signing.
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ValueListenableBuilder<String?>(
                valueListenable: _label,
                builder: (context, label, _) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label == null
                            ? 'Show a sign'
                            : 'Seeing: ${canonicalSignLabel(label)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
