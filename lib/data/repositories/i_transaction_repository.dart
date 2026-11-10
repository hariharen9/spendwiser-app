import '../models/transaction.dart';

abstract interface class ITransactionRepository {
  Future<Transaction> addTransaction(TransactionDraft draft);

  Future<void> updateTransaction(Transaction transaction);

  Future<void> deleteTransaction(String transactionId);

  Future<void> restoreTransaction(Transaction transaction);

  Future<void> addTag(String tag);

  Future<void> deleteTag(String tag);

  Future<void> renameTag(String oldTag, String newTag);

  Future<void> renameCategory(String oldCategory, String newCategory);

  Future<void> deleteCategory(String category);
}
