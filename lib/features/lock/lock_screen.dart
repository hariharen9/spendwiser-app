import 'package:flutter/material.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _unlock;

  @override
  void initState() {
    super.initState();
    _unlock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _unlock.dispose();
    super.dispose();
  }

  Future<void> _unlockNow() async {
    Haptics.medium();
    await _unlock.forward();
    if (!mounted) return;
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return AnimatedBuilder(
      animation: _unlock,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_unlock.value);
        return Opacity(
          opacity: 1 - t,
          child: Transform.scale(scale: 1 + t * 0.1, child: child),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.bg,
          gradient: RadialGradient(
            center: const Alignment(0, -1),
            radius: 1.2,
            colors: [c.ac.withValues(alpha: 0.16), c.bg.withValues(alpha: 0)],
            stops: const [0, 0.7],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Spendwiser',
                style: AppTypography.serif(size: 46, color: c.tx),
              ),
              Text('Locked', style: AppTypography.sans(size: 14, color: c.mu)),
              const SizedBox(height: 22),
              Pressable(
                onTap: _unlockNow,
                scale: 0.94,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.c1,
                    border: Border.all(color: c.ln),
                    boxShadow: [
                      BoxShadow(
                        color: c.ac.withValues(alpha: 0.08),
                        blurRadius: 0,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: SpendIcon('vault', size: 34, color: c.ac),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tap to unlock with Face ID',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              const SizedBox(height: 18),
              Pressable(
                onTap: () => showAppSheet<void>(
                  context,
                  (sheetContext) => _PinSheet(
                    onComplete: () {
                      Navigator.of(sheetContext).pop();
                      _unlockNow();
                    },
                  ),
                ),
                child: Text(
                  'Use PIN instead',
                  style: AppTypography.sans(size: 12, color: c.ac),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';

  void _append(String digit) {
    Haptics.light();
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      Future<void>.delayed(
        const Duration(milliseconds: 180),
        widget.onComplete,
      );
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    Haptics.light();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Enter your PIN',
          subtitle: 'Any 4 digits unlock the demo.',
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? c.ac : c.c2,
                  border: Border.all(color: i < _pin.length ? c.ac : c.ln),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: row[i].isEmpty
                        ? const SizedBox(height: 52)
                        : GestureDetector(
                            onTap: row[i] == '⌫'
                                ? _backspace
                                : () => _append(row[i]),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: c.c2,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                row[i],
                                style: AppTypography.sans(
                                  size: 18,
                                  color: c.tx,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
