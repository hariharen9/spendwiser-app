import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/services/finance_calculator.dart';
import '../shell/app_module.dart';
import '../transactions/add_transaction_sheet.dart';

enum _ToolTab {
  calc('Calc'),
  emi('EMI'),
  sip('SIP'),
  gst('GST');

  const _ToolTab(this.label);
  final String label;
}

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key, required this.onNavigate});

  final ValueChanged<AppModule> onNavigate;

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  _ToolTab _tab = _ToolTab.calc;
  String _expression = '';
  double _loan = 2500000;
  double _rate = 8.5;
  double _years = 20;
  double _sip = 10000;
  double _sipRate = 12;
  double _sipYears = 15;
  final _gstAmount = TextEditingController();
  int _gstRate = 18;

  @override
  void dispose() {
    _gstAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScroll(
      children: [
        const PageHeader(title: 'Tools', subtitle: 'Quick utilities'),
        SegmentedControl<_ToolTab>(
          options: [
            for (final tab in _ToolTab.values) SegmentedOption(tab, tab.label),
          ],
          selected: _tab,
          onChanged: (value) => setState(() => _tab = value),
        ),
        switch (_tab) {
          _ToolTab.calc => _calculator(context),
          _ToolTab.emi => _emi(context),
          _ToolTab.sip => _sipCalculator(context),
          _ToolTab.gst => _gst(context),
        },
        const SectionCaption('Shortcuts'),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            _Shortcut(
              label: 'Add',
              onTap: () => showAddTransactionSheet(context),
            ),
            _Shortcut(
              label: 'Pay card',
              onTap: () => widget.onNavigate(AppModule.cards),
            ),
            _Shortcut(
              label: 'Split',
              onTap: () => widget.onNavigate(AppModule.split),
            ),
            _Shortcut(
              label: 'Export',
              onTap: () =>
                  ref.read(toastProvider.notifier).show('Preparing export…'),
            ),
            _Shortcut(
              label: 'Budgets',
              onTap: () => widget.onNavigate(AppModule.budgets),
            ),
            _Shortcut(
              label: 'Subs',
              onTap: () => widget.onNavigate(AppModule.subscriptions),
            ),
            _Shortcut(
              label: 'Debt',
              onTap: () => widget.onNavigate(AppModule.debt),
            ),
            _Shortcut(
              label: 'Insights',
              onTap: () => widget.onNavigate(AppModule.insights),
            ),
          ],
        ),
      ],
    );
  }

  Widget _calculator(BuildContext context) {
    final c = context.spend;
    final preview = _evaluate(_expression);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                preview == null ? ' ' : '= $preview',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              Text(
                _expression.isEmpty ? '0' : _expression,
                textAlign: TextAlign.right,
                style: AppTypography.serif(size: 46, color: c.tx),
              ),
            ],
          ),
        ),
        for (final row in const [
          ['C', '⌫', '%', '÷'],
          ['7', '8', '9', '×'],
          ['4', '5', '6', '−'],
          ['1', '2', '3', '+'],
          ['0', '.', '(', ')'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _Key(
                      label: row[i],
                      accent: const ['÷', '×', '−', '+'].contains(row[i]),
                      onTap: () => _key(row[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        _Key(
          label: '=',
          accent: true,
          wide: true,
          onTap: () {
            final result = _evaluate(_expression);
            if (result != null) {
              setState(() => _expression = result);
            }
          },
        ),
      ],
    );
  }

  Widget _emi(BuildContext context) {
    final c = context.spend;
    final emi = FinanceCalculator.emiFor(_loan, _rate, (_years * 12).round());
    final interest = emi * _years * 12 - _loan;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Monthly EMI', style: AppTypography.sans(size: 12, color: c.mu)),
          Text(
            '${rupee(emi)} /mo',
            style: AppTypography.serif(size: 46, color: c.tx),
          ),
          Text(
            'Interest ${rupee(interest)}',
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
          _SliderRow(
            label: 'Loan amount',
            value: rupee(_loan),
            value2: _loan,
            min: 100000,
            max: 10000000,
            step: 50000,
            onChanged: (value) => setState(() => _loan = value),
          ),
          _SliderRow(
            label: 'Interest rate',
            value: '${_rate.toStringAsFixed(1)}%',
            value2: _rate,
            min: 5,
            max: 18,
            step: 0.1,
            onChanged: (value) => setState(() => _rate = value),
          ),
          _SliderRow(
            label: 'Tenure',
            value: '${_years.round()} yrs',
            value2: _years,
            min: 1,
            max: 30,
            step: 1,
            onChanged: (value) => setState(() => _years = value),
          ),
        ],
      ),
    );
  }

  Widget _sipCalculator(BuildContext context) {
    final c = context.spend;
    final i = _sipRate / 1200;
    final n = _sipYears * 12;
    final corpus = _sip * (((math.pow(1 + i, n) - 1) / i) * (1 + i));
    final invested = _sip * n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Corpus after ${_sipYears.round()} years',
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
          Text(
            rupee(corpus),
            style: AppTypography.serif(size: 46, color: c.tx),
          ),
          Text(
            'Invested ${rupee(invested)} · gains ${rupee(corpus - invested)}',
            style: AppTypography.sans(size: 12, color: c.mu),
          ),
          _SliderRow(
            label: 'Monthly SIP',
            value: rupee(_sip),
            value2: _sip,
            min: 500,
            max: 200000,
            step: 500,
            onChanged: (value) => setState(() => _sip = value),
          ),
          _SliderRow(
            label: 'Expected return',
            value: '${_sipRate.toStringAsFixed(1)}%',
            value2: _sipRate,
            min: 4,
            max: 20,
            step: 0.5,
            onChanged: (value) => setState(() => _sipRate = value),
          ),
          _SliderRow(
            label: 'Years',
            value: '${_sipYears.round()} yrs',
            value2: _sipYears,
            min: 1,
            max: 40,
            step: 1,
            onChanged: (value) => setState(() => _sipYears = value),
          ),
        ],
      ),
    );
  }

  Widget _gst(BuildContext context) {
    final c = context.spend;
    final amount = double.tryParse(_gstAmount.text) ?? 0;
    final gst = amount * _gstRate / 100;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _gstAmount,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              style: AppTypography.sans(size: 14, color: c.tx),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Amount before GST',
                hintStyle: AppTypography.sans(size: 13, color: c.mu),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final rate in const [5, 12, 18, 28])
                AppPill(
                  label: '$rate%',
                  active: _gstRate == rate,
                  onTap: () => setState(() => _gstRate = rate),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'GST ${rupee(gst)} · Total ${rupee(amount + gst)}',
            style: AppTypography.serif(size: 28, color: c.tx),
          ),
        ],
      ),
    );
  }

  void _key(String key) {
    Haptics.light();
    setState(() {
      if (key == 'C') {
        _expression = '';
      } else if (key == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (key == '=') {
        final result = _evaluate(_expression);
        if (result != null) _expression = result;
      } else {
        _expression += key;
      }
    });
  }

  String? _evaluate(String input) {
    final normalized = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('%', '/100')
        .replaceAll(' ', '');
    if (normalized.isEmpty) return null;
    if (!RegExp(r'^[\d+\-*/.()]+$').hasMatch(normalized)) return null;
    try {
      final parser = _ExpressionParser(normalized);
      final value = parser.parse();
      if (!value.isFinite) return null;
      final rounded = (value * 100000000).round() / 100000000;
      return rounded == rounded.roundToDouble()
          ? rounded.round().toString()
          : rounded.toString();
    } catch (_) {
      return null;
    }
  }
}

