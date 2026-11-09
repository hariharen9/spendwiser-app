import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../data/persistence/pin_vault.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _unlock;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _authenticating = false;

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

  Future<void> _tryBiometric() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final enabled = await _localAuth.isDeviceSupported();
      if (!canCheck || !enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics are not available')),
          );
        }
        return;
      }
      final did = await _localAuth.authenticate(
        localizedReason: 'Unlock Spendwiser',
        biometricOnly: true,
      );
      if (did && mounted) await _unlockNow();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final biometricAvailable = PinVault.biometricsEnabled;
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
                onTap: _authenticating ? null : _tryBiometric,
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
                _authenticating
                    ? 'Waiting for biometrics…'
                    : biometricAvailable
                    ? 'Tap to unlock with Face ID / fingerprint'
                    : 'Tap to unlock with biometrics',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              const SizedBox(height: 18),
              PinVault.hasPin
                  ? Pressable(
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
                    )
                  : Pressable(
                      onTap: () => showAppSheet<void>(
                        context,
                        (sheetContext) => _PinSetupSheet(
                          onDone: () {
                            Navigator.of(sheetContext).pop();
                            _unlockNow();
                          },
                        ),
                      ),
                      child: Text(
                        'Set a PIN',
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

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  String _pin = '';
  bool _confirm = false;
  String _first = '';

  void _append(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      if (!_confirm) {
        setState(() {
          _first = _pin;
          _confirm = true;
          _pin = '';
        });
      } else {
        if (_pin == _first) {
          PinVault.setPin(_pin).then((_) {
            if (mounted) widget.onDone();
          });
        } else {
          setState(() {
            _pin = '';
            _confirm = false;
            _first = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PINs do not match')),
          );
        }
      }
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(
          _confirm ? 'Confirm PIN' : 'Set a 4-digit PIN',
          subtitle: 'Stored as a hash on this device only.',
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
        _PinPad(onDigit: _append, onBack: _backspace),
      ],
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
  String? _error;
  int _attempts = 0;

  void _append(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      if (PinVault.verify(_pin)) {
        _attempts = 0;
        Future<void>.delayed(const Duration(milliseconds: 180), widget.onComplete);
      } else {
        _attempts++;
        setState(() {
          _error = _attempts >= 5
              ? 'Too many attempts — wait 30s or use biometrics'
              : 'Wrong PIN';
          _pin = '';
        });
        if (_attempts >= 5) {
          Future<void>.delayed(const Duration(seconds: 30), () {
            if (mounted) setState(() => _attempts = 0);
          });
        }
      }
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final locked = _attempts >= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Enter your PIN'),
        const SizedBox(height: 8),
        if (_error != null)
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.sans(size: 12, color: c.co),
          ),
        const SizedBox(height: 12),
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
        if (locked)
          Text(
            'PIN locked for 30 seconds',
            textAlign: TextAlign.center,
            style: AppTypography.sans(size: 12, color: c.mu),
          )
        else
          _PinPad(onDigit: _append, onBack: _backspace),
      ],
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onBack});

  final ValueChanged<String> onDigit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in row)
                _PinKey(digit: d, onTap: () => onDigit(d)),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PinKey(digit: '', onTap: null),
            _PinKey(digit: '0', onTap: () => onDigit('0')),
            _PinKey(digit: '⌫', onTap: onBack),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.digit, required this.onTap});

  final String digit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    if (digit.isEmpty) return const SizedBox(width: 72, height: 56);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 56,
        alignment: Alignment.center,
        child: Text(
          digit,
          style: AppTypography.sans(size: 22, color: c.tx),
        ),
      ),
    );
  }
}
