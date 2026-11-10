import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'atmosphere_background.dart';

const _coinGold = Color(0xFFFFCE52);

class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key, this.still = false, this.message});

  /// Skips the intro and holds the final frame for internal boot screens.
  final bool still;
  final String? message;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _orbit;
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: widget.still ? 1 : 0,
    );
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    if (!widget.still) _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _orbit.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Scaffold(
      backgroundColor: c.bg,
      body: Semantics(
        container: true,
        label: 'Spendwiser is loading',
        child: AtmosphereBackground(
          tint: _coinGold,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final centerY = constraints.maxHeight / 2;
                return AnimatedBuilder(
                  animation: Listenable.merge([_intro, _orbit, _breathe]),
                  builder: (context, _) {
                    final mark = Curves.easeOutBack.transform(
                      const Interval(0, 0.65).transform(_intro.value),
                    );
                    final copy = Curves.easeOutCubic.transform(
                      const Interval(0.28, 0.78).transform(_intro.value),
                    );
                    final tag = Curves.easeOutCubic.transform(
                      const Interval(0.42, 0.88).transform(_intro.value),
                    );
                    final fade = Curves.easeOut.transform(
                      const Interval(0, 0.22).transform(_intro.value),
                    );
                    final breath = math.sin(_breathe.value * math.pi);
                    final orbit = _orbit.value * math.pi * 2;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0, 0.04),
                                  radius: 0.92,
                                  colors: [
                                    Colors.transparent,
                                    c.bg.withValues(alpha: 0.34),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: centerY - 110,
                          left: 0,
                          right: 0,
                          child: SizedBox(
                            height: 220,
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: fade,
                                    child: Transform.scale(
                                      scale: 0.92 + 0.08 * mark,
                                      child: Container(
                                        width: 194,
                                        height: 194,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              _coinGold.withValues(
                                                alpha: 0.09 + 0.035 * breath,
                                              ),
                                              _coinGold.withValues(alpha: 0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Opacity(
                                    opacity: fade,
                                    child: Transform.rotate(
                                      angle: orbit,
                                      child: CustomPaint(
                                        size: const Size.square(216),
                                        painter: _SplashRingPainter(
                                          opacity: fade,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Opacity(
                                    opacity: fade,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        (1 - mark) * 10 - breath * 1.4,
                                      ),
                                      child: Transform.scale(
                                        scale: 0.78 + 0.22 * mark,
                                        child: Image.asset(
                                          'assets/branding/splash_mark.png',
                                          width: 128,
                                          height: 128,
                                          filterQuality: FilterQuality.high,
                                          semanticLabel: 'Spendwiser',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: centerY + 118,
                          left: 24,
                          right: 24,
                          child: Opacity(
                            opacity: copy,
                            child: Transform.translate(
                              offset: Offset(0, (1 - copy) * 8),
                              child: Text(
                                'Spendwiser',
                                textAlign: TextAlign.center,
                                style: AppTypography.serif(
                                  size: 36,
                                  color: c.tx,
                                  height: 1,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: centerY + 164,
                          left: 24,
                          right: 24,
                          child: Opacity(
                            opacity: tag,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _Rule(progress: tag),
                                const SizedBox(width: 9),
                                Text(
                                  'SPEND WISER',
                                  style: AppTypography.sans(
                                    size: 8.5,
                                    color: c.mu,
                                    letterSpacing: 2.4,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                _Rule(progress: tag),
                              ],
                            ),
                          ),
                        ),
                        if (widget.message != null)
                          Positioned(
                            top: centerY + 196,
                            left: 28,
                            right: 28,
                            child: Opacity(
                              opacity: tag,
                              child: _SplashMessage(message: widget.message!),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 28,
                          child: Opacity(
                            opacity: tag,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 54,
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _coinGold.withValues(alpha: 0),
                                        _coinGold.withValues(alpha: 0.55),
                                        _coinGold.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'SECURE · PRIVATE · YOURS',
                                  style: AppTypography.sans(
                                    size: 8,
                                    color: c.mu.withValues(alpha: 0.62),
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22 * progress,
      height: 1,
      color: _coinGold.withValues(alpha: 0.7),
    );
  }
}

class _SplashMessage extends StatelessWidget {
  const _SplashMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.co.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.co.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.sans(size: 10.5, color: c.co),
      ),
    );
  }
}

class _SplashRingPainter extends CustomPainter {
  const _SplashRingPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.045 * opacity),
    );

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          _coinGold.withValues(alpha: 0),
          _coinGold.withValues(alpha: 0.08 * opacity),
          _coinGold.withValues(alpha: 0.62 * opacity),
          _coinGold.withValues(alpha: 0),
        ],
        stops: const [0, 0.24, 0.62, 1],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.45, false, arc);

    final end = -math.pi / 2 + math.pi * 1.45;
    canvas.drawCircle(
      center + Offset(math.cos(end) * radius, math.sin(end) * radius),
      1.5,
      Paint()..color = _coinGold.withValues(alpha: 0.75 * opacity),
    );
  }

  @override
  bool shouldRepaint(covariant _SplashRingPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
