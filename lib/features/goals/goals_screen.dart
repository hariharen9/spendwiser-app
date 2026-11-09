import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/custom_painters/health_score_gauge.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/models/goal.dart';
import '../../data/services/finance_calculator.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  List<bool>? _challenge;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final settings = ref.watch(settingsProvider);
    final saved = snapshot.goals.fold<double>(0, (sum, g) => sum + g.saved);
    final target = snapshot.goals.fold<double>(0, (sum, g) => sum + g.target);
    final challengeAmount = _challenge == null
        ? 0.0
        : List.generate(52, (i) => i)
              .where((i) => _challenge![i])
              .fold<double>(0, (sum, i) => sum + (i + 1) * 50);

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Goals',
          subtitle: '${rupee(saved)} saved of ${rupee(target)}',
        ),
        if (snapshot.goals.isEmpty)
          EmptyState(
            title: 'No goals yet',
            message: 'Save with intent.',
            actionLabel: 'Create a goal',
            onAction: () => _addGoal(context),
          )
        else
          for (final goal in snapshot.goals)
            _GoalCard(goal: goal, onTap: () => _showGoal(context, goal)),
        AppButton(
          label: '+ New goal',
          onTap: () => _addGoal(context),
          margin: const EdgeInsets.only(top: 8),
        ),
        const SectionCaption('52-week challenge'),
        if (_challenge == null)
          AppButton(
            label: 'Start the 52-week challenge',
            centered: true,
            onTap: () => setState(() => _challenge = List.filled(52, false)),
          )
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Save ₹50 more each week',
                        style: AppTypography.sans(
                          size: 14,
                          color: c.tx,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${rupee(challengeAmount)} / ₹68,900',
                      style: AppTypography.sans(size: 12, color: c.ac),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 13,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (var i = 0; i < 52; i++)
                      GestureDetector(
                        onTap: () => setState(() {
                          _challenge![i] = !_challenge![i];
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _challenge![i] ? c.ac : c.c2,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: AppTypography.sans(
                              size: 8,
                              color: _challenge![i] ? c.aci : c.mu,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SectionCaption('Round-ups'),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Round spends up to the next ₹10',
                      style: AppTypography.sans(size: 14, color: c.tx),
                    ),
                    Text(
                      'The change goes into a “Round-ups” goal',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
              AppToggle(
                value: settings.roundUps,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).patch(roundUps: value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showGoal(BuildContext context, Goal goal) {
    final name = TextEditingController(text: goal.name);
    final target = TextEditingController(text: goal.target.round().toString());
    final monthly = TextEditingController(
      text: goal.monthlyContribution.round().toString(),
    );
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(goal.name),
          Text(
            '${rupee(goal.saved)} saved · ${rupee(goal.remaining)} to go',
            style: AppTypography.sans(size: 12, color: sheetContext.spend.mu),
          ),
          const SectionCaption('Add money from HDFC Savings'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in const [1000, 5000, 10000, 25000])
                AppPill(
                  label: '+${rupee(amount)}',
                  onTap: () async {
                    await ref
                        .read(goalRepositoryProvider)
                        .addGoalMoney(goal.id, amount.toDouble());
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ref
                        .read(toastProvider.notifier)
                        .show('Added ${rupee(amount)}');
                  },
                ),
            ],
          ),
          const SectionCaption('Edit goal'),
          _Field(controller: name, hint: 'Name'),
          Row(
            children: [
              Expanded(
                child: _Field(controller: target, hint: 'Target', number: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: monthly,
                  hint: 'Monthly',
                  number: true,
                ),
              ),
            ],
          ),
          PrimaryButton(
            label: 'Save goal',
            onTap: () async {
              await ref
                  .read(goalRepositoryProvider)
                  .updateGoal(
                    goalId: goal.id,
                    name: name.text.trim().isEmpty
                        ? goal.name
                        : name.text.trim(),
                    target: double.tryParse(target.text) ?? goal.target,
                    monthlyContribution:
                        double.tryParse(monthly.text) ??
                        goal.monthlyContribution,
                  );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Goal updated');
            },
          ),
          AppButton(
            label: 'Delete goal',
            color: sheetContext.spend.co,
            centered: true,
            onTap: () async {
              await ref.read(goalRepositoryProvider).removeGoal(goal.id);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Goal removed');
            },
          ),
        ],
      ),
    );
  }

  void _addGoal(BuildContext context) {
    final name = TextEditingController();
    final target = TextEditingController();
    final monthly = TextEditingController();
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('New goal'),
          const SizedBox(height: 12),
          _Field(controller: name, hint: 'What are you saving for?'),
          _Field(controller: target, hint: 'Target amount', number: true),
          _Field(
            controller: monthly,
            hint: 'Monthly contribution',
            number: true,
          ),
          PrimaryButton(
            label: 'Create goal',
            onTap: () async {
              if (name.text.trim().isEmpty) {
                ref.read(toastProvider.notifier).show('Name the goal');
                return;
              }
              await ref
                  .read(goalRepositoryProvider)
                  .addGoal(
                    name: name.text.trim(),
                    target: double.tryParse(target.text) ?? 50000,
                    monthlyContribution: double.tryParse(monthly.text) ?? 5000,
                    color:
                        AppColors.accents[DateTime.now().microsecond %
                            AppColors.accents.length],
                  );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Goal created');
            },
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final months = goal.monthlyContribution <= 0
        ? 0
        : (goal.remaining / goal.monthlyContribution).ceil();
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          HealthScoreGauge(
            score: (goal.progress * 100).round(),
            size: 58,
            strokeWidth: 6,
            color: goal.color,
            showScore: false,
            child: Text(
              '${(goal.progress * 100).round()}%',
              style: AppTypography.sans(size: 12, color: c.tx),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: AppTypography.sans(
                    size: 14,
                    color: c.tx,
                    weight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${rupee(goal.saved)} of ${rupee(goal.target)}',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
                Text(
                  goal.isReached
                      ? 'Goal reached'
                      : 'ready by ${FinanceCalculator.resultLabel(months)} at ${rupee(goal.monthlyContribution)}/mo',
                  style: AppTypography.sans(size: 12, color: goal.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.number = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: AppTypography.sans(size: 13, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.sans(size: 13, color: c.mu),
        ),
      ),
    );
  }
}
