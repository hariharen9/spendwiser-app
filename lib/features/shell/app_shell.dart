import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
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
    with TickerProviderStateMixin {
  AppModule _module = AppModule.home;
  bool _launcherOpen = false;
  bool _radialOpen = false;
  Offset? _radialPointer;
  final _radialKey = GlobalKey<RadialOrbitOverlayState>();
  bool _locked = false;
  bool _showOnboarding = false;
  bool _hintVisible = false;
  bool _hintShown = false;

  late final AnimationController _fabPulse;
  late final AnimationController _hintFade;
  Timer? _hintShowTimer;
  Timer? _hintHideTimer;

  @override
  void initState() {
    super.initState();
    _showOnboarding = !ref.read(settingsProvider).onboardingSeen;
    _fabPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _hintFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _hintShowTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted || _hintShown) return;
      _hintShown = true;
      setState(() => _hintVisible = true);
      _hintFade.forward();
      _hintHideTimer = Timer(const Duration(milliseconds: 5200), () {
        if (!mounted) return;
        setState(() => _hintVisible = false);
      });
    });
  }

  @override
  void dispose() {
    _hintShowTimer?.cancel();
    _hintHideTimer?.cancel();
    _fabPulse.dispose();
    _hintFade.dispose();
    super.dispose();
  }

  void _go(AppModule module) {
    if (_module == module && !_launcherOpen && !_radialOpen) return;
    Haptics.light();
    setState(() {
      _module = module;
      _launcherOpen = false;
      _radialOpen = false;
      _hintVisible = false;
    });
  }

  void _toggleLauncher() {
    Haptics.medium();
    setState(() {
      _launcherOpen = !_launcherOpen;
      _radialOpen = false;
      _hintVisible = false;
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
        onLock: () => setState(() => _locked = true),
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 650),
                reverseDuration: const Duration(milliseconds: 300),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, animation) {
                  return _SpendwiserPageTransition(
                    animation: animation,
                    child: child,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_module),
                  child: _screenFor(_module),
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
            if (_hintVisible && !_launcherOpen && !_radialOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: _fabBottom(context) + 76,
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: _hintFade,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.tx,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Tap for all modules · hold and slide to jump',
                          style: AppTypography.sans(size: 12, color: c.bg),
                        ),
                      ),
                    ),
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
                      _hintVisible = false;
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
            if (_locked)
              Positioned.fill(
                child: LockScreen(
                  onUnlocked: () => setState(() => _locked = false),
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

class _OrbFabState extends State<_OrbFab> {
  Timer? _holdTimer;
  bool _isHolding = false;

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
        animation: widget.pulse,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(widget.pulse.value);
          final scale = widget.open
              ? 0.88
              : (widget.radialOpen ? 0.90 : 1.0);
          return AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 400),
            curve: const Cubic(0.3, 1.5, 0.5, 1),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: c.ac,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.ac.withValues(alpha: 0.16 - 0.08 * t),
                    blurRadius: 0,
                    spreadRadius: 7 + 7 * t,
                  ),
                  BoxShadow(
                    color: c.ac.withValues(alpha: 0.40 + 0.15 * t),
                    blurRadius: 40 + 14 * t,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween<double>(begin: 0.8, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: widget.open || widget.radialOpen
                    ? Transform.rotate(
                        key: const ValueKey('close'),
                        angle: math.pi / 4,
                        child: SpendIcon(
                          'close',
                          size: 26,
                          color: c.aci,
                          strokeWidth: 1.8,
                        ),
                      )
                    : SpendIcon(
                        widget.module.icon,
                        key: ValueKey(widget.module),
                        size: 26,
                        color: c.aci,
                        strokeWidth: 1.7,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpendwiserPageTransition extends StatelessWidget {
  const _SpendwiserPageTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (animation.status == AnimationStatus.completed) {
          return child;
        }

        final isIncoming = animation.status == AnimationStatus.forward;

        if (isIncoming) {
          final t = animation.value.clamp(0.0, 1.0);
          // Prototype spec: rise .7s cubic-bezier(.2,.9,.2,1) both
          // from { opacity: 0; transform: translateY(24px) scale(.97); }
          const curve = Cubic(0.2, 0.9, 0.2, 1.0);
          final curved = curve.transform(t);

          // Progressive opacity fade: starts at 0, smoothly blooms to 1.0
          final opacity = Curves.easeOut.transform(t);

          // Smooth rise from 36px below
          final translateY = 36.0 * (1.0 - curved);

          // Subtle bloom scale from 0.965 to 1.0
          final scale = 0.965 + (0.035 * curved);

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          );
        } else {
          // Outgoing screen: gracefully dissolves in place without moving down
          final t = animation.value.clamp(0.0, 1.0);
          final opacity = Curves.easeInOut.transform(t);
          final scale = 0.985 + (0.015 * t);

          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        }
      },
    );
  }
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
