import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/transaction.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';
import 'app_icons.dart';
import 'money_text.dart';
import 'pressable.dart';

class TransactionRow extends ConsumerWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDate = true,
    this.showDivider = true,
    this.trailing,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final bool showDate;
  final bool showDivider;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final card = transaction.cardId == null
        ? null
        : snapshot.cardById(transaction.cardId!);
    final parts = <String>[transaction.category];
    if (showDate) parts.add(transaction.dateLabel);
    parts.addAll(transaction.tags.map((tag) => '#$tag'));
    if (transaction.hasReceipt) parts.add('receipt');
    if (card != null) parts.add('${card.firstName} card');

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: c.ln, width: 1))
              : null,
        ),
        child: Row(
          children: [
            MerchantAvatar(
              merchant: transaction.merchant,
              category: transaction.category,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(size: 14, color: c.tx),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ?trailing,
            MoneyText(
              transaction.isIncome
                  ? '+${rupee(transaction.amount)}'
                  : '−${rupee(transaction.amount)}',
              style: AppTypography.sans(
                size: 14,
                color: transaction.isIncome ? c.ac : c.tx,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
