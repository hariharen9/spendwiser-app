class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.renewsInDays,
    this.active = true,
    this.note,
  });

  final String id;
  final String name;
  double price;
  int renewsInDays;
  bool active;
  String? note;

  Subscription copyWith({
    String? name,
    double? price,
    int? renewsInDays,
    bool? active,
    String? note,
  }) => Subscription(
    id: id,
    name: name ?? this.name,
    price: price ?? this.price,
    renewsInDays: renewsInDays ?? this.renewsInDays,
    active: active ?? this.active,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'renewsInDays': renewsInDays,
    'active': active,
    'note': note,
  };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    id: j['id'] as String,
    name: j['name'] as String,
    price: (j['price'] as num? ?? 0).toDouble(),
    renewsInDays: (j['renewsInDays'] as num? ?? 0).toInt(),
    active: j['active'] as bool? ?? true,
    note: j['note'] as String?,
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
    this.active = true,
  });

  final String id;
  final String name;
  double amount;
  RecurringFrequency frequency;
  bool isIncome;
  bool active;

  double get monthlyAmount => amount * frequency.monthlyFactor;

  RecurringTransaction copyWith({
    String? name,
    double? amount,
    RecurringFrequency? frequency,
    bool? isIncome,
    bool? active,
  }) => RecurringTransaction(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    frequency: frequency ?? this.frequency,
    isIncome: isIncome ?? this.isIncome,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'frequency': frequency.label,
    'isIncome': isIncome,
    'active': active,
  };

  factory RecurringTransaction.fromJson(Map<String, dynamic> j) =>
      RecurringTransaction(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: (j['amount'] as num? ?? 0).toDouble(),
        frequency: RecurringFrequency.fromLabel(j['frequency'] as String? ?? 'monthly'),
        isIncome: j['isIncome'] as bool? ?? false,
        active: j['active'] as bool? ?? true,
      );
}
