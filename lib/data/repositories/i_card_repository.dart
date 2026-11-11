import '../models/credit_card.dart';

abstract interface class ICardRepository {
  Future<CreditCard> addCard({
    required String name,
    required double limit,
    required String last4,
    required int statementDay,
    required int dueDay,
    String cardHolder = '',
  });

  Future<void> updateCard(CreditCard card);

  Future<void> removeCard(String cardId);

  Future<void> payCardBill({
    required String cardId,
    required double amount,
    required String accountId,
  });
}
