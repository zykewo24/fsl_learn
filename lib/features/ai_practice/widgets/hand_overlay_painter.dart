import 'package:flutter/material.dart';

import '../models/detection_result.dart';

/// Draws the MediaPipe hand skeleton over the camera feed with a layered
/// neon-glow effect and brighter fingertip highlights so the skeleton
/// is clearly visible against any background.
///
/// - [color] green for correct placement, red for wrong.
///
/// The painter expects landmark coordinates in the same (0..1) normalised
/// space used by [CameraPreviewWidget] so it must be wrapped in the same
/// `FittedBox` transform to stay aligned with the visible preview.
class HandOverlayPainter extends CustomPainter {
  final DetectionResult? detection;
  final Color color;

  const HandOverlayPainter({
    required this.detection,
    required this.color,
  });

  /// MediaPipe hand landmark connections.
  static const List<List<int>> connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  /// Tip landmarks (index 8, middle 12, ring 16, pinky 20, thumb 4).
  static const Set<int> fingertips = {4, 8, 12, 16, 20};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final detection = this.detection;
    if (detection == null) return;

    final landmarks = detection.landmarks;
    if (landmarks.length != 21) return;

    final points = <Offset>[
      for (final lm in landmarks)
        Offset(lm.x * size.width, lm.y * size.height),
    ];

    // --- Multi-layer glow ---------------------------------------------------

    // Wide soft aura.
    final auraPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Mid glow.
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Core stroke.
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final c in connections) {
      final a = points[c[0]];
      final b = points[c[1]];

      canvas.drawLine(a, b, auraPaint);
      canvas.drawLine(a, b, glowPaint);
      canvas.drawLine(a, b, linePaint);
    }

    // --- Joint dots ---------------------------------------------------------

    final jointGlowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final jointPaint = Paint()..color = color;

    final corePaint = Paint()..color = Colors.white;

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final isTip = fingertips.contains(i);
      final r = isTip ? 6.0 : 3.5;

      if (isTip) {
        canvas.drawCircle(p, r + 4, jointGlowPaint);
      }
      canvas.drawCircle(p, r, jointPaint);
      canvas.drawCircle(p, r * 0.45, corePaint);
    }

    // --- Fingertip halo ring ------------------------------------------------

    final haloPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final tip in fingertips) {
      canvas.drawCircle(points[tip], 10, haloPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HandOverlayPainter oldDelegate) {
    return oldDelegate.detection != detection || oldDelegate.color != color;
  }
}