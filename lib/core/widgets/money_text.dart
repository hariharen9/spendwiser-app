import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../utils/currency_formatter.dart';

/// Blurs a single amount when "Hide balances" is enabled.
class HideableMoney extends ConsumerWidget {
  const HideableMoney({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(settingsProvider.select((s) => s.hideBalances));
    if (!hidden) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
      child: child,
    );
  }
}

class MoneyText extends ConsumerWidget {
  const MoneyText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HideableMoney(
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

/// Count-up amount with the prototype's 800ms ease-out cubic curve.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount({
    super.key,
    required this.value,
    required this.style,
    this.formatter = rupee,
    this.duration = const Duration(milliseconds: 850),
    this.textAlign,
    this.suffix,
    this.prefix,
  });

  final double value;
  final TextStyle style;
  final String Function(double) formatter;
  final Duration duration;
  final TextAlign? textAlign;
  final Widget? suffix;
  final Widget? prefix;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _from;
  late double _to;

  @override
  void initState() {
    super.initState();
    _from = 0;
    _to = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = oldWidget.value;
      _to = widget.value;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HideableMoney(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final value = _from + (_to - _from) * t;
          final text = Text(
            widget.formatter(value),
            style: widget.style,
            textAlign: widget.textAlign,
          );
          if (widget.prefix == null && widget.suffix == null) return text;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (widget.prefix != null) widget.prefix!,
              text,
              if (widget.suffix != null) widget.suffix!,
            ],
          );
        },
      ),
    );
  }
}

/// Fade + rise entrance used to stagger sections like `#scr > *`.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 700),
  });

  final Widget child;
  final int index;
  final Duration duration;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 1, curve: Curves.easeOutCubic),
    );
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curved);
    _scale = Tween<double>(begin: 0.985, end: 1).animate(curved);
    final delay = Duration(milliseconds: (widget.index.clamp(0, 9) * 55));
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
