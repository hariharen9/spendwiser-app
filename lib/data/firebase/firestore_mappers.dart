import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/credit_card.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/shortcut.dart';
import '../models/split_group.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../services/finance_calculator.dart';
import 'firestore_utils.dart';

const cardGradients = <List<Color>>[
  CreditCard.iciciGradient,
  CreditCard.axisGradient,
  CreditCard.newCardGradient,
  [Color(0xFF1D3A6B), Color(0xFF0B1530)],
];

List<Color> gradientFor(String id) {
  final hash = id.codeUnits.fold<int>(0, (total, code) => total + code);
  return cardGradients[hash % cardGradients.length];
}

AccountType accountTypeFromRemote(String remoteType) => switch (remoteType) {
  'Investment' => AccountType.investments,
  'Cash' || 'Wallet' => AccountType.cash,
  _ => AccountType.savings,
};

String remoteAccountType(String? remoteType, AccountType type) {
  if (remoteType != null && remoteType.isNotEmpty) return remoteType;
  return switch (type) {
    AccountType.savings => 'Bank',
    AccountType.investments => 'Investment',
    AccountType.cash => 'Cash',
  };
}

bool isCreditCardDoc(Map<String, dynamic> data) =>
    asString(data['type']) == 'Credit Card';

Transaction transactionFromDoc(
  String id,
  Map<String, dynamic> data, {
  required Set<String> cardIds,
  required Map<String, String> tagIdToName,
}) {
  final rawAccountId = asString(data['accountId']);
  final isCard = rawAccountId.isNotEmpty && cardIds.contains(rawAccountId);
  final rawTags = (data['tags'] as List?) ?? const <dynamic>[];
  final tags = rawTags
      .map((tag) => tagIdToName[asString(tag)] ?? asString(tag))
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
  final category = asString(data['category'], 'Other');
  final name = asString(data['name']);
  return Transaction(
    id: id,
    merchant: name.isEmpty ? category : name,
    category: category,
    amount: asDouble(data['amount']),
    date: parseFirestoreDate(data['date']) ?? DateTime.now(),
    addedAt: parseFirestoreDate(data['createdAt']),
    accountId: isCard ? null : (rawAccountId.isEmpty ? null : rawAccountId),
    cardId: isCard ? rawAccountId : null,
    note: asString(data['comments']),
    tags: tags,
    hasReceipt: asBool(data['hasReceipt']),
  );
}

Map<String, dynamic> transactionCreatePayload(
  TransactionDraft draft, {
  required Map<String, String> tagNameToId,
}) {
  final accountId = draft.cardId ?? draft.accountId;
  return {
    'name': draft.merchant,
    'amount': draft.amount,
    'date': firestoreDate(draft.date),
    'category': draft.category,
    'type': draft.amount >= 0 ? 'income' : 'expense',
    if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
    if (draft.note.isNotEmpty) 'comments': draft.note,
    'tags': draft.tags.map((tag) => tagNameToId[tag] ?? tag).toList(),
    'createdAt': draft.addedAt?.toUtc().toIso8601String() ?? nowIso(),
    'isMock': false,
  };
}

Map<String, dynamic> transactionUpdatePayload(
  Transaction transaction, {
  required Map<String, String> tagNameToId,
}) {
  final accountId = transaction.cardId ?? transaction.accountId;
  return {
    'name': transaction.merchant,
    'amount': transaction.amount,
    'date': firestoreDate(transaction.date),
    'category': transaction.category,
    'type': transaction.amount >= 0 ? 'income' : 'expense',
    'accountId': accountId == null || accountId.isEmpty
        ? FieldValue.delete()
        : accountId,
    'comments': transaction.note.isEmpty
        ? FieldValue.delete()
        : transaction.note,
    'tags': transaction.tags.map((tag) => tagNameToId[tag] ?? tag).toList(),
    'hasReceipt': transaction.hasReceipt,
  };
}

