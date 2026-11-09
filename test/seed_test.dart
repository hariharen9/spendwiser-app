import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/mock/mock_finance_store.dart';
import 'package:spendwiser_app/data/services/finance_calculator.dart';

void main() {
  test('seed matches the reference prototype snapshot', () async {
    final store = MockFinanceStore.seeded(now: DateTime(2026, 11, 9, 14, 20));
    final s = store.current;

    expect(s.transactions.length, 152);
    expect(s.netWorth, 1054100);
    expect(s.cardDues, 25660);
    expect(s.loanOutstanding, 2720000);
    expect(s.totalBudgetLimit, 88000);
    expect(s.totalBudgetSpent, 61780);

    final safe = FinanceCalculator.safeToSpend(s, now: DateTime(2026, 11, 9));
    expect(safe.perDay, 1190);
    expect(safe.daysLeft, 22);

    final icici = s.cards.first;
    expect(icici.outstanding, 14170);
    expect(icici.due?.amount, 4130);
    expect(icici.minimumDue, 210);
    expect(icici.due?.days, 3);

    final flow = s.flow(DateTime(2026, 11, 1));
    expect(flow.income, 142000);
    expect(flow.expense, 86280);

    final health = FinanceCalculator.health(s, now: DateTime(2026, 11, 9));
    expect(health.score, 61);

    expect(FinanceCalculator.streak(s, now: DateTime(2026, 11, 9)), 5);
  });
}
