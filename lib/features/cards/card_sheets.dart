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
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/segmented_control.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/models/transaction.dart';
import '../../data/services/finance_calculator.dart';

Future<void> showPayCardSheet(
  BuildContext context,
  String cardId, {
  double? initialAmount,
}) {
  return showAppSheet<void>(
    context,
    (_) => _PayCardSheet(cardId: cardId, initialAmount: initialAmount),
  );
}

class _PayCardSheet extends ConsumerStatefulWidget {
  const _PayCardSheet({required this.cardId, this.initialAmount});

  final String cardId;
  final double? initialAmount;

  @override
  ConsumerState<_PayCardSheet> createState() => _PayCardSheetState();
}

class _PayCardSheetState extends ConsumerState<_PayCardSheet> {
  double _amount = 0;
  String? _accountId;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    final snapshot = ref.read(financeSnapshotProvider);
    final card = snapshot.cardById(widget.cardId);
    _amount =
        widget.initialAmount ?? card?.due?.amount ?? card?.outstanding ?? 0;
    _accountId = snapshot.accounts.isEmpty ? null : snapshot.accounts.first.id;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final snapshot = ref.read(financeSnapshotProvider);
    final card = snapshot.cardById(widget.cardId);
    if (card == null || _amount <= 0) {
      ref.read(toastProvider.notifier).show('Enter an amount');
      return;
    }
    await ref
        .read(cardRepositoryProvider)
        .payCardBill(
          cardId: card.id,
          amount: _amount,
          accountId: _accountId ?? snapshot.accounts.first.id,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Paid ${rupee(_amount)}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final card = snapshot.cardById(widget.cardId);
    if (card == null) return const SizedBox.shrink();
    final due = card.due;
    final statementAmount = due?.amount ?? card.outstanding;
    final options = [
      ('Statement', statementAmount),
      ('Minimum', card.minimumDue),
      ('All', card.outstanding),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pay ${card.name}',
          style: AppTypography.sans(size: 14, color: c.mu),
        ),
        Text(
          rupee(_amount),
          style: AppTypography.serif(size: 50, color: c.tx, height: 1.1),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              if (option.$2 > 0)
                AppPill(
                  label: '${option.$1} ${rupee(option.$2)}',
                  onTap: () {
                    setState(() {
                      _amount = option.$2;
                      _input.clear();
                    });
                  },
                ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: c.c2,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _input,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.sans(size: 14, color: c.tx),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) setState(() => _amount = parsed);
            },
            decoration: InputDecoration(
              hintText: 'Or enter an amount',
              hintStyle: AppTypography.sans(size: 13, color: c.mu),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AppSelect<String>(
          value: _accountId,
          options: [
            for (final account in snapshot.accounts)
              AppSelectOption(
                account.id,
                '${account.name} · ${rupee(account.balance)}',
              ),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        ),
        PrimaryButton(label: 'Pay now', onTap: _pay),
      ],
    );
  }
}

Future<void> showEmiSheet(BuildContext context, String cardId) {
  return showAppSheet<void>(context, (_) => _EmiSheet(cardId: cardId));
}

class _EmiSheet extends ConsumerStatefulWidget {
  const _EmiSheet({required this.cardId});

  final String cardId;

  @override
  ConsumerState<_EmiSheet> createState() => _EmiSheetState();
}

class _EmiSheetState extends ConsumerState<_EmiSheet> {
  int _months = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final card = snapshot.cardById(widget.cardId);
    if (card == null) return const SizedBox.shrink();
    final amount = card.outstanding;
    final emi = FinanceCalculator.emiFor(amount, 13, _months).roundToDouble();
    final interest = emi * _months - amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Convert ${rupee(amount)} to EMI',
          style: AppTypography.sans(size: 14, color: c.mu),
        ),
        SegmentedControl<int>(
          options: const [
            SegmentedOption(3, '3 months'),
            SegmentedOption(6, '6 months'),
            SegmentedOption(12, '12 months'),
          ],
          selected: _months,
          onChanged: (value) => setState(() => _months = value),
        ),
        Text(
          rupee(emi),
          style: AppTypography.serif(size: 50, color: c.tx, height: 1.1),
        ),
        Text(' /mo', style: AppTypography.sans(size: 12, color: c.mu)),
        Text(
          '13% p.a. · total interest ${rupee(interest)}',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        AppButton(
          label: 'Confirm plan',
          centered: true,
          margin: const EdgeInsets.only(top: 16),
          onTap: () {
            Navigator.of(context).pop();
            ref.read(toastProvider.notifier).show('EMI plan created');
          },
        ),
      ],
    );
  }
}

Future<void> showManageCardSheet(BuildContext context, String cardId) {
  return showAppSheet<void>(context, (_) => _ManageCardSheet(cardId: cardId));
}

class _ManageCardSheet extends ConsumerStatefulWidget {
  const _ManageCardSheet({required this.cardId});

  final String cardId;

  @override
  ConsumerState<_ManageCardSheet> createState() => _ManageCardSheetState();
}

