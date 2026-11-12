import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/premium_sheet.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/account.dart';
import '../../data/models/finance_snapshot.dart';
import '../transactions/edit_transaction_sheet.dart';

const _accountTypeOptions = <AppSelectOption<AccountType>>[
  AppSelectOption(AccountType.savings, 'Bank account'),
  AppSelectOption(AccountType.cash, 'Cash'),
];

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final bankAccounts = snapshot.accounts
        .where((account) => account.type == AccountType.savings)
        .toList();
    final cashAccounts = snapshot.accounts
        .where((account) => account.type == AccountType.cash)
        .toList();
    final bankTotal = bankAccounts.fold<double>(
      0,
      (sum, account) => sum + account.balance,
    );
    final cashTotal = cashAccounts.fold<double>(
      0,
      (sum, account) => sum + account.balance,
    );
    final available = bankTotal + cashTotal;
    final accountCount = bankAccounts.length + cashAccounts.length;

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Banks',
          subtitle: accountCount == 0
              ? 'Bank & cash balances'
              : '$accountCount account${accountCount == 1 ? '' : 's'} · ${rupee(available)} available',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: 'accounts',
                    color: c.ac,
                    size: 36,
                    backgroundOpacity: 0.1,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available across banks & cash',
                          style: AppTypography.sans(size: 12, color: c.mu),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          accountCount == 0
                              ? 'No accounts linked'
                              : '$accountCount linked account${accountCount == 1 ? '' : 's'}',
                          style: AppTypography.sans(
                            size: 10,
                            color: c.mu.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedAmount(
                value: available,
                style: AppTypography.serif(
                  size: 42,
                  color: c.tx,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'In banks',
                      amount: bankTotal,
                      icon: 'accounts',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Cash in hand',
                      amount: cashTotal,
                      icon: 'cash',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (accountCount == 0)
          EmptyState(
            title: 'No bank accounts yet',
            message: 'Add a bank account or cash balance to start tracking.',
            actionLabel: 'Add account',
            onAction: () => _showAddAccount(context, ref),
          ),
        if (bankAccounts.isNotEmpty) ...[
          _AccountsSectionHeader(
            icon: 'accounts',
            label: 'Bank accounts',
            amount: bankTotal,
          ),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < bankAccounts.length; i++)
                  _AccountRow(
                    account: bankAccounts[i],
                    showDivider: i < bankAccounts.length - 1,
                    onTap: () => _showAccount(context, ref, bankAccounts[i]),
                  ),
              ],
            ),
          ),
        ],
        if (cashAccounts.isNotEmpty) ...[
          _AccountsSectionHeader(
            icon: 'cash',
            label: 'Cash',
            amount: cashTotal,
          ),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < cashAccounts.length; i++)
                  _AccountRow(
                    account: cashAccounts[i],
                    showDivider: i < cashAccounts.length - 1,
                    onTap: () => _showAccount(context, ref, cashAccounts[i]),
                  ),
              ],
            ),
          ),
        ],
        AppButton(
          label: 'Add account',
          leading: SpendIcon('plus', size: 14, color: c.tx),
          onTap: () => _showAddAccount(context, ref),
        ),
        if (accountCount >= 2)
          AppButton(
            label: 'Transfer between accounts',
            leading: SpendIcon('transfer', size: 14, color: c.tx),
            onTap: () => _showTransfer(context, ref, snapshot),
          ),
      ],
    );
  }

  void _showAccount(BuildContext context, WidgetRef ref, Account account) {
    final name = TextEditingController(text: account.name);
    final balance = TextEditingController(
      text: account.balance.round().toString(),
    );
    var type = account.type;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final c = context.spend;
          final recent = ref
              .read(financeSnapshotProvider)
              .forAccount(account.id)
              .take(3)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(account.name),
              AnimatedAmount(
                value: account.balance,
                style: AppTypography.serif(size: 50, color: c.tx),
              ),
              const SizedBox(height: 10),
              LabeledField(
                label: 'Account name',
                child: _Field(controller: name, hint: 'Name'),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Account type',
                      child: AppSelect<AccountType>(
                        value: type,
                        options: _accountTypeOptions,
                        onChanged: (value) =>
                            setSheetState(() => type = value ?? account.type),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LabeledField(
                      label: 'Balance',
                      child: _Field(
                        controller: balance,
                        hint: 'Balance',
                        number: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SectionCaption('Recent'),
              if (recent.isEmpty)
                Text(
                  'No linked transactions yet',
                  style: AppTypography.sans(size: 12, color: c.mu),
                )
              else
                for (var i = 0; i < recent.length; i++)
                  TransactionRow(
                    transaction: recent[i],
                    showDivider: i < recent.length - 1,
                    onTap: () =>
                        showEditTransactionSheet(context, recent[i].id),
                  ),
              PrimaryButton(
                label: 'Save',
                onTap: () async {
                  await ref
                      .read(accountRepositoryProvider)
                      .updateAccount(
                        account.copyWith(
                          name: name.text.trim().isEmpty
                              ? account.name
                              : name.text.trim(),
                          balance:
                              double.tryParse(balance.text) ?? account.balance,
                          type: type,
                        ),
                      );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref.read(toastProvider.notifier).show('Account updated');
                },
              ),
              AppButton(
                label: 'Transfer money',
                centered: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showTransfer(
                    context,
                    ref,
                    ref.read(financeSnapshotProvider),
                  );
                },
              ),
              AppButton(
                label: 'Delete account',
                color: c.co,
                centered: true,
                onTap: () async {
                  await ref
                      .read(accountRepositoryProvider)
                      .removeAccount(account.id);
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref.read(toastProvider.notifier).show('Account removed');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddAccount(BuildContext context, WidgetRef ref) {
    showAppSheet<void>(context, (_) => const _AddAccountSheet());
  }

  void _showTransfer(
    BuildContext context,
    WidgetRef ref,
    FinanceSnapshot snapshot,
  ) {
    final transferable = snapshot.accounts
        .where((account) => account.type != AccountType.investments)
        .toList();
    if (transferable.length < 2) {
      ref.read(toastProvider.notifier).show('Add two accounts first');
      return;
    }
    showAppSheet<void>(context, (_) => const _TransferMoneySheet());
  }
}

class _AccountsSectionHeader extends StatelessWidget {
  const _AccountsSectionHeader({
    required this.icon,
    required this.label,
    required this.amount,
  });

  final String icon;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Row(
        children: [
          SpendIcon(icon, size: 13, color: c.mu, strokeWidth: 1.7),
          const SizedBox(width: 6),
          Text(label.toUpperCase(), style: AppTypography.caption(c.mu)),
          const Spacer(),
          Text(rupee(amount), style: AppTypography.sans(size: 12, color: c.mu)),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.showDivider,
    required this.onTap,
  });

  final Account account;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final isCash = account.type == AccountType.cash;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: c.ln)) : null,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (isCash)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: const Color(0xFF34D399).withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const SpendIcon(
                      'cash',
                      size: 19,
                      color: Color(0xFF34D399),
                    ),
                  )
                else
                  MerchantAvatar(
                    merchant: account.name,
                    category: 'Income',
                    size: 38,
                  ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: c.c1,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.ln),
                    ),
                    alignment: Alignment.center,
                    child: SpendIcon(
                      isCash ? 'cash' : 'accounts',
                      size: 9,
                      color: isCash ? const Color(0xFF34D399) : c.mu,
                      strokeWidth: 1.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(size: 14, color: c.tx),
                  ),
                  Text(
                    isCash
                        ? 'Cash'
                        : (account.last4 == null || account.last4!.isEmpty
                              ? 'Bank account'
                              : 'Bank · •••• ${account.last4}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                ],
              ),
            ),
            MoneyText(
              rupee(account.balance),
              style: AppTypography.sans(size: 14, color: c.tx),
            ),
            const SizedBox(width: 8),
            SpendIcon('chevronRight', size: 14, color: c.mu),
          ],
        ),
      ),
    );
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  const _AddAccountSheet();

  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  AccountType _type = AccountType.savings;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  double get _opening => double.tryParse(_balance.text) ?? 0;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ref.read(toastProvider.notifier).show('Name the account');
      return;
    }
    if (_opening < 0) {
      ref
          .read(toastProvider.notifier)
          .show('Opening balance cannot be negative');
      return;
    }
    await ref
        .read(accountRepositoryProvider)
        .addAccount(name: name, type: _type, openingBalance: _opening);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('$name added');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final name = _name.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'accounts',
          title: 'Add account',
          subtitle: 'Track a bank balance or cash in hand.',
        ),
        const SizedBox(height: 20),
        const PremiumLabel('Account name', requiredField: true),
        PremiumField(
          controller: _name,
          hint: 'e.g. HDFC Savings',
          icon: 'accounts',
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
              ('HDFC Savings', AccountType.savings),
              ('SBI Salary', AccountType.savings),
              ('Cash wallet', AccountType.cash),
            ])
              AppPill(
                label: preset.$1,
                onTap: () => setState(() {
                  _name.text = preset.$1;
                  _type = preset.$2;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Account type'),
        Row(
          children: [
            Expanded(
              child: _AccountTypeChoice(
                icon: 'accounts',
                title: 'Bank account',
                subtitle: 'Savings or salary',
                selected: _type == AccountType.savings,
                onTap: () => setState(() => _type = AccountType.savings),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AccountTypeChoice(
                icon: 'cash',
                title: 'Cash in hand',
                subtitle: 'Wallet or cash',
                selected: _type == AccountType.cash,
                onTap: () => setState(() => _type = AccountType.cash),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Opening balance'),
        PremiumField(
          controller: _balance,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        PremiumSummaryCard(
          icon: _type == AccountType.cash ? 'cash' : 'accounts',
          eyebrow: 'Ready to add',
          value: rupee(_opening),
          caption: name.isEmpty
              ? 'Name this account'
              : '$name · ${_type.label}',
          accent: c.ac,
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Create account', onTap: _save),
      ],
    );
  }
}

class _AccountTypeChoice extends StatelessWidget {
  const _AccountTypeChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected ? c.ac.withValues(alpha: c.dark ? 0.1 : 0.07) : c.c2,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? c.ac.withValues(alpha: 0.45) : c.ln,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              color: selected ? c.ac : c.mu,
              size: 32,
              backgroundOpacity: selected ? 0.12 : 0.06,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(
                      size: 12,
                      color: c.tx,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(size: 9, color: c.mu),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferMoneySheet extends ConsumerStatefulWidget {
  const _TransferMoneySheet();

  @override
  ConsumerState<_TransferMoneySheet> createState() =>
      _TransferMoneySheetState();
}

class _TransferMoneySheetState extends ConsumerState<_TransferMoneySheet> {
  final _amount = TextEditingController();
  String? _from;
  String? _to;

  @override
  void initState() {
    super.initState();
    final accounts = ref
        .read(financeSnapshotProvider)
        .accounts
        .where((account) => account.type != AccountType.investments)
        .toList();
    if (accounts.isNotEmpty) _from = accounts.first.id;
    if (accounts.length > 1) _to = accounts[1].id;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(List<Account> accounts) async {
    final fromId = _from != null && accounts.any((a) => a.id == _from)
        ? _from!
        : accounts.first.id;
    final toOptions = accounts.where((a) => a.id != fromId).toList();
    final toId = _to != null && toOptions.any((a) => a.id == _to)
        ? _to!
        : toOptions.first.id;
    final value = double.tryParse(_amount.text) ?? 0;
    final from = accounts.firstWhere((a) => a.id == fromId);
    if (value <= 0) {
      ref.read(toastProvider.notifier).show('Enter an amount');
      return;
    }
    if (value > from.balance) {
      ref.read(toastProvider.notifier).show('Not enough in ${from.name}');
      return;
    }
    await ref
        .read(accountRepositoryProvider)
        .transferBetweenAccounts(
          fromAccountId: fromId,
          toAccountId: toId,
          amount: value,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Moved ${rupee(value)}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final accounts = ref
        .watch(financeSnapshotProvider)
        .accounts
        .where((account) => account.type != AccountType.investments)
        .toList();
    if (accounts.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumSheetHeader(
            icon: 'transfer',
            title: 'Transfer money',
            subtitle: 'Move cash between two accounts.',
          ),
          const SizedBox(height: 18),
          const PremiumNotice(
            icon: 'accounts',
            text: 'Add at least two bank or cash accounts to transfer money.',
          ),
        ],
      );
    }
    final fromId = accounts.any((a) => a.id == _from)
        ? _from
        : accounts.first.id;
    final toOptions = accounts.where((a) => a.id != fromId).toList();
    final toId = toOptions.any((a) => a.id == _to) ? _to : toOptions.first.id;
    final from = accounts.firstWhere((a) => a.id == fromId);
    final to = accounts.firstWhere((a) => a.id == toId);
    final amount = double.tryParse(_amount.text) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'transfer',
          title: 'Transfer money',
          subtitle: 'Move cash between your accounts.',
        ),
        const SizedBox(height: 20),
        const PremiumLabel('From'),
        AppSelect<String>(
          value: fromId,
          options: [
            for (final account in accounts)
              AppSelectOption(
                account.id,
                '${account.name} · ${rupee(account.balance)}',
              ),
          ],
          onChanged: (value) => setState(() => _from = value ?? fromId),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () {
              setState(() {
                final previousFrom = fromId;
                _from = toId;
                _to = previousFrom;
              });
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.c2, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: SpendIcon('transfer', size: 16, color: c.tx),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const PremiumLabel('To'),
        AppSelect<String>(
          value: toId,
          options: [
            for (final account in toOptions)
              AppSelectOption(
                account.id,
                '${account.name} · ${rupee(account.balance)}',
              ),
          ],
          onChanged: (value) => setState(() => _to = value ?? toId),
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Amount'),
        PremiumField(
          controller: _amount,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        PremiumSummaryCard(
          icon: 'transfer',
          eyebrow: 'Move',
          value: rupee(amount),
          caption: '${from.name} → ${to.name}',
          accent: c.ac,
        ),
        const SizedBox(height: 12),
        const PremiumNotice(
          text: 'The transfer updates both balances immediately.',
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Transfer', onTap: () => _save(accounts)),
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
        textAlignVertical: TextAlignVertical.center,
        keyboardType: number ? TextInputType.number : TextInputType.text,
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
