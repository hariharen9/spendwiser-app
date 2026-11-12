import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/date_helpers.dart';
import '../models/bill.dart';
import '../models/credit_card.dart';
import '../models/finance_snapshot.dart';
import '../models/loan.dart';
import '../models/subscription.dart';
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
class CashRunwayPoint {
  const CashRunwayPoint({required this.date, required this.balance});

  final DateTime date;
  final double balance;
}

@immutable
class CashRunwayEvent {
  const CashRunwayEvent({
    required this.date,
    required this.label,
    required this.amount,
    required this.isIncome,
  });

  final DateTime date;
  final String label;

  /// Positive for income, negative for a bill or other commitment.
  final double amount;
  final bool isIncome;
}

@immutable
class CashRunway {
  const CashRunway({
    required this.startDate,
    required this.startingBalance,
    required this.endingBalance,
    required this.lowestBalance,
    required this.lowestDate,
    required this.payday,
    required this.expectedIncome,
    required this.dailySpend,
    required this.totalBills,
    required this.days,
    required this.points,
    required this.events,
  });

  final DateTime startDate;
  final double startingBalance;
  final double endingBalance;
  final double lowestBalance;
  final DateTime lowestDate;
  final DateTime? payday;
  final double expectedIncome;
  final double dailySpend;
  final double totalBills;
  final int days;
  final List<CashRunwayPoint> points;
  final List<CashRunwayEvent> events;

  bool get hasPayday => payday != null;
  bool get paydayInWindow =>
      payday != null && payday!.difference(startDate).inDays <= days;
  bool get isShortfall => lowestBalance < 0;
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
    card.outstanding = math.max(
      0,
      (card.openingOutstanding + charges - paid).roundToDouble(),
    );
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
    final spent = snapshot.hasTotalBudget
        ? snapshot.expensesIn(n)
        : snapshot.totalBudgetSpent;
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

  /// Projects liquid cash until the next expected income, net of upcoming
  /// bills and typical daily spending.
  static CashRunway cashRunway(FinanceSnapshot snapshot, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final start = todayFrom(n);
    final starting = snapshot.liquidAssets;
    final nextIncome = _nextIncome(snapshot, start);
    final payday = nextIncome?.date;
    final expectedIncome = nextIncome?.amount ?? 0;
    final window = (payday == null ? 30 : payday.difference(start).inDays)
        .clamp(1, 60)
        .toInt();
    final upcoming = bills(
      snapshot,
      now: n,
    ).where((bill) => bill.days >= 0 && bill.days <= window).toList();
    final commitments = <({DateTime date, String label, double amount})>[
      for (final bill in upcoming)
        (date: dateOnly(bill.dueDate), label: bill.name, amount: bill.amount),
    ];
    final subscribedIds = <String>{
      for (final subscription in snapshot.subscriptions.where(
        (subscription) => subscription.active,
      ))
        if (subscription.recurringId != null) subscription.recurringId!,
    };
    final trackedKeys = <String>{
      for (final bill in upcoming) _normMerchant(bill.name),
      for (final s in snapshot.subscriptions.where((s) => s.active))
        _normMerchant(s.name),
    }..remove('');
    final limit = start.add(Duration(days: window));

    for (final recurring in snapshot.recurring.where(
      (item) => item.active && !item.isIncome,
    )) {
      final recurringKey = _normMerchant(recurring.name);
      if (recurringKey.isNotEmpty) trackedKeys.add(recurringKey);
      if (subscribedIds.contains(recurring.id)) continue;
      final base = recurring.lastProcessedDate ?? recurring.startDate;
      var date = base == null
          ? DateTime(start.year, start.month + 1, 1)
          : _addRecurring(dateOnly(base), recurring.frequency);
      var guard = 0;
      while (!date.isAfter(start) && guard++ < 120) {
        date = _addRecurring(date, recurring.frequency);
      }
      final paidThisMonth =
          recurring.frequency == RecurringFrequency.monthly &&
          snapshot.transactions.any(
            (t) =>
                t.amount < 0 &&
                t.date.year == start.year &&
                t.date.month == start.month &&
                _normMerchant(t.merchant) == recurringKey,
          );
      while (!date.isAfter(limit) && guard++ < 240) {
        final sameMonth = date.year == start.year && date.month == start.month;
        if (!(paidThisMonth && sameMonth)) {
          commitments.add((
            date: dateOnly(date),
            label: recurring.name,
            amount: recurring.amount.abs(),
          ));
        }
        date = _addRecurring(date, recurring.frequency);
      }
    }

    // Auto-detect recurring monthly outflows from transaction history that
    // aren't explicitly registered in `recurring` or `subscriptions`.
    final detectedRecurring = _detectRecurringOutflows(
      snapshot,
      start,
      trackedKeys,
    );
    final detectedKeys = <String>{};
    for (final det in detectedRecurring) {
      detectedKeys.add(det.key);
      for (var mOffset = 0; mOffset <= 2; mOffset++) {
        final targetMonth = DateTime(start.year, start.month + mOffset, 1);
        final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
        final dueDate = DateTime(
          targetMonth.year,
          targetMonth.month,
          det.expectedDay.clamp(1, lastDay),
        );
        if (dueDate.isBefore(start) || dueDate.isAfter(limit)) continue;
        final sameMonth =
            dueDate.year == start.year && dueDate.month == start.month;
        if (det.paidThisMonth && sameMonth) continue;
        commitments.add((
          date: dueDate,
          label: det.label,
          amount: det.amount,
        ));
      }
    }

    final spendModel = _RunwaySpendModel.fromSnapshot(
      snapshot,
      start: start,
      extraExcludedMerchants: {...trackedKeys, ...detectedKeys},
    );

    var balance = starting;
    var lowest = starting;
    var lowestDate = start;
    var projectedVariableTotal = 0.0;
    final points = <CashRunwayPoint>[];
    final events = <CashRunwayEvent>[];

    for (var d = 0; d <= window; d++) {
      final date = start.add(Duration(days: d));
      if (payday != null &&
          payday.difference(start).inDays == d &&
          expectedIncome > 0) {
        balance += expectedIncome;
        events.add(
          CashRunwayEvent(
            date: date,
            label: 'Payday',
            amount: expectedIncome,
            isIncome: true,
          ),
        );
      }
      if (d > 0) {
        final daySpend = spendModel.dailyFor(date);
        balance -= daySpend;
        projectedVariableTotal += daySpend;
      }
      for (final commitment in commitments.where(
        (commitment) => commitment.date.difference(start).inDays == d,
      )) {
        balance -= commitment.amount;
        events.add(
          CashRunwayEvent(
            date: date,
            label: commitment.label,
            amount: -commitment.amount,
            isIncome: false,
          ),
        );
      }
      points.add(CashRunwayPoint(date: date, balance: balance));
      if (balance < lowest) {
        lowest = balance;
        lowestDate = date;
      }
    }

    final dailySpend = window > 0 ? projectedVariableTotal / window : 0.0;

    return CashRunway(
      startDate: start,
      startingBalance: starting,
      endingBalance: points.isEmpty ? starting : points.last.balance,
      lowestBalance: lowest,
      lowestDate: lowestDate,
      payday: payday,
      expectedIncome: expectedIncome,
      dailySpend: dailySpend,
      totalBills: commitments.fold(0.0, (sum, item) => sum + item.amount),
      days: window,
      points: List.unmodifiable(points),
      events: List.unmodifiable(events),
    );
  }

