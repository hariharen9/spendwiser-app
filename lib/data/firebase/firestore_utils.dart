import 'package:cloud_firestore/cloud_firestore.dart';

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String asString(dynamic value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

bool asBool(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<String> asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => asString(e)).where((e) => e.isNotEmpty).toList();
  }
  return const <String>[];
}

String firestoreDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? parseFirestoreDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        12,
      );
    }
    return DateTime.tryParse(raw)?.toLocal();
  }
  return null;
}

String nowIso() => DateTime.now().toUtc().toIso8601String();

DateTime calendarDate(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime addFrequency(DateTime date, String frequency) => switch (frequency) {
  'daily' => DateTime(date.year, date.month, date.day + 1),
  'weekly' => DateTime(date.year, date.month, date.day + 7),
  'yearly' => DateTime(date.year + 1, date.month, date.day),
  _ => DateTime(date.year, date.month + 1, date.day),
};
