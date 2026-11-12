import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../data/models/transaction.dart';
import '../services/ask_ai_client.dart';

/// 1-tap confirmation card rendered when SpendWiser AI proposes logging a
/// transaction, creating a budget, or creating a savings goal.
class AiActionCard extends ConsumerStatefulWidget {
  const AiActionCard({super.key, required this.proposal});

  final AiActionProposal proposal;

  @override
  ConsumerState<AiActionCard> createState() => _AiActionCardState();
}

class _AiActionCardState extends ConsumerState<AiActionCard> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _confirm() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    final p = widget.proposal;
    try {
      switch (p.type) {
        case AiActionType.logTx:
          final snapshot = ref.read(financeSnapshotProvider);
          final accountId = snapshot.accounts.isNotEmpty
              ? snapshot.accounts.first.id
              : null;
          await ref.read(transactionRepositoryProvider).addTransaction(
            TransactionDraft(
              merchant: p.title,
              category: p.category,
              amount: p.isIncome ? p.amount : -p.amount,
              date: DateTime.now(),
              addedAt: DateTime.now(),
              accountId: accountId,
              note: p.note,
            ),
          );
        case AiActionType.addBudget:
          await ref.read(budgetRepositoryProvider).addBudget(
            category: p.category,
            limit: p.amount,
          );
        case AiActionType.addGoal:
          await ref.read(goalRepositoryProvider).addGoal(
            name: p.title,
            target: p.amount,
            monthlyContribution: (p.amount / 12).roundToDouble(),
            color: AppColors.ac,
          );
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      ref.read(toastProvider.notifier).show('Saved: ${p.title}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ref.read(toastProvider.notifier).show('Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final p = widget.proposal;
    final kindLabel = switch (p.type) {
      AiActionType.logTx => p.isIncome ? 'Log income' : 'Log expense',
      AiActionType.addBudget => 'Create budget',
      AiActionType.addGoal => 'Create goal',
    };
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.c1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _saved ? c.ac : c.ac.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SpendIcon('sparkle', size: 14, color: c.ac),
              const SizedBox(width: 6),
              Text(
                kindLabel,
                style: AppTypography.sans(
                  size: 11,
                  color: c.ac,
                  weight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                rupee(p.amount),
                style: AppTypography.sans(
                  size: 14,
                  color: c.tx,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            p.type == AiActionType.logTx
                ? '${p.title} · ${p.category}'
                : p.title,
            style: AppTypography.sans(
              size: 13,
              color: c.tx,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: _saved
                ? 'Saved ✓'
                : (_saving ? 'Saving…' : 'Confirm & Save'),
            onTap: (_saving || _saved) ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