  static ({DateTime date, double amount})? _nextIncome(
    FinanceSnapshot snapshot,
    DateTime today,
  ) {
    DateTime? bestDate;
    var bestAmount = 0.0;

    for (final recurring in snapshot.recurring.where(
      (item) => item.active && item.isIncome,
    )) {
      final base = recurring.lastProcessedDate ?? recurring.startDate;
      DateTime next;
      if (base == null) {
        next = DateTime(today.year, today.month + 1, 1);
      } else {
        next = _addRecurring(dateOnly(base), recurring.frequency);
        var guard = 0;
        while (!next.isAfter(today) && guard++ < 120) {
          next = _addRecurring(next, recurring.frequency);
        }
      }
      if (next.isAfter(today) &&
          (bestDate == null || next.isBefore(bestDate))) {
        bestDate = next;
        bestAmount = recurring.amount.abs();
      }
    }

    if (bestDate != null && bestAmount > 0) {
      return (date: bestDate, amount: bestAmount);
    }

    final cutoff = today.subtract(const Duration(days: 180));
    final counts = <int, int>{};
    final totals = <int, double>{};
    for (final transaction in snapshot.transactions) {
      if (transaction.amount > 0 &&
          transaction.category != 'Transfer' &&
          !transaction.date.isBefore(cutoff)) {
        final day = transaction.date.day;
        counts[day] = (counts[day] ?? 0) + 1;
        totals[day] = (totals[day] ?? 0) + transaction.amount;
      }
    }
    if (counts.isEmpty) return null;

    var day = counts.keys.first;
    for (final candidate in counts.keys) {
      if (counts[candidate]! > counts[day]! ||
          (counts[candidate] == counts[day] &&
              (totals[candidate] ?? 0) > (totals[day] ?? 0))) {
        day = candidate;
      }
    }
    final expected = avgMonthlyIncome(snapshot, now: today);
    if (expected <= 0) return null;
    return (date: _nextDayOfMonth(today, day), amount: expected);
  }

