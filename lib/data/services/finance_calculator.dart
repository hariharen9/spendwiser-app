import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/date_helpers.dart';
import '../models/bill.dart';
import '../models/credit_card.dart';
import '../models/finance_snapshot.dart';
import '../models/loan.dart';
import '../models/transaction.dart';

enum PayoffStrategy { avalanche, snowball }

@immutable
class PayoffResult {
  const PayoffResult({
    required this.months,
    required this.interest,
    required this.finishMonths,
    required this.order,
    required this.history,
  });

  final int months;
  final double interest;
  final Map<int, int> finishMonths;
  final List<int> order;
  final List<double> history;
}

@immutable
class StrategyResult {
  const StrategyResult({
    required this.name,
    required this.result,
    required this.color,
  });

  final String name;
  final PayoffResult result;
  final Color color;
}

@immutable
class HealthComponent {
  const HealthComponent({
    required this.label,
    required this.score,
    required this.detail,
  });

  final String label;
  final double score;
  final String detail;
}

@immutable
class HealthReport {
  const HealthReport({required this.score, required this.components});

  final int score;
  final List<HealthComponent> components;
}

@immutable
class CashFlowPoint {
  const CashFlowPoint({required this.day, required this.balance});

  final int day;
  final double balance;
}

@immutable
class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final double income;
  final double expense;
}

abstract final class FinanceCalculator {
  static const double propertyValue = 2800000;

  // ---------------------------------------------------------------- cards ---

  static List<CardStatement> buildStatements(
    CreditCard card,
    List<Transaction> transactions, {
    DateTime? now,
  }) {
    final today = todayFrom(now);
    final cardTx = transactions.where((t) => t.cardId == card.id).toList();
    final sd = card.statementDay;
    final dd = card.dueDay;

    var latestEnd = DateTime(today.year, today.month, sd);
    if (latestEnd.isAfter(today)) {
      latestEnd = DateTime(today.year, today.month - 1, sd);
    }

    final statements = <CardStatement>[];
    for (var n = 0; n < 7; n++) {
      final end = DateTime(latestEnd.year, latestEnd.month - n, sd);
      final start = DateTime(end.year, end.month - 1, sd + 1);
      final due = dd > sd
          ? DateTime(end.year, end.month, dd)
          : DateTime(end.year, end.month + 1, dd);
      final endExclusive = end.add(const Duration(days: 1));

      var amount = 0.0;
      for (final t in cardTx) {
        if (!t.date.isBefore(start) && t.date.isBefore(endExclusive)) {
          amount -= t.amount;
        }
      }
      var paid = 0.0;
      for (final p in card.payments) {
        if (p.statementEnd != null &&
            dateOnly(p.statementEnd!).isAtSameMomentAs(end)) {
          paid += p.amount;
        }
      }
      final remaining = math.max(0.0, amount - paid);
      final status = amount <= 0
          ? StatementStatus.nil
          : remaining <= 0
          ? StatementStatus.paid
          : due.isBefore(today)
          ? StatementStatus.overdue
          : StatementStatus.due;

      statements.add(
        CardStatement(
          index: n,
          start: start,
          end: end,
          dueDate: due,
          amount: amount,
          paid: paid,
          remaining: remaining,
          status: status,
        ),
      );
    }
    return statements;
  }

  static CardCycle buildOpenCycle(
    CreditCard card,
    List<Transaction> transactions, {
    DateTime? now,
  }) {
    final today = todayFrom(now);
    var latestEnd = DateTime(today.year, today.month, card.statementDay);
    if (latestEnd.isAfter(today)) {
      latestEnd = DateTime(today.year, today.month - 1, card.statementDay);
    }
    final start = DateTime(
      latestEnd.year,
      latestEnd.month,
      card.statementDay + 1,
    );
    final end = DateTime(
      latestEnd.year,
      latestEnd.month + 1,
      card.statementDay,
    );
    final endExclusive = end.add(const Duration(days: 1));
    var amount = 0.0;
    for (final t in transactions.where((t) => t.cardId == card.id)) {
      if (!t.date.isBefore(start) && t.date.isBefore(endExclusive)) {
        amount -= t.amount;
      }
    }
    final daysLeft = math.max(0, end.difference(today).inDays);
    return CardCycle(
      start: start,
      end: end,
      amount: amount,
      daysLeft: daysLeft,
    );
  }

