import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class RingGaugePainter extends CustomPainter {
  RingGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.color,
    required this.strokeWidth,
    this.startAngle = -math.pi / 2,
    this.rounded = true,
  });

  final double progress; // 0..100
  final Color trackColor;
  final Color color;
  final double strokeWidth;
  final double startAngle;
  final bool rounded;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final sweep = (progress.clamp(0, 100) / 100) * 2 * math.pi;
    if (sweep <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = rounded ? StrokeCap.round : StrokeCap.butt
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant RingGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Circular progress ring used by the health score, card utilisation and goals.
class HealthScoreGauge extends StatelessWidget {
  const HealthScoreGauge({
    super.key,
    required this.score,
    this.size = 170,
    this.strokeWidth = 9,
    this.color,
    this.label,
    this.showScore = true,
    this.child,
  });

  final int score;
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? label;
  final bool showScore;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: RingGaugePainter(
                progress: score.toDouble(),
                trackColor: c.c2,
                color: color ?? c.ac,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
          if (child != null)
            child!
          else if (showScore)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: AppTypography.serif(
                    size: size * 0.28,
                    color: c.tx,
                    height: 1,
                  ),
                ),
                if (label != null)
                  Text(
                    label!,
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
