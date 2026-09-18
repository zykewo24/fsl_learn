import 'package:flutter/services.dart';

class MediaPipeService {
  MediaPipeService._();

  static const MethodChannel _channel = MethodChannel(
    'com.signcorrect.fsl_learn/mediapipe',
  );

  static Future<void> initialize() async {
    await _channel.invokeMethod('initialize');
  }
}