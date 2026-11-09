import 'package:flutter/foundation.dart';

import '../../../core/theme/app_colors.dart';

class Budget {
  Budget({
    required this.category,
    required this.limit,
    this.spent = 0,
    this.rollover = false,
    this.alertAt = 80,
  });

  final String category;
  double limit;
  double spent;
  bool rollover;
  int alertAt;

  double get progress => limit <= 0 ? 0 : spent / limit;
  double get remaining => limit - spent;
  double get overBy => spent > limit ? spent - limit : 0;
  bool get isOver => spent > limit;
  bool get isNearLimit => progress >= 0.85;
  bool get shouldAlert => progress >= alertAt / 100;

  Budget copyWith({
    double? limit,
    double? spent,
    bool? rollover,
    int? alertAt,
  }) => Budget(
    category: category,
    limit: limit ?? this.limit,
    spent: spent ?? this.spent,
    rollover: rollover ?? this.rollover,
    alertAt: alertAt ?? this.alertAt,
  );
}

@immutable
class BudgetMonthPoint {
  const BudgetMonthPoint({required this.label, required this.spent});

  final String label;
  final double spent;
}

@immutable
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.amount,
    required this.count,
  });

  final String category;
  final double amount;
  final int count;

  String get colorHex => AppColors.toHex(AppColors.category(category));
}
