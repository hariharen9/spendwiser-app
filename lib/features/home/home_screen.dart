import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth_provider.dart';
import '../../core/state/providers.dart';
import '../../core/utils/category_aliases.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/custom_painters/cash_runway_chart.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/profile_avatar.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/account.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/bill.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/goal.dart';
import '../../data/models/transaction.dart';
import '../../data/services/finance_calculator.dart';
import '../../data/services/shortcut_parser.dart';
import '../shell/app_module.dart';
import '../sms/sms_review_sheet.dart';
import '../transactions/add_transaction_sheet.dart';
import 'customize_home_sheet.dart';
import 'services/capture_parser.dart';
import 'widgets/cash_runway_sheet.dart';
import 'widgets/receipt_scanner_sheet.dart';
import 'widgets/voice_capture_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<AppModule> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);
    final settings = ref.watch(settingsProvider);
    final photoUrl = ref.watch(authStateProvider).value?.photoURL;
    final widgets = settings.homeWidgets
        .where(
          (widget) =>
              widget != HomeWidget.forecast &&
              !settings.hiddenWidgets.contains(widget),
        )
        .toList();

    final builders = <HomeWidget, Widget>{
      HomeWidget.netWorth: _NetWorthHero(
        snapshot: snapshot,
        onInsights: () => onNavigate(AppModule.insights),
      ),
      HomeWidget.quickAdd: _CaptureBar(snapshot: snapshot),
      HomeWidget.safeRing: _CashRunwayHero(
        snapshot: snapshot,
        onOpen: () => onNavigate(AppModule.calendar),
      ),
      HomeWidget.comingUp: _ComingUp(
        snapshot: snapshot,
        onOpen: () => onNavigate(AppModule.calendar),
      ),
      HomeWidget.streak: _StreakAndBuffer(snapshot: snapshot),
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
          photoUrl: photoUrl,
          onAvatar: () => onNavigate(AppModule.settings),
        ),
        const SmsReviewBanner(),
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
  const _HomeHeader({
    required this.settings,
    required this.photoUrl,
    required this.onAvatar,
  });

  final AppSettings settings;
  final String? photoUrl;
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
        ProfileAvatar(
          photoUrl: photoUrl,
          size: 42,
          onTap: onAvatar,
          fallback: AppPill(
            label: settings.initials,
            textColor: c.tx,
            fontSize: 12,
          ),
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
    final flow = snapshot.flow(monthStart(DateTime.now()));
    final balanceAccounts = snapshot.accounts
        .where(
          (account) =>
              account.type == AccountType.savings ||
              account.type == AccountType.cash,
        )
        .toList();
    final balance = balanceAccounts.fold<double>(
      0,
      (sum, account) => sum + account.balance,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlowCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          glowStrength: 0.4,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(child: _BalanceFinish()),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.ac,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: c.ac.withValues(alpha: 0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'CURRENT BALANCE',
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
                    value: balance,
                    formatter: (value) => formatINR(value),
                    style:
                        AppTypography.serif(
                          size: 50,
                          color: c.tx,
                          letterSpacing: -1,
                          height: 1.05,
                        ).copyWith(
                          shadows: [
                            Shadow(
                              color: c.ac.withValues(
                                alpha: c.dark ? 0.22 : 0.12,
                              ),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      SpendIcon('accounts', size: 12, color: c.mu),
                      const SizedBox(width: 5),
                      Text(
                        balanceAccounts.isEmpty
                            ? 'Bank + cash · no accounts yet'
                            : 'Bank + cash · ${balanceAccounts.length} account${balanceAccounts.length == 1 ? '' : 's'}',
                        style: AppTypography.sans(size: 11, color: c.mu),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        _Trio(flow: flow),
      ],
    );
  }
}

class _BalanceFinish extends StatefulWidget {
  const _BalanceFinish();

  @override
  State<_BalanceFinish> createState() => _BalanceFinishState();
}

class _BalanceFinishState extends State<_BalanceFinish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _BalanceFinishPainter(
          progress: _controller.value,
          accent: c.ac,
          dark: c.dark,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BalanceFinishPainter extends CustomPainter {
  const _BalanceFinishPainter({
    required this.progress,
    required this.accent,
    required this.dark,
  });

  final double progress;
  final Color accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = progress * math.pi * 2;

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
    );

    final field = Offset.zero & size;
    canvas.drawRect(
      field,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            accent.withValues(alpha: dark ? 0.045 : 0.03),
            accent.withValues(alpha: 0),
          ],
          stops: const [0, 0.78],
        ).createShader(field),
    );

    final rim = Rect.fromLTWH(w * 0.14, 0, w * 0.72, 1);
    canvas.drawRect(
      rim,
      Paint()
        ..shader = LinearGradient(
          colors: [
            accent.withValues(alpha: 0),
            accent.withValues(alpha: dark ? 0.34 : 0.22),
            accent.withValues(alpha: 0),
          ],
        ).createShader(rim),
    );

    final under = Rect.fromLTWH(w * 0.28, h - 1, w * 0.44, 1);
    canvas.drawRect(
      under,
      Paint()..color = Colors.white.withValues(alpha: dark ? 0.035 : 0.02),
    );

    canvas.save();
    canvas.rotate(-0.28);
    final sweepX = -w * 0.6 + ((progress * 1.0) % 1) * (w * 2.2);
    final sweep = Rect.fromLTWH(sweepX, -h * 0.6, w * 0.12, h * 2.2);
    canvas.drawRect(
      sweep,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: dark ? 0.022 : 0.012),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(sweep),
    );
    canvas.restore();

    final glint = Offset(
      w * 0.76 + 3 * math.sin(t),
      h * 0.34 + 2 * math.cos(t),
    );
    canvas.drawCircle(
      glint,
      1.1,
      Paint()..color = Colors.white.withValues(alpha: dark ? 0.12 : 0.08),
    );
    canvas.drawCircle(
      Offset(w * 0.9, h * 0.72),
      1,
      Paint()..color = accent.withValues(alpha: dark ? 0.12 : 0.08),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BalanceFinishPainter oldDelegate) => true;
}

