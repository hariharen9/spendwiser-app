import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class DonutSegment {
  const DonutSegment({required this.value, required this.color});
  final double value;
  final Color color;
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    required this.size,
    this.strokeWidth = 20,
    this.child,
  });

  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;
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
              painter: DonutPainter(
                segments: segments,
                trackColor: c.c2,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.segments,
    required this.trackColor,
    required this.strokeWidth,
  });

  final List<DonutSegment> segments;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = segments.fold<double>(
      0,
      (sum, s) => sum + math.max(0, s.value),
    );
    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = trackColor,
      );
      return;
    }

    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = (math.max(0, segment.value) / total) * 2 * math.pi;
      if (sweep <= 0) continue;
      final gap = 0.018;
      canvas.drawArc(
        rect,
        start + gap,
        math.max(0, sweep - gap * 2),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..color = segment.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) => true;
}

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.colors,
    this.height = 100,
    this.highlightIndex,
    this.highlightColor,
    this.budgetValue,
    this.budgetColor,
    this.barWidth = 28,
  });

  final List<double> values;
  final List<String> labels;
  final List<Color>? colors;
  final double height;
  final int? highlightIndex;
  final Color? highlightColor;
  final double? budgetValue;
  final Color? budgetColor;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: SimpleBarPainter(
          values: values,
          labels: labels,
          colors: colors,
          accent: c.ac,
          coral: c.co,
          track: c.c2,
          labelColor: c.mu,
          highlightIndex: highlightIndex,
          highlightColor: highlightColor,
          budgetValue: budgetValue,
          budgetColor: budgetColor ?? c.co,
          barWidth: barWidth,
        ),
      ),
    );
  }
}

class SimpleBarPainter extends CustomPainter {
  SimpleBarPainter({
    required this.values,
    required this.labels,
    required this.accent,
    required this.coral,
    required this.track,
    required this.labelColor,
    required this.budgetColor,
    required this.barWidth,
    this.colors,
    this.highlightIndex,
    this.highlightColor,
    this.budgetValue,
  });

  final List<double> values;
  final List<String> labels;
  final List<Color>? colors;
  final Color accent;
  final Color coral;
  final Color track;
  final Color labelColor;
  final Color budgetColor;
  final int? highlightIndex;
  final Color? highlightColor;
  final double? budgetValue;
  final double barWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelHeight = 16.0;
    final chartHeight = size.height - labelHeight;
    var maxValue = values.reduce(math.max);
    if (budgetValue != null) maxValue = math.max(maxValue, budgetValue!);
    if (maxValue <= 0) maxValue = 1;

    final slot = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final barHeight = math.max(1.0, value / maxValue * (chartHeight - 8));
      final x = i * slot + (slot - barWidth) / 2;
      final y = chartHeight - barHeight;
      final isHighlight = highlightIndex == i;
      final color = colors != null && i < colors!.length
          ? colors![i]
          : (isHighlight ? (highlightColor ?? coral) : accent);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(6),
        ),
        Paint()
          ..color = color.withValues(alpha: isHighlight ? 1 : 0.58)
          ..style = PaintingStyle.fill,
      );
      if (labels.length > i) {
        final text = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(color: labelColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(i * slot + slot / 2 - text.width / 2, size.height - 12),
        );
      }
    }

    if (budgetValue != null) {
      final y = chartHeight - budgetValue! / maxValue * (chartHeight - 8);
      final paint = Paint()
        ..color = budgetColor
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SimpleBarPainter oldDelegate) => true;
}

class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.income,
    required this.expense,
    required this.labels,
    this.height = 170,
    this.budgetValue,
  });

  final List<double> income;
  final List<double> expense;
  final List<String> labels;
  final double height;
  final double? budgetValue;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _GroupedBarPainter(
          income: income,
          expense: expense,
          labels: labels,
          accent: c.ac,
          coral: c.co,
          labelColor: c.mu,
          budgetValue: budgetValue,
          budgetColor: c.co,
        ),
      ),
    );
  }
}

class _GroupedBarPainter extends CustomPainter {
  _GroupedBarPainter({
    required this.income,
    required this.expense,
    required this.labels,
    required this.accent,
    required this.coral,
    required this.labelColor,
    required this.budgetValue,
    required this.budgetColor,
  });

  final List<double> income;
  final List<double> expense;
  final List<String> labels;
  final Color accent;
  final Color coral;
  final Color labelColor;
  final double? budgetValue;
  final Color budgetColor;

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 20.0;
    final chartHeight = size.height - labelHeight;
    var maxValue = 1.0;
    for (final v in [...income, ...expense]) {
      maxValue = math.max(maxValue, v);
    }
    if (budgetValue != null) maxValue = math.max(maxValue, budgetValue!);
    final slot = size.width / math.max(1, income.length);

    for (var i = 0; i < income.length; i++) {
      final groupX = i * slot + 6;
      final barWidth = math.min(16.0, (slot - 14) / 2);
      final incomeHeight = income[i] / maxValue * (chartHeight - 6);
      final expenseHeight = expense[i] / maxValue * (chartHeight - 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            groupX,
            chartHeight - incomeHeight,
            barWidth,
            incomeHeight,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = accent,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            groupX + barWidth + 3,
            chartHeight - expenseHeight,
            barWidth,
            expenseHeight,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = coral,
      );
      if (labels.length > i) {
        final text = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(color: labelColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(i * slot + slot / 2 - text.width / 2, size.height - 14),
        );
      }
    }

    if (budgetValue != null) {
      final y = chartHeight - budgetValue! / maxValue * (chartHeight - 6);
      final paint = Paint()
        ..color = budgetColor
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GroupedBarPainter oldDelegate) => true;
}
