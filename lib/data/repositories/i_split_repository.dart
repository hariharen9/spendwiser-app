import '../models/split_group.dart';

abstract interface class ISplitRepository {
  Future<void> addGroup({required String name, required List<String> members});

  Future<void> renameGroup(String groupId, String name);

  Future<void> removeGroup(String groupId);

  Future<void> addSplitExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required SplitType type,
    required Map<String, double> shares,
  });

  Future<void> editSplitExpense({
    required String groupId,
    required int index,
    required String description,
    required double amount,
    required String paidBy,
    required SplitType type,
    required Map<String, double> shares,
  });

  Future<void> deleteSplitExpense(String groupId, int index);

  Future<void> settleSplit({
    required String groupId,
    required String from,
    required String to,
    required double amount,
    required DateTime date,
  });
}
