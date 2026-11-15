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
import '../../core/widgets/custom_painters/cash_runway_chart.dart';
import '../../core/widgets/custom_painters/charts.dart';
import '../../core/widgets/custom_painters/debt_amortization_chart.dart';
import '../../core/widgets/custom_painters/health_score_gauge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/month_navigator.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/models/budget.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/transaction.dart';
import '../../data/services/finance_calculator.dart';
import '../shell/app_module.dart';
import 'ask_spendwiser_sheet.dart';
import 'insight_sheets.dart';

const _incomeGreen = Color(0xFF22C55E);
const _expenseRed = Color(0xFFEF4444);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
  int _cut = 15;

  DateTime get _month =>
      DateTime(DateTime.now().year, DateTime.now().month - _monthOffset, 1);

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final month = _month;

    return ScreenScroll(
      children: [
        const PageHeader(
          title: 'Insights',
          subtitle: 'Deep financial analysis & projections',
        ),
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
        const SizedBox(height: 10),
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
        const SizedBox(height: 14),
        Text(
          'Analysis recalculates dynamically with every transaction.',
          textAlign: TextAlign.center,
          style: AppTypography.sans(size: 11, color: c.mu),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// =============================================================================
// SPEND TAB: Categorical breakdown, Needs vs Wants, Velocity & MoM Movers
// =============================================================================
class _SpendTab extends StatelessWidget {
  const _SpendTab({required this.snapshot, required this.month});

  final FinanceSnapshot snapshot;
  final DateTime month;

  static const _essentials = {
    'Bills',
    'Groceries',
    'Rent',
    'Utilities',
    'Health',
    'Healthcare',
    'Medical',
    'Education',
    'EMI',
    'Loan',
    'Insurance',
    'Transport',
    'Fuel',
    'Transit',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final spends = snapshot.spendByCategory(month);
    final total = spends.fold<double>(0, (sum, s) => sum + s.amount);
    final totalTxs = spends.fold<int>(0, (sum, s) => sum + s.count);

    final days = daysInMonth(month.year, month.month);
    final now = DateTime.now();
    final elapsed = isCurrentMonth(month, now: now) ? now.day : days;
    final dailyAvg = elapsed > 0 ? total / elapsed : 0.0;
    final avgTxSize = totalTxs > 0 ? total / totalTxs : 0.0;

    // Previous month comparison
    final prevMonth = DateTime(month.year, month.month - 1, 1);
    final prevFlow = snapshot.flow(prevMonth);
    final prevSpends = snapshot.spendByCategory(prevMonth);
    final prevTotal = prevFlow.expense;
    final momDelta = total - prevTotal;
    final momPercent = prevTotal > 0 ? (momDelta / prevTotal * 100) : 0.0;

    // MoM Category Movers
    final prevMap = {for (final s in prevSpends) s.category: s.amount};
    MapEntry<String, double>? biggestSpike;
    MapEntry<String, double>? biggestSaved;

    for (final s in spends) {
      final prevAmt = prevMap[s.category] ?? 0.0;
      final diff = s.amount - prevAmt;
      if (diff > 0 && (biggestSpike == null || diff > biggestSpike.value)) {
        biggestSpike = MapEntry(s.category, diff);
      }
    }
    for (final entry in prevMap.entries) {
      final currentCategorySpend = spends.cast<CategorySpend?>().firstWhere(
        (s) => s?.category == entry.key,
        orElse: () => null,
      );
      final currAmt = currentCategorySpend?.amount ?? 0.0;
      final saved = entry.value - currAmt;
      if (saved > 0 && (biggestSaved == null || saved > biggestSaved.value)) {
        biggestSaved = MapEntry(entry.key, saved);
      }
    }

    // Needs vs Wants calculation
    var needsTotal = 0.0;
    var wantsTotal = 0.0;
    for (final s in spends) {
      if (_essentials.contains(s.category)) {
        needsTotal += s.amount;
      } else {
        wantsTotal += s.amount;
      }
    }
    final needsRatio = total > 0 ? (needsTotal / total).clamp(0.0, 1.0) : 0.5;

    // Budget envelope mapping
    final budgetMap = {for (final b in snapshot.budgets) b.category: b};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. KPI Metric Strip
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'TOTAL SPENT',
                value: formatINR(total),
                subLabel:
                    '${momDelta >= 0 ? '+' : ''}${formatINR(momDelta)} (${momPercent >= 0 ? '+' : ''}${momPercent.round()}%) MoM',
                subColor: momDelta > 0 ? _expenseRed : _incomeGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'DAILY BURN',
                value: formatINR(dailyAvg),
                subLabel: 'Across $elapsed days',
                subColor: c.mu,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'AVG TICKET',
                value: formatINR(avgTxSize),
                subLabel: '$totalTxs transactions',
                subColor: c.mu,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Donut Breakdown Hero
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            children: [
              total == 0
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'No expenses recorded in ${monthFull[month.month - 1]}',
                        style: AppTypography.sans(size: 14, color: c.mu),
                      ),
                    )
                  : DonutChart(
                      size: 210,
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
                            'OUTFLOW',
                            style: AppTypography.sans(
                              size: 10,
                              color: c.mu,
                              letterSpacing: 1.2,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedAmount(
                            value: total,
                            formatter: compactINR,
                            style: AppTypography.serif(
                              size: 24,
                              color: c.tx,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '${spends.length} categories',
                            style: AppTypography.sans(size: 10, color: c.mu),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Needs vs Wants Split (50/30/20 guideline)
        if (total > 0)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Needs vs Wants Breakdown',
                      style: AppTypography.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.tx,
                      ),
                    ),
                    Text(
                      '50/30/20 Guideline',
                      style: AppTypography.sans(size: 11, color: c.mu),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        Expanded(
                          flex: math.max(1, (needsRatio * 100).round()),
                          child: const ColoredBox(color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: math.max(1, ((1 - needsRatio) * 100).round()),
                          child: const ColoredBox(color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Essentials: ${formatINR(needsTotal)} (${(needsRatio * 100).round()}%)',
                          style: AppTypography.sans(size: 11, color: c.mu),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Discretionary: ${formatINR(wantsTotal)} (${((1 - needsRatio) * 100).round()}%)',
                          style: AppTypography.sans(size: 11, color: c.mu),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),

        // 4. MoM Movers & Anomalies
        if (biggestSpike != null || biggestSaved != null)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Month-over-Month Velocity',
                  style: AppTypography.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.tx,
                  ),
                ),
                const SizedBox(height: 8),
                if (biggestSpike != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 18,
                          color: _expenseRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${biggestSpike.key} surged by ${formatINR(biggestSpike.value)} vs last month.',
                            style: AppTypography.sans(size: 12, color: c.tx),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (biggestSaved != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_down_rounded,
                        size: 18,
                        color: _incomeGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${biggestSaved.key} dropped by ${formatINR(biggestSaved.value)} (saved vs last mo).',
                          style: AppTypography.sans(size: 12, color: c.tx),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),

        // 5. Category Details List with Budget Envelope Trackers
        const SectionCaption('Category breakdown & envelopes'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < spends.length; i++) ...[
                _CategoryDetailRow(
                  spend: spends[i],
                  totalSpend: total,
                  budget: budgetMap[spends[i].category],
                ),
                if (i < spends.length - 1)
                  Divider(color: c.ln.withValues(alpha: 0.6), height: 1),
              ],
              if (spends.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No categorized spend for this month.',
                    style: AppTypography.sans(size: 13, color: c.mu),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryDetailRow extends StatelessWidget {
  const _CategoryDetailRow({
    required this.spend,
    required this.totalSpend,
    this.budget,
  });

  final CategorySpend spend;
  final double totalSpend;
  final Budget? budget;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final percent = totalSpend > 0 ? (spend.amount / totalSpend * 100).round() : 0;
    final hasBudget = budget != null && budget!.limit > 0;
    final budgetRatio = hasBudget ? (spend.amount / budget!.limit).clamp(0.0, 1.5) : 0.0;
    final isOverBudget = hasBudget && spend.amount > budget!.limit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              MerchantAvatar(
                merchant: spend.category,
                category: spend.category,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            spend.category,
                            style: AppTypography.sans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: c.tx,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: c.c2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${spend.count} txs',
                            style: AppTypography.sans(size: 10, color: c.mu),
                          ),
                        ),
                      ],
                    ),
                    if (hasBudget)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          isOverBudget
                              ? 'Exceeded by ${formatINR(spend.amount - budget!.limit)}'
                              : '${formatINR(budget!.limit - spend.amount)} left of ${compactINR(budget!.limit)}',
                          style: AppTypography.sans(
                            size: 10,
                            color: isOverBudget ? _expenseRed : c.mu,
                            weight: isOverBudget ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    formatINR(spend.amount),
                    style: AppTypography.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: c.tx,
                    ),
                  ),
                  Text(
                    '$percent% of total',
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ),
            ],
          ),
          if (hasBudget) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (budgetRatio).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: c.c2,
                valueColor: AlwaysStoppedAnimation(
                  isOverBudget ? _expenseRed : AppColors.category(spend.category),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// TRENDS TAB: Multi-Month Cash Flow, Growth, Lifestyle Creep & Savings Volatility
// =============================================================================
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
    final totalSaved = totalIncome - totalExpense;
    final avgSavingsRate = totalIncome > 0 ? (totalSaved / totalIncome * 100) : 0.0;

    final incomeGrowth = FinanceCalculator.incomeGrowth(snapshot);
    final lifestyleCreep = FinanceCalculator.lifestyleCreep(snapshot);

    var bestIndex = 0;
    var highestExpenseIndex = 0;
    for (var i = 1; i < flows.length; i++) {
      if (flows[i].saved > flows[bestIndex].saved) bestIndex = i;
      if (flows[i].expense > flows[highestExpenseIndex].expense) {
        highestExpenseIndex = i;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 6-Month Metric Summary Strip
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'AVG SAVINGS RATE',
                value: '${avgSavingsRate.round()}%',
                subLabel: '${formatINR(totalSaved)} 6-mo net',
                subColor: avgSavingsRate >= 0 ? _incomeGreen : _expenseRed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'INCOME GROWTH',
                value: '${incomeGrowth >= 0 ? '+' : ''}${incomeGrowth.round()}%',
                subLabel: 'vs prior quarter',
                subColor: incomeGrowth >= 0 ? _incomeGreen : _expenseRed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'LIFESTYLE CREEP',
                value: '${lifestyleCreep >= 0 ? '+' : ''}${lifestyleCreep.round()}%',
                subLabel: 'Expense acceleration',
                subColor: lifestyleCreep > 5 ? _expenseRed : _incomeGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. 6-Month In vs Out Grouped Bar Chart
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cash flow · 6 months',
                    style: AppTypography.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: c.tx,
                    ),
                  ),
                  Row(
                    children: [
                      _LegendPill(color: _incomeGreen, label: 'Income'),
                      const SizedBox(width: 10),
                      _LegendPill(color: _expenseRed, label: 'Expense'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GroupedBarChart(
                income: [for (final f in flows) f.income],
                expense: [for (final f in flows) f.expense],
                labels: [for (final m in months) monthShort[m.month - 1]],
                incomeColor: _incomeGreen,
                expenseColor: _expenseRed,
                height: 165,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Month by Month Performance Grid
        const SectionCaption('Monthly cash flow ledger'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (var i = months.length - 1; i >= 0; i--) ...[
                _MonthlyFlowRow(
                  month: months[i],
                  flow: flows[i],
                  isBestMonth: i == bestIndex && flows[i].saved > 0,
                  isHighestBurn: i == highestExpenseIndex,
                ),
                if (i > 0)
                  Divider(color: c.ln.withValues(alpha: 0.6), height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 4. Milestone Highlights
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Best Month',
                          style: AppTypography.sans(
                            size: 11,
                            color: c.mu,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${monthShort[months[bestIndex].month - 1]} ${months[bestIndex].year}',
                      style: AppTypography.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: c.tx,
                      ),
                    ),
                    Text(
                      'Saved ${formatINR(flows[bestIndex].saved)} (${flows[bestIndex].savingsRate.round()}%)',
                      style: AppTypography.sans(size: 11, color: _incomeGreen),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: _expenseRed,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Peak Outflow',
                          style: AppTypography.sans(
                            size: 11,
                            color: c.mu,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${monthShort[months[highestExpenseIndex].month - 1]} ${months[highestExpenseIndex].year}',
                      style: AppTypography.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: c.tx,
                      ),
                    ),
                    Text(
                      'Spent ${formatINR(flows[highestExpenseIndex].expense)}',
                      style: AppTypography.sans(size: 11, color: _expenseRed),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthlyFlowRow extends StatelessWidget {
  const _MonthlyFlowRow({
    required this.month,
    required this.flow,
    this.isBestMonth = false,
    this.isHighestBurn = false,
  });

  final DateTime month;
  final MonthFlow flow;
  final bool isBestMonth;
  final bool isHighestBurn;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final isPositive = flow.saved >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthShort[month.month - 1],
                  style: AppTypography.sans(
                    size: 13,
                    weight: FontWeight.w700,
                    color: c.tx,
                  ),
                ),
                Text(
                  '${month.year}',
                  style: AppTypography.sans(size: 10, color: c.mu),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatINR(flow.income),
                        style: AppTypography.sans(
                          size: 12,
                          color: _incomeGreen,
                          weight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        formatINR(flow.expense),
                        style: AppTypography.sans(
                          size: 12,
                          color: _expenseRed,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isPositive ? '+' : ''}${formatINR(flow.saved)}',
                      style: AppTypography.sans(
                        size: 13,
                        weight: FontWeight.w700,
                        color: isPositive ? _incomeGreen : _expenseRed,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: (isPositive ? _incomeGreen : _expenseRed)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${flow.savingsRate.round()}% saved',
                        style: AppTypography.sans(
                          size: 10,
                          weight: FontWeight.w600,
                          color: isPositive ? _incomeGreen : _expenseRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FORECAST TAB: Month-End Spend Projection, Cash Runway & What-If Simulator
// =============================================================================
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
    final daysLeft = math.max(0, days - current);

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
    final burnRate = spent / math.max(1, current);
    final projected = (spent + burnRate * daysLeft).roundToDouble();
    final budget = snapshot.totalBudgetLimit;
    final hasBudget = budget > 0;
    final isUnderBudget = hasBudget && projected <= budget;
    final safeDailySpend = daysLeft > 0 && hasBudget
        ? math.max(0.0, (budget - spent) / daysLeft)
        : 0.0;

    // Cumulative chart trajectory values
    final chartValues = <double>[];
    for (var day = 0; day <= days; day++) {
      if (day <= current) {
        chartValues.add(cumulative[day]);
      } else {
        final step = (projected - spent) / math.max(1, daysLeft);
        chartValues.add(spent + step * (day - current));
      }
    }

    // 30-Day Cash Runway Projection
    final runway = FinanceCalculator.cashRunway(snapshot);
    final runwayValues = runway.points.map((p) => p.balance).toList();
    var lowestIndex = 0;
    for (var i = 1; i < runwayValues.length; i++) {
      if (runwayValues[i] < runwayValues[lowestIndex]) lowestIndex = i;
    }
    final paydayIndex = runway.payday != null
        ? runway.points.indexWhere(
            (p) => _isSameDay(p.date, runway.payday!),
          )
        : null;

    final billIndices = <int>{};
    for (final event in runway.events) {
      if (!event.isIncome) {
        final idx = runway.points.indexWhere(
          (p) => _isSameDay(p.date, event.date),
        );
        if (idx != -1) billIndices.add(idx);
      }
    }

    // Scenario Planning: Discretionary spend reduction
    final spends = snapshot.spendByCategory(month);
    const essentials = _SpendTab._essentials;
    final discretionaryMonthly = spends
        .where((s) => !essentials.contains(s.category))
        .fold<double>(0, (sum, s) => sum + s.amount);
    final monthlySaving = (discretionaryMonthly * cut / 100).roundToDouble();
    final yearlySaving = monthlySaving * 12;
    final runwayExtensionDays = burnRate > 0 ? (monthlySaving / burnRate).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Month-End Run-Rate Forecast Card
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PROJECTED MONTH-END OUTFLOW',
                    style: AppTypography.sans(
                      size: 10,
                      color: c.mu,
                      letterSpacing: 1.1,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (hasBudget)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isUnderBudget ? _incomeGreen : _expenseRed)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isUnderBudget
                            ? '−${formatINR(budget - projected)} Under Budget'
                            : '+${formatINR(projected - budget)} Overshoot',
                        style: AppTypography.sans(
                          size: 10,
                          weight: FontWeight.w700,
                          color: isUnderBudget ? _incomeGreen : _expenseRed,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedAmount(
                value: projected,
                formatter: (value) => formatINR(value),
                style: AppTypography.serif(
                  size: 38,
                  color: c.tx,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              AreaLineChart(
                values: chartValues,
                color: isUnderBudget ? _incomeGreen : _expenseRed,
                height: 145,
                budgetValue: hasBudget ? budget : null,
                budgetLabel: hasBudget ? 'Budget ${compactINR(budget)}' : null,
                forecastFrom: current,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ForecastMetricCol(
                    label: 'Current spend',
                    value: formatINR(spent),
                  ),
                  _ForecastMetricCol(
                    label: 'Daily burn rate',
                    value: '${formatINR(burnRate)}/day',
                  ),
                  if (hasBudget && daysLeft > 0)
                    _ForecastMetricCol(
                      label: 'Safe daily pace',
                      value: '${formatINR(safeDailySpend)}/day',
                      color: isUnderBudget ? _incomeGreen : _expenseRed,
                    )
                  else
                    _ForecastMetricCol(
                      label: 'Days remaining',
                      value: '$daysLeft days',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. 30-Day Cash Runway Projection (Checking & Cash balance)
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '30-Day Cash Runway Curve',
                    style: AppTypography.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: c.tx,
                    ),
                  ),
                  if (runway.isShortfall)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _expenseRed.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Shortfall Risk',
                        style: AppTypography.sans(
                          size: 10,
                          weight: FontWeight.w700,
                          color: _expenseRed,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Starting balance: ${formatINR(runway.startingBalance)} · Lowest: ${formatINR(runway.lowestBalance)} on ${monthShort[runway.lowestDate.month - 1]} ${runway.lowestDate.day}',
                style: AppTypography.sans(size: 11, color: c.mu),
              ),
              const SizedBox(height: 10),
              CashRunwayChart(
                values: runwayValues,
                lowestIndex: lowestIndex,
                color: runway.isShortfall ? _expenseRed : _incomeGreen,
                billIndices: billIndices,
                paydayIndex: paydayIndex != -1 ? paydayIndex : null,
                height: 130,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    runway.hasPayday
                        ? 'Next payday: ${monthShort[runway.payday!.month - 1]} ${runway.payday!.day} (+${formatINR(runway.expectedIncome)})'
                        : 'No recurring payday detected in window',
                    style: AppTypography.sans(
                      size: 11,
                      color: runway.hasPayday ? _incomeGreen : c.mu,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${runway.events.length} commitments',
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Upcoming Runway Commitments (Bills, EMIs, Subscriptions)
        if (runway.events.isNotEmpty) ...[
          const SectionCaption('Upcoming commitments in window'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (var i = 0; i < math.min(5, runway.events.length); i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: (runway.events[i].isIncome
                                    ? _incomeGreen
                                    : _expenseRed)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            runway.events[i].isIncome
                                ? Icons.arrow_downward_rounded
                                : Icons.receipt_long_rounded,
                            size: 15,
                            color: runway.events[i].isIncome
                                ? _incomeGreen
                                : _expenseRed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                runway.events[i].label,
                                style: AppTypography.sans(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: c.tx,
                                ),
                              ),
                              Text(
                                '${monthShort[runway.events[i].date.month - 1]} ${runway.events[i].date.day}',
                                style: AppTypography.sans(size: 10, color: c.mu),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${runway.events[i].isIncome ? '+' : '−'}${formatINR(runway.events[i].amount.abs())}',
                          style: AppTypography.sans(
                            size: 13,
                            weight: FontWeight.w600,
                            color: runway.events[i].isIncome
                                ? _incomeGreen
                                : c.tx,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < math.min(5, runway.events.length) - 1)
                    Divider(color: c.ln.withValues(alpha: 0.6), height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 4. Interactive "What-If" Scenario Simulator
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'What-If: Trim Discretionary Spend',
                    style: AppTypography.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: c.tx,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.ac.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Trim $cut%',
                      style: AppTypography.sans(
                        size: 11,
                        weight: FontWeight.w700,
                        color: c.ac,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Simulate trimming dining, shopping & entertainment',
                style: AppTypography.sans(size: 11, color: c.mu),
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: Theme.of(context).sliderTheme.copyWith(
                  trackHeight: 4,
                  activeTrackColor: c.ac,
                  inactiveTrackColor: c.c2,
                  thumbColor: c.ac,
                  overlayColor: c.ac.withValues(alpha: 0.14),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: cut.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 10,
                  onChanged: (value) => onCut(value.round()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ForecastMetricCol(
                    label: 'Monthly savings',
                    value: '+${formatINR(monthlySaving)}',
                    color: _incomeGreen,
                  ),
                  _ForecastMetricCol(
                    label: 'Annual potential',
                    value: '+${formatINR(yearlySaving)}',
                    color: _incomeGreen,
                  ),
                  _ForecastMetricCol(
                    label: 'Runway extended',
                    value: '+$runwayExtensionDays days',
                    color: c.ac,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForecastMetricCol extends StatelessWidget {
  const _ForecastMetricCol({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.sans(size: 10, color: c.mu),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.sans(
            size: 13,
            weight: FontWeight.w600,
            color: color ?? c.tx,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HEALTH TAB: 5-Pillar Score, Radial Gauge, Actionable Prescriptions & Ratios
// =============================================================================
class _HealthTab extends StatelessWidget {
  const _HealthTab({required this.snapshot});

  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final report = FinanceCalculator.health(snapshot);
    final score = report.score;

    final (tierLabel, tierColor) = score >= 85
        ? ('Exceptional', _incomeGreen)
        : score >= 70
            ? ('Healthy', _incomeGreen)
            : score >= 50
                ? ('Moderate', const Color(0xFFF59E0B))
                : ('At Risk', _expenseRed);

    // Key financial ratios
    final monthlyBurn = math.max(1.0, FinanceCalculator.avgMonthlySpend(snapshot));
    final emergencyRunwayMonths = (snapshot.liquidAssets / monthlyBurn).toStringAsFixed(1);
    final cardUtil = snapshot.cardLimitTotal > 0
        ? (snapshot.cardDues / snapshot.cardLimitTotal * 100).round()
        : 0;
    final totalAssets = snapshot.accountsTotal + snapshot.investmentsValue;
    final totalDebt = snapshot.cardDues + snapshot.loanOutstanding;
    final debtToAsset = totalAssets > 0 ? (totalDebt / totalAssets * 100).round() : 0;

    // Actionable Prescriptions Engine
    final prescriptions = <String>[];
    for (final comp in report.components) {
      if (comp.score < 60) {
        if (comp.label.contains('Savings')) {
          prescriptions.add('Automate savings: Aim to transfer 20%+ of income on payday before discretionary spending.');
        } else if (comp.label.contains('Safety')) {
          prescriptions.add('Build liquid reserves: You have under 3 months of emergency expenses. Direct funds to savings.');
        } else if (comp.label.contains('Card')) {
          prescriptions.add('Lower card utilization: Keep card balances below 30% of limit to improve credit standing.');
        } else if (comp.label.contains('Debt')) {
          prescriptions.add('Heavy loan burden: EMIs consume a high share of income. Consider paying extra toward principal.');
        } else if (comp.label.contains('Budget')) {
          prescriptions.add('Envelope overshoots: Tighten overspending categories or adjust realistic budget envelopes.');
        }
      }
    }
    if (prescriptions.isEmpty) {
      prescriptions.add('Outstanding financial discipline! All core health pillars meet or exceed recommended benchmarks.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Health Score Gauge Hero
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              HealthScoreGauge(score: score, size: 180, strokeWidth: 10),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$tierLabel Status',
                  style: AppTypography.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: tierColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Composite of 5 foundational financial pillars',
                style: AppTypography.sans(size: 11, color: c.mu),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. The 5 Core Health Pillars
        const SectionCaption('Core diagnostic pillars'),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var i = 0; i < report.components.length; i++) ...[
                _HealthPillarRow(component: report.components[i]),
                if (i < report.components.length - 1)
                  Divider(color: c.ln.withValues(alpha: 0.6), height: 18),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Actionable Financial Prescriptions
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    size: 18,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Prescriptions & Next Steps',
                    style: AppTypography.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: c.tx,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final tip in prescriptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 6),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.mu,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tip,
                          style: AppTypography.sans(size: 12, color: c.tx),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 4. Financial Ratios Matrix
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'EMERGENCY BUFFER',
                value: '$emergencyRunwayMonths mo',
                subLabel: 'Recommended: 6 mo',
                subColor: double.parse(emergencyRunwayMonths) >= 6
                    ? _incomeGreen
                    : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'CARD UTILIZATION',
                value: '$cardUtil%',
                subLabel: 'Target: < 30%',
                subColor: cardUtil <= 30 ? _incomeGreen : _expenseRed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'DEBT TO ASSET',
                value: '$debtToAsset%',
                subLabel: 'Solvency check',
                subColor: debtToAsset <= 40 ? _incomeGreen : _expenseRed,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HealthPillarRow extends StatelessWidget {
  const _HealthPillarRow({required this.component});

  final HealthComponent component;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final score = component.score.round();
    final color = score >= 70
        ? _incomeGreen
        : score >= 50
            ? const Color(0xFFF59E0B)
            : _expenseRed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              component.label,
              style: AppTypography.sans(
                size: 13,
                weight: FontWeight.w600,
                color: c.tx,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$score / 100',
                style: AppTypography.sans(
                  size: 11,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (component.score / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: c.c2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          component.detail,
          style: AppTypography.sans(size: 11, color: c.mu),
        ),
      ],
    );
  }
}

// =============================================================================
// PATTERNS TAB: Weekday Velocity, Heatmap Calendar, No-Spend Streak & Ticket Sizes
// =============================================================================
class _PatternsTab extends StatefulWidget {
  const _PatternsTab({required this.snapshot, required this.month});

  final FinanceSnapshot snapshot;
  final DateTime month;

  @override
  State<_PatternsTab> createState() => _PatternsTabState();
}

class _PatternsTabState extends State<_PatternsTab> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final averages = FinanceCalculator.weekdayAverages(widget.snapshot);
    final maxAverage = averages.reduce(math.max);
    final busiest = averages.indexOf(maxAverage);

    final weekdayAvg = (averages[1] + averages[2] + averages[3] + averages[4] + averages[5]) / 5;
    final weekendAvg = (averages[0] + averages[6]) / 2;

    final intensity = FinanceCalculator.spendIntensity(widget.snapshot, widget.month);
    final maxIntensity = intensity.isEmpty
        ? 1.0
        : math.max(1.0, intensity.values.reduce(math.max));

    final days = daysInMonth(widget.month.year, widget.month.month);
    final now = DateTime.now();
    final elapsed = isCurrentMonth(widget.month, now: now) ? now.day : days;
    final noSpendDays = List.generate(elapsed, (i) => i + 1)
        .where((day) => (intensity[day] ?? 0) <= 0)
        .length;
    final streak = FinanceCalculator.streak(widget.snapshot);

    // Ticket Size Breakdown
    final monthTxs = widget.snapshot
        .inMonth(widget.month)
        .where((t) => t.amount < 0 && t.category != 'Transfer')
        .toList();
    final smallTxs = monthTxs.where((t) => -t.amount < 500).toList();
    final midTxs = monthTxs.where((t) => -t.amount >= 500 && -t.amount < 2500).toList();
    final largeTxs = monthTxs.where((t) => -t.amount >= 2500).toList();

    Transaction? largestTx;
    for (final t in monthTxs) {
      if (largestTx == null || t.amount < largestTx.amount) largestTx = t;
    }

    // Calendar layout: first day of month weekday offset (Sunday = 0)
    final firstWeekday = DateTime(widget.month.year, widget.month.month, 1).weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Day of Week Velocity Chart
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Average spend by day of week',
                    style: AppTypography.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: c.tx,
                    ),
                  ),
                  Text(
                    'Last 90 days',
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SimpleBarChart(
                values: averages,
                labels: const ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
                height: 130,
                highlightIndex: busiest,
                highlightColor: c.ac,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${weekdayFullSun[busiest]} is your highest spend day (${formatINR(maxAverage)} avg)',
                    style: AppTypography.sans(
                      size: 11,
                      color: c.tx,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Weekday: ${compactINR(weekdayAvg)} · Weekend: ${compactINR(weekendAvg)}',
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Spend Intensity Heatmap (Calendar view)
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Spend Heatmap · ${monthFull[widget.month.month - 1]}',
                    style: AppTypography.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: c.tx,
                    ),
                  ),
                  Text(
                    '$noSpendDays zero-spend days',
                    style: AppTypography.sans(size: 11, color: _incomeGreen),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Weekday header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _CalendarHeaderCell('S'),
                  _CalendarHeaderCell('M'),
                  _CalendarHeaderCell('T'),
                  _CalendarHeaderCell('W'),
                  _CalendarHeaderCell('T'),
                  _CalendarHeaderCell('F'),
                  _CalendarHeaderCell('S'),
                ],
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: firstWeekday + days,
                itemBuilder: (context, index) {
                  if (index < firstWeekday) return const SizedBox.shrink();
                  final day = index - firstWeekday + 1;
                  final daySpend = intensity[day] ?? 0.0;
                  final isElapsed = day <= elapsed;
                  final isSelected = _selectedDay == day;

                  final tileColor = !isElapsed
                      ? c.c2.withValues(alpha: 0.3)
                      : daySpend <= 0
                          ? c.c2
                          : Color.lerp(
                              c.co.withValues(alpha: 0.28),
                              c.co,
                              (daySpend / maxIntensity).clamp(0.0, 1.0),
                            )!;

                  return GestureDetector(
                    onTap: isElapsed
                        ? () => setState(
                              () => _selectedDay =
                                  _selectedDay == day ? null : day,
                            )
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(6),
                        border: isSelected
                            ? Border.all(color: c.tx, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: AppTypography.sans(
                          size: 10,
                          weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isElapsed
                              ? (daySpend > maxIntensity * 0.5 ? Colors.white : c.tx)
                              : c.mu.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_selectedDay != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.c2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${monthShort[widget.month.month - 1]} $_selectedDay spend',
                        style: AppTypography.sans(size: 12, color: c.tx),
                      ),
                      Text(
                        formatINR(intensity[_selectedDay] ?? 0.0),
                        style: AppTypography.sans(
                          size: 12,
                          weight: FontWeight.w700,
                          color: (intensity[_selectedDay] ?? 0) > 0
                              ? _expenseRed
                              : _incomeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. No-Spend Habit Stats
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'ZERO-SPEND DAYS',
                value: '$noSpendDays of $elapsed',
                subLabel: '${elapsed > 0 ? (noSpendDays / elapsed * 100).round() : 0}% of days',
                subColor: _incomeGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'ACTIVE STREAK',
                value: '$streak day${streak == 1 ? '' : 's'}',
                subLabel: 'Under daily budget',
                subColor: streak > 2 ? _incomeGreen : c.mu,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4. Ticket Size Distribution & Largest Outflow
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Transaction Size Distribution',
                style: AppTypography.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: c.tx,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _TicketTierCol(
                      label: '< ₹500',
                      subLabel: 'Micro',
                      count: smallTxs.length,
                      total: smallTxs.fold(0.0, (sum, t) => sum - t.amount),
                    ),
                  ),
                  Expanded(
                    child: _TicketTierCol(
                      label: '₹500 – ₹2.5k',
                      subLabel: 'Medium',
                      count: midTxs.length,
                      total: midTxs.fold(0.0, (sum, t) => sum - t.amount),
                    ),
                  ),
                  Expanded(
                    child: _TicketTierCol(
                      label: '> ₹2.5k',
                      subLabel: 'Large',
                      count: largeTxs.length,
                      total: largeTxs.fold(0.0, (sum, t) => sum - t.amount),
                    ),
                  ),
                ],
              ),
              if (largestTx != null) ...[
                const SizedBox(height: 12),
                Divider(color: c.ln.withValues(alpha: 0.6), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Month\'s largest single purchase: ${largestTx.merchant} (${formatINR(-largestTx.amount)})',
                        style: AppTypography.sans(size: 12, color: c.tx),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarHeaderCell extends StatelessWidget {
  const _CalendarHeaderCell(this.day);
  final String day;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        day,
        style: AppTypography.sans(size: 10, color: context.spend.mu),
      ),
    );
  }
}

class _TicketTierCol extends StatelessWidget {
  const _TicketTierCol({
    required this.label,
    required this.subLabel,
    required this.count,
    required this.total,
  });

  final String label;
  final String subLabel;
  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.sans(size: 12, weight: FontWeight.w700, color: c.tx),
        ),
        Text(
          '$count txs · ${compactINR(total)}',
          style: AppTypography.sans(size: 10, color: c.mu),
        ),
      ],
    );
  }
}

// =============================================================================
// MERCHANTS TAB: Top Vendors, Concentration Analysis & Recurring Subscriptions
// =============================================================================
class _MerchantsTab extends StatelessWidget {
  const _MerchantsTab({required this.snapshot, required this.month});

  final FinanceSnapshot snapshot;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final merchants = FinanceCalculator.topMerchants(snapshot, month, limit: 10);
    final monthTxs = snapshot.inMonth(month);
    final categories = <String, String>{
      for (final t in monthTxs) t.merchant: t.category,
    };
    final maxAmount = merchants.isEmpty ? 1.0 : merchants.first.value;
    final totalSpent = snapshot.expensesIn(month);

    // Concentration analysis: Top 3 share
    final top3Sum = merchants.take(3).fold<double>(0, (sum, m) => sum + m.value);
    final top3Share = totalSpent > 0 ? (top3Sum / totalSpent * 100).round() : 0;

    // Active subscriptions & recurring commitments
    final recurring = snapshot.recurring.where((r) => r.active && !r.isIncome).toList();
    final subscriptions = snapshot.subscriptions.where((s) => s.active).toList();
    final monthlyFixedCost = snapshot.monthlySubscriptionCost +
        recurring.fold<double>(0, (sum, r) => sum + r.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Merchant Concentration Risk Banner
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (top3Share > 55 ? _expenseRed : c.ac)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  size: 20,
                  color: top3Share > 55 ? _expenseRed : c.ac,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 3 Merchants: $top3Share% of Outflow',
                      style: AppTypography.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.tx,
                      ),
                    ),
                    Text(
                      top3Share > 55
                          ? 'High concentration: significant spend absorbed by few vendors.'
                          : 'Healthy vendor distribution across diverse merchants.',
                      style: AppTypography.sans(size: 11, color: c.mu),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Top Merchants Leaderboard
        const SectionCaption('Top merchants leaderboard'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < merchants.length; i++) ...[
                _MerchantLeaderboardRow(
                  rank: i + 1,
                  merchant: merchants[i].key,
                  amount: merchants[i].value,
                  maxAmount: maxAmount,
                  totalSpent: totalSpent,
                  category: categories[merchants[i].key] ?? 'Food',
                  txCount: monthTxs
                      .where(
                        (t) =>
                            t.merchant == merchants[i].key &&
                            t.amount < 0 &&
                            t.category != 'Transfer',
                      )
                      .length,
                ),
                if (i < merchants.length - 1)
                  Divider(color: c.ln.withValues(alpha: 0.6), height: 1),
              ],
              if (merchants.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No merchant expenses this month.',
                    style: AppTypography.sans(size: 13, color: c.mu),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Fixed Recurring & Subscriptions
        SectionCaption(
          'Active subscriptions & recurring (${formatINR(monthlyFixedCost)}/mo)',
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < subscriptions.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      MerchantAvatar(
                        merchant: subscriptions[i].name,
                        category: 'Bills',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscriptions[i].name,
                              style: AppTypography.sans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: c.tx,
                              ),
                            ),
                            Text(
                              'Renews in ${subscriptions[i].renewsInDays} days · ${subscriptions[i].category}',
                              style: AppTypography.sans(size: 10, color: c.mu),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${formatINR(subscriptions[i].price)}/mo',
                        style: AppTypography.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: c.tx,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < subscriptions.length - 1 || recurring.isNotEmpty)
                  Divider(color: c.ln.withValues(alpha: 0.6), height: 1),
              ],
              for (var i = 0; i < recurring.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      MerchantAvatar(
                        merchant: recurring[i].name,
                        category: recurring[i].category,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recurring[i].name,
                              style: AppTypography.sans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: c.tx,
                              ),
                            ),
                            Text(
                              'Recurring ${recurring[i].frequency.name}',
                              style: AppTypography.sans(size: 10, color: c.mu),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatINR(recurring[i].amount),
                        style: AppTypography.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: c.tx,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < recurring.length - 1)
                  Divider(color: c.ln.withValues(alpha: 0.6), height: 1),
              ],
              if (subscriptions.isEmpty && recurring.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'No recurring subscriptions detected.',
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MerchantLeaderboardRow extends StatelessWidget {
  const _MerchantLeaderboardRow({
    required this.rank,
    required this.merchant,
    required this.amount,
    required this.maxAmount,
    required this.totalSpent,
    required this.category,
    required this.txCount,
  });

  final int rank;
  final String merchant;
  final double amount;
  final double maxAmount;
  final double totalSpent;
  final String category;
  final int txCount;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final percent = totalSpent > 0 ? (amount / totalSpent * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '$rank',
                  style: AppTypography.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: c.mu,
                  ),
                ),
              ),
              MerchantAvatar(merchant: merchant, category: category),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant,
                      style: AppTypography.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.tx,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$category · $txCount transactions',
                      style: AppTypography.sans(size: 10, color: c.mu),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    formatINR(amount),
                    style: AppTypography.sans(
                      size: 13,
                      weight: FontWeight.w700,
                      color: c.tx,
                    ),
                  ),
                  Text(
                    '$percent% of spend',
                    style: AppTypography.sans(size: 10, color: c.mu),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (amount / maxAmount).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: c.c2,
              valueColor: AlwaysStoppedAnimation(AppColors.category(category)),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// NET WORTH TAB: Balance Sheet, 6-Month Trajectory, Solvency & Debt Payoff Engine
// =============================================================================
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

    // Assets breakdown
    final liquidCash = snapshot.accountsTotal;
    final investments = snapshot.investmentsValue;
    final fixedAssets = FinanceSnapshot.propertyValue;
    final totalAssets = liquidCash + investments + fixedAssets;

    // Liabilities breakdown
    final cardDues = snapshot.cardDues;
    final loans = snapshot.loanOutstanding;
    final totalLiabilities = cardDues + loans;

    final netWorth = snapshot.netWorth;
    final initialNW = values.isNotEmpty ? values.first : netWorth;
    final nwDelta = netWorth - initialNW;
    final nwDeltaPercent = initialNW > 0 ? (nwDelta / initialNW * 100) : 0.0;

    final solvencyRatio = totalLiabilities > 0
        ? (totalAssets / totalLiabilities).toStringAsFixed(1)
        : '∞';

    // Payoff strategies if debt exists
    final hasDebt = totalLiabilities > 0;
    final strategies = hasDebt ? FinanceCalculator.strategies(snapshot) : <StrategyResult>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Net Worth Hero Card with 6-Month Area Chart
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LIQUID NET WORTH',
                    style: AppTypography.sans(
                      size: 10,
                      color: c.mu,
                      letterSpacing: 1.1,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (nwDelta >= 0 ? _incomeGreen : _expenseRed)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${nwDelta >= 0 ? '+' : ''}${formatINR(nwDelta)} (${nwDeltaPercent.round()}%) 6mo',
                      style: AppTypography.sans(
                        size: 10,
                        weight: FontWeight.w700,
                        color: nwDelta >= 0 ? _incomeGreen : _expenseRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedAmount(
                value: netWorth,
                formatter: (value) => formatINR(value),
                style: AppTypography.serif(
                  size: 40,
                  color: c.tx,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              AreaLineChart(
                values: values,
                color: nwDelta >= 0 ? _incomeGreen : c.ac,
                height: 135,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final label in labels)
                    Text(
                      label,
                      style: AppTypography.sans(size: 10, color: c.mu),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Comprehensive Balance Sheet: Assets vs Liabilities
        const SectionCaption('Balance sheet breakdown'),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // ASSETS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL ASSETS',
                    style: AppTypography.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: _incomeGreen,
                    ),
                  ),
                  Text(
                    formatINR(totalAssets),
                    style: AppTypography.sans(
                      size: 14,
                      weight: FontWeight.w700,
                      color: _incomeGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _BalanceSheetItem(
                label: 'Bank accounts & cash',
                value: formatINR(liquidCash),
              ),
              _BalanceSheetItem(
                label: 'Investments & portfolio',
                value: formatINR(investments),
              ),
              _BalanceSheetItem(
                label: 'Real estate / fixed assets',
                value: formatINR(fixedAssets),
              ),
              Divider(color: c.ln, height: 20),

              // LIABILITIES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL LIABILITIES',
                    style: AppTypography.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: _expenseRed,
                    ),
                  ),
                  Text(
                    '−${formatINR(totalLiabilities)}',
                    style: AppTypography.sans(
                      size: 14,
                      weight: FontWeight.w700,
                      color: _expenseRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _BalanceSheetItem(
                label: 'Credit card dues',
                value: formatINR(cardDues),
                isLiability: true,
              ),
              _BalanceSheetItem(
                label: 'Outstanding loans',
                value: formatINR(loans),
                isLiability: true,
              ),
              Divider(color: c.ln, height: 20),

              // SOLVENCY RATIO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Asset Coverage Multiplier',
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                  Text(
                    '${solvencyRatio}x solvency',
                    style: AppTypography.sans(
                      size: 12,
                      weight: FontWeight.w700,
                      color: _incomeGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Debt Payoff Projection Engine (Snowball vs Avalanche)
        if (hasDebt) ...[
          const SectionCaption('Debt freedom payoff engine'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Accelerated Payoff Strategies',
                  style: AppTypography.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.tx,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Simulated with +₹5,000 extra monthly prepayment',
                  style: AppTypography.sans(size: 11, color: c.mu),
                ),
                const SizedBox(height: 12),
                for (final strategy in strategies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.c2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strategy.name,
                                style: AppTypography.sans(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: c.tx,
                                ),
                              ),
                              Text(
                                'Debt free in ${FinanceCalculator.resultLabel(strategy.result.months)}',
                                style: AppTypography.sans(size: 10, color: c.mu),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatINR(strategy.result.interest),
                                style: AppTypography.sans(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: c.tx,
                                ),
                              ),
                              Text(
                                'Total interest',
                                style: AppTypography.sans(size: 9, color: c.mu),
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
        ] else ...[
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 24,
                  color: _incomeGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% Debt-Free',
                        style: AppTypography.sans(
                          size: 14,
                          weight: FontWeight.w700,
                          color: _incomeGreen,
                        ),
                      ),
                      Text(
                        'No outstanding credit card dues or active loans detected.',
                        style: AppTypography.sans(size: 11, color: c.mu),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BalanceSheetItem extends StatelessWidget {
  const _BalanceSheetItem({
    required this.label,
    required this.value,
    this.isLiability = false,
  });

  final String label;
  final String value;
  final bool isLiability;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
          Text(
            value,
            style: AppTypography.sans(
              size: 12,
              weight: FontWeight.w500,
              color: isLiability ? _expenseRed : c.tx,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REUSABLE MICRO-WIDGETS
// =============================================================================
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.subColor,
  });

  final String label;
  final String value;
  final String subLabel;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.sans(
              size: 9,
              color: c.mu,
              letterSpacing: 1.1,
              weight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.serif(
              size: 16,
              color: c.tx,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: AppTypography.sans(
              size: 10,
              color: subColor,
              weight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.sans(size: 11, color: context.spend.mu),
        ),
      ],
    );
  }
}
