import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.leading,
    this.trailing,
    this.color,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    this.fontSize = 12,
    this.fontWeight,
    this.borderColor,
    this.radius = 99,
    this.background,
    this.haptic = true,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final Color? color;
  final Color? textColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color? borderColor;
  final double radius;
  final Color? background;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final activeColor = color ?? c.ac;
    final activeGradient = active && background == null
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeColor,
              color == null ? c.ac2 : AppColors.accentSecondary(activeColor),
            ],
          )
        : null;
    final bg =
        background ??
        (active
            ? null
            : (color != null ? color!.withValues(alpha: 0.12) : c.c1));
    final fg = textColor ?? (active ? c.aci : (color ?? c.mu));
    final border = borderColor ?? (active ? activeColor : (color ?? c.ln));

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        gradient: activeGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
        boxShadow: active
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.14),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Text(
            label,
            maxLines: 1,
            style: AppTypography.sans(
              size: fontSize,
              color: fg,
              weight:
                  fontWeight ?? (active ? FontWeight.w600 : FontWeight.w400),
              height: 1.2,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 5), trailing!],
        ],
      ),
    );

    if (onTap == null) return content;
    return Pressable(onTap: onTap, haptic: haptic, scale: 0.95, child: content);
  }
}
