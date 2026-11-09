import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/transaction.dart';

Future<void> showEditTransactionSheet(
  BuildContext context,
  String transactionId,
) {
  return showAppSheet<void>(
    context,
    (_) => _EditTransactionSheet(transactionId: transactionId),
  );
}

class _EditTransactionSheet extends ConsumerStatefulWidget {
  const _EditTransactionSheet({required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<_EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<_EditTransactionSheet> {
  late final Transaction _original;
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late bool _income;
  late String _category;
  late String _source;
  late DateTime _date;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    final snapshot = ref.read(financeSnapshotProvider);
    _original = snapshot.transactions.firstWhere(
      (t) => t.id == widget.transactionId,
      orElse: () => snapshot.transactions.first,
    );
    _merchant = TextEditingController(text: _original.merchant);
    _amount = TextEditingController(
      text: _original.amount.abs().round().toString(),
    );
    _note = TextEditingController(text: _original.note);
    _income = _original.isIncome;
    _category = _original.category;
    _source = _original.cardId != null
        ? 'c:${_original.cardId}'
        : _original.accountId != null
        ? 'a:${_original.accountId}'
        : '';
    _date = _original.date;
    _tags = List.of(_original.tags);
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_amount.text) ?? 0;
    if (value <= 0) {
      ref.read(toastProvider.notifier).show('Enter an amount');
      return;
    }
    final isCard = _source.startsWith('c:');
    final sourceId = _source.length > 2 ? _source.substring(2) : null;
    final updated = _original.copyWith(
      merchant: _merchant.text.trim().isEmpty
          ? _original.merchant
          : _merchant.text.trim(),
      category: _income ? 'Income' : _category,
      amount: _income ? value : -value,
      date: DateTime(_date.year, _date.month, _date.day, 12),
      accountId: isCard ? null : sourceId,
      cardId: isCard ? sourceId : null,
      note: _note.text.trim(),
      tags: _tags,
      clearAccount: isCard || sourceId == null,
      clearCard: !isCard,
    );
    await ref.read(transactionRepositoryProvider).updateTransaction(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Saved');
  }

  Future<void> _delete() async {
    await ref
        .read(transactionRepositoryProvider)
        .deleteTransaction(_original.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref
        .read(toastProvider.notifier)
        .show(
          'Deleted',
          undoLabel: 'Undo',
          onUndo: () {
            ref
                .read(transactionRepositoryProvider)
                .addTransaction(
                  TransactionDraft(
                    merchant: _original.merchant,
                    category: _original.category,
                    amount: _original.amount,
                    date: _original.date,
                    accountId: _original.accountId,
                    cardId: _original.cardId,
                    note: _original.note,
                    tags: _original.tags,
                  ),
                );
          },
          duration: const Duration(seconds: 5),
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Edit transaction'),
        const SizedBox(height: 12),
        _Field(controller: _merchant, hint: 'Merchant'),
        Row(
          children: [
            Expanded(
              child: _Field(controller: _amount, hint: 'Amount', number: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SegmentedControl<bool>(
                margin: EdgeInsets.zero,
                options: const [
                  SegmentedOption(false, 'Expense'),
                  SegmentedOption(true, 'Income'),
                ],
                selected: _income,
                onChanged: (value) => setState(() => _income = value),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AppSelect<String>(
                value: _category,
                options: [
                  for (final category in AppColors.categoryList)
                    AppSelectOption(category, category),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppSelect<String>(
                value: _source,
                hint: 'No account',
                options: [
                  const AppSelectOption('', 'No account'),
                  for (final account in snapshot.accounts)
                    AppSelectOption('a:${account.id}', account.name),
                  for (final card in snapshot.cards)
                    AppSelectOption('c:${card.id}', 'Card · ${card.name}'),
                ],
                onChanged: (value) => setState(() => _source = value ?? ''),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme
                      .copyWith(primary: c.ac, surface: c.c1, onSurface: c.tx),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: Container(
            height: 48,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shortDate(_date),
                    style: AppTypography.sans(size: 13, color: c.tx),
                  ),
                ),
                SpendIcon('calendar', size: 16, color: c.mu),
              ],
            ),
          ),
        ),
        _Field(controller: _note, hint: 'Note'),
        Text('Tags', style: AppTypography.sans(size: 12, color: c.mu)),
        const SizedBox(height: 6),
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
        const SizedBox(height: 10),
        AppCard(
          margin: EdgeInsets.zero,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tag for tax',
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
              ),
              AppToggle(
                value: _tags.isNotEmpty,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      if (_tags.isEmpty) {
                        _tags.add(snapshot.tags.first);
                      }
                    } else {
                      _tags.clear();
                    }
                  });
                },
              ),
            ],
          ),
        ),
        PrimaryButton(label: 'Save changes', onTap: _save),
        AppButton(label: 'Delete', color: c.co, centered: true, onTap: _delete),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.number = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: AppTypography.sans(size: 13, color: c.tx),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.sans(size: 13, color: c.mu),
        ),
      ),
    );
  }
}
