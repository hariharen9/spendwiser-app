import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/state/sms_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/category_aliases.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/sms/sms_inbox.dart';

Future<void> showSmsReviewSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _SmsReviewSheet());
}

class SmsReviewBanner extends ConsumerWidget {
  const SmsReviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(smsReviewProvider).length;
    if (count == 0) return const SizedBox.shrink();
    final c = context.spend;
    return AppCard(
      onTap: () => showSmsReviewSheet(context),
      child: Row(
        children: [
          IconTile(icon: 'ledger', color: c.ac, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank messages to review',
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                Text(
                  '$count waiting · stays on this device',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ],
            ),
          ),
          AppPill(label: '$count', active: true),
        ],
      ),
    );
  }
}

class _SmsReviewSheet extends ConsumerStatefulWidget {
  const _SmsReviewSheet();

  @override
  ConsumerState<_SmsReviewSheet> createState() => _SmsReviewSheetState();
}

class _SmsReviewSheetState extends ConsumerState<_SmsReviewSheet> {
  bool? _permission;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await SmsInbox.hasPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
  }

  Future<void> _enable() async {
    final granted = await SmsInbox.requestPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
    if (granted) {
      await ref.read(smsReviewProvider.notifier).refresh();
    } else {
      ref
          .read(toastProvider.notifier)
          .show('SMS access was not granted. Enable it in Android settings.');
    }
  }

  void _paste() {
    showAppSheet<void>(context, (_) => const _PasteSmsSheet());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final items = ref.watch(smsReviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Review bank SMS',
          subtitle: 'Nothing is uploaded until you tap Add transaction.',
        ),
        const SizedBox(height: 12),
        if (_permission == false) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMS access is off',
                  style: AppTypography.sans(
                    size: 15,
                    color: c.tx,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Spendwiser needs permission to read bank transaction SMS. '
                  'Messages are parsed on this phone and stored only in app-private storage.',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ],
            ),
          ),
          PrimaryButton(label: 'Enable SMS access', onTap: _enable),
        ],
        if (_permission == true && items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              title: 'Nothing to review',
              message: 'New bank transaction SMS will appear here.',
            ),
          ),
        if (items.isNotEmpty) ...[
          const SectionCaption('Waiting'),
          for (final item in items)
            AppCard(
              onTap: () =>
                  showAppSheet<void>(context, (_) => _SmsItemSheet(item: item)),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.c2,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: SpendIcon('ledger', size: 18, color: c.mu),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.parsed.merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.sans(size: 14, color: c.tx),
                        ),
                        Text(
                          '${item.message.sender} · ${shortDate(item.message.receivedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.sans(size: 11, color: c.mu),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.parsed.isIncome ? '+' : '−'}${rupee(item.parsed.amount)}',
                    style: AppTypography.sans(
                      size: 14,
                      color: item.parsed.isIncome ? c.ac : c.tx,
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 6),
        AppButton(label: 'Paste a test message', centered: true, onTap: _paste),
        if (_permission == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Checking SMS access…',
              textAlign: TextAlign.center,
              style: AppTypography.sans(size: 11, color: c.mu),
            ),
          ),
      ],
    );
  }
}

class _SmsItemSheet extends ConsumerStatefulWidget {
  const _SmsItemSheet({required this.item});

  final SmsReviewItem item;

  @override
  ConsumerState<_SmsItemSheet> createState() => _SmsItemSheetState();
}

class _SmsItemSheetState extends ConsumerState<_SmsItemSheet> {
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late bool _income;
  late DateTime _date;
  late String _category;
  late String _source;

  @override
  void initState() {
    super.initState();
    final parsed = widget.item.parsed;
    _merchant = TextEditingController(
      text: parsed.merchant == 'Bank transaction' ? '' : parsed.merchant,
    );
    _amount = TextEditingController(text: parsed.amount.round().toString());
    _income = parsed.isIncome;
    _date = parsed.date;

    final settings = ref.read(settingsProvider);
    _category = _income
        ? 'Income'
        : resolveCategoryName(parsed.category, settings.categories.keys);

    final snapshot = ref.read(financeSnapshotProvider);
    final last4 = parsed.last4;
    String? source;
    if (last4 != null && last4.isNotEmpty) {
      for (final card in snapshot.cards) {
        if (card.last4 == last4) {
          source = 'c:${card.id}';
          break;
        }
      }
      if (source == null) {
        for (final account in snapshot.accounts) {
          if (account.last4 == last4) {
            source = 'a:${account.id}';
            break;
          }
        }
      }
    }
    final defaultAccountId =
        ref.read(userProfileRepositoryProvider)?.defaultAccountId ??
        (snapshot.accounts.isNotEmpty ? snapshot.accounts.first.id : null);
    source ??= defaultAccountId == null ? '' : 'a:$defaultAccountId';
    _source = source;
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final value = double.tryParse(_amount.text) ?? 0;
    if (value <= 0) {
      ref.read(toastProvider.notifier).show('Enter an amount');
      return;
    }
    final isCard = _source.startsWith('c:');
    final sourceId = _source.length > 2 ? _source.substring(2) : null;
    final added = await ref
        .read(smsReviewProvider.notifier)
        .approve(
          item: widget.item,
          merchant: _merchant.text,
          amount: value,
          isIncome: _income,
          date: _date,
          category: _category,
          accountId: isCard ? null : sourceId,
          cardId: isCard ? sourceId : null,
        );
    if (!mounted) return;
    if (!added) {
      ref.read(toastProvider.notifier).show('Could not add the transaction');
      return;
    }
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Added ${rupee(value)}');
  }

