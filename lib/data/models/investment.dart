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
}
