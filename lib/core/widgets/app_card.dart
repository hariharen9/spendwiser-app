import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// 22px rounded surface with subtle border, glass gradient and soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 10),
    this.radius = 22,
    this.onTap,
    this.onLongPress,
    this.color,
    this.gradient,
    this.border,
    this.dashed = false,
    this.shadow = true,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final bool dashed;
  final bool shadow;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final borderRadius = BorderRadius.circular(radius);
    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? c.c1) : null,
      gradient: gradient ?? (c.dark ? c.cardGradient : null),
      borderRadius: borderRadius,
      border: border ?? Border.all(color: c.ln, width: 1),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: c.shadow,
                blurRadius: 36,
                spreadRadius: -22,
                offset: const Offset(0, 16),
              ),
            ]
          : null,
    );

    Widget content = Container(
      padding: padding,
      decoration: decoration,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: child,
    );

    if (dashed) {
      content = CustomPaint(
        painter: DashedRoundedBorderPainter(
          color: c.mu.withValues(alpha: 0.55),
          radius: radius,
          dash: 5,
          gap: 5,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? (c.dark ? c.c1 : c.c1),
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      );
    }

    if (onTap != null || onLongPress != null) {
      content = Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      );
    }

    return Padding(padding: margin, child: content);
  }
}

class DashedRoundedBorderPainter extends CustomPainter {
  DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
    this.dash = 4,
    this.gap = 4,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

/// The 28px radial-glow card used by the Home net-worth hero.
class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(top: 16, bottom: 8),
    this.glowStrength = 1,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final glow = color ?? c.ac;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: c.c1,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.ln),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 36,
            spreadRadius: -22,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1, -1),
                  radius: 1.35,
                  colors: [
                    glow.withValues(
                      alpha: (c.dark ? 0.15 : 0.12) * glowStrength,
                    ),
                    glow.withValues(alpha: 0.01 * glowStrength),
                  ],
                  stops: const [0, 0.72],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
