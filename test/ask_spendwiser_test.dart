import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/mock/mock_finance_store.dart';
import 'package:spendwiser_app/data/models/app_settings.dart';
import 'package:spendwiser_app/data/models/finance_snapshot.dart';
import 'package:spendwiser_app/data/models/transaction.dart';
import 'package:spendwiser_app/features/insights/services/ask_ai_client.dart';
import 'package:spendwiser_app/features/insights/services/local_ask_engine.dart';

void main() {
  group('LocalAskEngine', () {
    test('answers OS-level intents (cash runway, card dues, compare)', () {
      final now = DateTime(2026, 11, 9);
      final snapshot = MockFinanceStore.seeded(now: now).current;

      final runway = LocalAskEngine.answer(
        snapshot,
        'What is my cash runway?',
        now: now,
      );
      expect(runway.headline, startsWith('Cash runway'));
      expect(runway.amount, isNotNull);
      expect(runway.bars, isNotEmpty);
      expect(runway.isHighConfidence, isTrue);

      final cards = LocalAskEngine.answer(
        snapshot,
        'Credit card dues',
        now: now,
      );
      expect(cards.headline, 'Credit card dues');
      expect(cards.amount, snapshot.cardDues);

      final compare = LocalAskEngine.answer(
        snapshot,
        'Compare vs last month',
        now: now,
      );
      expect(compare.headline, 'This month vs last month');
      expect(compare.bars.length, 2);
    });

    test('matches unbudgeted categories, specific months, and multi-word merchants', () {
      final now = DateTime(2026, 11, 12);
      final base = MockFinanceStore.seeded(now: now).current;
      final snapshot = FinanceSnapshot(
        accounts: base.accounts,
        cards: base.cards,
        loans: base.loans,
        budgets: base.budgets,
        goals: base.goals,
        subscriptions: base.subscriptions,
        recurring: base.recurring,
        groups: base.groups,
        investments: base.investments,
        tags: base.tags,
        revision: base.revision,
        generatedAt: base.generatedAt,
        transactions: [
          ...base.transactions,
          Transaction(
            id: 'tx_misc',
            merchant: 'Tata Power',
            category: 'Miscellaneous',
            amount: -1850,
            date: DateTime(2026, 10, 15),
            accountId: base.accounts.first.id,
          ),
        ],
      );

      final miscOct = LocalAskEngine.answer(
        snapshot,
        'Miscellaneous in October',
        knownCategories: const ['Miscellaneous', 'Food'],
        now: now,
      );
      expect(miscOct.amount, 1850);
      expect(miscOct.headline, contains('Miscellaneous'));
      expect(miscOct.headline, contains('October 2026'));
      expect(miscOct.ledgerPrefill?.category, 'Miscellaneous');

      final tata = LocalAskEngine.answer(
        snapshot,
        'Tata Power October',
        now: now,
      );
      expect(tata.amount, 1850);
      expect(tata.headline, contains('Tata Power'));
      expect(tata.ledgerPrefill?.query, 'Tata Power');
    });

    test('flags open-ended conversational queries as low confidence for AI routing', () {
      final now = DateTime(2026, 11, 9);
      final snapshot = MockFinanceStore.seeded(now: now).current;

      final advice = LocalAskEngine.answer(
        snapshot,
        'Why did I spend so much and how can I save ₹5,000?',
        now: now,
      );
      expect(advice.isHighConfidence, isFalse);
    });

    test('supports list of spends in last 2 days, #tag, and custom date ranges', () {
      final now = DateTime(2026, 11, 12);
      final base = MockFinanceStore.seeded(now: now).current;
      final snapshot = FinanceSnapshot(
        accounts: base.accounts,
        cards: base.cards,
        loans: base.loans,
        budgets: base.budgets,
        goals: base.goals,
        subscriptions: base.subscriptions,
        recurring: base.recurring,
        groups: base.groups,
        investments: base.investments,
        tags: base.tags,
        revision: base.revision,
        generatedAt: base.generatedAt,
        transactions: [
          Transaction(
            id: 'd1',
            merchant: 'Blue Tokai',
            category: 'Food',
            amount: -320,
            date: DateTime(2026, 11, 11),
            accountId: base.accounts.first.id,
            tags: const ['trip'],
          ),
          Transaction(
            id: 'd2',
            merchant: 'Uber',
            category: 'Transport',
            amount: -480,
            date: DateTime(2026, 11, 12),
            accountId: base.accounts.first.id,
            tags: const ['trip'],
          ),
          Transaction(
            id: 'old',
            merchant: 'Zomato',
            category: 'Food',
            amount: -900,
            date: DateTime(2026, 11, 5),
            accountId: base.accounts.first.id,
          ),
        ],
      );

      final last2 = LocalAskEngine.answer(
        snapshot,
        'Spends in last 2 days',
        now: now,
      );
      expect(last2.amount, 800);
      expect(last2.bars.length, 2);
      expect(last2.bars.first.label, 'Uber');

      final tagged = LocalAskEngine.answer(
        snapshot,
        'Transactions in #trip',
        now: now,
      );
      expect(tagged.amount, 800);
      expect(tagged.headline.toLowerCase(), contains('#trip'));

      final range = LocalAskEngine.answer(
        snapshot,
        'Spends from 1 Nov to 10 Nov',
        now: now,
      );
      expect(range.amount, 900);
      expect(range.bars.single.label, 'Zomato');
    });
  });

  group('AskAiClient & AppSettings BYOK', () {
    test('buildContext produces valid compact JSON briefing', () {
      final now = DateTime(2026, 11, 9);
      final snapshot = MockFinanceStore.seeded(now: now).current;
      final raw = AskAiClient.buildContext(
        snapshot,
        query: 'How is my cash runway and Swiggy spend?',
        now: now,
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['netWorth'], isNotNull);
      expect(decoded['cashRunway'], isA<Map>());
      expect(decoded['cards'], isA<List>());
      expect(decoded['loans'], isA<List>());
      expect(decoded['budgets'], isA<List>());
      expect(decoded['goals'], isA<List>());
      expect(decoded['subscriptions'], isA<List>());
      expect(decoded['matchingTransactions'], isA<List>());
    });

    test('parseReply extracts log_tx, add_budget, and add_goal action blocks', () {
      final txReply = AskAiClient.parseReply('''
Logged your chai!
```action
{"action":"log_tx","merchant":"Chai Point","amount":40,"category":"Food","isIncome":false,"note":"Evening tea"}
```
''');
      expect(txReply.text, 'Logged your chai!');
      expect(txReply.action?.type, AiActionType.logTx);
      expect(txReply.action?.title, 'Chai Point');
      expect(txReply.action?.amount, 40);
      expect(txReply.action?.category, 'Food');

      final budgetReply = AskAiClient.parseReply('''
Created a Goa trip budget.
```action
{"action":"add_budget","category":"Travel","amount":25000}
```
''');
      expect(budgetReply.text, 'Created a Goa trip budget.');
      expect(budgetReply.action?.type, AiActionType.addBudget);
      expect(budgetReply.action?.amount, 25000);
      expect(budgetReply.action?.category, 'Travel');

      final goalReply = AskAiClient.parseReply('''
Added your emergency fund goal.
```action
{"action":"add_goal","title":"Emergency Fund","amount":150000}
```
''');
      expect(goalReply.action?.type, AiActionType.addGoal);
      expect(goalReply.action?.title, 'Emergency Fund');
      expect(goalReply.action?.amount, 150000);
    });

    test('AppSettings persists AI provider, key, and model through JSON', () {
      const settings = AppSettings(
        aiProvider: AiProvider.openrouter,
        aiApiKey: 'sk-or-v1-test',
        aiModel: 'openrouter/free',
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.aiProvider, AiProvider.openrouter);
      expect(restored.aiApiKey, 'sk-or-v1-test');
      expect(restored.aiModel, 'openrouter/free');
      expect(restored.hasAiKey, isTrue);
    });
  });
}
