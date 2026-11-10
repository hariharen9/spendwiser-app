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
import '../../core/widgets/money_text.dart';
import '../../core/widgets/premium_sheet.dart';
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
    showAppSheet<void>(context, (_) => const _AddGoalSheet());
  }
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _monthly = TextEditingController();
  Color _color = AppColors.accents.first;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _monthly.dispose();
    super.dispose();
  }

  double get _targetValue => double.tryParse(_target.text) ?? 0;
  double get _monthlyValue => double.tryParse(_monthly.text) ?? 0;
  int get _months =>
      _monthlyValue <= 0 ? 0 : (_targetValue / _monthlyValue).ceil();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ref.read(toastProvider.notifier).show('Name the goal');
      return;
    }
    if (_targetValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter a target amount');
      return;
    }
    await ref
        .read(goalRepositoryProvider)
        .addGoal(
          name: _name.text.trim(),
          target: _targetValue,
          monthlyContribution: _monthlyValue,
          color: _color,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Goal created');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'goals',
          title: 'New goal',
          subtitle: 'Turn a target into a monthly plan.',
        ),
        const SizedBox(height: 20),
        const PremiumLabel('What are you saving for?', requiredField: true),
        PremiumField(
          controller: _name,
          hint: 'e.g. Japan trip',
          icon: 'goals',
          capitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Target amount', requiredField: true),
        PremiumField(
          controller: _target,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        const PremiumLabel('Monthly contribution'),
        PremiumField(
          controller: _monthly,
          hint: '0',
          number: true,
          prefix: '₹ ',
          suffix: '/mo',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Goal colour'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in AppColors.accents)
              GestureDetector(
                onTap: () => setState(() => _color = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == color ? c.tx : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: _color == color
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: _color == color
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.black87,
                        )
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        PremiumSummaryCard(
          icon: 'goals',
          eyebrow: 'Savings plan',
          value: rupee(_targetValue),
          caption: _monthlyValue <= 0
              ? 'Add a monthly contribution to see the timeline'
              : '${rupee(_monthlyValue)}/mo · reached in $_months months',
          accent: _color,
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Create goal', onTap: _save),
      ],
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
                AnimatedAmount(
                  value: goal.saved,
                  style: AppTypography.sans(size: 12, color: c.mu),
                  suffix: Text(
                    ' of ${rupee(goal.target)}',
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
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
