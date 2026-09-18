import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import 'hand_overlay_painter.dart';

/// Camera preview with an optional hand-skeleton overlay drawn on top.
///
/// Both the preview and the overlay share the same `FittedBox` transform so
/// the [HandOverlayPainter] stays aligned with the camera feed.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  final DetectionResult? detection;

  /// Colour of the hand skeleton. When null the skeleton is not drawn.
  /// Green signals a correct placement, red a wrong one.
  final Color? skeletonColor;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    this.detection,
    this.skeletonColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final detection = this.detection;
    final skeletonColor = this.skeletonColor;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              if (detection != null && skeletonColor != null)
                CustomPaint(
                  painter: HandOverlayPainter(
                    detection: detection,
                    color: skeletonColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}