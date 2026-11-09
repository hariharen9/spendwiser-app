import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/date_helpers.dart';
import 'app_icons.dart';
import 'pressable.dart';

class MonthNavigator extends StatelessWidget {
  const MonthNavigator({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.canGoNext = true,
    this.margin = const EdgeInsets.symmetric(vertical: 2),
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final bool canGoNext;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Padding(
      padding: margin,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(icon: 'chevronLeft', onTap: onPrevious, color: c.tx),
          Text(
            monthYear(month),
            style: AppTypography.sans(
              size: 14,
              color: c.tx,
              weight: FontWeight.w500,
            ),
          ),
          _NavButton(
            icon: 'chevronRight',
            onTap: canGoNext ? onNext : null,
            color: canGoNext ? c.tx : c.mu.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final String icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c.c1,
          shape: BoxShape.circle,
          border: Border.all(color: c.ln),
        ),
        alignment: Alignment.center,
        child: SpendIcon(icon, size: 16, color: color, strokeWidth: 1.8),
      ),
    );
  }
}
