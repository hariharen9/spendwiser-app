import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/data/sms/bank_sms_parser.dart';
import 'package:spendwiser_app/data/sms/sms_inbox.dart';

SmsMessage message(String sender, String body) => SmsMessage(
  id: 'test',
  sender: sender,
  body: body,
  receivedAt: DateTime(2026, 11, 10, 14),
);

void main() {
  group('BankSmsParser', () {
    test('parses an HDFC debit with a balance tail', () {
      final parsed = BankSmsParser.parse(
        message(
          'AD-HDFCBK',
          'Rs.450.00 debited from a/c XX1234 on 10-11-26 to SWIGGY. '
              'Avl Bal: INR 12,340.00',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 450);
      expect(parsed.isIncome, false);
      expect(parsed.merchant, 'Swiggy');
      expect(parsed.last4, '1234');
      expect(parsed.date, DateTime(2026, 11, 10, 12));
      expect(parsed.category, 'Food & Dining');
    });

    test('parses an ICICI debit with an Info merchant', () {
      final parsed = BankSmsParser.parse(
        message(
          'ICICIB',
          'INR 1,200.00 debited from ICICI Bank A/c XX5678 on 10-Nov-26. '
              'Info: UPI/AMAZON. Avl Bal: INR 45,000.00',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1200);
      expect(parsed.merchant, 'Amazon');
      expect(parsed.last4, '5678');
      expect(parsed.date, DateTime(2026, 11, 10, 12));
      expect(parsed.category, 'Shopping');
    });

    test('parses an Axis credit-card spend and ignores the limit', () {
      final parsed = BankSmsParser.parse(
        message(
          'AXISBK',
          'INR 2,499.00 spent on Axis Bank Credit Card XX4821 at AMAZON on '
              '10-11-2026. Avl limit: INR 97,501.00',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 2499);
      expect(parsed.isIncome, false);
      expect(parsed.merchant, 'Amazon');
      expect(parsed.last4, '4821');
      expect(parsed.category, 'Shopping');
    });

    test('parses an SBI debit with a compact date', () {
      final parsed = BankSmsParser.parse(
        message(
          'SBIINB',
          'Your A/c XX1234 debited by Rs 849.00 on 10Nov26. '
              'Transaction at SWIGGY. Avl Bal Rs 12,340.00',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 849);
      expect(parsed.merchant, 'Swiggy');
      expect(parsed.last4, '1234');
      expect(parsed.date, DateTime(2026, 11, 10, 12));
    });

    test('parses a Kotak UPI debit', () {
      final parsed = BankSmsParser.parse(
        message(
          'KOTAKB',
          'Rs 500.00 debited from Kotak Bank A/c XX9012 on 10/11/26 to UBER. '
              'Avl Bal Rs 8,000.00',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 500);
      expect(parsed.merchant, 'Uber');
      expect(parsed.last4, '9012');
      expect(parsed.category, 'Transportation');
    });

    test('parses an income credit', () {
      final parsed = BankSmsParser.parse(
        message(
          'HDFCBK',
          'Rs.50,000.00 credited to your A/c XX1234 on 01-11-26 from '
              'NIMBUS LABS. Avl Bal: INR 62,340.00',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 50000);
      expect(parsed.isIncome, true);
      expect(parsed.merchant, 'Nimbus Labs');
      expect(parsed.last4, '1234');
      expect(parsed.category, 'Income');
    });

    test('parses an Amex charge with a card ending', () {
      final parsed = BankSmsParser.parse(
        message(
          'AMEX',
          'A transaction of Rs.2,499.00 has been made on your American Express '
              'Card ending 1234 at AMAZON on 10-11-2026.',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 2499);
      expect(parsed.merchant, 'Amazon');
      expect(parsed.last4, '1234');
    });

    test('parses an ICICI UPI debit where the counterparty is credited', () {
      final parsed = BankSmsParser.parse(
        message(
          'AD-ICICIB',
          'ICICI Bank Acct XX855 debited for Rs 1000.00 on 10-Nov-26; '
              'S RAMANI credited. UPI:631434570155. '
              'Call 18002662 for dispute. SMS BLOCK 855 to 9215676766.',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1000);
      expect(parsed.isIncome, false);
      expect(parsed.merchant, 'S Ramani');
      expect(parsed.date, DateTime(2026, 11, 10, 12));
    });

    test('parses a second ICICI UPI debit with a different counterparty', () {
      final parsed = BankSmsParser.parse(
        message(
          'AD-ICICIB',
          'ICICI Bank Acct XX855 debited for Rs 500.00 on 10-Nov-26; '
              'Nithishkumar Ya credited. UPI:631430177547. '
              'Call 18002662 for dispute. SMS BLOCK 855 to 9215676766.',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 500);
      expect(parsed.isIncome, false);
      expect(parsed.merchant, contains('Nithishkumar'));
      expect(parsed.date, DateTime(2026, 11, 10, 12));
    });

    test('parses an HDFC Sent UPI transfer', () {
      final parsed = BankSmsParser.parse(
        message(
          'AD-HDFCBK',
          'Sent Rs.375.00\n'
              'From HDFC Bank A/C *6539\n'
              'To Babai Tiffins VTR-1\n'
              'On 30/07/26\n'
              'Ref 127517458170\n'
              'Not You?\n'
              'Call 18002586161/SMS BLOCK UPI to 7308080808',
        ),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 375);
      expect(parsed.isIncome, false);
      expect(parsed.merchant, contains('Babai Tiffins'));
      expect(parsed.last4, '6539');
      expect(parsed.date, DateTime(2026, 7, 30, 12));
      expect(parsed.category, 'Food & Dining');
    });

    test('rejects OTP messages', () {
      expect(
        BankSmsParser.parse(
          message(
            'AD-HDFCBK',
            '123456 is your OTP for a transaction of Rs.450.00 at SWIGGY. '
                'Do not share it with anyone.',
          ),
        ),
        isNull,
      );
    });

    test('rejects payment reminders', () {
      expect(
        BankSmsParser.parse(
          message(
            'ICICIB',
            'Your payment due of INR 5,000 is on 15-11-26. '
                'Minimum due INR 500.',
          ),
        ),
        isNull,
      );
    });

    test('rejects promotional messages', () {
      expect(
        BankSmsParser.parse(
          message(
            'AXISBK',
            'Get 10% cashback on your next spend of Rs 500 at SWIGGY. '
                'Offer valid till 30-11-26.',
          ),
        ),
        isNull,
      );
    });

    test('rejects non-bank senders', () {
      expect(
        BankSmsParser.parse(
          message(
            'JM-SWIGGY',
            'Rs.450.00 debited from a/c XX1234 on 10-11-26 to SWIGGY.',
          ),
        ),
        isNull,
      );
    });
  });
}