class _ManageCardSheetState extends ConsumerState<_ManageCardSheet> {
  late final TextEditingController _name;
  late final TextEditingController _limit;
  late final TextEditingController _statementDay;
  late final TextEditingController _dueDay;

  @override
  void initState() {
    super.initState();
    final card = ref.read(financeSnapshotProvider).cardById(widget.cardId);
    _name = TextEditingController(text: card?.name ?? '');
    _limit = TextEditingController(text: card?.limit.round().toString() ?? '');
    _statementDay = TextEditingController(
      text: (card?.statementDay ?? 20).toString(),
    );
    _dueDay = TextEditingController(text: (card?.dueDay ?? 10).toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _statementDay.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final snapshot = ref.read(financeSnapshotProvider);
    final card = snapshot.cardById(widget.cardId);
    if (card == null) return;
    final updated = card.copyWith(
      name: _name.text.trim().isEmpty ? card.name : _name.text.trim(),
      limit: double.tryParse(_limit.text) ?? card.limit,
      statementDay: (int.tryParse(_statementDay.text) ?? card.statementDay)
          .clamp(1, 28),
      dueDay: (int.tryParse(_dueDay.text) ?? card.dueDay).clamp(1, 28),
    );
    await ref.read(cardRepositoryProvider).updateCard(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Card updated');
  }

  Future<void> _remove() async {
    await ref.read(cardRepositoryProvider).removeCard(widget.cardId);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Card removed');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Manage card'),
        const SizedBox(height: 12),
        _SheetField(controller: _name, hint: 'Card name'),
        Row(
          children: [
            Expanded(
              child: _SheetField(
                controller: _limit,
                hint: 'Credit limit',
                number: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SheetField(
                controller: _statementDay,
                hint: 'Statement day',
                number: true,
              ),
            ),
          ],
        ),
        _SheetField(controller: _dueDay, hint: 'Payment due day', number: true),
        const SizedBox(height: 4),
        const SectionCaption(
          'Statement history',
          margin: EdgeInsets.only(top: 12, bottom: 8),
        ),
        AppCard(
          child: Column(
            children: [
              for (final row in const [
                ['Oct', 21340],
                ['Sep', 17980],
                ['Aug', 24110],
              ])
                KeyValueRow(
                  label: '${row[0]} statement',
                  value: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoneyText(
                        rupee(row[1] as int),
                        style: AppTypography.sans(size: 14, color: c.tx),
                      ),
                      const SizedBox(width: 10),
                      const AppPill(label: 'Paid'),
                    ],
                  ),
                  border: row[0] != 'Aug',
                ),
            ],
          ),
        ),
        PrimaryButton(label: 'Save changes', onTap: _save),
        AppButton(
          label: 'Remove card',
          color: c.co,
          centered: true,
          onTap: _remove,
        ),
      ],
    );
  }
}

Future<void> showAddCardSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _AddCardSheet());
}

class _AddCardSheet extends ConsumerStatefulWidget {
  const _AddCardSheet();

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _name = TextEditingController();
  final _limit = TextEditingController();
  final _last4 = TextEditingController();
  final _statementDay = TextEditingController();
  final _dueDay = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _last4.dispose();
    _statementDay.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await ref
        .read(cardRepositoryProvider)
        .addCard(
          name: _name.text.trim().isEmpty ? 'New card' : _name.text.trim(),
          limit: double.tryParse(_limit.text) ?? 50000,
          last4: _last4.text.trim().isEmpty ? '0000' : _last4.text.trim(),
          statementDay: int.tryParse(_statementDay.text) ?? 20,
          dueDay: int.tryParse(_dueDay.text) ?? 10,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Card added');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('New card'),
        const SizedBox(height: 12),
        _SheetField(controller: _name, hint: 'Card name'),
        Row(
          children: [
            Expanded(
              child: _SheetField(
                controller: _limit,
                hint: 'Credit limit',
                number: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SheetField(
                controller: _last4,
                hint: 'Last 4 digits',
                number: true,
                maxLength: 4,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _SheetField(
                controller: _statementDay,
                hint: 'Statement day',
                number: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SheetField(
                controller: _dueDay,
                hint: 'Due day',
                number: true,
              ),
            ),
          ],
        ),
        PrimaryButton(label: 'Add card', onTap: _add),
      ],
    );
  }
}

Future<void> showStatementDetailSheet(
  BuildContext context,
  String cardId, {
  int? statementIndex,
  bool openCycle = false,
}) {
  return showAppSheet<void>(
    context,
    (_) => _StatementDetailSheet(
      cardId: cardId,
      statementIndex: statementIndex,
      openCycle: openCycle,
    ),
  );
}

class _StatementDetailSheet extends ConsumerWidget {
  const _StatementDetailSheet({
    required this.cardId,
    this.statementIndex,
    this.openCycle = false,
  });

