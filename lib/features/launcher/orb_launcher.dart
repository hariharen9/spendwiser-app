import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/state/sms_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/services/finance_calculator.dart';
import '../insights/ask_spendwiser_sheet.dart';
import '../shell/app_module.dart';
import '../sms/sms_review_sheet.dart';
import '../transactions/add_transaction_sheet.dart';

class OrbLauncher extends ConsumerStatefulWidget {
  const OrbLauncher({
    super.key,
    required this.current,
    required this.onNavigate,
    required this.onClose,
  });

  final AppModule current;
  final ValueChanged<AppModule> onNavigate;
  final VoidCallback onClose;

  @override
  ConsumerState<OrbLauncher> createState() => _OrbLauncherState();
}

class _OrbLauncherState extends ConsumerState<OrbLauncher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _search.dispose();
    super.dispose();
  }

  String _metric(AppModule module, FinanceSnapshot s) {
    final now = DateTime.now();
    return switch (module) {
      AppModule.home =>
        '${compactINR(FinanceCalculator.safeToSpend(s, now: now).perDay)} safe today',
      AppModule.ledger => '${s.transactions.length} entries',
      AppModule.accounts => 'Net ${compactINR(s.accountsTotal - s.cardDues)}',
      AppModule.cards =>
        '${compactINR(s.cardDues)} due${s.cards.isEmpty ? '' : ' · ${math.max(0, FinanceCalculator.earliestCardDue(s)?.days ?? 0)}d'}',
      AppModule.budgets =>
        '${compactINR((s.totalBudgetLimit - (s.hasTotalBudget ? s.expensesIn(now) : s.totalBudgetSpent)).clamp(0, double.infinity))} left',
      AppModule.subscriptions => '${compactINR(s.monthlySubscriptionCost)}/mo',
      AppModule.debt => '${compactINR(s.monthlyEmis)} EMI/mo',
      AppModule.split => 'Owed ${compactINR(s.youAreOwed.abs())}',
      AppModule.goals => '${s.goalsProgress.round()}% funded',
      AppModule.calendar =>
        '${FinanceCalculator.bills(s, now: now).where((b) => b.days <= 7).length} bills this week',
      AppModule.insights => 'Health ${FinanceCalculator.health(s, now: now).score}',
      AppModule.tools => 'Calc · SIP',
      AppModule.settings =>
        '${ref.read(settingsProvider).themeLabel} · INR · Synced',
    };
  }

  bool _hasAlert(AppModule module, FinanceSnapshot s) {
    return switch (module) {
      AppModule.cards => s.cards.any((c) => c.hasDue),
      AppModule.budgets => s.budgets.any((b) => b.progress > 0.85),
      AppModule.subscriptions => s.subscriptions.any(
        (sub) => sub.active && sub.note != null,
      ),
      AppModule.debt => s.loans.any(
        (l) => FinanceCalculator.loanDue(l).overdue,
      ),
      _ => false,
    };
  }

  void _quick(VoidCallback action) {
    widget.onClose();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final settings = ref.watch(settingsProvider);
    final snapshot = ref.watch(financeSnapshotProvider);
    final smsCount = ref.watch(smsReviewProvider).length;
    final modules = AppModule.values
        .where(
          (m) =>
              _query.isEmpty ||
              m.label.toLowerCase().contains(_query.toLowerCase()) ||
              m.subtitle.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return ClipRect(
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: ColoredBox(
            color: c.bg.withValues(alpha: 0.72),
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top > 40
                      ? MediaQuery.paddingOf(context).top + 6
                      : 50,
                  16,
                  130,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final column = (width - 16) / 3;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FadeSlide(
                          animation: _entrance,
                          interval: const Interval(
                            0,
                            0.28,
                            curve: Curves.easeOut,
                          ),
                          offset: const Offset(0, -12),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: c.c1,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.ln),
                            ),
                            child: Row(
                              children: [
                                SpendIcon('search', size: 18, color: c.mu),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _search,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: AppTypography.sans(
                                      size: 14,
                                      color: c.tx,
                                    ),
                                    textInputAction: TextInputAction.search,
                                    onChanged: (value) =>
                                        setState(() => _query = value.trim()),
                                    onSubmitted: (_) {
                                      if (modules.isNotEmpty) {
                                        widget.onNavigate(modules.first);
                                      } else if (_query.isNotEmpty) {
                                        _quick(
                                          () => showAskSpendwiserSheet(
                                            context,
                                            initialQuery: _query,
                                            onOpenLedger: () => widget
                                                .onNavigate(AppModule.ledger),
                                          ),
                                        );
                                      }
                                    },
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      hintText: 'Jump to anything, or ask a question…',
                                      hintStyle: AppTypography.sans(
                                        size: 14,
                                        color: c.mu,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _FadeSlide(
                          animation: _entrance,
                          interval: const Interval(
                            0.04,
                            0.32,
                            curve: Curves.easeOut,
                          ),
                          offset: const Offset(0, -10),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                AppPill(
                                  label: '＋ Transaction',
                                  onTap: () => _quick(
                                    () => showAddTransactionSheet(context),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AppPill(
                                  label: 'Pay card',
                                  onTap: () =>
                                      widget.onNavigate(AppModule.cards),
                                ),
                                const SizedBox(width: 8),
                                AppPill(
                                  label: 'Split bill',
                                  onTap: () =>
                                      widget.onNavigate(AppModule.split),
                                ),
                                const SizedBox(width: 8),
                                if (smsCount > 0) ...[
                                  AppPill(
                                    label: 'Review SMS · $smsCount',
                                    onTap: () => _quick(
                                      () => showSmsReviewSheet(context),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                AppPill(
                                  label: 'Ask Spendwiser',
                                  onTap: () => _quick(
                                    () => showAskSpendwiserSheet(
                                      context,
                                      onOpenLedger: () =>
                                          widget.onNavigate(AppModule.ledger),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < modules.length; i++)
                              _buildTile(
                                context,
                                module: modules[i],
                                index: i,
                                width: modules[i].fullWidth
                                    ? width
                                    : modules[i].wide
                                    ? column * 2 + 8
                                    : column,
                                snapshot: snapshot,
                                settingsLabel: settings.themeLabel,
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildTile(
    BuildContext context, {
    required AppModule module,
    required int index,
    required double width,
    required FinanceSnapshot snapshot,
    required String settingsLabel,
  }) {
    final c = context.spend;
    final current = module == widget.current;
    final fullWidth = module.fullWidth;
    final height = fullWidth ? 56.0 : 96.0;
    final isWide = module.wide;
    final alert = _hasAlert(module, snapshot);
    final fg = current ? c.aci : c.tx;
    final subColor = current ? c.aci.withValues(alpha: 0.7) : c.mu;

    final tile = Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: fullWidth ? 14 : 12,
        vertical: fullWidth ? 0 : 10,
      ),
      decoration: BoxDecoration(
        color: current
            ? c.ac
            : (c.dark
                  ? c.c1.withValues(alpha: 0.88)
                  : c.c1.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(fullWidth ? 20 : 24),
        border: Border.all(color: current ? c.ac : c.ln),
      ),
      child: fullWidth
          ? Row(
              children: [
                IconTile(
                  icon: module.icon,
                  color: current ? c.aci : module.tint,
                  size: 30,
                  backgroundOpacity: current ? 0.14 : 0.16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    module.label,
                    style: AppTypography.sans(
                      size: 14,
                      color: fg,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '$settingsLabel · INR · Local',
                  style: AppTypography.sans(size: 12, color: subColor),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(
                      icon: module.icon,
                      color: current ? c.aci : module.tint,
                      size: 30,
                      backgroundOpacity: current ? 0.14 : 0.16,
                    ),
                    const Spacer(),
                    if (alert)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.co,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: c.co.withValues(alpha: 0.25),
                              blurRadius: 0,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isWide
                          ? AppTypography.sans(
                              size: 12,
                              color: subColor,
                              weight: FontWeight.w500,
                            )
                          : AppTypography.sans(
                              size: 14,
                              color: fg,
                              weight: FontWeight.w500,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metric(module, snapshot),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isWide
                          ? AppTypography.serif(
                              size: 19,
                              color: fg,
                              height: 1.05,
                            )
                          : AppTypography.sans(size: 11, color: subColor),
                    ),
                  ],
                ),
              ],
            ),
    );

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final start = (index * 0.035).clamp(0.0, 0.55);
        final end = (start + 0.45).clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(
          Interval(start, end).transform(_entrance.value),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 260 * (1 - t)),
            child: Transform.scale(
              scale: 0.6 + 0.4 * t,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: Pressable(onTap: () => widget.onNavigate(module), child: tile),
    );
  }
}

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({
    required this.animation,
    required this.interval,
    required this.offset,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = interval.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: offset * (1 - t), child: child),
        );
      },
      child: child,
    );
  }
}
