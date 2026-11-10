import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/material.dart';

import '../../core/utils/date_helpers.dart' hide dateOnly;
import '../models/account.dart';
import '../models/credit_card.dart';
import '../models/finance_snapshot.dart';
import '../models/loan.dart';
import '../models/shortcut.dart';
import '../models/split_group.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../repositories/i_account_repository.dart';
import '../repositories/i_budget_repository.dart';
import '../repositories/i_card_repository.dart';
import '../repositories/i_finance_repository.dart';
import '../repositories/i_goal_repository.dart';
import '../repositories/i_loan_repository.dart';
import '../repositories/i_shortcut_repository.dart';
import '../repositories/i_split_repository.dart';
import '../repositories/i_subscription_repository.dart';
import '../repositories/i_transaction_repository.dart';
import '../services/finance_calculator.dart';
import 'demo_data_seeder.dart';
import 'firestore_mappers.dart';
import 'firestore_refs.dart';
import 'firestore_utils.dart';
import 'user_profile_repository.dart';

/// Firestore implementation of every repository contract.
///
/// Firestore is the source of truth. The store keeps raw document maps so it
/// can derive balances/payments the same way the web app does, then emits an
/// immutable [FinanceSnapshot] to the presentation layer.
class FirestoreFinanceStore
    implements
        IFinanceRepository,
        ITransactionRepository,
        IAccountRepository,
        ICardRepository,
        ILoanRepository,
        IBudgetRepository,
        IGoalRepository,
        ISubscriptionRepository,
        ISplitRepository,
        IShortcutRepository {
  FirestoreFinanceStore({
    required this.refs,
    required this.profile,
    this.onError,
  }) {
    _listen();
  }

  final FirestoreRefs refs;
  final FirestoreUserProfileRepository profile;
  final void Function(String message)? onError;

  final _controller = StreamController<FinanceSnapshot>.broadcast();
  final _ready = Completer<FinanceSnapshot>();

  FinanceSnapshot _snapshot = FinanceSnapshot.empty();
  var _revision = 0;
  var _disposed = false;
  var _emittedReady = false;

  final Map<String, Map<String, dynamic>> _transactionDocs = {};
  final Map<String, Map<String, dynamic>> _accountDocs = {};
  final Map<String, Map<String, dynamic>> _budgetDocs = {};
  final Map<String, Map<String, dynamic>> _goalDocs = {};
  final Map<String, Map<String, dynamic>> _loanDocs = {};
  final Map<String, Map<String, dynamic>> _recurringDocs = {};
  final Map<String, Map<String, dynamic>> _shortcutDocs = {};
  final Map<String, Map<String, dynamic>> _deletedTransactionDocs = {};

  final Map<String, Map<String, dynamic>> _participantDocs = {};
  final Map<String, Map<String, dynamic>> _groupDocs = {};
  final Map<String, Map<String, Map<String, dynamic>>> _expensesByGroup = {};
  final Map<String, Map<String, Map<String, dynamic>>> _settledByGroup = {};
  final Map<String, List<StreamSubscription<dynamic>>> _groupSubscriptions = {};
  final Map<String, List<SplitHistoryEntry>> _groupHistory = {};
  Map<String, dynamic>? _totalBudgetDoc;
  Map<String, String> _participantNames = const {'1': 'You'};
  Map<String, String> _participantIdByName = const {'You': '1'};

  final Set<String> _loaded = {};
  static const _sources = {
    'transactions',
    'accounts',
    'budgets',
    'totalBudget',
    'goals',
    'loans',
    'recurring',
    'shortcuts',
    'splitsParticipants',
    'splitsGroups',
    'user',
  };

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  FinanceSnapshot get current => _snapshot;

  @override
  Stream<FinanceSnapshot> watch() => _controller.stream;

  Future<FinanceSnapshot> get ready async {
    if (_emittedReady) return _snapshot;
    return _ready.future;
  }

  // --------------------------------------------------------------- listeners ---

  void _listen() {
    _subscriptions.add(
      refs.transactions.snapshots().listen((snapshot) {
        _transactionDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        _mark('transactions');
      }, onError: (Object error) => _fail('transactions', error)),
    );
    _subscriptions.add(
      refs.accounts.snapshots().listen((snapshot) {
        _accountDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        _mark('accounts');
      }, onError: (Object error) => _fail('accounts', error)),
    );
    _subscriptions.add(
      refs.budgets.snapshots().listen((snapshot) {
        _budgetDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        _mark('budgets');
      }, onError: (Object error) => _fail('budgets', error)),
    );
    _subscriptions.add(
      refs.totalBudget.snapshots().listen((snapshot) {
        _totalBudgetDoc = snapshot.data();
        _mark('totalBudget');
      }, onError: (Object error) => _fail('totalBudget', error)),
    );
    _subscriptions.add(
      refs.goals.snapshots().listen((snapshot) {
        _goalDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        _mark('goals');
      }, onError: (Object error) => _fail('goals', error)),
    );
    _subscriptions.add(
      refs.loans.snapshots().listen((snapshot) {
        _loanDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        _mark('loans');
      }, onError: (Object error) => _fail('loans', error)),
    );
    _subscriptions.add(
      refs.recurring.snapshots().listen((snapshot) {
        _recurringDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        _mark('recurring');
      }, onError: (Object error) => _fail('recurring', error)),
    );
    _subscriptions.add(
      refs.shortcuts.snapshots().listen((snapshot) {
        _shortcutDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        _mark('shortcuts');
      }, onError: (Object error) => _fail('shortcuts', error)),
    );
    _subscriptions.add(
      refs.participants.snapshots().listen((snapshot) {
        _participantDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        final names = <String, String>{'1': 'You'};
        final ids = <String, String>{'You': '1'};
        for (final entry in _participantDocs.entries) {
          final name = asString(entry.value['name']).trim();
          if (name.isEmpty) continue;
          names[entry.key] = name;
          ids[name] = entry.key;
        }
        _participantNames = names;
        _participantIdByName = ids;
        _mark('splitsParticipants');
      }, onError: (Object error) => _fail('splitsParticipants', error)),
    );
    _subscriptions.add(
      refs.splitGroups.snapshots().listen((snapshot) {
        _groupDocs
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
          );
        _syncGroupListeners(snapshot.docs.map((doc) => doc.id).toSet());
        _mark('splitsGroups');
      }, onError: (Object error) => _fail('splitsGroups', error)),
    );
    _subscriptions.add(
      refs.user.snapshots().listen(
        (_) => _mark('user'),
        onError: (Object error) => _fail('user', error),
      ),
    );
  }

  void _syncGroupListeners(Set<String> groupIds) {
    for (final groupId in _groupSubscriptions.keys.toList()) {
      if (groupIds.contains(groupId)) continue;
      for (final subscription
          in _groupSubscriptions.remove(groupId) ?? const []) {
        subscription.cancel();
      }
      _expensesByGroup.remove(groupId);
      _settledByGroup.remove(groupId);
      _groupHistory.remove(groupId);
    }

    for (final groupId in groupIds) {
      if (_groupSubscriptions.containsKey(groupId)) continue;
      final subscriptions = <StreamSubscription<dynamic>>[
        refs.expenses(groupId).snapshots().listen(
          (snapshot) {
            _expensesByGroup[groupId] = {
              for (final doc in snapshot.docs) doc.id: doc.data(),
            };
            _emit();
          },
          onError: (Object error) =>
              _error('Could not load split expenses: $error'),
        ),
        refs.settledPayments(groupId).snapshots().listen(
          (snapshot) {
            _settledByGroup[groupId] = {
              for (final doc in snapshot.docs) doc.id: doc.data(),
            };
            _emit();
          },
          onError: (Object error) =>
              _error('Could not load settlements: $error'),
        ),
      ];
      _groupSubscriptions[groupId] = subscriptions;
    }
  }

  void _mark(String source) {
    _loaded.add(source);
    if (!_emittedReady && _loaded.containsAll(_sources)) {
      _emittedReady = true;
      _emit();
      if (!_ready.isCompleted) _ready.complete(_snapshot);
      return;
    }
    _emit();
  }

  void _fail(String source, Object error) {
    _error('Could not load $source: $error');
    _mark(source);
  }

  void _error(String message) => onError?.call(message);

  // ------------------------------------------------------------------ derive ---

  void _emit() {
    if (_disposed) return;
    final now = DateTime.now();
    final cardIds = _accountDocs.entries
        .where((entry) => isCreditCardDoc(entry.value))
        .map((entry) => entry.key)
        .toSet();

    final transactions =
        _transactionDocs.entries
            .map(
              (entry) => transactionFromDoc(
                entry.key,
                entry.value,
                cardIds: cardIds,
                tagIdToName: profile.tagIdToName,
              ),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final accountDeltas = <String, double>{};
    for (final doc in _transactionDocs.values) {
      final accountId = asString(doc['accountId']);
      if (accountId.isEmpty) continue;
      accountDeltas[accountId] =
          (accountDeltas[accountId] ?? 0) + asDouble(doc['amount']);
    }

    final accounts = <Account>[];
    final cards = <CreditCard>[];
    for (final entry in _accountDocs.entries) {
      final data = entry.value;
      if (isCreditCardDoc(data)) {
        final payments = _transactionDocs.values
            .where((doc) => asString(doc['creditCardPaymentId']) == entry.key)
            .toList();
        final card = creditCardFromDoc(
          entry.key,
          data,
          paymentDocs: payments,
          now: now,
        );
        FinanceCalculator.recalcCard(card, transactions, now: now);
        cards.add(card);
      } else {
        final opening = asDouble(data['balance']);
        accounts.add(
          accountFromDoc(
            entry.key,
            data,
            liveBalance: opening + (accountDeltas[entry.key] ?? 0),
          ),
        );
      }
    }

    final month = monthStart(now);
    final budgets = _budgetDocs.entries.map((entry) {
      final category = asString(entry.value['category'], 'Other');
      return budgetFromDoc(
        entry.key,
        entry.value,
        spent: _spentIn(category, month),
        rollover: asBool(entry.value['rollover']),
        alertAt: asInt(entry.value['alertAt'], 80),
      );
    }).toList();

    final goals = _goalDocs.entries.map((entry) {
      final colorInt = entry.value['mobileColor'];
      final fallback = categoryColorFor(entry.key, entry.key.hashCode, null);
      return goalFromDoc(
        entry.key,
        entry.value,
        fallbackColor: colorInt == null
            ? fallback
            : Color(asInt(colorInt, fallback.toARGB32())),
      );
    }).toList();

    final loans = _loanDocs.entries.map((entry) {
      final payments = _transactionDocs.values
          .where((doc) => asString(doc['loanId']) == entry.key)
          .toList();
      return loanFromDoc(
        entry.key,
        entry.value,
        paymentDocs: payments,
        now: now,
      );
    }).toList();

    final recurring = _recurringDocs.entries
        .map((entry) => recurringFromDoc(entry.key, entry.value))
        .toList();
    final subscriptions = recurring
        .map((rule) => subscriptionFromRecurring(rule, now: now))
        .whereType<Subscription>()
        .toList();
    final shortcuts = _shortcutDocs.entries
        .map((entry) => shortcutFromDoc(entry.key, entry.value))
        .toList();

    final groups = <SplitGroup>[];
    final historyByGroup = <String, List<SplitHistoryEntry>>{};
    for (final entry in _groupDocs.entries) {
      final expenseDocs =
          (_expensesByGroup[entry.key] ??
                  const <String, Map<String, dynamic>>{})
              .entries
              .toList();
      final settledDocs =
          (_settledByGroup[entry.key] ?? const <String, Map<String, dynamic>>{})
              .entries
              .toList();
      final mapped = splitGroupFromDocs(
        id: entry.key,
        data: entry.value,
        participantNames: _participantNames,
        expenseDocs: expenseDocs,
        settledDocs: settledDocs,
      );
      groups.add(mapped.group);
      historyByGroup[entry.key] = mapped.history;
    }
    _groupHistory
      ..clear()
      ..addAll(historyByGroup);

    final accountsTotal = accounts
        .where((account) => account.type != AccountType.investments)
        .fold<double>(0, (total, account) => total + account.balance);
    final cardDues = cards.fold<double>(
      0,
      (total, card) => total + card.outstanding,
    );
    final loanOutstanding = loans.fold<double>(
      0,
      (total, loan) => total + loan.outstanding,
    );

    final totalLimit = _totalBudgetDoc == null
        ? null
        : asDouble(_totalBudgetDoc!['limit']);
    final totalBudgetOverride = totalLimit != null && totalLimit > 0
        ? totalLimit
        : null;
    final hasMockData =
        _transactionDocs.values.any((doc) => asBool(doc['isMock'])) ||
        _accountDocs.values.any((doc) => asBool(doc['isMock'])) ||
        _budgetDocs.values.any((doc) => asBool(doc['isMock'])) ||
        _goalDocs.values.any((doc) => asBool(doc['isMock'])) ||
        _loanDocs.values.any((doc) => asBool(doc['isMock'])) ||
        _recurringDocs.values.any((doc) => asBool(doc['isMock'])) ||
        asBool(_totalBudgetDoc?['isMock']);

    _revision++;
    _snapshot = FinanceSnapshot(
      transactions: List.unmodifiable(transactions),
      accounts: List.unmodifiable(accounts),
      cards: List.unmodifiable(cards),
      loans: List.unmodifiable(loans),
      budgets: List.unmodifiable(budgets),
      goals: List.unmodifiable(goals),
      subscriptions: List.unmodifiable(subscriptions),
      recurring: List.unmodifiable(recurring),
      groups: List.unmodifiable(groups),
      investments: const [],
      tags: List.unmodifiable(profile.tags.map((tag) => tag.name)),
      revision: _revision,
      generatedAt: now,
      netWorthOverride: accountsTotal - cardDues - loanOutstanding,
      totalBudgetOverride: totalBudgetOverride,
      hasMockData: hasMockData,
      shortcuts: List.unmodifiable(shortcuts),
      excludeInvestments: true,
    );
    _controller.add(_snapshot);
  }

  double _spentIn(String category, DateTime month) {
    var total = 0.0;
    for (final doc in _transactionDocs.values) {
      if (asString(doc['category']) != category) continue;
      final amount = asDouble(doc['amount']);
      if (amount >= 0) continue;
      final date = parseFirestoreDate(doc['date']);
      if (date == null || !isSameMonth(date, month)) continue;
      total -= amount;
    }
    return total;
  }

  String? get _defaultAccountId {
    final preferred = profile.defaultAccountId;
    if (preferred != null && _accountDocs.containsKey(preferred)) {
      return preferred;
    }
    for (final entry in _accountDocs.entries) {
      if (!isCreditCardDoc(entry.value)) return entry.key;
    }
    return _accountDocs.keys.isEmpty ? null : _accountDocs.keys.first;
  }

  String _cardName(String cardId) =>
      asString(_accountDocs[cardId]?['name'], 'Card');

  Future<Map<String, String>> _tagIds(List<String> names) =>
      profile.ensureTagIds(names);

  // ------------------------------------------------------------ transactions ---

  @override
  Future<Transaction> addTransaction(TransactionDraft draft) async {
    try {
      final tagMap = await _tagIds(draft.tags);
      final payload = transactionCreatePayload(draft, tagNameToId: tagMap);
      final ref = await refs.transactions.add(payload);
      return Transaction(
        id: ref.id,
        merchant: draft.merchant,
        category: draft.category,
        amount: draft.amount,
        date: draft.date,
        accountId: draft.accountId,
        cardId: draft.cardId,
        note: draft.note,
        tags: draft.tags,
      );
    } catch (error) {
      _error('Could not save transaction: $error');
      rethrow;
    }
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    try {
      final tagMap = await _tagIds(transaction.tags);
      await refs.transactions
          .doc(transaction.id)
          .update(transactionUpdatePayload(transaction, tagNameToId: tagMap));
    } catch (error) {
      _error('Could not update transaction: $error');
    }
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final cached = _transactionDocs[transactionId];
    if (cached != null) _deletedTransactionDocs[transactionId] = cached;
    try {
      await refs.transactions.doc(transactionId).delete();
    } catch (error) {
      _error('Could not delete transaction: $error');
    }
  }

  @override
  Future<void> restoreTransaction(Transaction transaction) async {
    try {
      final cached = _deletedTransactionDocs.remove(transaction.id);
      final payload = cached != null
          ? Map<String, dynamic>.from(cached)
          : transactionCreatePayload(
              TransactionDraft(
                merchant: transaction.merchant,
                category: transaction.category,
                amount: transaction.amount,
                date: transaction.date,
                accountId: transaction.accountId,
                cardId: transaction.cardId,
                note: transaction.note,
                tags: transaction.tags,
              ),
              tagNameToId: profile.tagNameToId,
            );
      await refs.transactions.doc(transaction.id).set(payload);
    } catch (error) {
      _error('Could not restore transaction: $error');
    }
  }

  @override
  Future<void> addTag(String tag) async {
    try {
      await profile.addTag(tag);
    } catch (error) {
      _error('Could not add tag: $error');
    }
  }

  @override
  Future<void> deleteTag(String tag) async {
    try {
      final tagId = profile.tagNameToId[tag];
      await profile.removeTag(tag);
      if (tagId == null) return;
      final batch = refs.db.batch();
      for (final entry in _transactionDocs.entries) {
        final tags = asStringList(entry.value['tags']);
        if (!tags.contains(tagId)) continue;
        batch.update(refs.transactions.doc(entry.key), {
          'tags': tags.where((id) => id != tagId).toList(),
        });
      }
      await batch.commit();
    } catch (error) {
      _error('Could not delete tag: $error');
    }
  }

  @override
  Future<void> renameTag(String oldTag, String newTag) async {
    try {
      await profile.renameTag(oldTag, newTag);
    } catch (error) {
      _error('Could not rename tag: $error');
    }
  }

  @override
  Future<void> renameCategory(String oldCategory, String newCategory) async {
    try {
      final categories = profile.current.categories.keys
          .map((name) => name == oldCategory ? newCategory : name)
          .toList();
      final batch = refs.db.batch();
      batch.update(refs.user, {'categories': categories});
      for (final entry in _transactionDocs.entries) {
        if (asString(entry.value['category']) != oldCategory) continue;
        batch.update(refs.transactions.doc(entry.key), {
          'category': newCategory,
        });
      }
      await batch.commit();
    } catch (error) {
      _error('Could not rename category: $error');
    }
  }

  @override
  Future<void> deleteCategory(String category) async {
    try {
      final categories = profile.current.categories.keys
          .where((name) => name != category)
          .toList();
      final batch = refs.db.batch();
      batch.update(refs.user, {'categories': categories});
      for (final entry in _transactionDocs.entries) {
        if (asString(entry.value['category']) != category) continue;
        batch.update(refs.transactions.doc(entry.key), {'category': 'Other'});
      }
      await batch.commit();
    } catch (error) {
      _error('Could not delete category: $error');
    }
  }

  // ---------------------------------------------------------------- accounts ---

  @override
  Future<Account> addAccount({
    required String name,
    required AccountType type,
    required double openingBalance,
  }) async {
    final payload = {
      'name': name,
      'type': remoteAccountType(null, type),
      'balance': openingBalance,
      'isMock': false,
    };
    final ref = await refs.accounts.add(payload);
    _accountDocs[ref.id] = Map<String, dynamic>.from(payload);
    _emit();
    return Account(
      id: ref.id,
      name: name,
      type: type,
      balance: openingBalance,
      remoteType: payload['type'] as String,
    );
  }

  @override
  Future<void> updateAccount(Account account) async {
    try {
      final delta = _accountDelta(account.id);
      final opening = account.balance - delta;
      final remoteType =
          account.remoteType == 'Wallet' && account.type == AccountType.cash
          ? 'Wallet'
          : remoteAccountType(null, account.type);
      await refs.accounts.doc(account.id).update({
        'name': account.name,
        'type': remoteType,
        'balance': opening,
        if (account.last4 != null) 'last4Digits': account.last4,
      });
      final existing = _accountDocs[account.id] ?? const <String, dynamic>{};
      _accountDocs[account.id] = {
        ...existing,
        'name': account.name,
        'type': remoteType,
        'balance': opening,
        if (account.last4 != null) 'last4Digits': account.last4,
      };
      _emit();
    } catch (error) {
      _error('Could not update account: $error');
    }
  }

  double _accountDelta(String accountId) {
    var total = 0.0;
    for (final doc in _transactionDocs.values) {
      if (asString(doc['accountId']) == accountId) {
        total += asDouble(doc['amount']);
      }
    }
    return total;
  }

  @override
  Future<void> removeAccount(String accountId) async {
    try {
      await refs.accounts.doc(accountId).delete();
      _accountDocs.remove(accountId);
      _emit();
    } catch (error) {
      _error('Could not remove account: $error');
    }
  }

  @override
  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
  }) async {
    if (amount <= 0 || fromAccountId == toAccountId) return;
    try {
      final fromName = asString(
        _accountDocs[fromAccountId]?['name'],
        'Account',
      );
      final toName = asString(_accountDocs[toAccountId]?['name'], 'Account');
      final batch = refs.db.batch();
      final date = firestoreDate(DateTime.now());
      final createdAt = nowIso();
      batch.set(refs.transactions.doc(), {
        'name': 'Transfer to $toName',
        'amount': -amount,
        'date': date,
        'category': 'Transfer',
        'type': 'expense',
        'accountId': fromAccountId,
        'createdAt': createdAt,
        'isMock': false,
      });
      batch.set(refs.transactions.doc(), {
        'name': 'Transfer from $fromName',
        'amount': amount,
        'date': date,
        'category': 'Transfer',
        'type': 'income',
        'accountId': toAccountId,
        'createdAt': createdAt,
        'isMock': false,
      });
      await batch.commit();
    } catch (error) {
      _error('Could not transfer: $error');
    }
  }

  // ------------------------------------------------------------------- cards ---

  @override
  Future<CreditCard> addCard({
    required String name,
    required double limit,
    required String last4,
    required int statementDay,
    required int dueDay,
  }) async {
    final payload = {
      'name': name,
      'type': 'Credit Card',
      'balance': 0,
      'limit': limit,
      'last4Digits': last4,
      'network': 'other',
      'statementDate': statementDay,
      'paymentDueDate': dueDay,
      'isMock': false,
    };
    final ref = await refs.accounts.add(payload);
    return CreditCard(
      id: ref.id,
      name: name,
      gradient: gradientFor(ref.id),
      last4: last4,
      limit: limit,
      statementDay: statementDay,
      dueDay: dueDay,
    );
  }

  @override
  Future<void> updateCard(CreditCard card) async {
    try {
      await refs.accounts.doc(card.id).update({
        'name': card.name,
        'type': 'Credit Card',
        'limit': card.limit,
        'last4Digits': card.last4,
        'statementDate': card.statementDay,
        'paymentDueDate': card.dueDay,
      });
    } catch (error) {
      _error('Could not update card: $error');
    }
  }

  @override
  Future<void> removeCard(String cardId) async {
    try {
      await refs.accounts.doc(cardId).delete();
    } catch (error) {
      _error('Could not remove card: $error');
    }
  }

  @override
  Future<void> payCardBill({
    required String cardId,
    required double amount,
    required String accountId,
  }) async {
    try {
      await refs.transactions.add({
        'name': 'Credit Card Payment - ${_cardName(cardId)}',
        'amount': -amount.abs(),
        'date': firestoreDate(DateTime.now()),
        'category': 'Payment',
        'type': 'expense',
        'accountId': accountId,
        'creditCardPaymentId': cardId,
        'comments': 'Payment to ${_cardName(cardId)}',
        'createdAt': nowIso(),
        'isMock': false,
      });
    } catch (error) {
      _error('Could not pay card: $error');
    }
  }

  // ----------------------------------------------------------------- budgets ---

  String? _budgetDocFor(String category) {
    for (final entry in _budgetDocs.entries) {
      if (asString(entry.value['category']) == category) return entry.key;
    }
    return null;
  }

  @override
  Future<void> addBudget({
    required String category,
    required double limit,
    bool rollover = false,
    int alertAt = 80,
  }) async {
    try {
      final existing = _budgetDocFor(category);
      if (existing != null) {
        await refs.budgets.doc(existing).update({
          'limit': limit,
          'rollover': rollover,
          'alertAt': alertAt,
        });
        return;
      }
      await refs.budgets.add({
        'category': category,
        'limit': limit,
        'rollover': rollover,
        'alertAt': alertAt,
        'spent': 0,
        'isMock': false,
      });
    } catch (error) {
      _error('Could not add budget: $error');
    }
  }

  @override
  Future<void> updateBudget({
    required String category,
    required double limit,
    required bool rollover,
    required int alertAt,
  }) async {
    try {
      final docId = _budgetDocFor(category);
      if (docId == null) {
        await addBudget(category: category, limit: limit);
        return;
      }
      await refs.budgets.doc(docId).update({
        'category': category,
        'limit': limit,
        'rollover': rollover,
        'alertAt': alertAt,
      });
    } catch (error) {
      _error('Could not update budget: $error');
    }
  }

  @override
  Future<void> removeBudget(String category) async {
    try {
      final docId = _budgetDocFor(category);
      if (docId != null) await refs.budgets.doc(docId).delete();
    } catch (error) {
      _error('Could not remove budget: $error');
    }
  }

  @override
  Future<void> setTotalBudget(double limit) async {
    try {
      final now = DateTime.now();
      final month =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      await refs.totalBudget.set({
        'limit': limit,
        'month': month,
        'isMock': false,
      });
    } catch (error) {
      _error('Could not save total budget: $error');
    }
  }

  @override
  Future<void> removeTotalBudget() async {
    try {
      await refs.totalBudget.delete();
    } catch (error) {
      _error('Could not remove total budget: $error');
    }
  }

  // ------------------------------------------------------------------- goals ---

  @override
  Future<void> addGoal({
    required String name,
    required double target,
    required double monthlyContribution,
    required Color color,
  }) async {
    try {
      final targetDate = DateTime.now().add(const Duration(days: 365));
      await refs.goals.add({
        'name': name,
        'targetAmount': target,
        'currentAmount': 0,
        'targetDate': firestoreDate(targetDate),
        'emoji': '🎯',
        'isMock': false,
        'mobileColor': color.toARGB32(),
        'mobileMonthlyContribution': monthlyContribution,
      });
    } catch (error) {
      _error('Could not add goal: $error');
    }
  }

  @override
  Future<void> updateGoal({
    required String goalId,
    required String name,
    required double target,
    required double monthlyContribution,
  }) async {
    try {
      await refs.goals.doc(goalId).update({
        'name': name,
        'targetAmount': target,
        'mobileMonthlyContribution': monthlyContribution,
      });
    } catch (error) {
      _error('Could not update goal: $error');
    }
  }

  @override
  Future<void> addGoalMoney(
    String goalId,
    double amount, {
    String? accountId,
  }) async {
    if (amount <= 0) return;
    try {
      final doc = await refs.goals.doc(goalId).get();
      if (!doc.exists) return;
      final data = doc.data() ?? const <String, dynamic>{};
      final current = asDouble(data['currentAmount']);
      final name = asString(data['name'], 'Goal');
      final source = accountId ?? _defaultAccountId;

      final batch = refs.db.batch();
      batch.update(refs.goals.doc(goalId), {'currentAmount': current + amount});
      final payload = <String, dynamic>{
        'name': 'Contribution to $name',
        'amount': -amount,
        'date': firestoreDate(DateTime.now()),
        'category': 'Goal Contribution',
        'type': 'expense',
        'createdAt': nowIso(),
        'isMock': false,
      };
      if (source != null) payload['accountId'] = source;
      batch.set(refs.transactions.doc(), payload);
      await batch.commit();
    } catch (error) {
      _error('Could not fund goal: $error');
    }
  }

  @override
  Future<void> removeGoal(String goalId) async {
    try {
      await refs.goals.doc(goalId).delete();
    } catch (error) {
      _error('Could not remove goal: $error');
    }
  }

  // ------------------------------------------------------------------- loans ---

  @override
  Future<Loan> addLoan({
    required String name,
    required String lender,
    required LoanType type,
    required double principal,
    required double rate,
    required int years,
    required int emiDay,
  }) async {
    final months = years * 12;
    final emi = FinanceCalculator.emiFor(
      principal,
      rate,
      months,
    ).roundToDouble();
    final start = DateTime.now();
    await refs.loans.add({
      'name': name,
      'loanAmount': principal,
      'interestRate': rate,
      'tenure': years,
      'tenureInMonths': months,
      'emi': emi,
      'startDate': firestoreDate(start),
      'type': remoteLoanType(type),
      'isMock': false,
      'mobileLender': lender,
    });
    return Loan(
      id: '',
      name: name,
      lender: lender,
      type: type,
      outstanding: principal,
      original: principal,
      rate: rate,
      emi: emi,
      emiDay: emiDay,
      tenureMonths: months,
      startDate: start,
    );
  }

  @override
  Future<void> updateLoan(Loan loan) async {
    try {
      await refs.loans.doc(loan.id).update({
        'name': loan.name,
        'loanAmount': loan.original,
        'interestRate': loan.rate,
        'tenure': (loan.tenureMonths ?? 0) ~/ 12,
        'tenureInMonths': loan.tenureMonths,
        'emi': loan.emi,
        'startDate': firestoreDate(loan.startDate),
        'type': remoteLoanType(loan.type),
        'mobileLender': loan.lender,
      });
    } catch (error) {
      _error('Could not update loan: $error');
    }
  }

  @override
  Future<void> removeLoan(String loanId) async {
    try {
      await refs.loans.doc(loanId).delete();
    } catch (error) {
      _error('Could not remove loan: $error');
    }
  }

  @override
  Future<void> recordLoanPayment({
    required String loanId,
    required double amount,
    required LoanPaymentType type,
    required DateTime date,
    required String accountId,
  }) async {
    try {
      final name = asString(_loanDocs[loanId]?['name'], 'Loan');
      await refs.transactions.add({
        'name': 'EMI Payment - $name',
        'amount': -amount.abs(),
        'date': firestoreDate(date),
        'category': 'Bills & EMIs',
        'type': 'expense',
        'accountId': accountId,
        'loanId': loanId,
        'comments': type == LoanPaymentType.prepayment
            ? 'Prepayment'
            : 'EMI payment',
        'createdAt': nowIso(),
        'isMock': false,
      });
    } catch (error) {
      _error('Could not record loan payment: $error');
    }
  }

  @override
  Future<void> deleteLoanPayment(String loanId, int paymentIndex) async {
    try {
      final entries =
          _transactionDocs.entries
              .where((entry) => asString(entry.value['loanId']) == loanId)
              .toList()
            ..sort(
              (a, b) => (parseFirestoreDate(a.value['date']) ?? DateTime(2000))
                  .compareTo(
                    parseFirestoreDate(b.value['date']) ?? DateTime(2000),
                  ),
            );
      if (paymentIndex < 0 || paymentIndex >= entries.length) return;
      await refs.transactions.doc(entries[paymentIndex].key).delete();
    } catch (error) {
      _error('Could not delete loan payment: $error');
    }
  }

  // ------------------------------------------------------- recurring / subs ---

  Future<void> _addRecurringRule({
    required String name,
    required double amount,
    required String category,
    required bool isIncome,
    required RecurringFrequency frequency,
    required DateTime startDate,
    String? accountId,
    String? note,
  }) async {
    final start = calendarDate(startDate);
    final lastProcessed = start.subtract(const Duration(days: 1));
    final payload = <String, dynamic>{
      'name': name,
      'amount': amount,
      'category': category,
      'type': isIncome ? 'income' : 'expense',
      'frequency': frequency.label,
      'startDate': firestoreDate(start),
      'endDate': null,
      'lastProcessedDate': firestoreDate(lastProcessed),
      'accountId': accountId ?? _defaultAccountId,
      'isPaused': false,
      'isMock': false,
    };
    if (note != null && note.isNotEmpty) payload['note'] = note;
    await refs.recurring.add(payload);
  }

  @override
  Future<void> addSubscription({
    required String name,
    required double price,
    required int renewsInDays,
  }) async {
    try {
      await _addRecurringRule(
        name: name,
        amount: -price.abs(),
        category: 'Other',
        isIncome: false,
        frequency: RecurringFrequency.monthly,
        startDate: DateTime.now().add(
          Duration(days: math.max(0, renewsInDays)),
        ),
      );
    } catch (error) {
      _error('Could not add subscription: $error');
    }
  }

  @override
  Future<void> updateSubscription(Subscription subscription) async {
    try {
      final id = subscription.recurringId ?? subscription.id;
      await refs.recurring.doc(id).update({
        'name': subscription.name,
        'amount': -subscription.price.abs(),
        'type': 'expense',
        'category': subscription.category,
        'isPaused': !subscription.active,
        if (subscription.note != null) 'note': subscription.note,
      });
    } catch (error) {
      _error('Could not update subscription: $error');
    }
  }

  @override
  Future<void> toggleSubscription(String subscriptionId) async {
    try {
      final doc = await refs.recurring.doc(subscriptionId).get();
      final paused = asBool(doc.data()?['isPaused']);
      await refs.recurring.doc(subscriptionId).update({'isPaused': !paused});
    } catch (error) {
      _error('Could not update subscription: $error');
    }
  }

  @override
  Future<void> removeSubscription(String subscriptionId) async {
    try {
      await refs.recurring.doc(subscriptionId).delete();
    } catch (error) {
      _error('Could not remove subscription: $error');
    }
  }

  @override
  Future<void> addRecurring({
    required String name,
    required double amount,
    required RecurringFrequency frequency,
    required bool isIncome,
  }) async {
    try {
      await _addRecurringRule(
        name: name,
        amount: amount,
        category: 'Other',
        isIncome: isIncome,
        frequency: frequency,
        startDate: DateTime.now(),
      );
    } catch (error) {
      _error('Could not add recurring rule: $error');
    }
  }

  @override
  Future<void> updateRecurring(RecurringTransaction recurring) async {
    try {
      await refs.recurring.doc(recurring.id).update({
        'name': recurring.name,
        'amount': recurring.amount,
        'category': recurring.category,
        'type': recurring.isIncome ? 'income' : 'expense',
        'frequency': recurring.frequency.label,
        if (recurring.accountId != null) 'accountId': recurring.accountId,
        'isPaused': !recurring.active,
        if (recurring.note != null) 'note': recurring.note,
      });
    } catch (error) {
      _error('Could not update recurring rule: $error');
    }
  }

  @override
  Future<void> removeRecurring(String recurringId) async {
    try {
      await refs.recurring.doc(recurringId).delete();
    } catch (error) {
      _error('Could not remove recurring rule: $error');
    }
  }

  // --------------------------------------------------------------- shortcuts ---

  @override
  Future<void> addShortcut({
    required String keyword,
    required String name,
    required double amount,
    required String category,
    required bool isIncome,
    String? accountId,
  }) async {
    try {
      await refs.shortcuts.add({
        'keyword': keyword.trim(),
        'name': name.trim(),
        'amount': isIncome ? amount.abs() : -amount.abs(),
        'category': category,
        'type': isIncome ? 'income' : 'expense',
        if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      });
    } catch (error) {
      _error('Could not save shortcut: $error');
    }
  }

  @override
  Future<void> updateShortcut(Shortcut shortcut) async {
    try {
      await refs.shortcuts.doc(shortcut.id).update({
        'keyword': shortcut.keyword.trim(),
        'name': shortcut.name.trim(),
        'amount': shortcut.isIncome
            ? shortcut.amount.abs()
            : -shortcut.amount.abs(),
        'category': shortcut.category,
        'type': shortcut.isIncome ? 'income' : 'expense',
        'accountId': shortcut.accountId ?? FieldValue.delete(),
      });
    } catch (error) {
      _error('Could not update shortcut: $error');
    }
  }

  @override
  Future<void> removeShortcut(String shortcutId) async {
    try {
      await refs.shortcuts.doc(shortcutId).delete();
    } catch (error) {
      _error('Could not remove shortcut: $error');
    }
  }

  // ------------------------------------------------------------------ splits ---

  Future<String> _ensureParticipant(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty || name == 'You') return '1';
    final existing = _participantIdByName[name];
    if (existing != null) return existing;
    final ref = await refs.participants.add({
      'name': name,
      'createdAt': Timestamp.now(),
    });
    _participantNames = {..._participantNames, ref.id: name};
    _participantIdByName = {..._participantIdByName, name: ref.id};
    return ref.id;
  }

  Future<String> _requireParticipantId(String name) async {
    final id = _participantIdByName[name] ?? (name == 'You' ? '1' : null);
    return id ?? _ensureParticipant(name);
  }

  @override
  Future<void> addGroup({
    required String name,
    required List<String> members,
  }) async {
    try {
      final ids = <String>['1'];
      for (final member in members) {
        final id = await _ensureParticipant(member);
        if (!ids.contains(id)) ids.add(id);
      }
      await refs.splitGroups.add({
        'name': name,
        'participantIds': ids,
        'currency': '₹',
        'createdAt': Timestamp.now(),
      });
    } catch (error) {
      _error('Could not create group: $error');
    }
  }

  @override
  Future<void> renameGroup(String groupId, String name) async {
    try {
      await refs.splitGroups.doc(groupId).update({'name': name});
    } catch (error) {
      _error('Could not rename group: $error');
    }
  }

  @override
  Future<void> removeGroup(String groupId) async {
    try {
      await _deleteCollection(refs.expenses(groupId));
      await _deleteCollection(refs.settledPayments(groupId));
      await refs.splitGroups.doc(groupId).delete();
      for (final subscription
          in _groupSubscriptions.remove(groupId) ??
              const <StreamSubscription<dynamic>>[]) {
        subscription.cancel();
      }
      _expensesByGroup.remove(groupId);
      _settledByGroup.remove(groupId);
      _groupHistory.remove(groupId);
      _emit();
    } catch (error) {
      _error('Could not remove group: $error');
    }
  }

  Future<Map<String, dynamic>> _splitPayload({
    required String description,
    required double amount,
    required String paidBy,
    required SplitType type,
    required Map<String, double> shares,
    required DateTime date,
    bool includeDate = true,
  }) async {
    final paidById = await _requireParticipantId(paidBy);
    final splits = <Map<String, dynamic>>[];
    for (final entry in shares.entries) {
      if (entry.key.trim().isEmpty) continue;
      final participantId = await _requireParticipantId(entry.key);
      splits.add({
        'participantId': participantId,
        'amount': entry.value,
        if (type == SplitType.percent)
          'percentage': amount <= 0 ? 0.0 : entry.value / amount * 100,
      });
    }
    return {
      'description': description,
      'amount': amount,
      'paidBy': paidById,
      'splitType': remoteSplitType(type),
      'splits': splits,
      if (includeDate) 'date': firestoreDate(date),
      'category': 'Other',
    };
  }

  @override
  Future<void> addSplitExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required SplitType type,
    required Map<String, double> shares,
  }) async {
    try {
      final payload = await _splitPayload(
        description: description,
        amount: amount,
        paidBy: paidBy,
        type: type,
        shares: shares,
        date: DateTime.now(),
      );
      payload['createdAt'] = Timestamp.now();
      await refs.expenses(groupId).add(payload);
    } catch (error) {
      _error('Could not add split expense: $error');
    }
  }

  SplitHistoryEntry? _historyEntry(String groupId, int index) {
    final history = _groupHistory[groupId];
    if (history == null || index < 0 || index >= history.length) return null;
    return history[index];
  }

  @override
  Future<void> editSplitExpense({
    required String groupId,
    required int index,
    required String description,
    required double amount,
    required String paidBy,
    required SplitType type,
    required Map<String, double> shares,
  }) async {
    final entry = _historyEntry(groupId, index);
    if (entry == null) return;
    if (entry.settlement) {
      _error('Settlements cannot be edited. Remove and re-add it instead.');
      return;
    }
    try {
      final payload = await _splitPayload(
        description: description,
        amount: amount,
        paidBy: paidBy,
        type: type,
        shares: shares,
        date: DateTime.now(),
        includeDate: false,
      );
      payload['updatedAt'] = Timestamp.now();
      await refs.expenses(groupId).doc(entry.id).update(payload);
    } catch (error) {
      _error('Could not edit split expense: $error');
    }
  }

  @override
  Future<void> deleteSplitExpense(String groupId, int index) async {
    final entry = _historyEntry(groupId, index);
    if (entry == null) return;
    try {
      if (entry.settlement) {
        await refs.settledPayments(groupId).doc(entry.id).delete();
      } else {
        await refs.expenses(groupId).doc(entry.id).delete();
      }
    } catch (error) {
      _error('Could not delete split expense: $error');
    }
  }

  @override
  Future<void> settleSplit({
    required String groupId,
    required String from,
    required String to,
    required double amount,
    required DateTime date,
  }) async {
    try {
      final fromId = await _requireParticipantId(from);
      final toId = await _requireParticipantId(to);
      await refs.settledPayments(groupId).add({
        'from': fromId,
        'to': toId,
        'amount': amount,
        'groupId': groupId,
        'date': firestoreDate(date),
        'createdAt': Timestamp.fromDate(date),
      });
    } catch (error) {
      _error('Could not settle split: $error');
    }
  }

  // ------------------------------------------------------------------- life ---

  @override
  Future<void> resetDemo() async {}

  @override
  Future<void> deleteAccountData() async {
    final groups = await refs.splitGroups.get();
    for (final group in groups.docs) {
      await _deleteCollection(refs.expenses(group.id));
      await _deleteCollection(refs.settledPayments(group.id));
    }
    await _deleteCollection(refs.transactions);
    await _deleteCollection(refs.accounts);
    await _deleteCollection(refs.budgets);
    await _deleteCollection(refs.goals);
    await _deleteCollection(refs.loans);
    await _deleteCollection(refs.recurring);
    await _deleteCollection(refs.participants);
    await _deleteCollection(refs.splitGroups);
    await _deleteCollection(refs.user.collection('pending_transactions'));
    await _deleteCollection(refs.user.collection('shortcuts'));
    await refs.totalBudget.delete();
    await refs.user.delete();

    _transactionDocs.clear();
    _accountDocs.clear();
    _budgetDocs.clear();
    _goalDocs.clear();
    _loanDocs.clear();
    _recurringDocs.clear();
    _shortcutDocs.clear();
    _participantDocs.clear();
    _groupDocs.clear();
    _expensesByGroup.clear();
    _settledByGroup.clear();
    _groupHistory.clear();
    _emit();
  }

  @override
  Future<void> loadDemoData() async {
    try {
      await clearMockData();
      await DemoDataSeeder(refs).seed();
    } catch (error) {
      _error('Could not load demo data: $error');
    }
  }

  @override
  Future<void> clearMockData() async {
    try {
      for (final collection in [
        refs.transactions,
        refs.accounts,
        refs.budgets,
        refs.goals,
        refs.loans,
        refs.recurring,
      ]) {
        await _deleteWhere(collection.where('isMock', isEqualTo: true));
      }
      if (asBool(_totalBudgetDoc?['isMock'])) {
        await refs.totalBudget.delete();
      }
    } catch (error) {
      _error('Could not clear mock data: $error');
    }
  }

  Future<void> _deleteWhere(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.get();
    var batch = refs.db.batch();
    var pending = 0;
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      pending++;
      if (pending >= 450) {
        await batch.commit();
        batch = refs.db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }

  @override
  Future<void> startFresh() async {
    try {
      final groups = await refs.splitGroups.get();
      for (final group in groups.docs) {
        await _deleteCollection(refs.expenses(group.id));
        await _deleteCollection(refs.settledPayments(group.id));
      }
      await _deleteCollection(refs.transactions);
      await _deleteCollection(refs.accounts);
      await _deleteCollection(refs.budgets);
      await _deleteCollection(refs.goals);
      await _deleteCollection(refs.loans);
      await _deleteCollection(refs.recurring);
      await _deleteCollection(refs.participants);
      await _deleteCollection(refs.splitGroups);
      await _deleteCollection(refs.user.collection('pending_transactions'));
      await _deleteCollection(refs.user.collection('shortcuts'));
      await refs.totalBudget.delete();
      _transactionDocs.clear();
      _accountDocs.clear();
      _budgetDocs.clear();
      _goalDocs.clear();
      _loanDocs.clear();
      _recurringDocs.clear();
      _emit();
    } catch (error) {
      _error('Could not erase data: $error');
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    var batch = refs.db.batch();
    var pending = 0;
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      pending++;
      if (pending >= 450) {
        await batch.commit();
        batch = refs.db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _controller.close();
  }
}