  /// Recomputes every derived card field in place, like the prototype's
  /// `recalc()` function.
  static void recalcCard(
    CreditCard card,
    List<Transaction> transactions, {
    DateTime? now,
  }) {
    final cardTx = transactions.where((t) => t.cardId == card.id).toList();
    card.payments = card.payments;
    card.statements = buildStatements(card, transactions, now: now);
    card.openCycle = buildOpenCycle(card, transactions, now: now);

    var charges = 0.0;
    var spend = 0.0;
    for (final t in cardTx) {
      charges -= t.amount;
      if (t.amount < 0) spend -= t.amount;
    }
    final paid = card.payments.fold(0.0, (sum, p) => sum + p.amount);
    card.outstanding = math.max(0, (charges - paid).roundToDouble());
    card.rewardPoints = (spend / 100).floor();

    final unpaid = card.statements.where((s) => s.remaining > 0).toList();
    if (unpaid.isEmpty) {
      card.due = null;
      card.minimumDue = 0;
      card.dueLabel = '—';
    } else {
      final oldest = unpaid.last;
      final total = unpaid.fold(0.0, (sum, s) => sum + s.remaining);
      card.due = CardDue(
        amount: total,
        days: oldest.dueDate.difference(todayFrom(now)).inDays,
        status: oldest.status,
        dueDate: oldest.dueDate,
      );
      card.minimumDue = math
          .max(50.0, (oldest.remaining * 0.05 / 10).round() * 10.0)
          .toDouble();
      card.dueLabel =
          '${weekdayShortSun[oldest.dueDate.weekday % 7]} ${oldest.dueDate.day} ${monthShort[oldest.dueDate.month - 1]}';
    }
    card.cycleLeftDays = card.openCycle?.daysLeft ?? 0;
  }

  static CardDue? earliestCardDue(FinanceSnapshot snapshot) {
    final dues = snapshot.cards.map((c) => c.due).whereType<CardDue>().toList()
      ..sort((a, b) => a.days.compareTo(b.days));
    return dues.isEmpty ? null : dues.first;
  }

  // ----------------------------------------------------------------- loans ---

  static LoanDue loanDue(Loan loan, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = todayFrom(n);
    final lastEmi = loan.payments
        .where((p) => p.type == LoanPaymentType.emi)
        .fold<DateTime?>(null, (latest, p) {
          if (latest == null || p.date.isAfter(latest)) return p.date;
          return latest;
        });
    final paidThisMonth =
        lastEmi != null && lastEmi.year == n.year && lastEmi.month == n.month;
    final due = DateTime(
      n.year,
      n.month + (paidThisMonth ? 1 : 0),
      loan.emiDay,
    );
    final days = dateOnly(due).difference(today).inDays;
    return LoanDue(date: due, days: days, overdue: due.isBefore(today));
  }

  static AmortizationResult amortize({
    required double balance,
    required double annualRate,
    required double emi,
    required DateTime firstDue,
    double extraMonthly = 0,
    double prepayment = 0,
  }) {
    var remaining = math.max(0.0, balance - prepayment);
    final monthlyRate = annualRate / 1200;
    final entries = <AmortizationEntry>[];
    var interestTotal = 0.0;
    var month = 0;

    while (remaining > 1 && month < 600) {
      month++;
      final interest = remaining * monthlyRate;
      final principal = math
          .min(emi + extraMonthly - interest, remaining)
          .clamp(0.0, remaining);
      if (principal <= 0) break;
      remaining -= principal;
      interestTotal += interest;
      entries.add(
        AmortizationEntry(
          month: month,
          date: DateTime(
            firstDue.year,
            firstDue.month + month - 1,
            firstDue.day,
          ),
          interest: interest,
          principal: principal,
          balance: math.max(0.0, remaining),
        ),
      );
    }
    return AmortizationResult(
      months: month,
      interest: interestTotal,
      entries: entries,
    );
  }

  static double emiFor(double principal, double annualRate, int months) {
    if (months <= 0) return 0;
    final r = annualRate / 1200;
    if (r == 0) return principal / months;
    final factor = math.pow(1 + r, months).toDouble();
    return principal * r * factor / (factor - 1);
  }

  static List<PayoffStrategy> allStrategies = PayoffStrategy.values;

