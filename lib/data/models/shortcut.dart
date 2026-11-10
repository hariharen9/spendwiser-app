import 'package:flutter/foundation.dart';

@immutable
class Shortcut {
  const Shortcut({
    required this.id,
    required this.keyword,
    required this.name,
    required this.amount,
    required this.category,
    required this.isIncome,
    this.accountId,
  });

  final String id;
  final String keyword;
  final String name;
  final double amount;
  final String category;
  final bool isIncome;
  final String? accountId;

  Shortcut copyWith({
    String? keyword,
    String? name,
    double? amount,
    String? category,
    bool? isIncome,
    String? accountId,
  }) => Shortcut(
    id: id,
    keyword: keyword ?? this.keyword,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    isIncome: isIncome ?? this.isIncome,
    accountId: accountId ?? this.accountId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'keyword': keyword,
    'name': name,
    'amount': amount,
    'category': category,
    'isIncome': isIncome,
    'accountId': accountId,
  };

  factory Shortcut.fromJson(Map<String, dynamic> json) => Shortcut(
    id: json['id'] as String,
    keyword: json['keyword'] as String? ?? '',
    name: json['name'] as String? ?? 'Shortcut',
    amount: (json['amount'] as num? ?? 0).toDouble(),
    category: json['category'] as String? ?? 'Other',
    isIncome:
        json['isIncome'] as bool? ??
        ((json['type'] as String?) == 'income'),
    accountId: json['accountId'] as String?,
  );
}
