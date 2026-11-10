import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class BackupDoc {
  const BackupDoc({required this.id, required this.data, this.groupId});

  final String id;
  final String? groupId;
  final Map<String, dynamic> data;
}

class NormalizedBackup {
  const NormalizedBackup({
    required this.transactions,
    required this.accounts,
    required this.budgets,
    required this.goals,
    required this.loans,
    required this.recurring,
    required this.shortcuts,
    required this.pending,
    required this.participants,
    required this.groups,
    required this.expenses,
    required this.settlements,
    required this.totalBudget,
    required this.totalBudgetPresent,
    required this.hasBillSplitting,
    this.userDoc,
    this.webSettings,
    this.appSettings,
    this.categories,
  });

  final List<BackupDoc>? transactions;
  final List<BackupDoc>? accounts;
  final List<BackupDoc>? budgets;
  final List<BackupDoc>? goals;
  final List<BackupDoc>? loans;
  final List<BackupDoc>? recurring;
  final List<BackupDoc>? shortcuts;
  final List<BackupDoc>? pending;
  final List<BackupDoc> participants;
  final List<BackupDoc> groups;
  final List<BackupDoc> expenses;
  final List<BackupDoc> settlements;
  final BackupDoc? totalBudget;
  final bool totalBudgetPresent;
  final bool hasBillSplitting;
  final Map<String, dynamic>? userDoc;
  final Map<String, dynamic>? webSettings;
  final Map<String, dynamic>? appSettings;
  final List<String>? categories;
}

Map<String, dynamic>? _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<BackupDoc> _docs(dynamic raw) {
  if (raw is! List) return const [];
  final result = <BackupDoc>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final data = Map<String, dynamic>.from(item);
    final id = (data.remove('id') ?? '').toString();
    result.add(BackupDoc(id: id, data: data));
  }
  return result;
}

List<BackupDoc>? _docsOrNull(dynamic raw) {
  if (raw is! List) return null;
  return _docs(raw);
}

List<BackupDoc> _flatDocs(dynamic raw) {
  if (raw is! List) return const [];
  final result = <BackupDoc>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final groupId = map['groupId']?.toString();
    final docId = (map['docId'] ?? map['id'] ?? '').toString();
    final data = _asMap(map['data']) ?? <String, dynamic>{};
    result.add(BackupDoc(id: docId, groupId: groupId, data: data));
  }
  return result;
}

class _Splits {
  const _Splits({
    required this.has,
    required this.participants,
    required this.groups,
    required this.expenses,
    required this.settlements,
  });

  final bool has;
  final List<BackupDoc> participants;
  final List<BackupDoc> groups;
  final List<BackupDoc> expenses;
  final List<BackupDoc> settlements;
}

_Splits _parseSplits(dynamic raw) {
  if (raw is! Map) {
    return const _Splits(
      has: false,
      participants: [],
      groups: [],
      expenses: [],
      settlements: [],
    );
  }
  final splits = Map<String, dynamic>.from(raw);
  final participants = _docs(splits['participants']);
  final groups = _docs(splits['groups']);
  final expenses = _flatDocs(splits['expenses']);
  final settlements = _flatDocs(
    splits['settledPayments'] ?? splits['settlements'],
  );

  for (final group in groups) {
    final nestedExpenses = group.data.remove('expenses');
    if (nestedExpenses is List) {
      for (final item in nestedExpenses) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final id = (data.remove('id') ?? '').toString();
        expenses.add(BackupDoc(id: id, groupId: group.id, data: data));
      }
    }
    final nestedSettlements = group.data.remove('settledPayments');
    if (nestedSettlements is List) {
      for (final item in nestedSettlements) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final id = (data.remove('id') ?? '').toString();
        settlements.add(BackupDoc(id: id, groupId: group.id, data: data));
      }
    }
  }

  return _Splits(
    has: true,
    participants: participants,
    groups: groups,
    expenses: expenses,
    settlements: settlements,
  );
}

BackupDoc? _totalBudgetDoc(dynamic raw) {
  Map<String, dynamic>? data;
  if (raw is Map) {
    data = Map<String, dynamic>.from(raw);
  } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
    data = Map<String, dynamic>.from(raw.first as Map);
  }
  if (data == null) return null;
  data.remove('id');
  if (data.isEmpty) return null;
  return BackupDoc(id: 'current', data: data);
}

