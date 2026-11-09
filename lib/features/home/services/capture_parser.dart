import '../../../data/models/transaction.dart';
import '../../../core/theme/app_colors.dart';

class ParsedCapture {
  final String raw;
  final String merchant;
  final double amount;
  final String category;
  final bool isIncome;
  final List<ReceiptItem> items;

  const ParsedCapture({
    required this.raw,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.isIncome,
    this.items = const [],
  });

  TransactionDraft toDraft({String? accountId}) {
    return TransactionDraft(
      merchant: merchant,
      category: category,
      amount: isIncome ? amount.abs() : -amount.abs(),
      date: DateTime.now(),
      accountId: accountId,
    );
  }
}

class ReceiptItem {
  final String name;
  final double price;

  const ReceiptItem({required this.name, required this.price});
}

class CaptureParser {
  static const Map<String, int> _numberWords = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  /// Parses natural language input like:
  /// - "chai 40"
  /// - "uber 280"
  /// - "spent 1200 on dinner"
  /// - "zomato four eighty six"
  /// - "salary 50000"
  /// - "starbucks two fifty"
  static ParsedCapture? parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();
    final isIncome = RegExp(
      r'\b(salary|bonus|refund|cashback|dividend|freelance|received|credit|deposit)\b',
    ).hasMatch(lower);

