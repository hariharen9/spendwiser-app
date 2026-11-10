import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/services/backup_codec.dart';
import 'package:spendwiser_app/data/services/backup_service.dart';

void main() {
  group('normalizeBackupPayload', () {
    test('reads the web Restore shape', () {
      final normalized = normalizeBackupPayload({
        'transactions': [
          {
            'id': 't1',
            'name': 'Tea',
            'amount': -20,
            'date': '2026-11-01',
            'type': 'expense',
          },
        ],
        'accounts': [
          {'id': 'a1', 'name': 'Bank', 'type': 'Bank', 'balance': 1000},
        ],
        'settings': {
          'darkMode': true,
          'currency': '₹',
          'defaultAccountId': 'a1',
          'fontPreference': 'Montserrat',
        },
        'userCategories': ['Food & Dining', 'Other'],
        'metadata': {'backupDate': '2026-11-10', 'version': '1.0.0'},
      });

      expect(normalized.transactions?.length, 1);
      expect(normalized.transactions?.first.id, 't1');
      expect(normalized.transactions?.first.data['name'], 'Tea');
      expect(normalized.accounts?.first.data['balance'], 1000);
      expect(normalized.webSettings?['darkMode'], true);
      expect(normalized.categories, ['Food & Dining', 'Other']);
      expect(normalized.hasBillSplitting, false);
    });

    test('reads the migration entities shape', () {
      final normalized = normalizeBackupPayload({
        'app': 'spendwiser',
        'version': 1,
        'entities': {
          'transactions': [
            {'id': 't1', 'name': 'Tea', 'amount': -20, 'date': '2026-11-01'},
          ],
          'accounts': const [],
          'budgets': const [],
          'goals': const [],
          'loans': const [],
          'recurringTransactions': const [],
          'shortcuts': [
            {
              'id': 's1',
              'keyword': 'tea',
              'name': 'Tea',
              'amount': -20,
              'category': 'Food & Dining',
              'type': 'expense',
            },
          ],
          'pendingTransactions': const [],
          'billSplitting': {
            'participants': [
              {'id': 'p1', 'name': 'Rohan'},
            ],
            'groups': [
              {
                'id': 'g1',
                'name': 'Goa',
                'participantIds': ['p1'],
                'createdAt': '2026-10-15T10:00:00.000Z',
              },
            ],
            'expenses': [
              {
                'groupId': 'g1',
                'docId': 'e1',
                'data': {
                  'description': 'Dinner',
                  'amount': 3200,
                  'paidBy': '1',
                  'splitType': 'equal',
                  'splits': const [],
                  'date': '2026-10-16',
                  'createdAt': '2026-10-16T21:30:00.000Z',
                },
              },
            ],
          },
          'totalBudget': [
            {'id': 'current', 'limit': 60000, 'month': '2026-11'},
          ],
        },
        'settings': {
          'userDoc': {
            'name': 'Test',
            'categories': ['Food & Dining'],
          },
        },
        'metadata': {'uid': 'u1'},
      });

      expect(normalized.transactions?.length, 1);
      expect(normalized.shortcuts?.length, 1);
      expect(normalized.userDoc?['name'], 'Test');
      expect(normalized.categories, ['Food & Dining']);
      expect(normalized.hasBillSplitting, true);
      expect(normalized.groups.length, 1);
      expect(normalized.expenses.length, 1);
      expect(normalized.expenses.first.groupId, 'g1');
      expect(normalized.totalBudget?.id, 'current');
      expect(normalized.totalBudget?.data['limit'], 60000);
    });

    test('reads the older app finance shape', () {
      final normalized = normalizeBackupPayload({
        'app': 'spendwiser',
        'version': 1,
        'finance': {
          'transactions': [
            {'id': 't1', 'name': 'Tea', 'amount': -20},
          ],
          'totalBudget': {'limit': 1000, 'month': '2026-11'},
        },
        'settings': {
          'theme': 'dark',
          'userName': 'X',
          'categories': {'Food': 0xFFFF0000},
        },
      });

      expect(normalized.transactions?.length, 1);
      expect(normalized.appSettings?['theme'], 'dark');
      expect(normalized.totalBudget?.data['limit'], 1000);
    });
  });

  group('parseBackup', () {
    test('accepts all three shapes', () {
      expect(
        () => BackupService.parseBackup(
          jsonEncode({
            'transactions': const [],
            'accounts': const [],
          }),
        ),
        returnsNormally,
      );
      expect(
        () => BackupService.parseBackup(
          jsonEncode({
            'app': 'spendwiser',
            'version': 1,
            'entities': const {},
          }),
        ),
        returnsNormally,
      );
      expect(
        () => BackupService.parseBackup(
          jsonEncode({
            'app': 'spendwiser',
            'version': 1,
            'finance': const {},
          }),
        ),
        returnsNormally,
      );
    });

    test('rejects unrelated JSON', () {
      expect(
        () => BackupService.parseBackup(jsonEncode({'foo': 'bar'})),
        throwsFormatException,
      );
    });
  });
}
