import 'package:flutter/material.dart';

class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.monthlyContribution,
    required this.color,
  });

  final String id;
  final String name;
  double target;
  double saved;
  double monthlyContribution;
  final Color color;

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1);
  double get remaining => (target - saved).clamp(0, target);
  bool get isReached => saved >= target;

  Goal copyWith({
    String? name,
    double? target,
    double? saved,
    double? monthlyContribution,
  }) => Goal(
    id: id,
    name: name ?? this.name,
    target: target ?? this.target,
    saved: saved ?? this.saved,
    monthlyContribution: monthlyContribution ?? this.monthlyContribution,
    color: color,
  );
}
