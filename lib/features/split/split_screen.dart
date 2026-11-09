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
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/split_group.dart';

class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({super.key});

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> {
  int _groupIndex = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    if (snapshot.groups.isEmpty) {
      return ScreenScroll(
        children: [
          const PageHeader(title: 'Split', subtitle: 'No groups yet'),
          EmptyState(
            title: 'Split with friends',
            message: 'Create a group to track shared expenses.',
            actionLabel: 'New group',
            onAction: () => _newGroup(context),
          ),
        ],
      );
    }
    final index = _groupIndex.clamp(0, snapshot.groups.length - 1);
    final group = snapshot.groups[index];
    final net = group.netBalances();
    final yourBalance = net['You'] ?? 0;
    final total = snapshot.youAreOwed;
    final transfers = group.simplify();

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Split',
          subtitle: total >= 0
              ? 'You’re owed ${rupee(total)}'
              : 'You owe ${rupee(total)}',
        ),
        BleedRow(
          height: 34,
          children: [
            for (var i = 0; i < snapshot.groups.length; i++)
              AppPill(
                label: snapshot.groups[i].name,
                active: i == index,
                onTap: () => setState(() => _groupIndex = i),
              ),
            AppPill(label: '+ New group', onTap: () => _newGroup(context)),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${group.members.length} people · ${rupee(group.totalSpent)} spent',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ),
                  AppPill(
                    label: 'Manage',
                    onTap: () => _manageGroup(context, group),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MoneyText(
                '${yourBalance < 0 ? '−' : ''}${rupee(yourBalance)}',
                style: AppTypography.serif(
                  size: 36,
                  color: yourBalance < 0 ? c.co : c.tx,
                ),
              ),
              Text(
                yourBalance > 0
                    ? 'you get back'
                    : yourBalance < 0
                    ? 'you owe'
                    : 'you’re settled',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        PrimaryButton(
          label: '+ Add expense',
          onTap: () => _showExpense(context, group),
          margin: const EdgeInsets.only(top: 0, bottom: 8),
        ),
        const SectionCaption('Balances'),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < group.members.length; i++)
                _MemberRow(
                  name: group.members[i],
                  balance: net[group.members[i]] ?? 0,
                  showDivider: i < group.members.length - 1,
                ),
            ],
          ),
        ),
        const SectionCaption('Settle up'),
        AppCard(
          child: Column(
            children: [
              if (transfers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'All settled up',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  ),
                )
              else
                for (var i = 0; i < transfers.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i < transfers.length - 1
                          ? Border(bottom: BorderSide(color: c.ln))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${transfers[i].from} pays ${transfers[i].to}',
                                style: AppTypography.sans(
                                  size: 14,
                                  color: c.tx,
                                ),
                              ),
                              Text(
                                'suggested',
                                style: AppTypography.sans(
                                  size: 11,
                                  color: c.mu,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoneyText(
                          rupee(transfers[i].amount),
                          style: AppTypography.sans(size: 14, color: c.tx),
                        ),
                        const SizedBox(width: 8),
                        AppPill(
                          label: 'Settle',
                          active: true,
                          onTap: () async {
                            await ref
                                .read(splitRepositoryProvider)
                                .settleSplit(
                                  groupId: group.id,
                                  from: transfers[i].from,
                                  to: transfers[i].to,
                                  amount: transfers[i].amount,
                                  date: DateTime.now(),
                                );
                            ref
                                .read(toastProvider.notifier)
                                .show(
                                  '${transfers[i].from} paid ${transfers[i].to} ${rupee(transfers[i].amount)}',
                                );
                          },
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SectionCaption('History'),
        AppCard(
          child: Column(
            children: [
              for (var i = group.expenses.length - 1; i >= 0; i--)
                _ExpenseRow(
                  expense: group.expenses[i],
                  showDivider: i > 0,
                  onTap: () => group.expenses[i].isSettlement
                      ? _removeSettlement(context, group, i)
                      : _showExpense(context, group, index: i),
                ),
              if (group.expenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'No expenses yet',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _newGroup(BuildContext context) {
    final name = TextEditingController();
    final members = TextEditingController();
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('New group'),
          const SizedBox(height: 12),
          _Field(controller: name, hint: 'Group name (e.g. Weekend trip)'),
          _Field(controller: members, hint: 'People, comma separated'),
          Text(
            'You’re added automatically.',
            style: AppTypography.sans(size: 12, color: sheetContext.spend.mu),
          ),
          PrimaryButton(
            label: 'Create group',
            onTap: () async {
              if (name.text.trim().isEmpty) {
                ref.read(toastProvider.notifier).show('Name the group');
                return;
              }
              await ref
                  .read(splitRepositoryProvider)
                  .addGroup(
                    name: name.text.trim(),
                    members: members.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList(),
                  );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Group created');
            },
          ),
        ],
      ),
    );
  }

  void _manageGroup(BuildContext context, SplitGroup group) {
    final name = TextEditingController(text: group.name);
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('Manage group'),
          const SizedBox(height: 12),
          _Field(controller: name, hint: 'Group name'),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < group.members.length; i++)
                  KeyValueRow(
                    label: group.members[i],
                    value: Text(
                      group.members[i] == 'You' ? 'you' : 'member',
                      style: AppTypography.sans(
                        size: 12,
                        color: sheetContext.spend.mu,
                      ),
                    ),
                    border: i < group.members.length - 1,
                  ),
              ],
            ),
          ),
          PrimaryButton(
            label: 'Save',
            onTap: () async {
              await ref
                  .read(splitRepositoryProvider)
                  .renameGroup(group.id, name.text.trim());
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
            },
          ),
          AppButton(
            label: 'Delete group',
            color: sheetContext.spend.co,
            centered: true,
            onTap: () async {
              await ref.read(splitRepositoryProvider).removeGroup(group.id);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              setState(() => _groupIndex = 0);
              ref.read(toastProvider.notifier).show('Group removed');
            },
          ),
        ],
      ),
    );
  }

  void _removeSettlement(BuildContext context, SplitGroup group, int index) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Remove settlement?',
            subtitle: 'Balances will go back to what they were before.',
          ),
          PrimaryButton(
            label: 'Remove',
            onTap: () async {
              await ref
                  .read(splitRepositoryProvider)
                  .deleteSplitExpense(group.id, index);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showExpense(BuildContext context, SplitGroup group, {int? index}) {
    showAppSheet<void>(
      context,
      (_) => _ExpenseSheet(groupId: group.id, index: index),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.balance,
    required this.showDivider,
  });

  final String name;
  final double balance;
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              name.substring(0, 1),
              style: AppTypography.sans(size: 12, color: c.tx),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.sans(size: 14, color: c.tx)),
                Text(
                  balance > 0
                      ? 'gets back'
                      : balance < 0
                      ? 'owes'
                      : 'settled',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ],
            ),
          ),
          MoneyText(
            balance == 0 ? '—' : rupee(balance),
            style: AppTypography.sans(
              size: 14,
              color: balance > 0 ? c.ac : c.tx,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.showDivider,
    required this.onTap,
  });

  final SplitExpense expense;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                    expense.isSettlement
                        ? '${expense.paidBy} paid ${expense.settledTo}'
                        : expense.description,
                    style: AppTypography.sans(size: 14, color: c.tx),
                  ),
                  Text(
                    expense.isSettlement
                        ? 'Settlement · ${shortDate(expense.date)}'
                        : 'paid by ${expense.paidBy} · ${expense.type.label} · ${shortDate(expense.date)}',
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ),
            ),
            MoneyText(
              rupee(expense.amount),
              style: AppTypography.sans(size: 14, color: c.tx),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({required this.groupId, this.index});

  final String groupId;
  final int? index;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  late final TextEditingController _description;
  late final TextEditingController _amount;
  final _values = <String, TextEditingController>{};
  late String _paidBy;
  late SplitType _type;
  late Set<String> _included;

  @override
  void initState() {
    super.initState();
    final group = ref
        .read(financeSnapshotProvider)
        .groups
        .firstWhere((g) => g.id == widget.groupId);
    final existing = widget.index == null
        ? null
        : group.expenses[widget.index!];
    _description = TextEditingController(text: existing?.description ?? '');
    _amount = TextEditingController(
      text: existing == null ? '' : existing.amount.round().toString(),
    );
    _paidBy = existing?.paidBy ?? 'You';
    _type = existing?.type ?? SplitType.equal;
    _included = existing == null
        ? group.members.toSet()
        : existing.shares.keys.toSet();
    for (final member in group.members) {
      final share = existing?.shares[member];
      _values[member] = TextEditingController(
        text: share == null
            ? ''
            : existing!.type == SplitType.percent
            ? (share / existing.amount * 100).toStringAsFixed(2)
            : share.round().toString(),
      );
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, double>? _shares(double amount) {
    if (_type == SplitType.equal) {
      return splitEqually(amount, _included.toList());
    }
    final shares = <String, double>{};
    var total = 0.0;
    for (final member in _included) {
      final value = double.tryParse(_values[member]?.text ?? '') ?? 0;
      shares[member] = _type == SplitType.percent
          ? amount * value / 100
          : value;
      total += value;
    }
    final expected = _type == SplitType.percent ? 100.0 : amount;
    return (total - expected).abs() < 0.01 ? shares : null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final group = ref
        .watch(financeSnapshotProvider)
        .groups
        .firstWhere((g) => g.id == widget.groupId);
    final amount = double.tryParse(_amount.text) ?? 0;
    final shares = _shares(amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle('${widget.index == null ? 'New' : 'Edit'} expense'),
        const SizedBox(height: 12),
        _Field(controller: _description, hint: 'What was it for?'),
        _Field(
          controller: _amount,
          hint: 'Amount',
          number: true,
          onChanged: (_) => setState(() {}),
        ),
        Text('Paid by', style: AppTypography.sans(size: 12, color: c.mu)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final member in group.members)
              AppPill(
                label: member,
                active: _paidBy == member,
                onTap: () => setState(() => _paidBy = member),
              ),
          ],
        ),
        SegmentedControl<SplitType>(
          options: const [
            SegmentedOption(SplitType.equal, 'Equally'),
            SegmentedOption(SplitType.exact, 'Exact ₹'),
            SegmentedOption(SplitType.percent, 'Percent'),
          ],
          selected: _type,
          onChanged: (value) => setState(() => _type = value),
        ),
        Text('Split between', style: AppTypography.sans(size: 12, color: c.mu)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final member in group.members)
              AppPill(
                label: member,
                active: _included.contains(member),
                onTap: () => setState(() {
                  if (_included.contains(member)) {
                    if (_included.length > 1) _included.remove(member);
                  } else {
                    _included.add(member);
                  }
                }),
              ),
          ],
        ),
        if (_type != SplitType.equal) ...[
          const SizedBox(height: 8),
          for (final member in _included)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      member,
                      style: AppTypography.sans(size: 13, color: c.tx),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: _Field(
                      controller: _values[member]!,
                      hint: _type == SplitType.percent ? '%' : '₹',
                      number: true,
                      onChanged: (_) => setState(() {}),
                      margin: false,
                    ),
                  ),
                ],
              ),
            ),
        ],
        Text(
          _type == SplitType.equal
              ? (amount == 0
                    ? ''
                    : '${rupee(amount / _included.length)} each · ${_included.length} people')
              : (shares == null ? 'The split doesn’t add up yet' : 'Adds up'),
          style: AppTypography.sans(
            size: 12,
            color: shares == null && _type != SplitType.equal ? c.co : c.mu,
          ),
        ),
        PrimaryButton(
          label: 'Save expense',
          onTap: () async {
            if (amount <= 0) {
              ref.read(toastProvider.notifier).show('Enter an amount');
              return;
            }
            final computed = _shares(amount);
            if (computed == null) {
              ref.read(toastProvider.notifier).show('The split doesn’t add up');
              return;
            }
            if (widget.index == null) {
              await ref
                  .read(splitRepositoryProvider)
                  .addSplitExpense(
                    groupId: group.id,
                    description: _description.text.trim().isEmpty
                        ? 'Expense'
                        : _description.text.trim(),
                    amount: amount,
                    paidBy: _paidBy,
                    type: _type,
                    shares: computed,
                  );
            } else {
              await ref
                  .read(splitRepositoryProvider)
                  .editSplitExpense(
                    groupId: group.id,
                    index: widget.index!,
                    description: _description.text.trim().isEmpty
                        ? 'Expense'
                        : _description.text.trim(),
                    amount: amount,
                    paidBy: _paidBy,
                    type: _type,
                    shares: computed,
                  );
            }
            if (!context.mounted) return;
            Navigator.of(context).pop();
            ref.read(toastProvider.notifier).show('Saved ${rupee(amount)}');
          },
        ),
        if (widget.index != null)
          AppButton(
            label: 'Delete expense',
            color: c.co,
            centered: true,
            onTap: () async {
              await ref
                  .read(splitRepositoryProvider)
                  .deleteSplitExpense(group.id, widget.index!);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.number = false,
    this.onChanged,
    this.margin = true,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final ValueChanged<String>? onChanged;
  final bool margin;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 48,
      margin: margin ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
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
        onChanged: onChanged,
        style: AppTypography.sans(size: 13, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.sans(size: 13, color: c.mu),
        ),
      ),
    );
  }
}
