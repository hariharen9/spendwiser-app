import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/custom_painters/health_score_gauge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/credit_card.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/transaction.dart';
import '../transactions/add_transaction_sheet.dart';
import 'card_sheets.dart';
import 'widgets/credit_card_face.dart';
import '../../core/widgets/segmented_control.dart';

enum _CardTab { overview, statements, transactions }

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  int _selected = 0;
  bool _flipped = false;
  _CardTab _tab = _CardTab.overview;
  String _cycle = 'all';
  String _category = '';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    if (snapshot.cards.isEmpty) {
      return ScreenScroll(
        children: [
          const PageHeader(title: 'Cards', subtitle: 'No cards yet'),
          EmptyState(
            title: 'Add a credit card',
            message: 'Track statements, dues and rewards in one place.',
            actionLabel: 'Add card',
            onAction: () => showAddCardSheet(context),
          ),
        ],
      );
    }
    final selected = _selected.clamp(0, snapshot.cards.length - 1);
    final card = snapshot.cards[selected];

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'Cards',
          subtitle:
              '${snapshot.cards.length} cards · ${rupee(snapshot.cardAvailable)} available',
        ),
        const SizedBox(height: 8),
        BleedRow(
          height: 176,
          spacing: 10,
          children: [
            for (var i = 0; i < snapshot.cards.length; i++)
              CreditCardFace(
                key: ValueKey(snapshot.cards[i].id),
                card: snapshot.cards[i],
                selected: i == selected,
                flipped: i == selected && _flipped,
                onTap: () {
                  Haptics.light();
                  setState(() {
                    if (i == selected) {
                      _flipped = !_flipped;
                    } else {
                      _selected = i;
                      _flipped = false;
                    }
                  });
                },
              ),
            _AddCardTile(onTap: () => showAddCardSheet(context)),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Tap a card to flip · CVV',
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
        ),
        SegmentedControl<_CardTab>(
          options: const [
            SegmentedOption(_CardTab.overview, 'Overview'),
            SegmentedOption(_CardTab.statements, 'Statements'),
            SegmentedOption(_CardTab.transactions, 'Transactions'),
          ],
          selected: _tab,
          onChanged: (value) => setState(() => _tab = value),
        ),
        switch (_tab) {
          _CardTab.overview => _Overview(
            card: card,
            snapshot: snapshot,
            onPay: () => showPayCardSheet(context, card.id),
            onEmi: () => showEmiSheet(context, card.id),
            onManage: () => showManageCardSheet(context, card.id),
            onStatement: () =>
                showStatementDetailSheet(context, card.id, statementIndex: 0),
            onOpenCycle: () =>
                showStatementDetailSheet(context, card.id, openCycle: true),
          ),
          _CardTab.statements => _Statements(
            card: card,
            snapshot: snapshot,
            onOpen: (index) => showStatementDetailSheet(
              context,
              card.id,
              statementIndex: index,
            ),
            onOpenCycle: () =>
                showStatementDetailSheet(context, card.id, openCycle: true),
          ),
          _CardTab.transactions => _Transactions(
            card: card,
            snapshot: snapshot,
            cycle: _cycle,
            category: _category,
            query: _query,
            onCycle: (value) => setState(() => _cycle = value),
            onCategory: (value) => setState(() => _category = value),
            onQuery: (value) => setState(() => _query = value),
            onAdd: () => showAddTransactionSheet(context, cardId: card.id),
          ),
        },
      ],
    );
  }
}

