import '../models/transaction.dart';

abstract interface class ITransactionRepository {
  Future<Transaction> addTransaction(TransactionDraft draft);

  Future<void> updateTransaction(Transaction transaction);

  Future<void> deleteTransaction(String transactionId);
}
