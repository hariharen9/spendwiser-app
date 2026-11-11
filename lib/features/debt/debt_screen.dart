import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/custom_painters/debt_amortization_chart.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/loan.dart';
import '../../data/services/finance_calculator.dart';
import 'debt_sheets.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/segmented_control.dart';

enum _LoanTab { overview, schedule, payments, projection }

class DebtScreen extends ConsumerStatefulWidget {
  const DebtScreen({super.key});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen> {
  String? _selectedId;
  _LoanTab _tab = _LoanTab.overview;
  double _prepay = 0;
  double _extra = 5000;

  void _open(Loan loan) {
    Haptics.light();
    setState(() {
      _selectedId = loan.id;
      _tab = _LoanTab.overview;
      _prepay = 0;
      _extra = 5000;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(financeSnapshotProvider);
    if (_selectedId != null) {
      final loan = snapshot.loanById(_selectedId!);
      if (loan == null) {
        _selectedId = null;
      } else {
        return _LoanDetail(
          loan: loan,
          tab: _tab,
          prepay: _prepay,
          extra: _extra,
          onTab: (value) => setState(() => _tab = value),
          onPrepay: (value) => setState(() => _prepay = value),
          onExtra: (value) => setState(() => _extra = value),
          onBack: () => setState(() => _selectedId = null),
          onDeleted: () => setState(() => _selectedId = null),
        );
      }
    }
    return _LoanList(snapshot: snapshot, onOpen: _open);
  }
}

class _LoanSnapshot {
  _LoanSnapshot(this.loan, this.due, this.amortization);

  final Loan loan;
  final LoanDue due;
  final AmortizationResult amortization;
}

class _LoanList extends ConsumerWidget {
  const _LoanList({required this.snapshot, required this.onOpen});

  final FinanceSnapshot snapshot;
  final ValueChanged<Loan> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final now = DateTime.now();
    if (snapshot.loans.isEmpty) {
      return ScreenScroll(
        children: [
          const PageHeader(title: 'Debt', subtitle: 'Loans & obligations'),
          EmptyState(
            title: 'No loans tracked',
            message: 'Add a loan to start a payoff plan.',
            actionLabel: 'Add loan',
            onAction: () => showAddLoanSheet(context),
          ),
        ],
      );
    }

    final items = snapshot.loans.map((loan) {
      final due = FinanceCalculator.loanDue(loan, now: now);
      return _LoanSnapshot(
        loan,
        due,
        FinanceCalculator.amortize(
          balance: loan.outstanding,
          annualRate: loan.rate,
          emi: loan.emi,
          firstDue: due.date,
        ),
      );
    }).toList();

    final totalOutstanding = items.fold<double>(
      0,
      (sum, item) => sum + item.loan.outstanding,
    );
    final totalOriginal = items.fold<double>(
      0,
      (sum, item) => sum + item.loan.original,
    );
    final totalEmi = items.fold<double>(0, (sum, item) => sum + item.loan.emi);
    final totalInterest = items.fold<double>(
      0,
      (sum, item) => sum + item.amortization.interest,
    );
    final maxMonths = items.fold<int>(
      1,
      (max, item) => math.max(max, item.amortization.months),
    );
    final weightedRate = totalOutstanding == 0
        ? 0.0
        : items.fold<double>(
                0,
                (sum, item) => sum + item.loan.outstanding * item.loan.rate,
              ) /
              totalOutstanding;
    final income = FinanceCalculator.avgMonthlyIncome(
      snapshot,
      now: now,
    ).clamp(1, 1e12);
    final repaid = totalOriginal == 0
        ? 0.0
        : 1 - totalOutstanding / totalOriginal;
    final nextEmis = [...items]
      ..sort((a, b) => a.due.days.compareTo(b.due.days));
    final strategies = FinanceCalculator.strategies(
      snapshot,
      extraMonthly: 5000,
    );
    final base = strategies.first;
    String shortEnd(int months) {
      final end = DateTime(now.year, now.month + months, 1);
      return '${monthShort[end.month - 1]} ${end.year}';
    }

    return ScreenScroll(
      children: [
        const PageHeader(title: 'Debt', subtitle: 'Loans & obligations'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total outstanding',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              AnimatedAmount(
                value: totalOutstanding,
                style: AppTypography.serif(
                  size: 46,
                  color: c.tx,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value: repaid.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: c.c2,
                  valueColor: AlwaysStoppedAnimation(c.ac),
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${(repaid * 100).round()}% of ${rupee(totalOriginal)} repaid · debt-free by ',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                    TextSpan(
                      text: FinanceCalculator.resultLabel(maxMonths, now: now),
                      style: AppTypography.sans(
                        size: 12,
                        color: c.tx,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        MetricGrid(
          children: [
            MetricTile(
              label: 'Monthly EMIs',
              amount: totalEmi,
              padding: const EdgeInsets.all(16),
            ),
            MetricTile(
              label: 'Debt-to-income',
              amount: totalEmi / income * 100,
              formatter: (value) => '${value.round()}%',
              valueColor: totalEmi / income > 0.4 ? c.co : null,
              padding: const EdgeInsets.all(16),
            ),
            MetricTile(
              label: 'Avg interest rate',
              amount: weightedRate,
              formatter: (value) => '${value.toStringAsFixed(1)}%',
              padding: const EdgeInsets.all(16),
            ),
            MetricTile(
              label: 'Interest to pay',
              amount: totalInterest,
              formatter: compactINR,
              padding: const EdgeInsets.all(16),
            ),
          ],
        ),
        const SectionCaption('Timeline'),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == items.length - 1 ? 0 : 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              items[i].loan.name,
                              style: AppTypography.sans(size: 13, color: c.tx),
                            ),
                          ),
                          Text(
                            shortEnd(items[i].amortization.months),
                            style: AppTypography.sans(size: 12, color: c.mu),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(
                          value: items[i].amortization.months / maxMonths,
                          minHeight: 6,
                          backgroundColor: c.c2,
                          valueColor: AlwaysStoppedAnimation(
                            items[i].loan.type.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SectionCaption('Next EMIs'),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < nextEmis.length; i++)
                GestureDetector(
                  onTap: () => onOpen(nextEmis[i].loan),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: i < nextEmis.length - 1
                          ? Border(bottom: BorderSide(color: c.ln))
                          : null,
                    ),
                    child: Row(
                      children: [
                        IconTile(
                          icon: 'loan',
                          color: nextEmis[i].loan.type.color,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nextEmis[i].loan.name,
                                style: AppTypography.sans(
                                  size: 14,
                                  color: c.tx,
                                ),
                              ),
                              Text(
                                '${nextEmis[i].due.overdue ? 'Overdue since' : 'Due'} ${dayMonth(nextEmis[i].due.date)}'
                                '${nextEmis[i].due.overdue ? '' : ' · in ${nextEmis[i].due.days} days'}',
                                style: AppTypography.sans(
                                  size: 12,
                                  color: c.mu,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            MoneyText(
                              rupee(nextEmis[i].loan.emi),
                              style: AppTypography.sans(size: 14, color: c.tx),
                            ),
                            if (nextEmis[i].due.overdue)
                              Text(
                                'Overdue',
                                style: AppTypography.sans(
                                  size: 11,
                                  color: c.co,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SectionCaption('Your loans'),
        for (final item in items)
          AppCard(
            onTap: () => onOpen(item.loan),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconTile(icon: 'loan', color: item.loan.type.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.loan.name,
                            style: AppTypography.sans(
                              size: 14,
                              color: c.tx,
                              weight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${item.loan.lender} · ${item.loan.type.label} · ${item.loan.rate}%',
                            style: AppTypography.sans(size: 12, color: c.mu),
                          ),
                        ],
                      ),
                    ),
                    SpendIcon('chevronRight', size: 16, color: c.mu),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outstanding',
                            style: AppTypography.sans(size: 12, color: c.mu),
                          ),
                          MoneyText(
                            rupee(item.loan.outstanding),
                            style: AppTypography.serif(size: 26, color: c.tx),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'EMI',
                          style: AppTypography.sans(size: 12, color: c.mu),
                        ),
                        MoneyText(
                          rupee(item.loan.emi),
                          style: AppTypography.serif(size: 26, color: c.tx),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: item.loan.repaidRatio,
                    minHeight: 6,
                    backgroundColor: c.c2,
                    valueColor: AlwaysStoppedAnimation(item.loan.type.color),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.amortization.months} EMIs left',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ),
                    Text(
                      'ends ${shortEnd(item.amortization.months)}',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SectionCaption('Payoff curve'),
        AppCard(
          child: Column(
            children: [
              PayoffCurveChart(
                height: 120,
                series: [
                  DebtSeries(
                    history: strategies[0].result.history,
                    color: c.mu,
                    dashed: true,
                  ),
                  DebtSeries(
                    history: strategies[1].result.history,
                    color: c.co,
                    strokeWidth: 2,
                  ),
                  DebtSeries(
                    history: strategies[2].result.history,
                    color: c.ac,
                    strokeWidth: 2.6,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Now', style: AppTypography.sans(size: 12, color: c.mu)),
                  Text(
                    FinanceCalculator.resultLabel(
                      (base.result.months / 2).round(),
                      now: now,
                    ),
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                  Text(
                    FinanceCalculator.resultLabel(base.result.months, now: now),
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionCaption('Strategy comparison'),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < strategies.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i < strategies.length - 1
                        ? Border(bottom: BorderSide(color: c.ln))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: strategies[i].color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strategies[i].name,
                              style: AppTypography.sans(size: 13, color: c.tx),
                            ),
                            Text(
                              '${FinanceCalculator.resultLabel(strategies[i].result.months, now: now)} · ${strategies[i].result.months} months',
                              style: AppTypography.sans(size: 11, color: c.mu),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MoneyText(
                            rupee(strategies[i].result.interest),
                            style: AppTypography.sans(size: 13, color: c.tx),
                          ),
                          Text(
                            i == 0
                                ? 'interest'
                                : 'saves ${rupee(base.result.interest - strategies[i].result.interest)}',
                            style: AppTypography.sans(size: 11, color: c.mu),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AppButton(
          label: '+ Add loan',
          onTap: () => showAddLoanSheet(context),
          margin: const EdgeInsets.only(top: 8, bottom: 8),
        ),
      ],
    );
  }
}

class _LoanDetail extends ConsumerStatefulWidget {
  const _LoanDetail({
    required this.loan,
    required this.tab,
    required this.prepay,
    required this.extra,
    required this.onTab,
    required this.onPrepay,
    required this.onExtra,
    required this.onBack,
    required this.onDeleted,
  });

  final Loan loan;
  final _LoanTab tab;
  final double prepay;
  final double extra;
  final ValueChanged<_LoanTab> onTab;
  final ValueChanged<double> onPrepay;
  final ValueChanged<double> onExtra;
  final VoidCallback onBack;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_LoanDetail> createState() => _LoanDetailState();
}

class _LoanDetailState extends ConsumerState<_LoanDetail> {
  Future<void> _delete() async {
    await ref.read(loanRepositoryProvider).removeLoan(widget.loan.id);
    if (!mounted) return;
    widget.onDeleted();
    ref.read(toastProvider.notifier).show('Loan removed');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final loan = widget.loan;
    final now = DateTime.now();
    final due = FinanceCalculator.loanDue(loan, now: now);
    final amortization = FinanceCalculator.amortize(
      balance: loan.outstanding,
      annualRate: loan.rate,
      emi: loan.emi,
      firstDue: due.date,
    );

    return ScreenScroll(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppPill(label: '‹ All loans', onTap: widget.onBack),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconTile(icon: 'loan', color: loan.type.color, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.name,
                    style: AppTypography.serif(
                      size: 30,
                      color: c.tx,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    '${loan.lender} · ${loan.type.label}',
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedControl<_LoanTab>(
          options: const [
            SegmentedOption(_LoanTab.overview, 'Overview'),
            SegmentedOption(_LoanTab.schedule, 'Schedule'),
            SegmentedOption(_LoanTab.payments, 'Payments'),
            SegmentedOption(_LoanTab.projection, 'Projection'),
          ],
          selected: widget.tab,
          onChanged: widget.onTab,
        ),
        switch (widget.tab) {
          _LoanTab.overview => _Overview(
            loan: loan,
            due: due,
            amortization: amortization,
            onRecord: () => showRecordLoanPaymentSheet(context, loan.id),
            onEdit: () => showEditLoanSheet(context, loan.id),
            onDelete: _delete,
          ),
          _LoanTab.schedule => _Schedule(amortization: amortization),
          _LoanTab.payments => _Payments(
            loan: loan,
            onRecord: () => showRecordLoanPaymentSheet(context, loan.id),
          ),
          _LoanTab.projection => _Projection(
            loan: loan,
            prepay: widget.prepay,
            extra: widget.extra,
            onPrepay: widget.onPrepay,
            onExtra: widget.onExtra,
          ),
        },
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.loan,
    required this.due,
    required this.amortization,
    required this.onRecord,
    required this.onEdit,
    required this.onDelete,
  });

  final Loan loan;
  final LoanDue due;
  final AmortizationResult amortization;
  final VoidCallback onRecord;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final interestPaid = loan.payments.fold<double>(
      0,
      (sum, p) => sum + p.interest,
    );
    final end = DateTime.now();
    final endDate = DateTime(end.year, end.month + amortization.months, 1);

    Widget stat(String label, String value) => AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.sans(size: 12, color: c.mu)),
          Text(
            value,
            style: AppTypography.serif(size: 24, color: c.tx, height: 1.2),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outstanding principal',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              AnimatedAmount(
                value: loan.outstanding,
                style: AppTypography.serif(
                  size: 46,
                  color: c.tx,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value: loan.repaidRatio,
                  minHeight: 6,
                  backgroundColor: c.c2,
                  valueColor: AlwaysStoppedAnimation(loan.type.color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(loan.repaidRatio * 100).round()}% repaid of ${rupee(loan.original)}',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        AppCard(
          border: Border.all(color: due.overdue ? c.co : c.ln),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next EMI',
                          style: AppTypography.sans(size: 12, color: c.mu),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: rupee(loan.emi),
                                style: AppTypography.serif(
                                  size: 28,
                                  color: c.tx,
                                ),
                              ),
                              TextSpan(
                                text: ' on ${shortDate(due.date)}',
                                style: AppTypography.sans(
                                  size: 12,
                                  color: c.mu,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppPill(
                    label: due.overdue
                        ? '${-due.days} days late'
                        : due.days == 0
                        ? 'Today'
                        : 'In ${due.days} days',
                    active: !due.overdue,
                    textColor: due.overdue ? c.co : null,
                    background: due.overdue ? c.c1 : null,
                    borderColor: due.overdue ? c.co : null,
                  ),
                ],
              ),
              AppButton(
                label: 'Record payment',
                primary: true,
                centered: true,
                margin: const EdgeInsets.only(top: 12, bottom: 0),
                onTap: onRecord,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        MetricGrid(
          children: [
            stat('Interest rate', '${loan.rate}% p.a.'),
            stat('EMIs left', '${amortization.months}'),
            stat('Ends', '${monthShort[endDate.month - 1]} ${endDate.year}'),
            stat('EMI day', '${loan.emiDay}th each month'),
            stat('Interest paid so far', rupee(interestPaid)),
            stat('Interest still to pay', rupee(amortization.interest)),
            stat(
              'Total still payable',
              rupee(loan.outstanding + amortization.interest),
            ),
            stat(
              'Tenure',
              loan.tenureMonths == null
                  ? '—'
                  : '${(loan.tenureMonths! / 12 * 10).round() / 10} yrs',
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Lender',
                value: Text(
                  loan.lender,
                  style: AppTypography.sans(size: 14, color: c.mu),
                ),
                padding: const EdgeInsets.only(bottom: 10),
              ),
              KeyValueRow(
                label: 'Type',
                value: Text(
                  loan.type.label,
                  style: AppTypography.sans(size: 14, color: c.mu),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              KeyValueRow(
                label: 'Started',
                value: Text(
                  shortDate(loan.startDate),
                  style: AppTypography.sans(size: 14, color: c.mu),
                ),
                padding: const EdgeInsets.only(top: 10),
                border: false,
              ),
            ],
          ),
        ),
        AppButton(label: 'Edit loan details', onTap: onEdit),
        AppButton(
          label: 'Close & delete loan',
          color: c.co,
          centered: true,
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({required this.amortization});

  final AmortizationResult amortization;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    if (amortization.entries.isEmpty) {
      return const EmptyState(
        title: 'Fully repaid',
        message: 'There are no remaining payments.',
      );
    }
    final groups = <int, List<AmortizationEntry>>{};
    for (final entry in amortization.entries) {
      groups.putIfAbsent(entry.date.year, () => []).add(entry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${amortization.months} EMIs from ${shortDate(amortization.entries.first.date)} · tap a year to expand',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < groups.entries.length; i++)
          _ScheduleYear(
            year: groups.entries.elementAt(i).key,
            entries: groups.entries.elementAt(i).value,
            initiallyExpanded: i == 0,
          ),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Total interest',
                value: MoneyText(
                  rupee(amortization.interest),
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                padding: const EdgeInsets.only(bottom: 8),
              ),
              KeyValueRow(
                label: 'Total principal',
                value: MoneyText(
                  rupee(
                    amortization.entries.first.balance +
                        amortization.entries.first.principal -
                        amortization.entries.last.balance,
                  ),
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                padding: const EdgeInsets.only(top: 8),
                border: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleYear extends StatefulWidget {
  const _ScheduleYear({
    required this.year,
    required this.entries,
    required this.initiallyExpanded,
  });

  final int year;
  final List<AmortizationEntry> entries;
  final bool initiallyExpanded;

  @override
  State<_ScheduleYear> createState() => _ScheduleYearState();
}

class _ScheduleYearState extends State<_ScheduleYear> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final interest = widget.entries.fold<double>(
      0,
      (sum, e) => sum + e.interest,
    );
    final principal = widget.entries.fold<double>(
      0,
      (sum, e) => sum + e.principal,
    );
    return AppCard(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${widget.year}',
                style: AppTypography.sans(
                  size: 14,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.entries.length} EMIs · interest ${compactINR(interest)} · principal ${compactINR(principal)}',
                style: AppTypography.sans(size: 11, color: c.mu),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.ln)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: Text(
                      'DATE',
                      style: AppTypography.sans(
                        size: 9,
                        color: c.mu,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (final label in const [
                    'INTEREST',
                    'PRINCIPAL',
                    'BALANCE',
                  ])
                    Expanded(
                      flex: label == 'BALANCE' ? 11 : 10,
                      child: Text(
                        label,
                        textAlign: TextAlign.right,
                        style: AppTypography.sans(
                          size: 9,
                          color: c.mu,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final entry in widget.entries)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.ln)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Text(
                        '${monthShort[entry.date.month - 1]} ${entry.date.day}',
                        style: AppTypography.sans(size: 11, color: c.tx),
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: Text(
                        rupee(entry.interest),
                        textAlign: TextAlign.right,
                        style: AppTypography.sans(size: 11, color: c.tx),
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: Text(
                        rupee(entry.principal),
                        textAlign: TextAlign.right,
                        style: AppTypography.sans(size: 11, color: c.tx),
                      ),
                    ),
                    Expanded(
                      flex: 11,
                      child: Text(
                        rupee(entry.balance),
                        textAlign: TextAlign.right,
                        style: AppTypography.sans(size: 11, color: c.tx),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Payments extends ConsumerWidget {
  const _Payments({required this.loan, required this.onRecord});

  final Loan loan;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final payments = [...loan.payments]
      ..sort((a, b) => b.date.compareTo(a.date));
    final paid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final interest = payments.fold<double>(0, (sum, p) => sum + p.interest);
    final principal = payments.fold<double>(0, (sum, p) => sum + p.principal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Paid',
                amount: paid,
                formatter: compactINR,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Interest',
                amount: interest,
                formatter: compactINR,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Principal',
                amount: principal,
                formatter: compactINR,
              ),
            ),
          ],
        ),
        PrimaryButton(label: 'Record payment', onTap: onRecord),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < payments.length; i++)
                GestureDetector(
                  onTap: payments[i].imported
                      ? null
                      : () => _deletePayment(context, ref, i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: i < payments.length - 1
                          ? Border(bottom: BorderSide(color: c.ln))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payments[i].type == LoanPaymentType.emi
                                    ? 'EMI'
                                    : 'Prepayment',
                                style: AppTypography.sans(
                                  size: 14,
                                  color: c.tx,
                                ),
                              ),
                              Text(
                                '${shortDate(payments[i].date)} · interest ${rupee(payments[i].interest)} · principal ${rupee(payments[i].principal)}${payments[i].imported ? ' · imported' : ''}',
                                style: AppTypography.sans(
                                  size: 11,
                                  color: c.mu,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoneyText(
                          rupee(payments[i].amount),
                          style: AppTypography.sans(size: 14, color: c.tx),
                        ),
                      ],
                    ),
                  ),
                ),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No payments recorded yet.',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _deletePayment(BuildContext context, WidgetRef ref, int index) {
    showAppSheet<void>(
      context,
      (sheetContext) => Consumer(
        builder: (sheetContext, sheetRef, _) {
          final payment = loan.payments[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${payment.type == LoanPaymentType.emi ? 'EMI' : 'Prepayment'} · ${shortDate(payment.date)}',
                style: AppTypography.sans(
                  size: 14,
                  color: sheetContext.spend.mu,
                ),
              ),
              Text(
                rupee(payment.amount),
                style: AppTypography.serif(
                  size: 44,
                  color: sheetContext.spend.tx,
                ),
              ),
              Text(
                'Interest ${rupee(payment.interest)} · principal ${rupee(payment.principal)}',
                style: AppTypography.sans(
                  size: 12,
                  color: sheetContext.spend.mu,
                ),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Delete this payment',
                color: sheetContext.spend.co,
                centered: true,
                onTap: () async {
                  await sheetRef
                      .read(loanRepositoryProvider)
                      .deleteLoanPayment(loan.id, index);
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  sheetRef.read(toastProvider.notifier).show('Payment removed');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Projection extends StatelessWidget {
  const _Projection({
    required this.loan,
    required this.prepay,
    required this.extra,
    required this.onPrepay,
    required this.onExtra,
  });

  final Loan loan;
  final double prepay;
  final double extra;
  final ValueChanged<double> onPrepay;
  final ValueChanged<double> onExtra;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final now = DateTime.now();
    final due = FinanceCalculator.loanDue(loan, now: now);
    final current = FinanceCalculator.amortize(
      balance: loan.outstanding,
      annualRate: loan.rate,
      emi: loan.emi,
      firstDue: due.date,
    );
    final accelerated = FinanceCalculator.amortize(
      balance: loan.outstanding,
      annualRate: loan.rate,
      emi: loan.emi,
      firstDue: due.date,
      extraMonthly: extra,
      prepayment: prepay,
    );
    final monthsSaved = current.months - accelerated.months;
    final interestSaved = current.interest - accelerated.interest;
    final maxPrepay = math.max(
      10000,
      math.min(loan.outstanding, 1000000).round(),
    );
    final maxExtra = 25000.0;
    final endLabel = accelerated.months == 0
        ? 'Debt-free now'
        : FinanceCalculator.resultLabel(accelerated.months, now: now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What if I pay a little more?',
                style: AppTypography.sans(
                  size: 14,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              _SliderRow(
                label: 'One-time prepayment',
                value: rupee(prepay),
                slider: Slider(
                  value: prepay.clamp(0, maxPrepay.toDouble()),
                  min: 0,
                  max: maxPrepay.toDouble(),
                  divisions: math.max(1, (maxPrepay / 10000).round()),
                  onChanged: onPrepay,
                ),
              ),
              _SliderRow(
                label: 'Extra every month',
                value: rupee(extra),
                slider: Slider(
                  value: extra.clamp(0, maxExtra),
                  min: 0,
                  max: maxExtra,
                  divisions: 50,
                  onChanged: onExtra,
                ),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(endLabel, style: AppTypography.serif(size: 34, color: c.tx)),
              Text(
                monthsSaved > 0
                    ? '$monthsSaved months sooner · saves ${rupee(interestSaved)} interest'
                    : 'Same as your current plan',
                style: AppTypography.sans(
                  size: 12,
                  color: monthsSaved > 0 ? c.ac : c.mu,
                ),
              ),
              const SizedBox(height: 10),
              DebtAmortizationChart(
                currentHistory: [
                  loan.outstanding,
                  ...current.entries.map((e) => e.balance),
                ],
                acceleratedHistory: [
                  math.max(0, loan.outstanding - prepay),
                  ...accelerated.entries.map((e) => e.balance),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Now', style: AppTypography.sans(size: 11, color: c.mu)),
                  Text(
                    'Dashed: current plan',
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                  Text(
                    FinanceCalculator.resultLabel(current.months, now: now),
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              KeyValueRow(
                label: 'Total interest from here',
                value: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: rupee(accelerated.interest),
                        style: AppTypography.sans(size: 14, color: c.tx),
                      ),
                      TextSpan(
                        text: ' (was ${rupee(current.interest)})',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ],
                  ),
                ),
                border: false,
              ),
            ],
          ),
        ),
        if (prepay > 0)
          PrimaryButton(
            label: 'Make this prepayment',
            onTap: () => showRecordLoanPaymentSheet(
              context,
              loan.id,
              prepayment: true,
              amount: prepay,
            ),
            margin: const EdgeInsets.only(top: 0, bottom: 8),
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
  });

  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTypography.sans(size: 12, color: c.mu)),
              MoneyText(
                value,
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: theme.sliderTheme.copyWith(
            trackHeight: 4,
            activeTrackColor: c.ac,
            inactiveTrackColor: c.c2,
            thumbColor: c.ac,
            overlayColor: c.ac.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: slider,
        ),
      ],
    );
  }
}
