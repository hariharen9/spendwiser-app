import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/date_helpers.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/credit_card.dart';
import '../models/finance_snapshot.dart';
import '../models/goal.dart';
import '../models/investment.dart';
import '../models/loan.dart';
import '../models/split_group.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../repositories/i_account_repository.dart';
import '../repositories/i_budget_repository.dart';
import '../repositories/i_card_repository.dart';
import '../repositories/i_finance_repository.dart';
import '../repositories/i_goal_repository.dart';
import '../repositories/i_loan_repository.dart';
import '../repositories/i_split_repository.dart';
import '../repositories/i_subscription_repository.dart';
import '../repositories/i_transaction_repository.dart';
import '../services/finance_calculator.dart';

/// In-memory implementation of every repository contract.
///
/// The seed generator is a faithful port of the prototype's `seed()`,
/// `seedCards()` and `seedLoans()` routines, including its deterministic LCG
/// (seed = 42), so Home / Cards / Debt show the same numbers as the reference
/// when run on the same date.
class MockFinanceStore
    implements
        IFinanceRepository,
        ITransactionRepository,
        IAccountRepository,
        ICardRepository,
        ILoanRepository,
        IBudgetRepository,
        IGoalRepository,
        ISubscriptionRepository,
        ISplitRepository {
  final void Function(Map<String, dynamic>)? _saveState;

  MockFinanceStore.seeded({
    DateTime? now,
    Map<String, dynamic>? Function()? loadState,
    void Function(Map<String, dynamic>)? saveState,
    // ignore: prefer_initializing_formals
  }) : _saveState = saveState {
    _now = now;
    final restored = loadState?.call();
    if (restored != null) {
      _importState(restored);
    } else {
      _seed();
    }
  }


  DateTime? _now;
  final _controller = StreamController<FinanceSnapshot>.broadcast();
  FinanceSnapshot _snapshot = FinanceSnapshot.empty();
  var _revision = 0;
  var _txCounter = 0;
  var _idCounter = 0;
  final _randomSeed = _Lcg(42);

  final List<Transaction> _transactions = [];
  final List<Account> _accounts = [];
  final List<CreditCard> _cards = [];
  final List<Loan> _loans = [];
  final List<Budget> _budgets = [];
  final List<Goal> _goals = [];
  final List<Subscription> _subscriptions = [];
  final List<RecurringTransaction> _recurring = [];
  final List<SplitGroup> _groups = [];
  final List<Investment> _investments = [];
  final List<String> _tags = [
    'Personal',
    'Work',
    'Shared',
    'Disputed',
    'Trip',
  ];

  @override
  FinanceSnapshot get current => _snapshot;

  @override
  Stream<FinanceSnapshot> watch() => _controller.stream;

  // -------------------------------------------------------------- seeding ---

  void _seed() {
    _now ??= DateTime.now();
    final now = _now!;
    _transactions.clear();
    _accounts.clear();
    _cards.clear();
    _loans.clear();
    _budgets.clear();
    _goals.clear();
    _subscriptions.clear();
    _recurring.clear();
    _groups.clear();
    _investments.clear();
    _txCounter = 0;
    _idCounter = 0;
    _randomSeed.reset(42);

    _seedTransactions(now);
    _seedAccounts();
    _seedCards();
    _seedBudgets();
    _seedGoals();
    _seedSubscriptions();
    _seedGroups(now);
    _seedInvestments();
    _seedCardsTransactions(now);
    _seedLoanTransactions(now);

    _transactions.sort((a, b) => b.date.compareTo(a.date));
    _recalc();
    _commit();
  }

  void _seedTransactions(DateTime now) {
    for (var k = 5; k >= 0; k--) {
      final month = DateTime(now.year, now.month - k, 1);
      DateTime at(int day) => DateTime(month.year, month.month, day, 12);
      final lastDay = k != 0 ? 28 : now.day;

      _addSeedTx(
        'Salary · Nimbus Labs',
        'Income',
        142000,
        at(1),
        now,
        accountId: 'hdfc',
      );
      _addSeedTx(
        'Rent · Indiranagar',
        'Bills',
        -32000,
        at(2),
        now,
        accountId: 'hdfc',
        tags: const ['Personal'],
      );
      if (k % 2 == 0) {
        _addSeedTx(
          'LIC Premium',
          'Bills',
          -12000,
          at(6),
          now,
          accountId: 'hdfc',
          tags: const ['Personal'],
        );
      }
      if (k == 2) {
        _addSeedTx(
          'Apollo Pharmacy',
          'Shop',
          -1850,
          at(11),
          now,
          accountId: 'hdfc',
        );
      }

      final merchants = <String, List<String>>{
        'Food': [
          'Swiggy',
          'Zomato',
          'Blue Tokai Coffee',
          'Big Basket',
          'Chaayos',
        ],
        'Travel': ['Uber', 'Ola', 'Metro card', 'Indian Oil'],
        'Shop': ['Amazon', 'Myntra', 'Decathlon'],
        'Fun': ['BookMyShow', 'Cult.fit', 'Steam'],
        'Bills': ['BESCOM Electricity', 'Airtel Fiber', 'Jio Recharge'],
      };

      final count = 16 + (_randomSeed.next() * 6).floor();
      for (var j = 0; j < count; j++) {
        final category = <String>[
          'Food',
          'Food',
          'Food',
          'Travel',
          'Shop',
          'Fun',
          'Bills',
        ][(_randomSeed.next() * 7).floor()];
        final options = merchants[category]!;
        // The prototype computes the amount before choosing the merchant, so
        // the LCG draws happen in this exact order.
        final base = switch (category) {
          'Shop' => 900 + _randomSeed.next() * 3500,
          'Bills' => 600 + _randomSeed.next() * 1500,
          'Travel' => 120 + _randomSeed.next() * 500,
          'Fun' => 300 + _randomSeed.next() * 900,
          _ => 150 + _randomSeed.next() * 700,
        };
        final merchant = options[(_randomSeed.next() * options.length).floor()];
        final amount = (base / 10).round() * 10.0;
        final day = math.max(
          1,
          math.min(lastDay, 1 + (_randomSeed.next() * lastDay).floor()),
        );
        _addSeedTx(
          merchant,
          category,
          -amount,
          at(day),
          now,
          accountId: 'hdfc',
        );
      }
    }
  }

  Transaction _addSeedTx(
    String merchant,
    String category,
    double amount,
    DateTime date,
    DateTime now, {
    String? accountId,
    List<String> tags = const [],
  }) {
    final tx = Transaction(
      id: 'tx-${_txCounter++}',
      merchant: merchant,
      category: category,
      amount: amount,
      date: date,
      accountId: accountId,
      tags: tags,
    );
    if (!date.isAfter(now)) {
      // Filtered later, but keeping the prototype's filter semantics explicit.
      _transactions.add(tx);
    }
    return tx;
  }

  void _seedAccounts() {
    _accounts.addAll([
      const Account(
        id: 'hdfc',
        name: 'HDFC Savings',
        type: AccountType.savings,
        balance: 384210,
        last4: '4821',
        gradient: [Color(0xFF1D3A6B), Color(0xFF0B1530)],
      ),
      const Account(
        id: 'sbi',
        name: 'SBI Salary',
        type: AccountType.savings,
        balance: 58300,
        last4: '1130',
        gradient: [Color(0xFF21482D), Color(0xFF07130B)],
      ),
      const Account(
        id: 'zerodha',
        name: 'Zerodha',
        type: AccountType.investments,
        balance: 198400,
        last4: '0091',
        gradient: [Color(0xFF3B2F78), Color(0xFF100C24)],
      ),
      const Account(
        id: 'cash',
        name: 'Cash wallet',
        type: AccountType.cash,
        balance: 2150,
        gradient: [Color(0xFF4A4A3A), Color(0xFF14140F)],
      ),
    ]);
  }

  void _seedCards() {
    _cards.addAll([CreditCard.seededIcici(), CreditCard.seededAxis()]);
  }

  void _seedBudgets() {
    const limits = <String, double>{
      'Food': 15000,
      'Travel': 8000,
      'Shop': 12000,
      'Bills': 45000,
      'Fun': 8000,
    };
    limits.forEach((category, limit) {
      _budgets.add(Budget(category: category, limit: limit));
    });
  }

  void _seedGoals() {
    _goals.addAll([
      Goal(
        id: 'goal-${_idCounter++}',
        name: 'Emergency fund',
        target: 300000,
        saved: 184000,
        monthlyContribution: 15000,
        color: const Color(0xFF2DD4BF),
      ),
      Goal(
        id: 'goal-${_idCounter++}',
        name: 'Goa trip · Dec',
        target: 60000,
        saved: 41500,
        monthlyContribution: 10000,
        color: const Color(0xFFFFD23F),
      ),
      Goal(
        id: 'goal-${_idCounter++}',
        name: 'New MacBook',
        target: 180000,
        saved: 32000,
        monthlyContribution: 8000,
        color: const Color(0xFFC084FC),
      ),
    ]);
  }

  void _seedSubscriptions() {
    _subscriptions.addAll([
      Subscription(id: 'sub-0', name: 'Netflix', price: 649, renewsInDays: 2),
      Subscription(id: 'sub-1', name: 'Spotify', price: 119, renewsInDays: 9),
      Subscription(id: 'sub-2', name: 'iCloud+', price: 75, renewsInDays: 11),
      Subscription(
        id: 'sub-3',
        name: 'Cult.fit',
        price: 1499,
        renewsInDays: 12,
        note: 'unused 23 days',
      ),
      Subscription(id: 'sub-4', name: 'Notion', price: 800, renewsInDays: 19),
      Subscription(
        id: 'sub-5',
        name: 'YouTube Premium',
        price: 189,
        renewsInDays: 24,
      ),
    ]);

    _recurring.addAll([
      RecurringTransaction(
        id: 'rec-0',
        name: 'Salary · Nimbus Labs',
        amount: 142000,
        frequency: RecurringFrequency.monthly,
        isIncome: true,
      ),
      RecurringTransaction(
        id: 'rec-1',
        name: 'Rent',
        amount: 32000,
        frequency: RecurringFrequency.monthly,
        isIncome: false,
      ),
      RecurringTransaction(
        id: 'rec-2',
        name: 'SIP · Nifty 50',
        amount: 10000,
        frequency: RecurringFrequency.monthly,
        isIncome: false,
      ),
      RecurringTransaction(
        id: 'rec-3',
        name: 'Gym',
        amount: 1499,
        frequency: RecurringFrequency.monthly,
        isIncome: false,
      ),
      RecurringTransaction(
        id: 'rec-4',
        name: 'Domain renewal',
        amount: 1200,
        frequency: RecurringFrequency.yearly,
        isIncome: false,
        active: false,
      ),
    ]);
  }

  void _seedGroups(DateTime now) {
    DateTime day(int offset) =>
        DateTime(now.year, now.month, now.day - offset, 12);

    final goaMembers = ['You', 'Rhea', 'Kabir', 'Meera', 'Dev'];
    _groups.add(
      SplitGroup(
        id: 'group-goa',
        name: 'Goa trip',
        members: goaMembers,
        expenses: [
          SplitExpense(
            description: 'Villa advance',
            amount: 15000,
            paidBy: 'Rhea',
            shares: splitEqually(15000, goaMembers),
            type: SplitType.equal,
            date: day(4),
          ),
          SplitExpense(
            description: 'Scooter rentals',
            amount: 1800,
            paidBy: 'Dev',
            shares: splitEqually(1800, goaMembers),
            type: SplitType.equal,
            date: day(3),
          ),
          SplitExpense(
            description: 'Beach shack dinner',
            amount: 4200,
            paidBy: 'You',
            shares: splitEqually(4200, goaMembers),
            type: SplitType.equal,
            date: day(2),
          ),
          SplitExpense(
            description: 'Airport cabs',
            amount: 3000,
            paidBy: 'You',
            shares: splitEqually(3000, goaMembers),
            type: SplitType.equal,
            date: day(1),
          ),
        ],
      ),
    );

    final flatMembers = ['You', 'Aman', 'Isha'];
    _groups.add(
      SplitGroup(
        id: 'group-flat',
        name: 'Flatmates',
        members: flatMembers,
        expenses: [
          SplitExpense(
            description: 'Wi-Fi + maid',
            amount: 3400,
            paidBy: 'You',
            shares: splitEqually(3400, flatMembers),
            type: SplitType.equal,
            date: day(7),
          ),
          SplitExpense(
            description: 'Groceries',
            amount: 2100,
            paidBy: 'Aman',
            shares: splitEqually(2100, flatMembers),
            type: SplitType.equal,
            date: day(5),
          ),
        ],
      ),
    );
  }

  void _seedInvestments() {
    _investments.addAll([
      Investment(
        id: 'inv-0',
        name: 'Nifty 50 Index Fund',
        type: 'Mutual fund',
        invested: 150000,
        value: 178400,
        monthlySip: 10000,
      ),
      Investment(
        id: 'inv-1',
        name: 'Digital Gold',
        type: 'Gold',
        invested: 40000,
        value: 46800,
      ),
      Investment(
        id: 'inv-2',
        name: 'PPF',
        type: 'Debt',
        invested: 120000,
        value: 131500,
      ),
    ]);
  }

  void _seedCardsTransactions(DateTime now) {
    final today = todayFrom(now);

    // Assign some spends to cards using the prototype's day-parity rule.
    for (final t in _transactions) {
      if (t.amount < 0 && t.cardId == null && t.accountId == 'hdfc') {
        final dayNumber = t.date.millisecondsSinceEpoch ~/ 86400000;
        if (const ['Shop', 'Fun', 'Travel'].contains(t.category) &&
            _cards.isNotEmpty) {
          final index = dayNumber % 2;
          if (index < _cards.length) {
            _replaceTransaction(
              t.copyWith(cardId: _cards[index].id, clearAccount: true),
            );
          }
        } else if (t.category == 'Food' &&
            dayNumber % 3 == 0 &&
            _cards.length > 1) {
          _replaceTransaction(
            t.copyWith(cardId: _cards[1].id, clearAccount: true),
          );
        }
      }
    }

    // Generate the historical statement payments exactly like `seedCards`.
    for (final card in _cards) {
      card.payments = [];
      final statements = FinanceCalculator.buildStatements(
        card,
        _transactions,
        now: now,
      );
      for (final statement in statements) {
        if (statement.amount > 0 && statement.dueDate.isBefore(today)) {
          final paidAt = statement.dueDate.subtract(const Duration(days: 2));
          card.payments.add(
            CardPayment(
              date: paidAt,
              amount: statement.amount,
              statementEnd: statement.end,
              accountId: 'hdfc',
            ),
          );
          _transactions.add(
            Transaction(
              id: 'tx-${_txCounter++}',
              merchant: 'Card payment · ${card.name}',
              category: 'Transfer',
              amount: -statement.amount,
              date: paidAt,
              accountId: 'hdfc',
            ),
          );
        }
      }
    }
  }

  void _seedLoanTransactions(DateTime now) {
    _loans.addAll([
      Loan(
        id: 'loan-home',
        name: 'Home loan',
        lender: 'HDFC Bank',
        type: LoanType.home,
        outstanding: 2150000,
        original: 2800000,
        rate: 8.5,
        emi: 24500,
        emiDay: 5,
        tenureMonths: 240,
        startDate: DateTime(now.year - 5, now.month, 5),
      ),
      Loan(
        id: 'loan-car',
        name: 'Car loan',
        lender: 'Axis Bank',
        type: LoanType.car,
        outstanding: 420000,
        original: 700000,
        rate: 9.2,
        emi: 14200,
        emiDay: 10,
        tenureMonths: 60,
        startDate: DateTime(now.year - 2, now.month - 3, 10),
      ),
      Loan(
        id: 'loan-personal',
        name: 'Personal loan',
        lender: 'SBI',
        type: LoanType.personal,
        outstanding: 150000,
        original: 300000,
        rate: 13.5,
        emi: 6800,
        emiDay: 15,
        tenureMonths: 60,
        startDate: DateTime(now.year - 2, now.month - 9, 15),
      ),
    ]);

    for (final loan in _loans) {
      final payments = <LoanPayment>[];
      for (var k = 5; k >= 0; k--) {
        final date = DateTime(now.year, now.month - k, loan.emiDay, 12);
        if (date.isAfter(now)) continue;
        final interest = (loan.outstanding * loan.rate / 1200).round();
        payments.add(
          LoanPayment(
            date: date,
            amount: loan.emi,
            type: LoanPaymentType.emi,
            interest: interest.toDouble(),
            principal: loan.emi - interest,
          ),
        );
        _transactions.add(
          Transaction(
            id: 'tx-${_txCounter++}',
            merchant: '${loan.name} EMI',
            category: 'EMI',
            amount: -loan.emi,
            date: date,
            accountId: 'hdfc',
          ),
        );
      }
      loan.payments = payments;
    }
  }

  // ------------------------------------------------------------- snapshot ---

  void _recalc() {
    final month = monthStart(_now ?? DateTime.now());
    for (final budget in _budgets) {
      budget.spent = _spentIn(budget.category, month);
    }
    for (final card in _cards) {
      FinanceCalculator.recalcCard(card, _transactions, now: _now);
    }
  }

  double _spentIn(String category, DateTime month) {
    var total = 0.0;
    for (final t in _transactions) {
      if (t.category == category &&
          t.amount < 0 &&
          isSameMonth(t.date, month)) {
        total -= t.amount;
      }
    }
    return total;
  }

  void _commit() {
    _recalc();
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    _revision++;
    _snapshot = FinanceSnapshot(
      transactions: List.unmodifiable(_transactions),
      accounts: List.unmodifiable(
        _accounts.map(
          (a) => a.copyWith(name: a.name, type: a.type, balance: a.balance),
        ),
      ),
      cards: List.unmodifiable(_cards.map(_cloneCard)),
      loans: List.unmodifiable(
        _loans.map((l) => l.copyWith(payments: List.of(l.payments))),
      ),
      budgets: List.unmodifiable(
        _budgets.map(
          (b) => b.copyWith(
            limit: b.limit,
            spent: b.spent,
            rollover: b.rollover,
            alertAt: b.alertAt,
          ),
        ),
      ),
      goals: List.unmodifiable(
        _goals.map(
          (g) => g.copyWith(
            name: g.name,
            target: g.target,
            saved: g.saved,
            monthlyContribution: g.monthlyContribution,
          ),
        ),
      ),
      subscriptions: List.unmodifiable(
        _subscriptions.map(
          (s) => s.copyWith(
            name: s.name,
            price: s.price,
            renewsInDays: s.renewsInDays,
            active: s.active,
            note: s.note,
          ),
        ),
      ),
      recurring: List.unmodifiable(
        _recurring.map(
          (r) => r.copyWith(
            name: r.name,
            amount: r.amount,
            frequency: r.frequency,
            isIncome: r.isIncome,
            active: r.active,
          ),
        ),
      ),
      groups: List.unmodifiable(_groups.map(_cloneGroup)),
      investments: List.unmodifiable(
        _investments.map(
          (i) => i.copyWith(
            name: i.name,
            type: i.type,
            invested: i.invested,
            value: i.value,
            monthlySip: i.monthlySip,
          ),
        ),
      ),
      tags: List.unmodifiable(_tags),
      revision: _revision,
      generatedAt: _now ?? DateTime.now(),
    );
    if (!_controller.isClosed) _controller.add(_snapshot);
    _saveState?.call(_exportState());
  }

  Map<String, dynamic> _exportState() => {
    'version': 1,
    'now': _now?.toIso8601String(),
    'revision': _revision,
    'txCounter': _txCounter,
    'idCounter': _idCounter,
    'transactions': _transactions.map((e) => e.toJson()).toList(),
    'accounts': _accounts.map((e) => e.toJson()).toList(),
    'cards': _cards.map((e) => e.toJson()).toList(),
    'loans': _loans.map((e) => e.toJson()).toList(),
    'budgets': _budgets.map((e) => e.toJson()).toList(),
    'goals': _goals.map((e) => e.toJson()).toList(),
    'subscriptions': _subscriptions.map((e) => e.toJson()).toList(),
    'recurring': _recurring.map((e) => e.toJson()).toList(),
    'groups': _groups.map((e) => e.toJson()).toList(),
    'investments': _investments.map((e) => e.toJson()).toList(),
    'tags': _tags,
  };

  void _importState(Map<String, dynamic> j) {
    final nowRaw = j['now'] as String?;
    if (nowRaw != null) {
      _now = DateTime.tryParse(nowRaw) ?? _now;
    }
    _revision = (j['revision'] as num? ?? 0).toInt();
    _txCounter = (j['txCounter'] as num? ?? 0).toInt();
    _idCounter = (j['idCounter'] as num? ?? 0).toInt();
    _transactions
      ..clear()
      ..addAll(
        ((j['transactions'] as List?) ?? []).map(
          (e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _accounts
      ..clear()
      ..addAll(
        ((j['accounts'] as List?) ?? []).map(
          (e) => Account.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _cards
      ..clear()
      ..addAll(
        ((j['cards'] as List?) ?? []).map(
          (e) => CreditCard.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _loans
      ..clear()
      ..addAll(
        ((j['loans'] as List?) ?? []).map(
          (e) => Loan.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _budgets
      ..clear()
      ..addAll(
        ((j['budgets'] as List?) ?? []).map(
          (e) => Budget.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _goals
      ..clear()
      ..addAll(
        ((j['goals'] as List?) ?? []).map(
          (e) => Goal.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _subscriptions
      ..clear()
      ..addAll(
        ((j['subscriptions'] as List?) ?? []).map(
          (e) => Subscription.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _recurring
      ..clear()
      ..addAll(
        ((j['recurring'] as List?) ?? []).map(
          (e) => RecurringTransaction.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _groups
      ..clear()
      ..addAll(
        ((j['groups'] as List?) ?? []).map(
          (e) => SplitGroup.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _investments
      ..clear()
      ..addAll(
        ((j['investments'] as List?) ?? []).map(
          (e) => Investment.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    final tags = (j['tags'] as List?)?.map((e) => e as String).toList();
    if (tags != null && tags.isNotEmpty) {
      _tags
        ..clear()
        ..addAll(tags);
    }
    _recalc();
    _commit();
  }

  CreditCard _cloneCard(CreditCard card) {
    return CreditCard(
      id: card.id,
      name: card.name,
      gradient: card.gradient,
      last4: card.last4,
      limit: card.limit,
      statementDay: card.statementDay,
      dueDay: card.dueDay,
      outstanding: card.outstanding,
      minimumDue: card.minimumDue,
      rewardPoints: card.rewardPoints,
      onlinePayments: card.onlinePayments,
      international: card.international,
      tapToPay: card.tapToPay,
      frozen: card.frozen,
      payments: List.of(card.payments),
      statements: List.of(card.statements),
      openCycle: card.openCycle,
      due: card.due,
      dueLabel: card.dueLabel,
      cycleLeftDays: card.cycleLeftDays,
    );
  }

  SplitGroup _cloneGroup(SplitGroup group) {
    return SplitGroup(
      id: group.id,
      name: group.name,
      members: List.of(group.members),
      expenses: List.of(group.expenses),
    );
  }

  void _replaceTransaction(Transaction transaction) {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      _transactions[index] = transaction;
    }
  }

  // ------------------------------------------------------- transactions ---

  @override
  Future<Transaction> addTransaction(TransactionDraft draft) async {
    final tx = Transaction(
      id: 'tx-${_txCounter++}',
      merchant: draft.merchant.isEmpty ? draft.category : draft.merchant,
      category: draft.category,
      amount: draft.amount,
      date: draft.date,
      accountId: draft.accountId,
      cardId: draft.cardId,
      note: draft.note,
      tags: List.of(draft.tags),
    );
    _transactions.add(tx);
    _applyAccountDelta(tx, 1);
    _commit();
    return tx;
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index < 0) return;
    final old = _transactions[index];
    _applyAccountDelta(old, -1);
    _applyAccountDelta(transaction, 1);
    _transactions[index] = transaction;
    _commit();
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index < 0) return;
    final tx = _transactions.removeAt(index);
    _applyAccountDelta(tx, -1);
    _commit();
  }

  @override
  Future<void> addTag(String tag) async {
    final clean = tag.trim().replaceAll('#', '');
    if (clean.isEmpty || _tags.contains(clean)) return;
    _tags.add(clean);
    _commit();
  }

  @override
  Future<void> deleteTag(String tag) async {
    final clean = tag.trim().replaceAll('#', '');
    _tags.remove(clean);
    for (var i = 0; i < _transactions.length; i++) {
      if (_transactions[i].tags.contains(clean)) {
        final updatedTags = List<String>.of(_transactions[i].tags)..remove(clean);
        _transactions[i] = _transactions[i].copyWith(tags: updatedTags);
      }
    }
    _commit();
  }

  @override
  Future<void> renameTag(String oldTag, String newTag) async {
    final cleanOld = oldTag.trim().replaceAll('#', '');
    final cleanNew = newTag.trim().replaceAll('#', '');
    if (cleanNew.isEmpty || cleanOld == cleanNew) return;
    final index = _tags.indexOf(cleanOld);
    if (index != -1) {
      _tags[index] = cleanNew;
    }
    for (var i = 0; i < _transactions.length; i++) {
      if (_transactions[i].tags.contains(cleanOld)) {
        final updatedTags = _transactions[i].tags.map((t) => t == cleanOld ? cleanNew : t).toList();
        _transactions[i] = _transactions[i].copyWith(tags: updatedTags);
      }
    }
    _commit();
  }

  void _applyAccountDelta(Transaction tx, int sign) {
    if (tx.accountId == null) return;
    final account = _accounts.where((a) => a.id == tx.accountId).firstOrNullX;
    if (account == null) return;
    final nextBalance = account.balance + tx.amount * sign;
    final index = _accounts.indexOf(account);
    _accounts[index] = account.copyWith(balance: nextBalance);
  }

  // ----------------------------------------------------------- accounts ---

  @override
  Future<Account> addAccount({
    required String name,
    required AccountType type,
    required double openingBalance,
  }) async {
    final account = Account(
      id: 'account-${_idCounter++}',
      name: name,
      type: type,
      balance: openingBalance,
      gradient: const [Color(0xFF1D3A6B), Color(0xFF0B1530)],
    );
    _accounts.add(account);
    _commit();
    return account;
  }

  @override
  Future<void> updateAccount(Account account) async {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index < 0) return;
    _accounts[index] = account;
    _commit();
  }

  @override
  Future<void> removeAccount(String accountId) async {
    if (_accounts.length <= 1) return;
    _accounts.removeWhere((a) => a.id == accountId);
    for (var i = 0; i < _transactions.length; i++) {
      if (_transactions[i].accountId == accountId) {
        _transactions[i] = _transactions[i].copyWith(clearAccount: true);
      }
    }
    _commit();
  }

  @override
  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
  }) async {
    if (amount <= 0 || fromAccountId == toAccountId) return;
    final from = _accounts.where((a) => a.id == fromAccountId).firstOrNullX;
    final to = _accounts.where((a) => a.id == toAccountId).firstOrNullX;
    if (from == null || to == null) return;
    _accounts[_accounts.indexOf(from)] = from.copyWith(
      balance: from.balance - amount,
    );
    _accounts[_accounts.indexOf(to)] = to.copyWith(
      balance: to.balance + amount,
    );
    _transactions.add(
      Transaction(
        id: 'tx-${_txCounter++}',
        merchant: 'Transfer → ${to.name}',
        category: 'Transfer',
        amount: -amount,
        date: DateTime.now(),
        accountId: fromAccountId,
      ),
    );
    _commit();
  }

  // -------------------------------------------------------------- cards ---

  @override
  Future<CreditCard> addCard({
    required String name,
    required double limit,
    required String last4,
    required int statementDay,
    required int dueDay,
  }) async {
    final card = CreditCard(
      id: 'card-${_idCounter++}',
      name: name,
      gradient: CreditCard.newCardGradient,
      last4: last4,
      limit: limit,
      statementDay: statementDay.clamp(1, 28),
      dueDay: dueDay.clamp(1, 28),
      payments: [],
    );
    _cards.add(card);
    _commit();
    return card;
  }

  @override
  Future<void> updateCard(CreditCard card) async {
    final index = _cards.indexWhere((c) => c.id == card.id);
    if (index < 0) return;
    _cards[index] = _cloneCard(card);
    _commit();
  }

  @override
  Future<void> removeCard(String cardId) async {
    _cards.removeWhere((c) => c.id == cardId);
    for (var i = 0; i < _transactions.length; i++) {
      if (_transactions[i].cardId == cardId) {
        _transactions[i] = _transactions[i].copyWith(clearCard: true);
      }
    }
    _commit();
  }

  @override
  Future<void> payCardBill({
    required String cardId,
    required double amount,
    required String accountId,
  }) async {
    final card = _cards.where((c) => c.id == cardId).firstOrNullX;
    if (card == null || amount <= 0) return;
    final payable = math.min(amount, card.outstanding);
    var rest = payable;
    final unpaid = card.statements
        .where((s) => s.remaining > 0)
        .toList()
        .reversed;
    for (final statement in unpaid) {
      if (rest <= 0) break;
      final portion = math.min(rest, statement.remaining);
      card.payments.add(
        CardPayment(
          date: DateTime.now(),
          amount: portion,
          statementEnd: statement.end,
          accountId: accountId,
        ),
      );
      rest -= portion;
    }
    if (rest > 0) {
      card.payments.add(
        CardPayment(date: DateTime.now(), amount: rest, accountId: accountId),
      );
    }
    _transactions.add(
      Transaction(
        id: 'tx-${_txCounter++}',
        merchant: 'Card payment · ${card.name}',
        category: 'Transfer',
        amount: -payable,
        date: DateTime.now(),
        accountId: accountId,
      ),
    );
    _applyAccountDelta(_transactions.last, 1);
    _commit();
  }

  // -------------------------------------------------------------- loans ---

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
    final loan = Loan(
      id: 'loan-${_idCounter++}',
      name: name,
      lender: lender,
      type: type,
      outstanding: principal,
      original: principal,
      rate: rate,
      emi: emi,
      emiDay: emiDay.clamp(1, 28),
      tenureMonths: months,
      startDate: DateTime.now(),
      payments: [],
    );
    _loans.add(loan);
    _commit();
    return loan;
  }

  @override
  Future<void> updateLoan(Loan loan) async {
    final index = _loans.indexWhere((l) => l.id == loan.id);
    if (index < 0) return;
    _loans[index] = loan.copyWith(payments: List.of(loan.payments));
    _commit();
  }

  @override
  Future<void> removeLoan(String loanId) async {
    _loans.removeWhere((l) => l.id == loanId);
    _commit();
  }

  @override
  Future<void> recordLoanPayment({
    required String loanId,
    required double amount,
    required LoanPaymentType type,
    required DateTime date,
    required String accountId,
  }) async {
    final loan = _loans.where((l) => l.id == loanId).firstOrNullX;
    if (loan == null || amount <= 0) return;
    final interest = type == LoanPaymentType.emi
        ? math.min(
            amount,
            (loan.outstanding * loan.rate / 1200).roundToDouble(),
          )
        : 0.0;
    final principal = math.min(loan.outstanding, amount - interest);
    loan.payments.add(
      LoanPayment(
        date: date,
        amount: amount,
        type: type,
        interest: interest,
        principal: principal,
      ),
    );
    loan.outstanding = math.max(0, loan.outstanding - principal);
    final tx = Transaction(
      id: 'tx-${_txCounter++}',
      merchant:
          '${loan.name}${type == LoanPaymentType.emi ? ' EMI' : ' prepayment'}',
      category: 'EMI',
      amount: -amount,
      date: date,
      accountId: accountId,
    );
    _transactions.add(tx);
    _applyAccountDelta(tx, 1);
    _commit();
  }

  @override
  Future<void> deleteLoanPayment(String loanId, int paymentIndex) async {
    final loan = _loans.where((l) => l.id == loanId).firstOrNullX;
    if (loan == null ||
        paymentIndex < 0 ||
        paymentIndex >= loan.payments.length) {
      return;
    }
    final payment = loan.payments.removeAt(paymentIndex);
    loan.outstanding += payment.principal;
    final txIndex = _transactions.indexWhere(
      (t) =>
          t.amount == -payment.amount &&
          t.merchant.startsWith(loan.name) &&
          dateOnly(t.date).isAtSameMomentAs(dateOnly(payment.date)),
    );
    if (txIndex >= 0) {
      final tx = _transactions.removeAt(txIndex);
      _applyAccountDelta(tx, -1);
    }
    _commit();
  }

  // ------------------------------------------------------------ budgets ---

  @override
  Future<void> addBudget({
    required String category,
    required double limit,
  }) async {
    _budgets.add(Budget(category: category, limit: limit));
    _commit();
  }

  @override
  Future<void> updateBudget({
    required String category,
    required double limit,
    required bool rollover,
    required int alertAt,
  }) async {
    final index = _budgets.indexWhere((b) => b.category == category);
    if (index < 0) return;
    _budgets[index] = _budgets[index].copyWith(
      limit: limit,
      rollover: rollover,
      alertAt: alertAt,
    );
    _commit();
  }

  @override
  Future<void> removeBudget(String category) async {
    _budgets.removeWhere((b) => b.category == category);
    _commit();
  }

  // -------------------------------------------------------------- goals ---

  @override
  Future<void> addGoal({
    required String name,
    required double target,
    required double monthlyContribution,
    required Color color,
  }) async {
    _goals.add(
      Goal(
        id: 'goal-${_idCounter++}',
        name: name,
        target: target,
        saved: 0,
        monthlyContribution: monthlyContribution,
        color: color,
      ),
    );
    _commit();
  }

  @override
  Future<void> updateGoal({
    required String goalId,
    required String name,
    required double target,
    required double monthlyContribution,
  }) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index < 0) return;
    _goals[index] = _goals[index].copyWith(
      name: name,
      target: target,
      monthlyContribution: monthlyContribution,
    );
    _commit();
  }

  @override
  Future<void> addGoalMoney(
    String goalId,
    double amount, {
    String? accountId,
  }) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index < 0 || amount <= 0) return;
    final goal = _goals[index];
    _goals[index] = goal.copyWith(saved: goal.saved + amount);
    final account =
        accountId ?? (_accounts.isEmpty ? null : _accounts.first.id);
    final tx = Transaction(
      id: 'tx-${_txCounter++}',
      merchant: 'Goal · ${goal.name}',
      category: 'Transfer',
      amount: -amount,
      date: DateTime.now(),
      accountId: account,
    );
    _transactions.add(tx);
    _applyAccountDelta(tx, 1);
    _commit();
  }

  @override
  Future<void> removeGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    _commit();
  }

  // ------------------------------------------------------ subscriptions ---

  @override
  Future<void> addSubscription({
    required String name,
    required double price,
    required int renewsInDays,
  }) async {
    _subscriptions.add(
      Subscription(
        id: 'sub-${_idCounter++}',
        name: name,
        price: price,
        renewsInDays: renewsInDays,
      ),
    );
    _commit();
  }

  @override
  Future<void> updateSubscription(Subscription subscription) async {
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index < 0) return;
    _subscriptions[index] = subscription;
    _commit();
  }

  @override
  Future<void> toggleSubscription(String subscriptionId) async {
    final index = _subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (index < 0) return;
    final subscription = _subscriptions[index];
    _subscriptions[index] = subscription.copyWith(active: !subscription.active);
    _commit();
  }

  @override
  Future<void> removeSubscription(String subscriptionId) async {
    _subscriptions.removeWhere((s) => s.id == subscriptionId);
    _commit();
  }

  @override
  Future<void> addRecurring({
    required String name,
    required double amount,
    required RecurringFrequency frequency,
    required bool isIncome,
  }) async {
    _recurring.add(
      RecurringTransaction(
        id: 'rec-${_idCounter++}',
        name: name,
        amount: amount,
        frequency: frequency,
        isIncome: isIncome,
      ),
    );
    _commit();
  }

  @override
  Future<void> updateRecurring(RecurringTransaction recurring) async {
    final index = _recurring.indexWhere((r) => r.id == recurring.id);
    if (index < 0) return;
    _recurring[index] = recurring;
    _commit();
  }

  @override
  Future<void> removeRecurring(String recurringId) async {
    _recurring.removeWhere((r) => r.id == recurringId);
    _commit();
  }

  // --------------------------------------------------------------- split ---

  @override
  Future<void> addGroup({
    required String name,
    required List<String> members,
  }) async {
    final people = <String>['You'];
    for (final member in members) {
      final trimmed = member.trim();
      if (trimmed.isNotEmpty && !people.contains(trimmed)) people.add(trimmed);
    }
    _groups.add(
      SplitGroup(id: 'group-${_idCounter++}', name: name, members: people),
    );
    _commit();
  }

  @override
  Future<void> renameGroup(String groupId, String name) async {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index < 0) return;
    final group = _groups[index];
    _groups[index] = SplitGroup(
      id: group.id,
      name: name,
      members: group.members,
      expenses: group.expenses,
    );
    _commit();
  }

  @override
  Future<void> removeGroup(String groupId) async {
    _groups.removeWhere((g) => g.id == groupId);
    _commit();
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
    final group = _groups.where((g) => g.id == groupId).firstOrNullX;
    if (group == null) return;
    group.expenses.add(
      SplitExpense(
        description: description,
        amount: amount,
        paidBy: paidBy,
        shares: shares,
        type: type,
        date: DateTime.now(),
      ),
    );
    _commit();
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
    final group = _groups.where((g) => g.id == groupId).firstOrNullX;
    if (group == null || index < 0 || index >= group.expenses.length) return;
    final previous = group.expenses[index];
    group.expenses[index] = SplitExpense(
      description: description,
      amount: amount,
      paidBy: paidBy,
      shares: shares,
      type: type,
      date: previous.date,
    );
    _commit();
  }

  @override
  Future<void> deleteSplitExpense(String groupId, int index) async {
    final group = _groups.where((g) => g.id == groupId).firstOrNullX;
    if (group == null || index < 0 || index >= group.expenses.length) return;
    group.expenses.removeAt(index);
    _commit();
  }

  @override
  Future<void> settleSplit({
    required String groupId,
    required String from,
    required String to,
    required double amount,
    required DateTime date,
  }) async {
    final group = _groups.where((g) => g.id == groupId).firstOrNullX;
    if (group == null) return;
    group.expenses.add(
      SplitExpense(
        description: 'Settlement',
        amount: amount,
        paidBy: from,
        shares: const {},
        type: SplitType.equal,
        date: date,
        settledTo: to,
      ),
    );
    _commit();
  }

  // -------------------------------------------------------------- reset ---

  @override
  Future<void> resetDemo() async {
    _now = DateTime.now();
    _seed();
  }

  @override
  Future<void> startFresh() async {
    _transactions.clear();
    _cards.clear();
    _loans.clear();
    _goals.clear();
    _subscriptions.clear();
    _recurring.clear();
    _groups.clear();
    _investments.clear();
    _accounts
      ..clear()
      ..add(
        const Account(
          id: 'cash',
          name: 'Cash',
          type: AccountType.cash,
          balance: 0,
        ),
      );
    for (final budget in _budgets) {
      budget.spent = 0;
    }
    _commit();
  }

  void renameCategory(String from, String to) {
    for (var i = 0; i < _transactions.length; i++) {
      if (_transactions[i].category == from) {
        _transactions[i] = _transactions[i].copyWith(category: to);
      }
    }
    for (var i = 0; i < _budgets.length; i++) {
      if (_budgets[i].category == from) {
        _budgets[i] = _budgets[i].copyWith(category: to);
      }
    }
    _recalc();
    _commit();
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _Lcg {
  _Lcg(int seed) : _seed = seed;
  int _seed;

  void reset(int seed) => _seed = seed;

  double next() {
    _seed = (_seed * 16807) % 2147483647;
    return _seed / 2147483647;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNullX {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
