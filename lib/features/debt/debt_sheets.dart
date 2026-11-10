import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/premium_sheet.dart';
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
  final _rate = TextEditingController(text: '9');
  final _years = TextEditingController(text: '5');
  final _emiDay = TextEditingController(text: '5');
  LoanType _type = LoanType.home;

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

  double get _principalValue => double.tryParse(_principal.text) ?? 0;
  double get _rateValue => double.tryParse(_rate.text) ?? 0;
  int get _yearsValue => int.tryParse(_years.text) ?? 0;
  int get _emiDayValue => int.tryParse(_emiDay.text) ?? 0;

  double get _previewEmi {
    final months = _yearsValue * 12;
    if (_principalValue <= 0 || months <= 0) return 0;
    return FinanceCalculator.emiFor(_principalValue, _rateValue, months);
  }

  double get _totalInterest {
    final months = _yearsValue * 12;
    if (months <= 0) return 0;
    return (_previewEmi * months - _principalValue).clamp(0, double.infinity);
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) {
      ref.read(toastProvider.notifier).show('Name the loan');
      return;
    }
    if (_principalValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter the principal');
      return;
    }
    if (_yearsValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter the tenure');
      return;
    }
    if (_emiDayValue < 1 || _emiDayValue > 28) {
      ref.read(toastProvider.notifier).show('EMI day must be 1–28');
      return;
    }
    await ref
        .read(loanRepositoryProvider)
        .addLoan(
          name: _name.text.trim(),
          lender: _lender.text.trim(),
          type: _type,
          principal: _principalValue,
          rate: _rateValue,
          years: _yearsValue,
          emiDay: _emiDayValue,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Loan added');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final months = _yearsValue * 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'debt',
          title: 'Add loan',
          subtitle: 'Set the principal, rate and payoff plan.',
        ),
        const SizedBox(height: 20),
        const PremiumLabel('Loan name', requiredField: true),
        PremiumField(
          controller: _name,
          hint: 'e.g. Home loan',
          icon: 'debt',
          capitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumLabel('Lender'),
                  PremiumField(
                    controller: _lender,
                    hint: 'HDFC Bank',
                    capitalization: TextCapitalization.words,
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
                  const PremiumLabel('EMI day'),
                  PremiumField(
                    controller: _emiDay,
                    hint: '5',
                    number: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const PremiumLabel('Loan type'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in LoanType.values)
              AppPill(
                label: type.label,
                active: _type == type,
                onTap: () => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Outstanding principal', requiredField: true),
        PremiumField(
          controller: _principal,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumLabel('Rate % p.a.'),
                  PremiumField(
                    controller: _rate,
                    hint: '9.0',
                    number: true,
                    suffix: '%',
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
                  const PremiumLabel('Years left', requiredField: true),
                  PremiumField(
                    controller: _years,
                    hint: '5',
                    number: true,
                    suffix: 'yr',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PremiumSummaryCard(
          icon: 'debt',
          eyebrow: 'Estimated EMI',
          value: '${rupee(_previewEmi)} /mo',
          caption: months <= 0
              ? 'Enter a tenure'
              : '$_yearsValue years · ${rupee(_totalInterest)} total interest',
          accent: c.ac,
        ),
        const SizedBox(height: 14),
        const PremiumNotice(
          icon: 'insights',
          text: 'The payoff plan uses the rate and tenure to estimate your monthly EMI and total interest.',
        ),
        const SizedBox(height: 18),
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
