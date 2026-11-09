import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/mock/mock_finance_store.dart';
import 'package:spendwiser_app/data/services/backup_service.dart';

void main() {
  group('Exports', () {
    test('annual summary PDF builds non-empty bytes', () async {
      final store = MockFinanceStore.seeded(now: DateTime(2026, 11, 9, 14, 20));
      final bytes = await BackupService.buildAnnualSummaryPdf(store.current);
      expect(bytes.length, greaterThan(500));
    });

    test('statements XLSX builds non-empty bytes', () {
      final store = MockFinanceStore.seeded(now: DateTime(2026, 11, 9, 14, 20));
      final bytes = BackupService.buildStatementsXlsx(store.current, 'a');
      expect(bytes.length, greaterThan(1000));
    });
  });
}
