import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
import 'services/ask_ai_client.dart';
import 'widgets/formatted_ai_response.dart';
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
              child: MetricTile(
                label: 'In',
                amount: flow.income,
                formatter: compactINR,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Out',
                amount: flow.expense,
                formatter: compactINR,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Saved',
                amount: flow.savingsRate.toDouble(),
                formatter: (value) => '${value.round()}%',
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
        if (ref.watch(settingsProvider).hasAiKey)
          _MonthlyAiTakeaway(month: month, snapshot: snapshot),
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
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 480),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _YearInReview(
          pages: pages,
          aiPrompt:
              'Year $year summary: Income ${rupee(income)}, Expense ${rupee(expense)}, '
              'Top category ${top?.category ?? 'None'} (${top == null ? '₹0' : rupee(top.amount)}), '
              'Biggest spend ${biggest.isEmpty ? 'None' : '${biggest.first.merchant} ${rupee(biggest.first.amount)}'}, '
              'Busiest day ${weekdayFullSun[busiest]}. '
              'Give 3 crisp bullets: what spiked, what improved, and 1 move for next year.',
        ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 18 * curved.value,
              sigmaY: 18 * curved.value,
            ),
            child: child,
          ),
        ),
      );
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

class _MonthlyAiTakeaway extends ConsumerStatefulWidget {
  const _MonthlyAiTakeaway({required this.month, required this.snapshot});

  final DateTime month;
  final FinanceSnapshot snapshot;

  @override
  ConsumerState<_MonthlyAiTakeaway> createState() => _MonthlyAiTakeawayState();
}

class _MonthlyAiTakeawayState extends ConsumerState<_MonthlyAiTakeaway> {
  String? _text;
  String? _error;
  bool _loading = false;

  Future<void> _generate() async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasAiKey || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final prevMonth = DateTime(widget.month.year, widget.month.month - 1, 1);
    final currFlow = widget.snapshot.flow(widget.month);
    final prevFlow = widget.snapshot.flow(prevMonth);
    final top = widget.snapshot.spendByCategory(widget.month).take(5);
    final prompt =
        'Monthly report for ${monthFull[widget.month.month - 1]} ${widget.month.year}: '
        'Income ${rupee(currFlow.income)}, Expense ${rupee(currFlow.expense)} '
        '(previous month expense ${rupee(prevFlow.expense)}). '
        'Top categories: ${top.map((e) => '${e.category} ${rupee(e.amount)}').join(', ')}. '
        'Give 3 crisp bullets: what spiked, what improved, and 1 move for next month.';
    try {
      final result = await AskAiClient.generateNarrative(
        provider: settings.aiProvider,
        apiKey: settings.aiApiKey,
        model: settings.effectiveAiModel,
        prompt: prompt,
      );
      if (!mounted) return;
      setState(() {
        _text = result;
        _loading = false;
      });
    } on AskAiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AI takeaway',
                style: AppTypography.sans(
                  size: 13,
                  color: c.ac,
                  weight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_text == null && !_loading)
                GestureDetector(
                  onTap: _generate,
                  child: Text(
                    'Generate',
                    style: AppTypography.sans(
                      size: 12,
                      color: c.ac,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 10),
            Text(
              'Summarizing your month…',
              style: AppTypography.sans(size: 12, color: c.mu),
            ),
          ] else if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: AppTypography.sans(size: 12, color: c.co)),
          ] else if (_text != null) ...[
            const SizedBox(height: 8),
            FormattedAiResponse(text: _text!),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Tap Generate for a 3-bullet executive brief on what spiked, improved, and what to do next.',
              style: AppTypography.sans(size: 12, color: c.mu),
            ),
          ],
        ],
      ),
    );
  }
}

class _YearInReview extends ConsumerStatefulWidget {
  const _YearInReview({required this.pages, this.aiPrompt});

  final List<_ReviewPage> pages;
  final String? aiPrompt;

  @override
  ConsumerState<_YearInReview> createState() => _YearInReviewState();
}

class _YearInReviewState extends ConsumerState<_YearInReview> {
  int _index = 0;
  String? _aiText;
  bool _aiLoading = false;

  Future<void> _loadAi() async {
    final prompt = widget.aiPrompt;
    final settings = ref.read(settingsProvider);
    if (prompt == null || !settings.hasAiKey || _aiLoading) return;
    setState(() => _aiLoading = true);
    try {
      final res = await AskAiClient.generateNarrative(
        provider: settings.aiProvider,
        apiKey: settings.aiApiKey,
        model: settings.effectiveAiModel,
        prompt: prompt,
      );
      if (!mounted) return;
      setState(() {
        _aiText = res;
        _aiLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
    }
  }

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
                  color: c.bg.withValues(alpha: 0.55),
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
                          const SizedBox(height: 24),
                          if (_index == widget.pages.length - 1 &&
                              ref.watch(settingsProvider).hasAiKey) ...[
                            if (_aiText != null)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: c.c1.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: c.ac.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SpendIcon(
                                          'sparkle',
                                          size: 14,
                                          color: c.ac,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'AI TAKEAWAY',
                                          style: AppTypography.sans(
                                            size: 10,
                                            color: c.ac,
                                            weight: FontWeight.w700,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    FormattedAiResponse(text: _aiText!),
                                  ],
                                ),
                              )
                            else
                              AppPill(
                                label: _aiLoading
                                    ? 'Writing AI takeaway...'
                                    : 'Generate AI takeaway',
                                leading: SpendIcon(
                                  'sparkle',
                                  size: 14,
                                  color: c.ac,
                                ),
                                color: c.ac,
                                onTap: _aiLoading ? null : _loadAi,
                              ),
                            const SizedBox(height: 18),
                          ],
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
