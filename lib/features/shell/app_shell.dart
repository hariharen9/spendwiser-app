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
import '../../data/models/app_settings.dart';
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

const _swipeCycle = <AppModule>[
  AppModule.home,
  AppModule.ledger,
  AppModule.cards,
  AppModule.debt,
  AppModule.settings,
];

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
  final List<AppModule> _history = <AppModule>[];
  int _cycleCursor = 0;
  double _swipeDx = 0;
  final ValueNotifier<double> _swipeProgress = ValueNotifier<double>(0);
  final ValueNotifier<AppModule?> _swipeTarget = ValueNotifier<AppModule?>(
    null,
  );

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
    _swipeProgress.dispose();
    _swipeTarget.dispose();
    super.dispose();
  }

  bool get _canSwipe =>
      !_launcherOpen &&
      !_radialOpen &&
      !_showOnboarding &&
      !ref.read(securityProvider).isLocked;

  void _go(AppModule module, {bool? reverse}) {
    final same = _module == module;
    if (same && !_launcherOpen && !_radialOpen) return;
    Haptics.light();
    if (!same) {
      _history.add(_module);
      if (_history.length > 24) _history.removeAt(0);
    }
    final cycleIndex = _swipeCycle.indexOf(module);
    if (cycleIndex >= 0) _cycleCursor = cycleIndex;
    setState(() {
      _transitionReverse = reverse ?? module.index < _module.index;
      _module = module;
      _launcherOpen = false;
      _radialOpen = false;
    });
  }

  void _handleBack() {
    if (_showOnboarding || ref.read(securityProvider).isLocked) return;
    if (_launcherOpen) {
      setState(() => _launcherOpen = false);
      return;
    }
    if (_radialOpen) {
      setState(() => _radialOpen = false);
      return;
    }
    if (_swipeProgress.value > 0) {
      _resetSwipe();
      return;
    }
    if (_history.isNotEmpty) {
      final previous = _history.removeLast();
      final cycleIndex = _swipeCycle.indexOf(previous);
      if (cycleIndex >= 0) _cycleCursor = cycleIndex;
      Haptics.light();
      setState(() {
        _transitionReverse = true;
        _module = previous;
        _launcherOpen = false;
        _radialOpen = false;
      });
      return;
    }
    if (_module != AppModule.home) {
      _cycleCursor = 0;
      Haptics.light();
      setState(() {
        _transitionReverse = true;
        _module = AppModule.home;
        _launcherOpen = false;
        _radialOpen = false;
      });
      return;
    }
    SystemNavigator.pop();
  }

  void _onSwipeStart(DragStartDetails details) {
    if (!_canSwipe) return;
    _swipeDx = 0;
    _swipeProgress.value = 0;
    _swipeTarget.value = null;
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    if (!_canSwipe) return;
    _swipeDx += details.delta.dx;
    final target = _swipeTargetFor(_swipeDx);
    if (target != _swipeTarget.value) {
      _swipeTarget.value = target;
      if (target != null) Haptics.light();
    }
    _swipeProgress.value = (_swipeDx.abs() / 140).clamp(0, 1);
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (!_canSwipe) {
      _resetSwipe();
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final enough = _swipeDx.abs() > 58 || velocity.abs() > 500;
    if (!enough) {
      _resetSwipe();
      return;
    }
    final forward = velocity.abs() > 420 ? velocity < 0 : _swipeDx < 0;
    final index =
        (_cycleCursor + (forward ? 1 : -1) + _swipeCycle.length) %
        _swipeCycle.length;
    final target = _swipeCycle[index];
    Haptics.medium();
    _resetSwipe();
    _go(target, reverse: !forward);
  }

  AppModule? _swipeTargetFor(double dx) {
    if (dx.abs() < 8) return null;
    final direction = dx < 0 ? 1 : -1;
    final index =
        (_cycleCursor + direction + _swipeCycle.length) % _swipeCycle.length;
    return _swipeCycle[index];
  }

  void _resetSwipe() {
    _swipeDx = 0;
    _swipeProgress.value = 0;
    _swipeTarget.value = null;
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
    final navMode = settings.navigation == AppNavigationMode.navbar;
    final overlayStyle = settings.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _onSwipeStart,
                  onHorizontalDragUpdate: _onSwipeUpdate,
                  onHorizontalDragEnd: _onSwipeEnd,
                  onHorizontalDragCancel: _resetSwipe,
                  child: PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 460),
                    reverse: _transitionReverse,
                    layoutBuilder: (entries) =>
                        Stack(fit: StackFit.expand, children: entries),
                    transitionBuilder:
                        (child, primaryAnimation, secondaryAnimation) {
                          final scale = Tween<double>(begin: 0.985, end: 1)
                              .animate(
                                CurvedAnimation(
                                  parent: primaryAnimation,
                                  curve: Curves.easeOutCubic,
                                  reverseCurve: Curves.easeInCubic,
                                ),
                              );
                          return SharedAxisTransition(
                            animation: primaryAnimation,
                            secondaryAnimation: secondaryAnimation,
                            transitionType: SharedAxisTransitionType.horizontal,
                            fillColor: Colors.transparent,
                            child: ScaleTransition(scale: scale, child: child),
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
              Positioned(
                left: 0,
                right: 0,
                bottom: navMode
                    ? math.max(8, MediaQuery.paddingOf(context).bottom) + 82
                    : math.max(4, MediaQuery.paddingOf(context).bottom),
                child: _SwipeEdgeFeedback(
                  progress: _swipeProgress,
                  target: _swipeTarget,
                  current: _module,
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
              if (!navMode)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _fabBottom(context) + 88,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<AppModule?>(
                      valueListenable: _swipeTarget,
                      builder: (context, target, _) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: target == null
                            ? const SizedBox.shrink(key: ValueKey('no-target'))
                            : Center(
                                key: ValueKey(target),
                                child: _SwipeTargetPill(module: target),
                              ),
                      ),
                    ),
                  ),
                ),
              if (!navMode)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _fabBottom(context),
                  child: Center(
                    child: ValueListenableBuilder<AppModule?>(
                      valueListenable: _swipeTarget,
                      builder: (context, target, _) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _swipeProgress,
                          builder: (context, progress, _) {
                            return _OrbFab(
                              module: target ?? _module,
                              swipeProgress: progress,
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
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              if (navMode)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: math.max(8, MediaQuery.paddingOf(context).bottom),
                  child: _BottomNavBar(
                    current: _module,
                    left: settings.navbarLeft,
                    right: settings.navbarRight,
                    allOpen: _launcherOpen,
                    onNavigate: (module) => _go(module),
                    onAllApps: _toggleLauncher,
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
                    onUnlocked: () =>
                        ref.read(securityProvider.notifier).unlock(),
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
      ),
    );
  }

  double _fabBottom(BuildContext context) =>
      math.max(30, MediaQuery.paddingOf(context).bottom);
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.current,
    required this.left,
    required this.right,
    required this.allOpen,
    required this.onNavigate,
    required this.onAllApps,
  });

  final AppModule current;
  final List<AppModule> left;
  final List<AppModule> right;
  final bool allOpen;
  final ValueChanged<AppModule> onNavigate;
  final VoidCallback onAllApps;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final totalItems = left.length + 1 + right.length;
    final compact = totalItems > 5;
    final selectedIndex = allOpen ? null : _selectionIndex(current);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    c.c1,
                    Colors.white,
                    c.dark ? 0.07 : 0.55,
                  )!.withValues(alpha: c.dark ? 0.6 : 0.72),
                  c.c1.withValues(alpha: c.dark ? 0.52 : 0.6),
                ],
              ),
              border: Border.all(color: c.ln),
              borderRadius: BorderRadius.circular(26),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / totalItems;
                return Stack(
                  children: [
                    if (selectedIndex != null)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                        left: selectedIndex * itemWidth + (compact ? 2 : 3),
                        top: 7,
                        width: itemWidth - (compact ? 4 : 6),
                        height: 58,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                c.ac.withValues(alpha: 0.12),
                                c.ac2.withValues(alpha: 0.055),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: c.ac.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        for (final module in left)
                          _NavBarItem(
                            icon: module.icon,
                            label: module.label,
                            compact: compact,
                            selected: current == module,
                            onTap: () => onNavigate(module),
                          ),
                        _AllAppsNavItem(
                          open: allOpen,
                          compact: compact,
                          onTap: onAllApps,
                        ),
                        for (final module in right)
                          _NavBarItem(
                            icon: module.icon,
                            label: module.label,
                            compact: compact,
                            selected: current == module,
                            onTap: () => onNavigate(module),
                          ),
                      ],
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 0,
                      height: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(
                                alpha: c.dark ? 0.16 : 0.5,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  int? _selectionIndex(AppModule module) {
    final leftIndex = left.indexOf(module);
    if (leftIndex >= 0) return leftIndex;
    final rightIndex = right.indexOf(module);
    if (rightIndex >= 0) return left.length + 1 + rightIndex;
    return null;
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpendIcon(
                icon,
                size: compact ? 19 : 21,
                color: selected ? c.ac : c.mu,
                strokeWidth: selected ? 1.9 : 1.65,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sans(
                  size: compact ? 8.5 : 9,
                  color: selected ? c.tx : c.mu,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 14 : 4,
                height: 2,
                decoration: BoxDecoration(
                  gradient: selected ? c.accentGradient : null,
                  color: selected ? null : c.ln,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllAppsNavItem extends StatelessWidget {
  const _AllAppsNavItem({
    required this.open,
    required this.onTap,
    this.compact = false,
  });

  final bool open;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final orbSize = compact ? 38.0 : 42.0;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        scale: 0.93,
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: orbSize,
                height: orbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: c.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: c.ac.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: -2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: SpendIcon(
                  open ? 'closeSmall' : 'grid',
                  size: 19,
                  color: c.aci,
                  strokeWidth: 1.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                open ? 'Close' : 'Apps',
                style: AppTypography.sans(
                  size: 9,
                  color: open ? c.tx : c.mu,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeEdgeFeedback extends StatelessWidget {
  const _SwipeEdgeFeedback({
    required this.progress,
    required this.target,
    required this.current,
  });

  final ValueNotifier<double> progress;
  final ValueNotifier<AppModule?> target;
  final AppModule current;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, value, _) {
          if (value <= 0.01) return const SizedBox.shrink();
          return ValueListenableBuilder<AppModule?>(
            valueListenable: target,
            builder: (context, next, _) {
              final accent = next?.tint ?? c.ac;
              final secondary = next == null
                  ? c.ac2
                  : Color.lerp(next.tint, Colors.white, 0.25)!;
              return Opacity(
                opacity: Curves.easeOut.transform(value.clamp(0.0, 1.0)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 1.5,
                      margin: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0),
                            accent.withValues(alpha: 0.75),
                            secondary.withValues(alpha: 0.64),
                            accent.withValues(alpha: 0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final module in _swipeCycle)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: module == next ? 18 : 10,
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: module == current
                                  ? c.tx
                                  : module == next
                                  ? accent
                                  : c.mu.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SwipeTargetPill extends StatelessWidget {
  const _SwipeTargetPill({required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.c1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: module.tint.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: module.tint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            module.label,
            style: AppTypography.sans(
              size: 10,
              color: c.tx,
              weight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbFab extends StatefulWidget {
  const _OrbFab({
    required this.module,
    required this.swipeProgress,
    required this.open,
    required this.radialOpen,
    required this.pulse,
    required this.onTap,
    required this.onRadialOpen,
    required this.onRadialDrag,
    required this.onRadialEnd,
  });

  final AppModule module;
  final double swipeProgress;
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
          final open = widget.open || widget.radialOpen;
          final scale = widget.open ? 0.88 : (widget.radialOpen ? 0.90 : 1.0);
          final swipe = widget.swipeProgress.clamp(0.0, 1.0);
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
                  if (swipe > 0.01)
                    CustomPaint(
                      size: const Size.square(80),
                      painter: _SwipeArcPainter(
                        progress: swipe,
                        color: widget.module.tint,
                        color2: Color.lerp(
                          widget.module.tint,
                          Colors.white,
                          0.25,
                        )!,
                      ),
                    ),
                  Container(
                    width: 62,
                    height: 62,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(c.c2, Colors.white, c.dark ? 0.07 : 0.4)!,
                          c.c1,
                          Color.lerp(c.bg, Colors.black, c.dark ? 0.24 : 0.04)!,
                        ],
                        stops: const [0, 0.5, 1],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: c.dark ? 0.1 : 0.4,
                        ),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: c.dark ? 0.46 : 0.14,
                          ),
                          blurRadius: 18,
                          spreadRadius: -3,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: c.ac.withValues(alpha: 0.025 + 0.012 * t),
                          blurRadius: 20,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _PuckRimPainter(
                              accent: c.ac,
                              accent2: c.ac2,
                              active: open,
                              breath: t,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 16,
                          child: Transform.rotate(
                            angle: -0.4,
                            child: Container(
                              width: 13,
                              height: 2.4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: c.dark ? 0.22 : 0.5,
                                ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            transitionBuilder: (child, animation) =>
                                RotationTransition(
                                  turns: Tween<double>(
                                    begin: 0.92,
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
                                      size: 23,
                                      color: c.tx,
                                      strokeWidth: 1.6,
                                    ),
                                  )
                                : SpendIcon(
                                    widget.module.icon,
                                    key: ValueKey(widget.module),
                                    size: 23,
                                    color: c.tx,
                                    strokeWidth: 1.6,
                                  ),
                          ),
                        ),
                      ],
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

class _PuckRimPainter extends CustomPainter {
  const _PuckRimPainter({
    required this.accent,
    required this.accent2,
    required this.active,
    required this.breath,
  });

  final Color accent;
  final Color accent2;
  final bool active;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.3;
    final rect = Rect.fromCircle(center: center, radius: radius - 0.2);
    final rimAlpha = active ? 0.82 : 0.42 + 0.12 * breath;
    final rimShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accent.withValues(alpha: rimAlpha),
        accent2.withValues(alpha: rimAlpha),
      ],
    ).createShader(rect);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.055),
    );

    if (active) {
      final activeShader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.28),
          accent2.withValues(alpha: 0.28),
        ],
      ).createShader(rect);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..shader = activeShader,
      );
    }

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..shader = rimShader;
    canvas.drawArc(rect, math.pi * 0.16, math.pi * 0.68, false, rim);
  }

  @override
  bool shouldRepaint(covariant _PuckRimPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.accent2 != accent2 ||
      oldDelegate.active != active ||
      oldDelegate.breath != breath;
}

class _SwipeArcPainter extends CustomPainter {
  const _SwipeArcPainter({
    required this.progress,
    required this.color,
    required this.color2,
  });

  final double progress;
  final Color color;
  final Color color2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.78), color2.withValues(alpha: 0.9)],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, paint);

    final end = -math.pi / 2 + math.pi * 2 * progress;
    canvas.drawCircle(
      center + Offset(math.cos(end) * radius, math.sin(end) * radius),
      1.8,
      Paint()..color = color2,
    );
  }

  @override
  bool shouldRepaint(covariant _SwipeArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.color2 != color2;
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
