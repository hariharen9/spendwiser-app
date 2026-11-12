import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/pressable.dart';

/// Compact icon-only switch between the ledger list and calendar views.
class LedgerViewSwitch extends StatelessWidget {
  const LedgerViewSwitch({
    super.key,
    required this.calendar,
    required this.onChanged,
  });

  final bool calendar;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Semantics(
      container: true,
      label: 'Ledger view',
      child: Container(
        width: 76,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.c1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.ln),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.dark ? 0.16 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: calendar ? 35 : 0,
              top: 0,
              bottom: 0,
              width: 35,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.ac, c.ac2],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _SwitchButton(
                    icon: 'ledger',
                    label: 'List view',
                    selected: !calendar,
                    onTap: () => onChanged(false),
                  ),
                ),
                Expanded(
                  child: _SwitchButton(
                    icon: 'calendar',
                    label: 'Calendar view',
                    selected: calendar,
                    onTap: () => onChanged(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 450),
        child: Pressable(
          onTap: onTap,
          scale: 0.9,
          child: Center(
            child: AnimatedScale(
              scale: selected ? 1 : 0.9,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: SpendIcon(
                icon,
                size: 16,
                color: selected ? c.aci : c.mu,
                strokeWidth: 1.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
