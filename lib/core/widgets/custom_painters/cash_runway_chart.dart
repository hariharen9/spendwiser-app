import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Glowing balance curve used by the Home cash-runway hero.
class CashRunwayChart extends StatelessWidget {
  const CashRunwayChart({
    super.key,
    required this.values,
    required this.lowestIndex,
    required this.color,
    this.billIndices = const <int>{},
    this.paydayIndex,
    this.height = 132,
  });

  final List<double> values;
  final int lowestIndex;
  final Color color;
  final Set<int> billIndices;
  final int? paydayIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _CashRunwayPainter(
          values: values,
          lowestIndex: lowestIndex,
          color: color,
          billIndices: billIndices,
          paydayIndex: paydayIndex,
          gridColor: c.ln,
          mutedColor: c.mu,
        ),
      ),
    );
  }
}

class _CashRunwayPainter extends CustomPainter {
  const _CashRunwayPainter({
    required this.values,
    required this.lowestIndex,
    required this.color,
    required this.billIndices,
    required this.paydayIndex,
    required this.gridColor,
    required this.mutedColor,
  });

  final List<double> values;
  final int lowestIndex;
  final Color color;
  final Set<int> billIndices;
  final int? paydayIndex;
  final Color gridColor;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));

    final minValue = math.min(0.0, values.reduce((a, b) => a < b ? a : b));
    final maxValue = math.max(0.0, values.reduce((a, b) => a > b ? a : b));
    final span = math.max(1.0, maxValue - minValue);
    const verticalPad = 12.0;
    final chartTop = verticalPad;
    final chartBottom = size.height - verticalPad;
    final chartHeight = chartBottom - chartTop;

    double xFor(int index) => values.length == 1
        ? size.width / 2
        : index / (values.length - 1) * size.width;

    double yFor(double value) =>
        chartTop + (maxValue - value) / span * chartHeight;

    // Zero / safety line.
    if (minValue <= 0 && maxValue >= 0) {
      final zeroY = yFor(0);
      _drawDashedLine(
        canvas,
        Offset(0, zeroY),
        Offset(size.width, zeroY),
        Paint()
          ..color = gridColor
          ..strokeWidth = 1,
      );
    }

    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(xFor(i), yFor(values[i]));
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }

    final area = Path.from(line)
      ..lineTo(xFor(values.length - 1), chartBottom)
      ..lineTo(xFor(0), chartBottom)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(rect),
    );

    // Soft glow under the line.
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = color.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Bill markers.
    for (final index in billIndices) {
      if (index < 0 || index >= values.length) continue;
      final x = xFor(index);
      final y = yFor(values[index]);
      canvas.drawLine(
        Offset(x, chartBottom),
        Offset(x, y),
        Paint()
          ..color = mutedColor.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(x, y),
        2.4,
        Paint()..color = mutedColor.withValues(alpha: 0.85),
      );
    }

    // Payday marker.
    final payday = paydayIndex;
    if (payday != null && payday >= 0 && payday < values.length) {
      final x = xFor(payday);
      final y = yFor(values[payday]);
      _drawDashedLine(
        canvas,
        Offset(x, chartTop),
        Offset(x, chartBottom),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()..color = const Color(0xFF09090B),
      );
    }

    // Lowest point.
    if (lowestIndex >= 0 && lowestIndex < values.length) {
      final center = Offset(xFor(lowestIndex), yFor(values[lowestIndex]));
      canvas.drawCircle(
        center,
        6.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color,
      );
      canvas.drawCircle(center, 3.2, Paint()..color = color);
    }

    canvas.restore();
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    final length = (end - start).distance;
    if (length == 0) return;
    final direction = (end - start) / length;
    var distance = 0.0;
    while (distance < length) {
      final segmentEnd = math.min(distance + dash, length);
      canvas.drawLine(
        start + direction * distance,
        start + direction * segmentEnd,
        paint,
      );
      distance += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _CashRunwayPainter oldDelegate) => true;
}
