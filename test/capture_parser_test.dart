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

    test('unknown merchants are not forced into Food', () {
      final p = CaptureParser.parse('foobar 100');
      expect(p, isNotNull);
      expect(p!.category, 'Other');
      expect(p.categoryDetected, false);
    });

    test('maps misc and mis to Miscellaneous', () {
      final p1 = CaptureParser.parse('misc 100');
      expect(p1, isNotNull);
      expect(p1!.category, 'Miscellaneous');
      expect(p1.categoryDetected, true);

      final p2 = CaptureParser.parse('mis 50');
      expect(p2, isNotNull);
      expect(p2!.category, 'Miscellaneous');
      expect(p2.categoryDetected, true);
    });

    test('auto-categorises Indian merchants and everyday expenses', () {
      expect(CaptureParser.parse('biryani 320')!.category, 'Food');
      expect(CaptureParser.parse('chaayos 180')!.category, 'Food');
      expect(CaptureParser.parse('kirana 450')!.category, 'Food');
      expect(CaptureParser.parse('petrol 1500')!.category, 'Fuel');
      expect(CaptureParser.parse('indianoil 2000')!.category, 'Fuel');
      expect(CaptureParser.parse('namma yatri 140')!.category, 'Travel');
      expect(CaptureParser.parse('irctc 1250')!.category, 'Travel');
      expect(CaptureParser.parse('bescom 1850')!.category, 'Utilities');
      expect(CaptureParser.parse('jiofiber 999')!.category, 'Utilities');
      expect(CaptureParser.parse('nobroker 18000')!.category, 'Rent & Housing');
      expect(CaptureParser.parse('pharmeasy 640')!.category, 'Healthcare');
      expect(CaptureParser.parse('zerodha 5000')!.category, 'Investment');
      expect(CaptureParser.parse('urban company 799')!.category, 'Personal');
      expect(CaptureParser.parse('unacademy 3000')!.category, 'Education');
      expect(CaptureParser.parse('zudio 1200')!.category, 'Shop');
      expect(CaptureParser.parse('hotstar 299')!.category, 'Fun');
      expect(CaptureParser.parse('cred 4500')!.category, 'EMI');
      expect(CaptureParser.parse('temple 101')!.category, 'Miscellaneous');
    });

    test('rejects text that is not a receipt', () {
      final result = CaptureParser.parseReceipt(
        'Had a nice walk today. Total steps 4200.',
      );
      expect(result.isReceipt, false);
      expect(result.capture, isNull);
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
