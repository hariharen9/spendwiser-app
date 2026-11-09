abstract interface class IBudgetRepository {
  Future<void> addBudget({required String category, required double limit});

  Future<void> updateBudget({
    required String category,
    required double limit,
    required bool rollover,
    required int alertAt,
  });

  Future<void> removeBudget(String category);
}
