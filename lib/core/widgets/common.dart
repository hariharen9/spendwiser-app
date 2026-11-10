import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_icons.dart';
import 'money_text.dart';

class ScreenScroll extends StatelessWidget {
  const ScreenScroll({
    super.key,
    required this.children,
    this.controller,
    this.padding,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final top =
        padding?.top ??
        (MediaQuery.paddingOf(context).top > 30
            ? MediaQuery.paddingOf(context).top + 16.0
            : 54.0);
    final bottom =
        padding?.bottom ?? (120 + MediaQuery.paddingOf(context).bottom);
    return SingleChildScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: padding ?? EdgeInsets.fromLTRB(20, top, 20, bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Horizontal, edge-to-edge pill / card strip. Children are padded 20px while
/// the strip itself bleeds through the screen gutter.
class BleedRow extends StatelessWidget {
  const BleedRow({
    super.key,
    required this.children,
    this.height,
    this.spacing = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.alignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final double? height;
  final double spacing;
  final EdgeInsets padding;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: Row(
        crossAxisAlignment: alignment,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            children[i],
          ],
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveHeight = height ?? 44.0;
        return SizedBox(
          height: effectiveHeight,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            minHeight: effectiveHeight,
            maxHeight: effectiveHeight,
            child: Transform.translate(
              offset: const Offset(-20, 0),
              child: SizedBox(
                width: width,
                height: effectiveHeight,
                child: row,
              ),
            ),
          ),
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 34),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.serif(size: 26, color: c.tx),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.sans(size: 14, color: c.mu),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            AppButton(
              label: actionLabel!,
              onTap: onAction,
              primary: true,
              centered: true,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    this.value,
    this.amount,
    this.formatter,
    this.valueColor,
    this.icon,
    this.padding = const EdgeInsets.all(12),
  }) : assert(value != null || amount != null);

  final String label;
  final String? value;
  final double? amount;
  final String Function(double)? formatter;
  final Color? valueColor;
  final String? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.c1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.ln),
        gradient: c.dark ? c.cardGradient : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                SpendIcon(icon!, size: 12, color: c.mu, strokeWidth: 1.7),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.sans(
                    size: 10,
                    color: c.mu,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: amount == null
                ? Text(
                    value!,
                    style: AppTypography.serif(
                      size: 22,
                      color: valueColor ?? c.tx,
                      height: 1.1,
                    ),
                  )
                : AnimatedAmount(
                    value: amount!,
                    formatter: formatter ?? rupee,
                    style: AppTypography.serif(
                      size: 22,
                      color: valueColor ?? c.tx,
                      height: 1.1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 2x2 metric grid used by Debt (the prototype's `.trio` with 2 columns).
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = 8,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final row = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (i + j < children.length) {
          row.add(Expanded(child: children[i + j]));
        } else {
          row.add(const Spacer());
        }
        if (j < columns - 1) row.add(SizedBox(width: spacing));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: row,
          ),
        ),
      );
      if (i + columns < children.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    return Column(children: rows);
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.border = true,
  });

  final String label;
  final Widget value;
  final Color? valueColor;
  final EdgeInsetsGeometry padding;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: border ? Border(bottom: BorderSide(color: c.ln)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.sans(size: 14, color: c.tx),
            ),
          ),
          DefaultTextStyle(
            style: AppTypography.sans(size: 14, color: valueColor ?? c.mu),
            child: value,
          ),
        ],
      ),
    );
  }
}

class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.serif(size: 30, color: c.tx, height: 1.1),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppTypography.sans(size: 14, color: c.mu)),
        ],
      ],
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: context.spend.ln);
  }
}

class AppCardHeader extends StatelessWidget {
  const AppCardHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.sans(
                  size: 14,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(padding: padding ?? const EdgeInsets.all(16), child: child);
  }
}
