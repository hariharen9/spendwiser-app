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
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/month_navigator.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/transaction.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/edit_transaction_sheet.dart';

enum _LedgerView { list, calendar }

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  int _monthOffset = 0;
  _LedgerView _view = _LedgerView.list;
  String _filter = 'all';
  String _tag = '';
  String? _accountId;
  String _sort = 'new';
  String _query = '';
  int _day = 0;

  DateTime get _month =>
      DateTime(DateTime.now().year, DateTime.now().month - _monthOffset, 1);

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final month = _month;
    final flow = snapshot.flow(month);

    final filtered = _filtered(snapshot, month);

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Ledger',
          subtitle: '${snapshot.transactions.length} entries · on this device',
        ),
        MonthNavigator(
          month: month,
          onPrevious: () => setState(() => _monthOffset++),
          onNext: _monthOffset == 0
              ? null
              : () => setState(() => _monthOffset--),
          canGoNext: _monthOffset > 0,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                    MoneyText(
                      rupee(flow.income),
                      style: AppTypography.serif(
                        size: 26,
                        color: c.ac,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Out',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                    MoneyText(
                      rupee(flow.expense),
                      style: AppTypography.serif(
                        size: 26,
                        color: c.tx,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SegmentedControl<_LedgerView>(
          options: const [
            SegmentedOption(_LedgerView.list, 'List'),
            SegmentedOption(_LedgerView.calendar, 'Calendar'),
          ],
          selected: _view,
          onChanged: (value) => setState(() {
            _view = value;
            _day = 0;
          }),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: c.c1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.ln),
            gradient: c.dark ? c.cardGradient : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: AppTypography.sans(size: 14, color: c.tx),
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search merchants, notes…',
                    hintStyle: AppTypography.sans(size: 14, color: c.mu),
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => showAddTransactionSheet(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.ac,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: SpendIcon('plus', size: 18, color: c.aci),
                ),
              ),
            ],
          ),
        ),
        if (_view == _LedgerView.calendar)
          _CalendarView(
            snapshot: snapshot,
            month: month,
            selectedDay: _day,
            onSelect: (day) => setState(() => _day = day),
          )
        else ...[
          BleedRow(
            height: 34,
            children: [
              for (final filter in const [
                ('all', 'All'),
                ('out', 'Expenses'),
                ('in', 'Income'),
                ('tag', 'Tagged'),
              ])
                AppPill(
                  label: filter.$2,
                  active: _filter == filter.$1,
                  onTap: () => setState(() => _filter = filter.$1),
                ),
              for (final tag in snapshot.tags)
                AppPill(
                  label: '#$tag',
                  active: _tag == tag,
                  onTap: () => setState(() {
                    _tag = _tag == tag ? '' : tag;
                    if (_tag.isNotEmpty) _filter = 'all';
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppSelect<String>(
                  value: _accountId,
                  hint: 'All accounts',
                  options: [
                    const AppSelectOption('', 'All accounts'),
                    for (final account in snapshot.accounts)
                      AppSelectOption(account.id, account.name),
                  ],
                  onChanged: (value) =>
                      setState(() => _accountId = value == '' ? null : value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppSelect<String>(
                  value: _sort,
                  options: const [
                    AppSelectOption('new', 'Newest'),
                    AppSelectOption('old', 'Oldest'),
                    AppSelectOption('hi', 'Largest'),
                  ],
                  onChanged: (value) => setState(() => _sort = value ?? 'new'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            EmptyState(
              title: 'No transactions here',
              message: 'Try another filter or add one.',
              actionLabel: 'Add transaction',
              onAction: () => showAddTransactionSheet(context),
            )
          else if (_sort == 'hi')
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < filtered.length; i++)
                    TransactionRow(
                      transaction: filtered[i],
                      showDivider: i < filtered.length - 1,
                      onTap: () =>
                          showEditTransactionSheet(context, filtered[i].id),
                    ),
                ],
              ),
            )
          else
            ..._grouped(context, filtered),
        ],
      ],
    );
  }

  List<Transaction> _filtered(FinanceSnapshot snapshot, DateTime month) {
    final list = snapshot.transactions.where((t) {
      if (!isSameMonth(t.date, month)) return false;
      if (_filter == 'out' && !(t.amount < 0 && t.category != 'Transfer')) {
        return false;
      }
      if (_filter == 'in' && !(t.amount > 0 && t.category != 'Transfer')) {
        return false;
      }
      if (_filter == 'tag' && t.tags.isEmpty) return false;
      if (_tag.isNotEmpty && !t.tags.contains(_tag)) return false;
      if (_accountId != null && t.accountId != _accountId) return false;
      if (_query.isNotEmpty &&
          !'${t.merchant}${t.category}${t.note}'.toLowerCase().contains(
            _query.toLowerCase(),
          )) {
        return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case 'old':
        list.sort((a, b) => a.date.compareTo(b.date));
      case 'hi':
        list.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
      default:
        list.sort((a, b) => b.date.compareTo(a.date));
    }
    return list;
  }

  List<Widget> _grouped(BuildContext context, List<Transaction> items) {
    final c = context.spend;
    final groups = <String, List<Transaction>>{};
    for (final item in items) {
      groups.putIfAbsent(item.dateLabel, () => []).add(item);
    }
    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      final sum = entry.value
          .where((t) => t.category != 'Transfer')
          .fold<double>(0, (sum, t) => sum + t.amount);
      widgets.add(
        SectionCaption(
          entry.key,
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          trailing: MoneyText(
            '${sum < 0 ? '−' : '+'}${rupee(sum)}',
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
        ),
      );
      widgets.add(
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < entry.value.length; i++)
                TransactionRow(
                  transaction: entry.value[i],
                  showDivider: i < entry.value.length - 1,
                  onTap: () =>
                      showEditTransactionSheet(context, entry.value[i].id),
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.snapshot,
    required this.month,
    required this.selectedDay,
    required this.onSelect,
  });

  final FinanceSnapshot snapshot;
  final DateTime month;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final days = daysInMonth(month.year, month.month);
    final offset = DateTime(month.year, month.month, 1).weekday % 7;
    final spend = <int, double>{};
    for (final t in snapshot.inMonth(month)) {
      if (t.amount < 0 && t.category != 'Transfer') {
        spend[t.date.day] = (spend[t.date.day] ?? 0) - t.amount;
      }
    }
    final maxSpend = spend.values.isEmpty
        ? 1.0
        : spend.values.reduce((a, b) => a > b ? a : b);
    final selected = selectedDay == 0
        ? <Transaction>[]
        : snapshot.transactions
              .where(
                (t) => isSameMonth(t.date, month) && t.date.day == selectedDay,
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
                children: [
                  for (final day in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                    Center(
                      child: Text(
                        day,
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ),
                  for (var i = 0; i < offset; i++) const SizedBox.shrink(),
                  for (var day = 1; day <= days; day++)
                    GestureDetector(
                      onTap: () => onSelect(selectedDay == day ? 0 : day),
                      child: Container(
                        decoration: BoxDecoration(
                          color: (spend[day] ?? 0) > 0
                              ? c.co.withValues(
                                  alpha:
                                      0.18 +
                                      ((spend[day] ?? 0) / maxSpend) * 0.6,
                                )
                              : c.c2,
                          borderRadius: BorderRadius.circular(11),
                          border: selectedDay == day
                              ? Border.all(color: c.tx, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: AppTypography.sans(size: 12, color: c.tx),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Darker means heavier spend · tap a day',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ),
            ],
          ),
        ),
        if (selectedDay > 0) ...[
          SectionCaption('$selectedDay ${monthShort[month.month - 1]}'),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < selected.length; i++)
                  TransactionRow(
                    transaction: selected[i],
                    showDivider: i < selected.length - 1,
                    onTap: () =>
                        showEditTransactionSheet(context, selected[i].id),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
