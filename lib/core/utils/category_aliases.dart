/// Maps the prototype's short category names onto the web app's category set,
/// and provides fallbacks when a web category is absent from local defaults.
const categoryAliases = <String, String>{
  'Food': 'Food & Dining',
  'Bills': 'Bills & EMIs',
  'Rent': 'Rent & Housing',
  'Rent & Housing': 'Bills',
  'Utilities': 'Bills',
  'Shop': 'Shopping',
  'Fun': 'Entertainment',
  'EMI': 'Bills & EMIs',
  'Fuel': 'Travel',
  'Transportation': 'Travel',
  'Groceries': 'Food',
  'Healthcare': 'Miscellaneous',
  'Education': 'Miscellaneous',
  'Personal': 'Miscellaneous',
  'Investment': 'Miscellaneous',
  'Misc': 'Miscellaneous',
  'Mis': 'Miscellaneous',
};

String resolveCategoryName(String raw, Iterable<String> available) {
  final names = available.toList(growable: false);
  if (names.contains(raw)) return raw;
  final mapped = categoryAliases[raw];
  if (mapped != null && names.contains(mapped)) return mapped;
  if (names.contains('Other')) return 'Other';
  return names.isEmpty ? raw : names.first;
}
