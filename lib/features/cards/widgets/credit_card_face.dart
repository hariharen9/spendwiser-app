import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../data/models/credit_card.dart';

class CreditCardFace extends StatefulWidget {
  const CreditCardFace({
    super.key,
    required this.card,
    required this.selected,
    required this.flipped,
    required this.onTap,
  });

  final CreditCard card;
  final bool selected;
  final bool flipped;
  final VoidCallback onTap;

  @override
  State<CreditCardFace> createState() => _CreditCardFaceState();
}

class _CreditCardFaceState extends State<CreditCardFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
      value: widget.flipped ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant CreditCardFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped != widget.flipped) {
      if (widget.flipped) {
        _flip.forward();
      } else {
        _flip.reverse();
      }
    }
    if (!widget.selected && oldWidget.selected) {
      _flip.value = 0;
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: widget.selected ? 1 : 0.5,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 400),
          scale: widget.selected ? 1 : 0.94,
          child: SizedBox(
            width: 300,
            height: 176,
            child: AnimatedBuilder(
              animation: _flip,
              builder: (context, _) {
                final angle = _flip.value * math.pi;
                final showingFront = _flip.value < 0.5;
                final matrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle);
                final face = showingFront
                    ? _FrontFace(card: card)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _BackFace(card: card, showCvv: widget.flipped),
                      );
                return Transform(
                  alignment: Alignment.center,
                  transform: matrix,
                  child: card.frozen
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: face,
                        )
                      : face,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FrontFace extends StatelessWidget {
  const _FrontFace({required this.card});

  final CreditCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.sans(
                    size: 14,
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                card.frozen ? 'FROZEN' : 'VISA',
                style: AppTypography.sans(
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3D98B), Color(0xFFB8913D)],
              ),
            ),
          ),
          Text(
            '••••  ••••  ••••  ${card.last4}',
            style: AppTypography.sans(
              size: 14,
              color: Colors.white,
              letterSpacing: 3,
              height: 1.1,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _CardLabel(
                  label: 'CARDHOLDER',
                  value: card.cardHolder.isEmpty
                      ? '—'
                      : card.cardHolder.toUpperCase(),
                ),
              ),
              _CardLabel(label: 'EXPIRES', value: '09/29', alignEnd: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackFace extends StatelessWidget {
  const _BackFace({required this.card, required this.showCvv});

  final CreditCard card;
  final bool showCvv;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            color: Colors.black.withValues(alpha: 0.62),
            margin: const EdgeInsets.only(top: 22),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFFDF5),
                          Color(0xFFFFFDF5),
                          Color(0xFFDDD8CC),
                          Color(0xFFDDD8CC),
                        ],
                        stops: [0, 0.45, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    showCvv ? '482' : '•••',
                    style: AppTypography.sans(
                      size: 14,
                      color: const Color(0xFF111111),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Text(
              'CVV · tap to hide',
              style: AppTypography.sans(
                size: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(CreditCard card) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: card.gradient,
    ),
    border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.32),
        blurRadius: 40,
        spreadRadius: -8,
        offset: const Offset(0, 18),
      ),
    ],
  );
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.sans(
            size: 8,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 1.12,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.sans(size: 13, color: Colors.white),
        ),
      ],
    );
  }
}