    // 1. Try to find numeric digits first (e.g. ₹500, Rs. 500, 486, 1,200.50)
    final digitMatch = RegExp(
      r'(?:₹|rs\.?|inr)?\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(text);

    double? extractedAmount;
    String cleanText = text;

    if (digitMatch != null) {
      final numStr = digitMatch.group(1)!.replaceAll(',', '');
      extractedAmount = double.tryParse(numStr);
      if (extractedAmount != null) {
        cleanText = text.replaceRange(digitMatch.start, digitMatch.end, '').trim();
      }
    }

    // 2. If no digits found, try to parse spoken number words (e.g. "four eighty six", "two eighty", "fifty")
    if (extractedAmount == null) {
      final parsedWords = _extractSpokenAmount(lower);
      if (parsedWords != null) {
        extractedAmount = parsedWords.amount;
        cleanText = parsedWords.remainingText;
      }
    }

    if (extractedAmount == null || extractedAmount <= 0) {
      return null;
    }

    // 3. Clean up merchant name
    var merchant = cleanText
        .replaceAll(
          RegExp(r'\b(spent|paid|for|on|at|to|from|rs|inr|rupees)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (merchant.isEmpty) {
      merchant = isIncome ? 'Income' : 'Expense';
    } else {
      // Capitalize
      final parts = merchant.split(' ');
      merchant = parts
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
          .join(' ');
    }

    final category = detectCategory(merchant, lower, isIncome: isIncome);

    return ParsedCapture(
      raw: text,
      merchant: merchant,
      amount: extractedAmount,
      category: category,
      isIncome: isIncome,
    );
  }

  /// Extracts spoken numbers like:
  /// "four eighty six" -> 486
  /// "two eighty" -> 280
  /// "one thousand five hundred" -> 1500
  /// "forty" -> 40
  static _SpokenNumberResult? _extractSpokenAmount(String text) {
    final words = text.split(RegExp(r'\s+'));
    final numberTokens = <String>[];
    final remainingTokens = <String>[];

    for (final word in words) {
      final clean = word.replaceAll(RegExp(r'[^\w]'), '');
      if (_numberWords.containsKey(clean) ||
          clean == 'hundred' ||
          clean == 'thousand' ||
          clean == 'lakh' ||
          clean == 'k') {
        numberTokens.add(clean);
      } else {
        remainingTokens.add(word);
      }
    }

    if (numberTokens.isEmpty) return null;

    double total = 0;
    double current = 0;

    for (var i = 0; i < numberTokens.length; i++) {
      final token = numberTokens[i];

      if (token == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
      } else if (token == 'thousand' || token == 'k') {
        current = (current == 0 ? 1 : current) * 1000;
        total += current;
        current = 0;
      } else if (token == 'lakh') {
        current = (current == 0 ? 1 : current) * 100000;
        total += current;
        current = 0;
      } else {
        final val = _numberWords[token] ?? 0;
        // Check for compound spoken numbers like "four" followed by "eighty" -> 400 + 80
        if (current > 0 && current < 10 && val >= 20) {
          // e.g. "four eighty" -> 480
          current = (current * 100) + val;
        } else {
          current += val;
        }
      }
    }
    total += current;

    if (total <= 0) return null;

    return _SpokenNumberResult(
      amount: total,
      remainingText: remainingTokens.join(' '),
    );
  }

  static String detectCategory(
    String merchant,
    String lower, {
    bool isIncome = false,
  }) {
    if (isIncome) return 'Income';

    final text = '$merchant $lower'.toLowerCase();

    // Food
    if (RegExp(
      r'\b(chai|coffee|tea|starbucks|ccd|cafe|swiggy|zomato|blinkit|zepto|instamart|groceries|grocery|food|dinner|lunch|breakfast|burger|pizza|mcdonalds|kfc|dominos|subway|biryani|restaurant|amul|milk|bakery|dosa|sweets)\b',
    ).hasMatch(text)) {
      return 'Food';
    }

    // Travel
    if (RegExp(
      r'\b(uber|ola|rapido|cab|taxi|metro|train|irctc|flight|indigo|air\s*india|vistara|fuel|petrol|diesel|shell|hp|indianoil|toll|fastag|parking|auto)\b',
    ).hasMatch(text)) {
      return 'Travel';
    }

    // Bills & Utilities
    if (RegExp(
      r'\b(rent|electricity|electric|bescom|tneb|power|wifi|broadband|airtel|jio|vi|vodafone|recharge|water|gas|cylinder|indane|maintenance|utility|bill|society)\b',
    ).hasMatch(text)) {
      return 'Bills';
    }

    // Shopping
    if (RegExp(
      r'\b(amazon|flipkart|myntra|zara|h&m|ajio|meesho|nykaa|clothes|shoes|electronics|apple|croma|reliance\s*digital|shopping|mall|decathlon)\b',
    ).hasMatch(text)) {
      return 'Shop';
    }

    // Entertainment / Fun
    if (RegExp(
      r'\b(netflix|prime|hotstar|spotify|apple\s*music|youtube|movie|cinema|pvr|inox|bms|bookmyshow|game|gaming|steam|playstation|pub|bar|drinks|club)\b',
    ).hasMatch(text)) {
      return 'Fun';
    }

    // Debt / EMI
    if (RegExp(r'\b(emi|loan|interest|mortgage|prepayment)\b').hasMatch(text)) {
      return 'EMI';
    }

    // Fallback to active app categories if available
    return AppColors.categoryList.contains('Food') ? 'Food' : 'Expense';
  }

  /// Parses raw text extracted from a receipt image into merchant, items, and total
  static ParsedCapture parseReceiptText(String fullText) {
    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String detectedMerchant = 'Receipt';
    double detectedTotal = 0;
    final items = <ReceiptItem>[];

    // Common receipt words to ignore for merchant name
    final ignoreMerchant = RegExp(
      r'\b(tax|invoice|bill|receipt|gstin|gst|tel|phone|cash|welcome|date|time|order|token|table|store|pos)\b',
      caseSensitive: false,
    );

    // 1. Identify merchant name from first 4 lines
    for (var i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      if (line.length >= 3 &&
          !ignoreMerchant.hasMatch(line) &&
          !RegExp(r'^\d+$').hasMatch(line) &&
          !RegExp(r'^[0-9\.\,\:\/\-]+$').hasMatch(line)) {
        detectedMerchant = line;
        break;
      }
    }

    // Clean merchant name
    detectedMerchant = detectedMerchant
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s\&\-]'), '')
        .trim();
    if (detectedMerchant.isEmpty) detectedMerchant = 'Store Purchase';

    // 2. Look for Total amount
    final totalRegex = RegExp(
      r'(?:total|grand\s*total|net\s*amount|amount\s*payable|subtotal|balance\s*due)[\s\:\=₹Rs\.]*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = totalRegex.firstMatch(line);
      if (match != null) {
        final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (val != null && val > detectedTotal) {
          detectedTotal = val;
        }
      }
    }

    // 3. Look for line items (e.g. "Amul milk 2x 128", "Eggs 96.00")
    final lineItemRegex = RegExp(
      r'^(.+?)[\s\.\-]+(?:₹|rs\.?|inr)?\s*([0-9]+(?:\.[0-9]{1,2})?)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (line.toLowerCase().contains('total') ||
          line.toLowerCase().contains('tax') ||
          line.toLowerCase().contains('gst') ||
          line.toLowerCase().contains('discount')) {
        continue;
      }
      final match = lineItemRegex.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!.trim();
        final price = double.tryParse(match.group(2)!) ?? 0;
        if (name.length > 2 && price > 0 && price < 100000) {
          items.add(ReceiptItem(name: name, price: price));
        }
      }
    }

    // 4. Fallback if no total line was explicitly matched
    if (detectedTotal == 0) {
      if (items.isNotEmpty) {
        detectedTotal = items.fold(0.0, (sum, i) => sum + i.price);
      } else {
        // Find largest number on the receipt
        final allNums = RegExp(r'\b([0-9]+(?:\.[0-9]{2})?)\b')
            .allMatches(fullText)
            .map((m) => double.tryParse(m.group(1)!) ?? 0)
            .where((n) => n > 10 && n < 500000)
            .toList();
        if (allNums.isNotEmpty) {
          allNums.sort();
          detectedTotal = allNums.last;
        } else {
          detectedTotal = 480;
        }
      }
    }

    final category = detectCategory(detectedMerchant, fullText.toLowerCase());

    return ParsedCapture(
      raw: fullText,
      merchant: detectedMerchant,
      amount: detectedTotal,
      category: category,
      isIncome: false,
      items: items,
    );
  }
}

class _SpokenNumberResult {
  final double amount;
  final String remainingText;

  const _SpokenNumberResult({
    required this.amount,
    required this.remainingText,
  });
}
