import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/state/providers.dart';
import '../../data/models/finance_snapshot.dart';

/// File-based backup helpers: full JSON backup (settings + finance state)
/// and range-filtered ledger CSV export.
abstract final class BackupService {
  static String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }

  static Future<File> _writeFile(String name, String contents) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(contents);
    return file;
  }

  /// Build the full backup payload (delegates to the provider helper so the
  /// Hive boxes remain the single source of truth) and share it as a file.
  static Future<void> exportFullBackup() async {
    final payload = await exportBackup();
    final file = await _writeFile(
      'spendwiser-backup-${_timestamp()}.json',
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Spendwiser backup'),
    );
  }

  /// Ledger CSV for a date range; range is 'm' (this month), 'f' (financial
  /// year Apr–Mar) or 'a' (all time).
  static String buildLedgerCsv(FinanceSnapshot snapshot, String range) {
    final now = DateTime.now();
    DateTime? start;
    if (range == 'm') {
      start = DateTime(now.year, now.month, 1);
    } else if (range == 'f') {
      start = now.month >= 4
          ? DateTime(now.year, 4, 1)
          : DateTime(now.year - 1, 4, 1);
    }
    final rows = snapshot.transactions
        .where((t) => start == null || !t.date.isBefore(start))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final buffer = StringBuffer(
      'date,merchant,category,amount,account,card,note,tags\n',
    );
    for (final t in rows) {
      buffer.writeln(
        [
          t.date.toIso8601String().substring(0, 10),
          _csv(t.merchant),
          _csv(t.category),
          t.amount.toStringAsFixed(2),
          _csv(t.accountId ?? ''),
          _csv(t.cardId ?? ''),
          _csv(t.note),
          _csv(t.tags.join(' ')),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  static Future<void> exportLedgerCsv(FinanceSnapshot snapshot, String range) async {
    final file = await _writeFile(
      'spendwiser-ledger-$range-${_timestamp()}.csv',
      buildLedgerCsv(snapshot, range),
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Spendwiser ledger export'),
    );
  }

  static String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  /// Validate a backup payload before restoring it.
  static void validateBackup(Map<String, dynamic> payload) {
    if (payload['app'] != 'spendwiser') {
      throw const FormatException('Not a Spendwiser backup file');
    }
    if (payload['version'] != 1) {
      throw const FormatException('Unsupported backup version');
    }
    if (payload['finance'] is! Map && payload['finance'] != null) {
      throw const FormatException('Backup is missing finance data');
    }
  }

  /// Decode + validate a backup file's raw contents.
  static Map<String, dynamic> parseBackup(String contents) {
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup file is not valid JSON');
    }
    validateBackup(decoded);
    return decoded;
  }
}
