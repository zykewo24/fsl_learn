import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/routes.dart';
import '../models/detection_result.dart';
import '../models/finger_state.dart';
import '../models/gesture_debug_data.dart';
import '../models/recognition_result.dart';
import '../recognition/gesture_recognizer.dart';
import '../recognition/tuning.dart';
import '../services/a_calibration_tracker.dart';
import '../services/detection_stream.dart';
import '../services/finger_state_detector.dart';
import '../widgets/hand_landmark_painter.dart';

class MediaPipeTestScreen extends StatefulWidget {
  const MediaPipeTestScreen({super.key});

  @override
  State<MediaPipeTestScreen> createState() =>
      _MediaPipeTestScreenState();
}

class _MediaPipeTestScreenState
    extends State<MediaPipeTestScreen> {
  final GestureRecognizer _gestureRecognizer =
      GestureRecognizer();

  final ACalibrationTracker _aCalibration =
      ACalibrationTracker();

  StreamSubscription<DetectionResult>? _subscription;

  DetectionResult? _lastDetection;
  FingerState? _fingerState;
  RecognitionResult? _recognitionResult;
  GestureDebugData? _gestureDebugData;

  bool _calibratingA = false;

  bool _cameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (!mounted) return;
      setState(() {
        _cameraPermissionGranted = status.isGranted;
      });
    });

    _subscription = DetectionStream.stream.listen(
      (result) {
        if (!mounted) return;

        final fingerState =
            FingerStateDetector.detect(result);

        final recognition =
            _gestureRecognizer.recognize(result);

        final debugData =
            _gestureRecognizer.lastDebugData;

        if (_calibratingA && debugData != null) {
          _aCalibration.addSample(debugData);
        }

        setState(() {
          _lastDetection = result;
          _fingerState = fingerState;
          _recognitionResult = recognition;
          _gestureDebugData = debugData;
        });
      },
      onError: (error) {
        debugPrint(
          'Detection stream error: $error',
        );
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _toggleACalibration() {
    setState(() {
      _calibratingA = !_calibratingA;

      if (_calibratingA) {
        _aCalibration.clear();
      }
    });
  }

  void _clearACalibration() {
    setState(() {
      _aCalibration.clear();
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          title: const Text('Native Camera Test'),
        ),
body: Platform.isAndroid
            ? !_cameraPermissionGranted
                ? _buildPermissionDenied()
                : Stack(
                    children: [
                      const Positioned.fill(
                        child: AndroidView(
                          viewType: 'camera_preview',
                        ),
                      ),

                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: CustomPaint(
                            painter: HandLandmarkPainter(
                              detection: _lastDetection,
                            ),
                          ),
                        ),
                      ),

                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: SafeArea(
                      child: SingleChildScrollView(
                        child: _buildDebugPanel(),
                      ),
                    ),
                  ),
                ],
              )
            : const Center(
                child: Text(
                  'Native camera preview is only supported on Android.',
                ),
              ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off,
              size: 56,
              color: Colors.black38,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera access required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow camera permission to run the native test.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final status = await Permission.camera.request();
                if (!mounted) return;
                setState(() {
                  _cameraPermissionGranted = status.isGranted;
                });
              },
              icon: const Icon(Icons.camera),
              label: const Text('Allow Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Card(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildDetectionSection(),
            const SizedBox(height: 12),
            _buildFingerSection(),
            const SizedBox(height: 12),
            _buildRecognitionSection(),
            const SizedBox(height: 12),
            _buildCalibrationSection(),
            const SizedBox(height: 12),
            _buildTuningSection(),
          ],
        ),
      ),
    );
  }

  /// The live values of every recognition threshold, with what each one does.
  ///
  /// Collapsed by default: it is long, and the numbers above it are what you
  /// actually watch while holding a sign. Open it when something will not
  /// recognise and you need to know what it is being compared against.
  ///
  /// The values are read from [RecognitionTuning] at build time, which is the
  /// same place the recognisers read them from, so this cannot report a number
  /// the app is not using.
  Widget _buildTuningSection() {
    final entries = RecognitionTuning.entries;

    // Preserve declaration order while grouping, so the section order matches
    // the order in tuning.dart.
    final groups = <String, List<TuningEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.group, () => <TuningEntry>[]).add(e);
    }

    return Card(
      color: const Color(0xFF111827),
      child: Theme(
        // The parent card is already dark; keep the expansion tile from
        // repainting its header in a light theme colour.
        data: ThemeData.dark(),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: const Text(
            'Tuning constants',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '${entries.length} thresholds in use',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          children: [
            const Text(
              'These were set against synthetic hands, not a camera. '
              'If a sign will not lock on, adjust the one below that governs '
              'it, rebuild, and watch the live readout above.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            for (final group in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  group.key,
                  style: const TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final e in group.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              e.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            e.value,
                            style: const TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        e.meaning,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        e.tuning,
                        style: const TextStyle(
                          color: Color(0xFFFCD34D),
                          fontSize: 12,
                          height: 1.3,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionSection() {
    if (_lastDetection == null) {
      return const Text(
        'Waiting for hand...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      );
    }

    return _section(
      title: 'Detection',
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _text(
            'Hands: ${_lastDetection!.handCount}',
          ),
          _text(
            'Hand: '
            '${_lastDetection!.handedness ?? 'Unknown'}',
          ),
          _text(
            'Confidence: '
            '${_lastDetection!.confidence.toStringAsFixed(2)}',
          ),
          _text(
            'Landmarks: '
            '${_lastDetection!.landmarks.length}',
          ),
          _text(
            'Inference: '
            '${_lastDetection!.inferenceTimeMs} ms',
          ),
        ],
      ),
    );
  }

  Widget _buildFingerSection() {
    return _section(
      title: 'Finger State',
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _fingerText(
            'Thumb',
            _fingerState?.thumbOpen,
          ),
          _fingerText(
            'Index',
            _fingerState?.indexOpen,
          ),
          _fingerText(
            'Middle',
            _fingerState?.middleOpen,
          ),
          _fingerText(
            'Ring',
            _fingerState?.ringOpen,
          ),
          _fingerText(
            'Pinky',
            _fingerState?.pinkyOpen,
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionSection() {
    final recognition = _recognitionResult;

    return _section(
      title: 'Recognition',
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _text(
            recognition?.matched == true
                ? 'Detected: ${recognition!.label}'
                : 'Detected: No match',
          ),
          if (recognition?.matched == true)
            _text(
              'Recognition confidence: '
              '${(recognition!.confidence * 100).toStringAsFixed(0)}%',
            ),
        ],
      ),
    );
  }

  Widget _buildCalibrationSection() {
    final debug = _gestureDebugData;

    return _section(
      title: 'Letter A Calibration',
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleACalibration,
                  child: Text(
                    _calibratingA
                        ? 'Stop A Calibration'
                        : 'Start A Calibration',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear calibration',
                onPressed:
                    _aCalibration.sampleCount == 0
                        ? null
                        : _clearACalibration,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _text(
            'Status: '
            '${_calibratingA ? 'Recording' : 'Not recording'}',
          ),

          _text(
            'Samples: ${_aCalibration.sampleCount}',
          ),

          if (debug != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Current frame',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            _fingerText(
              'Thumb',
              debug.thumbOpen,
            ),
            _fingerText(
              'Index',
              debug.indexOpen,
            ),
            _fingerText(
              'Middle',
              debug.middleOpen,
            ),
            _fingerText(
              'Ring',
              debug.ringOpen,
            ),
            _fingerText(
              'Pinky',
              debug.pinkyOpen,
            ),
            const SizedBox(height: 8),
            _text(
              'Thumb → Index: '
              '${debug.thumbToIndex.toStringAsFixed(3)}',
            ),
            _text(
              'Thumb → Pinky: '
              '${debug.thumbToPinky.toStringAsFixed(3)}',
            ),
            _text(
              'Palm Width: '
              '${debug.palmWidth.toStringAsFixed(3)}',
            ),
            _text(
              'A Match: '
              '${debug.matchesA ? 'YES' : 'NO'}',
            ),
            _text(
              'A Confidence: '
              '${(debug.confidence * 100).toStringAsFixed(0)}%',
            ),
          ],

          if (_aCalibration.sampleCount > 0) ...[
            const SizedBox(height: 12),
            const Text(
              'Recorded range',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            _text('Thumb → Index'),
            _text(
              '  Min: '
              '${_aCalibration.minThumbToIndex.toStringAsFixed(3)}',
            ),
            _text(
              '  Max: '
              '${_aCalibration.maxThumbToIndex.toStringAsFixed(3)}',
            ),
            _text(
              '  Avg: '
              '${_aCalibration.averageThumbToIndex.toStringAsFixed(3)}',
            ),

            const SizedBox(height: 6),

            _text('Thumb → Pinky'),
            _text(
              '  Min: '
              '${_aCalibration.minThumbToPinky.toStringAsFixed(3)}',
            ),
            _text(
              '  Max: '
              '${_aCalibration.maxThumbToPinky.toStringAsFixed(3)}',
            ),
            _text(
              '  Avg: '
              '${_aCalibration.averageThumbToPinky.toStringAsFixed(3)}',
            ),

            const SizedBox(height: 6),

            _text(
              'Match rate: '
              '${(_aCalibration.matchRate * 100).toStringAsFixed(1)}%',
            ),
          ],
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _text(String text) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _fingerText(
    String name,
    bool? isOpen,
  ) {
    final value =
        isOpen == true ? 'Open' : 'Closed';

    return _text(
      '$name: $value',
    );
  }
}