import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/models/budget.dart';
import 'package:spendwiser_app/data/models/finance_snapshot.dart';
import 'package:spendwiser_app/data/models/transaction.dart';
import 'package:spendwiser_app/data/services/finance_calculator.dart';

void main() {
  test('total budget override is compared with all monthly expenses', () {
    final snapshot = FinanceSnapshot(
      transactions: [
        Transaction(
          id: 't1',
          merchant: 'Swiggy',
          category: 'Food & Dining',
          amount: -1000,
          date: DateTime(2026, 11, 1),
        ),
        Transaction(
          id: 't2',
          merchant: 'Transfer to savings',
          category: 'Transfer',
          amount: -500,
          date: DateTime(2026, 11, 2),
        ),
        Transaction(
          id: 't3',
          merchant: 'Salary',
          category: 'Income',
          amount: 50000,
          date: DateTime(2026, 11, 1),
        ),
      ],
      accounts: const [],
      cards: const [],
      loans: const [],
      budgets: [
        Budget(category: 'Food & Dining', limit: 5000, spent: 1000),
      ],
      goals: const [],
      subscriptions: const [],
      recurring: const [],
      groups: const [],
      investments: const [],
      tags: const [],
      revision: 1,
      generatedAt: DateTime(2026, 11, 10),
      totalBudgetOverride: 20000,
    );

    expect(snapshot.hasTotalBudget, true);
    expect(snapshot.totalBudgetLimit, 20000);
    expect(snapshot.expensesIn(DateTime(2026, 11, 1)), 1500);

    final safe = FinanceCalculator.safeToSpend(
      snapshot,
      now: DateTime(2026, 11, 10),
    );
    expect(safe.spent, 1500);
    expect(safe.left, 18500);
  });

  test('without an override the envelope limits are still used', () {
    final snapshot = FinanceSnapshot(
      transactions: const [],
      accounts: const [],
      cards: const [],
      loans: const [],
      budgets: [Budget(category: 'Food', limit: 5000)],
      goals: const [],
      subscriptions: const [],
      recurring: const [],
      groups: const [],
      investments: const [],
      tags: const [],
      revision: 1,
      generatedAt: DateTime(2026, 11, 10),
    );

    expect(snapshot.hasTotalBudget, false);
    expect(snapshot.totalBudgetLimit, 5000);
  });
}
