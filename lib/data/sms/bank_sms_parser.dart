import 'sms_inbox.dart';

class ParsedBankSms {
  const ParsedBankSms({
    required this.merchant,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.category,
    required this.confidence,
    this.last4,
  });

  final String merchant;

  /// Always positive; [isIncome] carries the direction.
  final double amount;
  final bool isIncome;
  final DateTime date;
  final String category;
  final double confidence;
  final String? last4;
}

/// Conservative parser for Indian bank transaction SMS.
///
/// The native receiver already gates bank senders and transaction keywords;
/// this layer extracts fields and drops anything that still looks like an
/// OTP, a reminder, a promotion, or an ambiguous message.
abstract final class BankSmsParser {
  static const bankTokens = <String>[
    'HDFC',
    'ICICI',
    'AXIS',
    'SBI',
    'KOTAK',
    'IDFC',
    'YESBNK',
    'YESBANK',
    'INDUS',
    'RBL',
    'FEDERAL',
    'CANARA',
    'BOB',
    'PNB',
    'UNION',
    'IDBI',
    'CITI',
    'HSBC',
    'SCB',
    'DBS',
    'AUBANK',
    'AMEX',
    'BAJAJ',
    'TATA',
    'PAYTM',
  ];

  static const _merchantCategories = <String, String>{
    'swiggy': 'Food & Dining',
    'zomato': 'Food & Dining',
    'blinkit': 'Groceries',
    'bigbasket': 'Groceries',
    'zepto': 'Groceries',
    'dmart': 'Groceries',
    'uber': 'Transportation',
    'ola': 'Transportation',
    'rapido': 'Transportation',
    'irctc': 'Travel',
    'indigo': 'Travel',
    'makemytrip': 'Travel',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'jio': 'Utilities',
    'airtel': 'Utilities',
    'vodafone': 'Utilities',
    'electricity': 'Utilities',
    'apollo': 'Healthcare',
    'pharmeasy': 'Healthcare',
    '1mg': 'Healthcare',
    'cult': 'Personal',
    'gym': 'Personal',
    'tiffin': 'Food & Dining',
    'tiffins': 'Food & Dining',
  };

  static final _otp = RegExp(
    r'\b(otp|one[- ]time password|verification code|do not share|never share)\b',
    caseSensitive: false,
  );
  static final _income = RegExp(
    r'\b(credited|credit received|deposited|received|refund|reversal)\b',
    caseSensitive: false,
  );
  static final _expense = RegExp(
    r'\b(debited|debit|withdrawn|withdrawal|spent|paid|purchase|payment|charged|charge|made on|sent|transfer(?:red)?|trf)\b',
    caseSensitive: false,
  );
  static final _reminder = RegExp(
    r'\b(payment due|minimum due|due on|statement generated|bill generated|total amount due)\b',
    caseSensitive: false,
  );
  static final _strongTransaction = RegExp(
    r'\b(debited|credited|withdrawn|spent|paid)\b',
    caseSensitive: false,
  );

  static bool isBankSender(String sender) {
    final normalized = sender.toUpperCase();
    return bankTokens.any(normalized.contains);
  }

  static ParsedBankSms? parse(SmsMessage sms) {
    final body = sms.body.trim();
    if (body.isEmpty || !isBankSender(sms.sender)) return null;
    if (_otp.hasMatch(body)) return null;
    if (_reminder.hasMatch(body) && !_strongTransaction.hasMatch(body)) {
      return null;
    }

    final incomeMatch = _income.firstMatch(body);
    final expenseMatch = _expense.firstMatch(body);
    if (incomeMatch == null && expenseMatch == null) return null;
    // UPI messages often say "debited ...; <beneficiary> credited". The first
    // direction word belongs to the account owner, so it wins.
    final isIncome =
        incomeMatch != null &&
        (expenseMatch == null || incomeMatch.start < expenseMatch.start);

    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;

    final merchant = _extractMerchant(body, isIncome: isIncome);
    final last4 = _extractLast4(body);
    final date = _extractDate(body, sms.receivedAt);
    final category = isIncome ? 'Income' : _categoryFor(merchant);

    var confidence = 0.5;
    confidence += 0.2;
    confidence += 0.1;
    if (merchant != 'Bank transaction') confidence += 0.1;
    if (last4 != null) confidence += 0.05;
    if (date != sms.receivedAt) confidence += 0.05;

    return ParsedBankSms(
      merchant: merchant,
      amount: amount,
      isIncome: isIncome,
      date: date,
      category: category,
      confidence: confidence.clamp(0, 0.99),
      last4: last4,
    );
  }

  static double? _extractAmount(String body) {
    final cleaned = body.replaceAll(
      RegExp(
        r'\b(?:avl|available|avail)\s*\.?\s*(?:bal|balance|limit)[a-z]*[^.]*',
        caseSensitive: false,
      ),
      ' ',
    );
    final patterns = <RegExp>[
      RegExp(
        r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([\d,]+(?:\.\d{1,2})?)\s*(?:INR|Rs\.?|₹)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:debited|credited|spent|paid|withdrawn)\s+(?:by|with|for|of)?\s*([\d,]+(?:\.\d{1,2})?)\b',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match == null) continue;
      final value = double.tryParse((match.group(1) ?? '').replaceAll(',', ''));
      if (value != null && value > 0) return value;
    }
    return null;
  }

