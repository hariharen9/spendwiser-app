import 'package:flutter/material.dart';

enum LoanType {
  home('Home loan', Color(0xFF4DABF7)),
  car('Car loan', Color(0xFFFF9F43)),
  personal('Personal loan', Color(0xFFFF6B9D)),
  education('Education loan', Color(0xFFC084FC)),
  other('Other', Color(0xFF8B8883));

  const LoanType(this.label, this.color);
  final String label;
  final Color color;

  static LoanType fromLabel(String label) => LoanType.values.firstWhere(
    (t) => t.label.toLowerCase() == label.toLowerCase(),
    orElse: () => LoanType.other,
  );
}

enum LoanPaymentType { emi, prepayment }

@immutable
class LoanPayment {
  const LoanPayment({
    required this.date,
    required this.amount,
    required this.type,
    required this.interest,
    required this.principal,
  });

  final DateTime date;
  final double amount;
  final LoanPaymentType type;
  final double interest;
  final double principal;
}

@immutable
class LoanDue {
  const LoanDue({
    required this.date,
    required this.days,
    required this.overdue,
  });

  final DateTime date;
  final int days;
  final bool overdue;
}

class Loan {
  Loan({
    required this.id,
    required this.name,
    required this.lender,
    required this.type,
    required this.outstanding,
    required this.original,
    required this.rate,
    required this.emi,
    required this.emiDay,
    required this.tenureMonths,
    required this.startDate,
    this.payments = const <LoanPayment>[],
  });

  final String id;
  final String name;
  final String lender;
  final LoanType type;
  double outstanding;
  final double original;
  double rate;
  double emi;
  int emiDay;
  int? tenureMonths;
  final DateTime startDate;
  List<LoanPayment> payments;

  double get repaidRatio =>
      original <= 0 ? 0 : (1 - outstanding / original).clamp(0, 1);

  Loan copyWith({
    String? name,
    String? lender,
    LoanType? type,
    double? outstanding,
    double? rate,
    double? emi,
    int? emiDay,
    int? tenureMonths,
    List<LoanPayment>? payments,
  }) {
    return Loan(
      id: id,
      name: name ?? this.name,
      lender: lender ?? this.lender,
      type: type ?? this.type,
      outstanding: outstanding ?? this.outstanding,
      original: original,
      rate: rate ?? this.rate,
      emi: emi ?? this.emi,
      emiDay: emiDay ?? this.emiDay,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      startDate: startDate,
      payments: payments ?? this.payments,
    );
  }
}

@immutable
class AmortizationEntry {
  const AmortizationEntry({
    required this.month,
    required this.date,
    required this.interest,
    required this.principal,
    required this.balance,
  });

  final int month;
  final DateTime date;
  final double interest;
  final double principal;
  final double balance;
}

@immutable
class AmortizationResult {
  const AmortizationResult({
    required this.months,
    required this.interest,
    required this.entries,
  });

  final int months;
  final double interest;
  final List<AmortizationEntry> entries;

  int get years => months ~/ 12;

  double get totalPaid =>
      entries.fold(0, (sum, e) => sum + e.interest + e.principal);
}
