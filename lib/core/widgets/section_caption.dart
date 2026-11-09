import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SectionCaption extends StatelessWidget {
  const SectionCaption(
    this.label, {
    super.key,
    this.margin = const EdgeInsets.only(top: 22, bottom: 8),
    this.trailing,
  });

  final String label;
  final EdgeInsetsGeometry margin;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final text = Text(label.toUpperCase(), style: AppTypography.caption(c.mu));
    if (trailing == null) {
      return Padding(padding: margin, child: text);
    }
    return Padding(
      padding: margin,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [text, trailing!],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.trailing,
    this.bottom = 4,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle.isNotEmpty)
          Text(subtitle, style: AppTypography.sans(size: 12, color: c.mu)),
        Text(
          title,
          style: AppTypography.display(
            size: 40,
            color: c.tx,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: trailing == null
          ? heading
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: heading),
                trailing!,
              ],
            ),
    );
  }
}