  final String cardId;
  final int? statementIndex;
  final bool openCycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final card = snapshot.cardById(cardId);
    if (card == null) return const SizedBox.shrink();
    if (!openCycle && statementIndex == null) {
      return const SizedBox.shrink();
    }
    final statement = openCycle ? null : card.statements[statementIndex!];
    final cycle = card.openCycle;
    final rangeStart = openCycle ? cycle?.start : statement?.start;
    final rangeEnd = openCycle ? cycle?.end : statement?.end;
    if (rangeStart == null || rangeEnd == null) return const SizedBox.shrink();
    final tx =
        snapshot
            .forCard(cardId)
            .where(
              (t) =>
                  !t.date.isBefore(rangeStart) &&
                  t.date.isBefore(rangeEnd.add(const Duration(days: 1))),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final categories = <String, double>{};
    for (final t in tx) {
      if (t.amount < 0) {
        categories[t.category] = (categories[t.category] ?? 0) - t.amount;
      }
    }
    final maxCategory = categories.values.isEmpty
        ? 1.0
        : categories.values.reduce((a, b) => a > b ? a : b);
    final payments =
        card.payments
            .where(
              (p) =>
                  statement != null &&
                  p.statementEnd != null &&
                  dateOnly(p.statementEnd!).isAtSameMomentAs(statement.end),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.name, style: AppTypography.sans(size: 14, color: c.mu)),
        Text(
          openCycle ? 'Open cycle' : 'Statement',
          style: AppTypography.serif(size: 30, color: c.tx),
        ),
        Text(
          '${shortDate(rangeStart)} – ${shortDate(rangeEnd)}',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        const SizedBox(height: 12),
        MetricGrid(
          children: [
            MetricTile(
              label: openCycle ? 'Unbilled' : 'Billed',
              value: rupee(
                openCycle ? (cycle?.amount ?? 0) : (statement?.amount ?? 0),
              ),
            ),
            MetricTile(
              label: openCycle ? 'Bills on' : 'Due date',
              value: openCycle
                  ? dayMonth(rangeEnd)
                  : dayMonth(statement!.dueDate),
            ),
          ],
        ),
        if (!openCycle) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                      Text(
                        statement!.status.label,
                        style: AppTypography.sans(
                          size: 14,
                          color: statement.status.color(c),
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      '${rupee(statement.paid)} paid',
                      style: AppTypography.sans(size: 14, color: c.tx),
                    ),
                    MoneyText(
                      '${rupee(statement.remaining)} remaining',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${tx.length} transactions totalling ${rupee(tx.fold<double>(0, (sum, t) => sum - t.amount))}',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        const SizedBox(height: 10),
        for (final entry
            in categories.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: AppTypography.sans(size: 12, color: c.tx),
                      ),
                    ),
                    MoneyText(
                      rupee(entry.value),
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.value / maxCategory,
                    minHeight: 4,
                    backgroundColor: c.c2,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.category(entry.key),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SectionCaption(
          'Transactions',
          margin: EdgeInsets.only(top: 10, bottom: 6),
        ),
        for (var i = 0; i < tx.length; i++)
          _MiniTransaction(tx: tx[i], showDivider: i < tx.length - 1),
        if (payments.isNotEmpty) ...[
          const SectionCaption(
            'Payments',
            margin: EdgeInsets.only(top: 14, bottom: 6),
          ),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < payments.length; i++)
                  KeyValueRow(
                    label:
                        '${dayLabel(payments[i].date)} · from ${snapshot.accountById(payments[i].accountId)?.name ?? 'account'}',
                    value: MoneyText(
                      rupee(payments[i].amount),
                      style: AppTypography.sans(size: 14, color: c.ac),
                    ),
                    border: i < payments.length - 1,
                  ),
              ],
            ),
          ),
        ],
        if (!openCycle && (statement?.remaining ?? 0) > 0)
          PrimaryButton(
            label: 'Pay ${rupee(statement!.remaining)}',
            onTap: () {
              Navigator.of(context).pop();
              showPayCardSheet(
                context,
                cardId,
                initialAmount: statement.remaining,
              );
            },
          ),
        AppButton(
          label: 'Export statement',
          centered: true,
          margin: const EdgeInsets.only(top: 8),
          onTap: () {
            Navigator.of(context).pop();
            ref.read(toastProvider.notifier).show('Exporting statement…');
          },
        ),
      ],
    );
  }
}

class _MiniTransaction extends StatelessWidget {
  const _MiniTransaction({required this.tx, required this.showDivider});

  final Transaction tx;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchant,
                  style: AppTypography.sans(size: 13, color: c.tx),
                ),
                Text(
                  '${tx.category} · ${tx.dateLabel}',
                  style: AppTypography.sans(size: 11, color: c.mu),
                ),
              ],
            ),
          ),
          MoneyText(
            '−${rupee(tx.amount)}',
            style: AppTypography.sans(size: 13, color: c.tx),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    this.number = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final int? maxLength;

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
        maxLength: maxLength,
        style: AppTypography.sans(size: 13, color: c.tx),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: AppTypography.sans(size: 13, color: c.mu),
        ),
      ),
    );
  }
}
