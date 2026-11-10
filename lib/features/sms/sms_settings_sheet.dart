import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/state/sms_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/section_caption.dart';
import '../../data/services/notifications_service.dart';
import '../../data/sms/sms_inbox.dart';
import 'sms_review_sheet.dart';

Future<void> showSmsSettingsSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _SmsSettingsSheet());
}

class _SmsSettingsSheet extends ConsumerStatefulWidget {
  const _SmsSettingsSheet();

  @override
  ConsumerState<_SmsSettingsSheet> createState() => _SmsSettingsSheetState();
}

class _SmsSettingsSheetState extends ConsumerState<_SmsSettingsSheet> {
  bool? _permission;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final granted = await SmsInbox.hasPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
  }

  Future<void> _enable() async {
    await _setEnabled(true);
  }

  Future<void> _setEnabled(bool enabled) async {
    if (!enabled) {
      await SmsInbox.setEnabled(false);
      ref.read(settingsProvider.notifier).patch(smsCaptureEnabled: false);
      if (!mounted) return;
      ref.read(toastProvider.notifier).show('Bank SMS capture off');
      return;
    }
    final granted = await SmsInbox.requestPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
    if (!granted) {
      ref
          .read(toastProvider.notifier)
          .show('SMS access was not granted. Enable it in Android settings.');
      return;
    }
    await SmsInbox.setEnabled(true);
    ref.read(settingsProvider.notifier).patch(smsCaptureEnabled: true);
    await ref.read(smsReviewProvider.notifier).refresh();
    if (!mounted) return;
    ref.read(toastProvider.notifier).show('Bank SMS capture on');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final settings = ref.watch(settingsProvider);
    final enabled = settings.smsCaptureEnabled;
    final pending = ref.watch(smsReviewProvider).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'SMS capture',
          subtitle: 'Bank messages are parsed on this phone, then reviewed.',
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank SMS capture',
                      style: AppTypography.sans(
                        size: 14,
                        color: c.tx,
                        weight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      enabled
                          ? 'New bank transaction messages are detected automatically.'
                          : 'Off. New messages are not captured; the existing queue is still available.',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
              AppToggle(value: enabled, onChanged: _setEnabled),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _permission == true
                          ? 'SMS permission granted'
                          : _permission == false
                          ? 'SMS permission required'
                          : 'Checking SMS permission…',
                      style: AppTypography.sans(
                        size: 14,
                        color: c.tx,
                        weight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Only bank transaction messages are stored.',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
              AppPill(
                label: _permission == true ? 'Granted' : 'Needed',
                active: _permission == true,
              ),
            ],
          ),
        ),
        if (_permission != true)
          PrimaryButton(label: 'Enable SMS access', onTap: _enable),
        PrimaryButton(
          label: pending == 0
              ? 'Open review queue'
              : 'Review $pending message${pending == 1 ? '' : 's'}',
          onTap: () => showSmsReviewSheet(context),
        ),
        AppButton(
          label: 'Paste a test message',
          centered: true,
          onTap: () => showSmsReviewSheet(context),
        ),
        AppButton(
          label: 'Send test notification',
          centered: true,
          onTap: () async {
            await NotificationsService.requestPermissions();
            final sent = await SmsInbox.notifyTest();
            if (!mounted) return;
            ref
                .read(toastProvider.notifier)
                .show(
                  sent
                      ? 'Test SMS notification sent'
                      : 'Enable notifications in Android settings',
                );
          },
        ),
        const SectionCaption('How it works'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bullet(
                context,
                'The app reads bank transaction SMS on this phone.',
              ),
              _bullet(
                context,
                'Nothing is uploaded. The raw message stays in app-private storage.',
              ),
              _bullet(
                context,
                'Review the parsed amount, merchant and account, then add it. Only then is a normal transaction written to Firestore.',
              ),
              _bullet(
                context,
                'The web listener app is separate. This app never reads its pending queue.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bullet(BuildContext context, String text) {
    final c = context.spend;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: c.ac, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTypography.sans(size: 12, color: c.mu)),
          ),
        ],
      ),
    );
  }
}
