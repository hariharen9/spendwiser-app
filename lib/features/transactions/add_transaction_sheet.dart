import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/category_aliases.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/transaction.dart';
import '../home/services/capture_parser.dart';
import '../../data/services/notifications_service.dart';

Future<void> showAddTransactionSheet(
  BuildContext context, {
  String? cardId,
  String? accountId,
  String? category,
  double? amount,
  String? merchant,
}) {
  return showAppSheet<void>(
    context,
    (_) => _AddTransactionSheet(
      initialCardId: cardId,
      initialAccountId: accountId,
      initialCategory: category,
      initialAmount: amount,
      initialMerchant: merchant,
    ),
    scrollable: false,
  );
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet({
    this.initialCardId,
    this.initialAccountId,
    this.initialCategory,
    this.initialAmount,
    this.initialMerchant,
  });

  final String? initialCardId;
  final String? initialAccountId;
  final String? initialCategory;
  final double? initialAmount;
  final String? initialMerchant;

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late bool _income;
  late String _category;
  late String _source;
  late DateTime _date;
  late List<String> _tags;
  late bool _categoryManuallySelected;

  @override
  void initState() {
    super.initState();
    final snapshot = ref.read(financeSnapshotProvider);
    final categories = _expenseCategories();
    _income = widget.initialCategory?.toLowerCase() == 'income';
    _categoryManuallySelected = widget.initialCategory != null;
    _name = TextEditingController(text: widget.initialMerchant ?? '');
    _name.addListener(_onNameChanged);
    _amount = TextEditingController(text: _initialAmount(widget.initialAmount));
    _note = TextEditingController();
    _category = _income
        ? 'Income'
        : widget.initialCategory != null
        ? resolveCategoryName(widget.initialCategory!, categories)
        : (categories.isNotEmpty ? categories.first : 'Other');

    final defaultAccount = ref
        .read(userProfileRepositoryProvider)
        ?.defaultAccountId;
    final hasDefault =
        defaultAccount != null &&
        snapshot.accounts.any((account) => account.id == defaultAccount);
    final accountId =
        widget.initialAccountId ??
        (hasDefault
            ? defaultAccount
            : (snapshot.accounts.isNotEmpty
                  ? snapshot.accounts.first.id
                  : null));
    _source = widget.initialCardId != null && widget.initialCardId!.isNotEmpty
        ? 'c:${widget.initialCardId}'
        : accountId != null
        ? 'a:$accountId'
        : '';

    _date = DateTime.now();
    _tags = [];
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_income || _categoryManuallySelected) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final detected = CaptureParser.detectCategory(name, name.toLowerCase());
    if (detected == 'Other') return;
    final target = resolveCategoryName(detected, _expenseCategories());
    if (target != _category) {
      setState(() => _category = target);
    }
  }

  List<String> _expenseCategories() => ref
      .read(settingsProvider)
      .categories
      .keys
      .where((category) => category != 'Transfer' && category != 'Income')
      .toList();

  String _initialAmount(double? value) {
    if (value == null || value <= 0) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(2);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final value = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    if (name.isEmpty) {
      ref.read(toastProvider.notifier).show('Name the transaction');
      return;
    }
    if (value <= 0) {
      ref.read(toastProvider.notifier).show('Enter an amount');
      return;
    }

    final snapshot = ref.read(financeSnapshotProvider);
    final hasSources =
        snapshot.accounts.isNotEmpty || snapshot.cards.isNotEmpty;
    if (hasSources && _source.isEmpty) {
      ref.read(toastProvider.notifier).show('Choose an account');
      return;
    }

    final categories = _expenseCategories();
    final category = _income
        ? 'Income'
        : (categories.contains(_category)
              ? _category
              : (categories.isNotEmpty ? categories.first : 'Other'));
    final isCard = _source.startsWith('c:');
    final sourceId = _source.length > 2 ? _source.substring(2) : null;

    await ref
        .read(transactionRepositoryProvider)
        .addTransaction(
          TransactionDraft(
            merchant: name,
            category: category,
            amount: _income ? value : -value,
            date: DateTime(_date.year, _date.month, _date.day, 12),
            addedAt: DateTime.now(),
            accountId: isCard ? null : sourceId,
            cardId: isCard ? sourceId : null,
            note: _note.text.trim(),
            tags: List.unmodifiable(_tags),
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Saved ${rupee(value)}');
    if (!_income && ref.read(settingsProvider).budgetAlerts) {
      final current = ref.read(financeSnapshotProvider);
      final matching = current.budgets
          .where((budget) => budget.category == category)
          .toList();
      if (matching.isNotEmpty &&
          matching.first.progress >= matching.first.alertAt / 100) {
        final progress = matching.first.progress;
        final alertAt = matching.first.alertAt;
        Future<void>.delayed(const Duration(milliseconds: 1800), () async {
          ref
              .read(toastProvider.notifier)
              .show('$category envelope at ${(progress * 100).round()}%');
          await NotificationsService.budgetAlert(category, progress, alertAt);
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        final c = context.spend;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme
                .copyWith(primary: c.ac, surface: c.c1, onSurface: c.tx),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final categories = _expenseCategories();
    final effectiveCategory = _income
        ? 'Income'
        : (categories.contains(_category)
              ? _category
              : (categories.isNotEmpty ? categories.first : 'Other'));
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final sources = <AppSelectOption<String>>[
      for (final account in snapshot.accounts)
        AppSelectOption(
          'a:${account.id}',
          '${account.name} (${rupee(account.balance)})',
        ),
      for (final card in snapshot.cards)
        AppSelectOption(
          'c:${card.id}',
          '${card.name} (${rupee(card.outstanding)} due)',
        ),
      if (snapshot.accounts.isEmpty && snapshot.cards.isEmpty)
        const AppSelectOption('', 'No account'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: SheetTitle(
                        'Add transaction',
                        subtitle: 'Track money in or out.',
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.c2,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: SpendIcon('closeSmall', size: 18, color: c.tx),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _label(context, 'Transaction name *'),
                _Input(
                  controller: _name,
                  hint: 'e.g. Coffee Shop, Salary, Gas Station',
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                _label(context, 'Amount *'),
                _Input(
                  controller: _amount,
                  hint: '0.00',
                  number: true,
                  large: true,
                  prefix: '₹ ',
                ),
                const SizedBox(height: 12),
                _label(context, 'Type *'),
                SegmentedControl<bool>(
                  margin: EdgeInsets.zero,
                  options: const [
                    SegmentedOption(false, 'Expense'),
                    SegmentedOption(true, 'Income'),
                  ],
                  selected: _income,
                  onChanged: (value) => setState(() {
                    _income = value;
                    if (value) {
                      _category = 'Income';
                    } else if (!categories.contains(_category)) {
                      _category = categories.isNotEmpty
                          ? categories.first
                          : 'Other';
                    }
                  }),
                ),
                const SizedBox(height: 12),
                _label(context, 'Date *'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPill(
                      label: 'Today',
                      active: _sameDay(_date, today),
                      onTap: () => setState(() => _date = today),
                    ),
                    AppPill(
                      label: 'Yesterday',
                      active: _sameDay(_date, yesterday),
                      onTap: () => setState(() => _date = yesterday),
                    ),
                    AppPill(
                      label: 'Last week',
                      active: _sameDay(_date, lastWeek),
                      onTap: () => setState(() => _date = lastWeek),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
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
                          child: Text(
                            isoDate(_date),
                            style: AppTypography.sans(size: 14, color: c.tx),
                          ),
                        ),
                        SpendIcon('calendar', size: 16, color: c.mu),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _label(context, 'Category *'),
                if (_income)
                  const _ReadOnlyField(value: 'Income')
                else
                  AppSelect<String>(
                    value: effectiveCategory,
                    options: [
                      for (final category in categories)
                        AppSelectOption(category, category),
                    ],
                    onChanged: (value) => setState(() {
                      _categoryManuallySelected = true;
                      _category = value ?? _category;
                    }),
                  ),
                if (snapshot.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _label(context, 'Tags'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in snapshot.tags)
                        AppPill(
                          label: '#$tag',
                          active: _tags.contains(tag),
                          onTap: () {
                            setState(() {
                              if (_tags.contains(tag)) {
                                _tags.remove(tag);
                              } else {
                                _tags.add(tag);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _label(context, 'Account *'),
                AppSelect<String>(
                  value: _source,
                  hint: 'Choose account',
                  options: sources,
                  onChanged: (value) => setState(() => _source = value ?? ''),
                ),
                const SizedBox(height: 12),
                _label(context, 'Comments (optional)'),
                _Input(
                  controller: _note,
                  hint: 'Add any additional notes…',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.ln)),
          ),
          child: PrimaryButton(
            label: _income ? 'Save income' : 'Save expense',
            onTap: _save,
            margin: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.sans(size: 12, color: context.spend.mu),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.number = false,
    this.maxLines = 1,
    this.prefix,
    this.large = false,
    this.capitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final int maxLines;
  final String? prefix;
  final bool large;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: large ? 10 : 13),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: number
            ? [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(12),
              ]
            : null,
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : 1,
        textCapitalization: capitalization,
        style: large
            ? AppTypography.serif(
                size: 32,
                color: c.tx,
                letterSpacing: -0.8,
                height: 1.1,
              )
            : AppTypography.sans(size: 14, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.sans(size: 14, color: c.mu),
          prefixText: prefix,
          prefixStyle: AppTypography.serif(size: 26, color: c.mu),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});

  final String value;

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
      child: Text(value, style: AppTypography.sans(size: 14, color: c.tx)),
    );
  }
}
