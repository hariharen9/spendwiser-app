import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/sms/sms_inbox.dart';
import '../home/services/capture_parser.dart';
import '../insights/services/ask_ai_client.dart';

Future<void> showSmsReviewSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    (_) => const _SmsReviewSheet(),
    scrollable: false,
  );
}

/// Floating home banner alerting the user to unreviewed bank SMS.
class SmsReviewBanner extends ConsumerWidget {
  const SmsReviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(smsReviewProvider).length;
    if (count == 0) return const SizedBox.shrink();
    final c = context.spend;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => showSmsReviewSheet(context),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.ac.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.ac.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: SpendIcon('receipt', size: 20, color: c.ac),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Bank messages to review',
                      style: AppTypography.sans(
                        size: 14,
                        color: c.tx,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.ac,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.ac.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  count == 1
                      ? '1 waiting · stays on this device'
                      : '$count waiting · stays on this device',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.ac.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.ac.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: AppTypography.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: c.ac,
                  ),
                ),
                const SizedBox(width: 4),
                SpendIcon('arrowRight', size: 10, color: c.ac),
              ],
            ),
          ),
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
      ref.read(toastProvider.notifier).show(
            'SMS access was not granted. Enable it in Android settings.',
          );
    }
  }

  void _paste() {
    showAppSheet<void>(
      context,
      (_) => const _PasteSmsSheet(),
      scrollable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final items = ref.watch(smsReviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: SheetTitle(
                'Review bank SMS',
                subtitle: 'Nothing is added to your ledger until you approve.',
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.c2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SpendIcon('closeSmall', size: 18, color: c.tx),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
                  'Spendwiser parses bank alerts locally on your device. '
                  'Messages never leave your phone and are stored only in app-private storage.',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ],
            ),
          ),
          PrimaryButton(label: 'Enable SMS access', onTap: _enable),
        ],
        if (_permission == true && items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: EmptyState(
              title: 'All caught up',
              message: 'New bank and UPI transaction SMS alerts will appear here.',
            ),
          ),
        if (items.isNotEmpty) ...[
          SectionCaption('Pending alerts (${items.length})'),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final isIncome = item.parsed.isIncome;
                return AppCard(
                  margin: EdgeInsets.zero,
                  onTap: () => showAppSheet<void>(
                    context,
                    (_) => _SmsItemSheet(item: item),
                    scrollable: false,
                  ),
                  child: Row(
                    children: [
                      MerchantAvatar(
                        merchant: item.parsed.merchant,
                        category: item.parsed.category,
                        size: 40,
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
                              style: AppTypography.sans(
                                size: 14,
                                color: c.tx,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isIncome ? '+' : '−'}${rupee(item.parsed.amount)}',
                            style: AppTypography.serif(
                              size: 16,
                              color: isIncome ? c.ac : c.tx,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AppPill(
                            label: '${(item.parsed.confidence * 100).round()}% match',
                            active: item.parsed.confidence >= 0.8,
                            fontSize: 10,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 10),
        AppButton(
          label: 'Paste a test message',
          centered: true,
          onTap: _paste,
        ),
      ],
    );
  }
}

/// Fully reactive, modern transaction review sheet matching AddTransactionSheet.
class _SmsItemSheet extends ConsumerStatefulWidget {
  const _SmsItemSheet({required this.item});

  final SmsReviewItem item;

  @override
  ConsumerState<_SmsItemSheet> createState() => _SmsItemSheetState();
}

class _SmsItemSheetState extends ConsumerState<_SmsItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late bool _income;
  late DateTime _date;
  late String _category;
  late String _source;
  late bool _categoryManuallySelected;
  bool _aiParsing = false;

  @override
  void initState() {
    super.initState();
    final parsed = widget.item.parsed;
    final initialMerchant =
        parsed.merchant == 'Bank transaction' ? '' : parsed.merchant;

    _name = TextEditingController(text: initialMerchant);
    _name.addListener(_onNameChanged);

    _amount = TextEditingController(
      text: parsed.amount == parsed.amount.roundToDouble()
          ? parsed.amount.round().toString()
          : parsed.amount.toStringAsFixed(2),
    );

    _income = parsed.isIncome;
    _date = parsed.date;
    _categoryManuallySelected = false;

    final categories = _expenseCategories();
    _category = _income
        ? 'Income'
        : resolveCategoryName(parsed.category, categories);

    _note = TextEditingController(text: 'SMS · ${widget.item.message.sender}');

    // Smart-match account or card via last4
    final snapshot = ref.read(financeSnapshotProvider);
    final last4 = parsed.last4;
    String? matchedSource;

    if (last4 != null && last4.isNotEmpty) {
      for (final card in snapshot.cards) {
        if (card.last4 == last4) {
          matchedSource = 'c:${card.id}';
          break;
        }
      }
      if (matchedSource == null) {
        for (final account in snapshot.accounts) {
          if (account.last4 == last4) {
            matchedSource = 'a:${account.id}';
            break;
          }
        }
      }
    }

    final defaultAccount =
        ref.read(userProfileRepositoryProvider)?.defaultAccountId ??
        (snapshot.accounts.isNotEmpty ? snapshot.accounts.first.id : null);

    _source = matchedSource ?? (defaultAccount != null ? 'a:$defaultAccount' : '');
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<String> _expenseCategories() => ref
      .read(settingsProvider)
      .categories
      .keys
      .where((cat) => cat != 'Transfer' && cat != 'Income')
      .toList();

  /// Reactive auto-categorization when the user changes or types the name.
  void _onNameChanged() {
    if (_income || _categoryManuallySelected) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final detected = CaptureParser.detectCategory(name, name.toLowerCase());
    if (detected == 'Other') return;
    final target = resolveCategoryName(detected, _expenseCategories());
    if (target != _category) {
      setState(() => _category = target);
    }
  }

  Future<void> _cleanUpWithAi() async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasAiKey || _aiParsing) return;

    final rawInput =
        '${widget.item.message.body} (Sender: ${widget.item.message.sender})';

    setState(() => _aiParsing = true);
    try {
      final categories = _expenseCategories();
      final parsed = await AskAiClient.parseTransactionWithAi(
        provider: settings.aiProvider,
        apiKey: settings.aiApiKey.trim(),
        model: settings.effectiveAiModel,
        rawInput: rawInput,
        categories: categories,
      );
      if (!mounted) return;
      setState(() {
        _name.text = parsed.merchant;
        if (parsed.amount > 0) {
          _amount.text = parsed.amount == parsed.amount.roundToDouble()
              ? parsed.amount.round().toString()
              : parsed.amount.toStringAsFixed(2);
        }
        _income = parsed.isIncome;
        _category = parsed.isIncome
            ? 'Income'
            : resolveCategoryName(parsed.category, categories);
        _categoryManuallySelected = true;
        if (parsed.note.isNotEmpty) {
          _note.text = parsed.note;
        }
        _aiParsing = false;
      });
      ref.read(toastProvider.notifier).show('Cleaned up with AI');
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiParsing = false);
      ref.read(toastProvider.notifier).show(
            e.toString().replaceFirst('Exception: ', ''),
          );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        final c = context.spend;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: c.ac,
                  surface: c.c1,
                  onSurface: c.tx,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _approve() async {
    final name = _name.text.trim();
    final value = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    if (name.isEmpty) {
      ref.read(toastProvider.notifier).show('Name the transaction');
      return;
    }
    if (value <= 0) {
      ref.read(toastProvider.notifier).show('Enter a valid amount');
      return;
    }

    final isCard = _source.startsWith('c:');
    final sourceId = _source.length > 2 ? _source.substring(2) : null;

    final added = await ref.read(smsReviewProvider.notifier).approve(
          item: widget.item,
          merchant: name,
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
    ref.read(toastProvider.notifier).show('Added ${rupee(value)} to ledger');
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
    final categories = _expenseCategories();
    final effectiveCategory = _income
        ? 'Income'
        : (categories.contains(_category)
            ? _category
            : (categories.isNotEmpty ? categories.first : 'Other'));

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final smsDate = widget.item.parsed.date;

    final sources = <AppSelectOption<String>>[
      for (final account in snapshot.accounts)
        AppSelectOption(
          'a:${account.id}',
          '${account.name} (${rupee(account.balance)})',
        ),
      for (final card in snapshot.cards)
        AppSelectOption(
          'c:${card.id}',
          '${card.name} (${rupee(card.outstanding)} due)',
        ),
      if (snapshot.accounts.isEmpty && snapshot.cards.isEmpty)
        const AppSelectOption('', 'No account'),
    ];

    final currentAmount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: SheetTitle(
                        'Review message',
                        subtitle: 'Edit details if needed, then add.',
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.c2,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: SpendIcon('closeSmall', size: 18, color: c.tx),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Original Bank SMS Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.c1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.ln),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.c2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SpendIcon('lock', size: 12, color: c.mu),
                                const SizedBox(width: 4),
                                Text(
                                  widget.item.message.sender,
                                  style: AppTypography.sans(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    color: c.tx,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          AppPill(
                            label:
                                '${(widget.item.parsed.confidence * 100).round()}% match',
                            active: widget.item.parsed.confidence >= 0.8,
                            fontSize: 11,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.message.body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sans(
                          size: 12,
                          color: c.mu,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                Row(
                  children: [
                    Expanded(child: _fieldLabel(context, 'Transaction name *')),
                    if (ref.watch(settingsProvider).hasAiKey)
                      GestureDetector(
                        onTap: _aiParsing ? null : _cleanUpWithAi,
                        child: Text(
                          _aiParsing ? 'Cleaning…' : 'Clean up with AI',
                          style: AppTypography.sans(
                            size: 12,
                            color: c.ac,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                _SmsInput(
                  controller: _name,
                  hint: 'e.g. Zomato, Swiggy, Uber',
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),

                // Amount field
                _fieldLabel(context, 'Amount *'),
                _SmsInput(
                  controller: _amount,
                  hint: '0.00',
                  number: true,
                  large: true,
                  prefix: '₹ ',
                ),
                const SizedBox(height: 12),

                // Type field
                _fieldLabel(context, 'Type *'),
                SegmentedControl<bool>(
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
                    } else {
                      _onNameChanged();
                    }
                  }),
                ),
                const SizedBox(height: 12),

                // Date field
                _fieldLabel(context, 'Date *'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPill(
                      label: 'SMS date (${shortDate(smsDate)})',
                      active: _sameDay(_date, smsDate),
                      onTap: () => setState(() => _date = smsDate),
                    ),
                    AppPill(
                      label: 'Today',
                      active: _sameDay(_date, today),
                      onTap: () => setState(() => _date = today),
                    ),
                    AppPill(
                      label: 'Yesterday',
                      active: _sameDay(_date, yesterday),
                      onTap: () => setState(() => _date = yesterday),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: c.c2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isoDate(_date),
                            style: AppTypography.sans(size: 14, color: c.tx),
                          ),
                        ),
                        SpendIcon('calendar', size: 16, color: c.mu),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _fieldLabel(context, 'Category *'),
                    if (!_income && !_categoryManuallySelected)
                      Text(
                        'Auto-detected from name',
                        style: AppTypography.sans(
                          size: 10,
                          color: c.ac,
                          weight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                if (_income)
                  const _SmsReadOnlyField(value: 'Income')
                else
                  AppSelect<String>(
                    value: effectiveCategory,
                    options: [
                      for (final category in categories)
                        AppSelectOption(category, category),
                    ],
                    onChanged: (value) => setState(() {
                      _categoryManuallySelected = true;
                      _category = value ?? _category;
                    }),
                  ),
                const SizedBox(height: 12),

                // Account field
                _fieldLabel(context, 'Account / Card *'),
                AppSelect<String>(
                  value: _source,
                  hint: 'Choose account or card',
                  options: sources,
                  onChanged: (value) => setState(() => _source = value ?? ''),
                ),
                const SizedBox(height: 12),

                // Note field
                _fieldLabel(context, 'Note (optional)'),
                _SmsInput(
                  controller: _note,
                  hint: 'Additional context…',
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),

        // Action area
        Container(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.ln)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                label: currentAmount > 0
                    ? 'Add transaction (${rupee(currentAmount)})'
                    : 'Add transaction',
                onTap: _approve,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: 6),
              AppButton(
                label: 'Dismiss message',
                color: c.co,
                centered: true,
                onTap: _dismiss,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.sans(size: 12, color: context.spend.mu),
      ),
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
    text:
        'Rs.450.00 debited from a/c XX1234 on 10-11-26 to SWIGGY. Avl Bal: INR 12,340.00',
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
    ref.read(toastProvider.notifier).show(
          added == null ? 'Message could not be queued' : 'Test message queued',
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: SheetTitle(
                'Paste a test message',
                subtitle: 'Test the parser without waiting for a real SMS.',
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.c2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SpendIcon('closeSmall', size: 18, color: c.tx),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Sender ID *',
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
        ),
        _SmsInput(controller: _sender, hint: 'e.g. AD-HDFCBK, VM-ICICI'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Message body *',
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
        ),
        _SmsInput(
          controller: _body,
          hint: 'Paste full SMS message here…',
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        Text(
          'Only recognized bank senders and debit/credit messages are accepted.',
          style: AppTypography.sans(size: 11, color: c.mu),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Queue for review', onTap: _queue),
      ],
    );
  }
}

class _SmsInput extends StatelessWidget {
  const _SmsInput({
    required this.controller,
    required this.hint,
    this.number = false,
    this.maxLines = 1,
    this.prefix,
    this.large = false,
    this.capitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final int maxLines;
  final String? prefix;
  final bool large;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: large ? 10 : 13),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: number
            ? [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(12),
              ]
            : null,
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : 1,
        textCapitalization: capitalization,
        style: large
            ? AppTypography.serif(
                size: 32,
                color: c.tx,
                letterSpacing: -0.8,
                height: 1.1,
              )
            : AppTypography.sans(size: 14, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.sans(size: 14, color: c.mu),
          prefixText: prefix,
          prefixStyle: AppTypography.serif(size: 26, color: c.mu),
        ),
      ),
    );
  }
}

class _SmsReadOnlyField extends StatelessWidget {
  const _SmsReadOnlyField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      child: Text(value, style: AppTypography.sans(size: 14, color: c.tx)),
    );
  }
}
