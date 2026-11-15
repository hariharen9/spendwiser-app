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
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/premium_sheet.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/subscription.dart';
import '../insights/services/ask_ai_client.dart';
import '../insights/widgets/formatted_ai_response.dart';

enum _SubFilter { all, dueSoon, active, paused }
enum _SubSort { renewsSoonest, costHighToLow, nameAZ }
enum _RecFilter { all, income, expense, active, paused }

const _inGreen = Color(0xFF34D399);

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  bool _recurringMode = false;
  _SubFilter _subFilter = _SubFilter.all;
  _SubSort _subSort = _SubSort.renewsSoonest;
  _RecFilter _recFilter = _RecFilter.all;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);

    final subs = snapshot.subscriptions;
    final activeSubs = subs.where((s) => s.active).toList();
    final pausedSubs = subs.where((s) => !s.active).toList();
    final monthlyTotal = activeSubs.fold<double>(0, (sum, s) => sum + s.price);
    final yearlyTotal = monthlyTotal * 12;

    final dueSoonSubs = activeSubs.where((s) => s.renewsInDays <= 7).toList();
    final dueSoonTotal = dueSoonSubs.fold<double>(0, (sum, s) => sum + s.price);

    // Apply sorting
    final sortedSubs = [...subs];
    switch (_subSort) {
      case _SubSort.renewsSoonest:
        sortedSubs.sort((a, b) {
          if (a.active != b.active) return a.active ? -1 : 1;
          return a.renewsInDays.compareTo(b.renewsInDays);
        });
      case _SubSort.costHighToLow:
        sortedSubs.sort((a, b) => b.price.compareTo(a.price));
      case _SubSort.nameAZ:
        sortedSubs.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }

    // Apply filter
    final filteredSubs = sortedSubs.where((s) {
      return switch (_subFilter) {
        _SubFilter.all => true,
        _SubFilter.dueSoon => s.active && s.renewsInDays <= 7,
        _SubFilter.active => s.active,
        _SubFilter.paused => !s.active,
      };
    }).toList();

    // Grouping
    final groupDueSoon = filteredSubs
        .where((s) => s.active && s.renewsInDays <= 7)
        .toList();
    final groupThisMonth = filteredSubs
        .where((s) => s.active && s.renewsInDays > 7 && s.renewsInDays <= 30)
        .toList();
    final groupLater = filteredSubs
        .where((s) => s.active && s.renewsInDays > 30)
        .toList();
    final groupPaused = filteredSubs.where((s) => !s.active).toList();

    // Recurring items
    final recurring = snapshot.recurring;
    final monthlyIn = recurring
        .where((r) => r.active && r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.monthlyAmount);
    final monthlyOut = recurring
        .where((r) => r.active && !r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.monthlyAmount);
    final netRecurring = monthlyIn - monthlyOut;

    final filteredRecurring = recurring.where((r) {
      return switch (_recFilter) {
        _RecFilter.all => true,
        _RecFilter.income => r.isIncome,
        _RecFilter.expense => !r.isIncome,
        _RecFilter.active => r.active,
        _RecFilter.paused => !r.active,
      };
    }).toList();

    final hasAi = ref.watch(settingsProvider).hasAiKey;

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Subscriptions',
          subtitle: _recurringMode
              ? 'Predictable inflows & outflows'
              : '${rupee(monthlyTotal)} / month · ${rupee(yearlyTotal)} / year',
          trailing: hasAi
              ? AppPill(
                  label: 'Audit leaks',
                  active: true,
                  leading: SpendIcon('sparkle', size: 13, color: c.aci),
                  onTap: () => _showSubscriptionAudit(context),
                )
              : null,
        ),
        SegmentedControl<bool>(
          options: [
            SegmentedOption(false, 'Subscriptions (${activeSubs.length})'),
            SegmentedOption(true, 'Recurring rules (${recurring.length})'),
          ],
          selected: _recurringMode,
          onChanged: (value) => setState(() => _recurringMode = value),
        ),
        const SizedBox(height: 12),
        if (!_recurringMode) ...[
          // Subscriptions Hero Card
          _SubscriptionHeroCard(
            monthlyTotal: monthlyTotal,
            yearlyTotal: yearlyTotal,
            activeCount: activeSubs.length,
            pausedCount: pausedSubs.length,
            dueSoonCount: dueSoonSubs.length,
            dueSoonTotal: dueSoonTotal,
            onAddTap: () => _addSubscription(context),
          ),
          const SizedBox(height: 14),

          // Filters & Sort
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppPill(
                        label: 'All (${subs.length})',
                        active: _subFilter == _SubFilter.all,
                        onTap: () => setState(() => _subFilter = _SubFilter.all),
                      ),
                      const SizedBox(width: 6),
                      AppPill(
                        label: 'Due soon (${dueSoonSubs.length})',
                        active: _subFilter == _SubFilter.dueSoon,
                        color: dueSoonSubs.isNotEmpty ? c.co : null,
                        onTap: () => setState(() => _subFilter = _SubFilter.dueSoon),
                      ),
                      const SizedBox(width: 6),
                      AppPill(
                        label: 'Active (${activeSubs.length})',
                        active: _subFilter == _SubFilter.active,
                        onTap: () => setState(() => _subFilter = _SubFilter.active),
                      ),
                      const SizedBox(width: 6),
                      AppPill(
                        label: 'Paused (${pausedSubs.length})',
                        active: _subFilter == _SubFilter.paused,
                        onTap: () => setState(() => _subFilter = _SubFilter.paused),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_SubSort>(
                tooltip: 'Sort subscriptions',
                initialValue: _subSort,
                onSelected: (sort) => setState(() => _subSort = sort),
                color: c.c1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: c.ln),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.c2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.ln),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpendIcon('filter', size: 13, color: c.mu),
                      const SizedBox(width: 4),
                      Text(
                        switch (_subSort) {
                          _SubSort.renewsSoonest => 'Soonest',
                          _SubSort.costHighToLow => 'Cost',
                          _SubSort.nameAZ => 'A-Z',
                        },
                        style: AppTypography.sans(size: 11, color: c.tx),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _SubSort.renewsSoonest,
                    child: Text('Renews soonest'),
                  ),
                  const PopupMenuItem(
                    value: _SubSort.costHighToLow,
                    child: Text('Cost: High to low'),
                  ),
                  const PopupMenuItem(
                    value: _SubSort.nameAZ,
                    child: Text('Name: A to Z'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (filteredSubs.isEmpty)
            EmptyState(
              title: subs.isEmpty ? 'No subscriptions tracked' : 'No matching subscriptions',
              message: subs.isEmpty
                  ? 'Track Netflix, Spotify, cloud plans and never get surprised by auto-renewals.'
                  : 'Try changing your filter to view all subscriptions.',
              actionLabel: '+ Add subscription',
              onAction: () => _addSubscription(context),
            )
          else ...[
            if (_subFilter == _SubFilter.all) ...[
              if (groupDueSoon.isNotEmpty) ...[
                _SectionTitle(
                  label: 'Due this week',
                  count: groupDueSoon.length,
                  badgeColor: c.co,
                ),
                _SubscriptionCardGroup(
                  items: groupDueSoon,
                  onTap: (sub) => _editSubscription(context, sub),
                  onToggle: (sub) => ref
                      .read(subscriptionRepositoryProvider)
                      .toggleSubscription(sub.id),
                ),
                const SizedBox(height: 14),
              ],
              if (groupThisMonth.isNotEmpty) ...[
                _SectionTitle(
                  label: 'Renewing this month',
                  count: groupThisMonth.length,
                ),
                _SubscriptionCardGroup(
                  items: groupThisMonth,
                  onTap: (sub) => _editSubscription(context, sub),
                  onToggle: (sub) => ref
                      .read(subscriptionRepositoryProvider)
                      .toggleSubscription(sub.id),
                ),
                const SizedBox(height: 14),
              ],
              if (groupLater.isNotEmpty) ...[
                _SectionTitle(
                  label: 'Later / Annual',
                  count: groupLater.length,
                ),
                _SubscriptionCardGroup(
                  items: groupLater,
                  onTap: (sub) => _editSubscription(context, sub),
                  onToggle: (sub) => ref
                      .read(subscriptionRepositoryProvider)
                      .toggleSubscription(sub.id),
                ),
                const SizedBox(height: 14),
              ],
              if (groupPaused.isNotEmpty) ...[
                _SectionTitle(
                  label: 'Paused subscriptions',
                  count: groupPaused.length,
                  isMuted: true,
                ),
                _SubscriptionCardGroup(
                  items: groupPaused,
                  onTap: (sub) => _editSubscription(context, sub),
                  onToggle: (sub) => ref
                      .read(subscriptionRepositoryProvider)
                      .toggleSubscription(sub.id),
                ),
              ],
            ] else ...[
              _SubscriptionCardGroup(
                items: filteredSubs,
                onTap: (sub) => _editSubscription(context, sub),
                onToggle: (sub) => ref
                    .read(subscriptionRepositoryProvider)
                    .toggleSubscription(sub.id),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: '+ Add subscription',
              onTap: () => _addSubscription(context),
            ),
          ],
        ] else ...[
          // Recurring Mode
          _RecurringHeroBanner(
            monthlyIn: monthlyIn,
            monthlyOut: monthlyOut,
            netRecurring: netRecurring,
            onAddTap: () => _addRecurring(context),
          ),
          const SizedBox(height: 14),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AppPill(
                  label: 'All (${recurring.length})',
                  active: _recFilter == _RecFilter.all,
                  onTap: () => setState(() => _recFilter = _RecFilter.all),
                ),
                const SizedBox(width: 6),
                AppPill(
                  label: 'Income (${recurring.where((r) => r.isIncome).length})',
                  active: _recFilter == _RecFilter.income,
                  color: _inGreen,
                  onTap: () => setState(() => _recFilter = _RecFilter.income),
                ),
                const SizedBox(width: 6),
                AppPill(
                  label: 'Expense (${recurring.where((r) => !r.isIncome).length})',
                  active: _recFilter == _RecFilter.expense,
                  color: c.co,
                  onTap: () => setState(() => _recFilter = _RecFilter.expense),
                ),
                const SizedBox(width: 6),
                AppPill(
                  label: 'Active (${recurring.where((r) => r.active).length})',
                  active: _recFilter == _RecFilter.active,
                  onTap: () => setState(() => _recFilter = _RecFilter.active),
                ),
                const SizedBox(width: 6),
                AppPill(
                  label: 'Paused (${recurring.where((r) => !r.active).length})',
                  active: _recFilter == _RecFilter.paused,
                  onTap: () => setState(() => _recFilter = _RecFilter.paused),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filteredRecurring.isEmpty)
            EmptyState(
              title: recurring.isEmpty ? 'No recurring rules tracked' : 'No matching recurring items',
              message: recurring.isEmpty
                  ? 'Add your salary, house rent, EMIs or SIPs to automatically forecast cash flow.'
                  : 'Try changing your filter to view all recurring rules.',
              actionLabel: '+ Add recurring rule',
              onAction: () => _addRecurring(context),
            )
          else ...[
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < filteredRecurring.length; i++)
                    _RecurringRow(
                      recurring: filteredRecurring[i],
                      showDivider: i < filteredRecurring.length - 1,
                      onTap: () => _editRecurring(context, filteredRecurring[i]),
                      onToggle: () {
                        ref.read(subscriptionRepositoryProvider).updateRecurring(
                              filteredRecurring[i].copyWith(
                                active: !filteredRecurring[i].active,
                              ),
                            );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: '+ Add recurring rule',
              onTap: () => _addRecurring(context),
            ),
          ],
        ],
      ],
    );
  }

  void _addSubscription(BuildContext context) {
    showAppSheet<void>(context, (_) => const _AddSubscriptionSheet());
  }

  void _editSubscription(BuildContext context, Subscription subscription) {
    showAppSheet<void>(
      context,
      (_) => _EditSubscriptionSheet(subscription: subscription),
    );
  }

  void _addRecurring(BuildContext context) {
    showAppSheet<void>(context, (_) => const _AddRecurringSheet());
  }

  void _editRecurring(BuildContext context, RecurringTransaction recurring) {
    showAppSheet<void>(
      context,
      (_) => _EditRecurringSheet(recurring: recurring),
    );
  }

  void _showSubscriptionAudit(BuildContext context) {
    final settings = ref.read(settingsProvider);
    final snapshot = ref.read(financeSnapshotProvider);
    final future = AskAiClient.auditSubscriptions(
      provider: settings.aiProvider,
      apiKey: settings.aiApiKey.trim(),
      model: settings.effectiveAiModel,
      snapshot: snapshot,
    );
    showAppSheet<void>(
      context,
      (sheetContext) => FutureBuilder<String>(
        future: future,
        builder: (context, snap) {
          final c = context.spend;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SpendIcon('sparkle', size: 18, color: c.ac),
                  const SizedBox(width: 8),
                  Text(
                    'Subscription & Leak Audit',
                    style: AppTypography.serif(size: 22, color: c.tx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snap.connectionState == ConnectionState.waiting)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.ac,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Auditing recurring charges...',
                        style: AppTypography.sans(size: 13, color: c.mu),
                      ),
                    ],
                  ),
                )
              else if (snap.hasError)
                Text(
                  snap.error.toString().replaceFirst('Exception: ', ''),
                  style: AppTypography.sans(size: 13, color: c.co),
                )
              else
                FormattedAiResponse(text: snap.data ?? ''),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main UI Building Blocks
// ---------------------------------------------------------------------------

class _SubscriptionHeroCard extends StatelessWidget {
  const _SubscriptionHeroCard({
    required this.monthlyTotal,
    required this.yearlyTotal,
    required this.activeCount,
    required this.pausedCount,
    required this.dueSoonCount,
    required this.dueSoonTotal,
    required this.onAddTap,
  });

  final double monthlyTotal;
  final double yearlyTotal;
  final int activeCount;
  final int pausedCount;
  final int dueSoonCount;
  final double dueSoonTotal;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.ac.withValues(alpha: 0.95),
            Color.lerp(c.ac, Colors.black, 0.65)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: c.ac.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MONTHLY COMMITMENT',
                style: AppTypography.sans(
                  size: 11,
                  color: c.aci.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                  weight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.aci.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rupee(yearlyTotal)} / yr',
                  style: AppTypography.sans(
                    size: 11,
                    color: c.aci,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedAmount(
            value: monthlyTotal,
            style: AppTypography.serif(
              size: 44,
              color: c.aci,
              height: 1.05,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _HeroBadge(
                icon: 'check',
                text: '$activeCount active',
                color: c.aci,
              ),
              if (pausedCount > 0)
                _HeroBadge(
                  icon: 'pause',
                  text: '$pausedCount paused',
                  color: c.aci.withValues(alpha: 0.7),
                ),
              if (dueSoonCount > 0)
                _HeroBadge(
                  icon: 'bell',
                  text: '$dueSoonCount renews this week (${rupee(dueSoonTotal)})',
                  color: Colors.amberAccent,
                  isWarning: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.text,
    required this.color,
    this.isWarning = false,
  });

  final String icon;
  final String text;
  final Color color;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.black.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: isWarning
            ? Border.all(color: Colors.amberAccent.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpendIcon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTypography.sans(
              size: 11,
              color: color,
              weight: isWarning ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringHeroBanner extends StatelessWidget {
  const _RecurringHeroBanner({
    required this.monthlyIn,
    required this.monthlyOut,
    required this.netRecurring,
    required this.onAddTap,
  });

  final double monthlyIn;
  final double monthlyOut;
  final double netRecurring;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final isPositive = netRecurring >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.c1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.ln),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Scheduled In / mo',
                  amount: monthlyIn,
                  formatter: rupee,
                  valueColor: _inGreen,
                ),
              ),
              Container(width: 1, height: 42, color: c.ln),
              Expanded(
                child: MetricTile(
                  label: 'Scheduled Out / mo',
                  amount: monthlyOut,
                  formatter: rupee,
                  valueColor: c.co,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isPositive ? _inGreen : c.co).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net recurring balance',
                  style: AppTypography.sans(size: 12, color: c.tx),
                ),
                Text(
                  '${isPositive ? '+' : ''}${rupee(netRecurring)} / mo',
                  style: AppTypography.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: isPositive ? _inGreen : c.co,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.count,
    this.badgeColor,
    this.isMuted = false,
  });

  final String label;
  final int count;
  final Color? badgeColor;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.sans(
              size: 11,
              weight: FontWeight.w600,
              letterSpacing: 1.1,
              color: isMuted ? c.mu : c.tx,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: (badgeColor ?? c.mu).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: AppTypography.sans(
                size: 10,
                weight: FontWeight.w700,
                color: badgeColor ?? c.mu,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCardGroup extends StatelessWidget {
  const _SubscriptionCardGroup({
    required this.items,
    required this.onTap,
    required this.onToggle,
  });

  final List<Subscription> items;
  final ValueChanged<Subscription> onTap;
  final ValueChanged<Subscription> onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _SubscriptionRow(
              subscription: items[i],
              showDivider: i < items.length - 1,
              onTap: () => onTap(items[i]),
              onToggle: () => onToggle(items[i]),
            ),
        ],
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.subscription,
    required this.showDivider,
    required this.onTap,
    required this.onToggle,
  });

  final Subscription subscription;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final isDueSoon = subscription.active && subscription.renewsInDays <= 7;
    final isDueToday = subscription.active && subscription.renewsInDays == 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: subscription.active ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: c.ln.withValues(alpha: 0.6)))
                : null,
          ),
          child: Row(
            children: [
              MerchantAvatar(
                merchant: subscription.name,
                category: subscription.category.isNotEmpty
                    ? subscription.category
                    : 'Fun',
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subscription.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.sans(
                              size: 14,
                              weight: FontWeight.w600,
                              color: c.tx,
                            ),
                          ),
                        ),
                        if (subscription.category.isNotEmpty &&
                            subscription.category != 'Other') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: c.c2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subscription.category,
                              style: AppTypography.sans(size: 10, color: c.mu),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (subscription.active) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDueToday
                                  ? c.co.withValues(alpha: 0.18)
                                  : isDueSoon
                                      ? Colors.amber.withValues(alpha: 0.15)
                                      : c.c2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDueToday
                                  ? 'Renews today!'
                                  : subscription.renewsInDays == 1
                                      ? 'Renews tomorrow'
                                      : 'in ${subscription.renewsInDays} days',
                              style: AppTypography.sans(
                                size: 11,
                                weight: isDueSoon
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isDueToday
                                    ? c.co
                                    : isDueSoon
                                        ? Colors.amber[300] ?? c.co
                                        : c.mu,
                              ),
                            ),
                          ),
                          if (subscription.note != null &&
                              subscription.note!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                subscription.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.sans(size: 11, color: c.mu),
                              ),
                            ),
                          ],
                        ] else
                          Text(
                            'Paused',
                            style: AppTypography.sans(size: 11, color: c.mu),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    rupee(subscription.price),
                    style: AppTypography.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: c.tx,
                    ),
                  ),
                  Text(
                    '/mo',
                    style: AppTypography.sans(size: 10, color: c.mu),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              AppToggle(
                value: subscription.active,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({
    required this.recurring,
    required this.showDivider,
    required this.onTap,
    required this.onToggle,
  });

  final RecurringTransaction recurring;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: recurring.active ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: c.ln.withValues(alpha: 0.6)))
                : null,
          ),
          child: Row(
            children: [
              MerchantAvatar(
                merchant: recurring.name,
                category: recurring.isIncome ? 'Income' : recurring.category,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recurring.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: c.tx,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: c.c2,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            recurring.frequency.label,
                            style: AppTypography.sans(size: 10, color: c.mu),
                          ),
                        ),
                        if (recurring.category.isNotEmpty &&
                            recurring.category != 'Other') ...[
                          const SizedBox(width: 6),
                          Text(
                            recurring.category,
                            style: AppTypography.sans(size: 11, color: c.mu),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MoneyText(
                '${recurring.isIncome ? '+' : '-'}${rupee(recurring.amount.abs())}',
                style: AppTypography.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: recurring.isIncome ? _inGreen : c.co,
                ),
              ),
              const SizedBox(width: 10),
              AppToggle(
                value: recurring.active,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rebuilt Add Subscription Sheet
// ---------------------------------------------------------------------------

class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet();

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _renewalDate = DateTime.now().add(const Duration(days: 30));
  String _category = 'Entertainment';
  String? _accountId;
  bool _isYearly = false;

  static const _presets = [
    (name: 'Netflix', price: 649.0, category: 'Entertainment'),
    (name: 'Spotify', price: 119.0, category: 'Entertainment'),
    (name: 'YouTube Premium', price: 149.0, category: 'Entertainment'),
    (name: 'Amazon Prime', price: 299.0, category: 'Entertainment'),
    (name: 'ChatGPT Plus', price: 1999.0, category: 'Cloud'),
    (name: 'iCloud+', price: 219.0, category: 'Cloud'),
    (name: 'Google One', price: 130.0, category: 'Cloud'),
    (name: 'Disney+ Hotstar', price: 299.0, category: 'Entertainment'),
    (name: 'Gym / Fitness', price: 1500.0, category: 'Fitness'),
    (name: 'GitHub Copilot', price: 850.0, category: 'Cloud'),
  ];

  static const _categories = [
    'Entertainment',
    'Cloud',
    'Utilities',
    'Fitness',
    'Education',
    'Bills',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _calculatedDays {
    final today = dateOnly(DateTime.now());
    final target = dateOnly(_renewalDate);
    return math.max(0, target.difference(today).inDays);
  }

  double get _enteredPrice => double.tryParse(_priceController.text) ?? 0;
  double get _monthlyEquivalent => _isYearly ? _enteredPrice / 12 : _enteredPrice;

  void _applyPreset(String name, double price, String category) {
    setState(() {
      _nameController.text = name;
      if (_priceController.text.isEmpty) {
        _priceController.text = price.round().toString();
      }
      _category = category;
    });
  }

  Future<void> _pickRenewalDate(BuildContext context) async {
    final c = context.spend;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewalDate.isBefore(now) ? now : _renewalDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: c.ac,
            onPrimary: c.aci,
            surface: c.c1,
            onSurface: c.tx,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _renewalDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ref.read(toastProvider.notifier).show('Enter a subscription name');
      return;
    }
    if (_enteredPrice <= 0) {
      ref.read(toastProvider.notifier).show('Enter a valid price');
      return;
    }

    final days = _calculatedDays;
    await ref.read(subscriptionRepositoryProvider).addSubscription(
          name: name,
          price: _monthlyEquivalent,
          renewsInDays: days,
          category: _category,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          accountId: _accountId,
          frequency: _isYearly ? RecurringFrequency.yearly : RecurringFrequency.monthly,
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Subscription added (renews in $days days)');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final accounts = snapshot.accounts;
    final days = _calculatedDays;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumSheetHeader(
            icon: 'subscriptions',
            title: 'Add subscription',
            subtitle: 'Keep your recurring charges monitored and predictable.',
          ),
          const SizedBox(height: 16),

          // Quick brand presets
          Text(
            'POPULAR PRESETS',
            style: AppTypography.sans(size: 10, color: c.mu, letterSpacing: 1.1),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AppPill(
                      label: p.name,
                      active: _nameController.text.trim().toLowerCase() ==
                          p.name.toLowerCase(),
                      onTap: () => _applyPreset(p.name, p.price, p.category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Name Field
          const PremiumLabel('Subscription name', requiredField: true),
          PremiumField(
            controller: _nameController,
            hint: 'e.g. Netflix, Spotify',
            icon: 'subscriptions',
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Plan / Tier Note
          const PremiumLabel('Plan tier / Note'),
          PremiumField(
            controller: _noteController,
            hint: 'e.g. 4K Family, Student, Cloud 2TB',
            icon: 'tag',
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Billing cycle & Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumLabel('Amount', requiredField: true),
                    PremiumField(
                      controller: _priceController,
                      hint: '0',
                      number: true,
                      large: true,
                      prefix: '₹ ',
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumLabel('Cycle'),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: c.c2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.ln),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isYearly = false),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !_isYearly ? c.ac : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '/mo',
                                  style: AppTypography.sans(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: !_isYearly ? c.aci : c.mu,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isYearly = true),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _isYearly ? c.ac : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '/yr',
                                  style: AppTypography.sans(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: _isYearly ? c.aci : c.mu,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isYearly && _enteredPrice > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Equivalent to ${rupee(_monthlyEquivalent)} / month',
                style: AppTypography.sans(size: 11, color: c.mu),
              ),
            ),
          const SizedBox(height: 14),

          // Next Renewal Date
          const PremiumLabel('Next renewal date', requiredField: true),
          GestureDetector(
            onTap: () => _pickRenewalDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.c2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.ln),
              ),
              child: Row(
                children: [
                  SpendIcon('calendar', size: 18, color: c.ac),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shortDate(_renewalDate),
                          style: AppTypography.sans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: c.tx,
                          ),
                        ),
                        Text(
                          days == 0
                              ? 'Renews today!'
                              : days == 1
                                  ? 'Renews tomorrow'
                                  : 'Renews in $days days',
                          style: AppTypography.sans(size: 11, color: c.mu),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.c1,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.ln),
                    ),
                    child: Text(
                      'Change',
                      style: AppTypography.sans(size: 11, color: c.ac),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Quick renewal chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in [
                (days: 7, label: '7 days'),
                (days: 14, label: '14 days'),
                (days: 30, label: '30 days'),
                (days: 365, label: '1 year'),
              ])
                AppPill(
                  label: option.label,
                  active: days == option.days,
                  onTap: () {
                    setState(() {
                      _renewalDate = DateTime.now().add(
                        Duration(days: option.days),
                      );
                    });
                  },
                ),
              AppPill(
                label: '1st of next month',
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _renewalDate = DateTime(now.year, now.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category
          const PremiumLabel('Category'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AppPill(
                      label: cat,
                      active: _category == cat,
                      onTap: () => setState(() => _category = cat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Account (optional)
          if (accounts.isNotEmpty) ...[
            const PremiumLabel('Charged to account / card (optional)'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppPill(
                    label: 'Default / None',
                    active: _accountId == null,
                    onTap: () => setState(() => _accountId = null),
                  ),
                  for (final acc in accounts)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: AppPill(
                        label: acc.name,
                        active: _accountId == acc.id,
                        onTap: () => setState(() => _accountId = acc.id),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Summary Card
          PremiumSummaryCard(
            icon: 'subscriptions',
            eyebrow: 'Subscription forecast',
            value: '${rupee(_monthlyEquivalent)} / mo',
            caption: _nameController.text.trim().isEmpty
                ? 'Name this subscription'
                : '${_nameController.text.trim()} · renews in $days days (${shortDate(_renewalDate)})',
            accent: c.ac,
          ),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Add subscription', onTap: _save),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rebuilt Edit Subscription Sheet
// ---------------------------------------------------------------------------

class _EditSubscriptionSheet extends ConsumerStatefulWidget {
  const _EditSubscriptionSheet({required this.subscription});

  final Subscription subscription;

  @override
  ConsumerState<_EditSubscriptionSheet> createState() =>
      _EditSubscriptionSheetState();
}

class _EditSubscriptionSheetState extends ConsumerState<_EditSubscriptionSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;

  late DateTime _renewalDate;
  late String _category;
  late bool _active;

  static const _categories = [
    'Entertainment',
    'Cloud',
    'Utilities',
    'Fitness',
    'Education',
    'Bills',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subscription.name);
    _priceController = TextEditingController(
      text: widget.subscription.price.round().toString(),
    );
    _noteController = TextEditingController(
      text: widget.subscription.note ?? '',
    );
    _renewalDate = DateTime.now().add(
      Duration(days: widget.subscription.renewsInDays),
    );
    _category = widget.subscription.category.isNotEmpty
        ? widget.subscription.category
        : 'Entertainment';
    _active = widget.subscription.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _calculatedDays {
    final today = dateOnly(DateTime.now());
    final target = dateOnly(_renewalDate);
    return math.max(0, target.difference(today).inDays);
  }

  Future<void> _pickRenewalDate(BuildContext context) async {
    final c = context.spend;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewalDate.isBefore(now) ? now : _renewalDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: c.ac,
            onPrimary: c.aci,
            surface: c.c1,
            onSurface: c.tx,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _renewalDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ref.read(toastProvider.notifier).show('Enter subscription name');
      return;
    }
    final price = double.tryParse(_priceController.text) ?? widget.subscription.price;
    final days = _calculatedDays;

    await ref.read(subscriptionRepositoryProvider).updateSubscription(
          widget.subscription.copyWith(
            name: name,
            price: price,
            renewsInDays: days,
            category: _category,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            active: _active,
          ),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Subscription updated');
  }

  Future<void> _delete() async {
    await ref
        .read(subscriptionRepositoryProvider)
        .removeSubscription(widget.subscription.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Subscription deleted');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final days = _calculatedDays;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MerchantAvatar(
                merchant: widget.subscription.name,
                category: _category,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Edit ${widget.subscription.name}',
                  style: AppTypography.serif(size: 24, color: c.tx),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: SpendIcon('closeSmall', size: 18, color: c.mu),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active / Paused switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.ln),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _active ? 'Active subscription' : 'Subscription paused',
                      style: AppTypography.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: _active ? c.tx : c.mu,
                      ),
                    ),
                    Text(
                      _active
                          ? 'Included in monthly spend forecasts'
                          : 'Excluded from monthly budgets and forecasts',
                      style: AppTypography.sans(size: 11, color: c.mu),
                    ),
                  ],
                ),
                AppToggle(
                  value: _active,
                  onChanged: (val) => setState(() => _active = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Name
          const PremiumLabel('Name', requiredField: true),
          PremiumField(
            controller: _nameController,
            hint: 'Name',
            icon: 'subscriptions',
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Note / Plan
          const PremiumLabel('Plan tier / Note'),
          PremiumField(
            controller: _noteController,
            hint: 'e.g. Family 4K',
            icon: 'tag',
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Monthly price
          const PremiumLabel('Monthly price', requiredField: true),
          PremiumField(
            controller: _priceController,
            hint: '0',
            number: true,
            large: true,
            prefix: '₹ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Next Renewal Date
          const PremiumLabel('Next renewal date'),
          GestureDetector(
            onTap: () => _pickRenewalDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.c2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.ln),
              ),
              child: Row(
                children: [
                  SpendIcon('calendar', size: 18, color: c.ac),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shortDate(_renewalDate),
                          style: AppTypography.sans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: c.tx,
                          ),
                        ),
                        Text(
                          days == 0
                              ? 'Renews today!'
                              : days == 1
                                  ? 'Renews tomorrow'
                                  : 'Renews in $days days',
                          style: AppTypography.sans(size: 11, color: c.mu),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.c1,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.ln),
                    ),
                    child: Text(
                      'Change',
                      style: AppTypography.sans(size: 11, color: c.ac),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in [7, 14, 30, 365])
                AppPill(
                  label: d == 365 ? '1 year' : '$d days',
                  active: days == d,
                  onTap: () => setState(
                    () => _renewalDate = DateTime.now().add(Duration(days: d)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Category
          const PremiumLabel('Category'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AppPill(
                      label: cat,
                      active: _category == cat,
                      onTap: () => setState(() => _category = cat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          PrimaryButton(label: 'Save changes', onTap: _save),
          const SizedBox(height: 8),
          AppButton(
            label: 'Cancel subscription',
            color: c.co,
            centered: true,
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rebuilt Add Recurring Sheet
// ---------------------------------------------------------------------------

class _AddRecurringSheet extends ConsumerStatefulWidget {
  const _AddRecurringSheet();

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  RecurringFrequency _frequency = RecurringFrequency.monthly;
  bool _isIncome = false;
  String _category = 'Bills';
  DateTime _startDate = DateTime.now();
  String? _accountId;

  static const _incomeCategories = [
    'Salary',
    'Freelance',
    'Investments',
    'Rental',
    'Other',
  ];

  static const _expenseCategories = [
    'Rent',
    'Bills',
    'SIP',
    'EMI',
    'Insurance',
    'Utilities',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _enteredAmount => double.tryParse(_amountController.text) ?? 0;
  double get _monthlyImpact => _enteredAmount * _frequency.monthlyFactor;

  Future<void> _pickStartDate(BuildContext context) async {
    final c = context.spend;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: c.ac,
            onPrimary: c.aci,
            surface: c.c1,
            onSurface: c.tx,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ref.read(toastProvider.notifier).show('Enter a name');
      return;
    }
    if (_enteredAmount <= 0) {
      ref.read(toastProvider.notifier).show('Enter a valid amount');
      return;
    }

    await ref.read(subscriptionRepositoryProvider).addRecurring(
          name: name,
          amount: _enteredAmount,
          frequency: _frequency,
          isIncome: _isIncome,
          category: _category,
          startDate: _startDate,
          accountId: _accountId,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Recurring rule added');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final accounts = snapshot.accounts;
    final categories = _isIncome ? _incomeCategories : _expenseCategories;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumSheetHeader(
            icon: 'refresh',
            title: 'New recurring rule',
            subtitle: 'Schedule predictable cash flows to forecast your runway.',
          ),
          const SizedBox(height: 16),

          // Income vs Expense Segment
          SegmentedControl<bool>(
            options: const [
              SegmentedOption(false, 'Expense / Outflow'),
              SegmentedOption(true, 'Income / Inflow'),
            ],
            selected: _isIncome,
            onChanged: (val) {
              setState(() {
                _isIncome = val;
                _category = val ? _incomeCategories.first : _expenseCategories.first;
              });
            },
          ),
          const SizedBox(height: 14),

          // Name
          const PremiumLabel('Name / Source', requiredField: true),
          PremiumField(
            controller: _nameController,
            hint: _isIncome ? 'e.g. Monthly Salary, Freelance Retainer' : 'e.g. House Rent, Home Loan EMI, SIP',
            icon: 'refresh',
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Amount
          const PremiumLabel('Amount', requiredField: true),
          PremiumField(
            controller: _amountController,
            hint: '0',
            number: true,
            large: true,
            prefix: '₹ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Frequency
          const PremiumLabel('Frequency'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in RecurringFrequency.values)
                AppPill(
                  label: f.label,
                  active: _frequency == f,
                  onTap: () => setState(() => _frequency = f),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Start Date
          const PremiumLabel('First due date'),
          GestureDetector(
            onTap: () => _pickStartDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.c2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.ln),
              ),
              child: Row(
                children: [
                  SpendIcon('calendar', size: 18, color: c.ac),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shortDate(_startDate),
                      style: AppTypography.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: c.tx,
                      ),
                    ),
                  ),
                  Text('Change', style: AppTypography.sans(size: 11, color: c.ac)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Category
          const PremiumLabel('Category'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AppPill(
                      label: cat,
                      active: _category == cat,
                      onTap: () => setState(() => _category = cat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Account selector (optional)
          if (accounts.isNotEmpty) ...[
            const PremiumLabel('Linked account (optional)'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppPill(
                    label: 'Default',
                    active: _accountId == null,
                    onTap: () => setState(() => _accountId = null),
                  ),
                  for (final acc in accounts)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: AppPill(
                        label: acc.name,
                        active: _accountId == acc.id,
                        onTap: () => setState(() => _accountId = acc.id),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Note
          const PremiumLabel('Notes (optional)'),
          PremiumField(
            controller: _noteController,
            hint: 'e.g. Landlord account, Portfolio reference',
            icon: 'notes',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Impact summary
          PremiumSummaryCard(
            icon: 'refresh',
            eyebrow: _isIncome ? 'Projected income' : 'Projected recurring cost',
            value: rupee(_monthlyImpact),
            caption: '${_frequency.label} · ${rupee(_enteredAmount)} per execution',
            accent: _isIncome ? _inGreen : c.ac,
          ),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Add recurring rule', onTap: _save),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rebuilt Edit Recurring Sheet
// ---------------------------------------------------------------------------

class _EditRecurringSheet extends ConsumerStatefulWidget {
  const _EditRecurringSheet({required this.recurring});

  final RecurringTransaction recurring;

  @override
  ConsumerState<_EditRecurringSheet> createState() =>
      _EditRecurringSheetState();
}

class _EditRecurringSheetState extends ConsumerState<_EditRecurringSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late RecurringFrequency _frequency;
  late bool _isIncome;
  late String _category;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.recurring.name);
    _amountController = TextEditingController(
      text: widget.recurring.amount.abs().round().toString(),
    );
    _noteController = TextEditingController(text: widget.recurring.note ?? '');
    _frequency = widget.recurring.frequency;
    _isIncome = widget.recurring.isIncome;
    _category = widget.recurring.category;
    _active = widget.recurring.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ref.read(toastProvider.notifier).show('Enter a name');
      return;
    }
    final amount = double.tryParse(_amountController.text) ?? widget.recurring.amount.abs();

    await ref.read(subscriptionRepositoryProvider).updateRecurring(
          widget.recurring.copyWith(
            name: name,
            amount: _isIncome ? amount : -amount,
            frequency: _frequency,
            isIncome: _isIncome,
            category: _category,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            active: _active,
          ),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Recurring rule updated');
  }

  Future<void> _delete() async {
    await ref
        .read(subscriptionRepositoryProvider)
        .removeRecurring(widget.recurring.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Recurring rule removed');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MerchantAvatar(
                merchant: widget.recurring.name,
                category: _isIncome ? 'Income' : _category,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Edit ${widget.recurring.name}',
                  style: AppTypography.serif(size: 24, color: c.tx),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: SpendIcon('closeSmall', size: 18, color: c.mu),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active / Paused switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.ln),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _active ? 'Active rule' : 'Rule paused',
                      style: AppTypography.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: _active ? c.tx : c.mu,
                      ),
                    ),
                    Text(
                      _active ? 'Applied to recurring forecasts' : 'Ignored in forecasts',
                      style: AppTypography.sans(size: 11, color: c.mu),
                    ),
                  ],
                ),
                AppToggle(
                  value: _active,
                  onChanged: (val) => setState(() => _active = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Name
          const PremiumLabel('Name', requiredField: true),
          PremiumField(
            controller: _nameController,
            hint: 'Name',
            icon: 'refresh',
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Amount
          const PremiumLabel('Amount', requiredField: true),
          PremiumField(
            controller: _amountController,
            hint: '0',
            number: true,
            large: true,
            prefix: '₹ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Frequency
          const PremiumLabel('Frequency'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in RecurringFrequency.values)
                AppPill(
                  label: f.label,
                  active: _frequency == f,
                  onTap: () => setState(() => _frequency = f),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Type
          const PremiumLabel('Type'),
          SegmentedControl<bool>(
            options: const [
              SegmentedOption(false, 'Expense'),
              SegmentedOption(true, 'Income'),
            ],
            selected: _isIncome,
            onChanged: (val) => setState(() => _isIncome = val),
          ),
          const SizedBox(height: 14),

          // Note
          const PremiumLabel('Notes'),
          PremiumField(
            controller: _noteController,
            hint: 'Notes',
            icon: 'notes',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          PrimaryButton(label: 'Save changes', onTap: _save),
          const SizedBox(height: 8),
          AppButton(
            label: 'Delete recurring rule',
            color: c.co,
            centered: true,
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}
