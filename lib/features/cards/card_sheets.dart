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
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/premium_sheet.dart';
import '../../core/widgets/segmented_control.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/models/credit_card.dart';
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
            textAlignVertical: TextAlignVertical.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.sans(size: 14, color: c.tx),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) setState(() => _amount = parsed);
            },
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
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
  final _statementDay = TextEditingController(text: '20');
  final _dueDay = TextEditingController(text: '10');

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _last4.dispose();
    _statementDay.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  int get _statement => int.tryParse(_statementDay.text) ?? 0;
  int get _due => int.tryParse(_dueDay.text) ?? 0;
  double get _limitValue => double.tryParse(_limit.text) ?? 0;
  String get _digits => _last4.text.trim();

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) {
      ref.read(toastProvider.notifier).show('Name the card');
      return;
    }
    if (_limitValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter a credit limit');
      return;
    }
    if (_digits.length != 4 || int.tryParse(_digits) == null) {
      ref.read(toastProvider.notifier).show('Enter the last 4 digits');
      return;
    }
    if (_statement < 1 || _statement > 28 || _due < 1 || _due > 28) {
      ref.read(toastProvider.notifier).show('Billing days must be 1–28');
      return;
    }
    await ref
        .read(cardRepositoryProvider)
        .addCard(
          name: _name.text.trim(),
          limit: _limitValue,
          last4: _digits,
          statementDay: _statement,
          dueDay: _due,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Card added');
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    final last4 = _digits.isEmpty ? '••••' : _digits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'cards',
          title: 'Add card',
          subtitle: 'Track dues, statements and available credit.',
        ),
        const SizedBox(height: 18),
        _CardPreview(
          name: name.isEmpty ? 'NEW CARD' : name,
          last4: last4,
          limit: _limitValue,
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Card name', requiredField: true),
        PremiumField(
          controller: _name,
          hint: 'e.g. HDFC Millennia',
          icon: 'cards',
          capitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in const [
              'HDFC Millennia',
              'ICICI Amazon Pay',
              'Axis Neo',
            ])
              AppPill(
                label: preset,
                onTap: () => setState(() {
                  _name.text = preset;
                  _name.selection = TextSelection.collapsed(
                    offset: preset.length,
                  );
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Credit limit', requiredField: true),
        PremiumField(
          controller: _limit,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumLabel('Last 4 digits', requiredField: true),
                  PremiumField(
                    controller: _last4,
                    hint: '0000',
                    number: true,
                    maxLength: 4,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumLabel('Statement day'),
                  PremiumField(
                    controller: _statementDay,
                    hint: '20',
                    number: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumLabel('Due day'),
                  PremiumField(
                    controller: _dueDay,
                    hint: '10',
                    number: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PremiumNotice(
          icon: 'calendar',
          text:
              'Statement on the ${_ordinal(_statement)} · payment due on the ${_ordinal(_due)}.',
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Add card', onTap: _add),
      ],
    );
  }

  String _ordinal(int day) {
    if (day <= 0) return '—';
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.name,
    required this.last4,
    required this.limit,
  });

  final String name;
  final String last4;
  final double limit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: CreditCard.newCardGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 26,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -48,
            top: -68,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: 22,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'SPENDWISER',
                    style: AppTypography.sans(
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.52),
                      letterSpacing: 2.1,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  SpendIcon(
                    'cards',
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '••••  $last4',
                    style: AppTypography.sans(
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.72),
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.serif(
                      size: 24,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREDIT LIMIT',
                        style: AppTypography.sans(
                          size: 8,
                          color: Colors.white.withValues(alpha: 0.45),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        rupee(limit),
                        style: AppTypography.sans(
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'CREDIT',
                    style: AppTypography.sans(
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 1.4,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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
          ..sort(compareTransactionsNewestFirst);
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
              amount: openCycle
                  ? (cycle?.amount ?? 0)
                  : (statement?.amount ?? 0),
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
                  [
                    tx.category,
                    tx.dateLabel,
                    if (tx.addedTimeLabel != null) tx.addedTimeLabel!,
                  ].join(' · '),
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
        textAlignVertical: TextAlignVertical.center,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: AppTypography.sans(size: 13, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          counterText: '',
          hintText: hint,
          hintStyle: AppTypography.sans(size: 13, color: c.mu),
        ),
      ),
    );
  }
}
