import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.centered,
    this.leading,
    this.trailing,
    this.color,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    this.fontSize = 14,
    this.radius = 18,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool? centered;
  final Widget? leading;
  final Widget? trailing;
  final Color? color;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double radius;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final isCentered = centered ?? primary;
    final fg = primary ? c.aci : (color ?? c.tx);

    final content = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: primary
            ? (color ?? c.ac)
            : (color != null ? color!.withValues(alpha: 0.08) : c.c1),
        gradient: primary || color != null
            ? null
            : (c.dark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.glassTop, c.glassBottom],
                    )
                  : null),
        borderRadius: BorderRadius.circular(radius),
        border: primary
            ? null
            : Border.all(color: color?.withValues(alpha: 0.25) ?? c.ln),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: (color ?? c.ac).withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: -12,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: isCentered
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              textAlign: isCentered ? TextAlign.center : TextAlign.left,
              style: AppTypography.sans(
                size: fontSize,
                color: fg,
                weight: primary ? FontWeight.w600 : FontWeight.w400,
                height: 1.25,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    if (onTap == null) return content;
    return Pressable(onTap: onTap, haptic: haptic, child: content);
  }
}

/// Full-width primary CTA, matching `.btn.pri` from the prototype.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 8, top: 12),
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onTap: onTap,
      primary: true,
      margin: margin,
      leading: leading,
    );
  }
}
