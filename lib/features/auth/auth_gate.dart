import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth_provider.dart';
import '../../core/state/providers.dart';
import '../../core/widgets/brand_splash.dart';
import '../shell/app_shell.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late final Future<void> _minimumSplash;

  @override
  void initState() {
    super.initState();
    _minimumSplash = Future<void>.delayed(
      const Duration(milliseconds: 850),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    return FutureBuilder<void>(
      future: _minimumSplash,
      builder: (context, splash) {
        final waiting =
            splash.connectionState != ConnectionState.done || auth.isLoading;

        final Widget child;
        if (waiting) {
          child = const BrandSplash(key: ValueKey('splash'));
        } else if (auth.hasError) {
          child = BrandSplash(
            key: const ValueKey('splash-error'),
            still: true,
            message: '${auth.error}',
          );
        } else {
          final user = auth.value;
          child = user == null
              ? const LoginScreen(key: ValueKey('login'))
              : _SignedIn(key: ValueKey(user.uid), user: user);
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 460),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(fade),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

class _SignedIn extends ConsumerStatefulWidget {
  const _SignedIn({super.key, required this.user});

  final User user;

  @override
  ConsumerState<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends ConsumerState<_SignedIn> {
  late Future<void> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _run();
  }

  Future<void> _run() async {
    final profile = ref.read(userProfileRepositoryProvider);
    if (profile == null) return;
    await profile.ensureProfile(
      email: widget.user.email,
      displayName: widget.user.displayName,
    );
    await profile.loadOnce();
    final store = ref.read(firestoreFinanceStoreProvider);
    if (store != null) await store.ready;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootScreen();
        }
        if (snapshot.hasError) {
          return _BootScreen(message: '${snapshot.error}');
        }
        return const AppShell();
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return BrandSplash(still: true, message: message);
  }
}
