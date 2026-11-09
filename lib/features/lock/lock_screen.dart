import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/pressable.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with TickerProviderStateMixin {
  late final AnimationController _exitController;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  String _pin = '';
  bool _hasError = false;
  bool _didAutoPromptBiometrics = false;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14.0, end: 14.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    // Auto-prompt biometrics once on screen display if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptBiometrics();
    });
  }

  @override
  void dispose() {
    _exitController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkAndPromptBiometrics() async {
    if (!mounted || _didAutoPromptBiometrics) return;
    final security = ref.read(securityProvider);
    if (security.biometricsEnabled && !security.isLockedOut) {
      _didAutoPromptBiometrics = true;
      // Slight delay so the screen transition completes smoothly
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      await _tryBiometrics();
    }
  }

  Future<void> _tryBiometrics() async {
    final security = ref.read(securityProvider);
    if (security.isLockedOut) return;

    Haptics.light();
    final success = await ref
        .read(securityProvider.notifier)
        .authenticateBiometrics(reason: 'Unlock Spendwiser');

    if (success && mounted) {
      await _completeUnlock();
    }
  }

  Future<void> _completeUnlock() async {
    Haptics.medium();
    await _exitController.forward();
    if (!mounted) return;
    ref.read(securityProvider.notifier).unlock();
    widget.onUnlocked();
  }

  void _onDigit(String digit) {
    final security = ref.read(securityProvider);
    if (security.isLockedOut || _pin.length >= 4) return;

    Haptics.light();
    setState(() {
      _hasError = false;
      _pin += digit;
    });

    if (_pin.length == 4) {
      _verifyCurrentPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    Haptics.light();
    setState(() {
      _hasError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _onClear() {
    if (_pin.isEmpty) return;
    Haptics.medium();
    setState(() {
      _hasError = false;
      _pin = '';
    });
  }

  void _verifyCurrentPin() {
    final valid = ref.read(securityProvider.notifier).verifyPin(_pin);
    if (valid) {
      _completeUnlock();
    } else {
      Haptics.heavy();
      setState(() {
        _hasError = true;
        _pin = '';
      });
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final security = ref.watch(securityProvider);
    final isLockedOut = security.isLockedOut;
    final lockoutSeconds = security.lockoutSecondsRemaining;

    return AnimatedBuilder(
      animation: _exitController,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_exitController.value);
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1 + t * 0.08,
            child: child,
          ),
        );
      },
      child: Material(
        color: c.bg,
        child: Container(
          decoration: BoxDecoration(
            color: c.bg,
            gradient: RadialGradient(
              center: const Alignment(0, -0.6),
              radius: 1.1,
              colors: [
                c.ac.withValues(alpha: 0.12),
                c.bg.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.75],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const Spacer(flex: 2),
                            // Top branding & Shield icon
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.c1,
                                border: Border.all(color: c.ln),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.ac.withValues(alpha: 0.12),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: SpendIcon('vault', size: 30, color: c.ac),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Spendwiser',
                              style: AppTypography.serif(size: 34, color: c.tx),
                            ),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                isLockedOut
                                    ? 'PIN locked. Try again in ${lockoutSeconds}s'
                                    : _hasError
                                        ? 'Incorrect PIN. Try again.'
                                        : security.biometricsEnabled
                                            ? 'Enter PIN or use biometrics'
                                            : 'Enter your 4-digit PIN',
                                key: ValueKey(
                                  '${isLockedOut ? lockoutSeconds : _hasError ? "err" : "norm"}',
                                ),
                                textAlign: TextAlign.center,
                                style: AppTypography.sans(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: isLockedOut || _hasError ? c.co : c.mu,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // PIN dots with shake animation
                            AnimatedBuilder(
                              animation: _shakeAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(_shakeAnimation.value, 0),
                                  child: child,
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (index) {
                                  final isFilled = index < _pin.length;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    margin: const EdgeInsets.symmetric(horizontal: 10),
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFilled
                                          ? (_hasError ? c.co : c.ac)
                                          : c.c2,
                                      border: Border.all(
                                        color: isFilled
                                            ? (_hasError ? c.co : c.ac)
                                            : c.ln,
                                        width: 1.5,
                                      ),
                                      boxShadow: isFilled
                                          ? [
                                              BoxShadow(
                                                color: (_hasError ? c.co : c.ac)
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                            ),

                            const Spacer(flex: 3),

                            // Numpad
                            _LockNumpad(
                              onDigit: _onDigit,
                              onBackspace: _onBackspace,
                              onClear: _onClear,
                              onBiometric:
                                  security.biometricsEnabled ? _tryBiometrics : null,
                              showBiometric: security.biometricsEnabled,
                              disabled: isLockedOut,
                            ),

                            const Spacer(flex: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LockNumpad extends StatelessWidget {
  const _LockNumpad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onBiometric,
    required this.showBiometric,
    this.disabled = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback? onBiometric;
  final bool showBiometric;
  final bool disabled;

  Widget _buildRow(Widget c1, Widget c2, Widget c3) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        c1,
        const SizedBox(width: 24),
        c2,
        const SizedBox(width: 24),
        c3,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in keys) ...[
          _buildRow(
            _NumButton(
              text: row[0],
              onTap: disabled ? null : () => onDigit(row[0]),
            ),
            _NumButton(
              text: row[1],
              onTap: disabled ? null : () => onDigit(row[1]),
            ),
            _NumButton(
              text: row[2],
              onTap: disabled ? null : () => onDigit(row[2]),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _buildRow(
          // Left: Biometric trigger or exactly sized placeholder
          showBiometric && onBiometric != null
              ? _ActionButton(
                  icon: Icons.fingerprint,
                  onTap: disabled ? null : onBiometric,
                )
              : const SizedBox(width: 72, height: 72),

          // Middle: 0
          _NumButton(
            text: '0',
            onTap: disabled ? null : () => onDigit('0'),
          ),

          // Right: Backspace
          _ActionButton(
            icon: Icons.backspace_outlined,
            onTap: disabled ? null : onBackspace,
            onLongPress: disabled ? null : onClear,
          ),
        ),
      ],
    );
  }
}

class _NumButton extends StatelessWidget {
  const _NumButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SizedBox(
      width: 72,
      height: 72,
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.c1.withValues(alpha: 0.9),
            border: Border.all(color: c.ln.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 26,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: onTap == null ? c.mu.withValues(alpha: 0.4) : c.tx,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SizedBox(
      width: 72,
      height: 72,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Pressable(
          onTap: onTap,
          scale: 0.92,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 26,
              color: onTap == null ? c.mu.withValues(alpha: 0.4) : c.tx,
            ),
          ),
        ),
      ),
    );
  }
}
