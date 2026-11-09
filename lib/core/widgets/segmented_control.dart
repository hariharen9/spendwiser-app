import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

class SegmentedOption<T> {
  const SegmentedOption(this.value, this.label);
  final T value;
  final String label;
}

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.margin = const EdgeInsets.symmetric(vertical: 12),
    this.height = 38,
  });

  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry margin;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.c1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.ln),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Pressable(
                onTap: () {
                  if (option.value == selected) return;
                  onChanged(option.value);
                },
                scale: 0.96,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option.value == selected ? c.tx : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(
                      size: 12,
                      color: option.value == selected ? c.bg : c.mu,
                      weight: option.value == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