dynamic pick(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (source.containsKey(key)) return source[key];
  }
  return null;
}

NormalizedBackup normalizeBackupPayload(Map<String, dynamic> payload) {
  final entities = _asMap(payload['entities']);
  final finance = _asMap(payload['finance']);

  late Map<String, dynamic> source;
  late bool totalBudgetPresent;

  if (entities != null) {
    source = {
      'transactions': entities['transactions'],
      'accounts': entities['accounts'],
      'budgets': entities['budgets'],
      'goals': entities['goals'],
      'loans': entities['loans'],
      'recurringTransactions': entities['recurringTransactions'],
      'shortcuts': entities['shortcuts'],
      'pendingTransactions': entities['pendingTransactions'],
      'billSplitting': entities['billSplitting'],
      'totalBudget': entities['totalBudget'],
    };
    totalBudgetPresent = entities.containsKey('totalBudget');
  } else if (finance != null) {
    source = finance;
    totalBudgetPresent = finance.containsKey('totalBudget');
  } else {
    source = {
      'transactions': payload['transactions'],
      'accounts': payload['accounts'],
      'budgets': payload['budgets'],
      'goals': payload['goals'],
      'loans': payload['loans'],
      'recurringTransactions':
          payload['recurringTransactions'] ?? payload['recurring_transactions'],
      'shortcuts': payload['shortcuts'],
      'pendingTransactions':
          payload['pendingTransactions'] ?? payload['pending_transactions'],
      'billSplitting': payload['billSplitting'],
      'totalBudget': payload['totalBudget'],
    };
    totalBudgetPresent = payload.containsKey('totalBudget');
  }

  final splits = _parseSplits(source['billSplitting']);

  final settingsRaw = _asMap(payload['settings']);
  Map<String, dynamic>? userDoc;
  Map<String, dynamic>? webSettings;
  Map<String, dynamic>? appSettings;
  if (settingsRaw != null) {
    if (settingsRaw['userDoc'] is Map) {
      userDoc = _asMap(settingsRaw['userDoc']);
    } else if (settingsRaw.containsKey('darkMode') ||
        settingsRaw.containsKey('currency')) {
      webSettings = settingsRaw;
    } else if (settingsRaw.isNotEmpty) {
      appSettings = settingsRaw;
    }
  }
  if (payload['mobileSettings'] is Map) {
    appSettings = _asMap(payload['mobileSettings']);
  }

  List<String>? categories;
  final rawCategories = payload['userCategories'];
  if (rawCategories is List) {
    categories = rawCategories.map((value) => '$value').toList();
  } else if (userDoc?['categories'] is List) {
    categories = (userDoc!['categories'] as List)
        .map((value) => '$value')
        .toList();
  }

  return NormalizedBackup(
    transactions: _docsOrNull(pick(source, ['transactions'])),
    accounts: _docsOrNull(pick(source, ['accounts'])),
    budgets: _docsOrNull(pick(source, ['budgets'])),
    goals: _docsOrNull(pick(source, ['goals'])),
    loans: _docsOrNull(pick(source, ['loans'])),
    recurring: _docsOrNull(
      pick(source, ['recurring', 'recurringTransactions', 'recurring_transactions']),
    ),
    shortcuts: _docsOrNull(pick(source, ['shortcuts'])),
    pending: _docsOrNull(
      pick(source, ['pending', 'pendingTransactions', 'pending_transactions']),
    ),
    participants: splits.participants,
    groups: splits.groups,
    expenses: splits.expenses,
    settlements: splits.settlements,
    totalBudget: _totalBudgetDoc(pick(source, ['totalBudget'])),
    totalBudgetPresent: totalBudgetPresent,
    hasBillSplitting: splits.has,
    userDoc: userDoc,
    webSettings: webSettings,
    appSettings: appSettings,
    categories: categories,
  );
}

/// Converts Firestore Timestamps and DateTimes into ISO strings so a backup is
/// plain JSON, matching the web's `normalize()` behavior.
dynamic jsonSafe(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toUtc().toIso8601String();
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is List) {
    return value.map(jsonSafe).toList();
  }
  if (value is Map) {
    final result = <String, dynamic>{};
    value.forEach((key, item) => result['$key'] = jsonSafe(item));
    return result;
  }
  return value;
}
