import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_icons.dart';

class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label);
  final T value;
  final String label;
}

class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.margin = EdgeInsets.zero,
  });

  final T? value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      height: 48,
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: options.any((o) => o.value == value) ? value : null,
          isExpanded: true,
          hint: hint == null
              ? null
              : Text(hint!, style: AppTypography.sans(size: 13, color: c.mu)),
          dropdownColor: c.c2,
          borderRadius: BorderRadius.circular(16),
          icon: SpendIcon('chevronDown', size: 16, color: c.mu),
          style: AppTypography.sans(size: 13, color: c.tx),
          items: [
            for (final option in options)
              DropdownMenuItem<T>(
                value: option.value,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.sans(size: 13, color: c.tx),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
