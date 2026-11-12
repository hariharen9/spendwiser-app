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
import '../../data/models/account.dart';
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
    final runway = FinanceCalculator.cashRunway(s, now: now);
    return switch (module) {
      AppModule.home =>
        runway.isShortfall
            ? 'Shortfall before payday'
            : '${compactINR(runway.lowestBalance)} runway low',
      AppModule.ledger => '${s.transactions.length} entries',
      AppModule.accounts =>
        '${compactINR(s.accounts.where((a) => a.type != AccountType.investments).fold<double>(0, (sum, a) => sum + a.balance))} available',
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
      AppModule.insights =>
        'Health ${FinanceCalculator.health(s, now: now).score}',
      AppModule.tools => 'Calc · SIP',
      AppModule.ai =>
        '${ref.read(settingsProvider).aiProvider.label} · Copilot',
      AppModule.settings =>
        '${ref.read(settingsProvider).themeLabel} · INR · ${ref.read(userProfileRepositoryProvider) != null ? 'Synced' : 'Local'}',
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
              (m != AppModule.ai || settings.hasAiKey) &&
              (_query.isEmpty ||
                  m.label.toLowerCase().contains(_query.toLowerCase()) ||
                  m.subtitle.toLowerCase().contains(_query.toLowerCase())),
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
                                          onOpenLedger: () => widget.onNavigate(
                                            AppModule.ledger,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    hintText:
                                        'Jump to anything, or ask a question…',
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
                                onTap: () => widget.onNavigate(AppModule.cards),
                              ),
                              const SizedBox(width: 8),
                              AppPill(
                                label: 'Split bill',
                                onTap: () => widget.onNavigate(AppModule.split),
                              ),
                              const SizedBox(width: 8),
                              if (smsCount > 0) ...[
                                AppPill(
                                  label: 'Review SMS · $smsCount',
                                  onTap: () =>
                                      _quick(() => showSmsReviewSheet(context)),
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
                      if (_query.isEmpty) ...[
                        _buildBento(
                          context,
                          width: width,
                          column: column,
                          modules: modules
                              .where(
                                (m) =>
                                    m != AppModule.settings &&
                                    m != AppModule.ai,
                              )
                              .toList(),
                          snapshot: snapshot,
                          settingsLabel: settings.themeLabel,
                        ),
                        if (modules.contains(AppModule.ai)) ...[
                          const SizedBox(height: 8),
                          _buildTile(
                            context,
                            module: AppModule.ai,
                            index: modules.length - 2,
                            width: width,
                            snapshot: snapshot,
                            settingsLabel: settings.themeLabel,
                          ),
                        ],
                        if (modules.contains(AppModule.settings)) ...[
                          const SizedBox(height: 8),
                          _buildTile(
                            context,
                            module: AppModule.settings,
                            index: modules.length - 1,
                            width: width,
                            snapshot: snapshot,
                            settingsLabel: settings.themeLabel,
                          ),
                        ],
                      ] else
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

  Widget _buildBento(
    BuildContext context, {
    required double width,
    required double column,
    required List<AppModule> modules,
    required FinanceSnapshot snapshot,
    required String settingsLabel,
  }) {
    final available = {for (final module in modules) module: module};
    var index = 0;

    Widget tile(
      AppModule module, {
      required double width,
      required double height,
      bool wide = false,
      bool prominent = false,
      bool dense = false,
    }) {
      final resolved = available[module];
      if (resolved == null) return const SizedBox.shrink();
      return _buildTile(
        context,
        module: resolved,
        index: index++,
        width: width,
        height: height,
        wideLayout: wide,
        prominent: prominent,
        dense: dense,
        snapshot: snapshot,
        settingsLabel: settingsLabel,
      );
    }

    final smallColumn = (width - 24) / 4;
    Widget small(AppModule module) =>
        tile(module, width: smallColumn, height: 96, dense: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile(
              AppModule.home,
              width: column * 2 + 8,
              height: 160,
              wide: true,
              prominent: true,
            ),
            const SizedBox(width: 8),
            tile(
              AppModule.ledger,
              width: column,
              height: 160,
              prominent: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile(
              AppModule.cards,
              width: column * 2 + 8,
              height: 144,
              wide: true,
              prominent: true,
            ),
            const SizedBox(width: 8),
            tile(
              AppModule.debt,
              width: column,
              height: 144,
              prominent: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            small(AppModule.accounts),
            const SizedBox(width: 8),
            small(AppModule.budgets),
            const SizedBox(width: 8),
            small(AppModule.subscriptions),
            const SizedBox(width: 8),
            small(AppModule.split),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            small(AppModule.goals),
            const SizedBox(width: 8),
            small(AppModule.calendar),
            const SizedBox(width: 8),
            small(AppModule.insights),
            const SizedBox(width: 8),
            small(AppModule.tools),
          ],
        ),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required AppModule module,
    required int index,
    required double width,
    double? height,
    bool? wideLayout,
    bool prominent = false,
    bool dense = false,
    required FinanceSnapshot snapshot,
    required String settingsLabel,
  }) {
    final c = context.spend;
    final current = module == widget.current;
    final fullWidth = module.fullWidth;
    final tileHeight = height ?? (fullWidth ? 56.0 : 96.0);
    final isWide = wideLayout ?? module.wide;
    final featured = prominent || tileHeight >= 150;
    final huge = tileHeight >= 150;
    final compact = dense || (!featured && tileHeight < 92);
    final alert = _hasAlert(module, snapshot);
    final fg = current ? c.aci : c.tx;
    final subColor = current ? c.aci.withValues(alpha: 0.7) : c.mu;
    final iconSize = huge
        ? 38.0
        : (featured ? 34.0 : (compact ? 26.0 : 30.0));
    final radius = fullWidth
        ? 20.0
        : (huge ? 28.0 : (featured ? 26.0 : (compact ? 20.0 : 24.0)));

    final labelStyle = isWide || featured
        ? AppTypography.sans(
            size: huge ? 14 : (featured ? 13 : 12),
            color: subColor,
            weight: FontWeight.w500,
          )
        : AppTypography.sans(
            size: compact ? 13 : 14,
            color: fg,
            weight: FontWeight.w500,
          );

    final metricStyle = featured
        ? AppTypography.serif(
            size: isWide ? (huge ? 24 : 21) : (huge ? 19 : 17),
            color: fg,
            height: 1.05,
          )
        : isWide
        ? AppTypography.serif(
            size: compact ? 17 : 19,
            color: fg,
            height: 1.05,
          )
        : AppTypography.sans(
            size: compact ? 9.5 : 11,
            color: subColor,
          );

    final tile = Container(
      width: width,
      height: tileHeight,
      padding: fullWidth
          ? const EdgeInsets.symmetric(horizontal: 14)
          : EdgeInsets.symmetric(
              horizontal: 12,
              vertical: huge
                  ? 16
                  : (featured ? 14 : (compact ? 8 : 10)),
            ),
      decoration: BoxDecoration(
        color: current
            ? c.ac
            : (c.dark
                  ? c.c1.withValues(alpha: 0.88)
                  : c.c1.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(radius),
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
                  _metric(module, snapshot),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      size: iconSize,
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
                      style: labelStyle,
                    ),
                    if (huge) ...[
                      const SizedBox(height: 2),
                      Text(
                        module.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sans(
                          size: 10,
                          color: subColor.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _metric(module, snapshot),
                      maxLines: compact
                          ? 2
                          : (featured && !isWide ? 2 : 1),
                      overflow: TextOverflow.ellipsis,
                      style: metricStyle,
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
