import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/transaction.dart';

Future<void> showAddTransactionSheet(
  BuildContext context, {
  String? cardId,
  String? accountId,
  String? category,
  double? amount,
}) {
  return showAppSheet<void>(
    context,
    (_) => _AddTransactionSheet(
      initialCardId: cardId,
      initialAccountId: accountId,
      initialCategory: category,
      initialAmount: amount,
    ),
  );
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet({
    this.initialCardId,
    this.initialAccountId,
    this.initialCategory,
    this.initialAmount,
  });

  final String? initialCardId;
  final String? initialAccountId;
  final String? initialCategory;
  final double? initialAmount;

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  late String _amount;
  late bool _income;
  late String _category;
  late String _source;
  late DateTime _date;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount = widget.initialAmount == null
        ? '0'
        : widget.initialAmount!.round().toString();
    _income = false;
    _category = widget.initialCategory ?? 'Food';
    _source = widget.initialCardId != null
        ? 'c:${widget.initialCardId}'
        : 'a:${widget.initialAccountId ?? 'hdfc'}';
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _key(String key) {
    Haptics.light();
    setState(() {
      if (key == '⌫') {
        _amount = _amount.length <= 1
            ? '0'
            : _amount.substring(0, _amount.length - 1);
        if (_amount.isEmpty) _amount = '0';
        return;
      }
      if (key == '.') {
        if (_amount.contains('.')) return;
        _amount = '$_amount.';
        return;
      }
      if (_amount == '0') {
        _amount = key;
      } else {
        if (_amount.contains('.') && _amount.split('.').last.length >= 2) {
          return;
        }
        _amount = '$_amount$key';
      }
    });
  }

  Future<void> _save() async {
    final value = double.tryParse(_amount) ?? 0;
    if (value <= 0) {
      ref.read(toastProvider.notifier).show('Enter an amount');
      return;
    }
    final category = _income ? 'Income' : _category;
    final merchant = _note.text.trim().isEmpty
        ? (_income ? 'Income' : _category)
        : _note.text.trim();
    final isCard = _source.startsWith('c:');
    final sourceId = _source.substring(2);
    await ref
        .read(transactionRepositoryProvider)
        .addTransaction(
          TransactionDraft(
            merchant: merchant,
            category: category,
            amount: _income ? value : -value,
            date: DateTime(_date.year, _date.month, _date.day, 12),
            accountId: isCard ? null : sourceId,
            cardId: isCard ? sourceId : null,
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Saved ${rupee(value)}');
    if (!_income && ref.read(settingsProvider).budgetAlerts) {
      final snapshot = ref.read(financeSnapshotProvider);
      final matching = snapshot.budgets
          .where((b) => b.category == category)
          .toList();
      if (matching.isNotEmpty &&
          matching.first.progress >= matching.first.alertAt / 100) {
        Future<void>.delayed(
          const Duration(milliseconds: 1800),
          () => ref
              .read(toastProvider.notifier)
              .show(
                '$category envelope at ${(matching.first.progress * 100).round()}%',
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final accounts = snapshot.accounts;
    final cards = snapshot.cards;
    final categories = const ['Food', 'Travel', 'Bills', 'Shop', 'Fun', 'EMI'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedControl<bool>(
          margin: EdgeInsets.zero,
          options: const [
            SegmentedOption(false, 'Expense'),
            SegmentedOption(true, 'Income'),
          ],
          selected: _income,
          onChanged: (value) => setState(() {
            _income = value;
            if (value) _category = 'Income';
          }),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            rupee(double.tryParse(_amount) ?? 0),
            style: AppTypography.serif(
              size: 58,
              color: c.tx,
              letterSpacing: -1,
              height: 1.05,
            ),
          ),
        ),
        if (!_income) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final category in categories) ...[
                  AppPill(
                    label: category,
                    active: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final account in accounts) ...[
                AppPill(
                  label: account.name,
                  active: _source == 'a:${account.id}',
                  onTap: () => setState(() => _source = 'a:${account.id}'),
                ),
                const SizedBox(width: 8),
              ],
              for (final card in cards) ...[
                AppPill(
                  label: '${card.firstName} card',
                  active: _source == 'c:${card.id}',
                  onTap: () => setState(() => _source = 'c:${card.id}'),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: c.c2,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _note,
                  style: AppTypography.sans(size: 13, color: c.tx),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Note',
                    hintStyle: AppTypography.sans(size: 13, color: c.mu),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: c.ac,
                          surface: c.c1,
                          onSurface: c.tx,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
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
                          style: AppTypography.sans(size: 13, color: c.tx),
                        ),
                      ),
                      SpendIcon('calendar', size: 16, color: c.mu),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['.', '0', '⌫'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _KeypadKey(label: row[i], onTap: () => _key(row[i])),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _save,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: c.ac,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: c.ac.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: -12,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'Save ${_income ? 'income' : 'expense'}',
              style: AppTypography.sans(
                size: 14,
                color: c.aci,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: c.c2,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.sans(
            size: label == '⌫' ? 16 : 18,
            color: c.tx,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
