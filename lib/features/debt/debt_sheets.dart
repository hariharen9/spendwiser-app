import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/loan.dart';
import '../../data/services/finance_calculator.dart';

Future<void> showRecordLoanPaymentSheet(
  BuildContext context,
  String loanId, {
  bool prepayment = false,
  double? amount,
}) {
  return showAppSheet<void>(
    context,
    (_) => _RecordPaymentSheet(
      loanId: loanId,
      prepayment: prepayment,
      initialAmount: amount,
    ),
  );
}

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  const _RecordPaymentSheet({
    required this.loanId,
    this.prepayment = false,
    this.initialAmount,
  });

  final String loanId;
  final bool prepayment;
  final double? initialAmount;

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  late LoanPaymentType _type;
  late final TextEditingController _amount;
  late DateTime _date;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    final snapshot = ref.read(financeSnapshotProvider);
    final loan = snapshot.loanById(widget.loanId);
    _type = widget.prepayment
        ? LoanPaymentType.prepayment
        : LoanPaymentType.emi;
    _amount = TextEditingController(
      text: (widget.initialAmount ?? loan?.emi ?? 0).round().toString(),
    );
    _date = DateTime.now();
    _accountId = snapshot.accounts.isEmpty ? null : snapshot.accounts.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_amount.text) ?? 0;
    if (value <= 0) {
      ref.read(toastProvider.notifier).show('Enter an amount');
      return;
    }
    final snapshot = ref.read(financeSnapshotProvider);
    final loan = snapshot.loanById(widget.loanId);
    await ref
        .read(loanRepositoryProvider)
        .recordLoanPayment(
          loanId: widget.loanId,
          amount: value,
          type: _type,
          date: DateTime(_date.year, _date.month, _date.day, 12),
          accountId: _accountId ?? snapshot.accounts.first.id,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref
        .read(toastProvider.notifier)
        .show(
          loan != null && loan.outstanding <= value
              ? 'Loan fully repaid'
              : 'Payment recorded',
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final loan = snapshot.loanById(widget.loanId);
    if (loan == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Record payment'),
        Text(loan.name, style: AppTypography.sans(size: 12, color: c.mu)),
        const SizedBox(height: 8),
        SegmentedControl<LoanPaymentType>(
          options: const [
            SegmentedOption(LoanPaymentType.emi, 'EMI'),
            SegmentedOption(LoanPaymentType.prepayment, 'Prepayment'),
          ],
          selected: _type,
          onChanged: (value) {
            setState(() {
              _type = value;
              _amount.text =
                  (value == LoanPaymentType.emi ? loan.emi : loan.outstanding)
                      .round()
                      .toString();
            });
          },
        ),
        _LoanField(controller: _amount, hint: 'Amount', number: true),
        Row(
          children: [
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
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: c.c2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isoDate(_date),
                    style: AppTypography.sans(size: 13, color: c.tx),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppSelect<String>(
                value: _accountId,
                options: [
                  for (final account in snapshot.accounts)
                    AppSelectOption(account.id, account.name),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
            ),
          ],
        ),
        Text(
          'Interest is split out automatically and the balance updates.',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
        PrimaryButton(label: 'Save payment', onTap: _save),
      ],
    );
  }
}

Future<void> showAddLoanSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _AddLoanSheet());
}

class _AddLoanSheet extends ConsumerStatefulWidget {
  const _AddLoanSheet();

