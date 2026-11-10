import '../models/shortcut.dart';

class ShortcutMatch {
  const ShortcutMatch({required this.shortcut, required this.amount});

  final Shortcut shortcut;
  final double amount;
}

/// Matches the web app's `keyword.amount` macro, e.g. `coffee.250`.
ShortcutMatch? matchShortcut(String input, List<Shortcut> shortcuts) {
  final parts = input.trim().toLowerCase().split('.');
  if (parts.length != 2) return null;
  final keyword = parts[0].trim();
  final amount = double.tryParse(parts[1].trim());
  if (keyword.isEmpty || amount == null || amount <= 0) return null;
  for (final shortcut in shortcuts) {
    if (shortcut.keyword.toLowerCase() == keyword) {
      return ShortcutMatch(shortcut: shortcut, amount: amount);
    }
  }
  return null;
}