class _Trio extends StatelessWidget {
  const _Trio({required this.flow});

  final MonthFlow flow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Income',
            amount: flow.income,
            formatter: compactINR,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(
            label: 'Spent',
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final snapshot = ref.read(financeSnapshotProvider);
    final shortcutMatch = matchShortcut(input, snapshot.shortcuts);
    if (shortcutMatch != null) {
      final shortcut = shortcutMatch.shortcut;
      final amount = shortcutMatch.amount;
      final isCard =
          shortcut.accountId != null &&
          snapshot.cards.any((card) => card.id == shortcut.accountId);
      final category = resolveCategoryName(
        shortcut.category,
        ref.read(settingsProvider).categories.keys,
      );
      final defaultAccountId = ref
          .read(userProfileRepositoryProvider)
          ?.defaultAccountId;
      await ref
          .read(transactionRepositoryProvider)
          .addTransaction(
            TransactionDraft(
              merchant: shortcut.name,
              category: category,
              amount: shortcut.isIncome ? amount : -amount,
              date: DateTime.now(),
              addedAt: DateTime.now(),
              accountId: isCard
                  ? null
                  : (shortcut.accountId ?? defaultAccountId),
              cardId: isCard ? shortcut.accountId : null,
            ),
          );
      _controller.clear();
      ref
          .read(toastProvider.notifier)
          .show('Logged ${shortcut.name} ${rupee(amount)}');
      return;
    }

    final parsed = CaptureParser.parse(input);
    if (parsed == null) {
      ref
          .read(toastProvider.notifier)
          .show('Add an amount, e.g. “chai 40” or “uber 280”');
      return;
    }

    final learned = _learn(parsed.merchant, snapshot);
    final learnedCategory =
        learned.category == 'Income' || learned.category == 'Transfer'
        ? null
        : learned.category;
    final category = resolveCategoryName(
      parsed.isIncome
          ? 'Income'
          : (parsed.categoryDetected
                ? parsed.category
                : (learnedCategory ?? 'Other')),
      ref.read(settingsProvider).categories.keys,
    );

    _controller.clear();
    await showAddTransactionSheet(
      context,
      merchant: parsed.merchant,
      amount: parsed.amount,
      category: category,
      accountId: learned.accountId,
      cardId: learned.cardId,
    );
  }