  @override
  ConsumerState<_AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends ConsumerState<_AddLoanSheet> {
  final _name = TextEditingController();
  final _lender = TextEditingController();
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _years = TextEditingController();
  final _emiDay = TextEditingController();
  LoanType _type = LoanType.home;

  @override
  void initState() {
    super.initState();
    for (final controller in [_principal, _rate, _years]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _lender.dispose();
    _principal.dispose();
    _rate.dispose();
    _years.dispose();
    _emiDay.dispose();
    super.dispose();
  }

  double get _previewEmi {
    final p = double.tryParse(_principal.text) ?? 0;
    final r = double.tryParse(_rate.text) ?? 0;
    final y = int.tryParse(_years.text) ?? 0;
    return FinanceCalculator.emiFor(p, r, y * 12);
  }

  Future<void> _add() async {
    final principal = double.tryParse(_principal.text) ?? 0;
    final years = int.tryParse(_years.text) ?? 0;
    if (principal <= 0 || years <= 0) {
      ref.read(toastProvider.notifier).show('Fill amount and years');
      return;
    }
    await ref
        .read(loanRepositoryProvider)
        .addLoan(
          name: _name.text.trim().isEmpty ? 'Loan' : _name.text.trim(),
          lender: _lender.text.trim(),
          type: _type,
          principal: principal,
          rate: double.tryParse(_rate.text) ?? 0,
          years: years,
          emiDay: int.tryParse(_emiDay.text) ?? 5,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Loan added');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('New loan'),
        const SizedBox(height: 12),
        _LoanField(controller: _name, hint: 'Name (e.g. Home loan)'),
        Row(
          children: [
            Expanded(
              child: _LoanField(controller: _lender, hint: 'Lender'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppSelect<LoanType>(
                value: _type,
                options: [
                  for (final type in LoanType.values)
                    AppSelectOption(type, type.label),
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? LoanType.other),
              ),
            ),
          ],
        ),
        _LoanField(
          controller: _principal,
          hint: 'Outstanding principal',
          number: true,
        ),
        Row(
          children: [
            Expanded(
              child: _LoanField(
                controller: _rate,
                hint: 'Rate % p.a.',
                number: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LoanField(
                controller: _years,
                hint: 'Years left',
                number: true,
              ),
            ),
          ],
        ),
        _LoanField(controller: _emiDay, hint: 'EMI day of month', number: true),
        Text(
          'EMI ${rupee(_previewEmi)} /mo',
          style: AppTypography.serif(size: 34, color: c.tx),
        ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Add loan', onTap: _add),
      ],
    );
  }
}

Future<void> showEditLoanSheet(BuildContext context, String loanId) {
  return showAppSheet<void>(context, (_) => _EditLoanSheet(loanId: loanId));
}

class _EditLoanSheet extends ConsumerStatefulWidget {
  const _EditLoanSheet({required this.loanId});

  final String loanId;

  @override
  ConsumerState<_EditLoanSheet> createState() => _EditLoanSheetState();
}

class _EditLoanSheetState extends ConsumerState<_EditLoanSheet> {
  late final TextEditingController _name;
  late final TextEditingController _lender;
  late final TextEditingController _outstanding;
  late final TextEditingController _original;
  late final TextEditingController _rate;
  late final TextEditingController _emi;
  late final TextEditingController _emiDay;
  late LoanType _type;

  @override
  void initState() {
    super.initState();
    final loan = ref.read(financeSnapshotProvider).loanById(widget.loanId);
    _name = TextEditingController(text: loan?.name ?? '');
    _lender = TextEditingController(text: loan?.lender ?? '');
    _outstanding = TextEditingController(
      text: loan?.outstanding.round().toString() ?? '',
    );
    _original = TextEditingController(
      text: loan?.original.round().toString() ?? '',
    );
    _rate = TextEditingController(text: loan?.rate.toString() ?? '');
    _emi = TextEditingController(text: loan?.emi.round().toString() ?? '');
    _emiDay = TextEditingController(text: loan?.emiDay.toString() ?? '');
    _type = loan?.type ?? LoanType.other;
  }

  @override
  void dispose() {
    _name.dispose();
    _lender.dispose();
    _outstanding.dispose();
    _original.dispose();
    _rate.dispose();
    _emi.dispose();
    _emiDay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final loan = ref.read(financeSnapshotProvider).loanById(widget.loanId);
    if (loan == null) return;
    final updated = loan.copyWith(
      name: _name.text.trim().isEmpty ? loan.name : _name.text.trim(),
      lender: _lender.text.trim(),
      type: _type,
      outstanding: double.tryParse(_outstanding.text) ?? loan.outstanding,
      rate: double.tryParse(_rate.text) ?? loan.rate,
      emi: double.tryParse(_emi.text) ?? loan.emi,
      emiDay: (int.tryParse(_emiDay.text) ?? loan.emiDay).clamp(1, 28),
    );
    await ref.read(loanRepositoryProvider).updateLoan(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Loan updated');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Edit loan'),
        const SizedBox(height: 12),
        _LoanField(controller: _name, hint: 'Name'),
        Row(
          children: [
            Expanded(
              child: _LoanField(controller: _lender, hint: 'Lender'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppSelect<LoanType>(
                value: _type,
                options: [
                  for (final type in LoanType.values)
                    AppSelectOption(type, type.label),
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? LoanType.other),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _LoanField(
                controller: _outstanding,
                hint: 'Outstanding',
                number: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LoanField(
                controller: _original,
                hint: 'Original principal',
                number: true,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _LoanField(
                controller: _rate,
                hint: 'Rate % p.a.',
                number: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LoanField(controller: _emi, hint: 'EMI', number: true),
            ),
          ],
        ),
        _LoanField(controller: _emiDay, hint: 'EMI day of month', number: true),
        PrimaryButton(label: 'Save changes', onTap: _save),
      ],
    );
  }
}

class _LoanField extends StatelessWidget {
  const _LoanField({
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
