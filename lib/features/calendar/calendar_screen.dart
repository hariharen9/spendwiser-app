import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/month_navigator.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/transaction_row.dart';
import '../../data/models/bill.dart';
import '../../data/services/finance_calculator.dart';
import '../transactions/edit_transaction_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int _monthOffset = 0;
  int? _selectedDay;

  DateTime get _month =>
      DateTime(DateTime.now().year, DateTime.now().month - _monthOffset, 1);

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);
    final month = _month;
    final now = DateTime.now();
    final days = daysInMonth(month.year, month.month);
    final offset = DateTime(month.year, month.month, 1).weekday % 7;
    final allBills = FinanceCalculator.bills(snapshot, now: now);
    final tx = snapshot.inMonth(month);
    final selected =
        _selectedDay ?? (isCurrentMonth(month, now: now) ? now.day : 1);
    final dayBills = allBills
        .where(
          (b) =>
              b.dueDate.year == month.year &&
              b.dueDate.month == month.month &&
              b.dueDate.day == selected,
        )
        .toList();
    final dayTx = tx.where((t) => t.date.day == selected).toList();
    final billsThisMonth = allBills.where(
      (b) => b.dueDate.year == month.year && b.dueDate.month == month.month,
    );
    final due = billsThisMonth.fold<double>(0, (sum, b) => sum + b.amount);
    final income = FinanceCalculator.avgMonthlyIncome(snapshot, now: now);

    return ScreenScroll(
      children: [
        const PageHeader(title: 'Calendar', subtitle: 'Bills & cash flow'),
        MonthNavigator(
          month: month,
          onPrevious: () => setState(() {
            _monthOffset++;
            _selectedDay = null;
          }),
          onNext: _monthOffset == 0
              ? null
              : () => setState(() {
                  _monthOffset--;
                  _selectedDay = null;
                }),
          canGoNext: _monthOffset > 0,
        ),
        AppCard(
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
            children: [
              for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Center(
                  child: Text(
                    label,
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                ),
              for (var i = 0; i < offset; i++) const SizedBox.shrink(),
              for (var day = 1; day <= days; day++)
                GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected == day ? c.ac : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: selected == day
                          ? null
                          : (isCurrentMonth(month, now: now) && day == now.day
                                ? Border.all(color: c.ac)
                                : null),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity:
                              isCurrentMonth(month, now: now) && day > now.day
                              ? 0.55
                              : 1,
                          child: Text(
                            '$day',
                            style: AppTypography.sans(
                              size: 13,
                              color: selected == day ? c.aci : c.tx,
                              weight: selected == day
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (allBills.any(
                              (b) =>
                                  b.dueDate.year == month.year &&
                                  b.dueDate.month == month.month &&
                                  b.dueDate.day == day,
                            ) ||
                            tx.any((t) => t.date.day == day))
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color:
                                    allBills.any(
                                      (b) =>
                                          b.dueDate.year == month.year &&
                                          b.dueDate.month == month.month &&
                                          b.dueDate.day == day,
                                    )
                                    ? c.co
                                    : c.mu,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SectionCaption('$selected ${monthShort[month.month - 1]}'),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < dayBills.length; i++)
                _BillRow(bill: dayBills[i], showDivider: true),
              for (var i = 0; i < dayTx.length; i++)
                TransactionRow(
                  transaction: dayTx[i],
                  showDivider: i < dayTx.length - 1,
                  onTap: () => showEditTransactionSheet(context, dayTx[i].id),
                ),
              if (dayBills.isEmpty && dayTx.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Nothing on this day',
                    style: AppTypography.sans(size: 14, color: c.mu),
                  ),
                ),
            ],
          ),
        ),
        const SectionCaption('Month outlook'),
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Bills still due',
                value: AnimatedAmount(
                  value: due,
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                padding: const EdgeInsets.only(bottom: 10),
              ),
              KeyValueRow(
                label: 'Typical monthly income',
                value: AnimatedAmount(
                  value: income,
                  formatter: (value) => '+${rupee(value)}',
                  style: AppTypography.sans(size: 14, color: c.ac),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              KeyValueRow(
                label: 'Projected cash after bills',
                value: AnimatedAmount(
                  value: snapshot.liquidAssets + income - due,
                  formatter: (value) => formatINR(value),
                  style: AppTypography.serif(size: 22, color: c.tx),
                ),
                padding: const EdgeInsets.only(top: 10),
                border: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.showDivider});

  final BillItem bill;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: c.ln)) : null,
      ),
      child: Row(
        children: [
          IconTile(
            icon: bill.kind == BillKind.loan ? 'loan' : 'receipt',
            color: bill.kind == BillKind.card ? c.co : c.ac,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.name,
                  style: AppTypography.sans(size: 14, color: c.tx),
                ),
                Text('due', style: AppTypography.sans(size: 12, color: c.mu)),
              ],
            ),
          ),
          MoneyText(
            rupee(bill.amount),
            style: AppTypography.sans(size: 14, color: c.tx),
          ),
        ],
      ),
    );
  }
}
