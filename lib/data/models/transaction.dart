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
    this.addedAt,
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

  /// When this entry was created in Spendwiser.
  ///
  /// Older/web records may not have this; [date] remains the transaction date.
  final DateTime? addedAt;
  final String? accountId;
  final String? cardId;
  final String note;
  final List<String> tags;
  final bool hasReceipt;

  bool get isIncome => amount > 0;
  bool get isExpense => amount < 0;

  String get dateLabel => dayLabel(date);

  String? get addedTimeLabel => addedAt == null ? null : clockTime(addedAt!);

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
    DateTime? addedAt,
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
      addedAt: addedAt ?? this.addedAt,
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      cardId: clearCard ? null : (cardId ?? this.cardId),
      note: note ?? this.note,
      tags: tags ?? this.tags,
      hasReceipt: hasReceipt ?? this.hasReceipt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant': merchant,
    'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
    'addedAt': addedAt?.toIso8601String(),
    'accountId': accountId,
    'cardId': cardId,
    'note': note,
    'tags': tags,
    'hasReceipt': hasReceipt,
  };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: j['id'] as String,
    merchant: j['merchant'] as String,
    category: j['category'] as String,
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date'] as String),
    addedAt: j['addedAt'] == null
        ? null
        : DateTime.tryParse('${j['addedAt']}')?.toLocal(),
    accountId: j['accountId'] as String?,
    cardId: j['cardId'] as String?,
    note: j['note'] as String? ?? '',
    tags: ((j['tags'] as List?) ?? []).map((e) => e as String).toList(),
    hasReceipt: j['hasReceipt'] as bool? ?? false,
  );
}

@immutable
class TransactionDraft {
  const TransactionDraft({
    required this.merchant,
    required this.category,
    required this.amount,
    required this.date,
    this.addedAt,
    this.accountId,
    this.cardId,
    this.note = '',
    this.tags = const <String>[],
  });

  final String merchant;
  final String category;
  final double amount;
  final DateTime date;
  final DateTime? addedAt;
  final String? accountId;
  final String? cardId;
  final String note;
  final List<String> tags;
}

/// Newest transaction day first; within a day, newest app-added entry first.
///
/// Records without [Transaction.addedAt] (web/legacy) keep working and fall
/// back to their stored date/time.
int compareTransactionsNewestFirst(Transaction a, Transaction b) {
  final dayOrder = dateOnly(b.date).compareTo(dateOnly(a.date));
  if (dayOrder != 0) return dayOrder;

  final aAdded = a.addedAt;
  final bAdded = b.addedAt;
  if (aAdded != null && bAdded != null) {
    final addedOrder = bAdded.compareTo(aAdded);
    if (addedOrder != 0) return addedOrder;
  } else if (aAdded != null) {
    return -1;
  } else if (bAdded != null) {
    return 1;
  }

  final timeOrder = b.date.compareTo(a.date);
  if (timeOrder != 0) return timeOrder;
  return b.id.compareTo(a.id);
}

int compareTransactionsOldestFirst(Transaction a, Transaction b) =>
    compareTransactionsNewestFirst(b, a);

@immutable
class MonthFlow {
  const MonthFlow({required this.income, required this.expense});

  final double income;
  final double expense;

  double get saved => income - expense;
  double get savingsRate => income == 0 ? 0 : (income - expense) / income * 100;
}
