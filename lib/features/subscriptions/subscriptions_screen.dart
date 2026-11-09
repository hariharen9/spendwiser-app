import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/subscription.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  bool _recurring = false;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final active = snapshot.subscriptions.where((s) => s.active).toList();
    final monthly = active.fold<double>(0, (sum, s) => sum + s.price);
    final unused = active.where((s) => s.note != null).toList();
    final sorted = [...snapshot.subscriptions]
      ..sort((a, b) => a.renewsInDays.compareTo(b.renewsInDays));
    final recurring = snapshot.recurring;
    final monthlyIn = recurring
        .where((r) => r.active && r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.monthlyAmount);
    final monthlyOut = recurring
        .where((r) => r.active && !r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.monthlyAmount);

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Subscriptions',
          subtitle: _recurring
              ? 'Logged automatically on schedule'
              : '${rupee(monthly)} / month',
        ),
        SegmentedControl<bool>(
          options: const [
            SegmentedOption(false, 'Subscriptions'),
            SegmentedOption(true, 'Recurring'),
          ],
          selected: _recurring,
          onChanged: (value) => setState(() => _recurring = value),
        ),
        if (!_recurring) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.ac, Color.lerp(c.ac, Colors.black, 0.55)!],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yearly cost',
                  style: AppTypography.sans(size: 12, color: c.aci),
                ),
                Text(
                  rupee(monthly * 12),
                  style: AppTypography.serif(
                    size: 46,
                    color: c.aci,
                    height: 1.1,
                  ),
                ),
                Text(
                  unused.isEmpty
                      ? 'Everything active is in use'
                      : unused
                            .map(
                              (s) =>
                                  '${s.name} looks unused — pausing saves ${rupee(s.price * 12)}/yr',
                            )
                            .join('. '),
                  style: AppTypography.sans(size: 12, color: c.aci),
                ),
              ],
            ),
          ),
          const SectionCaption('Renewals'),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < sorted.length; i++)
                  _SubscriptionRow(
                    subscription: sorted[i],
                    showDivider: i < sorted.length - 1,
                    onTap: () => _editSubscription(context, sorted[i]),
                    onToggle: () => ref
                        .read(subscriptionRepositoryProvider)
                        .toggleSubscription(sorted[i].id),
                  ),
              ],
            ),
          ),
          AppButton(
            label: '+ Add subscription',
            onTap: () => _addSubscription(context),
            margin: const EdgeInsets.only(top: 8),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'In / month',
                  value: compactINR(monthlyIn),
                  valueColor: c.ac,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Out / month',
                  value: compactINR(monthlyOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < recurring.length; i++)
                  _RecurringRow(
                    recurring: recurring[i],
                    showDivider: i < recurring.length - 1,
                    onTap: () => _editRecurring(context, recurring[i]),
                    onToggle: () {
                      ref
                          .read(subscriptionRepositoryProvider)
                          .updateRecurring(
                            recurring[i].copyWith(active: !recurring[i].active),
                          );
                    },
                  ),
              ],
            ),
          ),
          AppButton(
            label: '+ Add recurring',
            onTap: () => _addRecurring(context),
            margin: const EdgeInsets.only(top: 8),
          ),
        ],
      ],
    );
  }

  void _addSubscription(BuildContext context) {
    final name = TextEditingController();
    final price = TextEditingController();
    final days = TextEditingController(text: '30');
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Add subscription',
            subtitle: 'Netflix, Spotify, iCloud and more.',
          ),
          const SizedBox(height: 12),
          _Field(controller: name, hint: 'Name'),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: price,
                  hint: 'Monthly price',
                  number: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: days,
                  hint: 'Renews in (days)',
                  number: true,
                ),
              ),
            ],
          ),
          PrimaryButton(
            label: 'Add subscription',
            onTap: () async {
              if (name.text.trim().isEmpty) {
                ref.read(toastProvider.notifier).show('Name the subscription');
                return;
              }
              await ref
                  .read(subscriptionRepositoryProvider)
                  .addSubscription(
                    name: name.text.trim(),
                    price: double.tryParse(price.text) ?? 0,
                    renewsInDays: int.tryParse(days.text) ?? 30,
                  );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Subscription added');
            },
          ),
        ],
      ),
    );
  }

  void _editSubscription(BuildContext context, Subscription subscription) {
    final name = TextEditingController(text: subscription.name);
    final price = TextEditingController(
      text: subscription.price.round().toString(),
    );
    final days = TextEditingController(
      text: subscription.renewsInDays.toString(),
    );
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle('Edit ${subscription.name}'),
          const SizedBox(height: 12),
          _Field(controller: name, hint: 'Name'),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: price,
                  hint: 'Monthly price',
                  number: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: days,
                  hint: 'Renews in (days)',
                  number: true,
                ),
              ),
            ],
          ),
          PrimaryButton(
            label: 'Save',
            onTap: () async {
              await ref
                  .read(subscriptionRepositoryProvider)
                  .updateSubscription(
                    subscription.copyWith(
                      name: name.text.trim().isEmpty
                          ? subscription.name
                          : name.text.trim(),
                      price: double.tryParse(price.text) ?? subscription.price,
                      renewsInDays:
                          int.tryParse(days.text) ?? subscription.renewsInDays,
                    ),
                  );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Subscription updated');
            },
          ),
          AppButton(
            label: subscription.active ? 'Pause' : 'Resume',
            centered: true,
            onTap: () async {
              await ref
                  .read(subscriptionRepositoryProvider)
                  .toggleSubscription(subscription.id);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
            },
          ),
          AppButton(
            label: 'Cancel subscription',
            color: sheetContext.spend.co,
            centered: true,
            onTap: () async {
              await ref
                  .read(subscriptionRepositoryProvider)
                  .removeSubscription(subscription.id);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Subscription cancelled');
            },
          ),
        ],
      ),
    );
  }

  void _addRecurring(BuildContext context) {
    final name = TextEditingController();
    final amount = TextEditingController();
    var frequency = RecurringFrequency.monthly;
    var income = false;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('New recurring'),
              const SizedBox(height: 12),
              _Field(controller: name, hint: 'Name'),
              _Field(controller: amount, hint: 'Amount', number: true),
              Row(
                children: [
                  Expanded(
                    child: AppSelect<RecurringFrequency>(
                      value: frequency,
                      options: [
                        for (final f in RecurringFrequency.values)
                          AppSelectOption(f, f.label),
                      ],
                      onChanged: (value) => setSheetState(
                        () => frequency = value ?? RecurringFrequency.monthly,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppSelect<bool>(
                      value: income,
                      options: const [
                        AppSelectOption(false, 'Expense'),
                        AppSelectOption(true, 'Income'),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => income = value ?? false),
                    ),
                  ),
                ],
              ),
              PrimaryButton(
                label: 'Add',
                onTap: () async {
                  await ref
                      .read(subscriptionRepositoryProvider)
                      .addRecurring(
                        name: name.text.trim().isEmpty
                            ? 'Recurring'
                            : name.text.trim(),
                        amount: double.tryParse(amount.text) ?? 0,
                        frequency: frequency,
                        isIncome: income,
                      );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref.read(toastProvider.notifier).show('Recurring added');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _editRecurring(BuildContext context, RecurringTransaction recurring) {
    final name = TextEditingController(text: recurring.name);
    final amount = TextEditingController(
      text: recurring.amount.round().toString(),
    );
    var frequency = recurring.frequency;
    var income = recurring.isIncome;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle('Edit ${recurring.name}'),
              const SizedBox(height: 12),
              _Field(controller: name, hint: 'Name'),
              _Field(controller: amount, hint: 'Amount', number: true),
              Row(
                children: [
                  Expanded(
                    child: AppSelect<RecurringFrequency>(
                      value: frequency,
                      options: [
                        for (final f in RecurringFrequency.values)
                          AppSelectOption(f, f.label),
                      ],
                      onChanged: (value) => setSheetState(
                        () => frequency = value ?? recurring.frequency,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppSelect<bool>(
                      value: income,
                      options: const [
                        AppSelectOption(false, 'Expense'),
                        AppSelectOption(true, 'Income'),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => income = value ?? false),
                    ),
                  ),
                ],
              ),
              PrimaryButton(
                label: 'Save',
                onTap: () async {
                  await ref
                      .read(subscriptionRepositoryProvider)
                      .updateRecurring(
                        recurring.copyWith(
                          name: name.text.trim().isEmpty
                              ? recurring.name
                              : name.text.trim(),
                          amount:
                              double.tryParse(amount.text) ?? recurring.amount,
                          frequency: frequency,
                          isIncome: income,
                        ),
                      );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref.read(toastProvider.notifier).show('Recurring updated');
                },
              ),
              AppButton(
                label: 'Delete',
                color: sheetContext.spend.co,
                centered: true,
                onTap: () async {
                  await ref
                      .read(subscriptionRepositoryProvider)
                      .removeRecurring(recurring.id);
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref.read(toastProvider.notifier).show('Recurring removed');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.subscription,
    required this.showDivider,
    required this.onTap,
    required this.onToggle,
  });

  final Subscription subscription;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: subscription.active ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: c.ln))
                : null,
          ),
          child: Row(
            children: [
              MerchantAvatar(merchant: subscription.name, category: 'Fun'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      style: AppTypography.sans(size: 14, color: c.tx),
                    ),
                    Text(
                      subscription.active
                          ? 'renews in ${subscription.renewsInDays} days${subscription.note != null ? ' · ${subscription.note}' : ''}'
                          : 'paused',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
              MoneyText(
                rupee(subscription.price),
                style: AppTypography.sans(size: 14, color: c.tx),
              ),
              const SizedBox(width: 10),
              AppToggle(
                value: subscription.active,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({
    required this.recurring,
    required this.showDivider,
    required this.onTap,
    required this.onToggle,
  });

  final RecurringTransaction recurring;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: recurring.active ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: c.ln))
                : null,
          ),
          child: Row(
            children: [
              MerchantAvatar(
                merchant: recurring.name,
                category: recurring.isIncome ? 'Income' : 'Bills',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recurring.name,
                      style: AppTypography.sans(size: 14, color: c.tx),
                    ),
                    Text(
                      '${recurring.frequency.label} · ${recurring.active ? 'active' : 'paused'}',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
              MoneyText(
                rupee(recurring.amount),
                style: AppTypography.sans(
                  size: 14,
                  color: recurring.isIncome ? c.ac : c.tx,
                ),
              ),
              const SizedBox(width: 10),
              AppToggle(value: recurring.active, onChanged: (_) => onToggle()),
            ],
          ),
        ),
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
