import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/state/providers.dart';
import '../../data/models/finance_snapshot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';

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

  static Future<Uint8List> buildAnnualSummaryPdf(FinanceSnapshot snapshot) async {
    final pdf = pw.Document(title: 'Spendwiser annual summary');
    final now = DateTime.now();
    final fyStart = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
    final tx = snapshot.transactions.where((t) => !t.date.isBefore(fyStart)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final income = tx.where((t) => t.amount > 0).fold(0.0, (s, t) => s + t.amount);
    final expense = tx.where((t) => t.amount < 0).fold(0.0, (s, t) => -t.amount);
    final byCategory = <String, double>{};
    for (final t in tx) {
      if (t.amount < 0) byCategory[t.category] = (byCategory[t.category] ?? 0) - t.amount;
    }
    final top = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Spendwiser - Annual summary'),
            pw.SizedBox(height: 6),
            pw.Text('Generated ${now.toIso8601String().substring(0, 10)}'),
            pw.SizedBox(height: 16),
            pw.Text('Income: Rs.${income.toStringAsFixed(0)}'),
            pw.Text('Expense: Rs.${expense.toStringAsFixed(0)}'),
            pw.Text('Net: Rs.${(income - expense).toStringAsFixed(0)}'),
            pw.Text('Transactions: ${tx.length}'),
            pw.SizedBox(height: 12),
            pw.Text('Top categories'),
            for (final e in top.take(10))
              pw.Row(children: [pw.Expanded(child: pw.Text(e.key)), pw.Text('Rs.${e.value.toStringAsFixed(0)}')]),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static Future<void> exportAnnualSummaryPdf(FinanceSnapshot snapshot) async {
    final bytes = await buildAnnualSummaryPdf(snapshot);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/spendwiser-annual-${_timestamp()}.pdf');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Spendwiser annual summary'),
    );
  }

  static List<int> buildStatementsXlsx(FinanceSnapshot snapshot, String range) {
    final excel = Excel.createExcel();
    final sheet = excel['Statements'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Merchant'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Account'),
      TextCellValue('Card'),
      TextCellValue('Note'),
      TextCellValue('Tags'),
    ]);
    DateTime? start;
    final now = DateTime.now();
    if (range == 'm') start = DateTime(now.year, now.month, 1);
    if (range == 'f') start = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
    final rows = snapshot.transactions.where((t) => start == null || !t.date.isBefore(start)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final t in rows) {
      sheet.appendRow([
        TextCellValue(t.date.toIso8601String().substring(0, 10)),
        TextCellValue(t.merchant),
        TextCellValue(t.category),
        DoubleCellValue(t.amount),
        TextCellValue(t.accountId ?? ''),
        TextCellValue(t.cardId ?? ''),
        TextCellValue(t.note),
        TextCellValue(t.tags.join(' ')),
      ]);
    }
    final summary = excel['Summary'];
    summary.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    summary.appendRow([TextCellValue('Transactions'), IntCellValue(rows.length)]);
    summary.appendRow([TextCellValue('Net worth'), DoubleCellValue(snapshot.netWorth)]);
    summary.appendRow([TextCellValue('Accounts total'), DoubleCellValue(snapshot.accountsTotal)]);
    summary.appendRow([TextCellValue('Card dues'), DoubleCellValue(snapshot.cardDues)]);
    final bytes = excel.save();
    return bytes ?? <int>[];
  }

  static Future<void> exportStatementsXlsx(FinanceSnapshot snapshot, String range) async {
    final bytes = buildStatementsXlsx(snapshot, range);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/spendwiser-statements-$range-${_timestamp()}.xlsx');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Spendwiser statements'),
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
