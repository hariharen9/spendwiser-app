import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/state/sms_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/atmosphere_background.dart';
import '../../core/widgets/pressable.dart';
import '../accounts/accounts_screen.dart';
import '../budgets/budgets_screen.dart';
import '../calendar/calendar_screen.dart';
import '../cards/cards_screen.dart';
import '../debt/debt_screen.dart';
import '../goals/goals_screen.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../launcher/orb_launcher.dart';
import '../launcher/radial_orbit_overlay.dart';
import '../ledger/ledger_screen.dart';
import '../lock/lock_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/settings_screen.dart';
import '../split/split_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../tools/tools_screen.dart';
import 'app_module.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  AppModule _module = AppModule.home;
  bool _launcherOpen = false;
  bool _radialOpen = false;
  Offset? _radialPointer;
  final _radialKey = GlobalKey<RadialOrbitOverlayState>();
  bool _showOnboarding = false;
  bool _transitionReverse = false;
  DateTime? _pausedAt;

  late final AnimationController _fabPulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showOnboarding = !ref.read(settingsProvider).onboardingSeen;
    _fabPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sec = ref.read(securityProvider);
    final secNotifier = ref.read(securityProvider.notifier);

    if (state == AppLifecycleState.paused) {
      if (!sec.isAuthenticatingBiometrics) {
        _pausedAt = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      final pausedTime = _pausedAt;
      _pausedAt = null;
      ref.read(smsReviewProvider.notifier).refresh();

      // Do not re-lock if biometrics are in progress or completed just now
      if (sec.isAuthenticatingBiometrics ||
          secNotifier.wasRecentlyAuthenticated) {
        return;
      }

      // Only lock if app was truly backgrounded for more than a transient dialog duration
      if (pausedTime != null && sec.isLockEnabled) {
        if (DateTime.now().difference(pausedTime).inMilliseconds > 800) {
          secNotifier.lock();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabPulse.dispose();
    super.dispose();
  }

  void _go(AppModule module) {
    if (_module == module && !_launcherOpen && !_radialOpen) return;
    Haptics.light();
    setState(() {
      _transitionReverse = module.index < _module.index;
      _module = module;
      _launcherOpen = false;
      _radialOpen = false;
    });
  }

  void _toggleLauncher() {
    Haptics.medium();
    setState(() {
      _launcherOpen = !_launcherOpen;
      _radialOpen = false;
    });
  }

  Widget _screenFor(AppModule module) {
    return switch (module) {
      AppModule.home => HomeScreen(onNavigate: _go),
      AppModule.ledger => const LedgerScreen(),
      AppModule.accounts => const AccountsScreen(),
      AppModule.cards => const CardsScreen(),
      AppModule.budgets => const BudgetsScreen(),
      AppModule.subscriptions => const SubscriptionsScreen(),
      AppModule.debt => const DebtScreen(),
      AppModule.split => const SplitScreen(),
      AppModule.goals => const GoalsScreen(),
      AppModule.calendar => const CalendarScreen(),
      AppModule.insights => InsightsScreen(onNavigate: _go),
      AppModule.tools => ToolsScreen(onNavigate: _go),
      AppModule.settings => SettingsScreen(
        onLock: () => ref.read(securityProvider.notifier).lock(),
        onReset: () => _go(AppModule.home),
        onReplayWelcome: () => setState(() => _showOnboarding = true),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final c = context.spend;
    final overlayStyle = settings.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: AtmosphereBackground(
                tint: _module.atmosphereTint,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: PageTransitionSwitcher(
                duration: const Duration(milliseconds: 420),
                reverse: _transitionReverse,
                layoutBuilder: (entries) => Stack(
                  fit: StackFit.expand,
                  children: entries,
                ),
                transitionBuilder:
                    (child, primaryAnimation, secondaryAnimation) {
                      return SharedAxisTransition(
                        animation: primaryAnimation,
                        secondaryAnimation: secondaryAnimation,
                        transitionType: SharedAxisTransitionType.horizontal,
                        fillColor: Colors.transparent,
                        child: child,
                      );
                    },
                child: KeyedSubtree(
                  key: ValueKey(_module),
                  child: RepaintBoundary(
                    child: KeyedSubtree(
                      key: ValueKey(
                        '${settings.font.name}_${settings.theme.name}',
                      ),
                      child: _screenFor(_module),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.bg.withValues(alpha: 0),
                        c.bg.withValues(alpha: 0.92),
                      ],
                      stops: const [0, 0.8],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                reverseDuration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previous.map((w) => IgnorePointer(child: w)),
                    ?current,
                  ],
                ),
                child: _launcherOpen
                    ? OrbLauncher(
                        key: const ValueKey('orb_launcher'),
                        current: _module,
                        onNavigate: _go,
                        onClose: _toggleLauncher,
                      )
                    : const IgnorePointer(
                        key: ValueKey('no_launcher'),
                        child: SizedBox.shrink(),
                      ),
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                reverseDuration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previous.map((w) => IgnorePointer(child: w)),
                    ?current,
                  ],
                ),
                child: _radialOpen
                    ? RadialOrbitOverlay(
                        key: _radialKey,
                        current: _module,
                        fabBottom: _fabBottom(context),
                        initialPointer: _radialPointer,
                        onNavigate: (module) {
                          _go(module);
                        },
                        onClose: () => setState(() => _radialOpen = false),
                      )
                    : const IgnorePointer(
                        key: ValueKey('no_radial'),
                        child: SizedBox.shrink(),
                      ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _fabBottom(context),
              child: Center(
                child: _OrbFab(
                  module: _module,
                  open: _launcherOpen,
                  radialOpen: _radialOpen,
                  pulse: _fabPulse,
                  onTap: _toggleLauncher,
                  onRadialOpen: (pos) {
                    setState(() {
                      _radialOpen = true;
                      _radialPointer = pos;
                      _launcherOpen = false;
                    });
                  },
                  onRadialDrag: (pos) {
                    _radialKey.currentState?.updatePointer(pos);
                  },
                  onRadialEnd: (pos) {
                    _radialKey.currentState?.handlePointerUp(pos);
                  },
                ),
              ),
            ),
            Positioned(
              top: 56,
              left: 20,
              right: 20,
              child: const _ToastOverlay(),
            ),
            if (ref.watch(securityProvider).isLocked)
              Positioned.fill(
                child: LockScreen(
                  onUnlocked: () => ref.read(securityProvider.notifier).unlock(),
                ),
              ),
            if (_showOnboarding)
              OnboardingOverlay(
                onDone: () {
                  setState(() => _showOnboarding = false);
                  _go(AppModule.home);
                },
              ),
          ],
        ),
      ),
    );
  }

  double _fabBottom(BuildContext context) =>
      math.max(30, MediaQuery.paddingOf(context).bottom);
}

