class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.renewsInDays,
    this.active = true,
    this.note,
    this.category = 'Other',
    this.recurringId,
  });

  final String id;
  final String name;
  double price;
  int renewsInDays;
  bool active;
  String? note;
  final String category;

  /// Firestore `recurring_transactions` document id backing this view.
  final String? recurringId;

  Subscription copyWith({
    String? name,
    double? price,
    int? renewsInDays,
    bool? active,
    String? note,
    String? category,
    String? recurringId,
  }) => Subscription(
    id: id,
    name: name ?? this.name,
    price: price ?? this.price,
    renewsInDays: renewsInDays ?? this.renewsInDays,
    active: active ?? this.active,
    note: note ?? this.note,
    category: category ?? this.category,
    recurringId: recurringId ?? this.recurringId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'renewsInDays': renewsInDays,
    'active': active,
    'note': note,
    'category': category,
    'recurringId': recurringId,
  };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    id: j['id'] as String,
    name: j['name'] as String,
    price: (j['price'] as num? ?? 0).toDouble(),
    renewsInDays: (j['renewsInDays'] as num? ?? 0).toInt(),
    active: j['active'] as bool? ?? true,
    note: j['note'] as String?,
    category: j['category'] as String? ?? 'Other',
    recurringId: j['recurringId'] as String?,
  );
}

enum RecurringFrequency {
  daily('daily', 30),
  weekly('weekly', 4.3),
  monthly('monthly', 1),
  yearly('yearly', 1 / 12);

  const RecurringFrequency(this.label, this.monthlyFactor);
  final String label;
  final double monthlyFactor;

  static RecurringFrequency fromLabel(String label) =>
      RecurringFrequency.values.firstWhere(
        (f) => f.label == label,
        orElse: () => RecurringFrequency.monthly,
      );
}

class RecurringTransaction {
  RecurringTransaction({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.isIncome,
    this.category = 'Other',
    this.startDate,
    this.endDate,
    this.lastProcessedDate,
    this.accountId,
    this.note,
    this.active = true,
  });

  final String id;
  final String name;
  double amount;
  RecurringFrequency frequency;
  bool isIncome;
  final String category;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? lastProcessedDate;
  final String? accountId;
  final String? note;
  bool active;

  double get monthlyAmount => amount * frequency.monthlyFactor;

  RecurringTransaction copyWith({
    String? name,
    double? amount,
    RecurringFrequency? frequency,
    bool? isIncome,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastProcessedDate,
    String? accountId,
    String? note,
    bool? active,
  }) => RecurringTransaction(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    frequency: frequency ?? this.frequency,
    isIncome: isIncome ?? this.isIncome,
    category: category ?? this.category,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
    accountId: accountId ?? this.accountId,
    note: note ?? this.note,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'frequency': frequency.label,
    'isIncome': isIncome,
    'category': category,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'lastProcessedDate': lastProcessedDate?.toIso8601String(),
    'accountId': accountId,
    'note': note,
    'active': active,
  };

  factory RecurringTransaction.fromJson(Map<String, dynamic> j) =>
      RecurringTransaction(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: (j['amount'] as num? ?? 0).toDouble(),
        frequency: RecurringFrequency.fromLabel(j['frequency'] as String? ?? 'monthly'),
        isIncome: j['isIncome'] as bool? ?? false,
        category: j['category'] as String? ?? 'Other',
        startDate: j['startDate'] == null
            ? null
            : DateTime.tryParse(j['startDate'] as String),
        endDate: j['endDate'] == null
            ? null
            : DateTime.tryParse(j['endDate'] as String),
        lastProcessedDate: j['lastProcessedDate'] == null
            ? null
            : DateTime.tryParse(j['lastProcessedDate'] as String),
        accountId: j['accountId'] as String?,
        note: j['note'] as String?,
        active: j['active'] as bool? ?? true,
      );
}