  static PayoffResult simulatePayoff(
    FinanceSnapshot snapshot,
    double extraMonthly,
    PayoffStrategy strategy, {
    bool rollPayments = true,
  }) {
    final loans = snapshot.loans;
    final balances = loans.map((l) => l.outstanding).toList();
    final rates = loans.map((l) => l.rate).toList();
    final emis = loans.map((l) => l.emi).toList();
    final order = List<int>.generate(loans.length, (i) => i)
      ..sort(
        (a, b) => strategy == PayoffStrategy.avalanche
            ? rates[b].compareTo(rates[a])
            : balances[a].compareTo(balances[b]),
      );

    final finishMonths = <int, int>{};
    final history = <double>[balances.fold(0.0, (s, b) => s + b)];
    var month = 0;
    var interest = 0.0;

    bool anyDue() => balances.any((b) => b > 1);

    while (anyDue() && month < 600) {
      month++;
      var pool = rollPayments ? extraMonthly : 0.0;
      for (var i = 0; i < loans.length; i++) {
        if (balances[i] <= 1) {
          pool += rollPayments ? emis[i] : 0;
          continue;
        }
        final charged = balances[i] * rates[i] / 1200;
        interest += charged;
        balances[i] += charged;
        final payment = math.min(emis[i], balances[i]);
        balances[i] -= payment;
        pool += rollPayments ? emis[i] - payment : 0;
        if (balances[i] <= 1 && !finishMonths.containsKey(i)) {
          finishMonths[i] = month;
        }
      }
      for (final i in order) {
        if (balances[i] > 1 && pool > 0) {
          final payment = math.min(pool, balances[i]);
          balances[i] -= payment;
          pool -= payment;
          if (balances[i] <= 1 && !finishMonths.containsKey(i)) {
            finishMonths[i] = month;
          }
        }
      }
      history.add(balances.fold(0.0, (s, b) => s + math.max(0, b)));
    }

    return PayoffResult(
      months: month,
      interest: interest,
      finishMonths: finishMonths,
      order: order,
      history: history,
    );
  }

  static List<StrategyResult> strategies(
    FinanceSnapshot snapshot, {
    double extraMonthly = 5000,
  }) {
    return [
      StrategyResult(
        name: 'Minimum only',
        result: simulatePayoff(
          snapshot,
          0,
          PayoffStrategy.avalanche,
          rollPayments: false,
        ),
        color: const Color(0xFF8B8883),
      ),
      StrategyResult(
        name: 'Snowball',
        result: simulatePayoff(snapshot, extraMonthly, PayoffStrategy.snowball),
        color: const Color(0xFFFF6B4A),
      ),
      StrategyResult(
        name: 'Avalanche',
        result: simulatePayoff(
          snapshot,
          extraMonthly,
          PayoffStrategy.avalanche,
        ),
        color: const Color(0xFFD4FF3A),
      ),
    ];
  }

  // ------------------------------------------------------------------ home ---

  static SafeToSpend safeToSpend(FinanceSnapshot snapshot, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final limit = snapshot.totalBudgetLimit;
    final spent = snapshot.totalBudgetSpent;
    final left = math.max(0.0, limit - spent);
    final days = daysLeftInMonth(n);
    return SafeToSpend(
      limit: limit,
      spent: spent,
      left: left,
      perDay: (left / days / 10).round() * 10.0,
      daysLeft: days,
    );
  }

  static double avgMonthlyIncome(
    FinanceSnapshot snapshot, {
    int from = 1,
    int to = 3,
    DateTime? now,
  }) {
    final n = now ?? snapshot.generatedAt;
    var total = 0.0;
    var count = 0;
    for (var k = from; k <= to; k++) {
      total += snapshot.flow(monthAgo(k, now: n)).income;
      count++;
    }
    return count == 0 ? 0 : total / count;
  }

  static double avgMonthlySpend(
    FinanceSnapshot snapshot, {
    int from = 1,
    int to = 3,
    DateTime? now,
  }) {
    final n = now ?? snapshot.generatedAt;
    var total = 0.0;
    var count = 0;
    for (var k = from; k <= to; k++) {
      total += snapshot.flow(monthAgo(k, now: n)).expense;
      count++;
    }
    return count == 0 ? 0 : total / count;
  }

  static double avgDailySpend(FinanceSnapshot snapshot, {DateTime? now}) {
    final n = now ?? snapshot.generatedAt;
    final cutoff = n.subtract(const Duration(days: 90));
    var total = 0.0;
    for (final t in snapshot.transactions) {
      if (t.amount < 0 && t.category != 'Transfer' && t.date.isAfter(cutoff)) {
        total -= t.amount;
      }
    }
    final value = total / 90;
    return value <= 0 ? 1 : value;
  }

  static double runwayMonths(FinanceSnapshot snapshot, {DateTime? now}) =>
      snapshot.liquidAssets / (avgDailySpend(snapshot, now: now) * 30);

  static double bufferDays(FinanceSnapshot snapshot, {DateTime? now}) =>
      snapshot.liquidAssets / avgDailySpend(snapshot, now: now);

