import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/models/account.dart';
import 'package:spendwiser_app/data/models/finance_snapshot.dart';
import 'package:spendwiser_app/data/models/subscription.dart';
import 'package:spendwiser_app/data/models/transaction.dart';
import 'package:spendwiser_app/data/services/finance_calculator.dart';

void main() {
  group('Intelligent CashRunway', () {
    test(
      'front-loaded rent & bills do not inflate daily spend into false shortfall',
      () {
        final now = DateTime(2026, 11, 12);
        final snapshot = FinanceSnapshot(
          accounts: const [
            Account(
              id: 'a1',
              name: 'HDFC Savings',
              type: AccountType.savings,
              balance: 50000,
            ),
          ],
          cards: const [],
          loans: const [],
          budgets: const [],
          goals: const [],
          subscriptions: const [],
          recurring: [
            RecurringTransaction(
              id: 'r_salary',
              name: 'Salary',
              amount: 100000,
              frequency: RecurringFrequency.monthly,
              isIncome: true,
              active: true,
              lastProcessedDate: DateTime(2026, 11, 1),
            ),
            RecurringTransaction(
              id: 'r_rent',
              name: 'House Rent',
              amount: 25000,
              frequency: RecurringFrequency.monthly,
              isIncome: false,
              active: true,
              startDate: DateTime(2026, 11, 2),
            ),
          ],
          groups: const [],
          investments: const [],
          tags: const [],
          revision: 1,
          generatedAt: now,
          transactions: [
            // Front-loaded rent + bills at start of month (₹35,000 total)
            Transaction(
              id: 't1',
              merchant: 'House Rent',
              category: 'Rent & Housing',
              amount: -25000,
              date: DateTime(2026, 11, 2),
              accountId: 'a1',
            ),
            Transaction(
              id: 't2',
              merchant: 'BESCOM',
              category: 'Utilities',
              amount: -5000,
              date: DateTime(2026, 11, 3),
              accountId: 'a1',
            ),
            Transaction(
              id: 't3',
              merchant: 'Car EMI',
              category: 'EMI',
              amount: -5000,
              date: DateTime(2026, 11, 4),
              accountId: 'a1',
            ),
            // Realistic variable daily spend (~₹500/day)
            for (var d = 5; d <= 11; d++)
              Transaction(
                id: 'td_$d',
                merchant: 'Lunch',
                category: 'Food & Dining',
                amount: -500,
                date: DateTime(2026, 11, d),
                accountId: 'a1',
              ),
          ],
        );

        final runway = FinanceCalculator.cashRunway(snapshot, now: now);

        // Typical daily spend should reflect ~₹500/day variable burn, not ₹3,500+/day
        expect(runway.dailySpend, lessThan(600));
        // Already-paid rent this month should not be double-counted
        expect(runway.totalBills, 0);
        // With ₹50,000 cash and ~₹500/day over 19 days to 1 Dec payday, user stays well covered
        expect(runway.isShortfall, false);
        expect(runway.lowestBalance, greaterThan(35000));
      },
    );

    test('one-off outlier purchase is winsorized and does not skew daily burn', () {
      final now = DateTime(2026, 11, 20);
      final snapshot = FinanceSnapshot(
        accounts: const [
          Account(
            id: 'a1',
            name: 'HDFC Savings',
            type: AccountType.savings,
            balance: 40000,
          ),
        ],
        cards: const [],
        loans: const [],
        budgets: const [],
        goals: const [],
        subscriptions: const [],
        recurring: const [],
        groups: const [],
        investments: const [],
        tags: const [],
        revision: 1,
        generatedAt: now,
        transactions: [
          for (var d = 1; d <= 19; d++)
            Transaction(
              id: 't_$d',
              merchant: 'Groceries',
              category: 'Groceries',
              amount: -400,
              date: DateTime(2026, 11, d),
              accountId: 'a1',
            ),
          // One-off ₹45,000 laptop purchase
          Transaction(
            id: 't_spike',
            merchant: 'Apple Store',
            category: 'Shopping',
            amount: -45000,
            date: DateTime(2026, 11, 10),
            accountId: 'a1',
          ),
        ],
      );

      final daily = FinanceCalculator.discretionaryDailySpend(
        snapshot,
        now: now,
      );
      // Without winsorizing, (19*400 + 45000)/20 = ₹2,630/day.
      // With winsorizing, spike is capped so daily burn stays reasonable (~₹500/day).
      expect(daily, lessThan(600));
    });

    test(
      'learns month-phase spending so start-of-month spikes do not skew mid/late month',
      () {
        final now = DateTime(2026, 11, 12);
        final txs = <Transaction>[];
        for (final m in [9, 10, 11]) {
          // Early month (days 1..5): heavy ₹4,000/day variable spend
          for (var d = 1; d <= 5; d++) {
            txs.add(
              Transaction(
                id: 'e_${m}_$d',
                merchant: 'Household Stockup',
                category: 'Shopping',
                amount: -4000,
                date: DateTime(2026, m, d),
                accountId: 'a1',
              ),
            );
          }
          // Mid/late month (days 8..30): light ₹400/day variable spend
          final maxDay = m == 11 ? 12 : 30;
          for (var d = 8; d <= maxDay; d++) {
            txs.add(
              Transaction(
                id: 'l_${m}_$d',
                merchant: 'Chai & Lunch',
                category: 'Food',
                amount: -400,
                date: DateTime(2026, m, d),
                accountId: 'a1',
              ),
            );
          }
        }

        final snapshot = FinanceSnapshot(
          accounts: const [
            Account(
              id: 'a1',
              name: 'HDFC Savings',
              type: AccountType.savings,
              balance: 25000,
            ),
          ],
          cards: const [],
          loans: const [],
          budgets: const [],
          goals: const [],
          subscriptions: const [],
          recurring: [
            RecurringTransaction(
              id: 'r_salary',
              name: 'Salary',
              amount: 100000,
              frequency: RecurringFrequency.monthly,
              isIncome: true,
              active: true,
              lastProcessedDate: DateTime(2026, 11, 1),
            ),
          ],
          groups: const [],
          investments: const [],
          tags: const [],
          revision: 1,
          generatedAt: now,
          transactions: txs,
        );

        final runway = FinanceCalculator.cashRunway(snapshot, now: now);
        // Remaining window (Nov 12..Dec 1) uses mid/late-month rate (~₹400/day),
        // not the early-month ₹4,000/day rate.
        expect(runway.dailySpend, lessThan(800));
        expect(runway.isShortfall, isFalse);
      },
    );

    test(
      'auto-detects unregistered monthly bills: schedules unpaid ones and skips paid ones',
      () {
        final now = DateTime(2026, 11, 12);
        final snapshot = FinanceSnapshot(
          accounts: const [
            Account(
              id: 'a1',
              name: 'HDFC Savings',
              type: AccountType.savings,
              balance: 40000,
            ),
          ],
          cards: const [],
          loans: const [],
          budgets: const [],
          goals: const [],
          subscriptions: const [],
          recurring: [
            RecurringTransaction(
              id: 'r_salary',
              name: 'Salary',
              amount: 100000,
              frequency: RecurringFrequency.monthly,
              isIncome: true,
              active: true,
              lastProcessedDate: DateTime(2026, 11, 1),
            ),
          ],
          groups: const [],
          investments: const [],
          tags: const [],
          revision: 1,
          generatedAt: now,
          transactions: [
            // Unpaid upcoming monthly pattern: Maid on 18th (Sep & Oct, not yet Nov)
            Transaction(
              id: 'maid_9',
              merchant: 'Maid Salary',
              category: 'Personal',
              amount: -4000,
              date: DateTime(2026, 9, 18),
              accountId: 'a1',
            ),
            Transaction(
              id: 'maid_10',
              merchant: 'Maid Salary',
              category: 'Personal',
              amount: -4000,
              date: DateTime(2026, 10, 18),
              accountId: 'a1',
            ),
            // Already-paid monthly pattern: Broadband on 3rd (Sep, Oct, AND Nov)
            Transaction(
              id: 'bb_9',
              merchant: 'Airtel Fiber',
              category: 'Utilities',
              amount: -1200,
              date: DateTime(2026, 9, 3),
              accountId: 'a1',
            ),
            Transaction(
              id: 'bb_10',
              merchant: 'Airtel Fiber',
              category: 'Utilities',
              amount: -1200,
              date: DateTime(2026, 10, 3),
              accountId: 'a1',
            ),
            Transaction(
              id: 'bb_11',
              merchant: 'Airtel Fiber',
              category: 'Utilities',
              amount: -1200,
              date: DateTime(2026, 11, 3),
              accountId: 'a1',
            ),
          ],
        );

        final runway = FinanceCalculator.cashRunway(snapshot, now: now);
        final labels = runway.events.map((e) => e.label).toList();
        expect(labels, contains('Maid Salary'));
        expect(labels, isNot(contains('Airtel Fiber')));
      },
    );
  });
}
