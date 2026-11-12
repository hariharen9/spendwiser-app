import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import 'services/ask_ai_client.dart';
import 'services/local_ask_engine.dart';

Future<void> showAskSpendwiserSheet(
  BuildContext context, {
  String? initialQuery,
  VoidCallback? onOpenLedger,
}) {
  return showAppSheet<void>(
    context,
    (_) => _AskSheet(initialQuery: initialQuery, onOpenLedger: onOpenLedger),
  );
}

class _AskSheet extends ConsumerStatefulWidget {
  const _AskSheet({this.initialQuery, this.onOpenLedger});

  final String? initialQuery;
  final VoidCallback? onOpenLedger;

  @override
  ConsumerState<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends ConsumerState<_AskSheet> {
  final _controller = TextEditingController();
  LocalAskResult? _local;
  String? _aiAnswer;
  String? _aiError;
  bool _aiLoading = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ask(widget.initialQuery!),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask(String query, {bool forceAi = false}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final snapshot = ref.read(financeSnapshotProvider);
    final settings = ref.read(settingsProvider);
    final local = LocalAskEngine.answer(
      snapshot,
      trimmed,
      knownCategories: settings.categories.keys,
    );
    setState(() {
      _local = local;
      _aiAnswer = null;
      _aiError = null;
      _aiLoading = false;
    });
    FocusScope.of(context).unfocus();

    if (settings.hasAiKey && (forceAi || !local.isHighConfidence)) {
      _askAi(trimmed);
    }
  }

  Future<void> _askAi(String query) async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasAiKey) return;
    final snapshot = ref.read(financeSnapshotProvider);
    final id = ++_requestId;
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final answer = await AskAiClient.ask(
        provider: settings.aiProvider,
        apiKey: settings.aiApiKey,
        model: settings.effectiveAiModel,
        query: query,
        snapshot: snapshot,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _aiAnswer = answer;
        _aiLoading = false;
      });
    } on AskAiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _aiError = e.message;
        _aiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final settings = ref.watch(settingsProvider);
    final snapshot = ref.watch(financeSnapshotProvider);
    final local = _local;
    final firstTag = snapshot.tags.isNotEmpty ? snapshot.tags.first : null;

    if (local == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SheetTitle('Ask Spendwiser')),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.c2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.ln),
                ),
                child: Text(
                  settings.hasAiKey
                      ? 'Hybrid · ${settings.aiProvider.label}'
                      : 'Local · Instant',
                  style: AppTypography.sans(
                    size: 11,
                    color: settings.hasAiKey ? c.ac : c.mu,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 52,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textAlignVertical: TextAlignVertical.center,
                    autofocus: false,
                    style: AppTypography.sans(size: 14, color: c.tx),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _ask,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: settings.hasAiKey
                          ? 'Ask anything: last 2 days, #tag, 1 Nov to 10 Nov…'
                          : 'e.g. Spends in last 2 days, #tag, Food Oct…',
                      hintStyle: AppTypography.sans(size: 13, color: c.mu),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _ask(_controller.text),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.ac,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: SpendIcon('arrowRight', size: 18, color: c.aci),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in [
                'Biggest spend this month',
                'Spends in last 2 days',
                'Transactions in last 7 days',
                if (firstTag != null) 'Transactions in #$firstTag',
                'Top merchants this month',
                'Compare vs last month',
                'Weekend spends',
                'Food this month',
                'Card dues',
                if (settings.hasAiKey) 'How can I save ₹5,000 this month?',
              ])
                AppPill(
                  label: suggestion,
                  onTap: () {
                    _controller.text = suggestion;
                    _ask(suggestion);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Ask', onTap: () => _ask(_controller.text)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            color: c.c2,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textAlignVertical: TextAlignVertical.center,
                  style: AppTypography.sans(size: 14, color: c.tx),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _ask,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: 'Ask another question…',
                    hintStyle: AppTypography.sans(size: 13, color: c.mu),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppPill(
                label: 'Ask',
                active: true,
                onTap: () => _ask(_controller.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_aiLoading) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.ac.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.ac,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Asking ${settings.aiProvider.label}…',
                    style: AppTypography.sans(size: 13, color: c.tx),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_aiAnswer != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.ac.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SpendIcon('sparkle', size: 14, color: c.ac),
                    const SizedBox(width: 6),
                    Text(
                      '${settings.aiProvider.label} · ${settings.effectiveAiModel}',
                      style: AppTypography.sans(
                        size: 11,
                        color: c.ac,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _FormattedAiResponse(text: _aiAnswer!),
              ],
            ),
          ),
        ] else if (_aiError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: c.co.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.co.withValues(alpha: 0.35)),
            ),
            child: Text(
              _aiError!,
              style: AppTypography.sans(size: 12, color: c.co),
            ),
          ),
        ],
        Text(local.headline, style: AppTypography.sans(size: 12, color: c.mu)),
        if (local.amount != null)
          AnimatedAmount(
            value: local.amount!,
            duration: const Duration(milliseconds: 650),
            style: AppTypography.serif(
              size: 52,
              color: c.tx,
              letterSpacing: -1,
              height: 1.05,
            ),
          ),
        MoneyText(
          local.subtitle,
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        if (local.bars.isNotEmpty) ...[
          const SectionCaption(
            'Breakdown',
            margin: EdgeInsets.only(top: 20, bottom: 8),
          ),
          for (final bar in local.bars)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bar.label,
                              style: AppTypography.sans(size: 14, color: c.tx),
                            ),
                            if (bar.sublabel != null)
                              Text(
                                bar.sublabel!,
                                style: AppTypography.sans(
                                  size: 11,
                                  color: c.mu,
                                ),
                              ),
                          ],
                        ),
                      ),
                      MoneyText(
                        bar.valueText,
                        style: AppTypography.sans(size: 14, color: c.mu),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: bar.ratio,
                      minHeight: 6,
                      backgroundColor: c.c2,
                      valueColor: AlwaysStoppedAnimation(c.ac),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (settings.hasAiKey && _aiAnswer == null && !_aiLoading) ...[
          const SizedBox(height: 6),
          AppButton(
            label: 'Ask ${settings.aiProvider.label} for deeper analysis',
            centered: true,
            onTap: () => _askAi(_controller.text),
          ),
        ] else if (!settings.hasAiKey && !local.isHighConfidence) ...[
          const SizedBox(height: 8),
          Text(
            'Tip: Add a free Gemini or OpenRouter API key in Settings → AI for conversational answers.',
            textAlign: TextAlign.center,
            style: AppTypography.sans(size: 11, color: c.mu),
          ),
        ],
        const SizedBox(height: 10),
        if (widget.onOpenLedger != null && local.ledgerPrefill != null)
          PrimaryButton(
            label: 'Open in ledger',
            onTap: () {
              ref.read(ledgerPrefillProvider.notifier).set(local.ledgerPrefill);
              Navigator.of(context).pop();
              widget.onOpenLedger!();
            },
          ),
        AppButton(
          label: 'Ask something else',
          centered: true,
          margin: const EdgeInsets.only(top: 8),
          onTap: () => setState(() {
            _local = null;
            _aiAnswer = null;
            _aiError = null;
            _aiLoading = false;
          }),
        ),
      ],
    );
  }
}

/// Renders lightweight Markdown (headings, bullet/numbered lists, bold, italic,
/// inline code, and dividers) using SpendWiser's typography and accent tokens.
class _FormattedAiResponse extends StatelessWidget {
  const _FormattedAiResponse({required this.text});

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

      // Horizontal rule
      if (RegExp(r'^[-*_]{3,}$').hasMatch(trimmed)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: c.ln),
          ),
        );
        continue;
      }

      // Heading (# / ## / ###)
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

      // Bullet list (- , * , • )
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

      // Numbered list (1. , 2. )
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

      // Regular paragraph line
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
            style: base.copyWith(
              color: c.ac,
              fontWeight: FontWeight.w500,
            ),
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
