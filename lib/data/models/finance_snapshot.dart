import 'package:flutter/foundation.dart';

import '../../../core/utils/date_helpers.dart';
import 'account.dart';
import 'budget.dart';
import 'credit_card.dart';
import 'goal.dart';
import 'investment.dart';
import 'loan.dart';
import 'split_group.dart';
import 'subscription.dart';
import 'transaction.dart';

/// Immutable read model handed to the presentation layer. The UI never talks
/// to a database directly — swapping the repository implementation is enough.
@immutable
class FinanceSnapshot {
  const FinanceSnapshot({
    required this.transactions,
    required this.accounts,
    required this.cards,
    required this.loans,
    required this.budgets,
    required this.goals,
    required this.subscriptions,
    required this.recurring,
    required this.groups,
    required this.investments,
    required this.tags,
    required this.revision,
    required this.generatedAt,
  });

  final List<Transaction> transactions;
  final List<Account> accounts;
  final List<CreditCard> cards;
  final List<Loan> loans;
  final List<Budget> budgets;
  final List<Goal> goals;
  final List<Subscription> subscriptions;
  final List<RecurringTransaction> recurring;
  final List<SplitGroup> groups;
  final List<Investment> investments;
  final List<String> tags;
  final int revision;
  final DateTime generatedAt;

  static const double propertyValue = 2800000;

  factory FinanceSnapshot.empty() => FinanceSnapshot(
    transactions: const [],
    accounts: const [],
    cards: const [],
    loans: const [],
    budgets: const [],
    goals: const [],
    subscriptions: const [],
    recurring: const [],
    groups: const [],
    investments: const [],
    tags: const [],
    revision: 0,
    generatedAt: DateTime.now(),
  );

  double get accountsTotal =>
      accounts.fold(0, (sum, account) => sum + account.balance);

  double get investmentsValue =>
      investments.fold(0, (sum, holding) => sum + holding.value);

  double get cardDues => cards.fold(0, (sum, card) => sum + card.outstanding);

  double get loanOutstanding =>
      loans.fold(0, (sum, loan) => sum + loan.outstanding);

  double get netWorth =>
      accountsTotal +
      investmentsValue +
      propertyValue -
      cardDues -
      loanOutstanding;

  double get liquidAssets => accounts
      .where((a) => a.type != AccountType.investments)
      .fold(0, (sum, account) => sum + account.balance);

  double get monthlyEmis => loans.fold(0, (sum, loan) => sum + loan.emi);

  double get monthlySubscriptionCost =>
      subscriptions.where((s) => s.active).fold(0, (sum, s) => sum + s.price);

  double get yearlySubscriptionCost => monthlySubscriptionCost * 12;

  double get cardLimitTotal => cards.fold(0, (sum, card) => sum + card.limit);

  double get cardAvailable =>
      cards.fold(0, (sum, card) => sum + card.available);

  double get totalBudgetLimit =>
      budgets.fold(0, (sum, budget) => sum + budget.limit);

  double get totalBudgetSpent =>
      budgets.fold(0, (sum, budget) => sum + budget.spent);

  double get totalSaved => goals.fold(0, (sum, goal) => sum + goal.saved);

  double get totalGoalTarget => goals.fold(0, (sum, goal) => sum + goal.target);

  double get goalsProgress =>
      totalGoalTarget <= 0 ? 0 : totalSaved / totalGoalTarget * 100;

  double get youAreOwed =>
      groups.fold(0, (sum, group) => sum + group.yourBalance);

  CreditCard? cardById(String id) {
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  Loan? loanById(String id) {
    for (final loan in loans) {
      if (loan.id == id) return loan;
    }
    return null;
  }

  Account? accountById(String? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Goal? goalById(String id) {
    for (final goal in goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  List<Transaction> inMonth(DateTime month) => transactions
      .where((t) => isSameMonth(t.date, month))
      .toList(growable: false);

  List<Transaction> forCard(String cardId) =>
      transactions.where((t) => t.cardId == cardId).toList(growable: false);

  List<Transaction> forAccount(String accountId) => transactions
      .where((t) => t.accountId == accountId)
      .toList(growable: false);

  MonthFlow flow(DateTime month) {
    var income = 0.0;
    var expense = 0.0;
    for (final t in inMonth(month)) {
      if (t.category == 'Transfer') continue;
      if (t.amount > 0) {
        income += t.amount;
      } else {
        expense -= t.amount;
      }
    }
    return MonthFlow(income: income, expense: expense);
  }

  double spentIn(String category, DateTime month) {
    var total = 0.0;
    for (final t in inMonth(month)) {
      if (t.amount < 0 && t.category == category) total -= t.amount;
    }
    return total;
  }

  List<CategorySpend> spendByCategory(DateTime month) {
    final amounts = <String, double>{};
    final counts = <String, int>{};
    for (final t in inMonth(month)) {
      if (t.amount >= 0 || t.category == 'Transfer') continue;
      amounts[t.category] = (amounts[t.category] ?? 0) - t.amount;
      counts[t.category] = (counts[t.category] ?? 0) + 1;
    }
    final entries = amounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map(
          (e) => CategorySpend(
            category: e.key,
            amount: e.value,
            count: counts[e.key] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  double spentByMonth(String category, int monthsBack) {
    final month = monthAgo(monthsBack, now: generatedAt);
    return spentIn(category, month);
  }
}

@immutable
class SafeToSpend {
  const SafeToSpend({
    required this.limit,
    required this.spent,
    required this.left,
    required this.perDay,
    required this.daysLeft,
  });

  final double limit;
  final double spent;
  final double left;
  final double perDay;
  final int daysLeft;
}
