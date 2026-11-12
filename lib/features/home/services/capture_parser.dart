import '../../../data/models/transaction.dart';

class ParsedCapture {
  final String raw;
  final String merchant;
  final double amount;
  final String category;
  final bool isIncome;
  final List<ReceiptItem> items;
  final bool categoryDetected;

  /// Receipt date when it can be read from the bill.
  final DateTime? date;

  const ParsedCapture({
    required this.raw,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.isIncome,
    this.items = const [],
    this.categoryDetected = true,
    this.date,
  });

  TransactionDraft toDraft({String? accountId, String? category}) {
    return TransactionDraft(
      merchant: merchant,
      category: category ?? this.category,
      amount: isIncome ? amount.abs() : -amount.abs(),
      date: date ?? DateTime.now(),
      addedAt: DateTime.now(),
      accountId: accountId,
    );
  }
}

class ReceiptParseResult {
  const ReceiptParseResult({
    required this.capture,
    required this.isReceipt,
    required this.confidence,
    required this.message,
  });

  final ParsedCapture? capture;
  final bool isReceipt;
  final double confidence;
  final String message;
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
      r'\b(salary|stipend|bonus|incentive|commission|reimbursement|refund|cashback|dividend|freelance|consulting|received|credit|deposit|allowance)\b',
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
        cleanText = text
            .replaceRange(digitMatch.start, digitMatch.end, '')
            .trim();
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
          RegExp(
            r'\b(spent|paid|for|on|at|to|from|rs|inr|rupees)\b',
            caseSensitive: false,
          ),
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
      categoryDetected: category != 'Other',
      date: DateTime.now(),
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

    // Food & Dining (Indian chains, street food, chai/coffee, kirana & quick-commerce)
    if (RegExp(
      r'\b(chai|coffee|filter\s*coffee|tea|starbucks|ccd|cafe|third\s*wave|blue\s*tokai|chaayos|chai\s*point|'
      r'swiggy|zomato|eatsure|faasos|behrouz|ovenstory|box8|blinkit|zepto|instamart|bigbasket|dmart|jiomart|'
      r'reliance\s*smart|nature\s*basket|kirana|ration|sabzi|vegetables|fruits|dairy|amul|mother\s*dairy|nandini|'
      r'milk|curd|paneer|bread|eggs|chicken|mutton|fish|meat|licious|freshtohome|groceries|grocery|food|'
      r'dinner|lunch|breakfast|brunch|snacks|tiffin|mess|canteen|thali|biryani|dosa|idli|vada|samosa|kachori|'
      r'chaat|panipuri|golgappa|pav\s*bhaji|chole|paratha|roti|momos|maggi|noodles|burger|pizza|mcdonalds|kfc|'
      r'dominos|pizza\s*hut|burger\s*king|subway|taco\s*bell|wow\s*momo|haldiram|haldirams|bikanervala|'
      r'saravana\s*bhavan|mtr|a2b|restaurant|dhaba|udupi|darshini|bakery|cake|theobroma|monginis|sweets|'
      r'mithai|lassi|juice|sugarcane|coconut|nariyal|paan|ice\s*cream|naturals|baskin)\b',
    ).hasMatch(text)) {
      return 'Food';
    }

    // Fuel
    if (RegExp(
      r'\b(fuel|petrol|diesel|cng|ev\s*charging|shell|hpcl|bpcl|iocl|indianoil|indian\s*oil|bharat\s*petroleum|nayara|jio\s*bp|pump|hp)\b',
    ).hasMatch(text)) {
      return 'Fuel';
    }

    // Travel & Commute (Indian cabs, autos, metro, IRCTC, buses, flights, stays)
    if (RegExp(
      r'\b(uber|ola|rapido|namma\s*yatri|indrive|blusmart|meru|cab|taxi|auto|rickshaw|metro|dmrc|bmrc|'
      r'namma\s*metro|mmrc|cmrl|local\s*train|train|irctc|railway|vande\s*bharat|shatabdi|rajdhani|redbus|'
      r'abhibus|ksrtc|msrtc|bmtc|bus|volvo|flight|indigo|air\s*india|vistara|akasa|spicejet|makemytrip|mmt|'
      r'goibibo|cleartrip|easemytrip|yatra|ixigo|oyo|treebo|fabhotels|zostel|hotel|airbnb|resort|toll|parking|valet)\b',
    ).hasMatch(text)) {
      return 'Travel';
    }

