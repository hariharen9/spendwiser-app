import 'package:flutter/foundation.dart';

enum BillKind { subscription, card, loan }

@immutable
class BillItem {
  const BillItem({
    required this.name,
    required this.amount,
    required this.days,
    required this.dueDate,
    required this.kind,
  });

  final String name;
  final double amount;
  final int days;
  final DateTime dueDate;
  final BillKind kind;

  String get relativeLabel {
    if (days < 0) return '${-days} days late';
    if (days == 0) return 'today';
    if (days == 1) return 'in 1 day';
    return 'in $days days';
  }
}