  static String _extractMerchant(String body, {required bool isIncome}) {
    final from = RegExp(
      r'\bfrom\s+([A-Za-z0-9&*._/\- ]{2,60}?)(?=\s+(?:on|dated|via|using)\b|[.,]|$)',
      caseSensitive: false,
    );
    final at = RegExp(
      r'\bat\s+([A-Za-z0-9&*._/\- ]{2,60}?)(?=\s+(?:on|dated|for|via|using)\b|[.,]|$)',
      caseSensitive: false,
    );
    final to = RegExp(
      r'\bto\s+([A-Za-z0-9&*._/\- ]{2,60}?)(?=\s+(?:on|dated|via|using|from)\b|[.,]|$)',
      caseSensitive: false,
    );
    final info = RegExp(
      r'\binfo[:\s]+([A-Za-z0-9&*._/\- ]{2,60}?)(?=\s+(?:avl|available|avail)\b|\.|$)',
      caseSensitive: false,
    );
    final trf = RegExp(
      r'\b(?:trf|transfer)\s+to\s+([A-Za-z0-9&*._/\- ]{2,60}?)(?=\s+(?:on|dated|via)\b|[.,]|$)',
      caseSensitive: false,
    );
    final counterparty = RegExp(
      r'(?:^|[;.]\s*)([A-Za-z0-9&*._/\- ]{2,60}?)\s+credited\b',
      caseSensitive: false,
    );

    final patterns = isIncome
        ? [from, info, at, counterparty]
        : [at, to, trf, info, from, counterparty];
    for (final pattern in patterns) {
      final cleaned = _cleanMerchant(pattern.firstMatch(body)?.group(1));
      if (cleaned != null) return cleaned;
    }
    return 'Bank transaction';
  }

  static String? _cleanMerchant(String? raw) {
    if (raw == null) return null;
    var value = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    value = value
        .split(RegExp(r'\.\s|\b(?:avl|available|avail)\b', caseSensitive: false))
        .first
        .trim();
    value = value.replaceAll(RegExp(r'[.,;:]+$'), '').trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower.contains('a/c') ||
        lower.contains('account') ||
        lower.contains('card')) {
      return null;
    }
    if (RegExp(r'xx+\s*\d{2,4}').hasMatch(lower)) return null;
    if (RegExp(r'^\d{6,}$').hasMatch(value)) return null;
    if (value.contains('/')) value = value.split('/').last.trim();
    if (value.isEmpty) return null;
    return _titleCase(value);
  }

  static String? _extractLast4(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:a/?c|acct|account|card)\s*(?:no\.?|number|ending|ending with)?\s*(?:xx+|\*+)?\s*(\d{4})\b',
        caseSensitive: false,
      ),
      RegExp(r'(?:xx+|\*+)\s*(\d{4})\b', caseSensitive: false),
      RegExp(r'ending\s*(?:with\s*)?(\d{4})\b', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static DateTime _extractDate(String body, DateTime fallback) {
    final numeric = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b');
    final numericMatch = numeric.firstMatch(body);
    if (numericMatch != null) {
      final parsed = _dateFromParts(
        numericMatch.group(1),
        numericMatch.group(2),
        numericMatch.group(3),
      );
      if (parsed != null && !_isFarFuture(parsed, fallback)) return parsed;
    }

    final named = RegExp(
      r'\b(\d{1,2})[ -]?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[ -]?(\d{2,4})\b',
      caseSensitive: false,
    );
    final namedMatch = named.firstMatch(body);
    if (namedMatch != null) {
      final month = _monthNumber(namedMatch.group(2));
      final parsed = _dateFromParts(
        namedMatch.group(1),
        month?.toString(),
        namedMatch.group(3),
      );
      if (parsed != null && !_isFarFuture(parsed, fallback)) return parsed;
    }
    return fallback;
  }

  static DateTime? _dateFromParts(
    String? dayRaw,
    String? monthRaw,
    String? yearRaw,
  ) {
    final day = int.tryParse(dayRaw ?? '');
    final month = int.tryParse(monthRaw ?? '');
    var year = int.tryParse(yearRaw ?? '');
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day, 12);
    if (date.month != month || date.day != day) return null;
    return date;
  }

  static bool _isFarFuture(DateTime date, DateTime fallback) =>
      date.isAfter(fallback.add(const Duration(days: 2)));

  static int? _monthNumber(String? raw) {
    if (raw == null) return null;
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final index = months.indexOf(raw.toLowerCase());
    return index < 0 ? null : index + 1;
  }

  static String _categoryFor(String merchant) {
    final lower = merchant.toLowerCase();
    for (final entry in _merchantCategories.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'Other';
  }

  static String _titleCase(String value) => value
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        if (word.length <= 2) return word.toUpperCase();
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}
