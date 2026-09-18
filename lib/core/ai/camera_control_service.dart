import 'package:flutter/services.dart';

import '../../features/settings/models/settings_state.dart';

/// Communicates with the native camera preview to set the preferred lens
/// facing. The preference is stored natively so the next time the practice
/// screen mounts a preview it uses the chosen camera.
class CameraControlService {
  CameraControlService._();

  static const MethodChannel _channel = MethodChannel(
    'com.signcorrect.fsl_learn/camera',
  );

  /// Sets the preferred lens facing for the native camera preview.
  static Future<void> setLensFacing(CameraLens lens) async {
    final facing =
        lens == CameraLens.back ? 1 : 0; // 0=front, 1=back
    try {
      await _channel.invokeMethod<void>('setLensFacing', facing);
    } on PlatformException {
      // Native side not ready (e.g. non-Android); ignore.
    }
  }
}
