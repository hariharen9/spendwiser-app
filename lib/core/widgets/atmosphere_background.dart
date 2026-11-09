import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The immersive, slowly drifting colour field behind every screen.
///
/// Mirrors `.ph:before`: four radial gradients (module tint, coral, cyan,
/// purple) animated with the 16s drift keyframe, plus an 8% noise overlay.
class AtmosphereBackground extends StatefulWidget {
  const AtmosphereBackground({
    super.key,
    required this.tint,
    required this.child,
  });

  final Color tint;
  final Widget child;

  @override
  State<AtmosphereBackground> createState() => _AtmosphereBackgroundState();
}

class _AtmosphereBackgroundState extends State<AtmosphereBackground>
    with TickerProviderStateMixin {
  late final AnimationController _drift;
  late final AnimationController _color;
  late Color _fromTint;
  late Color _toTint;

  @override
  void initState() {
    super.initState();
    _fromTint = widget.tint;
    _toTint = widget.tint;
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
    _color = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant AtmosphereBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tint != widget.tint) {
      _fromTint = _currentTint;
      _toTint = widget.tint;
      _color.forward(from: 0);
    }
  }

  Color get _currentTint =>
      Color.lerp(_fromTint, _toTint, Curves.easeOut.transform(_color.value))!;

  @override
  void dispose() {
    _drift.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return AnimatedBuilder(
      animation: Listenable.merge([_drift, _color]),
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.bg)),
            Positioned.fill(
              child: CustomPaint(
                painter: _AtmospherePainter(
                  tint: _currentTint,
                  base: c.bg,
                  dark: c.dark,
                  phase: Curves.easeInOut.transform(_drift.value),
                ),
              ),
            ),
            const Positioned.fill(child: _NoiseOverlay()),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter({
    required this.tint,
    required this.base,
    required this.dark,
    required this.phase,
  });

  final Color tint;
  final Color base;
  final bool dark;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(phase * 0.087); // 5deg
    canvas.scale(1 + phase * 0.12);
    canvas.translate(
      -size.width / 2 - size.width * 0.05 * phase,
      -size.height / 2 + size.height * 0.04 * phase,
    );

    final intensity = dark ? 1.0 : 0.55;
    _glow(
      canvas,
      size,
      Offset(size.width * 0.82, size.height * 0.10),
      size.width * 0.38,
      tint.withValues(alpha: 0.34 * intensity),
    );
    _glow(
      canvas,
      size,
      Offset(size.width * 0.06, size.height * 0.52),
      size.width * 0.42,
      const Color(0xFFFF6B4A).withValues(alpha: 0.20 * intensity),
    );
    _glow(
      canvas,
      size,
      Offset(size.width * 0.75, size.height * 0.98),
      size.width * 0.45,
      const Color(0xFF6EE7FF).withValues(alpha: 0.22 * intensity),
    );
    _glow(
      canvas,
      size,
      Offset(size.width * 0.30, size.height * 0.12),
      size.width * 0.30,
      const Color(0xFFC084FC).withValues(alpha: 0.18 * intensity),
    );
    canvas.restore();
  }

  void _glow(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    Color color,
  ) {
    final shader = ui.Gradient.radial(
      center,
      radius,
      [color, color.withValues(alpha: 0)],
      const [0, 1],
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.tint != tint ||
      oldDelegate.base != base ||
      oldDelegate.dark != dark;
}

class _NoiseOverlay extends StatelessWidget {
  const _NoiseOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _NoisePainter(), size: Size.infinite),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(11);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (var i = 0; i < 900; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
