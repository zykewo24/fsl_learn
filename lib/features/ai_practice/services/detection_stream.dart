import 'dart:async';

import 'package:flutter/services.dart';

import '../models/detection_result.dart';

/// Receives live hand detection events from Android.
///
/// This is the only class in Flutter that knows about the native
/// EventChannel.
class DetectionStream {
  DetectionStream._();

  static const EventChannel _channel = EventChannel(
    'com.signcorrect.fsl_learn/detections',
  );

  static Stream<DetectionResult> get stream {
    return _channel
        .receiveBroadcastStream()
        .map((event) {
          final map = event as Map<dynamic, dynamic>;
          return DetectionResult.fromMap(map);
        });
  }
}