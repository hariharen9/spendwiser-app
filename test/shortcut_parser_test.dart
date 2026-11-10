import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/models/shortcut.dart';
import 'package:spendwiser_app/data/services/shortcut_parser.dart';

const coffee = Shortcut(
  id: 's1',
  keyword: 'coffee',
  name: 'Blue Tokai',
  amount: -250,
  category: 'Food & Dining',
  isIncome: false,
  accountId: 'acc1',
);

void main() {
  test('matches keyword.amount case-insensitively', () {
    final match = matchShortcut('COFFEE.320', [coffee]);
    expect(match, isNotNull);
    expect(match!.amount, 320);
    expect(match.shortcut.name, 'Blue Tokai');
    expect(match.shortcut.accountId, 'acc1');
  });

  test('rejects unknown keywords', () {
    expect(matchShortcut('uber.200', [coffee]), isNull);
  });

  test('rejects malformed input', () {
    expect(matchShortcut('coffee', [coffee]), isNull);
    expect(matchShortcut('coffee.abc', [coffee]), isNull);
    expect(matchShortcut('coffee.0', [coffee]), isNull);
    expect(matchShortcut('a.b.250', [coffee]), isNull);
  });
}
