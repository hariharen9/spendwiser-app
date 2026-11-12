import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/premium_sheet.dart';
import '../../../core/widgets/section_caption.dart';
import '../../../data/services/finance_calculator.dart';

Future<void> showCashRunwaySheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _CashRunwaySheet());
}

class _CashRunwaySheet extends ConsumerWidget {
  const _CashRunwaySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final runway = FinanceCalculator.cashRunway(snapshot);
    final noData = snapshot.accounts.isEmpty && snapshot.transactions.isEmpty;
    if (noData) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSheetHeader(
            icon: 'cash',
            title: 'Cash runway',
            subtitle: 'The lowest cash point before your next payday.',
          ),
          SizedBox(height: 18),
          PremiumNotice(
            icon: 'accounts',
            text: 'Add a bank or cash account, or a transaction, and this sheet will explain your projected runway.',
          ),
          SizedBox(height: 12),
        ],
      );
    }
    final shortfall = runway.isShortfall;
    final tight = !shortfall && runway.lowestBalance < runway.dailySpend * 7;
    final lowDay = math.max(
      0,
      runway.lowestDate.difference(runway.startDate).inDays,
    );
    final eventsToLow = runway.events
        .where((event) => !dateOnly(event.date).isAfter(runway.lowestDate))
        .toList();
    final incomeToLow = eventsToLow
        .where((event) => event.isIncome)
        .fold<double>(0, (sum, event) => sum + event.amount);
    final billsToLow = eventsToLow
        .where((event) => !event.isIncome)
        .fold<double>(0, (sum, event) => sum - event.amount);
    final spendToLow = math.max(
      0.0,
      runway.startingBalance + incomeToLow - billsToLow - runway.lowestBalance,
    );
    final lowDrivers = eventsToLow.where((event) => !event.isIncome).toList()
      ..sort((a, b) => a.amount.compareTo(b.amount));
    final status = shortfall
        ? 'Shortfall'
        : tight
        ? 'Tight'
        : 'Covered';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'cash',
          title: 'Cash runway',
          subtitle: 'The lowest cash point before your next payday.',
        ),
        const SizedBox(height: 18),
        PremiumSummaryCard(
          icon: shortfall ? 'debt' : 'cash',
          eyebrow: 'Lowest projected cash · $status',
          value: formatINR(runway.lowestBalance),
          caption:
              '${dayMonth(runway.lowestDate)} · ${runway.days} day window'
              '${runway.paydayInWindow ? ' · payday ${dayMonth(runway.payday!)}' : ''}',
          accent: shortfall ? c.co : c.ac,
        ),
        const SizedBox(height: 12),
        if (shortfall)
          PremiumNotice(
            icon: 'debt',
            text: _shortfallExplanation(runway, billsToLow, spendToLow),
          )
        else if (tight)
          const PremiumNotice(
            icon: 'insights',
            text: 'You stay above zero, but the lowest point is less than a week of typical spending away.',
          )
        else
          const PremiumNotice(
            icon: 'check',
            text: 'Your cash stays above zero through this window after bills and typical spending.',
          ),
        const SizedBox(height: 16),
        const SectionCaption(
          'At a glance',
          margin: EdgeInsets.only(top: 0, bottom: 8),
        ),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Starting cash · banks + cash',
                value: Text(_money(runway.startingBalance)),
              ),
              KeyValueRow(
                label: 'Typical daily spend',
                value: Text('${_money(runway.dailySpend)}/day'),
              ),
              KeyValueRow(
                label: 'Bills & commitments in window',
                value: Text(_money(runway.totalBills)),
              ),
              KeyValueRow(
                label: 'Next payday',
                value: Text(
                  runway.paydayInWindow
                      ? '${dayMonth(runway.payday!)} · ${_money(runway.expectedIncome)}'
                      : 'Not in this window',
                ),
              ),
              KeyValueRow(
                label: runway.paydayInWindow
                    ? 'Balance at payday'
                    : 'Balance at window end',
                value: Text(_money(runway.endingBalance)),
                border: false,
              ),
            ],
          ),
        ),
        const SectionCaption(
          'Why the low point',
          margin: EdgeInsets.only(top: 22, bottom: 8),
        ),
        AppCard(
          child: Column(
            children: [
              _CalcRow(
                label: 'Starting cash',
                value: _money(runway.startingBalance),
              ),
              _CalcRow(
                label: 'Income before the low',
                value: _signedMoney(incomeToLow),
                color: incomeToLow > 0 ? c.ac : null,
              ),
              _CalcRow(
                label: 'Typical spend · $lowDay day${lowDay == 1 ? '' : 's'}',
                value: _signedMoney(-spendToLow),
                color: spendToLow > 0 ? c.mu : null,
              ),
              _CalcRow(
                label: 'Bills before the low',
                value: _signedMoney(-billsToLow),
                color: billsToLow > 0 ? c.mu : null,
              ),
              _CalcRow(
                label: 'Lowest cash',
                value: formatINR(runway.lowestBalance),
                color: shortfall ? c.co : c.tx,
                strong: true,
                border: false,
              ),
            ],
          ),
        ),
        if (lowDrivers.isNotEmpty) ...[
          const SizedBox(height: 12),
          PremiumNotice(
            icon: 'calendar',
            text:
                'The main items before this low are ${_driverSummary(lowDrivers)}.',
          ),
        ],
        const SectionCaption(
          'Upcoming events',
          margin: EdgeInsets.only(top: 22, bottom: 8),
        ),
        if (runway.events.isEmpty)
          const PremiumNotice(
            icon: 'calendar',
            text: 'No bills, EMIs, subscriptions or payday events in this window.',
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < runway.events.length; i++)
                  _EventRow(
                    event: runway.events[i],
                    showDivider: i < runway.events.length - 1,
                  ),
              ],
            ),
          ),
        const SectionCaption(
          'How it works',
          margin: EdgeInsets.only(top: 22, bottom: 8),
        ),
        AppCard(
          child: Text(
            'Start with your bank and cash balances. Walk forward day by day: '
            'subtract your typical daily spend, subtract card dues, loan EMIs, '
            'subscriptions and recurring bills on their due dates, and add your '
            'expected income on payday. The lowest balance in that window is the '
            'cash runway.',
            style: AppTypography.sans(size: 13, color: c.mu, height: 1.45),
          ),
        ),
        const SizedBox(height: 10),
        const PremiumNotice(
          icon: 'insights',
          text: 'Typical daily spend is the last 90 days of outgoing transactions divided by 90. Transfers are excluded.',
        ),
        const SizedBox(height: 8),
        const PremiumNotice(
          icon: 'accounts',
          text: 'Only bank and cash accounts are counted. Investments, credit limits and future spending you have not logged are not included.',
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _shortfallExplanation(
    CashRunway runway,
    double billsToLow,
    double spendToLow,
  ) {
    final gap = runway.lowestBalance.abs();
    final parts = <String>[
      'You dip below zero by ${formatINR(gap)} on ${dayMonth(runway.lowestDate)}.',
      if (billsToLow > 0)
        '${formatINR(billsToLow)} of bills and commitments land before that point.',
      if (spendToLow > 0) '${formatINR(spendToLow)} is typical daily spending.',
      if (runway.paydayInWindow && runway.payday!.isAfter(runway.lowestDate))
        'Your payday on ${dayMonth(runway.payday!)} comes after the low point, so it does not cover this gap.'
      else if (!runway.paydayInWindow)
        'No upcoming payday was found in this window.',
    ];
    return parts.join(' ');
  }

  String _driverSummary(List<CashRunwayEvent> drivers) {
    final top = drivers.take(3).toList();
    return top
        .map((event) => '${event.label} (${formatINR(-event.amount)})')
        .join(', ');
  }

  String _money(double value) => formatINR(value);

  String _signedMoney(double value) => formatINR(value, signed: true);
}

class _CalcRow extends StatelessWidget {
  const _CalcRow({
    required this.label,
    required this.value,
    this.color,
    this.strong = false,
    this.border = true,
  });

  final String label;
  final String value;
  final Color? color;
  final bool strong;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: border ? Border(bottom: BorderSide(color: c.ln)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.sans(
                size: 13,
                color: strong ? c.tx : c.mu,
                weight: strong ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.sans(
              size: 13,
              color: color ?? c.tx,
              weight: strong ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.showDivider});

  final CashRunwayEvent event;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: c.ln)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: event.isIncome ? c.ac : c.mu,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.sans(size: 13, color: c.tx),
                ),
                Text(
                  dayMonth(event.date),
                  style: AppTypography.sans(size: 11, color: c.mu),
                ),
              ],
            ),
          ),
          Text(
            formatINR(event.amount, signed: true),
            style: AppTypography.sans(
              size: 13,
              color: event.isIncome ? c.ac : c.tx,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
