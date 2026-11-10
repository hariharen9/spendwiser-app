import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Pressable(
      onTap: () => onChanged(!value),
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: value
              ? c.accentGradient
              : LinearGradient(colors: [c.c2, c.c2]),
          borderRadius: BorderRadius.circular(99),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: c.ac.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? c.aci : c.tx,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
