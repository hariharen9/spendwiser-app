import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/models/finance_snapshot.dart';

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
  _AskResult? _result;

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

  void _ask(String query) {
    if (query.trim().isEmpty) return;
    final snapshot = ref.read(financeSnapshotProvider);
    setState(() => _result = _AskResult.compute(snapshot, query));
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final result = _result;
    if (result == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('Ask Spendwiser'),
          const SizedBox(height: 12),
          Container(
            height: 52,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: false,
                    style: AppTypography.sans(size: 14, color: c.tx),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _ask,
                    decoration: InputDecoration(
                      hintText: 'e.g. Food last month, Uber this week',
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
              for (final suggestion in const [
                'Food this month',
                'Uber last month',
                'Total spent this week',
                'Income this month',
                'Shopping last 30 days',
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: AppTypography.sans(size: 14, color: c.tx),
                textInputAction: TextInputAction.search,
                onSubmitted: _ask,
                decoration: InputDecoration(
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
        const SizedBox(height: 18),
        Text(result.label, style: AppTypography.sans(size: 12, color: c.mu)),
        AnimatedAmount(
          value: result.total,
          duration: const Duration(milliseconds: 650),
          style: AppTypography.serif(
            size: 54,
            color: c.tx,
            letterSpacing: -1,
            height: 1.05,
          ),
        ),
        MoneyText(
          '${result.count} transactions · ${rupee(result.perDay)} per day',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        if (result.top.isNotEmpty) ...[
          const SectionCaption(
            'Top',
            margin: EdgeInsets.only(top: 20, bottom: 8),
          ),
          for (final entry in result.top)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: AppTypography.sans(size: 14, color: c.tx),
                        ),
                      ),
                      MoneyText(
                        rupee(entry.value),
                        style: AppTypography.sans(size: 14, color: c.mu),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: result.top.first.value == 0
                          ? 0
                          : entry.value / result.top.first.value,
                      minHeight: 6,
                      backgroundColor: c.c2,
                      valueColor: AlwaysStoppedAnimation(c.ac),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (widget.onOpenLedger != null)
          PrimaryButton(
            label: 'Open in ledger',
            onTap: () {
              Navigator.of(context).pop();
              widget.onOpenLedger!();
            },
          ),
        AppButton(
          label: 'Ask something else',
          centered: true,
          margin: const EdgeInsets.only(top: 8),
          onTap: () => setState(() => _result = null),
        ),
      ],
    );
  }
}

class _AskResult {
  const _AskResult({
    required this.label,
    required this.total,
    required this.count,
    required this.perDay,
    required this.top,
  });

  final String label;
  final double total;
  final int count;
  final double perDay;
  final List<MapEntry<String, double>> top;

  factory _AskResult.compute(FinanceSnapshot snapshot, String query) {
    final q = query.toLowerCase().trim();
    final now = DateTime.now();
    final today = dateOnly(now);
    var start = DateTime(now.year, now.month, 1);
    var end = DateTime(now.year, now.month + 1, 1);
    var label = 'this month';

    if (q.contains('today')) {
      start = today;
      end = today.add(const Duration(days: 1));
      label = 'today';
    } else if (q.contains('yesterday')) {
      start = today.subtract(const Duration(days: 1));
      end = today;
      label = 'yesterday';
    } else if (q.contains('last month')) {
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 1);
      label = 'last month';
    } else {
      final lastDays = RegExp(r'last (\d+) days').firstMatch(q);
      if (lastDays != null) {
        final n = int.parse(lastDays.group(1)!);
        start = today.subtract(Duration(days: n - 1));
        end = today.add(const Duration(days: 1));
        label = 'last $n days';
      } else if (q.contains('week')) {
        start = today.subtract(Duration(days: now.weekday - 1));
        end = today.add(const Duration(days: 1));
        label = 'this week';
      } else if (q.contains('year')) {
        start = DateTime(now.year, 1, 1);
        end = today.add(const Duration(days: 1));
        label = 'this year';
      }
    }

    final category = snapshot.budgets
        .map((b) => b.category)
        .where((cat) => q.contains(cat.toLowerCase()))
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final income = RegExp(r'income|earn|salary').hasMatch(q);
    String? merchant;
    final names = <String>{for (final t in snapshot.transactions) t.merchant};
    for (final name in names) {
      final token = name.toLowerCase().split(' ').first;
      if (token.length > 2 && q.contains(token)) {
        merchant = name;
        break;
      }
    }

    final matches = snapshot.transactions.where((t) {
      if (t.date.isBefore(start) || !t.date.isBefore(end)) return false;
      if (t.category == 'Transfer') return false;
      if (income ? t.amount <= 0 : t.amount >= 0) return false;
      if (category != null && t.category != category) return false;
      if (merchant != null && t.merchant != merchant) return false;
      return true;
    }).toList();

    final total = matches.fold<double>(0, (sum, t) => sum + t.amount.abs());
    final cutoff = end.isAfter(today.add(const Duration(days: 1)))
        ? today.add(const Duration(days: 1))
        : end;
    final days = cutoff.difference(start).inDays.clamp(1, 10000);
    final topMap = <String, double>{};
    for (final t in matches) {
      topMap[t.merchant] = (topMap[t.merchant] ?? 0) + t.amount.abs();
    }
    final top = topMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final parts = <String>[];
    parts.add(income ? 'Income' : 'Spent');
    if (category != null) parts.add('on $category');
    if (merchant != null) parts.add('· $merchant');
    parts.add('· $label');
    return _AskResult(
      label: parts.join(' '),
      total: total,
      count: matches.length,
      perDay: total / days,
      top: top.take(4).toList(),
    );
  }
}
