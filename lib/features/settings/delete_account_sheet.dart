import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth_provider.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/field_label.dart';
import '../../data/persistence/pin_vault.dart';
import '../../data/sms/sms_inbox.dart';

Future<void> showDeleteAccountSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _DeleteAccountSheet());
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirm.text.trim().toUpperCase() != 'DELETE') {
      setState(() => _error = 'Type DELETE to confirm.');
      return;
    }
    final isGoogle =
        ref
            .read(authStateProvider)
            .value
            ?.providerData
            .any((provider) => provider.providerId == 'google.com') ??
        false;
    if (!isGoogle && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.reauthenticate(password: isGoogle ? null : _password.text);
      await ref.read(financeRepositoryProvider).deleteAccountData();
      await SmsInbox.clear();
      await PinVault.clearPin();
      await auth.deleteUser();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = authErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final isGoogle =
        ref
            .watch(authStateProvider)
            .value
            ?.providerData
            .any((provider) => provider.providerId == 'google.com') ??
        false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Delete account', subtitle: 'This cannot be undone.'),
        const SizedBox(height: 8),
        Text(
          'This permanently deletes your Spendwiser account, every transaction, '
          'account, card, budget, goal, loan, split, shortcut and pending SMS. '
          'The local SMS queue and app PIN are cleared too.',
          style: AppTypography.sans(size: 14, color: c.mu),
        ),
        const SizedBox(height: 14),
        if (!isGoogle)
          LabeledField(
            label: 'Password',
            child: _Field(
              controller: _password,
              hint: 'Password',
              obscure: true,
            ),
          )
        else
          Text(
            'You will be asked to confirm with Google.',
            style: AppTypography.sans(size: 13, color: c.mu),
          ),
        const SizedBox(height: 8),
        LabeledField(
          label: 'Confirmation',
          child: _Field(controller: _confirm, hint: 'Type DELETE to confirm'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: AppTypography.sans(size: 13, color: c.co)),
        ],
        const SizedBox(height: 10),
        AppButton(
          label: _busy ? 'Deleting…' : 'Delete everything',
          color: c.co,
          centered: true,
          onTap: _busy ? null : _delete,
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: !obscure,
        textAlignVertical: TextAlignVertical.center,
        style: AppTypography.sans(size: 13, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.sans(size: 13, color: c.mu),
        ),
      ),
    );
  }
}