  static int streak(FinanceSnapshot snapshot, {DateTime? now}) {
    final days = <DateTime>{
      for (final t in snapshot.transactions) dateOnly(t.date),
    };
    var cursor = todayFrom(now);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static double lifestyleCreep(FinanceSnapshot snapshot, {DateTime? now}) {
    final recent = avgMonthlySpend(snapshot, from: 1, to: 3, now: now);
    final older = avgMonthlySpend(snapshot, from: 4, to: 6, now: now);
    return older == 0 ? 0 : (recent / older - 1) * 100;
  }

  static double incomeGrowth(FinanceSnapshot snapshot, {DateTime? now}) {
    final recent = avgMonthlyIncome(snapshot, from: 1, to: 3, now: now);
    final older = avgMonthlyIncome(snapshot, from: 4, to: 6, now: now);
    return older == 0 ? 0 : (recent / older - 1) * 100;
  }

  // ----------------------------------------------------------------- bills ---

  static List<BillItem> bills(FinanceSnapshot snapshot, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = todayFrom(n);
    final items = <BillItem>[];
    for (final subscription in snapshot.subscriptions.where((s) => s.active)) {
      final due = today.add(Duration(days: subscription.renewsInDays));
      items.add(
        BillItem(
          name: subscription.name,
          amount: subscription.price,
          days: subscription.renewsInDays,
          dueDate: due,
          kind: BillKind.subscription,
        ),
      );
    }
    for (final card in snapshot.cards) {
      final due = card.due;
      if (due != null && due.amount > 0) {
        items.add(
          BillItem(
            name: '${card.firstName} card',
            amount: due.amount,
            days: math.max(0, due.days),
            dueDate: due.dueDate,
            kind: BillKind.card,
          ),
        );
      }
    }
    for (final loan in snapshot.loans) {
      final due = loanDue(loan, now: n);
      items.add(
        BillItem(
          name: '${loan.name} EMI',
          amount: loan.emi,
          days: math.max(0, due.days),
          dueDate: due.date,
          kind: BillKind.loan,
        ),
      );
    }
    items.sort((a, b) => a.days.compareTo(b.days));
    return items;
  }

  static List<CashFlowPoint> cashFlowForecast(
    FinanceSnapshot snapshot, {
    int days = 30,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final upcoming = bills(snapshot, now: n);
    final income = avgMonthlyIncome(snapshot, now: n);
    var balance = snapshot.liquidAssets;
    final points = <CashFlowPoint>[];
    for (var d = 0; d < days; d++) {
      for (final bill in upcoming.where((b) => b.days == d)) {
        balance -= bill.amount;
      }
      final date = n.add(Duration(days: d));
      if (date.day == 1) balance += income;
      points.add(CashFlowPoint(day: d, balance: balance));
    }
    return points;
  }

  // -------------------------------------------------------------- insights ---

  static List<MonthPoint> monthSeries(
    FinanceSnapshot snapshot, {
    int count = 6,
    DateTime? now,
  }) {
    final n = now ?? snapshot.generatedAt;
    return [
      for (var k = count - 1; k >= 0; k--)
        () {
          final month = monthAgo(k, now: n);
          final flow = snapshot.flow(month);
          return MonthPoint(
            month: month,
            income: flow.income,
            expense: flow.expense,
          );
        }(),
    ];
  }

  static List<double> netWorthSeries(
    FinanceSnapshot snapshot, {
    int count = 6,
  }) {
    final current = snapshot.netWorth;
    final values = <double>[current];
    for (var k = 0; k < count - 1; k++) {
      final flow = snapshot.flow(monthAgo(k, now: snapshot.generatedAt));
      values.insert(0, values.first - flow.saved);
    }
    return values;
  }

  static HealthReport health(FinanceSnapshot snapshot, {DateTime? now}) {
    final n = now ?? snapshot.generatedAt;
    final income = avgMonthlyIncome(snapshot, now: n) == 0
        ? (snapshot.flow(monthStart(n)).income == 0
              ? 1
              : snapshot.flow(monthStart(n)).income)
        : avgMonthlyIncome(snapshot, now: n);
    final spend = avgMonthlySpend(snapshot, now: n) == 0
        ? (snapshot.flow(monthStart(n)).expense == 0
              ? 1
              : snapshot.flow(monthStart(n)).expense)
        : avgMonthlySpend(snapshot, now: n);
    final emis = snapshot.monthlyEmis;
    final utilisation = snapshot.cardLimitTotal == 0
        ? 0.0
        : snapshot.cardDues / snapshot.cardLimitTotal;
    final liquid = snapshot.liquidAssets;
    final disciplined = snapshot.budgets.isEmpty
        ? 100.0
        : snapshot.budgets.where((b) => b.spent <= b.limit).length /
              snapshot.budgets.length *
              100;
    final components = [
      HealthComponent(
        label: 'Savings rate',
        score: ((income - spend) / income * 200).clamp(0, 100).toDouble(),
        detail:
            'Saving ${((income - spend) / income * 100).round()}% of income',
      ),
      HealthComponent(
        label: 'Debt load',
        score: (100 - emis / income * 200).clamp(0, 100).toDouble(),
        detail: 'EMIs take ${(emis / income * 100).round()}% of income',
      ),
      HealthComponent(
        label: 'Card usage',
        score: (100 - utilisation * 200).clamp(0, 100).toDouble(),
        detail: '${(utilisation * 100).round()}% of limits used',
      ),
      HealthComponent(
        label: 'Safety net',
        score: math.min(100, liquid / spend / 6 * 100).toDouble(),
        detail: '${(liquid / spend).toStringAsFixed(1)} months of expenses',
      ),
      HealthComponent(
        label: 'Budget discipline',
        score: disciplined,
        detail: '${disciplined.round()}% of envelopes within limit',
      ),
    ];
    final score =
        (components.fold(0.0, (sum, c) => sum + c.score) / components.length)
            .round();
    return HealthReport(score: score, components: components);
  }

  /// Average spend per weekday over the last 90 days. Index 0 = Sunday.
  static List<double> weekdayAverages(
    FinanceSnapshot snapshot, {
    DateTime? now,
  }) {
    final n = now ?? snapshot.generatedAt;
    final cutoff = n.subtract(const Duration(days: 90));
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    var cursor = todayFrom(cutoff);
    while (cursor.isBefore(todayFrom(n))) {
      counts[cursor.weekday % 7]++;
      cursor = cursor.add(const Duration(days: 1));
    }
    for (final t in snapshot.transactions) {
      if (t.amount < 0 && t.category != 'Transfer' && t.date.isAfter(cutoff)) {
        sums[t.date.weekday % 7] -= t.amount;
      }
    }
    return [
      for (var i = 0; i < 7; i++) sums[i] / (counts[i] == 0 ? 1 : counts[i]),
    ];
  }

  static Map<int, double> spendIntensity(
    FinanceSnapshot snapshot,
    DateTime month,
  ) {
    final map = <int, double>{};
    for (final t in snapshot.inMonth(month)) {
      if (t.amount < 0 && t.category != 'Transfer') {
        map[t.date.day] = (map[t.date.day] ?? 0) - t.amount;
      }
    }
    return map;
  }

  static double projectedMonthEndSpend(
    FinanceSnapshot snapshot, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final month = monthStart(n);
    final days = daysInMonth(month.year, month.month);
    final today = n.day;
    var spent = 0.0;
    for (final t in snapshot.inMonth(month)) {
      if (t.amount < 0 && t.category != 'Transfer') spent -= t.amount;
    }
    final average = spent / math.max(1, today);
    return spent + average * (days - today);
  }

  static double remainingDiningSpend(FinanceSnapshot snapshot) {
    final month = monthStart(DateTime.now());
    final days = daysInMonth(month.year, month.month);
    final today = DateTime.now().day;
    var food = 0.0;
    for (final t in snapshot.inMonth(month)) {
      if (t.amount < 0 && t.category == 'Food') food -= t.amount;
    }
    final avg = food / math.max(1, today);
    return avg * (days - today);
  }

  static List<MapEntry<String, double>> topMerchants(
    FinanceSnapshot snapshot,
    DateTime month, {
    int limit = 7,
  }) {
    final map = <String, double>{};
    for (final t in snapshot.inMonth(month)) {
      if (t.amount < 0 && t.category != 'Transfer') {
        map[t.merchant] = (map[t.merchant] ?? 0) - t.amount;
      }
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  static List<String> recurringMerchants(
    FinanceSnapshot snapshot, {
    int months = 3,
  }) {
    final seen = <String, Set<int>>{};
    for (final t in snapshot.transactions) {
      if (t.amount < 0 && t.category != 'Transfer' && t.date.year > 2000) {
        final key = t.date.year * 12 + t.date.month;
        seen.putIfAbsent(t.merchant, () => <int>{}).add(key);
      }
    }
    return seen.entries
        .where((e) => e.value.length >= months)
        .map((e) => e.key)
        .take(5)
        .toList();
  }

  static String resultLabel(int months, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final d = DateTime(n.year, n.month + months, 1);
    return '${monthFull[d.month - 1]} ${d.year}';
  }
}
