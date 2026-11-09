import 'dart:math' as math;

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
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/services/finance_calculator.dart';
import '../../core/widgets/app_card.dart';

Future<void> showMonthlyReportSheet(BuildContext context, DateTime month) {
  return showAppSheet<void>(context, (_) => _MonthlyReportSheet(month: month));
}

class _MonthlyReportSheet extends ConsumerWidget {
  const _MonthlyReportSheet({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final flow = snapshot.flow(month);
    final previous = snapshot.flow(DateTime(month.year, month.month - 1, 1));
    final change = previous.expense == 0
        ? 0.0
        : (flow.expense / previous.expense - 1) * 100;
    final spends = snapshot.spendByCategory(month);
    final top = spends.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Monthly report',
          style: AppTypography.sans(size: 14, color: c.mu),
        ),
        Text(
          monthYear(month),
          style: AppTypography.serif(size: 34, color: c.tx),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricTile(label: 'In', value: compactINR(flow.income)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(label: 'Out', value: compactINR(flow.expense)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Saved',
                value: '${flow.savingsRate.round()}%',
                valueColor: c.ac,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending is ${change >= 0 ? 'up' : 'down'} ${change.abs().round()}% on last month.',
                style: AppTypography.sans(
                  size: 14,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              Text(
                '${rupee(previous.expense)} → ${rupee(flow.expense)}',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        const SectionCaption('Where it went'),
        if (top.isEmpty)
          Text(
            'No spending recorded.',
            style: AppTypography.sans(size: 14, color: c.mu),
          )
        else
          for (final spend in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          spend.category,
                          style: AppTypography.sans(size: 14, color: c.tx),
                        ),
                      ),
                      MoneyText(
                        rupee(spend.amount),
                        style: AppTypography.sans(size: 14, color: c.mu),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: top.first.amount == 0
                          ? 0
                          : spend.amount / top.first.amount,
                      minHeight: 6,
                      backgroundColor: c.c2,
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.category(spend.category),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        if (top.isNotEmpty)
          AppCard(
            child: Builder(
              builder: (context) {
                final limits = snapshot.budgets
                    .where((b) => b.category == top.first.category)
                    .toList();
                final limit = limits.isEmpty ? 0.0 : limits.first.limit;
                final percent = limit == 0
                    ? 0
                    : (top.first.amount / limit * 100).round();
                return Text(
                  '${top.first.category} is your biggest category. '
                  '$percent% of its envelope used'
                  '${isCurrentMonth(month) ? ' with ${daysLeftInMonth(month)} days to go' : ''}.',
                  style: AppTypography.sans(size: 12, color: c.mu),
                );
              },
            ),
          ),
        AppButton(
          label: 'Export as PDF',
          centered: true,
          onTap: () {
            Navigator.of(context).pop();
            ref.read(toastProvider.notifier).show('Preparing PDF…');
          },
        ),
      ],
    );
  }
}

Future<void> showTaxHelperSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _TaxHelperSheet());
}

class _TaxHelperSheet extends ConsumerWidget {
  const _TaxHelperSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    const limits = {'80C': 150000.0, '80D': 25000.0};
    final now = DateTime.now();
    final fy = now.month >= 4 ? now.year : now.year - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tax helper', style: AppTypography.serif(size: 30, color: c.tx)),
        Text(
          'FY $fy–${'${fy + 1}'.substring(2)} · based on your tags',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              for (final entry in limits.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${entry.key}',
                            style: AppTypography.sans(
                              size: 14,
                              color:
                                  AppColors.category(entry.key) == AppColors.mu
                                  ? c.tx
                                  : const Color(0xFFFF9F43),
                            ),
                          ),
                          const Spacer(),
                          MoneyText(
                            '${rupee(FinanceCalculator.taxTotal(snapshot, entry.key))} / ${rupee(entry.value)}',
                            style: AppTypography.sans(size: 13, color: c.tx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(
                          value:
                              (FinanceCalculator.taxTotal(snapshot, entry.key) /
                                      entry.value)
                                  .clamp(0, 1),
                          minHeight: 6,
                          backgroundColor: c.c2,
                          valueColor: AlwaysStoppedAnimation(
                            const Color(0xFFFF9F43),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Tag transactions from the ledger. This is a guide, not tax advice.',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        AppButton(
          label: 'Export tax report',
          primary: true,
          centered: true,
          onTap: () {
            Navigator.of(context).pop();
            ref.read(toastProvider.notifier).show('Preparing tax report…');
          },
        ),
      ],
    );
  }
}

Future<void> showYearInReview(BuildContext context, FinanceSnapshot snapshot) {
  final now = DateTime.now();
  final year = now.year;
  final items = snapshot.transactions
      .where((t) => t.date.year == year && t.category != 'Transfer')
      .toList();
  final income = items
      .where((t) => t.amount > 0)
      .fold<double>(0, (s, t) => s + t.amount);
  final expense = items
      .where((t) => t.amount < 0)
      .fold<double>(0, (s, t) => s - t.amount);
  final spends = snapshot.spendByCategory(monthStart(now));
  final top = spends.isEmpty ? null : spends.first;
  final biggest = items.where((t) => t.amount < 0).toList()
    ..sort((a, b) => a.amount.compareTo(b.amount));
  final weekdays = List<double>.filled(7, 0);
  for (final t in items.where((t) => t.amount < 0)) {
    weekdays[t.date.weekday % 7] -= t.amount;
  }
  final busiest = weekdays.indexOf(weekdays.reduce(math.max));
  final pages = [
    _ReviewPage(
      title: 'Your $year so far',
      body: 'You earned ${rupee(income)} and spent ${rupee(expense)}.',
      color: const Color(0xFFD4FF3A),
    ),
    _ReviewPage(
      title: 'Top category',
      body: top == null
          ? 'No spending yet.'
          : '${top.category} took ${rupee(top.amount)}',
      color: top == null ? AppColors.mu : AppColors.category(top.category),
    ),
    _ReviewPage(
      title: 'Biggest single spend',
      body: biggest.isEmpty
          ? '—'
          : '${biggest.first.merchant} · ${rupee(biggest.first.amount)}',
      color: const Color(0xFFC084FC),
    ),
    _ReviewPage(
      title: 'Busiest day',
      body: '${weekdayFullSun[busiest]}s are where the money goes.',
      color: const Color(0xFF6EE7FF),
    ),
    _ReviewPage(
      title: 'Savings rate',
      body:
          '${income == 0 ? 0 : ((income - expense) / income * 100).round()}% of income saved.',
      color: const Color(0xFFFFD23F),
    ),
  ];

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Year in review',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _YearInReview(pages: pages),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _ReviewPage {
  const _ReviewPage({
    required this.title,
    required this.body,
    required this.color,
  });

  final String title;
  final String body;
  final Color color;
}

class _YearInReview extends StatefulWidget {
  const _YearInReview({required this.pages});

  final List<_ReviewPage> pages;

  @override
  State<_YearInReview> createState() => _YearInReviewState();
}

class _YearInReviewState extends State<_YearInReview> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final page = widget.pages[_index];
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          if (_index < widget.pages.length - 1) {
            setState(() => _index++);
          } else {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.bg,
                  gradient: RadialGradient(
                    center: const Alignment(0.6, -1),
                    radius: 1.1,
                    colors: [
                      page.color.withValues(alpha: 0.35),
                      c.bg.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < widget.pages.length; i++)
                          Expanded(
                            child: Container(
                              height: 3,
                              margin: EdgeInsets.only(
                                right: i == widget.pages.length - 1 ? 0 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: i <= _index
                                    ? c.tx
                                    : c.tx.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: SpendIcon('closeSmall', size: 20, color: c.tx),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            page.title.toUpperCase(),
                            style: AppTypography.sans(
                              size: 12,
                              color: c.mu,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            page.body,
                            style: AppTypography.serif(
                              size: 44,
                              color: c.tx,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            'Tap to continue',
                            style: AppTypography.sans(size: 12, color: c.mu),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