  String _normalizeMerchant(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  ({String? category, String? accountId, String? cardId}) _learn(
    String merchant,
    FinanceSnapshot snapshot,
  ) {
    final key = _normalizeMerchant(merchant);
    Transaction? recent;
    for (final transaction in snapshot.transactions) {
      if (_normalizeMerchant(transaction.merchant) == key &&
          (recent == null || transaction.date.isAfter(recent.date))) {
        recent = transaction;
      }
    }

    final defaultAccountId = ref
        .read(userProfileRepositoryProvider)
        ?.defaultAccountId;
    if (defaultAccountId != null &&
        snapshot.accounts.any((account) => account.id == defaultAccountId)) {
      return (
        category: recent?.category,
        accountId: defaultAccountId,
        cardId: null,
      );
    }
    final recentCard = recent?.cardId;
    if (recentCard != null) {
      return (category: recent?.category, accountId: null, cardId: recentCard);
    }
    final recentAccount = recent?.accountId;
    if (recentAccount != null &&
        snapshot.accounts.any((account) => account.id == recentAccount)) {
      return (
        category: recent?.category,
        accountId: recentAccount,
        cardId: null,
      );
    }
    return (
      category: recent?.category,
      accountId: snapshot.accounts.isEmpty ? null : snapshot.accounts.first.id,
      cardId: null,
    );
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
          Pressable(
            onTap: _submit,
            scale: 0.92,
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
  showVoiceCaptureSheet(context);
}

void _showScan(BuildContext context) {
  showReceiptScannerSheet(context);
}

class _CashRunwayHero extends StatelessWidget {
  const _CashRunwayHero({required this.snapshot, required this.onOpen});

  final FinanceSnapshot snapshot;
  final VoidCallback onOpen;

  String _money(double value) => '${value < 0 ? '−' : ''}${compactINR(value)}';

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final runway = FinanceCalculator.cashRunway(snapshot);
    final shortfall = runway.isShortfall;
    final noData = snapshot.accounts.isEmpty && snapshot.transactions.isEmpty;
    final tight = !shortfall && runway.lowestBalance < runway.dailySpend * 7;
    final status = noData
        ? 'No data'
        : shortfall
        ? 'Shortfall'
        : tight
        ? 'Tight'
        : 'Covered';
    final accent = shortfall ? c.co : c.ac;
    final lowIndex = runway.points.indexWhere(
      (point) => point.date == runway.lowestDate,
    );
    final billIndices = <int>{
      for (final event in runway.events.where((event) => !event.isIncome))
        event.date.difference(runway.startDate).inDays,
    };
    final paydayIndex = runway.paydayInWindow
        ? runway.payday!.difference(runway.startDate).inDays
        : null;

    return Pressable(
      onTap: () => showCashRunwaySheet(context),
      scale: 0.995,
      child: GlowCard(
        color: accent,
        margin: const EdgeInsets.only(top: 16, bottom: 8),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'CASH RUNWAY',
                  style: AppTypography.sans(
                    size: 11,
                    color: c.mu,
                    letterSpacing: 1.32,
                  ),
                ),
                const SizedBox(width: 6),
                SpendIcon('info', size: 13, color: c.mu),
                const Spacer(),
                AppPill(
                  label: status,
                  active: status == 'Covered',
                  textColor: status == 'Covered' ? null : accent,
                  borderColor: status == 'Covered'
                      ? null
                      : accent.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: onOpen,
                  child: Text(
                    'Calendar →',
                    style: AppTypography.sans(size: 12, color: c.ac),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortfall
                            ? runway.paydayInWindow
                                  ? 'Shortfall before payday'
                                  : 'Shortfall in ${runway.days} days'
                            : runway.paydayInWindow
                            ? 'Lowest before payday'
                            : 'Lowest in ${runway.days} days',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                      AnimatedAmount(
                        value: runway.lowestBalance,
                        formatter: (value) => formatINR(value),
                        style: AppTypography.serif(
                          size: 42,
                          color: shortfall ? c.co : c.tx,
                          letterSpacing: -1,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        runway.paydayInWindow
                            ? '${dayMonth(runway.lowestDate)} · payday ${dayMonth(runway.payday!)}'
                            : '${dayMonth(runway.lowestDate)} · next ${runway.days} days',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      runway.paydayInWindow ? 'at payday' : 'now',
                      style: AppTypography.sans(size: 10, color: c.mu),
                    ),
                    Text(
                      _money(
                        runway.paydayInWindow
                            ? runway.endingBalance
                            : runway.startingBalance,
                      ),
                      style: AppTypography.serif(
                        size: 20,
                        color: c.tx,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.985 + 0.015 * value,
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
              child: CashRunwayChart(
                values: [for (final point in runway.points) point.balance],
                lowestIndex: lowIndex < 0 ? 0 : lowIndex,
                billIndices: billIndices,
                paydayIndex: paydayIndex,
                color: accent,
                height: 128,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _RunwayMetric(
                  label: 'Bills',
                  value: compactINR(runway.totalBills),
                ),
                const _RunwayDivider(),
                _RunwayMetric(
                  label: 'Typical spend',
                  value: '${compactINR(runway.dailySpend)}/day',
                ),
                const _RunwayDivider(),
                _RunwayMetric(
                  label: runway.paydayInWindow ? 'Payday' : 'Window',
                  value: runway.paydayInWindow
                      ? _money(runway.expectedIncome)
                      : '${runway.days} days',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunwayMetric extends StatelessWidget {
  const _RunwayMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sans(size: 9, color: c.mu, letterSpacing: 0.8),
          ),
          const SizedBox(height: 3),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.sans(
                size: 13,
                color: c.tx,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunwayDivider extends StatelessWidget {
  const _RunwayDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: context.spend.ln,
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
