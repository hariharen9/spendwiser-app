import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/firebase/firestore_mappers.dart';
import 'package:spendwiser_app/data/firebase/firestore_utils.dart';
import 'package:spendwiser_app/data/models/account.dart';
import 'package:spendwiser_app/data/models/transaction.dart';
import 'package:spendwiser_app/data/services/finance_calculator.dart';

void main() {
  group('transaction mapping', () {
    test('reads the web shape', () {
      final transaction = transactionFromDoc(
        'tx1',
        {
          'name': 'Swiggy',
          'amount': -240.0,
          'date': '2026-11-10',
          'category': 'Food & Dining',
          'type': 'expense',
          'accountId': 'acc1',
          'comments': 'Lunch',
          'tags': ['tag1'],
        },
        cardIds: const {},
        tagIdToName: const {'tag1': 'Work'},
      );

      expect(transaction.merchant, 'Swiggy');
      expect(transaction.amount, -240);
      expect(transaction.category, 'Food & Dining');
      expect(transaction.date, DateTime(2026, 11, 10, 12));
      expect(transaction.accountId, 'acc1');
      expect(transaction.cardId, isNull);
      expect(transaction.note, 'Lunch');
      expect(transaction.tags, ['Work']);
    });

    test('routes a card account to cardId', () {
      final transaction = transactionFromDoc(
        'tx2',
        {
          'name': 'Amazon',
          'amount': -1000,
          'date': '2026-11-10',
          'category': 'Shopping',
          'accountId': 'card1',
        },
        cardIds: const {'card1'},
        tagIdToName: const {},
      );

      expect(transaction.accountId, isNull);
      expect(transaction.cardId, 'card1');
    });

    test('writes signed type and maps tags to ids', () {
      final payload = transactionCreatePayload(
        TransactionDraft(
          merchant: 'Salary',
          category: 'Income',
          amount: 50000,
          date: DateTime(2026, 11, 1),
          accountId: 'acc1',
          tags: const ['Work'],
        ),
        tagNameToId: const {'Work': 'tag1'},
      );

      expect(payload['type'], 'income');
      expect(payload['date'], '2026-11-01');
      expect(payload['tags'], ['tag1']);
      expect(payload['accountId'], 'acc1');
    });
  });

  group('account mapping', () {
    test('maps web account types while preserving remoteType', () {
      final wallet = accountFromDoc(
        'acc1',
        {'name': 'Paytm', 'type': 'Wallet', 'balance': 500},
        liveBalance: 750,
      );

      expect(wallet.type, AccountType.cash);
      expect(wallet.remoteType, 'Wallet');
      expect(wallet.balance, 750);
    });
  });

  group('derived card balance', () {
    test('matches the web outstanding formula', () {
      final card = creditCardFromDoc(
        'card1',
        {
          'name': 'Axis',
          'type': 'Credit Card',
          'limit': 100000,
          'statementDate': 5,
          'paymentDueDate': 23,
        },
        paymentDocs: [
          {'amount': -2000, 'date': '2026-11-01', 'accountId': 'bank1'},
        ],
        now: DateTime(2026, 11, 10),
      );
      final transactions = [
        Transaction(
          id: 't1',
          merchant: 'Spend',
          category: 'Shopping',
          amount: -5000,
          date: DateTime(2026, 10, 20),
          cardId: 'card1',
        ),
      ];

      FinanceCalculator.recalcCard(card, transactions, now: DateTime(2026, 11, 10));
      expect(card.outstanding, 3000);
    });
  });

  group('loan mapping', () {
    test('derives outstanding from payment transactions', () {
      final loan = loanFromDoc(
        'loan1',
        {
          'name': 'Car Loan',
          'loanAmount': 600000,
          'interestRate': 9,
          'tenure': 5,
          'tenureInMonths': 60,
          'emi': 12455,
          'startDate': '2025-01-10',
          'type': 'auto',
        },
        paymentDocs: [
          {'amount': -12455, 'date': '2025-02-10'},
        ],
        now: DateTime(2026, 11, 10),
      );

      expect(loan.original, 600000);
      expect(loan.tenureMonths, 60);
      expect(loan.payments.length, 1);
      expect(loan.outstanding, lessThan(600000));
      expect(loan.outstanding, greaterThan(0));
    });
  });

  group('recurring mapping', () {
    test('creates a subscription view for active monthly expenses', () {
      final rule = recurringFromDoc('rule1', {
        'name': 'Netflix',
        'amount': -649,
        'category': 'Entertainment',
        'type': 'expense',
        'frequency': 'monthly',
        'startDate': '2026-01-01',
        'lastProcessedDate': '2026-11-01',
        'isPaused': false,
      });

      expect(rule.isIncome, false);
      expect(rule.active, true);

      final subscription = subscriptionFromRecurring(
        rule,
        now: DateTime(2026, 11, 10),
      );
      expect(subscription, isNotNull);
      expect(subscription!.price, 649);
      expect(subscription.recurringId, 'rule1');
    });
  });

  group('split mapping', () {
    test('maps members, splits, and settlements with stable history', () {
      final mapped = splitGroupFromDocs(
        id: 'g1',
        data: {
          'name': 'Goa Trip',
          'participantIds': ['p1', '1'],
        },
        participantNames: const {'1': 'You', 'p1': 'Rohan'},
        expenseDocs: [
          MapEntry('e1', {
            'description': 'Beach dinner',
            'amount': 3200.0,
            'paidBy': '1',
            'splitType': 'equal',
            'splits': [
              {'participantId': '1', 'amount': 1600.0},
              {'participantId': 'p1', 'amount': 1600.0},
            ],
            'date': '2026-10-16',
          }),
        ],
        settledDocs: [
          MapEntry('s1', {
            'from': 'p1',
            'to': '1',
            'amount': 1600.0,
            'createdAt': '2026-10-17',
          }),
        ],
      );

      expect(mapped.group.members, ['You', 'Rohan']);
      expect(mapped.group.expenses.length, 2);
      expect(mapped.group.expenses.first.shares['Rohan'], 1600);
      expect(mapped.group.expenses.last.isSettlement, true);
      expect(mapped.history.map((entry) => entry.id).toList(), ['e1', 's1']);
      expect(mapped.group.netBalances()['You'], 0);
      expect(mapped.group.netBalances()['Rohan'], 0);
    });
  });

  group('shortcut mapping', () {
    test('maps the web shortcut shape', () {
      final shortcut = shortcutFromDoc('s1', {
        'keyword': 'coffee',
        'name': 'Blue Tokai',
        'amount': -250,
        'category': 'Food & Dining',
        'type': 'expense',
        'accountId': 'acc1',
      });

      expect(shortcut.keyword, 'coffee');
      expect(shortcut.name, 'Blue Tokai');
      expect(shortcut.amount, -250);
      expect(shortcut.isIncome, false);
      expect(shortcut.category, 'Food & Dining');
      expect(shortcut.accountId, 'acc1');
    });
  });

  group('date helpers', () {
    test('round-trips YYYY-MM-DD at local noon', () {
      final date = DateTime(2026, 11, 9);
      expect(firestoreDate(date), '2026-11-09');
      expect(parseFirestoreDate('2026-11-09'), DateTime(2026, 11, 9, 12));
    });
  });
}
