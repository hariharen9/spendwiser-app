import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/core/utils/date_helpers.dart';
import 'package:spendwiser_app/data/models/transaction.dart';

void main() {
  group('transaction timing', () {
    test('formats local added time', () {
      expect(clockTime(DateTime(2026, 11, 10, 15, 4)), '3:04 PM');
      expect(clockTime(DateTime(2026, 11, 10, 0, 9)), '12:09 AM');
    });

    test('newly added entries lead same-day legacy rows', () {
      final legacy = Transaction(
        id: 'tx-legacy',
        merchant: 'Legacy',
        category: 'Food',
        amount: -100,
        date: DateTime(2026, 11, 10, 18),
      );
      final added = Transaction(
        id: 'tx-added',
        merchant: 'Added',
        category: 'Food',
        amount: -100,
        date: DateTime(2026, 11, 10, 12),
        addedAt: DateTime(2026, 11, 10, 9, 5),
      );

      final list = [legacy, added]..sort(compareTransactionsNewestFirst);
      expect(list.first.id, 'tx-added');
      expect(added.addedTimeLabel, '9:05 AM');
    });

    test('legacy rows without addedAt still round-trip', () {
      final original = Transaction(
        id: 'tx-1',
        merchant: 'Web row',
        category: 'Other',
        amount: -250,
        date: DateTime(2026, 11, 10),
      );

      final restored = Transaction.fromJson(original.toJson());
      expect(restored.addedAt, isNull);
      expect(restored.addedTimeLabel, isNull);
      expect(restored.date, original.date);
    });
  });
}
