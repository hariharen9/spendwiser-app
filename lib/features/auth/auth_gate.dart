import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth_provider.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/atmosphere_background.dart';
import '../shell/app_shell.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading) return const _BootScreen();
    if (auth.hasError) {
      return _BootScreen(message: '${auth.error}');
    }
    final user = auth.value;
    if (user == null) return const LoginScreen();
    return _SignedIn(key: ValueKey(user.uid), user: user);
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
    final c = context.spend;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AtmosphereBackground(
        tint: AppColors.moduleTint['home']!,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.ac,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: SpendIcon('sparkle', size: 26, color: c.aci),
              ),
              const SizedBox(height: 18),
              Text(
                'Spendwiser',
                style: AppTypography.serif(size: 30, color: c.tx),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.ac,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(size: 12, color: c.co),
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
