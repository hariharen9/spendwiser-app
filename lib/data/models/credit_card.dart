import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum StatementStatus {
  paid('Paid'),
  due('Due'),
  overdue('Overdue'),
  nil('No spends');

  const StatementStatus(this.label);
  final String label;

  Color color(SpendColors c) => switch (this) {
    StatementStatus.paid => c.ac,
    StatementStatus.due => const Color(0xFFFFD23F),
    StatementStatus.overdue => c.co,
    StatementStatus.nil => c.mu,
  };
}

@immutable
class CardStatement {
  const CardStatement({
    required this.index,
    required this.start,
    required this.end,
    required this.dueDate,
    required this.amount,
    required this.paid,
    required this.remaining,
    required this.status,
  });

  final int index;
  final DateTime start;
  final DateTime end;
  final DateTime dueDate;
  final double amount;
  final double paid;
  final double remaining;
  final StatementStatus status;

  double get paidRatio => amount <= 0 ? 0 : (paid / amount).clamp(0, 1);
}

@immutable
class CardCycle {
  const CardCycle({
    required this.start,
    required this.end,
    required this.amount,
    required this.daysLeft,
  });

  final DateTime start;
  final DateTime end;
  final double amount;
  final int daysLeft;
}

@immutable
class CardPayment {
  const CardPayment({
    required this.date,
    required this.amount,
    required this.accountId,
    this.statementEnd,
  });

  final DateTime date;
  final double amount;
  final String accountId;
  final DateTime? statementEnd;
}

@immutable
class CardDue {
  const CardDue({
    required this.amount,
    required this.days,
    required this.status,
    required this.dueDate,
  });

  final double amount;
  final int days;
  final StatementStatus status;
  final DateTime dueDate;
}

class CreditCard {
  CreditCard({
    required this.id,
    required this.name,
    required this.gradient,
    required this.last4,
    required this.limit,
    required this.statementDay,
    required this.dueDay,
    this.outstanding = 0,
    this.minimumDue = 0,
    this.rewardPoints = 0,
    this.onlinePayments = true,
    this.international = false,
    this.tapToPay = true,
    this.frozen = false,
    this.payments = const <CardPayment>[],
    this.statements = const <CardStatement>[],
    this.openCycle,
    this.due,
    this.dueLabel = '—',
    this.cycleLeftDays = 0,
  });

  final String id;
  final String name;
  final List<Color> gradient;
  final String last4;
  final double limit;
  final int statementDay;
  final int dueDay;

  double outstanding;
  double minimumDue;
  int rewardPoints;
  bool onlinePayments;
  bool international;
  bool tapToPay;
  bool frozen;
  List<CardPayment> payments;
  List<CardStatement> statements;
  CardCycle? openCycle;
  CardDue? due;
  String dueLabel;
  int cycleLeftDays;

  double get available => (limit - outstanding).clamp(0, limit);
  double get utilisation =>
      limit <= 0 ? 0 : (outstanding / limit * 100).clamp(0, 100);
  bool get hasDue => due != null && due!.amount > 0;

  String get firstName => name.split(' ').first;

  CreditCard copyWith({
    String? name,
    String? last4,
    double? limit,
    int? statementDay,
    int? dueDay,
    double? outstanding,
    double? minimumDue,
    int? rewardPoints,
    bool? onlinePayments,
    bool? international,
    bool? tapToPay,
    bool? frozen,
    List<CardPayment>? payments,
    List<CardStatement>? statements,
    CardCycle? openCycle,
    CardDue? due,
    String? dueLabel,
    int? cycleLeftDays,
  }) {
    return CreditCard(
      id: id,
      name: name ?? this.name,
      gradient: gradient,
      last4: last4 ?? this.last4,
      limit: limit ?? this.limit,
      statementDay: statementDay ?? this.statementDay,
      dueDay: dueDay ?? this.dueDay,
      outstanding: outstanding ?? this.outstanding,
      minimumDue: minimumDue ?? this.minimumDue,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      onlinePayments: onlinePayments ?? this.onlinePayments,
      international: international ?? this.international,
      tapToPay: tapToPay ?? this.tapToPay,
      frozen: frozen ?? this.frozen,
      payments: payments ?? this.payments,
      statements: statements ?? this.statements,
      openCycle: openCycle ?? this.openCycle,
      due: due ?? this.due,
      dueLabel: dueLabel ?? this.dueLabel,
      cycleLeftDays: cycleLeftDays ?? this.cycleLeftDays,
    );
  }

  static const iciciGradient = [Color(0xFF7A3B12), Color(0xFF1A0D05)];
  static const axisGradient = [Color(0xFF5B1D4A), Color(0xFF14060F)];
  static const newCardGradient = [Color(0xFF0F3D3A), Color(0xFF05100F)];

  static CreditCard seededIcici() => CreditCard(
    id: 'card-icici',
    name: 'ICICI Amazon Pay',
    gradient: iciciGradient,
    last4: '7702',
    limit: 80000,
    statementDay: 22,
    dueDay: 12,
  );

  static CreditCard seededAxis() => CreditCard(
    id: 'card-axis',
    name: 'Axis Neo',
    gradient: axisGradient,
    last4: '1190',
    limit: 40000,
    statementDay: 5,
    dueDay: 23,
    international: true,
  );
}
