import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Renders lightweight Markdown (headings, bullet/numbered lists, bold, italic,
/// inline code, and dividers) using SpendWiser's typography and accent tokens.
class FormattedAiResponse extends StatelessWidget {
  const FormattedAiResponse({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    final baseStyle = AppTypography.sans(
      size: 13,
      color: c.tx,
      height: 1.5,
    );

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].trimRight();
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 6));
        }
        continue;
      }

      if (RegExp(r'^[-*_]{3,}$').hasMatch(trimmed)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: c.ln),
          ),
        );
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 8, bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _parseInline(
                  headingMatch.group(2)!,
                  AppTypography.sans(
                    size: level == 1 ? 15 : 14,
                    color: c.tx,
                    weight: FontWeight.w600,
                    height: 1.35,
                  ),
                  c,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final bulletMatch = RegExp(r'^[-*•]\s+(.+)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 8, left: 2),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.ac,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInline(
                        bulletMatch.group(1)!,
                        baseStyle,
                        c,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final numMatch = RegExp(r'^(\d+\.)\s+(.+)$').firstMatch(trimmed);
      if (numMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    numMatch.group(1)!,
                    style: AppTypography.sans(
                      size: 12,
                      color: c.ac,
                      weight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInline(numMatch.group(2)!, baseStyle, c),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(children: _parseInline(trimmed, baseStyle, c)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static List<InlineSpan> _parseInline(
    String input,
    TextStyle base,
    SpendColors c,
  ) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`|\*(.+?)\*|_([^_]+)_)',
    );
    var cursor = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: input.substring(cursor, match.start), style: base),
        );
      }
      final bold = match.group(2) ?? match.group(3);
      final code = match.group(4);
      final italic = match.group(5) ?? match.group(6);
      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: base.copyWith(fontWeight: FontWeight.w600, color: c.tx),
          ),
        );
      } else if (code != null) {
        spans.add(
          TextSpan(
            text: code,
            style: base.copyWith(color: c.ac, fontWeight: FontWeight.w500),
          ),
        );
      } else if (italic != null) {
        spans.add(
          TextSpan(
            text: italic,
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor), style: base));
    }
    return spans;
  }
}

