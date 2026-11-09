import 'package:flutter/foundation.dart';

enum SplitType {
  equal('eq', 'Equally'),
  exact('ex', 'Exact ₹'),
  percent('pc', 'Percent');

  const SplitType(this.code, this.label);
  final String code;
  final String label;

  static SplitType fromCode(String code) => SplitType.values.firstWhere(
    (t) => t.code == code,
    orElse: () => SplitType.equal,
  );
}

@immutable
class SplitExpense {
  const SplitExpense({
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.shares,
    required this.type,
    required this.date,
    this.settledTo,
  });

  final String description;
  final double amount;
  final String paidBy;
  final Map<String, double> shares;
  final SplitType type;
  final DateTime date;
  final String? settledTo;

  bool get isSettlement => settledTo != null;
}

class SplitGroup {
  SplitGroup({
    required this.id,
    required this.name,
    required this.members,
    List<SplitExpense>? expenses,
  }) : expenses = expenses ?? <SplitExpense>[];

  final String id;
  final String name;
  final List<String> members;
  final List<SplitExpense> expenses;

  double get totalSpent => expenses
      .where((e) => !e.isSettlement)
      .fold(0, (sum, e) => sum + e.amount);

  Map<String, double> netBalances() {
    final net = <String, double>{for (final m in members) m: 0};
    for (final e in expenses) {
      net[e.paidBy] = (net[e.paidBy] ?? 0) + e.amount;
      if (e.settledTo != null) {
        net[e.settledTo!] = (net[e.settledTo!] ?? 0) - e.amount;
      } else {
        e.shares.forEach((member, share) {
          net[member] = (net[member] ?? 0) - share;
        });
      }
    }
    return net;
  }

  double get yourBalance => netBalances()['You'] ?? 0;

  /// Minimal set of transfers that settles the group.
  List<DebtTransfer> simplify() {
    final net = netBalances();
    final creditors = <MapEntry<String, double>>[];
    final debtors = <MapEntry<String, double>>[];
    net.forEach((name, value) {
      final rounded = value.roundToDouble();
      if (rounded > 0) creditors.add(MapEntry(name, rounded));
      if (rounded < 0) debtors.add(MapEntry(name, -rounded));
    });
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final transfers = <DebtTransfer>[];
    var i = 0;
    var j = 0;
    while (i < creditors.length && j < debtors.length) {
      final amount = creditors[i].value < debtors[j].value
          ? creditors[i].value
          : debtors[j].value;
      if (amount > 0) {
        transfers.add(
          DebtTransfer(
            from: debtors[j].key,
            to: creditors[i].key,
            amount: amount,
          ),
        );
      }
      creditors[i] = MapEntry(creditors[i].key, creditors[i].value - amount);
      debtors[j] = MapEntry(debtors[j].key, debtors[j].value - amount);
      if (creditors[i].value <= 0.01) i++;
      if (debtors[j].value <= 0.01) j++;
    }
    return transfers;
  }
}

@immutable
class DebtTransfer {
  const DebtTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });

  final String from;
  final String to;
  final double amount;
}

/// Even split helper matching the prototype (first member absorbs rounding).
Map<String, double> splitEqually(double amount, List<String> members) {
  if (members.isEmpty) return {};
  final base = (amount / members.length * 100).floor() / 100;
  final shares = <String, double>{for (final m in members) m: base};
  shares[members.first] = double.parse(
    (amount - base * (members.length - 1)).toStringAsFixed(2),
  );
  return shares;
}