  Future<void> _dismiss() async {
    await ref.read(smsReviewProvider.notifier).dismiss(widget.item.message.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Message dismissed');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final settings = ref.watch(settingsProvider);
    final categories = _income
        ? const ['Income']
        : <String>{
            ...settings.categories.keys,
            if (_category.isNotEmpty) _category,
          }.toList();
    final sourceOptions = <AppSelectOption<String>>[
      const AppSelectOption('', 'No account'),
      for (final account in snapshot.accounts)
        AppSelectOption('a:${account.id}', account.name),
      for (final card in snapshot.cards)
        AppSelectOption('c:${card.id}', 'Card · ${card.name}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Review message',
          subtitle: 'Edit anything that looks wrong, then add it.',
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.message.sender,
                      style: AppTypography.sans(
                        size: 13,
                        color: c.tx,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AppPill(
                    label:
                        '${(widget.item.parsed.confidence * 100).round()}% match',
                    active: widget.item.parsed.confidence >= 0.8,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.message.body,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        LabeledField(
          label: 'Merchant',
          child: _Field(controller: _merchant, hint: 'Merchant'),
        ),
        LabeledField(
          label: 'Amount',
          child: _Field(controller: _amount, hint: 'Amount', number: true),
        ),
        const SizedBox(height: 4),
        LabeledField(
          label: 'Type',
          child: SegmentedControl<bool>(
            margin: EdgeInsets.zero,
            options: const [
              SegmentedOption(false, 'Expense'),
              SegmentedOption(true, 'Income'),
            ],
            selected: _income,
            onChanged: (value) => setState(() {
              _income = value;
              if (value) {
                _category = 'Income';
              } else if (_category == 'Income') {
                final available = ref
                    .read(settingsProvider)
                    .categories
                    .keys
                    .toList();
                _category = available.isEmpty ? 'Other' : available.first;
              }
            }),
          ),
        ),
        const SizedBox(height: 10),
        LabeledField(
          label: 'Date',
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: c.ac,
                      surface: c.c1,
                      onSurface: c.tx,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: c.c2,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isoDate(_date),
                      style: AppTypography.sans(size: 13, color: c.tx),
                    ),
                  ),
                  SpendIcon('calendar', size: 16, color: c.mu),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LabeledField(
          label: 'Category',
          child: AppSelect<String>(
            value: _category,
            options: [
              for (final category in categories)
                AppSelectOption(category, category),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
        ),
        const SizedBox(height: 10),
        LabeledField(
          label: 'Account',
          child: AppSelect<String>(
            value: _source,
            hint: 'No account',
            options: sourceOptions,
            onChanged: (value) => setState(() => _source = value ?? ''),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Add transaction', onTap: _approve),
        AppButton(
          label: 'Dismiss message',
          centered: true,
          color: c.co,
          onTap: _dismiss,
        ),
      ],
    );
  }
}

class _PasteSmsSheet extends ConsumerStatefulWidget {
  const _PasteSmsSheet();

  @override
  ConsumerState<_PasteSmsSheet> createState() => _PasteSmsSheetState();
}

class _PasteSmsSheetState extends ConsumerState<_PasteSmsSheet> {
  final _sender = TextEditingController(text: 'AD-HDFCBK');
  final _body = TextEditingController(
    text: 'Rs.450.00 debited from a/c XX1234 on 10-11-26 to SWIGGY. Avl Bal: INR 12,340.00',
  );

  @override
  void dispose() {
    _sender.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _queue() async {
    final body = _body.text.trim();
    if (body.isEmpty) {
      ref.read(toastProvider.notifier).show('Paste a message first');
      return;
    }
    final added = await SmsInbox.addRaw(
      sender: _sender.text.trim().isEmpty ? 'AD-HDFCBK' : _sender.text.trim(),
      body: body,
    );
    await ref.read(smsReviewProvider.notifier).refresh();
    if (!mounted) return;
    Navigator.of(context).pop();
    ref
        .read(toastProvider.notifier)
        .show(
          added == null ? 'Message could not be queued' : 'Test message queued',
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Paste a test message',
          subtitle: 'For trying the parser without waiting for a real SMS.',
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Sender ID',
          child: _Field(controller: _sender, hint: 'Sender ID'),
        ),
        LabeledField(
          label: 'Message body',
          child: _Field(controller: _body, hint: 'Message body', lines: 4),
        ),
        const SizedBox(height: 8),
        Text(
          'Only bank senders and transaction-like messages are accepted.',
          style: AppTypography.sans(size: 11, color: c.mu),
        ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Queue for review', onTap: _queue),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.number = false,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        maxLines: lines,
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
