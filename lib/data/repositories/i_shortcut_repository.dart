import '../models/shortcut.dart';

abstract interface class IShortcutRepository {
  Future<void> addShortcut({
    required String keyword,
    required String name,
    required double amount,
    required String category,
    required bool isIncome,
    String? accountId,
  });

  Future<void> updateShortcut(Shortcut shortcut);

  Future<void> removeShortcut(String shortcutId);
}