    // Rent & Housing
    if (RegExp(
      r'\b(rent|landlord|pg|hostel|flat|deposit|brokerage|nobroker|magicbricks|99acres|mygate|nobrokerhood|'
      r'carpenter|plumber|electrician|ikea|pepperfry|urban\s*ladder|wakefit|furniture)\b',
    ).hasMatch(text)) {
      return 'Rent & Housing';
    }

    // Utilities & Recharge
    if (RegExp(
      r'\b(electricity|electric|bescom|tneb|mahavitaran|msedcl|tata\s*power|adani\s*electricity|bses|uppcl|'
      r'torrent\s*power|power|wifi|broadband|act\s*fibernet|jiofiber|xstream|hathway|airtel|jio|vi|vodafone|'
      r'bsnl|recharge|prepaid|postpaid|dth|tata\s*play|tatasky|dish\s*tv|water|bwssb|gas|cylinder|indane|'
      r'hp\s*gas|bharat\s*gas|igl|mahanagar\s*gas|fastag|maintenance|utility|bill|society)\b',
    ).hasMatch(text)) {
      return 'Utilities';
    }

    // Healthcare & Pharmacy
    if (RegExp(
      r'\b(apollo|pharmeasy|1mg|netmeds|medplus|practo|lal\s*pathlabs|thyrocare|diagnostics|pharmacy|'
      r'medical|medicine|tablet|doctor|clinic|hospital|dentist|dental|optician|eyewear|health|checkup|lab)\b',
    ).hasMatch(text)) {
      return 'Healthcare';
    }

    // Education & Books
    if (RegExp(
      r'\b(school|college|university|tuition|coaching|allen|aakash|byjus|unacademy|physicswallah|coursera|'
      r'udemy|upgrad|scaler|books|stationery|crossword|exam|fees|library|course)\b',
    ).hasMatch(text)) {
      return 'Education';
    }

    // Personal Care & Fitness
    if (RegExp(
      r'\b(salon|haircut|barber|parlour|parlor|spa|massage|grooming|urban\s*company|urbanclap|cult|cultfit|'
      r'gym|fitness|yoga|mamaearth|plum|sephora|laundry|dryclean|dhobi|tailor)\b',
    ).hasMatch(text)) {
      return 'Personal';
    }

    // Investment & Insurance
    if (RegExp(
      r'\b(zerodha|groww|upstox|angel\s*one|kite|kuvera|etmoney|indmoney|smallcase|sip|mutual\s*fund|'
      r'ppf|nps|epf|fixed\s*deposit|sgb|sovereign\s*gold|stocks|shares|demat|lic|insurance|policybazaar|acko|digit)\b',
    ).hasMatch(text)) {
      return 'Investment';
    }

    // Shopping & E-commerce
    if (RegExp(
      r'\b(amazon|flipkart|myntra|zara|h&m|ajio|meesho|nykaa|tatacliq|tata\s*cliq|snapdeal|firstcry|'
      r'lenskart|boat|croma|reliance\s*digital|vijay\s*sales|apple|samsung|xiaomi|oneplus|westside|zudio|'
      r'pantaloons|lifestyle|shoppers\s*stop|trends|fabindia|biba|manyavar|raymond|bata|woodland|nike|'
      r'adidas|puma|skechers|decathlon|titan|fastrack|tanishq|kalyan|malabar|jewellery|jewelry|clothes|'
      r'shoes|sneakers|electronics|mobile|laptop|shopping|mall|bazaar|fnp|gift)\b',
    ).hasMatch(text)) {
      return 'Shop';
    }

    // Entertainment / Fun
    if (RegExp(
      r'\b(netflix|prime|hotstar|jiohotstar|jiocinema|sonyliv|zee5|aha|hoichoi|spotify|jiosaavn|gaana|'
      r'wynk|apple\s*music|youtube|movie|cinema|pvr|inox|cinepolis|bms|bookmyshow|insider|concert|standup|'
      r'ipl|game|gaming|steam|playstation|ps5|xbox|bgmi|turf|badminton|cricket|bowling|arcade|wonderla|'
      r'imagica|pub|bar|brewery|toit|social|drinks|alcohol|wine|beer|club|lounge|party)\b',
    ).hasMatch(text)) {
      return 'Fun';
    }

