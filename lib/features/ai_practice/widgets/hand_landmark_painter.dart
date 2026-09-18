import 'package:flutter/material.dart';

import '../models/detection_result.dart';

class HandLandmarkPainter extends CustomPainter {
  final DetectionResult? detection;

  const HandLandmarkPainter({
    required this.detection,
  });

  /// MediaPipe hand landmark connections.
  static const List<List<int>> connections = [
    // Thumb
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],

    // Index finger
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],

    // Middle finger
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],

    // Ring finger
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],

    // Pinky
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],

    // Palm
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (detection == null) return;

    final landmarks = detection!.landmarks;

    if (landmarks.length != 21) return;

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    // Draw skeleton lines first.
    for (final connection in connections) {
      final start = landmarks[connection[0]];
      final end = landmarks[connection[1]];

      canvas.drawLine(
        Offset(
          start.x * size.width,
          start.y * size.height,
        ),
        Offset(
          end.x * size.width,
          end.y * size.height,
        ),
        linePaint,
      );
    }

    // Draw landmark points on top.
    for (final landmark in landmarks) {
      canvas.drawCircle(
        Offset(
          landmark.x * size.width,
          landmark.y * size.height,
        ),
        6,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HandLandmarkPainter oldDelegate) {
    return oldDelegate.detection != detection;
  }
}