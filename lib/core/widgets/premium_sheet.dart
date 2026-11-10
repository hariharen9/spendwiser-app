import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_icons.dart';
import 'app_toggle.dart';

class PremiumSheetHeader extends StatelessWidget {
  const PremiumSheetHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final tint = accent ?? c.ac;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon: icon, color: tint, size: 46, backgroundOpacity: 0.11),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.serif(size: 28, color: c.tx, height: 1.02),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.sans(
                    size: 12,
                    color: c.mu,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.c2, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: SpendIcon('closeSmall', size: 17, color: c.tx),
          ),
        ),
      ],
    );
  }
}

class PremiumLabel extends StatelessWidget {
  const PremiumLabel(this.text, {super.key, this.requiredField = false});

  final String text;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: AppTypography.sans(size: 12, color: c.mu)),
          ),
          if (requiredField)
            Text('Required', style: AppTypography.sans(size: 10, color: c.mu)),
        ],
      ),
    );
  }
}

class PremiumField extends StatefulWidget {
  const PremiumField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.prefix,
    this.suffix,
    this.number = false,
    this.maxLines = 1,
    this.maxLength,
    this.capitalization = TextCapitalization.sentences,
    this.onChanged,
    this.enabled = true,
    this.large = false,
    this.textInputAction,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final String? icon;
  final String? prefix;
  final String? suffix;
  final bool number;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool large;
  final TextInputAction? textInputAction;
  final bool autofocus;

  @override
  State<PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<PremiumField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focused == _focus.hasFocus) return;
      setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final multiline = widget.maxLines > 1;
    final base = widget.large
        ? AppTypography.serif(
            size: 30,
            color: c.tx,
            letterSpacing: -0.6,
            height: 1.1,
          )
        : AppTypography.sans(size: 14, color: c.tx);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: widget.large ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? c.ac.withValues(alpha: 0.55) : c.ln,
          width: _focused ? 1.2 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: c.ac.withValues(alpha: 0.07),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            SpendIcon(widget.icon!, size: 17, color: c.mu),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              keyboardType: widget.number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              inputFormatters: [
                if (widget.number)
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                if (widget.maxLength != null)
                  LengthLimitingTextInputFormatter(widget.maxLength),
              ],
              maxLines: widget.maxLines,
              minLines: multiline ? widget.maxLines : 1,
              textCapitalization: widget.capitalization,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              style: base,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppTypography.sans(
                  size: widget.large ? 15 : 14,
                  color: c.mu,
                ),
                prefixText: widget.prefix,
                prefixStyle: AppTypography.serif(
                  size: widget.large ? 26 : 15,
                  color: c.mu,
                ),
                suffixText: widget.suffix,
                suffixStyle: AppTypography.sans(size: 12, color: c.mu),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumSummaryCard extends StatelessWidget {
  const PremiumSummaryCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.value,
    this.caption,
    this.accent,
    this.trailing,
  });

  final String icon;
  final String eyebrow;
  final String value;
  final String? caption;
  final Color? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final tint = accent ?? c.ac;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: c.dark ? 0.11 : 0.06),
            c.c1,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          IconTile(icon: icon, color: tint, size: 40, backgroundOpacity: 0.12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: AppTypography.sans(
                    size: 10,
                    color: c.mu,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: AppTypography.serif(
                      size: 28,
                      color: c.tx,
                      height: 1.02,
                    ),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class PremiumToggleRow extends StatelessWidget {
  const PremiumToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.sans(size: 14, color: c.tx)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.sans(size: 11, color: c.mu)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AppToggle(value: value, onChanged: onChanged),
      ],
    );
  }
}

class PremiumNotice extends StatelessWidget {
  const PremiumNotice({super.key, required this.text, this.icon = 'sparkle'});

  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.ln),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpendIcon(icon, size: 15, color: c.mu),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppTypography.sans(size: 11, color: c.mu, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