  static DateTime _addRecurring(DateTime date, RecurringFrequency frequency) {
    return switch (frequency) {
      RecurringFrequency.daily => DateTime(date.year, date.month, date.day + 1),
      RecurringFrequency.weekly => DateTime(
        date.year,
        date.month,
        date.day + 7,
      ),
      RecurringFrequency.monthly => DateTime(
        date.year,
        date.month + 1,
        date.day,
      ),
      RecurringFrequency.yearly => DateTime(
        date.year + 1,
        date.month,
        date.day,
      ),
    };
  }

  static DateTime _nextDayOfMonth(DateTime today, int day) {
    DateTime at(int year, int month) {
      final last = daysInMonth(year, month);
      return DateTime(year, month, math.min(day, last));
    }

    final thisMonth = at(today.year, today.month);
    if (thisMonth.isAfter(today)) return thisMonth;
    return at(today.year, today.month + 1);
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

  static const _fixedCategories = <String>{
    'Transfer',
    'EMI',
    'Bills & EMIs',
    'Bills',
    'Rent & Housing',
    'Rent',
    'Utilities',
    'Investment',
  };

  static String _normMerchant(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Estimates typical *variable* daily cash spend for Cash Runway.
  ///
  /// Excludes fixed/committed categories (rent, EMIs, bills, utilities,
  /// investments, transfers), credit-card swipes (covered by card dues),
  /// and active recurring/subscription merchants (scheduled separately),
  /// then caps single-day outliers so lump-sum purchases don't skew the curve.
  static double discretionaryDailySpend(
    FinanceSnapshot snapshot, {
    DateTime? now,
  }) {
    final start = todayFrom(now ?? snapshot.generatedAt);
    final detected = _detectRecurringOutflows(snapshot, start, const {});
    return _RunwaySpendModel.fromSnapshot(
      snapshot,
      start: start,
      extraExcludedMerchants: {for (final d in detected) d.key},
    ).overallMean;
  }

  static List<
    ({
      String label,
      String key,
      double amount,
      int expectedDay,
      bool paidThisMonth,
    })
  >
  _detectRecurringOutflows(
    FinanceSnapshot snapshot,
    DateTime start,
    Set<String> alreadyTracked,
  ) {
    final cutoff = start.subtract(const Duration(days: 180));
    final byMerchant = <String, List<Transaction>>{};
    for (final t in snapshot.transactions) {
      if (t.amount >= 0) continue;
      if (t.cardId != null && t.cardId!.isNotEmpty) continue;
      if (t.category == 'Transfer') continue;
      final day = dateOnly(t.date);
      if (day.isBefore(cutoff) || day.isAfter(start)) continue;
      final key = _normMerchant(t.merchant);
      if (key.isEmpty || alreadyTracked.contains(key)) continue;
      byMerchant.putIfAbsent(key, () => []).add(t);
    }

    final detected =
        <
          ({
            String label,
            String key,
            double amount,
            int expectedDay,
            bool paidThisMonth,
          })
        >[];
    for (final entry in byMerchant.entries) {
      final txs = entry.value;
      final months = <int>{for (final t in txs) t.date.year * 12 + t.date.month};
      // Must span >= 2 distinct months and occur roughly once per month.
      if (months.length < 2 || txs.length > months.length + 1) continue;

      final amounts = txs.map((t) => t.amount.abs()).toList()..sort();
      final mid = amounts.length ~/ 2;
      final medianAmount = amounts.length.isOdd
          ? amounts[mid]
          : (amounts[mid - 1] + amounts[mid]) / 2;
      if (medianAmount <= 0) continue;
      if (amounts.first < medianAmount * 0.65 ||
          amounts.last > medianAmount * 1.35) {
        continue;
      }

      final days = txs.map((t) => t.date.day).toList()..sort();
      final daySpread = days.last - days.first;
      // Handle month-boundary wrap (e.g., 30th and 2nd) if spread is wide.
      final wrappedSpread = daySpread <= 8
          ? daySpread
          : (30 - days.last) + days.first;
      if (wrappedSpread > 8) continue;

      final expectedDay = days[days.length ~/ 2].clamp(1, 31);
      final paidThisMonth = txs.any(
        (t) => t.date.year == start.year && t.date.month == start.month,
      );
      detected.add((
        label: txs.last.merchant,
        key: entry.key,
        amount: medianAmount,
        expectedDay: expectedDay,
        paidThisMonth: paidThisMonth,
      ));
    }
    return detected;
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

/// Phase-aware, recency-weighted, outlier-resistant variable spend model used
/// by [FinanceCalculator.cashRunway].
class _RunwaySpendModel {
  const _RunwaySpendModel({
    required this.overallMean,
    required this.phaseRates,
    required this.weekdayMult,
    required this.weekendMult,
  });

  final double overallMean;
  final List<double> phaseRates;
  final double weekdayMult;
  final double weekendMult;

  static int _phaseOf(int dayOfMonth) {
    if (dayOfMonth <= 7) return 0; // Early month
    if (dayOfMonth <= 20) return 1; // Mid month
    return 2; // Late month
  }

  static _RunwaySpendModel fromSnapshot(
    FinanceSnapshot snapshot, {
    required DateTime start,
    Set<String> extraExcludedMerchants = const {},
  }) {
    final cutoff = start.subtract(const Duration(days: 120));
    final excluded = <String>{
      for (final s in snapshot.subscriptions.where((s) => s.active))
        FinanceCalculator._normMerchant(s.name),
      for (final r in snapshot.recurring.where((r) => r.active && !r.isIncome))
        FinanceCalculator._normMerchant(r.name),
      ...extraExcludedMerchants,
    }..remove('');

    final byDay = <DateTime, double>{};
    DateTime? earliest;
    for (final t in snapshot.transactions) {
      if (t.amount >= 0) continue;
      if (t.cardId != null && t.cardId!.isNotEmpty) continue;
      if (FinanceCalculator._fixedCategories.contains(t.category)) continue;
      if (excluded.contains(FinanceCalculator._normMerchant(t.merchant))) {
        continue;
      }
      final day = dateOnly(t.date);
      if (day.isBefore(cutoff) || day.isAfter(start)) continue;
      if (earliest == null || day.isBefore(earliest)) earliest = day;
      byDay[day] = (byDay[day] ?? 0) - t.amount;
    }

    if (byDay.isEmpty || earliest == null) {
      return const _RunwaySpendModel(
        overallMean: 0,
        phaseRates: [0, 0, 0],
        weekdayMult: 1,
        weekendMult: 1,
      );
    }

    final sortedNonZero = byDay.values.toList()..sort();
    final mid = sortedNonZero.length ~/ 2;
    final median = sortedNonZero.length.isOdd
        ? sortedNonZero[mid]
        : (sortedNonZero[mid - 1] + sortedNonZero[mid]) / 2;
    final cap = math.max(median * 3.0, 2500.0);

    final spanDays = (start.difference(earliest).inDays + 1).clamp(7, 120);
    final windowStart = start.subtract(Duration(days: spanDays - 1));

    var totalWeighted = 0.0;
    var totalWeight = 0.0;
    final phaseSum = <double>[0, 0, 0];
    final phaseWeight = <double>[0, 0, 0];
    var weekdaySum = 0.0;
    var weekdayWeight = 0.0;
    var weekendSum = 0.0;
    var weekendWeight = 0.0;

    for (var i = 0; i < spanDays; i++) {
      final day = windowStart.add(Duration(days: i));
      final age = start.difference(day).inDays;
      final w = age <= 30 ? 1.5 : (age <= 60 ? 1.0 : 0.7);
      final spend = math.min(byDay[day] ?? 0.0, cap);

      totalWeighted += spend * w;
      totalWeight += w;

      final phase = _phaseOf(day.day);
      phaseSum[phase] += spend * w;
      phaseWeight[phase] += w;

      if (day.weekday >= DateTime.saturday) {
        weekendSum += spend * w;
        weekendWeight += w;
      } else {
        weekdaySum += spend * w;
        weekdayWeight += w;
      }
    }

    final overallMean = totalWeight > 0 ? totalWeighted / totalWeight : 0.0;
    if (overallMean <= 0) {
      return const _RunwaySpendModel(
        overallMean: 0,
        phaseRates: [0, 0, 0],
        weekdayMult: 1,
        weekendMult: 1,
      );
    }

    const phasePrior = 5.0;
    final phaseRates = List<double>.generate(
      3,
      (p) => (phaseSum[p] + phasePrior * overallMean) /
          (phaseWeight[p] + phasePrior),
    );

    const dowPrior = 7.0;
    final wdRate = (weekdaySum + dowPrior * overallMean) /
        (weekdayWeight + dowPrior);
    final weRate = (weekendSum + dowPrior * overallMean) /
        (weekendWeight + dowPrior);
    final avgWeekRate = (5 * wdRate + 2 * weRate) / 7;
    final weekdayMult = avgWeekRate > 0
        ? (wdRate / avgWeekRate).clamp(0.65, 1.65)
        : 1.0;
    final weekendMult = avgWeekRate > 0
        ? (weRate / avgWeekRate).clamp(0.65, 1.65)
        : 1.0;

    return _RunwaySpendModel(
      overallMean: overallMean,
      phaseRates: phaseRates,
      weekdayMult: weekdayMult,
      weekendMult: weekendMult,
    );
  }

  double dailyFor(DateTime date) {
    final base = phaseRates[_phaseOf(date.day)];
    final mult = date.weekday >= DateTime.saturday ? weekendMult : weekdayMult;
    return base * mult;
  }
}
