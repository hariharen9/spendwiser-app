import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/transaction.dart';
import '../../data/sms/bank_sms_parser.dart';
import '../../data/sms/sms_inbox.dart';
import 'providers.dart';

@immutable
class SmsReviewItem {
  const SmsReviewItem({required this.message, required this.parsed});

  final SmsMessage message;
  final ParsedBankSms parsed;
}

class SmsReviewNotifier extends Notifier<List<SmsReviewItem>> {
  StreamSubscription<SmsMessage>? _subscription;
  var _refreshing = false;
  var _refreshAgain = false;
  var _disposed = false;

  @override
  List<SmsReviewItem> build() {
    _subscription = SmsInbox.watch().listen((_) => refresh());
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });
    Future<void>.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      final messages = await SmsInbox.pending();
      final items = <SmsReviewItem>[];
      final seen = <String>{};
      for (final message in messages) {
        if (!seen.add(message.id)) continue;
        final parsed = BankSmsParser.parse(message);
        if (parsed == null) {
          await SmsInbox.remove(message.id);
          continue;
        }
        items.add(SmsReviewItem(message: message, parsed: parsed));
      }
      items.sort(
        (a, b) => b.message.receivedAt.compareTo(a.message.receivedAt),
      );
      if (!_disposed) state = items;
    } finally {
      _refreshing = false;
      if (_refreshAgain) {
        _refreshAgain = false;
        await refresh();
      }
    }
  }

  Future<void> dismiss(String id) async {
    await SmsInbox.remove(id);
    await refresh();
  }

  Future<bool> approve({
    required SmsReviewItem item,
    required String merchant,
    required double amount,
    required bool isIncome,
    required DateTime date,
    required String category,
    String? accountId,
    String? cardId,
  }) async {
    if (amount <= 0) return false;
    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransaction(
            TransactionDraft(
              merchant: merchant.trim().isEmpty
                  ? item.parsed.merchant
                  : merchant.trim(),
              category: category,
              amount: isIncome ? amount.abs() : -amount.abs(),
              date: date,
              addedAt: DateTime.now(),
              accountId: accountId,
              cardId: cardId,
              note: 'SMS · ${item.message.sender}',
            ),
          );
      await SmsInbox.remove(item.message.id);
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final smsReviewProvider =
    NotifierProvider<SmsReviewNotifier, List<SmsReviewItem>>(
      SmsReviewNotifier.new,
    );
