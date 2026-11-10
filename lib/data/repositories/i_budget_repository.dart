abstract interface class IBudgetRepository {
  Future<void> addBudget({
    required String category,
    required double limit,
    bool rollover = false,
    int alertAt = 80,
  });

  Future<void> updateBudget({
    required String category,
    required double limit,
    required bool rollover,
    required int alertAt,
  });

  Future<void> removeBudget(String category);

  Future<void> setTotalBudget(double limit);

  Future<void> removeTotalBudget();
}
