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
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/custom_painters/charts.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/month_navigator.dart';
import '../../core/widgets/premium_sheet.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/budget.dart';
import '../../data/models/finance_snapshot.dart';
import '../transactions/edit_transaction_sheet.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  int _monthOffset = 0;

  DateTime get _month =>
      DateTime(DateTime.now().year, DateTime.now().month - _monthOffset, 1);

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final month = _month;
    final budgets = snapshot.budgets;
    final categoryLimit = budgets.fold<double>(0, (sum, b) => sum + b.limit);
    final limit = snapshot.totalBudgetLimit;
    final spent = snapshot.hasTotalBudget
        ? snapshot.expensesIn(month)
        : budgets.fold<double>(
            0,
            (sum, b) => sum + snapshot.spentIn(b.category, month),
          );
    final left = limit - spent;
    final income = snapshot.flow(month).income;
    final daysLeft = daysLeftInMonth(month);
    final history = [
      for (var k = 5; k >= 0; k--)
        snapshot.hasTotalBudget
            ? snapshot.expensesIn(DateTime(month.year, month.month - k, 1))
            : snapshot.flow(DateTime(month.year, month.month - k, 1)).expense,
    ];
    final historyLabels = [
      for (var k = 5; k >= 0; k--)
        monthShort[DateTime(month.year, month.month - k, 1).month - 1],
    ];
    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Budgets',
          subtitle: isCurrentMonth(month)
              ? '$daysLeft days left in ${monthShort[month.month - 1]}'
              : 'Closed · ${monthShort[month.month - 1]}',
        ),
        const SizedBox(height: 8),
        MonthNavigator(
          month: month,
          margin: EdgeInsets.zero,
          onPrevious: () => setState(() => _monthOffset++),
          onNext: _monthOffset == 0
              ? null
              : () => setState(() => _monthOffset--),
          canGoNext: _monthOffset > 0,
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly total',
                      style: AppTypography.sans(size: 14, color: c.tx),
                    ),
                    Text(
                      snapshot.hasTotalBudget
                          ? 'Set in the app or on the web'
                          : 'Using the sum of your envelopes',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedAmount(
                    value: snapshot.totalBudgetLimit,
                    style: AppTypography.sans(
                      size: 16,
                      color: c.tx,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppPill(
                    label: snapshot.hasTotalBudget ? 'Edit' : 'Set',
                    onTap: () => _showTotalBudget(context, snapshot),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      left < 0 ? 'Over budget by' : 'Left this month',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                    AnimatedAmount(
                      value: left.abs(),
                      style: AppTypography.serif(
                        size: 42,
                        color: left < 0 ? c.co : c.tx,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isCurrentMonth(month)
                        ? '≈ ${rupee(math.max(0, left) / daysLeft)} / day'
                        : 'final',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  ),
                  MoneyText(
                    '${rupee(spent)} of ${rupee(limit)}',
                    style: AppTypography.sans(size: 12, color: c.tx),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Income this month',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  ),
                  const Spacer(),
                  AnimatedAmount(
                    value: income,
                    style: AppTypography.sans(
                      size: 14,
                      color: c.tx,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      for (final budget in budgets)
                        if (income > 0)
                          Expanded(
                            flex: ((budget.limit / income) * 1000)
                                .round()
                                .clamp(1, 100000)
                                .toInt(),
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: AppColors.category(budget.category),
                            ),
                          ),
                      if (income > 0 && categoryLimit < income)
                        Expanded(
                          flex: (((income - categoryLimit) / income) * 1000)
                              .round()
                              .clamp(1, 100000)
                              .toInt(),
                          child: Container(color: c.c2),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Allocated ${rupee(categoryLimit)}',
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                  const Spacer(),
                  Text(
                    income >= categoryLimit
                        ? '${rupee(income - categoryLimit)} free → savings'
                        : '${rupee(categoryLimit - income)} over income',
                    style: AppTypography.sans(
                      size: 12,
                      color: income >= categoryLimit ? c.ac : c.co,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Last 6 months · spend vs budget',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              const SizedBox(height: 6),
              SimpleBarChart(
                values: history,
                labels: historyLabels,
                budgetValue: limit,
                height: 100,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SectionCaption(
          'Category Envelopes',
          trailing: AppPill(
            label: '+ New',
            onTap: () => _showNewBudget(context),
          ),
        ),
        for (final budget in budgets)
          _BudgetCard(
            budget: budget,
            month: month,
            spent: snapshot.spentIn(budget.category, month),
            onTap: () => _showBudget(context, budget, month),
          ),
        if (budgets.isEmpty)
          EmptyState(
            title: 'No envelopes yet',
            message: 'Give every rupee a job.',
            actionLabel: 'Create one',
            onAction: () => _showNewBudget(context),
          ),
        AppButton(
          label: '+ New envelope',
          onTap: () => _showNewBudget(context),
          margin: const EdgeInsets.only(top: 8),
        ),
      ],
    );
  }

  void _showBudget(
    BuildContext context,
    Budget budget,
    DateTime month,
  ) {
    showAppSheet<void>(
      context,
      (_) => _EditBudgetSheet(budget: budget, month: month),
    );
  }

  void _showTotalBudget(BuildContext context, FinanceSnapshot snapshot) {
    showAppSheet<void>(context, (_) => const _TotalBudgetSheet());
  }

  void _showNewBudget(BuildContext context) {
    showAppSheet<void>(context, (_) => const _NewBudgetSheet());
  }
}

class _EditBudgetSheet extends ConsumerStatefulWidget {
  const _EditBudgetSheet({
    required this.budget,
    required this.month,
  });

  final Budget budget;
  final DateTime month;

  @override
  ConsumerState<_EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends ConsumerState<_EditBudgetSheet> {
  late final TextEditingController _limit;
  late bool _rollover;
  late int _alertAt;

  @override
  void initState() {
    super.initState();
    _limit = TextEditingController(
      text: widget.budget.limit.round().toString(),
    );
    _rollover = widget.budget.rollover;
    _alertAt = widget.budget.alertAt;
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  double get _limitValue => double.tryParse(_limit.text) ?? 0;

  void _adjustLimit(double delta) {
    final next = math.max(0.0, _limitValue + delta);
    setState(() {
      _limit.text = next.round().toString();
    });
  }

  Future<void> _save() async {
    if (_limitValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter a valid monthly limit');
      return;
    }
    await ref.read(budgetRepositoryProvider).updateBudget(
          category: widget.budget.category,
          limit: _limitValue,
          rollover: _rollover,
          alertAt: _alertAt,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('${widget.budget.category} budget updated');
  }

  Future<void> _delete() async {
    await ref
        .read(budgetRepositoryProvider)
        .removeBudget(widget.budget.category);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('${widget.budget.category} envelope removed');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final spent = snapshot.spentIn(widget.budget.category, widget.month);
    final history = [
      for (var k = 5; k >= 0; k--)
        snapshot.spentIn(
          widget.budget.category,
          DateTime(widget.month.year, widget.month.month - k, 1),
        ),
    ];
    final labels = [
      for (var k = 5; k >= 0; k--)
        monthShort[DateTime(widget.month.year, widget.month.month - k, 1).month - 1],
    ];
    final tx = snapshot
        .inMonth(widget.month)
        .where((t) => t.category == widget.budget.category)
        .take(5)
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSheetHeader(
            icon: 'budgets',
            title: 'Edit ${widget.budget.category}',
            subtitle: '${rupee(spent)} spent in ${monthShort[widget.month.month - 1]}',
          ),
          const SizedBox(height: 18),
          const PremiumLabel('Monthly limit', requiredField: true),
          PremiumField(
            controller: _limit,
            hint: '0',
            number: true,
            large: true,
            prefix: '₹ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final delta in [500.0, 1000.0, 5000.0, 10000.0])
                AppPill(
                  label: '+${compactINR(delta)}',
                  onTap: () => _adjustLimit(delta),
                ),
              for (final delta in [-1000.0, -5000.0])
                AppPill(
                  label: compactINR(delta),
                  onTap: () => _adjustLimit(delta),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const PremiumLabel('Alert me at'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final threshold in const [50, 75, 85, 95, 100])
                AppPill(
                  label: '$threshold% used',
                  active: _alertAt == threshold,
                  onTap: () => setState(() => _alertAt = threshold),
                ),
            ],
          ),
          const SizedBox(height: 16),
          PremiumToggleRow(
            title: 'Roll unused over',
            subtitle: 'Carry leftover into next month',
            value: _rollover,
            onChanged: (value) => setState(() => _rollover = value),
          ),
          const SizedBox(height: 16),
          Text(
            'Last 6 months · spend vs limit',
            style: AppTypography.sans(size: 11, color: c.mu),
          ),
          const SizedBox(height: 6),
          SimpleBarChart(
            values: history,
            labels: labels,
            budgetValue: _limitValue,
            height: 100,
          ),
          const SizedBox(height: 14),
          if (tx.isNotEmpty) ...[
            SectionCaption(
              'Recent spends in ${monthShort[widget.month.month - 1]}',
            ),
            for (var i = 0; i < tx.length; i++)
              TransactionRow(
                transaction: tx[i],
                showDivider: i < tx.length - 1,
                onTap: () => showEditTransactionSheet(context, tx[i].id),
              ),
            const SizedBox(height: 14),
          ],
          PrimaryButton(
            label: 'Save budget',
            onTap: _save,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Delete envelope',
            color: c.co,
            centered: true,
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}

class _NewBudgetSheet extends ConsumerStatefulWidget {
  const _NewBudgetSheet();

  @override
  ConsumerState<_NewBudgetSheet> createState() => _NewBudgetSheetState();
}

class _NewBudgetSheetState extends ConsumerState<_NewBudgetSheet> {
  final _category = TextEditingController();
  final _limit = TextEditingController();
  bool _rollover = false;
  int _alertAt = 75;

  @override
  void dispose() {
    _category.dispose();
    _limit.dispose();
    super.dispose();
  }

  double get _limitValue => double.tryParse(_limit.text) ?? 0;

  Future<void> _save(FinanceSnapshot snapshot) async {
    final raw = _category.text.trim();
    if (raw.isEmpty) {
      ref.read(toastProvider.notifier).show('Name the envelope');
      return;
    }
    if (_limitValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter a monthly limit');
      return;
    }
    final matches = snapshot.budgets
        .where((b) => b.category.toLowerCase() == raw.toLowerCase())
        .toList();
    final existing = matches.isEmpty ? null : matches.first;
    if (existing == null) {
      await ref
          .read(budgetRepositoryProvider)
          .addBudget(
            category: raw,
            limit: _limitValue,
            rollover: _rollover,
            alertAt: _alertAt,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.read(toastProvider.notifier).show('Envelope created');
    } else {
      await ref
          .read(budgetRepositoryProvider)
          .updateBudget(
            category: existing.category,
            limit: _limitValue,
            rollover: _rollover,
            alertAt: _alertAt,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.read(toastProvider.notifier).show('Envelope updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final settings = ref.watch(settingsProvider);
    final raw = _category.text.trim();
    final matches = snapshot.budgets
        .where((b) => b.category.toLowerCase() == raw.toLowerCase())
        .toList();
    final existing = matches.isEmpty ? null : matches.first;
    final categories = settings.categories.keys
        .where((category) => category != 'Income' && category != 'Transfer')
        .take(10)
        .toList();
    final spent = raw.isEmpty ? 0.0 : snapshot.spentIn(raw, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'budgets',
          title: 'New envelope',
          subtitle: 'Give a category its own monthly spending limit.',
        ),
        const SizedBox(height: 20),
        const PremiumLabel('Envelope name', requiredField: true),
        PremiumField(
          controller: _category,
          hint: 'e.g. Food, Travel',
          icon: 'budgets',
          capitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                AppPill(
                  label: category,
                  active: raw.toLowerCase() == category.toLowerCase(),
                  onTap: () {
                    setState(() {
                      _category.text = category;
                      final match = snapshot.budgets
                          .where((b) => b.category == category)
                          .toList();
                      if (match.isNotEmpty && _limit.text.isEmpty) {
                        _limit.text = match.first.limit.round().toString();
                        _rollover = match.first.rollover;
                        _alertAt = match.first.alertAt;
                      }
                    });
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const PremiumLabel('Monthly limit', requiredField: true),
        PremiumField(
          controller: _limit,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        const PremiumLabel('Alert me at'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final threshold in const [75, 85, 95, 100])
              AppPill(
                label: '$threshold% used',
                active: _alertAt == threshold,
                onTap: () => setState(() => _alertAt = threshold),
              ),
          ],
        ),
        const SizedBox(height: 14),
        PremiumToggleRow(
          title: 'Roll unused over',
          subtitle: 'Carry leftover into next month',
          value: _rollover,
          onChanged: (value) => setState(() => _rollover = value),
        ),
        const SizedBox(height: 14),
        PremiumSummaryCard(
          icon: 'budgets',
          eyebrow: existing == null ? 'New envelope' : 'Update envelope',
          value: rupee(_limitValue),
          caption: raw.isEmpty
              ? 'Pick a category'
              : '$raw · alert at $_alertAt%',
          accent: c.ac,
        ),
        if (existing != null || spent > 0) ...[
          const SizedBox(height: 12),
          PremiumNotice(
            icon: 'insights',
            text: existing != null
                ? 'This envelope already exists. Saving will update its limit and rules. ${spent > 0 ? '${rupee(spent)} spent this month.' : ''}'
                : '${rupee(spent)} has already been spent in $raw this month.',
          ),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: existing == null ? 'Create envelope' : 'Update envelope',
          onTap: () => _save(snapshot),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.month,
    required this.spent,
    required this.onTap,
  });

  final Budget budget;
  final DateTime month; // kept for parity with the prototype's month context
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final progress = budget.limit <= 0 ? 0.0 : spent / budget.limit;
    final over = progress > 0.85;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MerchantAvatar(
                merchant: budget.category,
                category: budget.category,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.category,
                      style: AppTypography.sans(
                        size: 14,
                        color: c.tx,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${rupee(spent)} of ${rupee(budget.limit)}${budget.rollover ? ' · rolls over' : ''}',
                      style: AppTypography.sans(size: 11, color: c.mu),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    spent > budget.limit
                        ? '${rupee(spent - budget.limit)} over'
                        : '${rupee(budget.limit - spent)} left',
                    style: AppTypography.sans(
                      size: 12,
                      weight: FontWeight.w600,
                      color: over ? c.co : c.tx,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppPill(
                    label: 'Edit',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    fontSize: 10,
                    onTap: onTap,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: c.c2,
              valueColor: AlwaysStoppedAnimation(over ? c.co : c.ac),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBudgetSheet extends ConsumerStatefulWidget {
  const _TotalBudgetSheet();

  @override
  ConsumerState<_TotalBudgetSheet> createState() => _TotalBudgetSheetState();
}

class _TotalBudgetSheetState extends ConsumerState<_TotalBudgetSheet> {
  late final TextEditingController _limit;

  @override
  void initState() {
    super.initState();
    final snapshot = ref.read(financeSnapshotProvider);
    final value = snapshot.totalBudgetOverride ?? snapshot.totalBudgetLimit;
    _limit = TextEditingController(
      text: value <= 0 ? '' : value.round().toString(),
    );
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_limit.text) ?? 0;

  Future<void> _save() async {
    if (_value <= 0) {
      ref.read(toastProvider.notifier).show('Enter a monthly limit');
      return;
    }
    await ref.read(budgetRepositoryProvider).setTotalBudget(_value);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Total budget saved');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final envelopeTotal = snapshot.budgets.fold<double>(
      0,
      (sum, budget) => sum + budget.limit,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'budgets',
          title: 'Monthly total',
          subtitle: 'One limit across every expense this month.',
        ),
        const SizedBox(height: 20),
        const PremiumLabel('Total monthly limit', requiredField: true),
        PremiumField(
          controller: _limit,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          icon: 'budgets',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        PremiumSummaryCard(
          icon: 'budgets',
          eyebrow: 'Total budget',
          value: rupee(_value),
          caption: snapshot.hasTotalBudget
              ? 'Custom limit · replaces envelope total'
              : 'Envelope total is ${rupee(envelopeTotal)}',
          accent: c.ac,
        ),
        const SizedBox(height: 12),
        PremiumNotice(
          icon: 'insights',
          text: 'The total is compared with every outgoing transaction, while envelopes stay useful for category-level pacing.',
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Save total budget', onTap: _save),
        if (snapshot.hasTotalBudget)
          AppButton(
            label: 'Use envelope total instead',
            centered: true,
            onTap: () async {
              final navigator = Navigator.of(context);
              await ref.read(budgetRepositoryProvider).removeTotalBudget();
              if (!mounted) return;
              navigator.pop();
              ref.read(toastProvider.notifier).show('Total budget cleared');
            },
          ),
      ],
    );
  }
}
