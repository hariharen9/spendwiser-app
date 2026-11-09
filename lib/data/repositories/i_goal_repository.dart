import 'package:flutter/material.dart';

abstract interface class IGoalRepository {
  Future<void> addGoal({
    required String name,
    required double target,
    required double monthlyContribution,
    required Color color,
  });

  Future<void> updateGoal({
    required String goalId,
    required String name,
    required double target,
    required double monthlyContribution,
  });

  Future<void> addGoalMoney(String goalId, double amount, {String? accountId});

  Future<void> removeGoal(String goalId);
}