class _ExpressionParser {
  _ExpressionParser(this.source);
  final String source;
  int _index = 0;

  double parse() {
    final value = _expression();
    if (_index != source.length) throw const FormatException('trailing');
    return value;
  }

  double _expression() {
    var value = _term();
    while (_index < source.length) {
      final char = source[_index];
      if (char == '+') {
        _index++;
        value += _term();
      } else if (char == '-') {
        _index++;
        value -= _term();
      } else {
        break;
      }
    }
    return value;
  }

  double _term() {
    var value = _factor();
    while (_index < source.length) {
      final char = source[_index];
      if (char == '*') {
        _index++;
        value *= _factor();
      } else if (char == '/') {
        _index++;
        value /= _factor();
      } else {
        break;
      }
    }
    return value;
  }

  double _factor() {
    if (_index >= source.length) throw const FormatException('end');
    final char = source[_index];
    if (char == '-') {
      _index++;
      return -_factor();
    }
    if (char == '+') {
      _index++;
      return _factor();
    }
    if (char == '(') {
      _index++;
      final value = _expression();
      if (_index >= source.length || source[_index] != ')') {
        throw const FormatException('paren');
      }
      _index++;
      return value;
    }
    final start = _index;
    while (_index < source.length &&
        RegExp(r'[\d.]').hasMatch(source[_index])) {
      _index++;
    }
    if (start == _index) throw const FormatException('number');
    return double.parse(source.substring(start, _index));
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    this.accent = false,
    this.wide = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: wide ? double.infinity : null,
        height: 52,
        decoration: BoxDecoration(
          color: accent ? c.ac : c.c2,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.sans(
            size: 18,
            color: accent ? c.aci : c.tx,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.c1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.ln),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppTypography.sans(size: 12, color: c.tx)),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.value2,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final String value;
  final double value2;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final divisions = ((max - min) / step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
              ),
              Text(value, style: AppTypography.sans(size: 12, color: c.mu)),
            ],
          ),
        ),
        SliderTheme(
          data: Theme.of(context).sliderTheme.copyWith(
            trackHeight: 4,
            activeTrackColor: c.ac,
            inactiveTrackColor: c.c2,
            thumbColor: c.ac,
            overlayColor: c.ac.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value2.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: math.max(1, divisions),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