class _OrbFab extends StatefulWidget {
  const _OrbFab({
    required this.module,
    required this.open,
    required this.radialOpen,
    required this.pulse,
    required this.onTap,
    required this.onRadialOpen,
    required this.onRadialDrag,
    required this.onRadialEnd,
  });

  final AppModule module;
  final bool open;
  final bool radialOpen;
  final Animation<double> pulse;
  final VoidCallback onTap;
  final ValueChanged<Offset> onRadialOpen;
  final ValueChanged<Offset> onRadialDrag;
  final ValueChanged<Offset> onRadialEnd;

  @override
  State<_OrbFab> createState() => _OrbFabState();
}

class _OrbFabState extends State<_OrbFab>
    with SingleTickerProviderStateMixin {
  Timer? _holdTimer;
  bool _isHolding = false;
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.open) return;
    _isHolding = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 300), () {
      _isHolding = true;
      Haptics.medium();
      widget.onRadialOpen(event.position);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isHolding) {
      widget.onRadialDrag(event.position);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _holdTimer?.cancel();
    if (_isHolding) {
      _isHolding = false;
      widget.onRadialEnd(event.position);
    } else {
      widget.onTap();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _holdTimer?.cancel();
    if (_isHolding) {
      _isHolding = false;
      widget.onRadialEnd(event.position);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.pulse, _orbit]),
        builder: (context, _) {
          final t = Curves.easeInOut.transform(widget.pulse.value);
          final open = widget.open || widget.radialOpen;
          final glass = Color.lerp(
            c.c2,
            c.ac,
            c.dark ? 0.055 : 0.04,
          )!;
          final rim = Color.lerp(
            c.ac,
            Colors.white,
            c.dark ? 0.18 : 0.45,
          )!.withValues(alpha: open ? 0.62 : 0.38);
          final scale = widget.open
              ? 0.88
              : (widget.radialOpen ? 0.90 : 1.0);
          return AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 400),
            curve: const Cubic(0.3, 1.5, 0.5, 1),
            child: SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: _orbit.value * math.pi * 2,
                    child: CustomPaint(
                      size: const Size.square(80),
                      painter: _OrbHaloPainter(
                        accent: c.ac,
                        active: open,
                      ),
                    ),
                  ),
                  Container(
                    width: 62,
                    height: 62,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: rim, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: c.dark ? 0.55 : 0.18,
                          ),
                          blurRadius: 24,
                          spreadRadius: -2,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: c.ac.withValues(alpha: 0.03 + 0.015 * t),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(
                                alpha: c.dark ? 0.07 : 0.5,
                              ),
                              glass.withValues(alpha: c.dark ? 0.58 : 0.38),
                              Colors.black.withValues(
                                alpha: c.dark ? 0.3 : 0.06,
                              ),
                            ],
                            stops: const [0, 0.46, 1],
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  radius: 0.94,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(
                                      alpha: c.dark ? 0.24 : 0.08,
                                    ),
                                  ],
                                  stops: const [0.55, 1],
                                ),
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0, 0.95),
                                  radius: 0.7,
                                  colors: [
                                    c.ac.withValues(alpha: 0.075),
                                    c.ac.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(
                                      alpha: c.dark ? 0.18 : 0.05,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              left: 4,
                              right: 20,
                              height: 20,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.3, -0.6),
                                    radius: 0.8,
                                    colors: [
                                      Colors.white.withValues(
                                        alpha: c.dark ? 0.1 : 0.25,
                                      ),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 9,
                              left: 13,
                              child: Transform.rotate(
                                angle: -0.35,
                                child: Container(
                                  width: 19,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: c.dark ? 0.28 : 0.55,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) =>
                                    RotationTransition(
                                      turns: Tween<double>(
                                        begin: 0.8,
                                        end: 1,
                                      ).animate(animation),
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    ),
                                child: open
                                    ? Transform.rotate(
                                        key: const ValueKey('close'),
                                        angle: math.pi / 4,
                                        child: SpendIcon(
                                          'close',
                                          size: 26,
                                          color: c.tx,
                                          strokeWidth: 1.8,
                                        ),
                                      )
                                    : SpendIcon(
                                        widget.module.icon,
                                        key: ValueKey(widget.module),
                                        size: 26,
                                        color: c.tx,
                                        strokeWidth: 1.7,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrbHaloPainter extends CustomPainter {
  const _OrbHaloPainter({required this.accent, required this.active});

  final Color accent;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = accent.withValues(alpha: active ? 0.09 : 0.045),
    );

    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: active ? 0.12 : 0.06),
          accent.withValues(alpha: active ? 0.42 : 0.2),
          accent.withValues(alpha: 0),
        ],
        stops: const [0, 0.28, 0.64, 1],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.32, false, sweep);

    final endAngle = -math.pi / 2 + math.pi * 1.32;
    canvas.drawCircle(
      center +
          Offset(
            math.cos(endAngle) * radius,
            math.sin(endAngle) * radius,
          ),
      1,
      Paint()..color = accent.withValues(alpha: active ? 0.45 : 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbHaloPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.active != active;
}

class _ToastOverlay extends ConsumerWidget {
  const _ToastOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toast = ref.watch(toastProvider);
    final c = context.spend;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: const Cubic(0.3, 1.4, 0.4, 1),
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1.6),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: toast == null
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : Center(
              key: ValueKey(toast.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.tx,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        toast.text,
                        maxLines: 2,
                        style: AppTypography.sans(size: 13, color: c.bg),
                      ),
                    ),
                    if (toast.onUndo != null) ...[
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: () {
                          toast.onUndo!.call();
                          ref.read(toastProvider.notifier).hide();
                        },
                        child: Text(
                          toast.undoLabel ?? 'Undo',
                          style: AppTypography.sans(
                            size: 13,
                            color: c.bg,
                            weight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
