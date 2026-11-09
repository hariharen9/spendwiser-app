import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Dual concentric Hero gauge:
///  * outer dashed track = one tick per day of the month, lit for elapsed days
///  * inner coral ring = share of the monthly envelope already spent
class HeroGaugePainter extends CustomPainter {
  HeroGaugePainter({
    required this.progress,
    required this.dayCount,
    required this.currentDay,
    required this.trackColor,
    required this.accent,
    required this.coral,
    required this.isDark,
  });

  final double progress; // 0..100
  final int dayCount;
  final int currentDay;
  final Color trackColor;
  final Color accent;
  final Color coral;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 300;
    final outerRadius = 144 * scale;
    final tickLength = 10 * scale;
    final currentTickLength = 18 * scale;
    final innerRadius = 116 * scale;

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < dayCount; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / dayCount);
      final current = i == currentDay - 1;
      final elapsed = i < currentDay;
      final radiusEnd =
          outerRadius - (current ? currentTickLength : tickLength);
      final direction = Offset(math.cos(angle), math.sin(angle));
      tickPaint
        ..color = elapsed ? accent : trackColor
        ..strokeWidth = (current ? 4 : 3) * scale;
      canvas.drawLine(
        center + direction * outerRadius,
        center + direction * radiusEnd,
        tickPaint,
      );
    }

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..color = trackColor;
    canvas.drawCircle(center, innerRadius, track);

    final sweep = (progress.clamp(0, 100) / 100) * 2 * math.pi;
    if (sweep > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * scale
        ..strokeCap = StrokeCap.round
        ..color = coral;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        -math.pi / 2,
        sweep,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HeroGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.dayCount != dayCount ||
      oldDelegate.currentDay != currentDay ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.accent != accent ||
      oldDelegate.coral != coral ||
      oldDelegate.isDark != isDark;
}

class HeroGauge extends StatelessWidget {
  const HeroGauge({
    super.key,
    required this.progress,
    required this.dayCount,
    required this.currentDay,
    required this.child,
    this.size = 300,
  });

  final double progress;
  final int dayCount;
  final int currentDay;
  final Widget child;
  final double size;

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
              painter: HeroGaugePainter(
                progress: progress,
                dayCount: dayCount,
                currentDay: currentDay,
                trackColor: c.c2,
                accent: c.ac,
                coral: c.co,
                isDark: c.dark,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
