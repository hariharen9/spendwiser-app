import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_icons.dart';
import '../shell/app_module.dart';

class RadialOrbitOverlay extends StatefulWidget {
  const RadialOrbitOverlay({
    super.key,
    required this.current,
    required this.onNavigate,
    required this.onClose,
    this.initialPointer,
    required this.fabBottom,
  });

  final AppModule current;
  final ValueChanged<AppModule> onNavigate;
  final VoidCallback onClose;
  final Offset? initialPointer;
  final double fabBottom;

  @override
  State<RadialOrbitOverlay> createState() => RadialOrbitOverlayState();
}

class RadialOrbitOverlayState extends State<RadialOrbitOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  AppModule? _hovered;
  bool _sticky = false;

  static const _innerModules = <AppModule>[
    AppModule.home,
    AppModule.ledger,
    AppModule.accounts,
    AppModule.cards,
    AppModule.budgets,
  ];

  static const _outerModules = <AppModule>[
    AppModule.subscriptions,
    AppModule.debt,
    AppModule.split,
    AppModule.goals,
    AppModule.calendar,
    AppModule.insights,
    AppModule.tools,
    AppModule.settings,
  ];

  static const double _r1 = 98.0;
  static const double _r2 = 172.0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    if (widget.initialPointer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        updatePointer(widget.initialPointer!);
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Offset _fabCenter(Size size) {
    return Offset(size.width / 2, size.height - widget.fabBottom - 31);
  }

  Offset _nodeCenter(AppModule module, Size size) {
    final center = _fabCenter(size);
    final innerIndex = _innerModules.indexOf(module);
    if (innerIndex != -1) {
      final angle =
          (152.0 - (152.0 - 28.0) * innerIndex / (_innerModules.length - 1)) *
          math.pi /
          180.0;
      return Offset(
        center.dx + math.cos(angle) * _r1,
        center.dy - math.sin(angle) * _r1,
      );
    }
    final outerIndex = _outerModules.indexOf(module);
    if (outerIndex != -1) {
      final angle =
          (168.0 - (168.0 - 12.0) * outerIndex / (_outerModules.length - 1)) *
          math.pi /
          180.0;
      return Offset(
        center.dx + math.cos(angle) * _r2,
        center.dy - math.sin(angle) * _r2,
      );
    }
    return center;
  }

  void updatePointer(Offset globalPosition) {
    final size = MediaQuery.sizeOf(context);
    AppModule? best;
    double bestDist = 48.0; // detection threshold

    for (final m in [..._innerModules, ..._outerModules]) {
      final pos = _nodeCenter(m, size);
      final dist = (globalPosition - pos).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = m;
      }
    }

    if (best != _hovered) {
      Haptics.light();
      setState(() => _hovered = best);
    }
  }

  void handlePointerUp(Offset globalPosition) {
    final size = MediaQuery.sizeOf(context);
    final center = _fabCenter(size);

    if (_hovered != null) {
      Haptics.medium();
      widget.onNavigate(_hovered!);
      return;
    }

    // If released within 60px of the FAB, stay open in sticky mode
    final distToFab = (globalPosition - center).distance;
    if (distToFab < 60) {
      setState(() => _sticky = true);
    } else {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final size = MediaQuery.sizeOf(context);
    final center = _fabCenter(size);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_anim.value);

        return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_sticky) widget.onClose();
            },
            onPanUpdate: (d) => updatePointer(d.globalPosition),
            onPanEnd: (d) => handlePointerUp(d.velocity.pixelsPerSecond == Offset.zero ? center : Offset.zero),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 18 * t,
                  sigmaY: 18 * t,
                ),
                child: ColoredBox(
                  color: c.bg.withValues(alpha: 0.68 * t),
                  child: Stack(
                    children: [
                      // Concentric dashed orbit rings
                      CustomPaint(
                        size: size,
                        painter: _RadialRingsPainter(
                          center: center,
                          r1: _r1,
                          r2: _r2,
                          color: c.ac,
                          opacity: t,
                          scale: 0.3 + 0.7 * t,
                        ),
                      ),
                      if (_hovered != null)
                        CustomPaint(
                          size: size,
                          painter: _OrbitTetherPainter(
                            center: center,
                            target: _nodeCenter(_hovered!, size),
                            color: _hovered!.tint,
                            opacity: t,
                          ),
                        ),

                      // The hint stays near the orbit.
                      if (_hovered == null)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: widget.fabBottom + _r2 + 72,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: t,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.c1.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: c.ln),
                                  ),
                                  child: Text(
                                    'Slide to a module · release to open',
                                    style: AppTypography.sans(
                                      size: 12,
                                      color: c.mu,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // The selected title sits in the middle of the screen.
                      if (_hovered != null)
                        Positioned(
                          left: 20,
                          right: 20,
                          top: size.height * 0.38,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: t,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: 0.94,
                                        end: 1,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _OrbitSelectionTitle(
                                  key: ValueKey(_hovered!.id),
                                  module: _hovered!,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Inner 5 module nodes
                      for (var i = 0; i < _innerModules.length; i++)
                        _buildNode(
                          module: _innerModules[i],
                          pos: _nodeCenter(_innerModules[i], size),
                          center: center,
                          index: i,
                          t: t,
                          c: c,
                        ),

                      // Outer 8 module nodes
                      for (var i = 0; i < _outerModules.length; i++)
                        _buildNode(
                          module: _outerModules[i],
                          pos: _nodeCenter(_outerModules[i], size),
                          center: center,
                          index: _innerModules.length + i,
                          t: t,
                          c: c,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
  }

  Widget _buildNode({
    required AppModule module,
    required Offset pos,
    required Offset center,
    required int index,
    required double t,
    required dynamic c,
  }) {
    final isHot = _hovered == module;
    final isCurrent = widget.current == module;
    // Animate outwards from center on entrance
    final currentPos = Offset.lerp(center, pos, t)!;

    final node = GestureDetector(
      onTap: () {
        Haptics.medium();
        widget.onNavigate(module);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: isHot
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    module.tint,
                    Color.lerp(module.tint, Colors.black, 0.35)!,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.c1, Color.lerp(c.c1, c.c2, 0.55)!],
                ),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: isHot
                ? Colors.white.withValues(alpha: 0.28)
                : (isCurrent ? c.ac : c.ln),
            width: isHot ? 1.2 : (isCurrent ? 1.5 : 1),
          ),
          boxShadow: [
            if (isHot)
              BoxShadow(
                color: module.tint.withValues(alpha: 0.5),
                blurRadius: 32,
                spreadRadius: 3,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: SpendIcon(
          module.icon,
          size: 22,
          color: isHot
              ? const Color(0xFF09090B)
              : (isCurrent ? c.ac : c.tx),
        ),
      ),
    );

    return Positioned(
      left: currentPos.dx - 23,
      top: currentPos.dy - 23,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        scale: isHot ? 1.38 : 1.0,
        child: node,
      ),
    );
  }
}

class _OrbitSelectionTitle extends StatelessWidget {
  const _OrbitSelectionTitle({super.key, required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          module.label,
          textAlign: TextAlign.center,
          style: AppTypography.serif(
            size: 32,
            color: c.tx,
            height: 1.0,
          ).copyWith(
            shadows: [
              Shadow(
                color: c.bg.withValues(alpha: 0.9),
                blurRadius: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 1,
              color: module.tint.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                module.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sans(size: 11, color: c.mu),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RadialRingsPainter extends CustomPainter {
  _RadialRingsPainter({
    required this.center,
    required this.r1,
    required this.r2,
    required this.color,
    required this.opacity,
    required this.scale,
  });

  final Offset center;
  final double r1;
  final double r2;
  final Color color;
  final double opacity;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final glowRect = Rect.fromCircle(center: center, radius: r2 * scale);
    canvas.drawCircle(
      center,
      r2 * scale,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.06 * opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(glowRect),
    );

    final paint = Paint()
      ..color = color.withValues(alpha: 0.18 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    _drawDashedCircle(canvas, center, r1 * scale, paint);
    _drawDashedCircle(canvas, center, r2 * scale, paint);

    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r1 * scale),
      -0.65,
      0.9,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r2 * scale),
      2.3,
      0.55,
      false,
      arcPaint,
    );
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    if (radius <= 0) return;
    final circumference = 2 * math.pi * radius;
    final dashLength = 4.0;
    final dashSpace = 4.0;
    final count = (circumference / (dashLength + dashSpace)).floor();
    final sweepAngle = (dashLength / circumference) * 2 * math.pi;
    final spaceAngle = (dashSpace / circumference) * 2 * math.pi;

    for (var i = 0; i < count; i++) {
      final startAngle = i * (sweepAngle + spaceAngle);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadialRingsPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.r1 != r1 ||
      oldDelegate.r2 != r2 ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity ||
      oldDelegate.scale != scale;
}

class _OrbitTetherPainter extends CustomPainter {
  const _OrbitTetherPainter({
    required this.center,
    required this.target,
    required this.color,
    required this.opacity,
  });

  final Offset center;
  final Offset target;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(center, target);
    final glow = LinearGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.1 * opacity),
      ],
    ).createShader(rect);
    final line = LinearGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.5 * opacity),
      ],
    ).createShader(rect);

    canvas.drawLine(
      center,
      target,
      Paint()
        ..shader = glow
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center,
      target,
      Paint()
        ..shader = line
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitTetherPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.target != target ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity;
}

