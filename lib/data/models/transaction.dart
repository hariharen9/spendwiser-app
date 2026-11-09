import 'package:flutter/foundation.dart';

import '../../../core/utils/date_helpers.dart';

@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.merchant,
    required this.category,
    required this.amount,
    required this.date,
    this.accountId,
    this.cardId,
    this.note = '',
    this.tags = const <String>[],
    this.hasReceipt = false,
  });

  final String id;
  final String merchant;

  /// Food / Travel / Bills / Shop / Income / Fun / EMI / Transfer
  final String category;

  /// Negative = money out, positive = money in.
  final double amount;
  final DateTime date;
  final String? accountId;
  final String? cardId;
  final String note;
  final List<String> tags;
  final bool hasReceipt;

  bool get isIncome => amount > 0;
  bool get isExpense => amount < 0;

  String get dateLabel => dayLabel(date);

  String get subtitle {
    final parts = <String>[category];
    if (tags.isNotEmpty) parts.addAll(tags.map((t) => '#$t'));
    if (hasReceipt) parts.add('receipt');
    return parts.join(' · ');
  }

  Transaction copyWith({
    String? id,
    String? merchant,
    String? category,
    double? amount,
    DateTime? date,
    String? accountId,
    String? cardId,
    String? note,
    List<String>? tags,
    bool? hasReceipt,
    bool clearAccount = false,
    bool clearCard = false,
  }) {
    return Transaction(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      cardId: clearCard ? null : (cardId ?? this.cardId),
      note: note ?? this.note,
      tags: tags ?? this.tags,
      hasReceipt: hasReceipt ?? this.hasReceipt,
    );
  }
}

@immutable
class TransactionDraft {
  const TransactionDraft({
    required this.merchant,
    required this.category,
    required this.amount,
    required this.date,
    this.accountId,
    this.cardId,
    this.note = '',
    this.tags = const <String>[],
  });

  final String merchant;
  final String category;
  final double amount;
  final DateTime date;
  final String? accountId;
  final String? cardId;
  final String note;
  final List<String> tags;
}

@immutable
class MonthFlow {
  const MonthFlow({required this.income, required this.expense});

  final double income;
  final double expense;

  double get saved => income - expense;
  double get savingsRate => income == 0 ? 0 : (income - expense) / income * 100;
}
