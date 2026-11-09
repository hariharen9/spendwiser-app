import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/mock/mock_finance_store.dart';
import 'package:spendwiser_app/data/models/transaction.dart';

void main() {
  group('Standalone persistence', () {
    test('state export/import round-trips the full ledger', () {
      Map<String, dynamic>? saved;
      final store = MockFinanceStore.seeded(
        now: DateTime(2026, 11, 9, 14, 20),
        saveState: (state) => saved = state,
      );

      expect(saved, isNotNull);
      final first = store.current;
      expect(first.transactions.length, 152);

      final restored = MockFinanceStore.seeded(loadState: () => saved);
      final second = restored.current;

      expect(second.transactions.length, first.transactions.length);
      expect(second.netWorth, first.netWorth);
      expect(second.cardDues, first.cardDues);
      expect(second.loanOutstanding, first.loanOutstanding);
      expect(second.totalBudgetLimit, first.totalBudgetLimit);
      expect(second.accounts.length, first.accounts.length);
      expect(second.cards.length, first.cards.length);
      expect(second.loans.length, first.loans.length);
      expect(second.goals.length, first.goals.length);
      expect(second.subscriptions.length, first.subscriptions.length);
      expect(second.groups.length, first.groups.length);
    });

    test('new transactions survive a simulated restart', () async {
      Map<String, dynamic>? saved;
      final store = MockFinanceStore.seeded(
        now: DateTime(2026, 11, 9, 14, 20),
        saveState: (state) => saved = state,
      );

      final before = store.current.netWorth;
      await store.addTransaction(
        TransactionDraft(
          merchant: 'Persisted Chai',
          category: 'Food',
          amount: -50,
          accountId: 'hdfc',
          date: DateTime(2026, 11, 9, 15),
        ),
      );

      final restored = MockFinanceStore.seeded(loadState: () => saved);
      final after = restored.current;
      expect(after.transactions.length, store.current.transactions.length);
      expect(after.netWorth, before - 50);
      expect(
        after.transactions.any((t) => t.merchant == 'Persisted Chai'),
        isTrue,
      );
    });
  });
}
