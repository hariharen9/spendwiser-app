import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/core/state/providers.dart';

void main() {
  test('account edits update the snapshot and net worth', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(financeSnapshotProvider);
    final account = before.accounts.first;
    final beforeWorth = before.netWorth;

    await container
        .read(accountRepositoryProvider)
        .updateAccount(account.copyWith(balance: account.balance + 1000));

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final after = container.read(financeSnapshotProvider);
    expect(after.netWorth, closeTo(beforeWorth + 1000, 0.01));
  });
}
