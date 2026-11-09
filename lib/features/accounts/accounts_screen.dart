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
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/account.dart';
import '../../data/models/finance_snapshot.dart';
import '../transactions/edit_transaction_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final assets = snapshot.accountsTotal;
    final dues = snapshot.cardDues;
    final portfolioValue = snapshot.investmentsValue;
    final portfolioInvested = snapshot.investments.fold<double>(
      0,
      (sum, i) => sum + i.invested,
    );

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Banks',
          subtitle: 'Net worth ${rupee(snapshot.netWorth)}',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Assets',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  ),
                  const Spacer(),
                  MoneyText(
                    rupee(assets),
                    style: AppTypography.sans(
                      size: 14,
                      color: c.tx,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value: assets + dues == 0 ? 0 : assets / (assets + dues),
                  minHeight: 6,
                  backgroundColor: c.c2,
                  valueColor: AlwaysStoppedAnimation(c.ac),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Card dues',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  ),
                  const Spacer(),
                  MoneyText(
                    rupee(dues),
                    style: AppTypography.sans(size: 14, color: c.co),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final type in AccountType.values) ...[
          if (snapshot.accounts.any((a) => a.type == type)) ...[
            SectionCaption(type.label),
            AppCard(
              child: Column(
                children: [
                  for (final entry
                      in snapshot.accounts
                          .where((a) => a.type == type)
                          .toList()
                          .asMap()
                          .entries)
                    _AccountRow(
                      account: entry.value,
                      showDivider:
                          entry.key <
                          snapshot.accounts
                                  .where((a) => a.type == type)
                                  .length -
                              1,
                      onTap: () => _showAccount(context, ref, entry.value),
                    ),
                ],
              ),
            ),
          ],
        ],
        const SectionCaption('Portfolio'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current value',
                          style: AppTypography.sans(size: 12, color: c.mu),
                        ),
                        MoneyText(
                          rupee(portfolioValue),
                          style: AppTypography.serif(size: 34, color: c.tx),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${portfolioValue >= portfolioInvested ? '+' : '−'}${rupee(portfolioValue - portfolioInvested)}',
                        style: AppTypography.sans(
                          size: 13,
                          color: portfolioValue >= portfolioInvested
                              ? c.ac
                              : c.co,
                        ),
                      ),
                      Text(
                        '${portfolioInvested == 0 ? 0 : ((portfolioValue / portfolioInvested - 1) * 100).toStringAsFixed(1)}% overall',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < snapshot.investments.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i < snapshot.investments.length - 1
                        ? Border(bottom: BorderSide(color: c.ln))
                        : null,
                  ),
                  child: Row(
                    children: [
                      MerchantAvatar(
                        merchant: snapshot.investments[i].name,
                        category: 'Income',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot.investments[i].name,
                              style: AppTypography.sans(size: 14, color: c.tx),
                            ),
                            Text(
                              '${snapshot.investments[i].type}${snapshot.investments[i].monthlySip > 0 ? ' · SIP ${rupee(snapshot.investments[i].monthlySip)}' : ''}',
                              style: AppTypography.sans(size: 12, color: c.mu),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MoneyText(
                            rupee(snapshot.investments[i].value),
                            style: AppTypography.sans(size: 14, color: c.tx),
                          ),
                          Text(
                            '${snapshot.investments[i].gain >= 0 ? '+' : '−'}${snapshot.investments[i].gainPercent.abs().toStringAsFixed(1)}%',
                            style: AppTypography.sans(
                              size: 11,
                              color: snapshot.investments[i].gain >= 0
                                  ? c.ac
                                  : c.co,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              AppButton(
                label: '+ Add holding',
                onTap: () {
                  ref
                      .read(toastProvider.notifier)
                      .show('Holdings are read-only in this demo');
                },
              ),
            ],
          ),
        ),
        AppButton(
          label: '+ Add account',
          onTap: () => _showAddAccount(context, ref),
        ),
        AppButton(
          label: 'Transfer between accounts',
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
              MoneyText(
                rupee(account.balance),
                style: AppTypography.serif(size: 50, color: c.tx),
              ),
              const SizedBox(height: 10),
              _Field(controller: name, hint: 'Name'),
              Row(
                children: [
                  Expanded(
                    child: AppSelect<AccountType>(
                      value: type,
                      options: [
                        for (final t in AccountType.values)
                          AppSelectOption(t, t.label),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => type = value ?? account.type),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Field(
                      controller: balance,
                      hint: 'Balance',
                      number: true,
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
    final name = TextEditingController();
    final balance = TextEditingController();
    var type = AccountType.savings;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('New account'),
              const SizedBox(height: 12),
              _Field(controller: name, hint: 'Name'),
              _Field(
                controller: balance,
                hint: 'Opening balance',
                number: true,
              ),
              AppSelect<AccountType>(
                value: type,
                options: [
                  for (final t in AccountType.values)
                    AppSelectOption(t, t.label),
                ],
                onChanged: (value) =>
                    setSheetState(() => type = value ?? AccountType.savings),
              ),
              PrimaryButton(
                label: 'Add',
                onTap: () async {
                  await ref
                      .read(accountRepositoryProvider)
                      .addAccount(
                        name: name.text.trim().isEmpty
                            ? 'Account'
                            : name.text.trim(),
                        type: type,
                        openingBalance: double.tryParse(balance.text) ?? 0,
                      );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref.read(toastProvider.notifier).show('Account added');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransfer(
    BuildContext context,
    WidgetRef ref,
    FinanceSnapshot snapshot,
  ) {
    if (snapshot.accounts.length < 2) {
      ref.read(toastProvider.notifier).show('Add two accounts first');
      return;
    }
    var from = snapshot.accounts.first.id;
    var to = snapshot.accounts[1].id;
    final amount = TextEditingController();
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('Transfer'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppSelect<String>(
                      value: from,
                      options: [
                        for (final account in snapshot.accounts)
                          AppSelectOption(account.id, account.name),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => from = value ?? from),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppSelect<String>(
                      value: to,
                      options: [
                        for (final account in snapshot.accounts)
                          AppSelectOption(account.id, account.name),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => to = value ?? to),
                    ),
                  ),
                ],
              ),
              _Field(controller: amount, hint: 'Amount', number: true),
              PrimaryButton(
                label: 'Transfer',
                onTap: () async {
                  final value = double.tryParse(amount.text) ?? 0;
                  if (value <= 0 || from == to) {
                    ref.read(toastProvider.notifier).show('Pick two accounts');
                    return;
                  }
                  await ref
                      .read(accountRepositoryProvider)
                      .transferBetweenAccounts(
                        fromAccountId: from,
                        toAccountId: to,
                        amount: value,
                      );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(toastProvider.notifier)
                      .show('Moved ${rupee(value)}');
                },
              ),
            ],
          );
        },
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                account.name.substring(0, 1),
                style: AppTypography.sans(size: 12, color: c.tx),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: AppTypography.sans(size: 14, color: c.tx),
                  ),
                  Text(
                    account.type.label,
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                ],
              ),
            ),
            MoneyText(
              rupee(account.balance),
              style: AppTypography.sans(size: 14, color: c.tx),
            ),
          ],
        ),
      ),
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
