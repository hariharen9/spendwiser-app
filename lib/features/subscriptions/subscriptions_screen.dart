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
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/premium_sheet.dart';
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
                AnimatedAmount(
                  value: monthly * 12,
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
          if (sorted.isEmpty)
            EmptyState(
              title: 'No subscriptions tracked',
              message: 'Log recurring charges so nothing slips by.',
              actionLabel: 'Add subscription',
              onAction: () => _addSubscription(context),
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
                  amount: monthlyIn,
                  formatter: compactINR,
                  valueColor: c.ac,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Out / month',
                  amount: monthlyOut,
                  formatter: compactINR,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recurring.isEmpty)
            EmptyState(
              title: 'No recurring items',
              message: 'Add salary, rent or SIPs to forecast cash flow.',
              actionLabel: 'Add recurring',
              onAction: () => _addRecurring(context),
            ),
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
    showAppSheet<void>(context, (_) => const _AddSubscriptionSheet());
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
    showAppSheet<void>(context, (_) => const _AddRecurringSheet());
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

class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet();

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _days = TextEditingController(text: '30');

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _days.dispose();
    super.dispose();
  }

  double get _priceValue => double.tryParse(_price.text) ?? 0;
  int get _daysValue => int.tryParse(_days.text) ?? 0;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ref.read(toastProvider.notifier).show('Name the subscription');
      return;
    }
    if (_priceValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter the monthly price');
      return;
    }
    if (_daysValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter renewal days');
      return;
    }
    await ref
        .read(subscriptionRepositoryProvider)
        .addSubscription(
          name: _name.text.trim(),
          price: _priceValue,
          renewsInDays: _daysValue,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Subscription added');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final name = _name.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'subscriptions',
          title: 'Add subscription',
          subtitle: 'Keep recurring charges visible before they renew.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final brand in const [
              'Netflix',
              'Spotify',
              'YouTube Premium',
              'iCloud',
              'Notion',
              'Amazon Prime',
            ])
              AppPill(
                label: brand,
                active: name == brand,
                onTap: () => setState(() {
                  _name.text = brand;
                  _name.selection = TextSelection.collapsed(
                    offset: brand.length,
                  );
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Subscription name', requiredField: true),
        PremiumField(
          controller: _name,
          hint: 'e.g. Netflix',
          icon: 'subscriptions',
          capitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Monthly price', requiredField: true),
        PremiumField(
          controller: _price,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Renews in'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in const [7, 15, 30, 365])
              AppPill(
                label: days == 365 ? '1 year' : '$days days',
                active: _daysValue == days,
                onTap: () => setState(() => _days.text = '$days'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        PremiumField(
          controller: _days,
          hint: '30',
          number: true,
          icon: 'calendar',
          suffix: 'days',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        PremiumSummaryCard(
          icon: 'subscriptions',
          eyebrow: 'Recurring charge',
          value: '${rupee(_priceValue)} /mo',
          caption: name.isEmpty
              ? 'Name this subscription'
              : '$name · renews in $_daysValue days',
          accent: c.ac,
        ),
        const SizedBox(height: 12),
        const PremiumNotice(
          icon: 'insights',
          text: 'Subscriptions are forecasts only until you mark a payment. You can pause or cancel any time.',
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Add subscription', onTap: _save),
      ],
    );
  }
}

class _AddRecurringSheet extends ConsumerStatefulWidget {
  const _AddRecurringSheet();

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  bool _income = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amount.text) ?? 0;
  double get _monthly => _amountValue * _frequency.monthlyFactor;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ref.read(toastProvider.notifier).show('Name the recurring item');
      return;
    }
    if (_amountValue <= 0) {
      ref.read(toastProvider.notifier).show('Enter an amount');
      return;
    }
    await ref
        .read(subscriptionRepositoryProvider)
        .addRecurring(
          name: _name.text.trim(),
          amount: _amountValue,
          frequency: _frequency,
          isIncome: _income,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Recurring item added');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSheetHeader(
          icon: 'refresh',
          title: 'New recurring',
          subtitle: 'Track predictable money in or out.',
        ),
        const SizedBox(height: 20),
        const PremiumLabel('Name', requiredField: true),
        PremiumField(
          controller: _name,
          hint: 'e.g. Rent, Salary',
          icon: 'refresh',
          capitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Amount', requiredField: true),
        PremiumField(
          controller: _amount,
          hint: '0',
          number: true,
          large: true,
          prefix: '₹ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Type'),
        SegmentedControl<bool>(
          margin: EdgeInsets.zero,
          options: const [
            SegmentedOption(false, 'Expense'),
            SegmentedOption(true, 'Income'),
          ],
          selected: _income,
          onChanged: (value) => setState(() => _income = value),
        ),
        const SizedBox(height: 16),
        const PremiumLabel('Frequency'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final frequency in RecurringFrequency.values)
              AppPill(
                label: frequency.label,
                active: _frequency == frequency,
                onTap: () => setState(() => _frequency = frequency),
              ),
          ],
        ),
        const SizedBox(height: 14),
        PremiumSummaryCard(
          icon: 'refresh',
          eyebrow: _income ? 'Monthly income' : 'Monthly cost',
          value: rupee(_monthly),
          caption:
              '${_frequency.label} · ${rupee(_amountValue)} per occurrence',
          accent: c.ac,
        ),
        const SizedBox(height: 12),
        const PremiumNotice(
          icon: 'calendar',
          text: 'Recurring items appear on the calendar and are used in cash-flow forecasts.',
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Add recurring', onTap: _save),
      ],
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