class _AddCardTile extends StatelessWidget {
  const _AddCardTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        height: 176,
        decoration: BoxDecoration(
          color: c.c1,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.ln),
        ),
        alignment: Alignment.center,
        child: Text(
          '+ Add card',
          style: AppTypography.sans(size: 14, color: c.mu),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.card,
    required this.snapshot,
    required this.onPay,
    required this.onEmi,
    required this.onManage,
    required this.onStatement,
    required this.onOpenCycle,
  });

  final CreditCard card;
  final FinanceSnapshot snapshot;
  final VoidCallback onPay;
  final VoidCallback onEmi;
  final VoidCallback onManage;
  final VoidCallback onStatement;
  final VoidCallback onOpenCycle;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final due = card.due;
    final latest = card.statements.isNotEmpty ? card.statements.first : null;
    final cycle = card.openCycle;
    final cats = <String, double>{};
    if (cycle != null) {
      for (final t in snapshot.forCard(card.id)) {
        if (t.amount < 0 &&
            !t.date.isBefore(cycle.start) &&
            t.date.isBefore(cycle.end.add(const Duration(days: 1)))) {
          cats[t.category] = (cats[t.category] ?? 0) - t.amount;
        }
      }
    }
    final maxCat = cats.isEmpty
        ? 1.0
        : cats.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          border: Border.all(
            color: due?.status == StatementStatus.overdue ? c.co : c.ln,
          ),
          child: due == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All paid up',
                      style: AppTypography.serif(size: 30, color: c.tx),
                    ),
                    Text(
                      'No statement is due on this card.',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            due.status == StatementStatus.overdue
                                ? 'Overdue'
                                : 'Statement due',
                            style: AppTypography.sans(size: 14, color: c.mu),
                          ),
                        ),
                        AppPill(
                          label: due.days < 0
                              ? '${-due.days} days late'
                              : due.days == 0
                              ? 'Due today'
                              : 'In ${due.days} days',
                          active: due.status != StatementStatus.overdue,
                          textColor: due.status == StatementStatus.overdue
                              ? c.co
                              : null,
                          borderColor: due.status == StatementStatus.overdue
                              ? c.co
                              : null,
                          background: due.status == StatementStatus.overdue
                              ? c.c1
                              : null,
                        ),
                      ],
                    ),
                    AnimatedAmount(
                      value: due.amount,
                      style: AppTypography.serif(
                        size: 46,
                        color: c.tx,
                        letterSpacing: -1,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Minimum ${rupee(card.minimumDue)} · pay by ${card.dueLabel}',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Pay now',
                            primary: true,
                            centered: true,
                            margin: EdgeInsets.zero,
                            onTap: onPay,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Convert to EMI',
                            centered: true,
                            margin: EdgeInsets.zero,
                            onTap: onEmi,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        if (latest != null && latest.amount > 0)
          AppCard(
            onTap: onStatement,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Latest statement',
                        style: AppTypography.sans(
                          size: 14,
                          color: c.tx,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SpendIcon('chevronRight', size: 16, color: c.mu),
                  ],
                ),
                Text(
                  '${dayMonth(latest.start)} – ${dayMonth(latest.end)}',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedAmount(
                        value: latest.amount,
                        style: AppTypography.serif(size: 28, color: c.tx),
                      ),
                    ),
                    AppPill(
                      label: latest.status.label,
                      textColor: latest.status.color(c),
                      background: c.c1,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: latest.paidRatio,
                    minHeight: 6,
                    backgroundColor: c.c2,
                    valueColor: AlwaysStoppedAnimation(c.ac),
                  ),
                ),
                const SizedBox(height: 6),
                MoneyText(
                  '${rupee(latest.paid)} paid · ${rupee(latest.remaining)} remaining',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ],
            ),
          ),
        if (cycle != null)
          AppCard(
            onTap: onOpenCycle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Current cycle',
                        style: AppTypography.sans(
                          size: 14,
                          color: c.tx,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'closes in ${cycle.daysLeft} days',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
                Text(
                  '${dayMonth(cycle.start)} – ${dayMonth(cycle.end)}',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: rupee(cycle.amount),
                        style: AppTypography.serif(size: 30, color: c.tx),
                      ),
                      TextSpan(
                        text: '  unbilled so far',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry
                    in cats.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: AppTypography.sans(
                                  size: 12,
                                  color: c.tx,
                                ),
                              ),
                            ),
                            MoneyText(
                              rupee(entry.value),
                              style: AppTypography.sans(size: 12, color: c.mu),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value / maxCat,
                            minHeight: 4,
                            backgroundColor: c.c2,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.category(entry.key),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        AppCard(
          child: Row(
            children: [
              HealthScoreGauge(
                score: card.utilisation.round(),
                size: 84,
                strokeWidth: 9,
                color: card.utilisation > 50 ? c.co : c.ac,
                showScore: false,
                child: Text(
                  '${card.utilisation.round()}%',
                  style: AppTypography.serif(size: 20, color: c.tx),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Credit limit',
                      value: MoneyText(
                        rupee(card.limit),
                        style: AppTypography.sans(size: 14, color: c.tx),
                      ),
                      padding: const EdgeInsets.only(bottom: 8),
                    ),
                    KeyValueRow(
                      label: 'Outstanding',
                      value: MoneyText(
                        rupee(card.outstanding),
                        style: AppTypography.sans(size: 14, color: c.tx),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    KeyValueRow(
                      label: 'Available',
                      value: MoneyText(
                        rupee(card.available),
                        style: AppTypography.sans(size: 14, color: c.ac),
                      ),
                      padding: const EdgeInsets.only(top: 8),
                      border: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Statement day · due day',
                value: Text(
                  '${card.statementDay}th → ${card.dueDay}th',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
                padding: const EdgeInsets.only(bottom: 10),
              ),
              KeyValueRow(
                label: 'Reward points',
                value: MoneyText(
                  '${card.rewardPoints} ≈ ${rupee(card.rewardPoints / 4)}',
                  style: AppTypography.sans(size: 14, color: c.ac),
                ),
                padding: const EdgeInsets.only(top: 10),
                border: false,
              ),
            ],
          ),
        ),
        AppButton(
          label: '+ Add transaction on this card',
          onTap: () => showAddTransactionSheet(context, cardId: card.id),
        ),
        AppButton(label: 'Manage card', onTap: onManage),
      ],
    );
  }
}

class _Statements extends StatelessWidget {
  const _Statements({
    required this.card,
    required this.snapshot,
    required this.onOpen,
    required this.onOpenCycle,
  });

  final CreditCard card;
  final FinanceSnapshot snapshot;
  final ValueChanged<int> onOpen;
  final VoidCallback onOpenCycle;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final listed = card.statements.where((s) => s.amount > 0).toList();
    final billed = listed.fold<double>(0, (sum, s) => sum + s.amount);
    final paid = listed.where((s) => s.status == StatementStatus.paid).length;
    final open = card.openCycle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Billed · 6 mo',
                amount: billed,
                formatter: compactINR,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Avg / month',
                amount: listed.isEmpty ? 0 : billed / listed.length,
                formatter: compactINR,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Paid',
                value: listed.isEmpty ? '—' : '$paid/${listed.length}',
                valueColor: listed.isNotEmpty && paid == listed.length
                    ? c.ac
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (open != null)
          AppCard(
            dashed: true,
            onTap: onOpenCycle,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open cycle',
                        style: AppTypography.sans(
                          size: 14,
                          color: c.tx,
                          weight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${dayMonth(open.start)} – ${dayMonth(open.end)}',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rupee(open.amount),
                      style: AppTypography.serif(size: 24, color: c.tx),
                    ),
                    Text(
                      'unbilled',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ],
            ),
          ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < listed.length; i++)
                _StatementRow(
                  statement: listed[i],
                  onTap: () => onOpen(listed[i].index),
                  showDivider: i < listed.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({
    required this.statement,
    required this.onTap,
    required this.showDivider,
  });

  final CardStatement statement;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: c.ln)) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dayMonth(statement.start)} – ${dayMonth(statement.end)}',
                    style: AppTypography.sans(size: 13, color: c.tx),
                  ),
                  Text(
                    'Due ${dayMonth(statement.dueDate)}${statement.paid > 0 ? ' · ${rupee(statement.paid)} paid' : ''}',
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(
                  rupee(statement.amount),
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                Text(
                  statement.status.label,
                  style: AppTypography.sans(
                    size: 11,
                    color: statement.status.color(c),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Transactions extends ConsumerWidget {
  const _Transactions({
    required this.card,
    required this.snapshot,
    required this.cycle,
    required this.category,
    required this.query,
    required this.onCycle,
    required this.onCategory,
    required this.onQuery,
    required this.onAdd,
  });

  final CreditCard card;
  final FinanceSnapshot snapshot;
  final String cycle;
  final String category;
  final String query;
  final ValueChanged<String> onCycle;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onQuery;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final open = card.openCycle;
    DateTime? start;
    DateTime? end;
    if (cycle == 'open' && open != null) {
      start = open.start;
      end = open.end.add(const Duration(days: 1));
    } else if (cycle != 'all' && cycle != 'open') {
      final index = int.tryParse(cycle);
      if (index != null && index < card.statements.length) {
        start = card.statements[index].start;
        end = card.statements[index].end.add(const Duration(days: 1));
      }
    }
    final items =
        snapshot
            .forCard(card.id)
            .where(
              (t) =>
                  (start == null ||
                      (!t.date.isBefore(start) && t.date.isBefore(end!))) &&
                  (category.isEmpty || t.category == category) &&
                  (query.isEmpty ||
                      '${t.merchant}${t.note}'.toLowerCase().contains(
                        query.toLowerCase(),
                      )),
            )
            .toList()
          ..sort(compareTransactionsNewestFirst);
    final categories = <String>{
      for (final t in snapshot.forCard(card.id)) t.category,
    }.toList();
    final total = items.fold<double>(0, (sum, t) => sum - t.amount);

    final grouped = <String, List<Transaction>>{};
    for (final t in items) {
      grouped.putIfAbsent(t.dateLabel, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSelect<String>(
          value: cycle,
          margin: const EdgeInsets.only(bottom: 8),
          options: [
            const AppSelectOption('all', 'All time'),
            if (open != null)
              AppSelectOption(
                'open',
                'Open cycle · ${dayMonth(open.start)} – ${dayMonth(open.end)}',
              ),
            for (final statement in card.statements.where((s) => s.amount > 0))
              AppSelectOption(
                '${statement.index}',
                'Statement · ${dayMonth(statement.start)} – ${dayMonth(statement.end)}',
              ),
          ],
          onChanged: (value) => onCycle(value ?? 'all'),
        ),
        Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: c.c1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.ln),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  textAlignVertical: TextAlignVertical.center,
                  style: AppTypography.sans(size: 14, color: c.tx),
                  onChanged: onQuery,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: 'Search this card…',
                    hintStyle: AppTypography.sans(size: 14, color: c.mu),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.ac,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: SpendIcon('plus', size: 18, color: c.aci),
                ),
              ),
            ],
          ),
        ),
        BleedRow(
          height: 34,
          children: [
            AppPill(
              label: 'All',
              active: category.isEmpty,
              onTap: () => onCategory(''),
            ),
            for (final cat in categories)
              AppPill(
                label: cat,
                active: category == cat,
                onTap: () => onCategory(cat),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} transactions',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                    MoneyText(
                      rupee(total),
                      style: AppTypography.serif(size: 28, color: c.tx),
                    ),
                  ],
                ),
              ),
              AppPill(
                label: 'Export',
                onTap: () {
                  ref.read(toastProvider.notifier).show('Exporting CSV…');
                },
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          EmptyState(
            title: 'No transactions here',
            message: 'Add one on this card.',
            actionLabel: 'Add',
            onAction: onAdd,
          )
        else
          for (final entry in grouped.entries) ...[
            SectionCaption(
              entry.key,
              margin: const EdgeInsets.only(top: 10, bottom: 2),
              trailing: MoneyText(
                rupee(entry.value.fold<double>(0, (sum, t) => sum - t.amount)),
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < entry.value.length; i++)
                    TransactionRow(
                      transaction: entry.value[i],
                      showDivider: i < entry.value.length - 1,
                    ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}
