import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated confetti celebration that plays for [duration] when triggered.
///
/// Usage: wrap in an `AnimatedBuilder` or use `ConfettiWidget` which
/// auto-plays on state creation.
class ConfettiPainter extends CustomPainter {
  final Object? particles;
  final double progress;

  ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final particles = this.particles;
    if (particles is! List<_Particle>) return;

    for (final p in particles) {
      final t = (progress * p.speed + p.seed) % 1.0;

      // Fall from top, drift sideways, fade out.
      final y = -20 + (size.height + 80) * t;
      final x = p.startX * size.width +
          math.sin(t * math.pi * p.driftFreq) * p.driftAmp;

      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation * t * math.pi * 2);

      if (p.shape == _Shape.rect) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      } else if (p.shape == _Shape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Star
        _drawStar(canvas, p.size / 2, paint);
      }

      canvas.restore();
    }
  }

  static void _drawStar(Canvas canvas, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final outer = Offset(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );
      final innerAngle = angle + 2 * math.pi / 5;
      final inner = Offset(
        radius * 0.4 * math.cos(innerAngle),
        radius * 0.4 * math.sin(innerAngle),
      );

      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

enum _Shape { rect, circle, star }

class _Particle {
  final double startX;
  final double seed;
  final double speed;
  final double driftFreq;
  final double driftAmp;
  final double rotation;
  final double size;
  final Color color;
  final _Shape shape;

  const _Particle({
    required this.startX,
    required this.seed,
    required this.speed,
    required this.driftFreq,
    required this.driftAmp,
    required this.rotation,
    required this.size,
    required this.color,
    required this.shape,
  });
}

/// Generates a fixed set of confetti particles with random properties.
List<_Particle> _generateParticles(int count, {int seed = 42}) {
  final rng = math.Random(seed);

  const palette = [
    Color(0xFFF59E0B), // amber
    Color(0xFF10B981), // emerald
    Color(0xFF3B82F6), // blue
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFF06B6D4), // cyan
  ];

  const shapes = _Shape.values;

  return List.generate(count, (_) {
    return _Particle(
      startX: rng.nextDouble(),
      seed: rng.nextDouble(),
      speed: 0.4 + rng.nextDouble() * 0.6,
      driftFreq: 1 + rng.nextDouble() * 3,
      driftAmp: 20 + rng.nextDouble() * 40,
      rotation: rng.nextDouble(),
      size: 4 + rng.nextDouble() * 8,
      color: palette[rng.nextInt(palette.length)],
      shape: shapes[rng.nextInt(shapes.length)],
    );
  });
}

/// Animated widget that shows confetti for [duration] then stops.
class ConfettiWidget extends StatefulWidget {
  final Duration duration;
  final int particleCount;

  const ConfettiWidget({
    super.key,
    this.duration = const Duration(seconds: 3),
    this.particleCount = 60,
  });

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    _particles = _generateParticles(widget.particleCount);

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
          child: const SizedBox.expand(),
        );
      },
    );
  }
}