    // Debt / EMI & Credit Card Bills
    if (RegExp(
      r'\b(emi|loan|bajaj\s*finserv|simpl|lazypay|slice|cred|cheq|credit\s*card|card\s*bill|interest|mortgage|prepayment|foreclosure)\b',
    ).hasMatch(text)) {
      return 'EMI';
    }

    // Miscellaneous
    if (RegExp(
      r'\b(misc|mis|miscellaneous|donation|charity|temple|mandir|church|mosque|gurudwara|puja|pooja|'
      r'prasad|dakshina|tip|tips|courier|delhivery|bluedart|dtdc|speed\s*post|xerox|print|photocopy|notary|challan|fine)\b',
    ).hasMatch(text)) {
      return 'Miscellaneous';
    }

    // Do not guess a spend category. The review sheet will default to Other.
    return 'Other';
  }

  /// Validates OCR text and extracts a receipt only when it looks like one.
  static ReceiptParseResult parseReceipt(String fullText) {
    final lines = fullText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final lower = fullText.toLowerCase();

    final cues = RegExp(
      r'\b(receipt|invoice|tax invoice|bill|gst|gstin|total|subtotal|amount payable|net payable|balance due|cash|card|upi|change|order|thank you|date|time)\b',
      caseSensitive: false,
    ).allMatches(lower).length;
    final totalCue = RegExp(
      r'\b(grand\s*total|total\s*amount|amount\s*payable|net\s*payable|balance\s*due|total)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final strongCue = RegExp(
      r'\b(receipt|invoice|tax invoice|bill|gst|gstin|order|thank you|amount payable|balance due|total)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (lines.length < 3 || cues == 0) {
      return const ReceiptParseResult(
        capture: null,
        isReceipt: false,
        confidence: 0,
        message: 'That doesn’t look like a receipt. Try a clear photo of the printed bill.',
      );
    }

    final ignoreMerchant = RegExp(
      r'\b(tax invoice|invoice|receipt|bill|gstin|gst no|gst|tel|phone|mobile|date|time|order|token|table|customer|welcome|thank|upi|card|cash|change|total|subtotal|amount|qty|quantity|item)\b',
      caseSensitive: false,
    );
    var merchant = 'Receipt';
    for (final line in lines.take(8)) {
      final clean = line
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s&.\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.length < 3 ||
          ignoreMerchant.hasMatch(clean) ||
          RegExp(r'^\d').hasMatch(clean) ||
          RegExp(r'\d{4,}').hasMatch(clean) ||
          _receiptAmounts(clean).isNotEmpty) {
        continue;
      }
      merchant = clean;
      break;
    }

    final items = <ReceiptItem>[];
    final itemRegex = RegExp(
      r'^(.{2,60}?)\s+(?:x\s*\d+\s+)?(?:₹|rs\.?|inr)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*$',
      caseSensitive: false,
    );
    final ignoreItem = RegExp(
      r'\b(total|tax|gst|discount|change|cash|card|round|payment|balance|subtotal|order|date|phone|upi)\b',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (ignoreItem.hasMatch(line)) continue;
      final match = itemRegex.firstMatch(line);
      if (match == null) continue;
      final name = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      final price = double.tryParse((match.group(2) ?? '').replaceAll(',', ''));
      if (name.length > 2 && price != null && price > 0 && price < 500000) {
        items.add(ReceiptItem(name: name, price: price));
      }
    }

    var total = 0.0;
    var totalPriority = 0;
    for (final line in lines) {
      final text = line.toLowerCase();
      if (!RegExp(r'\b(total|payable|balance due|grand total|net amount)\b')
          .hasMatch(text)) {
        continue;
      }
      if (RegExp(
        r'\b(total\s*(savings|discount|items|qty|quantity)|tax\s*total)\b',
      ).hasMatch(text)) {
        continue;
      }
      final amounts = _receiptAmounts(line);
      if (amounts.isEmpty) continue;
      final value = amounts.last;
      final priority =
          RegExp(r'grand|payable|net amount|balance due').hasMatch(text)
          ? 3
          : RegExp(r'\btotal\b').hasMatch(text)
          ? 2
          : 1;
      if (priority >= totalPriority) {
        total = value;
        totalPriority = priority;
      }
    }

    if (total <= 0 && items.isNotEmpty) {
      total = items.fold(0.0, (sum, item) => sum + item.price);
    }
    if (total <= 0) {
      final numbers = <double>[];
      for (final line in lines) {
        numbers.addAll(_receiptAmounts(line));
      }
      final plausible = numbers
          .where((value) => value >= 1 && value < 500000)
          .toList();
      if (plausible.isNotEmpty) {
        total = plausible.reduce((a, b) => a > b ? a : b);
      }
    }

    if (total <= 0) {
      return const ReceiptParseResult(
        capture: null,
        isReceipt: false,
        confidence: 0,
        message: 'No receipt total was found. Try a sharper, well-lit photo.',
      );
    }

    final date = _extractReceiptDate(fullText);
    final category = detectCategory(merchant, lower);
    final hasMoney = lines.any((line) => _receiptAmounts(line).isNotEmpty);
    final isReceipt =
        hasMoney &&
        cues >= 2 &&
        strongCue &&
        (totalCue || items.length >= 2) &&
        total > 0;
    if (!isReceipt) {
      return const ReceiptParseResult(
        capture: null,
        isReceipt: false,
        confidence: 0,
        message: 'That doesn’t look like a receipt. Try a clear photo of the printed bill.',
      );
    }

    var confidence = 0.3;
    if (totalCue) confidence += 0.3;
    if (cues >= 2) confidence += 0.1;
    if (items.isNotEmpty) confidence += 0.15;
    if (merchant != 'Receipt') confidence += 0.15;
    if (date != null) confidence += 0.1;
    confidence = confidence.clamp(0.0, 0.99);

    return ReceiptParseResult(
      capture: ParsedCapture(
        raw: fullText,
        merchant: merchant,
        amount: total,
        category: category,
        isIncome: false,
        items: items,
        categoryDetected: category != 'Other',
        date: date,
      ),
      isReceipt: true,
      confidence: confidence,
      message: confidence >= 0.65
          ? 'Receipt found'
          : 'Receipt found — check the details before logging',
    );
  }

  /// Backwards-compatible helper for callers that only need the capture.
  static ParsedCapture parseReceiptText(String fullText) {
    return parseReceipt(fullText).capture ??
        ParsedCapture(
          raw: fullText,
          merchant: 'Receipt',
          amount: 0,
          category: 'Other',
          isIncome: false,
          categoryDetected: false,
          date: DateTime.now(),
        );
  }

  static List<double> _receiptAmounts(String line) {
    final cleaned = line
        .replaceAll(RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b'), ' ')
        .replaceAll(RegExp(r'\b\d{2}:\d{2}(?::\d{2})?\b'), ' ')
        .replaceAll(RegExp(r'\b\d{10,}\b'), ' ')
        .replaceAll(RegExp(r'\b[0-9A-Z]{15}\b'), ' ');
    return RegExp(
          r'(?:(?:₹|rs\.?|inr)\s*)?([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
          caseSensitive: false,
        )
        .allMatches(cleaned)
        .map(
          (match) =>
              double.tryParse((match.group(1) ?? '').replaceAll(',', '')),
        )
        .whereType<double>()
        .where((value) => value > 0)
        .toList();
  }

  static DateTime? _extractReceiptDate(String text) {
    final now = DateTime.now();
    final numeric = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b');
    final named = RegExp(
      r'\b(\d{1,2})[ -]?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[ -]?(\d{2,4})\b',
      caseSensitive: false,
    );

    for (final match in numeric.allMatches(text)) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      var year = int.tryParse(match.group(3) ?? '');
      if (year != null && year < 100) year += 2000;
      final date = _safeDate(year, month, day);
      if (date != null && _plausibleReceiptDate(date, now)) return date;
    }

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
    for (final match in named.allMatches(text)) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = months.indexOf((match.group(2) ?? '').toLowerCase()) + 1;
      var year = int.tryParse(match.group(3) ?? '');
      if (year != null && year < 100) year += 2000;
      final date = _safeDate(year, month, day);
      if (date != null && _plausibleReceiptDate(date, now)) return date;
    }
    return null;
  }

  static DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day, 12);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static bool _plausibleReceiptDate(DateTime date, DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final fiveYearsAgo = DateTime(now.year - 5, now.month, now.day);
    return !date.isAfter(tomorrow) && !date.isBefore(fiveYearsAgo);
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
