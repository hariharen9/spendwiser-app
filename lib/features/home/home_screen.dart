import 'dart:async';

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
import '../../core/widgets/custom_painters/debt_amortization_chart.dart';
import '../../core/widgets/custom_painters/hero_gauge_painter.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/bill.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/goal.dart';
import '../../data/models/transaction.dart';
import '../../data/services/finance_calculator.dart';
import '../shell/app_module.dart';
import '../transactions/add_transaction_sheet.dart';
import 'customize_home_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<AppModule> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);
    final settings = ref.watch(settingsProvider);
    final widgets = settings.homeWidgets
        .where((w) => !settings.hiddenWidgets.contains(w))
        .toList();

    final builders = <HomeWidget, Widget>{
      HomeWidget.netWorth: _NetWorthHero(
        snapshot: snapshot,
        onInsights: () => onNavigate(AppModule.insights),
      ),
      HomeWidget.quickAdd: _CaptureBar(snapshot: snapshot),
      HomeWidget.safeRing: _SafeRing(snapshot: snapshot),
      HomeWidget.comingUp: _ComingUp(
        snapshot: snapshot,
        onOpen: () => onNavigate(AppModule.calendar),
      ),
      HomeWidget.streak: _StreakAndBuffer(snapshot: snapshot),
      HomeWidget.forecast: _CashFlowCard(snapshot: snapshot),
      HomeWidget.goals: _GoalsStrip(
        snapshot: snapshot,
        onOpen: () => onNavigate(AppModule.goals),
      ),
      HomeWidget.recent: _RecentList(
        snapshot: snapshot,
        onAdd: () => showAddTransactionSheet(context),
      ),
    };

    return ScreenScroll(
      children: [
        _HomeHeader(
          settings: settings,
          onAvatar: () => onNavigate(AppModule.settings),
        ),
        for (var i = 0; i < widgets.length; i++)
          Reveal(index: i + 1, child: builders[widgets[i]]!),
        Reveal(
          index: widgets.length + 1,
          child: AppButton(
            label: 'Customize Home',
            centered: true,
            onTap: () => showCustomizeHomeSheet(context),
            margin: const EdgeInsets.only(top: 14),
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.settings, required this.onAvatar});

  final AppSettings settings;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                longDate(now),
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              Text(
                'Good ${timeGreeting(now: now)}, ${settings.userName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.serif(size: 26, color: c.tx, height: 1.15),
              ),
            ],
          ),
        ),
        AppPill(
          label: settings.initials,
          textColor: c.tx,
          fontSize: 12,
          onTap: onAvatar,
        ),
      ],
    );
  }
}

class _NetWorthHero extends ConsumerWidget {
  const _NetWorthHero({required this.snapshot, required this.onInsights});

  final FinanceSnapshot snapshot;
  final VoidCallback onInsights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final now = DateTime.now();
    final flow = snapshot.flow(monthStart(now));
    final saved = flow.saved;
    final worth = snapshot.netWorth;
    final pct = worth == 0 ? 0.0 : (saved.abs() / worth * 100);
    final runway = FinanceCalculator.runwayMonths(snapshot, now: now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'TOTAL NET WORTH',
                    style: AppTypography.sans(
                      size: 11,
                      color: c.mu,
                      letterSpacing: 1.32,
                    ),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: onInsights,
                    child: Text(
                      'Insights →',
                      style: AppTypography.sans(size: 12, color: c.ac),
                    ),
                  ),
                ],
              ),
              AnimatedAmount(
                value: worth,
                style: AppTypography.serif(
                  size: 50,
                  color: c.tx,
                  letterSpacing: -1,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  AppPill(
                    label:
                        '${saved >= 0 ? '+' : '−'}${pct.toStringAsFixed(1)}%',
                    active: true,
                    fontSize: 12,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: MoneyText(
                      '${saved >= 0 ? '+' : '−'}${rupee(saved)} this month',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.ln)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Financial runway',
                      style: AppTypography.sans(size: 13, color: c.mu),
                    ),
                    Text(
                      '${runway.toStringAsFixed(1)} months safe',
                      style: AppTypography.sans(
                        size: 13,
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
        const SizedBox(height: 8),
        _Trio(flow: flow),
      ],
    );
  }
}

class _Trio extends StatelessWidget {
  const _Trio({required this.flow});

  final MonthFlow flow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricTile(label: 'Income', value: compactINR(flow.income)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(label: 'Spent', value: compactINR(flow.expense)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(
            label: 'Saved',
            value: '${flow.savingsRate.round()}%',
            valueColor: context.spend.ac,
          ),
        ),
      ],
    );
  }
}

