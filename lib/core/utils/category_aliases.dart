/// Maps the prototype's short category names onto the web app's category set.
const categoryAliases = <String, String>{
  'Food': 'Food & Dining',
  'Bills': 'Bills & EMIs',
  'Rent': 'Rent & Housing',
  'Shop': 'Shopping',
  'Fun': 'Entertainment',
  'EMI': 'Bills & EMIs',
};

String resolveCategoryName(String raw, Iterable<String> available) {
  final names = available.toList(growable: false);
  if (names.contains(raw)) return raw;
  final mapped = categoryAliases[raw];
  if (mapped != null && names.contains(mapped)) return mapped;
  return names.isEmpty ? raw : names.first;
}
