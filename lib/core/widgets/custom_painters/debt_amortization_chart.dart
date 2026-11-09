import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class DebtSeries {
  const DebtSeries({
    required this.history,
    required this.color,
    this.dashed = false,
    this.strokeWidth = 2,
  });

  final List<double> history;
  final Color color;
  final bool dashed;
  final double strokeWidth;
}

class DebtAmortizationChart extends StatelessWidget {
  const DebtAmortizationChart({
    super.key,
    required this.currentHistory,
    required this.acceleratedHistory,
    this.height = 110,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  });

  final List<double> currentHistory;
  final List<double> acceleratedHistory;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DebtChartPainter(
          series: [
            DebtSeries(
              history: currentHistory,
              color: c.mu,
              dashed: true,
              strokeWidth: 2,
            ),
            DebtSeries(
              history: acceleratedHistory,
              color: c.ac,
              strokeWidth: 2.6,
            ),
          ],
          padding: padding,
        ),
      ),
    );
  }
}

class PayoffCurveChart extends StatelessWidget {
  const PayoffCurveChart({
    super.key,
    required this.series,
    this.height = 120,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  });

  final List<DebtSeries> series;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DebtChartPainter(series: series, padding: padding),
      ),
    );
  }
}

class _DebtChartPainter extends CustomPainter {
  _DebtChartPainter({required this.series, required this.padding});

  final List<DebtSeries> series;
  final EdgeInsetsGeometry padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final insets = padding.resolve(TextDirection.ltr);
    final rect = Rect.fromLTWH(
      insets.left,
      insets.top,
      size.width - insets.horizontal,
      size.height - insets.vertical,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    var maxMonths = 1;
    for (final s in series) {
      maxMonths = math.max(maxMonths, s.history.length - 1);
    }
    var maxValue = 0.0;
    for (final s in series) {
      for (final value in s.history) {
        maxValue = math.max(maxValue, value);
      }
    }
    if (maxValue <= 0) maxValue = 1;

    for (final s in series) {
      if (s.history.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < s.history.length; i++) {
        final x = rect.left + (i / maxMonths) * rect.width;
        final y = rect.bottom - (s.history[i] / maxValue) * rect.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = s.color;
      if (s.dashed) {
        _drawDashedPath(canvas, path, paint, dash: 4, gap: 4);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DebtChartPainter oldDelegate) => true;
}

/// Small inline sparkline used inside the cash-flow forecast and net worth.
class AreaLineChart extends StatelessWidget {
  const AreaLineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 80,
    this.fill = true,
    this.strokeWidth = 2.4,
    this.budgetValue,
    this.budgetLabel,
    this.forecastFrom,
  });

  final List<double> values;
  final Color color;
  final double height;
  final bool fill;
  final double strokeWidth;
  final double? budgetValue;
  final String? budgetLabel;
  final int? forecastFrom;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: AreaLinePainter(
          values: values,
          color: color,
          fill: fill,
          strokeWidth: strokeWidth,
          budgetValue: budgetValue,
          budgetLabel: budgetLabel,
          budgetColor: c.co,
          labelColor: c.mu,
          forecastFrom: forecastFrom,
        ),
      ),
    );
  }
}

class AreaLinePainter extends CustomPainter {
  AreaLinePainter({
    required this.values,
    required this.color,
    required this.fill,
    required this.strokeWidth,
    required this.budgetColor,
    required this.labelColor,
    this.budgetValue,
    this.budgetLabel,
    this.forecastFrom,
  });

  final List<double> values;
  final Color color;
  final bool fill;
  final double strokeWidth;
  final double? budgetValue;
  final String? budgetLabel;
  final Color budgetColor;
  final Color labelColor;
  final int? forecastFrom;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const topInset = 10.0;
    final rect = Rect.fromLTWH(
      2,
      topInset,
      size.width - 4,
      size.height - topInset - 2,
    );
    var min = values.reduce(math.min);
    var max = values.reduce(math.max);
    if (budgetValue != null) max = math.max(max, budgetValue!);
    if (max - min < 1) {
      max += 1;
      min -= 1;
    }
    final range = max - min;

    double xFor(int i) => rect.left + (i / (values.length - 1)) * rect.width;
    double yFor(double v) => rect.bottom - ((v - min) / range) * rect.height;

    if (budgetValue != null) {
      final y = yFor(budgetValue!);
      final paint = Paint()
        ..color = budgetColor.withValues(alpha: 0.9)
        ..strokeWidth = 1;
      for (double x = rect.left; x < rect.right; x += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, rect.right), y),
          paint,
        );
      }
      if (budgetLabel != null) {
        final text = TextPainter(
          text: TextSpan(
            text: budgetLabel,
            style: TextStyle(color: budgetColor, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(rect.left, y - text.height - 2));
      }
    }

    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final offset = Offset(xFor(i), yFor(values[i]));
      if (i == 0) {
        line.moveTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
      }
    }

    if (fill) {
      final area = Path.from(line)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
      );
      canvas.drawPath(
        area,
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    if (forecastFrom != null && forecastFrom! < values.length - 1) {
      final path = Path();
      for (var i = forecastFrom!; i < values.length; i++) {
        final offset = Offset(xFor(i), yFor(values[i]));
        if (i == forecastFrom) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.65);
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          canvas.drawPath(
            metric.extractPath(distance, math.min(distance + 4, metric.length)),
            paint,
          );
          distance += 9;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant AreaLinePainter oldDelegate) => true;
}