class _CaptureBar extends ConsumerStatefulWidget {
  const _CaptureBar({required this.snapshot});

  final FinanceSnapshot snapshot;

  @override
  ConsumerState<_CaptureBar> createState() => _CaptureBarState();
}

class _CaptureBarState extends ConsumerState<_CaptureBar> {
  final _controller = TextEditingController();

  static const _shortcuts = <String, String>{
    'chai': 'Food',
    'coffee': 'Food',
    'uber': 'Travel',
    'ola': 'Travel',
    'netflix': 'Fun',
    'movie': 'Fun',
    'rent': 'Bills',
    'bill': 'Bills',
    'amazon': 'Shop',
    'myntra': 'Shop',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _categoryFor(String merchant) {
    final lower = merchant.toLowerCase();
    for (final entry in _shortcuts.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    if (RegExp(r'uber|ola|metro|auto|fuel|petrol|cab').hasMatch(lower)) {
      return 'Travel';
    }
    if (RegExp(r'amazon|myntra|flipkart|shop').hasMatch(lower)) return 'Shop';
    if (RegExp(r'netflix|movie|bms|game|pvr').hasMatch(lower)) return 'Fun';
    if (RegExp(r'rent|electric|wifi|recharge').hasMatch(lower)) return 'Bills';
    return 'Food';
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    final match = RegExp(r'(\d[\d,]*)').firstMatch(input);
    if (match == null) {
      ref.read(toastProvider.notifier).show('Add an amount, e.g. “chai 40”');
      return;
    }
    final amount = double.parse(match.group(1)!.replaceAll(',', ''));
    var merchant = input.replaceFirst(match.group(0)!, '').trim();
    if (merchant.isEmpty) merchant = 'Expense';
    final category = _categoryFor(merchant);
    merchant = merchant[0].toUpperCase() + merchant.substring(1).toLowerCase();
    final account = widget.snapshot.accounts.isEmpty
        ? null
        : widget.snapshot.accounts.first;
    await ref
        .read(transactionRepositoryProvider)
        .addTransaction(
          TransactionDraft(
            merchant: merchant,
            category: category,
            amount: -amount,
            date: DateTime.now(),
            accountId: account?.id,
          ),
        );
    _controller.clear();
    ref
        .read(toastProvider.notifier)
        .show('Logged · $category ${rupee(amount)}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: c.c1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.ln),
        gradient: c.dark ? c.cardGradient : null,
      ),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.sans(size: 14, color: c.tx),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Type “chai 40” or “uber 280”…',
                hintStyle: AppTypography.sans(size: 14, color: c.mu),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(icon: 'mic', onTap: () => _showVoice(context)),
          const SizedBox(width: 8),
          _RoundIconButton(icon: 'scan', onTap: () => _showScan(context)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.ac,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(
                '↵',
                style: AppTypography.sans(
                  size: 18,
                  color: c.aci,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c.c2,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: SpendIcon(icon, size: 18, color: c.tx),
      ),
    );
  }
}

void _showVoice(BuildContext context) {
  showAppSheet(context, (_) => const _VoiceSheet());
}

class _VoiceSheet extends ConsumerStatefulWidget {
  const _VoiceSheet();

  @override
  ConsumerState<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<_VoiceSheet> {
  String _text = 'Listening…';
  Timer? _one;
  Timer? _two;

  @override
  void initState() {
    super.initState();
    _one = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _text = '“Zomato four eighty six”');
      _two = Timer(const Duration(milliseconds: 1100), () async {
        if (!mounted) return;
        Navigator.of(context).pop();
        await ref
            .read(transactionRepositoryProvider)
            .addTransaction(
              TransactionDraft(
                merchant: 'Zomato',
                category: 'Food',
                amount: -486,
                date: DateTime.now(),
                accountId: ref.read(financeSnapshotProvider).accounts.isEmpty
                    ? null
                    : ref.read(financeSnapshotProvider).accounts.first.id,
              ),
            );
        ref.read(toastProvider.notifier).show('Logged ${rupee(486)} · Zomato');
      });
    });
  }

  @override
  void dispose() {
    _one?.cancel();
    _two?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      children: [
        const SizedBox(height: 14),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: c.ac,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.ac.withValues(alpha: 0.45),
                blurRadius: 0,
                spreadRadius: 20,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: SpendIcon('mic', size: 34, color: c.aci, strokeWidth: 1.8),
        ),
        const SizedBox(height: 22),
        Text(
          _text,
          style: AppTypography.serif(size: 28, color: c.tx),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Try “chai forty” or “uber two eighty”',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

void _showScan(BuildContext context) {
  showAppSheet(context, (_) => const _ScanSheet());
}

class _ScanSheet extends ConsumerStatefulWidget {
  const _ScanSheet();

  @override
  ConsumerState<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends ConsumerState<_ScanSheet> {
  bool _detected = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _detected = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    Navigator.of(context).pop();
    await ref
        .read(transactionRepositoryProvider)
        .addTransaction(
          TransactionDraft(
            merchant: 'Blinkit',
            category: 'Food',
            amount: -842,
            date: DateTime.now(),
            accountId: ref.read(financeSnapshotProvider).accounts.isEmpty
                ? null
                : ref.read(financeSnapshotProvider).accounts.first.id,
          ),
        );
    ref.read(toastProvider.notifier).show('Logged ${rupee(842)} · Blinkit');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    if (!_detected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('Scan receipt'),
          const SizedBox(height: 12),
          _Viewfinder(),
          const SizedBox(height: 12),
          Text(
            'Reading merchant, items and total…',
            textAlign: TextAlign.center,
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
          const SizedBox(height: 16),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Receipt detected',
          style: AppTypography.sans(size: 14, color: c.mu),
        ),
        const SizedBox(height: 4),
        Text(rupee(842), style: AppTypography.serif(size: 46, color: c.tx)),
        Text(
          'Blinkit · Food',
          style: AppTypography.sans(size: 14, color: c.tx),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              for (final item in const [
                ['Amul milk ×2', 128],
                ['Eggs ×12', 96],
                ['Basmati rice 5kg', 520],
                ['Delivery', 98],
              ])
                KeyValueRow(
                  label: item[0] as String,
                  value: MoneyText(
                    rupee(item[1] as int),
                    style: AppTypography.sans(size: 14, color: c.tx),
                  ),
                  border: item != const ['Delivery', 98],
                ),
            ],
          ),
        ),
        PrimaryButton(label: 'Confirm & log', onTap: _confirm),
      ],
    );
  }
}

class _Viewfinder extends StatefulWidget {
  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.ln, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SpendIcon('scan', size: 36, color: c.mu),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Positioned(
                left: 0,
                right: 0,
                top: 12 + _controller.value * 150,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: c.ac,
                    boxShadow: [
                      BoxShadow(color: c.ac, blurRadius: 18, spreadRadius: 1),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SafeRing extends StatelessWidget {
  const _SafeRing({required this.snapshot});

  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final now = DateTime.now();
    final safe = FinanceCalculator.safeToSpend(snapshot, now: now);
    final progress = safe.limit <= 0 ? 0.0 : safe.spent / safe.limit * 100;
    final days = daysInMonth(now.year, now.month);

    return Column(
      children: [
        const SizedBox(height: 8),
        HeroGauge(
          progress: progress,
          dayCount: days,
          currentDay: now.day,
          size: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Safe to spend today',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              AnimatedAmount(
                value: safe.perDay,
                style: AppTypography.serif(
                  size: 54,
                  color: c.tx,
                  letterSpacing: -1,
                  height: 1.05,
                ),
              ),
              MoneyText(
                '${rupee(safe.left)} left · ${safe.daysLeft} days',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        AppButton(
          label: '+ Add transaction',
          centered: true,
          margin: const EdgeInsets.only(top: 14),
          onTap: () => showAddTransactionSheet(context),
        ),
      ],
    );
  }
}

class _ComingUp extends StatelessWidget {
  const _ComingUp({required this.snapshot, required this.onOpen});

  final FinanceSnapshot snapshot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final bills = FinanceCalculator.bills(snapshot)
        .where((b) => b.days <= 14)
        .take(8)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionCaption(
          'Coming up',
          margin: EdgeInsets.only(top: 22, bottom: 8),
        ),
        if (bills.isEmpty)
          AppCard(
            child: Text(
              'No bills in the next two weeks.',
              style: AppTypography.sans(size: 14, color: c.mu),
            ),
          )
        else
          BleedRow(
            height: 104,
            alignment: CrossAxisAlignment.stretch,
            children: [
              for (final bill in bills) _BillCard(bill: bill, onTap: onOpen),
            ],
          ),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onTap});

  final BillItem bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 112,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.c1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.ln),
          gradient: c.dark ? c.cardGradient : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bill.relativeLabel,
              style: AppTypography.sans(size: 12, color: c.mu),
            ),
            const SizedBox(height: 8),
            Text(
              rupee(bill.amount),
              style: AppTypography.serif(
                size: 22,
                color: c.tx,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bill.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sans(size: 12, color: c.tx),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakAndBuffer extends StatelessWidget {
  const _StreakAndBuffer({required this.snapshot});

  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final now = DateTime.now();
    final buffer = FinanceCalculator.bufferDays(snapshot, now: now).round();
    final creep = FinanceCalculator.lifestyleCreep(snapshot, now: now);
    final incomeGrowth = FinanceCalculator.incomeGrowth(snapshot, now: now);
    final streak = FinanceCalculator.streak(snapshot, now: now);
    final flow = snapshot.flow(monthStart(now));
    final badges = <(String, bool)>[
      ('$streak-day streak', streak >= 3),
      (
        'Budget keeper',
        snapshot.budgets.isNotEmpty &&
            snapshot.budgets.every((b) => b.spent <= b.limit),
      ),
      ('20% saver', flow.income > 0 && flow.savingsRate >= 20),
      ('Debt slayer', snapshot.loans.isEmpty),
      ('Week of goals', snapshot.goals.any((g) => g.isReached)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionCaption(
          'Streak & buffer',
          margin: EdgeInsets.only(top: 22, bottom: 8),
        ),
        BleedRow(
          height: 42,
          children: [
            for (final badge in badges)
              Opacity(
                opacity: badge.$2 ? 1 : 0.4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.c1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.ln),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpendIcon(
                        badge.$2 ? 'goal' : 'vault',
                        size: 16,
                        color: badge.$2 ? c.ac : c.mu,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        badge.$1,
                        style: AppTypography.sans(size: 12, color: c.tx),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Days of buffer',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$buffer',
                              style: AppTypography.serif(
                                size: 38,
                                color: c.tx,
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: ' days',
                              style: AppTypography.sans(size: 12, color: c.mu),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(
                          value: (buffer / 180).clamp(0, 1),
                          minHeight: 6,
                          backgroundColor: c.c2,
                          valueColor: AlwaysStoppedAnimation(c.ac),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lifestyle creep',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                      Text(
                        '${creep >= 0 ? '+' : '−'}${creep.abs().toStringAsFixed(1)}%',
                        style: AppTypography.serif(
                          size: 38,
                          color: creep > incomeGrowth ? c.co : c.ac,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'spend vs ${incomeGrowth >= 0 ? '+' : '−'}${incomeGrowth.abs().toStringAsFixed(1)}% income',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.snapshot});

  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final points = FinanceCalculator.cashFlowForecast(snapshot, days: 30);
    final values = points.map((p) => p.balance).toList();
    final low = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);

    return AppCard(
      margin: const EdgeInsets.only(top: 10, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cash-flow forecast · 30 days',
                  style: AppTypography.sans(size: 14, color: c.mu),
                ),
              ),
              Text(
                'low ${compactINR(low)}',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AreaLineChart(values: values, color: c.ac, height: 80),
        ],
      ),
    );
  }
}

class _GoalsStrip extends StatelessWidget {
  const _GoalsStrip({required this.snapshot, required this.onOpen});

  final FinanceSnapshot snapshot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final goals = snapshot.goals.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionCaption(
          'Goals',
          margin: EdgeInsets.only(top: 22, bottom: 8),
        ),
        if (goals.isEmpty)
          AppCard(
            onTap: onOpen,
            child: Text(
              'Create your first goal →',
              style: AppTypography.sans(size: 14, color: c.mu),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: onOpen,
            child: Column(
              children: [for (final goal in goals) _GoalRow(goal: goal)],
            ),
          ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 6,
                    backgroundColor: c.c2,
                    valueColor: AlwaysStoppedAnimation(goal.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${(goal.progress * 100).round()}%',
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.snapshot, required this.onAdd});

  final FinanceSnapshot snapshot;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final recent = snapshot.transactions.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionCaption(
          'Recent',
          margin: EdgeInsets.only(top: 22, bottom: 8),
        ),
        if (recent.isEmpty)
          AppCard(
            child: EmptyState(
              title: 'No transactions yet',
              message: 'Add your first',
              actionLabel: 'Add transaction',
              onAction: onAdd,
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++)
                  TransactionRow(
                    transaction: recent[i],
                    showDivider: i < recent.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
