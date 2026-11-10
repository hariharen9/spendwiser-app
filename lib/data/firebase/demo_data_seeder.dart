import '../mock/mock_finance_store.dart';
import 'firestore_mappers.dart';
import 'firestore_refs.dart';
import 'firestore_utils.dart';

/// Writes the deterministic demo ledger into Firestore, tagging every document
/// with `isMock: true` so the web app and the app's "Clear mock data" action
/// can remove it without touching real records.
class DemoDataSeeder {
  DemoDataSeeder(this.refs);

  final FirestoreRefs refs;

  Future<void> seed() async {
    final store = MockFinanceStore.seeded(now: DateTime.now());
    final snapshot = store.current;

    final deltas = <String, double>{};
    for (final transaction in snapshot.transactions) {
      final accountId = transaction.cardId ?? transaction.accountId;
      if (accountId == null) continue;
      deltas[accountId] =
          (deltas[accountId] ?? 0) + transaction.amount;
    }

    final paymentDebits = <String, double>{};
    for (final card in snapshot.cards) {
      for (final payment in card.payments) {
        if (payment.accountId.isEmpty) continue;
        paymentDebits[payment.accountId] =
            (paymentDebits[payment.accountId] ?? 0) + payment.amount.abs();
      }
    }

    final batch = refs.db.batch();

    for (final account in snapshot.accounts) {
      final opening = account.balance -
          (deltas[account.id] ?? 0) +
          (paymentDebits[account.id] ?? 0);
      batch.set(refs.accounts.doc(account.id), {
        'name': account.name,
        'type': remoteAccountType(account.remoteType, account.type),
        'balance': opening,
        'isMock': true,
        if (account.last4 != null) 'last4Digits': account.last4,
      });
    }

    for (final card in snapshot.cards) {
      batch.set(refs.accounts.doc(card.id), {
        'name': card.name,
        'type': 'Credit Card',
        'balance': 0,
        'limit': card.limit,
        'last4Digits': card.last4,
        'network': 'other',
        'statementDate': card.statementDay,
        'paymentDueDate': card.dueDay,
        'isMock': true,
      });

      for (final payment in card.payments) {
        final payload = <String, dynamic>{
          'name': 'Credit Card Payment - ${card.name}',
          'amount': -payment.amount.abs(),
          'date': firestoreDate(payment.date),
          'category': 'Payment',
          'type': 'expense',
          'creditCardPaymentId': card.id,
          'createdAt': nowIso(),
          'isMock': true,
        };
        if (payment.accountId.isNotEmpty) {
          payload['accountId'] = payment.accountId;
        }
        batch.set(refs.transactions.doc(), payload);
      }
    }

    for (final transaction in snapshot.transactions) {
      final accountId = transaction.cardId ?? transaction.accountId;
      final payload = <String, dynamic>{
        'name': transaction.merchant,
        'amount': transaction.amount,
        'date': firestoreDate(transaction.date),
        'category': transaction.category,
        'type': transaction.amount >= 0 ? 'income' : 'expense',
        'createdAt': nowIso(),
        'isMock': true,
      };
      if (accountId != null) payload['accountId'] = accountId;
      if (transaction.note.isNotEmpty) payload['comments'] = transaction.note;
      batch.set(refs.transactions.doc(transaction.id), payload);
    }

    for (final budget in snapshot.budgets) {
      batch.set(refs.budgets.doc(), {
        'category': budget.category,
        'limit': budget.limit,
        'spent': 0,
        'isMock': true,
      });
    }

    for (final goal in snapshot.goals) {
      batch.set(refs.goals.doc(), {
        'name': goal.name,
        'targetAmount': goal.target,
        'currentAmount': goal.saved,
        'targetDate': firestoreDate(
          goal.targetDate ?? DateTime.now().add(const Duration(days: 365)),
        ),
        'emoji': goal.emoji,
        'mobileColor': goal.color.toARGB32(),
        'mobileMonthlyContribution': goal.monthlyContribution,
        'isMock': true,
      });
    }

    for (final loan in snapshot.loans) {
      final months = loan.tenureMonths ?? 0;
      batch.set(refs.loans.doc(loan.id), {
        'name': loan.name,
        'loanAmount': loan.original,
        'interestRate': loan.rate,
        'tenure': months ~/ 12,
        'tenureInMonths': months,
        'emi': loan.emi,
        'startDate': firestoreDate(loan.startDate),
        'type': remoteLoanType(loan.type),
        'mobileLender': loan.lender,
        'isMock': true,
      });
    }

    await batch.commit();
    await store.dispose();
  }
}
