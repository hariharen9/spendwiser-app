class Investment {
  Investment({
    required this.id,
    required this.name,
    required this.type,
    required this.invested,
    required this.value,
    this.monthlySip = 0,
  });

  final String id;
  final String name;
  String type;
  double invested;
  double value;
  double monthlySip;

  double get gain => value - invested;
  double get gainPercent => invested <= 0 ? 0 : (value / invested - 1) * 100;

  Investment copyWith({
    String? name,
    String? type,
    double? invested,
    double? value,
    double? monthlySip,
  }) => Investment(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    invested: invested ?? this.invested,
    value: value ?? this.value,
    monthlySip: monthlySip ?? this.monthlySip,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'invested': invested,
    'value': value,
    'monthlySip': monthlySip,
  };

  factory Investment.fromJson(Map<String, dynamic> j) => Investment(
    id: j['id'] as String,
    name: j['name'] as String,
    type: j['type'] as String? ?? 'Mutual Fund',
    invested: (j['invested'] as num? ?? 0).toDouble(),
    value: (j['value'] as num? ?? 0).toDouble(),
    monthlySip: (j['monthlySip'] as num? ?? 0).toDouble(),
  );
}
