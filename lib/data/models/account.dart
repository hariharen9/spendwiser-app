import 'package:flutter/material.dart';

enum AccountType {
  savings('Savings'),
  investments('Investments'),
  cash('Cash');

  const AccountType(this.label);
  final String label;

  static AccountType fromLabel(String label) => AccountType.values.firstWhere(
    (t) => t.label.toLowerCase() == label.toLowerCase(),
    orElse: () => AccountType.savings,
  );
}

@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.last4,
    this.gradient = const [Color(0xFF1D3A6B), Color(0xFF0B1530)],
  });

  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final String? last4;
  final List<Color> gradient;

  Account copyWith({String? name, AccountType? type, double? balance}) =>
      Account(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        last4: last4,
        gradient: gradient,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.label,
    'balance': balance,
    'last4': last4,
    'gradient': gradient.map((c) => c.toARGB32()).toList(),
  };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'] as String,
    name: j['name'] as String,
    type: AccountType.fromLabel(j['type'] as String? ?? 'Savings'),
    balance: (j['balance'] as num? ?? 0).toDouble(),
    last4: j['last4'] as String?,
    gradient: ((j['gradient'] as List?) ?? [])
        .map((e) => Color((e as num).toInt()))
        .toList(),
  );
}
