import 'dart:math' as math;

import '../../../core/state/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../data/models/finance_snapshot.dart';
import '../../../data/services/finance_calculator.dart';

class LocalAskBar {
  const LocalAskBar({
    required this.label,
    required this.valueText,
    required this.ratio,
    this.sublabel,
  });

  final String label;
  final String valueText;
  final double ratio;
  final String? sublabel;
}

class LocalAskResult {
  const LocalAskResult({
    required this.headline,
    required this.subtitle,
    this.amount,
    this.bars = const [],
    this.isHighConfidence = true,
    this.ledgerPrefill,
  });

  final String headline;
  final String subtitle;
  final double? amount;
  final List<LocalAskBar> bars;
  final bool isHighConfidence;
  final LedgerPrefill? ledgerPrefill;
}

abstract final class LocalAskEngine {
  static const _monthNames = <String, int>{
    'january': 1,
    'jan': 1,
    'february': 2,
    'feb': 2,
    'march': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'may': 5,
    'june': 6,
    'jun': 6,
    'july': 7,
    'jul': 7,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sept': 9,
    'sep': 9,
    'october': 10,
    'oct': 10,
    'november': 11,
    'nov': 11,
    'december': 12,
    'dec': 12,
  };

  /// Answers natural-language personal finance questions locally and offline.
  static LocalAskResult answer(
    FinanceSnapshot snapshot,
    String query, {
    Iterable<String> knownCategories = const [],
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = dateOnly(n);
    final q = query.toLowerCase().trim();

    // 1. Cash Runway / Safe to Spend
    if (RegExp(
      r'\b(runway|cash\s*runway|safe\s*to\s*spend|shortfall|run\s*out|lowest\s*balance|payday)\b',
    ).hasMatch(q)) {
      final runway = FinanceCalculator.cashRunway(snapshot, now: n);
      final safe = FinanceCalculator.safeToSpend(snapshot, now: n);
      final status = runway.isShortfall ? 'Shortfall' : 'Covered';
      return LocalAskResult(
        headline: 'Cash runway · $status',
        amount: runway.lowestBalance,
        subtitle:
            'Lowest on ${dayMonth(runway.lowestDate)} · '
            '${rupee(runway.dailySpend)}/day typical · '
            'Safe to spend ${rupee(safe.perDay)}/day',
        bars: [
          LocalAskBar(
            label: 'Liquid cash now',
            valueText: rupee(runway.startingBalance),
            ratio: 1,
          ),
          LocalAskBar(
            label: 'Upcoming bills (${runway.days}d)',
            valueText: rupee(runway.totalBills),
            ratio: runway.startingBalance <= 0
                ? 0
                : (runway.totalBills / runway.startingBalance).clamp(0.0, 1.0),
          ),
          if (runway.payday != null)
            LocalAskBar(
              label: 'Next payday (${dayMonth(runway.payday!)})',
              valueText: rupee(runway.expectedIncome),
              ratio: 1,
            ),
        ],
      );
    }

    // 2. Net Worth / Bank Balances
    if (RegExp(
      r'\b(net\s*worth|bank\s*balance|liquid|savings|how\s*much\s*(do\s*i\s*have|cash|money))\b',
    ).hasMatch(q)) {
      final maxBal = snapshot.accounts.isEmpty
          ? 1.0
          : snapshot.accounts
                .map((a) => a.balance.abs())
                .reduce(math.max)
                .clamp(1.0, double.infinity);
      final sortedAccounts = [...snapshot.accounts]
        ..sort((a, b) => b.balance.compareTo(a.balance));
      return LocalAskResult(
        headline: 'Net worth',
        amount: snapshot.netWorth,
        subtitle:
            '${rupee(snapshot.liquidAssets)} liquid cash · '
            '${rupee(snapshot.cardDues + snapshot.loanOutstanding)} total debt',
        bars: [
          for (final a in sortedAccounts.take(4))
            LocalAskBar(
              label: a.name,
              valueText: rupee(a.balance),
              ratio: (a.balance.abs() / maxBal).clamp(0.0, 1.0),
            ),
        ],
      );
    }

    // 3. Credit Cards & Dues
    if (RegExp(
      r'\b(card\s*due|credit\s*card|card\s*bill|statement|utilization|cards)\b',
    ).hasMatch(q)) {
      final sortedCards = [...snapshot.cards]
        ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
      final maxCard = sortedCards.isEmpty
          ? 1.0
          : sortedCards.first.outstanding.clamp(1.0, double.infinity);
      return LocalAskResult(
        headline: 'Credit card dues',
        amount: snapshot.cardDues,
        subtitle:
            '${snapshot.cards.length} card${snapshot.cards.length == 1 ? '' : 's'} · '
            '${rupee(snapshot.cards.fold<double>(0, (s, c) => s + c.limit))} total limit',
        bars: [
          for (final c in sortedCards.take(4))
            LocalAskBar(
              label: c.name,
              valueText: rupee(c.outstanding),
              ratio: (c.outstanding / maxCard).clamp(0.0, 1.0),
              sublabel: c.due == null
                  ? null
                  : 'Due ${dayMonth(c.due!.dueDate)}',
            ),
        ],
      );
    }

    // 4. Loans & EMIs
    if (RegExp(r'\b(loan|loans|emi|emis|debt)\b').hasMatch(q)) {
      final totalEmi = snapshot.loans.fold<double>(0, (s, l) => s + l.emi);
      final sortedLoans = [...snapshot.loans]
        ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
      final maxLoan = sortedLoans.isEmpty
          ? 1.0
          : sortedLoans.first.outstanding.clamp(1.0, double.infinity);
      return LocalAskResult(
        headline: 'Loan outstanding',
        amount: snapshot.loanOutstanding,
        subtitle:
            '${snapshot.loans.length} loan${snapshot.loans.length == 1 ? '' : 's'} · '
            '${rupee(totalEmi)}/mo total EMI',
        bars: [
          for (final l in sortedLoans.take(4))
            LocalAskBar(
              label: l.name,
              valueText: rupee(l.outstanding),
              ratio: (l.outstanding / maxLoan).clamp(0.0, 1.0),
              sublabel: '${rupee(l.emi)}/mo · ${l.rate.toStringAsFixed(1)}%',
            ),
        ],
      );
    }

    // 5. Subscriptions & Upcoming Bills
    if (RegExp(
      r'\b(subscription|subscriptions|renewal|renewals|recurring|upcoming\s*bill|bills\s*due)\b',
    ).hasMatch(q)) {
      final active = snapshot.subscriptions.where((s) => s.active).toList()
        ..sort((a, b) => b.price.compareTo(a.price));
      final monthly = active.fold<double>(0, (s, sub) => s + sub.price);
      final maxSub = active.isEmpty
          ? 1.0
          : active.first.price.clamp(1.0, double.infinity);
      return LocalAskResult(
        headline: 'Active subscriptions',
        amount: monthly,
        subtitle:
            '${active.length} active · ${rupee(monthly * 12)}/year',
        bars: [
          for (final sub in active.take(4))
            LocalAskBar(
              label: sub.name,
              valueText: '${rupee(sub.price)}/mo',
              ratio: (sub.price / maxSub).clamp(0.0, 1.0),
            ),
        ],
      );
    }

    // 6. Split / Who owes whom
    if (RegExp(r'\b(split|owe|owed|owes|friends|roommate)\b').hasMatch(q)) {
      var net = 0.0;
      for (final g in snapshot.groups) {
        net += g.yourBalance;
      }
      final maxGrp = snapshot.groups.isEmpty
          ? 1.0
          : snapshot.groups
                .map((g) => g.yourBalance.abs())
                .reduce(math.max)
                .clamp(1.0, double.infinity);
      return LocalAskResult(
        headline: net >= 0 ? 'Owed to you (Split)' : 'You owe (Split)',
        amount: net.abs(),
        subtitle:
            '${snapshot.groups.length} group${snapshot.groups.length == 1 ? '' : 's'}',
        bars: [
          for (final g in snapshot.groups.take(4))
            LocalAskBar(
              label: g.name,
              valueText:
                  '${g.yourBalance >= 0 ? '+' : '-'}${rupee(g.yourBalance.abs())}',
              ratio: (g.yourBalance.abs() / maxGrp).clamp(0.0, 1.0),
            ),
        ],
      );
    }

    // 7. Month-over-Month Comparison
    if (RegExp(r'\b(compare|vs\s*last\s*month|more\s*than\s*last|month\s*over\s*month)\b')
        .hasMatch(q)) {
      final thisM = DateTime(n.year, n.month, 1);
      final lastM = DateTime(n.year, n.month - 1, 1);
      final thisFlow = snapshot.flow(thisM);
      final lastFlow = snapshot.flow(lastM);
      final diff = thisFlow.expense - lastFlow.expense;
      final pct = lastFlow.expense > 0
          ? ((diff / lastFlow.expense) * 100).round()
          : 0;
      final dir = diff >= 0 ? 'more' : 'less';
      return LocalAskResult(
        headline: 'This month vs last month',
        amount: thisFlow.expense,
        subtitle:
            '${rupee(diff.abs())} $dir (${pct.abs()}%) than ${rupee(lastFlow.expense)} last month',
        bars: [
          LocalAskBar(
            label: 'This month',
            valueText: rupee(thisFlow.expense),
            ratio: math.max(thisFlow.expense, lastFlow.expense) <= 0
                ? 0
                : (thisFlow.expense /
                          math.max(thisFlow.expense, lastFlow.expense))
                      .clamp(0.0, 1.0),
          ),
          LocalAskBar(
            label: 'Last month',
            valueText: rupee(lastFlow.expense),
            ratio: math.max(thisFlow.expense, lastFlow.expense) <= 0
                ? 0
                : (lastFlow.expense /
                          math.max(thisFlow.expense, lastFlow.expense))
                      .clamp(0.0, 1.0),
          ),
        ],
      );
    }

    // 8. Transaction Query Engine (timeframes + all categories + merchants + tags + accounts)
    final range = _parseDateRange(q, n, today);
    final allCategories = <String>{
      ...snapshot.budgets.map((b) => b.category),
      ...snapshot.transactions.map((t) => t.category),
      ...knownCategories,
    }..removeWhere((c) => c.trim().isEmpty || c == 'Transfer');

    String? category;
    for (final cat in allCategories) {
      if (q.contains(cat.toLowerCase())) {
        category = cat;
        break;
      }
    }
    if (category == null && RegExp(r'\bmisc\b').hasMatch(q)) {
      if (allCategories.contains('Miscellaneous')) category = 'Miscellaneous';
    }

    final income = RegExp(r'\b(income|earn|earned|salary|credited)\b')
        .hasMatch(q);
    final spendOnly = RegExp(
      r'\b(spend|spends|spent|expense|expenses|biggest|largest|highest|most\s*expensive|top\s*spend)\b',
    ).hasMatch(q);
    final allTypes =
        !income &&
        !spendOnly &&
        RegExp(r'\b(transaction|transactions|txns|activity|entries)\b')
            .hasMatch(q);
    final biggest = RegExp(
      r'\b(biggest|largest|highest|most\s*expensive|top\s*spend)\b',
    ).hasMatch(q);
    final listMode =
        !biggest &&
        RegExp(
          r'\b(list|transactions|transaction|txns|spends\s+in|recent|show)\b',
        ).hasMatch(q);
    final weekendOnly = RegExp(r'\bweekend\b').hasMatch(q);

    // Match longest merchant name appearing in query
    String? merchant;
    final merchants = <String>{for (final t in snapshot.transactions) t.merchant}
      ..removeWhere((m) => m.trim().isEmpty);
    final sortedMerchants = merchants.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in sortedMerchants) {
      final lower = name.toLowerCase();
      if (lower.length >= 2 &&
          RegExp(r'\b' + RegExp.escape(lower) + r'\b').hasMatch(q)) {
        merchant = name;
        break;
      }
    }
    if (merchant == null) {
      for (final name in sortedMerchants) {
        final first = name.toLowerCase().split(' ').first;
        if (first.length > 2 &&
            RegExp(r'\b' + RegExp.escape(first) + r'\b').hasMatch(q)) {
          merchant = name;
          break;
        }
      }
    }

    // Match account or card
    String? accountId;
    String? cardId;
    String? sourceLabel;
    for (final a in snapshot.accounts) {
      if (q.contains(a.name.toLowerCase())) {
        accountId = a.id;
        sourceLabel = a.name;
        break;
      }
    }
    if (accountId == null) {
      for (final c in snapshot.cards) {
        if (q.contains(c.name.toLowerCase())) {
          cardId = c.id;
          sourceLabel = c.name;
          break;
        }
      }
    }

    // Match tag (checks #tag, snapshot.tags, and transaction tags)
    String? tag;
    String? tagLabel;
    final hashMatch = RegExp(r'#([a-z0-9_-]+)').firstMatch(q);
    final allTags = <String>{
      ...snapshot.tags,
      for (final t in snapshot.transactions) ...t.tags,
    };
    for (final tg in allTags) {
      final lower = tg.toLowerCase();
      if ((hashMatch != null && hashMatch.group(1) == lower) ||
          (tg.trim().length > 1 &&
              RegExp(r'\b' + RegExp.escape(lower) + r'\b').hasMatch(q))) {
        tag = tg;
        tagLabel = tg;
        break;
      }
    }

    final matches = snapshot.transactions.where((t) {
      if (t.date.isBefore(range.start) || !t.date.isBefore(range.end)) {
        return false;
      }
      if (weekendOnly && t.date.weekday < DateTime.saturday) return false;
      if (t.category == 'Transfer') return false;
      if (!allTypes && (income ? t.amount <= 0 : t.amount >= 0)) return false;
      if (category != null && t.category != category) return false;
      if (merchant != null && t.merchant != merchant) return false;
      if (accountId != null && t.accountId != accountId) return false;
      if (cardId != null && t.cardId != cardId) return false;
      if (tag != null &&
          !t.tags.any(
            (x) => x.toLowerCase() == tag!.toLowerCase(),
          )) {
        return false;
      }
      return true;
    }).toList();

    final total = allTypes
        ? matches.fold<double>(0, (sum, t) => sum + t.amount.abs())
        : matches.fold<double>(0, (sum, t) => sum + t.amount.abs());
    final cutoff = range.end.isAfter(today.add(const Duration(days: 1)))
        ? today.add(const Duration(days: 1))
        : range.end;
    final days = cutoff.difference(range.start).inDays.clamp(1, 10000);

    final bars = <LocalAskBar>[];
    if (biggest) {
      final sortedTx = [...matches]
        ..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
      final maxTx = sortedTx.isEmpty
          ? 1.0
          : sortedTx.first.amount.abs().clamp(1.0, double.infinity);
      for (final t in sortedTx.take(5)) {
        bars.add(
          LocalAskBar(
            label: t.merchant,
            valueText: rupee(t.amount.abs()),
            ratio: (t.amount.abs() / maxTx).clamp(0.0, 1.0),
            sublabel: '${t.category} · ${dayMonth(t.date)}',
          ),
        );
      }
    } else if (listMode) {
      final sortedTx = [...matches]
        ..sort((a, b) => b.date.compareTo(a.date));
      final maxTx = sortedTx.isEmpty
          ? 1.0
          : sortedTx
                .map((t) => t.amount.abs())
                .reduce(math.max)
                .clamp(1.0, double.infinity);
      for (final t in sortedTx.take(8)) {
        final sign = t.amount > 0 ? '+' : '';
        bars.add(
          LocalAskBar(
            label: t.merchant,
            valueText: '$sign${rupee(t.amount.abs())}',
            ratio: (t.amount.abs() / maxTx).clamp(0.0, 1.0),
            sublabel: '${t.category} · ${dayMonth(t.date)}',
          ),
        );
      }
    } else {
      final topMap = <String, double>{};
      for (final t in matches) {
        final key = merchant != null ? t.category : t.merchant;
        topMap[key] = (topMap[key] ?? 0) + t.amount.abs();
      }
      final top = topMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final maxTop = top.isEmpty
          ? 1.0
          : top.first.value.clamp(1.0, double.infinity);
      for (final entry in top.take(5)) {
        bars.add(
          LocalAskBar(
            label: entry.key,
            valueText: rupee(entry.value),
            ratio: (entry.value / maxTop).clamp(0.0, 1.0),
          ),
        );
      }
    }

    final parts = <String>[
      if (biggest)
        'Biggest ${income ? 'income' : 'spends'}'
      else if (allTypes)
        'Transactions'
      else
        (income ? 'Income' : 'Spent'),
      if (category != null) 'on $category',
      if (merchant != null) '· $merchant',
      if (sourceLabel != null) '· $sourceLabel',
      if (tagLabel != null) '· #$tagLabel',
      if (weekendOnly) '· weekends',
      '· ${range.label}',
    ];

    final hasExplicitFilter =
        category != null ||
        merchant != null ||
        sourceLabel != null ||
        tag != null ||
        income ||
        biggest ||
        listMode ||
        weekendOnly ||
        range.explicit ||
        RegExp(r'\b(total|spend|spent|merchants)\b').hasMatch(q);

    // Open-ended reasoning prompts should be flagged low-confidence so Hybrid
    // mode offers/uses AI when available.
    final looksConversational = RegExp(
      r'\b(why|how\s+can|should\s+i|can\s+i\s+afford|advise|advice|suggest|plan|cut|save|optimize)\b',
    ).hasMatch(q);

    return LocalAskResult(
      headline: parts.join(' '),
      amount: total,
      subtitle:
          '${matches.length} transaction${matches.length == 1 ? '' : 's'} · '
          '${rupee(total / days)} per day',
      bars: bars,
      isHighConfidence: hasExplicitFilter && !looksConversational,
      ledgerPrefill: LedgerPrefill(
        query: merchant ?? tag ?? '',
        category: category,
        from: range.start,
        to: range.end.subtract(const Duration(days: 1)),
      ),
    );
  }

