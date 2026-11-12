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
import '../../core/widgets/app_select.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/month_navigator.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/transaction.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/edit_transaction_sheet.dart';
import 'widgets/ledger_view_switch.dart';

enum _LedgerView { list, calendar }

const _sortOptions = <AppSelectOption<String>>[
  AppSelectOption('new', 'Newest first'),
  AppSelectOption('old', 'Oldest first'),
  AppSelectOption('largest', 'Largest amount'),
  AppSelectOption('smallest', 'Smallest amount'),
  AppSelectOption('az', 'Merchant A–Z'),
  AppSelectOption('za', 'Merchant Z–A'),
  AppSelectOption('category', 'Category'),
];

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  final _search = TextEditingController();
  int _monthOffset = 0;
  _LedgerView _view = _LedgerView.list;
  String _type = 'all';
  String? _category;
  String? _accountId;
  DateTime? _from;
  DateTime? _to;
  double? _min;
  double? _max;
  Set<String> _tags = {};
  bool _cardsOnly = false;
  bool _hasComments = false;
  String _sort = 'new';
  String _quick = 'month';
  String _query = '';
  int _day = 0;

  DateTime get _month =>
      DateTime(DateTime.now().year, DateTime.now().month - _monthOffset, 1);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, daysInMonth(now.year, now.month));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final month = _month;
    final monthFlow = snapshot.flow(month);
    final filtered = _filtered(snapshot);
    final isCalendar = _view == _LedgerView.calendar;
    final income = isCalendar
        ? monthFlow.income
        : filtered
              .where((t) => t.amount > 0 && t.category != 'Transfer')
              .fold<double>(0, (sum, t) => sum + t.amount);
    final expense = isCalendar
        ? monthFlow.expense
        : filtered
              .where((t) => t.amount < 0 && t.category != 'Transfer')
              .fold<double>(0, (sum, t) => sum - t.amount);

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Ledger',
          subtitle: isCalendar
              ? '${snapshot.transactions.length} entries · on this device'
              : '${filtered.length} shown · ${snapshot.transactions.length} total',
          trailing: LedgerViewSwitch(
            calendar: isCalendar,
            onChanged: (calendar) => setState(() {
              _view = calendar ? _LedgerView.calendar : _LedgerView.list;
              _day = 0;
            }),
          ),
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
                    AnimatedAmount(
                      value: income,
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
                    AnimatedAmount(
                      value: expense,
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
        const SizedBox(height: 10),
        if (isCalendar) ...[
          MonthNavigator(
            month: month,
            onPrevious: () => setState(() => _monthOffset++),
            onNext: _monthOffset == 0
                ? null
                : () => setState(() => _monthOffset--),
            canGoNext: _monthOffset > 0,
          ),
          const SizedBox(height: 10),
          _CalendarView(
            snapshot: snapshot,
            month: month,
            selectedDay: _day,
            onSelect: (day) => setState(() => _day = day),
          ),
        ] else ...[
          _searchBar(context, snapshot),
          const SizedBox(height: 10),
          _quickChips(context),
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 8),
            _activeFilters(context, snapshot),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${filtered.length} transaction${filtered.length == 1 ? '' : 's'}',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              const Spacer(),
              SizedBox(
                width: 170,
                child: AppSelect<String>(
                  value: _sort,
                  options: _sortOptions,
                  onChanged: (value) => setState(() => _sort = value ?? 'new'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            EmptyState(
              title: 'No transactions match',
              message: 'Try a wider range or clear a filter.',
              actionLabel: _activeFilterCount > 0
                  ? 'Clear filters'
                  : 'Add transaction',
              onAction: _activeFilterCount > 0
                  ? _clearFilters
                  : () => showAddTransactionSheet(context),
            )
          else if (_sort == 'new' || _sort == 'old')
            ..._grouped(context, filtered)
          else
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
            ),
        ],
      ],
    );
  }

  Widget _searchBar(BuildContext context, FinanceSnapshot snapshot) {
    final c = context.spend;
    return Container(
      height: 48,
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
              controller: _search,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.sans(size: 14, color: c.tx),
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Search merchants, notes, tags…',
                hintStyle: AppTypography.sans(size: 14, color: c.mu),
              ),
            ),
          ),
          _LedgerToolIcon(
            icon: 'filter',
            onTap: () => _showFilters(context),
            badge: _activeFilterCount,
          ),
          const SizedBox(width: 6),
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
    );
  }

  Widget _quickChips(BuildContext context) {
    const ranges = [
      ('today', 'Today'),
      ('yesterday', 'Yesterday'),
      ('week', 'Week'),
      ('month', 'Month'),
    ];
    return BleedRow(
      height: 34,
      children: [
        for (final range in ranges)
          AppPill(
            label: range.$2,
            active: _quick == range.$1,
            onTap: () => _applyQuick(range.$1),
          ),
        AppPill(
          label: 'More',
          active: _quick == 'custom' || _quick == 'all',
          onTap: () => _showFilters(context),
        ),
      ],
    );
  }

  Widget _activeFilters(BuildContext context, FinanceSnapshot snapshot) {
    final c = context.spend;
    String? accountName;
    if (_accountId != null) {
      for (final account in snapshot.accounts) {
        if (account.id == _accountId) {
          accountName = account.name;
          break;
        }
      }
    }
    final chips = <Widget>[
      if (_type != 'all')
        AppPill(label: _typeLabel(_type), onTap: () => _showFilters(context)),
      if (_category != null)
        AppPill(label: _category!, onTap: () => _showFilters(context)),
      if (accountName != null)
        AppPill(label: accountName, onTap: () => _showFilters(context)),
      if (_quick == 'custom' && (_from != null || _to != null))
        AppPill(
          label:
              '${_from == null ? 'Any' : shortDate(_from!)} – ${_to == null ? 'Any' : shortDate(_to!)}',
          onTap: () => _showFilters(context),
        ),
      if (_quick == 'all')
        AppPill(label: 'All time', onTap: () => _showFilters(context)),
      if (_min != null || _max != null)
        AppPill(label: _amountLabel, onTap: () => _showFilters(context)),
      for (final tag in _tags)
        AppPill(label: '#$tag', onTap: () => _showFilters(context)),
      if (_cardsOnly)
        AppPill(label: 'Cards only', onTap: () => _showFilters(context)),
      if (_hasComments)
        AppPill(label: 'Has comments', onTap: () => _showFilters(context)),
      AppPill(
        label: 'Clear all',
        textColor: c.co,
        borderColor: c.co.withValues(alpha: 0.4),
        onTap: _clearFilters,
      ),
    ];
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  String get _amountLabel {
    if (_min != null && _max != null) {
      return '${rupee(_min!)} – ${rupee(_max!)}';
    }
    if (_min != null) return '≥ ${rupee(_min!)}';
    return '≤ ${rupee(_max!)}';
  }

  String _typeLabel(String type) => switch (type) {
    'out' => 'Expenses',
    'in' => 'Income',
    'transfer' => 'Transfers',
    _ => 'All types',
  };

  int get _activeFilterCount {
    var count = 0;
    if (_type != 'all') count++;
    if (_category != null) count++;
    if (_accountId != null) count++;
    if (_quick != 'month') count++;
    if (_min != null || _max != null) count++;
    if (_tags.isNotEmpty) count++;
    if (_cardsOnly) count++;
    if (_hasComments) count++;
    return count;
  }

  void _applyQuick(String quick) {
    if (quick == 'more') {
      _showFilters(context);
      return;
    }
    final now = DateTime.now();
    final today = dateOnly(now);
    DateTime? from;
    DateTime? to;
    switch (quick) {
      case 'today':
        from = today;
        to = today;
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        from = yesterday;
        to = yesterday;
      case 'week':
        from = today.subtract(const Duration(days: 6));
        to = today;
      case 'month':
      default:
        from = DateTime(today.year, today.month, 1);
        to = DateTime(
          today.year,
          today.month,
          daysInMonth(today.year, today.month),
        );
    }
    setState(() {
      _quick = quick;
      _from = from;
      _to = to;
      _monthOffset = 0;
    });
  }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _type = 'all';
      _category = null;
      _accountId = null;
      _min = null;
      _max = null;
      _tags = {};
      _cardsOnly = false;
      _hasComments = false;
      _sort = 'new';
      _quick = 'month';
      _from = DateTime(now.year, now.month, 1);
      _to = DateTime(now.year, now.month, daysInMonth(now.year, now.month));
      _query = '';
      _search.clear();
    });
  }

  Future<void> _showFilters(BuildContext context) async {
    final snapshot = ref.read(financeSnapshotProvider);
    final settings = ref.read(settingsProvider);
    final categories = settings.categories.keys.toList();
    final minController = TextEditingController(
      text: _min == null ? '' : _min!.round().toString(),
    );
    final maxController = TextEditingController(
      text: _max == null ? '' : _max!.round().toString(),
    );

    var type = _type;
    String? category = _category;
    String? accountId = _accountId;
    var from = _from;
    var to = _to;
    var tags = Set<String>.of(_tags);
    var cardsOnly = _cardsOnly;
    var hasComments = _hasComments;
    var sort = _sort;
    var quick = _quick;

    await showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final c = context.spend;

          void pickDate({required bool isFrom}) async {
            final picked = await showDatePicker(
              context: sheetContext,
              initialDate: (isFrom ? from : to) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme
                      .copyWith(primary: c.ac, surface: c.c1, onSurface: c.tx),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
            if (picked == null) return;
            setSheetState(() {
              if (isFrom) {
                from = picked;
              } else {
                to = picked;
              }
              quick = 'custom';
            });
          }

          void quickRange(String value) {
            final now = DateTime.now();
            final today = dateOnly(now);
            DateTime? nextFrom;
            DateTime? nextTo;
            switch (value) {
              case 'today':
                nextFrom = today;
                nextTo = today;
              case 'yesterday':
                final yesterday = today.subtract(const Duration(days: 1));
                nextFrom = yesterday;
                nextTo = yesterday;
              case 'week':
                nextFrom = today.subtract(const Duration(days: 6));
                nextTo = today;
              case 'month':
                nextFrom = DateTime(today.year, today.month, 1);
                nextTo = DateTime(
                  today.year,
                  today.month,
                  daysInMonth(today.year, today.month),
                );
              case 'all':
                nextFrom = null;
                nextTo = null;
            }
            setSheetState(() {
              quick = value;
              from = nextFrom;
              to = nextTo;
            });
          }

          void reset() {
            final now = DateTime.now();
            setSheetState(() {
              type = 'all';
              category = null;
              accountId = null;
              minController.clear();
              maxController.clear();
              tags = {};
              cardsOnly = false;
              hasComments = false;
              sort = 'new';
              quick = 'month';
              from = DateTime(now.year, now.month, 1);
              to = DateTime(
                now.year,
                now.month,
                daysInMonth(now.year, now.month),
              );
            });
          }

          void apply() {
            var minValue = double.tryParse(
              minController.text.replaceAll(',', ''),
            );
            var maxValue = double.tryParse(
              maxController.text.replaceAll(',', ''),
            );
            if (minValue != null && maxValue != null && minValue > maxValue) {
              final temp = minValue;
              minValue = maxValue;
              maxValue = temp;
            }
            if (from != null && to != null && from!.isAfter(to!)) {
              final temp = from;
              from = to;
              to = temp;
            }
            setState(() {
              _type = type;
              _category = category;
              _accountId = accountId;
              _from = from;
              _to = to;
              _min = minValue;
              _max = maxValue;
              _tags = Set.of(tags);
              _cardsOnly = cardsOnly;
              _hasComments = hasComments;
              _sort = sort;
              _quick = quick;
              _monthOffset = 0;
            });
            Navigator.of(sheetContext).pop();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SheetTitle(
                      'Filters',
                      subtitle: 'Narrow down the ledger.',
                    ),
                  ),
                  AppPill(label: 'Reset', onTap: reset),
                ],
              ),
              const SizedBox(height: 12),
              const _FilterLabel('Type'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    ('all', 'All types'),
                    ('out', 'Expenses'),
                    ('in', 'Income'),
                    ('transfer', 'Transfers'),
                  ])
                    AppPill(
                      label: option.$2,
                      active: type == option.$1,
                      onTap: () => setSheetState(() => type = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const _FilterLabel('Category'),
              AppSelect<String>(
                value: category ?? '',
                options: [
                  const AppSelectOption('', 'All categories'),
                  for (final item in categories) AppSelectOption(item, item),
                ],
                onChanged: (value) => setSheetState(
                  () =>
                      category = value == null || value.isEmpty ? null : value,
                ),
              ),
              const SizedBox(height: 14),
              const _FilterLabel('Account'),
              AppSelect<String>(
                value: accountId ?? '',
                options: [
                  const AppSelectOption('', 'All accounts'),
                  for (final account in snapshot.accounts)
                    AppSelectOption(account.id, account.name),
                ],
                onChanged: (value) => setSheetState(
                  () =>
                      accountId = value == null || value.isEmpty ? null : value,
                ),
              ),
              const SizedBox(height: 14),
              const _FilterLabel('Date range'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    ('today', 'Today'),
                    ('yesterday', 'Yesterday'),
                    ('week', 'This week'),
                    ('month', 'This month'),
                    ('all', 'All time'),
                  ])
                    AppPill(
                      label: option.$2,
                      active: quick == option.$1,
                      onTap: () => quickRange(option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateFilterField(
                      label: 'From',
                      date: from,
                      onTap: () => pickDate(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateFilterField(
                      label: 'To',
                      date: to,
                      onTap: () => pickDate(isFrom: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _FilterLabel('Amount range'),
              Row(
                children: [
                  Expanded(
                    child: _FilterInput(
                      controller: minController,
                      hint: 'Min',
                      number: true,
                      prefix: '₹ ',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterInput(
                      controller: maxController,
                      hint: 'Max',
                      number: true,
                      prefix: '₹ ',
                    ),
                  ),
                ],
              ),
              if (snapshot.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                const _FilterLabel('Tags'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in snapshot.tags)
                      AppPill(
                        label: '#$tag',
                        active: tags.contains(tag),
                        onTap: () => setSheetState(() {
                          if (tags.contains(tag)) {
                            tags.remove(tag);
                          } else {
                            tags.add(tag);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const _FilterLabel('Options'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _FilterToggle(
                      label: 'Cards only',
                      value: cardsOnly,
                      onChanged: (value) =>
                          setSheetState(() => cardsOnly = value),
                    ),
                    _FilterToggle(
                      label: 'Has comments',
                      value: hasComments,
                      onChanged: (value) =>
                          setSheetState(() => hasComments = value),
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _FilterLabel('Sort by'),
              AppSelect<String>(
                value: sort,
                options: _sortOptions,
                onChanged: (value) =>
                    setSheetState(() => sort = value ?? 'new'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Reset',
                      centered: true,
                      margin: EdgeInsets.zero,
                      onTap: reset,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Apply filters',
                      margin: EdgeInsets.zero,
                      onTap: apply,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    minController.dispose();
    maxController.dispose();
  }

  List<Transaction> _filtered(FinanceSnapshot snapshot) {
    final from = _from == null ? null : dateOnly(_from!);
    final to = _to == null ? null : dateOnly(_to!);
    final query = _query.toLowerCase().trim();

    final list = snapshot.transactions.where((t) {
      final day = dateOnly(t.date);
      if (from != null && day.isBefore(from)) return false;
      if (to != null && day.isAfter(to)) return false;
      switch (_type) {
        case 'out':
          if (t.amount >= 0 || t.category == 'Transfer') return false;
        case 'in':
          if (t.amount <= 0 || t.category == 'Transfer') return false;
        case 'transfer':
          if (t.category != 'Transfer') return false;
      }
      if (_category != null && t.category != _category) return false;
      if (_accountId != null && t.accountId != _accountId) return false;
      if (_min != null && t.amount.abs() < _min!) return false;
      if (_max != null && t.amount.abs() > _max!) return false;
      for (final tag in _tags) {
        if (!t.tags.contains(tag)) return false;
      }
      if (_cardsOnly && t.cardId == null) return false;
      if (_hasComments && t.note.trim().isEmpty) return false;
      if (query.isNotEmpty &&
          !'${t.merchant} ${t.category} ${t.note} ${t.tags.join(' ')}'
              .toLowerCase()
              .contains(query)) {
        return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case 'old':
        list.sort(compareTransactionsOldestFirst);
      case 'largest':
        list.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
      case 'smallest':
        list.sort((a, b) => a.amount.abs().compareTo(b.amount.abs()));
      case 'az':
        list.sort(
          (a, b) =>
              a.merchant.toLowerCase().compareTo(b.merchant.toLowerCase()),
        );
      case 'za':
        list.sort(
          (a, b) =>
              b.merchant.toLowerCase().compareTo(a.merchant.toLowerCase()),
        );
      case 'category':
        list.sort((a, b) {
          final category = a.category.compareTo(b.category);
          return category != 0
              ? category
              : compareTransactionsNewestFirst(a, b);
        });
      default:
        list.sort(compareTransactionsNewestFirst);
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

class _LedgerToolIcon extends StatelessWidget {
  const _LedgerToolIcon({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final String icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: SpendIcon(icon, size: 17, color: c.tx),
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: c.ac,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.c1, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badge',
                  style: AppTypography.sans(
                    size: 8,
                    color: c.aci,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption(context.spend.mu),
      ),
    );
  }
}

class _FilterInput extends StatelessWidget {
  const _FilterInput({
    required this.controller,
    required this.hint,
    this.number = false,
    this.prefix,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlignVertical: TextAlignVertical.center,
        style: AppTypography.sans(size: 14, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.sans(size: 13, color: c.mu),
          prefixText: prefix,
          prefixStyle: AppTypography.sans(size: 13, color: c.mu),
        ),
      ),
    );
  }
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: c.c2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.sans(size: 9, color: c.mu)),
                  Text(
                    date == null ? 'Any' : shortDate(date!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(size: 13, color: c.tx),
                  ),
                ],
              ),
            ),
            SpendIcon('calendar', size: 16, color: c.mu),
          ],
        ),
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.ln)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.sans(size: 14, color: c.tx),
            ),
          ),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
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
