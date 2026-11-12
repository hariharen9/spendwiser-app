import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Persistent label above a form control.
///
/// Unlike a hint, this remains visible after the field is filled, so edit
/// sheets always describe what each value means.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.margin = EdgeInsets.zero,
  });

  final String label;
  final Widget child;
  final bool required;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sans(
              size: 11,
              color: c.mu,
              weight: FontWeight.w500,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