Account accountFromDoc(
  String id,
  Map<String, dynamic> data, {
  required double liveBalance,
}) {
  final remoteType = asString(data['type'], 'Bank');
  return Account(
    id: id,
    name: asString(data['name'], 'Account'),
    type: accountTypeFromRemote(remoteType),
    balance: liveBalance,
    last4: asString(data['last4Digits']).isEmpty
        ? null
        : asString(data['last4Digits']),
    remoteType: remoteType,
    gradient: gradientFor(id),
  );
}

CreditCard creditCardFromDoc(
  String id,
  Map<String, dynamic> data, {
  required List<Map<String, dynamic>> paymentDocs,
  required DateTime now,
}) {
  final payments =
      paymentDocs
          .map(
            (payment) => CardPayment(
              date: parseFirestoreDate(payment['date']) ?? now,
              amount: asDouble(payment['amount']).abs(),
              accountId: asString(payment['accountId']),
            ),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  return CreditCard(
    id: id,
    name: asString(data['name'], 'Card'),
    gradient: gradientFor(id),
    last4: asString(data['last4Digits']),
    limit: asDouble(data['limit']),
    statementDay: asInt(data['statementDate'], 1).clamp(1, 31),
    dueDay: asInt(data['paymentDueDate'], 1).clamp(1, 31),
    payments: payments,
  );
}

Budget budgetFromDoc(
  String id,
  Map<String, dynamic> data, {
  required double spent,
  bool rollover = false,
  int alertAt = 80,
}) => Budget(
  category: asString(data['category'], 'Other'),
  limit: asDouble(data['limit']),
  spent: spent,
  rollover: rollover,
  alertAt: alertAt,
);

Goal goalFromDoc(
  String id,
  Map<String, dynamic> data, {
  required Color fallbackColor,
}) => Goal(
  id: id,
  name: asString(data['name'], 'Goal'),
  target: asDouble(data['targetAmount']),
  saved: asDouble(data['currentAmount']),
  monthlyContribution: asDouble(data['mobileMonthlyContribution']),
  color: fallbackColor,
  targetDate: parseFirestoreDate(data['targetDate']),
  emoji: asString(data['emoji'], '🎯'),
);

LoanType loanTypeFromRemote(String raw) => switch (raw) {
  'home' => LoanType.home,
  'auto' => LoanType.car,
  'personal' => LoanType.personal,
  'student' => LoanType.education,
  _ => LoanType.other,
};

String remoteLoanType(LoanType type) => switch (type) {
  LoanType.home => 'home',
  LoanType.car => 'auto',
  LoanType.personal => 'personal',
  LoanType.education => 'student',
  LoanType.other => 'other',
};

Loan loanFromDoc(
  String id,
  Map<String, dynamic> data, {
  required List<Map<String, dynamic>> paymentDocs,
  required DateTime now,
}) {
  final original = asDouble(data['loanAmount']);
  final rate = asDouble(data['interestRate']);
  final monthsFromDoc = asInt(data['tenureInMonths']);
  final years = asInt(data['tenure']);
  final months = monthsFromDoc > 0 ? monthsFromDoc : years * 12;
  final start = parseFirestoreDate(data['startDate']) ?? now;
  final emi = asDouble(data['emi']) > 0
      ? asDouble(data['emi'])
      : FinanceCalculator.emiFor(original, rate, months);

  final sortedPayments = List<Map<String, dynamic>>.from(paymentDocs)
    ..sort(
      (a, b) => (parseFirestoreDate(a['date']) ?? now).compareTo(
        parseFirestoreDate(b['date']) ?? now,
      ),
    );

  final schedule = months > 0
      ? FinanceCalculator.amortize(
          balance: original,
          annualRate: rate,
          emi: emi,
          firstDue: start,
        )
      : null;

  double outstanding = original;
  if (sortedPayments.isNotEmpty) {
    if (schedule == null || schedule.entries.isEmpty) {
      outstanding = 0;
    } else if (sortedPayments.length >= schedule.entries.length) {
      outstanding = 0;
    } else {
      outstanding = schedule.entries[sortedPayments.length - 1].balance;
    }
  }

  final payments = <LoanPayment>[];
  for (var i = 0; i < sortedPayments.length; i++) {
    final doc = sortedPayments[i];
    final amount = asDouble(doc['amount']).abs();
    final entry = schedule != null && i < schedule.entries.length
        ? schedule.entries[i]
        : null;
    payments.add(
      LoanPayment(
        date: parseFirestoreDate(doc['date']) ?? now,
        amount: amount,
        type: LoanPaymentType.emi,
        interest: entry?.interest ?? 0,
        principal: entry?.principal ?? amount,
      ),
    );
  }

  return Loan(
    id: id,
    name: asString(data['name'], 'Loan'),
    lender: '',
    type: loanTypeFromRemote(asString(data['type'])),
    outstanding: outstanding,
    original: original,
    rate: rate,
    emi: emi,
    emiDay: start.day,
    tenureMonths: months > 0 ? months : null,
    startDate: start,
    payments: payments,
  );
}

RecurringTransaction recurringFromDoc(String id, Map<String, dynamic> data) {
  final frequency = RecurringFrequency.fromLabel(
    asString(data['frequency'], 'monthly'),
  );
  final type = asString(data['type'], 'expense');
  return RecurringTransaction(
    id: id,
    name: asString(data['name'], 'Recurring'),
    amount: asDouble(data['amount']),
    frequency: frequency,
    isIncome: type == 'income',
    category: asString(data['category'], 'Other'),
    startDate: parseFirestoreDate(data['startDate']),
    endDate: parseFirestoreDate(data['endDate']),
    lastProcessedDate: parseFirestoreDate(data['lastProcessedDate']),
    accountId: asString(data['accountId']).isEmpty
        ? null
        : asString(data['accountId']),
    note: asString(data['note']).isEmpty ? null : asString(data['note']),
    active: !asBool(data['isPaused']),
  );
}

Subscription? subscriptionFromRecurring(
  RecurringTransaction recurring, {
  required DateTime now,
}) {
  if (recurring.isIncome || !recurring.active) return null;
  if (recurring.frequency != RecurringFrequency.monthly &&
      recurring.frequency != RecurringFrequency.yearly) {
    return null;
  }
  var next = addFrequency(
    recurring.lastProcessedDate ??
        recurring.startDate ??
        calendarDate(now).subtract(const Duration(days: 1)),
    recurring.frequency.label,
  );
  var guard = 0;
  while (next.isBefore(calendarDate(now)) && guard < 120) {
    next = addFrequency(next, recurring.frequency.label);
    guard++;
  }
  return Subscription(
    id: recurring.id,
    name: recurring.name,
    price: recurring.amount.abs(),
    renewsInDays: next.difference(calendarDate(now)).inDays.clamp(0, 3650),
    active: recurring.active,
    note: recurring.note,
    category: recurring.category,
    recurringId: recurring.id,
  );
}

SplitType splitTypeFromRemote(String raw) => switch (raw) {
  'unequal' => SplitType.exact,
  'percentage' => SplitType.percent,
  _ => SplitType.equal,
};

String remoteSplitType(SplitType type) => switch (type) {
  SplitType.exact => 'unequal',
  SplitType.percent => 'percentage',
  SplitType.equal => 'equal',
};

String splitParticipantName(String id, Map<String, String> participantNames) {
  if (id.isEmpty) return 'Member';
  return participantNames[id] ?? (id == '1' ? 'You' : id);
}

SplitExpense splitExpenseFromDoc(
  Map<String, dynamic> data, {
  required Map<String, String> participantNames,
}) {
  final shares = <String, double>{};
  final rawSplits = (data['splits'] as List?) ?? const <dynamic>[];
  for (final raw in rawSplits) {
    final split = asMap(raw);
    final name = splitParticipantName(
      asString(split['participantId']),
      participantNames,
    );
    shares[name] = asDouble(split['amount']);
  }
  return SplitExpense(
    description: asString(data['description'], 'Expense'),
    amount: asDouble(data['amount']),
    paidBy: splitParticipantName(asString(data['paidBy']), participantNames),
    shares: shares,
    type: splitTypeFromRemote(asString(data['splitType'], 'equal')),
    date:
        parseFirestoreDate(data['date']) ??
        parseFirestoreDate(data['createdAt']) ??
        DateTime.now(),
  );
}

class SplitHistoryEntry {
  const SplitHistoryEntry({required this.id, required this.settlement});

  final String id;
  final bool settlement;
}

class MappedSplitGroup {
  const MappedSplitGroup({required this.group, required this.history});

  final SplitGroup group;
  final List<SplitHistoryEntry> history;
}

MappedSplitGroup splitGroupFromDocs({
  required String id,
  required Map<String, dynamic> data,
  required Map<String, String> participantNames,
  required List<MapEntry<String, Map<String, dynamic>>> expenseDocs,
  required List<MapEntry<String, Map<String, dynamic>>> settledDocs,
}) {
  final members = <String>['You'];
  for (final participantId in asStringList(data['participantIds'])) {
    if (participantId == '1') continue;
    final name = splitParticipantName(participantId, participantNames);
    if (!members.contains(name)) members.add(name);
  }

  DateTime expenseDate(Map<String, dynamic> doc) =>
      parseFirestoreDate(doc['date']) ??
      parseFirestoreDate(doc['createdAt']) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final orderedExpenses =
      List<MapEntry<String, Map<String, dynamic>>>.from(expenseDocs)
        ..sort((a, b) {
          final byDate = expenseDate(a.value).compareTo(expenseDate(b.value));
          return byDate != 0 ? byDate : a.key.compareTo(b.key);
        });
  final orderedSettlements =
      List<MapEntry<String, Map<String, dynamic>>>.from(settledDocs)
        ..sort((a, b) {
          final byDate = expenseDate(a.value).compareTo(expenseDate(b.value));
          return byDate != 0 ? byDate : a.key.compareTo(b.key);
        });

  final expenses = <SplitExpense>[];
  final history = <SplitHistoryEntry>[];

  for (final entry in orderedExpenses) {
    final expense = splitExpenseFromDoc(
      entry.value,
      participantNames: participantNames,
    );
    expenses.add(expense);
    history.add(SplitHistoryEntry(id: entry.key, settlement: false));
    for (final name in [expense.paidBy, ...expense.shares.keys]) {
      if (!members.contains(name)) members.add(name);
    }
  }

  for (final entry in orderedSettlements) {
    final doc = entry.value;
    final amount = asDouble(doc['amount']);
    if (amount <= 0) continue;
    final from = splitParticipantName(asString(doc['from']), participantNames);
    final to = splitParticipantName(asString(doc['to']), participantNames);
    expenses.add(
      SplitExpense(
        description: 'Settlement',
        amount: amount,
        paidBy: from,
        shares: const {},
        type: SplitType.exact,
        date:
            parseFirestoreDate(doc['createdAt']) ??
            parseFirestoreDate(doc['date']) ??
            DateTime.now(),
        settledTo: to,
      ),
    );
    history.add(SplitHistoryEntry(id: entry.key, settlement: true));
    if (!members.contains(from)) members.add(from);
    if (!members.contains(to)) members.add(to);
  }

  return MappedSplitGroup(
    group: SplitGroup(
      id: id,
      name: asString(data['name'], 'Group'),
      members: members,
      expenses: expenses,
    ),
    history: history,
  );
}

Shortcut shortcutFromDoc(String id, Map<String, dynamic> data) => Shortcut(
  id: id,
  keyword: asString(data['keyword']),
  name: asString(data['name'], 'Shortcut'),
  amount: asDouble(data['amount']),
  category: asString(data['category'], 'Other'),
  isIncome: asString(data['type'], 'expense') == 'income',
  accountId: asString(data['accountId']).isEmpty
      ? null
      : asString(data['accountId']),
);

Color categoryColorFor(String name, int index, Map<String, Color>? overrides) {
  final custom = overrides?[name];
  if (custom != null) return custom;
  final palette = AppColors.categoryPalette;
  return palette[index % palette.length];
}
