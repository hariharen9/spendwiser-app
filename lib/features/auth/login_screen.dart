import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/atmosphere_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/segmented_control.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  var _register = false;
  var _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final service = ref.read(authServiceProvider);
      if (_register) {
        await service.register(
          email: email,
          password: password,
          name: _name.text,
        );
      } else {
        await service.signIn(email: email, password: password);
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) {
        setState(() => _info = 'Password reset email sent to $email.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AtmosphereBackground(
        tint: AppColors.moduleTint['home']!,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.ac,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: SpendIcon('sparkle', size: 20, color: c.aci),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Spendwiser',
                          style: AppTypography.serif(size: 30, color: c.tx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _register ? 'Create your account' : 'Welcome back',
                      style: AppTypography.serif(size: 40, color: c.tx),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The same account, ledger and budgets as the web app.',
                      style: AppTypography.sans(size: 14, color: c.mu),
                    ),
                    const SizedBox(height: 22),
                    SegmentedControl<bool>(
                      margin: EdgeInsets.zero,
                      options: const [
                        SegmentedOption(false, 'Sign in'),
                        SegmentedOption(true, 'Create account'),
                      ],
                      selected: _register,
                      onChanged: (value) => setState(() {
                        _register = value;
                        _error = null;
                        _info = null;
                      }),
                    ),
                    const SizedBox(height: 18),
                    if (_register) ...[
                      _AuthField(controller: _name, hint: 'Name'),
                      const SizedBox(height: 10),
                    ],
                    _AuthField(
                      controller: _email,
                      hint: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _AuthField(
                      controller: _password,
                      hint: 'Password',
                      obscure: true,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: AppTypography.sans(size: 13, color: c.co),
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _info!,
                        style: AppTypography.sans(size: 13, color: c.ac),
                      ),
                    ],
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: _busy
                          ? 'Please wait…'
                          : (_register ? 'Create account' : 'Sign in'),
                      onTap: _busy ? null : _submit,
                    ),
                    if (!_register)
                      Pressable(
                        onTap: _busy ? null : _resetPassword,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Forgot password?',
                            textAlign: TextAlign.center,
                            style: AppTypography.sans(
                              size: 13,
                              color: c.mu,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: c.ln)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: AppTypography.sans(size: 12, color: c.mu),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: c.ln)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: 'Continue with Google',
                      margin: EdgeInsets.zero,
                      centered: true,
                      onTap: _busy ? null : _google,
                      leading: Text(
                        'G',
                        style: AppTypography.sans(
                          size: 16,
                          color: c.tx,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Spendwiser never sees your password.',
                      textAlign: TextAlign.center,
                      style: AppTypography.sans(size: 11, color: c.mu),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.ln),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: !obscure,
        style: AppTypography.sans(size: 14, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.sans(size: 14, color: c.mu),
        ),
      ),
    );
  }
}