  static ({DateTime start, DateTime end, String label, bool explicit})
  _parseDateRange(String q, DateTime now, DateTime today) {
    if (q.contains('today')) {
      return (
        start: today,
        end: today.add(const Duration(days: 1)),
        label: 'today',
        explicit: true,
      );
    }
    if (q.contains('yesterday')) {
      return (
        start: today.subtract(const Duration(days: 1)),
        end: today,
        label: 'yesterday',
        explicit: true,
      );
    }
    if (q.contains('last week')) {
      final thisMonday = today.subtract(Duration(days: now.weekday - 1));
      final lastMonday = thisMonday.subtract(const Duration(days: 7));
      return (
        start: lastMonday,
        end: thisMonday,
        label: 'last week',
        explicit: true,
      );
    }
    if (q.contains('this week') || q.contains('week')) {
      return (
        start: today.subtract(Duration(days: now.weekday - 1)),
        end: today.add(const Duration(days: 1)),
        label: 'this week',
        explicit: true,
      );
    }
    if (q.contains('last month')) {
      return (
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 1),
        label: 'last month',
        explicit: true,
      );
    }
    if (q.contains('last year')) {
      return (
        start: DateTime(now.year - 1, 1, 1),
        end: DateTime(now.year, 1, 1),
        label: 'last year',
        explicit: true,
      );
    }
    if (q.contains('year')) {
      return (
        start: DateTime(now.year, 1, 1),
        end: today.add(const Duration(days: 1)),
        label: 'this year',
        explicit: true,
      );
    }
    final lastDays = RegExp(r'last\s+(\d+)\s+days?').firstMatch(q);
    if (lastDays != null) {
      final n = int.parse(lastDays.group(1)!).clamp(1, 3650);
      return (
        start: today.subtract(Duration(days: n - 1)),
        end: today.add(const Duration(days: 1)),
        label: 'last $n days',
        explicit: true,
      );
    }
    final lastWeeks = RegExp(r'last\s+(\d+)\s+weeks?').firstMatch(q);
    if (lastWeeks != null) {
      final n = int.parse(lastWeeks.group(1)!).clamp(1, 260);
      return (
        start: today.subtract(Duration(days: n * 7 - 1)),
        end: today.add(const Duration(days: 1)),
        label: 'last $n weeks',
        explicit: true,
      );
    }
    final lastMonths = RegExp(r'last\s+(\d+)\s+months?').firstMatch(q);
    if (lastMonths != null) {
      final n = int.parse(lastMonths.group(1)!).clamp(1, 60);
      return (
        start: DateTime(now.year, now.month - n + 1, 1),
        end: today.add(const Duration(days: 1)),
        label: 'last $n months',
        explicit: true,
      );
    }
    // Explicit range like "1 nov to 10 nov" or "nov 1 to nov 10"
    final monthPattern = _monthNames.keys.join('|');
    final rangeMatch = RegExp(
      '(?:(\\d{1,2})\\s+($monthPattern)|($monthPattern)\\s+(\\d{1,2}))'
      '\\s*(?:to|and|-|–)\\s*'
      '(?:(\\d{1,2})\\s+($monthPattern)|($monthPattern)\\s+(\\d{1,2}))',
    ).firstMatch(q);
    if (rangeMatch != null) {
      final d1 = int.parse(rangeMatch.group(1) ?? rangeMatch.group(4)!);
      final m1 = _monthNames[rangeMatch.group(2) ?? rangeMatch.group(3)!]!;
      final d2 = int.parse(rangeMatch.group(5) ?? rangeMatch.group(8)!);
      final m2 = _monthNames[rangeMatch.group(6) ?? rangeMatch.group(7)!]!;
      final y1 = m1 > now.month ? now.year - 1 : now.year;
      final y2 = m2 < m1 ? y1 + 1 : y1;
      final startD = DateTime(y1, m1, d1.clamp(1, 31));
      final endD = DateTime(y2, m2, d2.clamp(1, 31)).add(
        const Duration(days: 1),
      );
      return (
        start: startD,
        end: endD.isAfter(startD) ? endD : startD.add(const Duration(days: 1)),
        label: '${dayMonth(startD)} – ${dayMonth(endD.subtract(const Duration(days: 1)))}',
        explicit: true,
      );
    }
    for (final entry in _monthNames.entries) {
      final mMatch = RegExp(
        r'\b' + entry.key + r'(?:\s+(\d{4}))?\b',
      ).firstMatch(q);
      if (mMatch != null) {
        final month = entry.value;
        final year = mMatch.group(1) != null
            ? int.parse(mMatch.group(1)!)
            : (month > now.month ? now.year - 1 : now.year);
        return (
          start: DateTime(year, month, 1),
          end: DateTime(year, month + 1, 1),
          label: '${monthFull[month - 1]} $year',
          explicit: true,
        );
      }
    }
    return (
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 1),
      label: 'this month',
      explicit: q.contains('this month'),
    );
  }
}
