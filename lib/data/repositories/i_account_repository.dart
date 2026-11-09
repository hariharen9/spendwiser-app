import '../models/account.dart';

abstract interface class IAccountRepository {
  Future<Account> addAccount({
    required String name,
    required AccountType type,
    required double openingBalance,
  });

  Future<void> updateAccount(Account account);

  Future<void> removeAccount(String accountId);

  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
  });
}
