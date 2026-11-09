import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/features/home/services/capture_parser.dart';

void main() {
  group('CaptureParser', () {
    test('parses simple text and amount', () {
      final p1 = CaptureParser.parse('chai 40');
      expect(p1, isNotNull);
      expect(p1!.amount, 40);
      expect(p1.merchant, 'Chai');
      expect(p1.category, 'Food');
      expect(p1.isIncome, false);

      final p2 = CaptureParser.parse('uber 280');
      expect(p2, isNotNull);
      expect(p2!.amount, 280);
      expect(p2.merchant, 'Uber');
      expect(p2.category, 'Travel');
      expect(p2.isIncome, false);
    });

    test('parses natural phrases and amounts with symbols', () {
      final p = CaptureParser.parse('spent ₹1,200 on dinner');
      expect(p, isNotNull);
      expect(p!.amount, 1200);
      expect(p.merchant, 'Dinner');
      expect(p.category, 'Food');
      expect(p.isIncome, false);
    });

    test('parses spoken number words', () {
      final p = CaptureParser.parse('zomato four eighty six');
      expect(p, isNotNull);
      expect(p!.amount, 486);
      expect(p.merchant, 'Zomato');
      expect(p.category, 'Food');
    });

    test('parses income transactions', () {
      final p = CaptureParser.parse('salary 50000');
      expect(p, isNotNull);
      expect(p!.amount, 50000);
      expect(p.isIncome, true);
      expect(p.category, 'Income');
    });

    test('parses receipt text with items and total', () {
      const receipt = '''
Blinkit Commerce Pvt Ltd
Amul Gold Milk 500ml x2  128.00
Farm Fresh Eggs 12pk     96.00
Daawat Basmati Rice 5kg  520.00
Delivery Fee              98.00
Total Amount Payable    ₹842.00
''';
      final p = CaptureParser.parseReceiptText(receipt);
      expect(p.merchant, 'Blinkit Commerce Pvt Ltd');
      expect(p.amount, 842);
      expect(p.category, 'Food');
      expect(p.items.length, greaterThanOrEqualTo(2));
    });
  });
}

