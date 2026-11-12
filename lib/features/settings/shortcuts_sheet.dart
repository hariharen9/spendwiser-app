import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/shortcut.dart';

Future<void> showShortcutsSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _ShortcutsSheet());
}

class _ShortcutsSheet extends ConsumerWidget {
  const _ShortcutsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final shortcuts = ref.watch(financeSnapshotProvider).shortcuts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Shortcuts',
          subtitle: 'Type keyword.amount in the capture bar, e.g. coffee.250.',
        ),
        const SizedBox(height: 12),
        if (shortcuts.isEmpty)
          const EmptyState(
            title: 'No shortcuts yet',
            message: 'Create one for the things you log every week.',
          )
        else
          for (final shortcut in shortcuts)
            AppCard(
              onTap: () => showAppSheet<void>(
                context,
                (_) => _ShortcutSheet(shortcut: shortcut),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${shortcut.keyword} → ${shortcut.name}',
                          style: AppTypography.sans(
                            size: 14,
                            color: c.tx,
                            weight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${shortcut.category} · ${shortcut.isIncome ? 'income' : 'expense'} · ${rupee(shortcut.amount.abs())}',
                          style: AppTypography.sans(size: 11, color: c.mu),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    shortcut.keyword,
                    style: AppTypography.sans(size: 11, color: c.ac),
                  ),
                ],
              ),
            ),
        PrimaryButton(
          label: '+ New shortcut',
          onTap: () =>
              showAppSheet<void>(context, (_) => const _ShortcutSheet()),
        ),
      ],
    );
  }
}

class _ShortcutSheet extends ConsumerStatefulWidget {
  const _ShortcutSheet({this.shortcut});

  final Shortcut? shortcut;

  @override
  ConsumerState<_ShortcutSheet> createState() => _ShortcutSheetState();
}

class _ShortcutSheetState extends ConsumerState<_ShortcutSheet> {
  late final TextEditingController _keyword;
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late bool _income;
  late String _category;
  late String _accountId;

  @override
  void initState() {
    super.initState();
    final shortcut = widget.shortcut;
    _keyword = TextEditingController(text: shortcut?.keyword ?? '');
    _name = TextEditingController(text: shortcut?.name ?? '');
    _amount = TextEditingController(
      text: shortcut == null ? '' : shortcut.amount.abs().round().toString(),
    );
    _income = shortcut?.isIncome ?? false;
    final settings = ref.read(settingsProvider);
    _category =
        shortcut?.category ??
        (settings.categories.isEmpty
            ? 'Other'
            : settings.categories.keys.first);
    _accountId = shortcut?.accountId ?? '';
  }

  @override
  void dispose() {
    _keyword.dispose();
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final keyword = _keyword.text.trim();
    final name = _name.text.trim();
    if (keyword.isEmpty || name.isEmpty) {
      ref.read(toastProvider.notifier).show('Add a keyword and a name');
      return;
    }
    final amount = double.tryParse(_amount.text) ?? 0;
    final repo = ref.read(shortcutRepositoryProvider);
    final existing = widget.shortcut;
    if (existing == null) {
      await repo.addShortcut(
        keyword: keyword,
        name: name,
        amount: amount,
        category: _category,
        isIncome: _income,
        accountId: _accountId.isEmpty ? null : _accountId,
      );
    } else {
      await repo.updateShortcut(
        Shortcut(
          id: existing.id,
          keyword: keyword,
          name: name,
          amount: _income ? amount.abs() : -amount.abs(),
          category: _category,
          isIncome: _income,
          accountId: _accountId.isEmpty ? null : _accountId,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Shortcut saved');
  }

  Future<void> _delete() async {
    final existing = widget.shortcut;
    if (existing == null) return;
    await ref.read(shortcutRepositoryProvider).removeShortcut(existing.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Shortcut removed');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final settings = ref.watch(settingsProvider);
    final categories = <String>{
      ...settings.categories.keys,
      if (_category.isNotEmpty) _category,
    }.toList();
    final accounts = <AppSelectOption<String>>[
      const AppSelectOption('', 'No account'),
      for (final account in snapshot.accounts)
        AppSelectOption(account.id, account.name),
      for (final card in snapshot.cards)
        AppSelectOption(card.id, 'Card · ${card.name}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.shortcut == null ? 'New shortcut' : 'Edit shortcut'),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Keyword',
          child: _Field(controller: _keyword, hint: 'Keyword (e.g. coffee)'),
        ),
        LabeledField(
          label: 'Transaction name',
          child: _Field(controller: _name, hint: 'Transaction name'),
        ),
        LabeledField(
          label: 'Default amount',
          child: _Field(
            controller: _amount,
            hint: 'Default amount (optional)',
            number: true,
          ),
        ),
        LabeledField(
          label: 'Type',
          child: SegmentedControl<bool>(
            margin: EdgeInsets.zero,
            options: const [
              SegmentedOption(false, 'Expense'),
              SegmentedOption(true, 'Income'),
            ],
            selected: _income,
            onChanged: (value) => setState(() => _income = value),
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
            value: _accountId,
            hint: 'No account',
            options: accounts,
            onChanged: (value) => setState(() => _accountId = value ?? ''),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Save shortcut', onTap: _save),
        if (widget.shortcut != null)
          AppButton(
            label: 'Delete shortcut',
            color: c.co,
            centered: true,
            onTap: _delete,
          ),
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
