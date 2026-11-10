import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/custom_painters/charts.dart';
import '../../core/widgets/custom_painters/debt_amortization_chart.dart';
import '../../core/widgets/custom_painters/health_score_gauge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/month_navigator.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/services/finance_calculator.dart';
import '../shell/app_module.dart';
import 'ask_spendwiser_sheet.dart';
import 'insight_sheets.dart';

enum _InsightTab {
  spend('Spend'),
  trends('Trends'),
  forecast('Forecast'),
  health('Health'),
  patterns('Patterns'),
  merchants('Merchants'),
  netWorth('Net worth');

  const _InsightTab(this.label);
  final String label;
}

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key, required this.onNavigate});

  final ValueChanged<AppModule> onNavigate;

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  _InsightTab _tab = _InsightTab.spend;
  int _monthOffset = 0;
  int _cut = 0;

  DateTime get _month =>
      DateTime(DateTime.now().year, DateTime.now().month - _monthOffset, 1);

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final month = _month;

    return ScreenScroll(
      children: [
        const PageHeader(title: 'Insights', subtitle: 'Know your money'),
        BleedRow(
          height: 36,
          children: [
            AppPill(
              label: 'Ask Spendwiser',
              active: true,
              onTap: () => showAskSpendwiserSheet(
                context,
                onOpenLedger: () => widget.onNavigate(AppModule.ledger),
              ),
            ),
            AppPill(
              label: 'Monthly report',
              onTap: () => showMonthlyReportSheet(context, month),
            ),
            AppPill(
              label: 'Year in review',
              onTap: () => showYearInReview(context, snapshot),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MonthNavigator(
          month: month,
          onPrevious: () => setState(() => _monthOffset++),
          onNext: _monthOffset == 0
              ? null
              : () => setState(() => _monthOffset--),
          canGoNext: _monthOffset > 0,
        ),
        const SizedBox(height: 8),
        BleedRow(
          height: 34,
          children: [
            for (final tab in _InsightTab.values)
              AppPill(
                label: tab.label,
                active: _tab == tab,
                onTap: () => setState(() => _tab = tab),
              ),
          ],
        ),
        const SizedBox(height: 8),
        switch (_tab) {
          _InsightTab.spend => _SpendTab(snapshot: snapshot, month: month),
          _InsightTab.trends => _TrendsTab(snapshot: snapshot, month: month),
          _InsightTab.forecast => _ForecastTab(
            snapshot: snapshot,
            month: month,
            cut: _cut,
            onCut: (value) => setState(() => _cut = value),
          ),
          _InsightTab.health => _HealthTab(snapshot: snapshot),
          _InsightTab.patterns => _PatternsTab(
            snapshot: snapshot,
            month: month,
          ),
          _InsightTab.merchants => _MerchantsTab(
            snapshot: snapshot,
            month: month,
          ),
          _InsightTab.netWorth => _NetWorthTab(snapshot: snapshot),
        },
        Text(
          'Numbers update as you add transactions.',
          textAlign: TextAlign.center,
          style: AppTypography.sans(size: 11, color: c.mu),
        ),
      ],
    );
  }
}

class _SpendTab extends StatelessWidget {
  const _SpendTab({required this.snapshot, required this.month});

  final FinanceSnapshot snapshot;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final budgetCategories = snapshot.budgets.map((b) => b.category).toSet();
    final spends = snapshot
        .spendByCategory(month)
        .where((s) => budgetCategories.contains(s.category))
        .toList();
    final total = spends.fold<double>(0, (sum, s) => sum + s.amount);
    final previous = snapshot
        .spendByCategory(DateTime(month.year, month.month - 1, 1))
        .where((s) => budgetCategories.contains(s.category))
        .toList();
    final previousMap = {for (final s in previous) s.category: s.amount};
    MapEntry<String, double>? mover;
    for (final spend in spends) {
      final delta = spend.amount - (previousMap[spend.category] ?? 0);
      if (delta > 0 && (mover == null || delta > mover.value)) {
        mover = MapEntry(spend.category, delta);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Center(
            child: total == 0
                ? Text(
                    'No spending recorded',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  )
                : DonutChart(
                    size: 220,
                    strokeWidth: 20,
                    segments: [
                      for (final spend in spends)
                        DonutSegment(
                          value: spend.amount,
                          color: AppColors.category(spend.category),
                        ),
                    ],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SPENT',
                          style: AppTypography.sans(
                            size: 9,
                            color: c.mu,
                            letterSpacing: 1.2,
                          ),
                        ),
                        MoneyText(
                          compactINR(total),
                          style: AppTypography.serif(size: 22, color: c.tx),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < spends.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i < spends.length - 1
                        ? Border(bottom: BorderSide(color: c.ln))
                        : null,
                  ),
                  child: Row(
                    children: [
                      MerchantAvatar(
                        merchant: spends[i].category,
                        category: spends[i].category,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          spends[i].category,
                          style: AppTypography.sans(size: 14, color: c.tx),
                        ),
                      ),
                      MoneyText(
                        rupee(spends[i].amount),
                        style: AppTypography.sans(size: 14, color: c.tx),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${total == 0 ? 0 : (spends[i].amount / total * 100).round()}%',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (mover != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mover.key} is up ${rupee(mover.value)} on last month.',
                  style: AppTypography.sans(
                    size: 14,
                    color: c.tx,
                    weight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Your biggest mover.',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrendsTab extends StatelessWidget {
  const _TrendsTab({required this.snapshot, required this.month});

  final FinanceSnapshot snapshot;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final months = [
      for (var k = 5; k >= 0; k--) DateTime(month.year, month.month - k, 1),
    ];
    final flows = [for (final m in months) snapshot.flow(m)];
    final totalIncome = flows.fold<double>(0, (sum, f) => sum + f.income);
    final totalExpense = flows.fold<double>(0, (sum, f) => sum + f.expense);
    final savingsRate = totalIncome == 0
        ? 0
        : (totalIncome - totalExpense) / totalIncome * 100;
    var bestIndex = 0;
    for (var i = 1; i < flows.length; i++) {
      if (flows[i].saved > flows[bestIndex].saved) bestIndex = i;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              GroupedBarChart(
                income: [for (final f in flows) f.income],
                expense: [for (final f in flows) f.expense],
                labels: [for (final m in months) monthShort[m.month - 1]],
                height: 170,
              ),
              const SizedBox(height: 6),
              Text(
                'Income vs spend, last 6 months',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Avg savings rate',
                value: Text(
                  '${savingsRate.round()}%',
                  style: AppTypography.sans(size: 14, color: c.ac),
                ),
                padding: const EdgeInsets.only(bottom: 10),
              ),
              KeyValueRow(
                label: 'Best month',
                value: Text(
                  '${monthShort[months[bestIndex].month - 1]} · ${rupee(flows[bestIndex].saved)} saved',
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                padding: const EdgeInsets.only(top: 10),
                border: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForecastTab extends StatelessWidget {
  const _ForecastTab({
    required this.snapshot,
    required this.month,
    required this.cut,
    required this.onCut,
  });

  final FinanceSnapshot snapshot;
  final DateTime month;
  final int cut;
  final ValueChanged<int> onCut;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final now = DateTime.now();
    final days = daysInMonth(month.year, month.month);
    final current = isCurrentMonth(month, now: now) ? now.day : days;
    final daily = snapshot
        .inMonth(month)
        .where((t) => t.amount < 0 && t.category != 'Transfer');
    final spendByDay = List<double>.filled(days + 1, 0);
    for (final t in daily) {
      spendByDay[t.date.day] -= t.amount;
    }
    final cumulative = List<double>.filled(days + 1, 0);
    for (var day = 1; day <= days; day++) {
      cumulative[day] = cumulative[day - 1] + spendByDay[day];
    }
    final spent = cumulative[current];
    final projected = (spent + spent / math.max(1, current) * (days - current))
        .roundToDouble();
    final budget = snapshot.totalBudgetLimit;
    final chartValues = <double>[];
    for (var day = 0; day <= days; day++) {
      if (day <= current) {
        chartValues.add(cumulative[day]);
      } else {
        final step = (projected - spent) / math.max(1, days - current);
        chartValues.add(spent + step * (day - current));
      }
    }
    final remainingDining =
        snapshot.spentIn('Food', month) * (days - current) / math.max(1, days);
    final yearlySaving = remainingDining * cut / 100 * 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Projected month-end spend',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              AnimatedAmount(
                value: projected,
                style: AppTypography.serif(
                  size: 42,
                  color: c.tx,
                  letterSpacing: -0.8,
                ),
              ),
              AreaLineChart(
                values: chartValues,
                color: c.ac,
                height: 150,
                budgetValue: budget,
                budgetLabel: 'Budget ${compactINR(budget)}',
                forecastFrom: current,
              ),
              Text(
                projected > budget
                    ? 'On track to overshoot by ${rupee(projected - budget)}'
                    : 'On track to finish ${rupee(budget - projected)} under budget',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What if I cut dining out?',
                style: AppTypography.sans(
                  size: 14,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reduction',
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                  Text(
                    '$cut%',
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                ],
              ),
              SliderTheme(
                data: Theme.of(context).sliderTheme.copyWith(
                  trackHeight: 4,
                  activeTrackColor: c.ac,
                  inactiveTrackColor: c.c2,
                  thumbColor: c.ac,
                  overlayColor: c.ac.withValues(alpha: 0.12),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 9,
                  ),
                ),
                child: Slider(
                  value: cut.toDouble(),
                  min: 0,
                  max: 60,
                  divisions: 12,
                  onChanged: (value) => onCut(value.round()),
                ),
              ),
              Text(
                'Saves ${rupee(yearlySaving)} a year',
                style: AppTypography.sans(size: 12, color: c.ac),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthTab extends StatelessWidget {
  const _HealthTab({required this.snapshot});

  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final report = FinanceCalculator.health(snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              HealthScoreGauge(score: report.score, size: 170, strokeWidth: 9),
              Text(
                'Financial health score',
                style: AppTypography.sans(size: 14, color: c.mu),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < report.components.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == report.components.length - 1 ? 0 : 14,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              report.components[i].label,
                              style: AppTypography.sans(size: 14, color: c.tx),
                            ),
                          ),
                          Text(
                            '${report.components[i].score.round()}',
                            style: AppTypography.sans(size: 12, color: c.mu),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(
                          value: report.components[i].score / 100,
                          minHeight: 6,
                          backgroundColor: c.c2,
                          valueColor: AlwaysStoppedAnimation(
                            report.components[i].score < 50 ? c.co : c.ac,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          report.components[i].detail,
                          style: AppTypography.sans(size: 12, color: c.mu),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatternsTab extends StatelessWidget {
  const _PatternsTab({required this.snapshot, required this.month});

  final FinanceSnapshot snapshot;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final averages = FinanceCalculator.weekdayAverages(snapshot);
    final maxAverage = averages.reduce(math.max);
    final busiest = averages.indexOf(maxAverage);
    final intensity = FinanceCalculator.spendIntensity(snapshot, month);
    final maxIntensity = intensity.isEmpty
        ? 1.0
        : intensity.values.reduce(math.max);
    final days = daysInMonth(month.year, month.month);
    final now = DateTime.now();
    final elapsed = isCurrentMonth(month, now: now) ? now.day : days;
    final noSpend = List.generate(
      elapsed,
      (i) => i + 1,
    ).where((day) => (intensity[day] ?? 0) <= 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Average spend by weekday · last 90 days',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ),
              SimpleBarChart(
                values: averages,
                labels: const ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
                height: 130,
                highlightIndex: busiest,
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Spend intensity · ${monthFull[month.month - 1]}',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                children: [
                  for (var day = 1; day <= days; day++)
                    Container(
                      decoration: BoxDecoration(
                        color: (intensity[day] ?? 0) > 0
                            ? c.co.withValues(
                                alpha:
                                    0.25 +
                                    ((intensity[day] ?? 0) / maxIntensity) *
                                        0.75,
                              )
                            : c.c2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${weekdayFullSun[busiest]}s cost you the most.',
                style: AppTypography.sans(
                  size: 14,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              Text(
                '${rupee(maxAverage)} on average.',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$noSpend no-spend day${noSpend == 1 ? '' : 's'} this month.',
                style: AppTypography.sans(
                  size: 14,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              Text(
                'Out of $elapsed so far.',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MerchantsTab extends StatelessWidget {
  const _MerchantsTab({required this.snapshot, required this.month});

  final FinanceSnapshot snapshot;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final merchants = FinanceCalculator.topMerchants(snapshot, month);
    final categories = <String, String>{
      for (final t in snapshot.inMonth(month)) t.merchant: t.category,
    };
    final maxAmount = merchants.isEmpty ? 1.0 : merchants.first.value;
    final recurring = FinanceCalculator.recurringMerchants(snapshot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionCaption(
          'Top merchants',
          margin: EdgeInsets.only(top: 6, bottom: 8),
        ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < merchants.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i < merchants.length - 1
                        ? Border(bottom: BorderSide(color: c.ln))
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          MerchantAvatar(
                            merchant: merchants[i].key,
                            category: categories[merchants[i].key] ?? 'Food',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              merchants[i].key,
                              style: AppTypography.sans(size: 14, color: c.tx),
                            ),
                          ),
                          MoneyText(
                            rupee(merchants[i].value),
                            style: AppTypography.sans(size: 14, color: c.tx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: merchants[i].value / maxAmount,
                          minHeight: 4,
                          backgroundColor: c.c2,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.category(
                              categories[merchants[i].key] ?? 'Food',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          categories[merchants[i].key] ?? '',
                          style: AppTypography.sans(size: 11, color: c.mu),
                        ),
                      ),
                    ],
                  ),
                ),
              if (merchants.isEmpty)
                Text(
                  'No spending this month',
                  style: AppTypography.sans(size: 14, color: c.mu),
                ),
            ],
          ),
        ),
        const SectionCaption('Detected recurring'),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < recurring.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i < recurring.length - 1
                        ? Border(bottom: BorderSide(color: c.ln))
                        : null,
                  ),
                  child: Row(
                    children: [
                      MerchantAvatar(merchant: recurring[i], category: 'Bills'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recurring[i],
                              style: AppTypography.sans(size: 14, color: c.tx),
                            ),
                            Text(
                              'seen in 3+ months',
                              style: AppTypography.sans(size: 11, color: c.mu),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (recurring.isEmpty)
                Text(
                  'Nothing repeats yet',
                  style: AppTypography.sans(size: 14, color: c.mu),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetWorthTab extends StatelessWidget {
  const _NetWorthTab({required this.snapshot});

  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final values = FinanceCalculator.netWorthSeries(snapshot);
    final labels = [
      for (var k = 5; k >= 0; k--)
        monthShort[DateTime(
              DateTime.now().year,
              DateTime.now().month - k,
              1,
            ).month -
            1],
    ];
    final liabilities = snapshot.loans.fold<double>(
      0,
      (total, loan) => total + loan.original,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Net worth · last 6 months',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              AnimatedAmount(
                value: snapshot.netWorth,
                style: AppTypography.serif(
                  size: 44,
                  color: c.tx,
                  letterSpacing: -0.8,
                ),
              ),
              AreaLineChart(values: values, color: c.ac, height: 140),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final label in labels)
                    Text(
                      label,
                      style: AppTypography.sans(size: 9, color: c.mu),
                    ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Bank & cash',
                value: MoneyText(
                  rupee(snapshot.accountsTotal),
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                padding: const EdgeInsets.only(bottom: 10),
              ),
              KeyValueRow(
                label: 'Investments',
                value: MoneyText(
                  rupee(snapshot.investmentsValue),
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              KeyValueRow(
                label: 'Loan principal',
                value: MoneyText(
                  '−${rupee(liabilities)}',
                  style: AppTypography.sans(size: 14, color: c.co),
                ),
                padding: const EdgeInsets.only(top: 10),
                border: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
