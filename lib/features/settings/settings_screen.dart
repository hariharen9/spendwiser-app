import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

import '../../core/state/auth_provider.dart';
import '../../core/state/providers.dart';
import '../../core/state/sms_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_select.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/profile_avatar.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/persistence/pin_vault.dart';
import '../../data/services/notifications_service.dart';
import '../../data/sms/sms_inbox.dart';
import '../../data/services/backup_service.dart';
import '../home/customize_home_sheet.dart';
import '../shell/app_module.dart';
import '../sms/sms_settings_sheet.dart';
import 'delete_account_sheet.dart';
import 'shortcuts_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onLock,
    required this.onReset,
    required this.onReplayWelcome,
  });

  final VoidCallback onLock;
  final VoidCallback onReset;
  final VoidCallback onReplayWelcome;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _range = 'm';
  List<List<String>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final raw = Hive.box('settings').get('backupHistoryJson') as String?;
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as List;
          _history = decoded
              .map((e) => (e as List).map((v) => v as String).toList())
              .toList();
          return;
        }
      }
    } catch (_) {}
    _history = [
      ['No backups yet', 'Create one below'],
    ];
  }

  void _logHistory(String label) {
    final now = DateTime.now();
    final stamp =
        '${now.day}/${now.month}/${now.year} · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _history.removeWhere((h) => h[0] == 'No backups yet');
      _history.insert(0, [label, stamp]);
      if (_history.length > 20) _history.length = 20;
    });
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('backupHistoryJson', jsonEncode(_history));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final settings = ref.watch(settingsProvider);
    final security = ref.watch(securityProvider);
    final snapshot = ref.watch(financeSnapshotProvider);
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? 'Signed in';
    final photoUrl = user?.photoURL;
    final pendingSms = ref.watch(smsReviewProvider).length;
    final defaultAccountId = ref
        .watch(userProfileRepositoryProvider)
        ?.defaultAccountId;
    String? defaultAccountName;
    if (defaultAccountId != null) {
      for (final account in snapshot.accounts) {
        if (account.id == defaultAccountId) {
          defaultAccountName = account.name;
          break;
        }
      }
    }
    final categoryCount = settings.categories.keys
        .where((category) => category != 'Transfer')
        .length;
    final notificationsOn = [
      settings.billReminders,
      settings.budgetAlerts,
      settings.dailyReminder,
      settings.weeklyDigest,
    ].where((enabled) => enabled).length;
    final lastBackup = _history.isEmpty || _history.first[0] == 'No backups yet'
        ? null
        : _history.first;
    final backupCount = _history
        .where((entry) => entry[0] != 'No backups yet')
        .length;

    return ScreenScroll(
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle: 'Your account, money and privacy',
          bottom: 16,
        ),
        AppCard(
          onTap: () => _editProfile(context, settings),
          child: Row(
            children: [
              ProfileAvatar(
                photoUrl: photoUrl,
                size: 52,
                fallback: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.ac,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    settings.initials,
                    style: AppTypography.sans(
                      size: 18,
                      color: c.aci,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sans(
                        size: 15,
                        color: c.tx,
                        weight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('Edit', style: AppTypography.sans(size: 12, color: c.ac)),
              const SizedBox(width: 4),
              SpendIcon('chevronRight', size: 16, color: c.mu),
            ],
          ),
        ),
        _SettingsSectionHeader(
          icon: 'eye',
          title: 'Appearance',
          subtitle: 'Theme, accent and typeface',
        ),
        _SettingsCard(
          children: [
            _SettingBlock(
              title: 'Theme',
              child: SegmentedControl<AppThemeMode>(
                margin: EdgeInsets.zero,
                options: const [
                  SegmentedOption(AppThemeMode.dark, 'Dark'),
                  SegmentedOption(AppThemeMode.light, 'Light'),
                ],
                selected: settings.theme,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).patch(theme: value),
              ),
            ),
            const _SettingsDivider(),
            _SettingBlock(
              title: 'Accent colour',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final accent in AppColors.accents)
                    _AccentDot(
                      color: accent,
                      selected: settings.accent == accent,
                      onTap: () {
                        Haptics.light();
                        ref
                            .read(settingsProvider.notifier)
                            .patch(accent: accent);
                      },
                    ),
                ],
              ),
            ),
            const _SettingsDivider(),
            _SettingBlock(
              title: 'Typeface',
              child: SegmentedControl<AppFontMode>(
                margin: EdgeInsets.zero,
                options: const [
                  SegmentedOption(AppFontMode.dmSans, 'DM Sans'),
                  SegmentedOption(AppFontMode.serif, 'Serif'),
                  SegmentedOption(AppFontMode.mono, 'Mono'),
                ],
                selected: settings.font,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).patch(font: value),
              ),
            ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'grid',
          title: 'Navigation',
          subtitle: 'Choose how you move around',
        ),
        _SettingsCard(
          children: [
            _SettingBlock(
              title: 'Navigation style',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedControl<AppNavigationMode>(
                    margin: EdgeInsets.zero,
                    options: const [
                      SegmentedOption(AppNavigationMode.orb, 'Orb'),
                      SegmentedOption(AppNavigationMode.navbar, 'Nav bar'),
                    ],
                    selected: settings.navigation,
                    onChanged: (value) {
                      Haptics.light();
                      ref
                          .read(settingsProvider.notifier)
                          .patch(navigation: value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    settings.navigation == AppNavigationMode.orb
                        ? 'Tap the orb for all modules. Hold and slide for the radial menu.'
                        : '${settings.navbarLeft.length + 1 + settings.navbarRight.length} tabs with Apps in the center.',
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
                ],
              ),
            ),
            if (settings.navigation == AppNavigationMode.navbar)
              _SettingsRow(
                icon: 'grid',
                title: 'Customize nav bar',
                subtitle: [
                  ...settings.navbarLeft.map((m) => m.label),
                  'Apps',
                  ...settings.navbarRight.map((m) => m.label),
                ].join(' · '),
                trailing: SpendIcon('chevronRight', size: 16, color: c.mu),
                onTap: () => showAppSheet<void>(
                  context,
                  (_) => const _NavbarCustomizeSheet(),
                ),
              ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'settings',
          title: 'Preferences',
          subtitle: 'How the app behaves',
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: 'eyeOff',
              title: 'Hide balances',
              subtitle: 'Blur amounts across the app',
              trailing: AppToggle(
                value: settings.hideBalances,
                onChanged: (value) => ref
                    .read(settingsProvider.notifier)
                    .patch(hideBalances: value),
              ),
            ),
            _SettingsRow(
              icon: 'sparkle',
              title: 'Haptics',
              subtitle: 'Vibrate on taps and actions',
              trailing: AppToggle(
                value: settings.haptics,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).patch(haptics: value),
              ),
            ),
            _SettingsRow(
              icon: 'home',
              title: 'Customize Home',
              subtitle: 'Reorder or hide Home widgets',
              onTap: () => showCustomizeHomeSheet(context),
              last: true,
            ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'calendar',
          title: 'Notifications',
          subtitle: 'Reminders and weekly summaries',
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: 'calendar',
              title: 'Reminder schedule',
              subtitle: notificationsOn == 0
                  ? 'All reminders are off'
                  : '$notificationsOn of 4 on${settings.dailyReminder ? ' · daily at ${settings.reminderLabel}' : ''}',
              trailing: AppPill(
                label: notificationsOn == 0 ? 'Off' : 'On',
                active: notificationsOn > 0,
              ),
              onTap: () => _showNotifications(context),
              last: true,
            ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'budget',
          title: 'Money',
          subtitle: 'Default account, categories and tags',
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: 'accounts',
              title: 'Default account',
              subtitle: defaultAccountName ?? 'Automatic',
              onTap: () => _showDefaultAccount(context),
            ),
            _SettingsRow(
              icon: 'budget',
              title: 'Categories',
              subtitle:
                  '$categoryCount categories · reorder, rename and recolour',
              onTap: () => _showCategories(context),
            ),
            _SettingsRow(
              icon: 'receipt',
              title: 'Tags',
              subtitle: snapshot.tags.isEmpty
                  ? 'No tags yet'
                  : '${snapshot.tags.length} tags',
              onTap: () => _showTags(context),
            ),
            _SettingsRow(
              icon: 'tools',
              title: 'Shortcuts',
              subtitle: '${snapshot.shortcuts.length} quick actions',
              onTap: () => showShortcutsSheet(context),
              last: true,
            ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'sparkle',
          title: 'Automation',
          subtitle: 'Bank SMS capture',
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: 'receipt',
              title: 'Bank SMS capture',
              subtitle: settings.smsCaptureEnabled
                  ? (pendingSms == 0
                        ? 'On · parse bank messages on this phone'
                        : 'On · $pendingSms message${pendingSms == 1 ? '' : 's'} waiting for review')
                  : pendingSms == 0
                  ? 'Off · no bank messages will be captured'
                  : 'Off · $pendingSms message${pendingSms == 1 ? '' : 's'} still waiting for review',
              trailing: AppToggle(
                value: settings.smsCaptureEnabled,
                onChanged: _setSmsEnabled,
              ),
              onTap: () => _showSms(context),
              last: true,
            ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'lock',
          title: 'Security',
          subtitle: 'App lock and biometrics',
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: 'lock',
              title: 'App lock',
              subtitle: security.hasPin
                  ? (security.biometricsEnabled
                        ? 'PIN + biometrics enabled'
                        : 'PIN enabled')
                  : 'Off',
              trailing: AppPill(
                label: security.isLockEnabled ? 'On' : 'Off',
                active: security.isLockEnabled,
              ),
              onTap: () => _showPinVault(context),
            ),
            _SettingsRow(
              icon: 'faceId',
              title: 'Lock now',
              subtitle: security.isLockEnabled
                  ? 'Require authentication immediately'
                  : 'Set up an app PIN first',
              onTap: () {
                if (!security.isLockEnabled) {
                  _showPinVault(context);
                  return;
                }
                ref.read(securityProvider.notifier).lock();
                widget.onLock();
              },
              last: true,
            ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'vault',
          title: 'Data & backup',
          subtitle: 'Cloud sync, exports and recovery',
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: 'vault',
              title: 'Cloud sync',
              subtitle: email,
              trailing: const AppPill(label: 'Cloud', active: true),
            ),
            _SettingsRow(
              icon: 'download',
              title: 'Export data',
              subtitle: 'CSV, PDF, XLSX or full JSON',
              onTap: () => _showExport(context),
            ),
            _SettingsRow(
              icon: 'upload',
              title: 'Backup & restore',
              subtitle: lastBackup == null
                  ? 'Create a full JSON backup'
                  : 'Last backup ${lastBackup[1]}',
              onTap: () => _showBackup(context),
            ),
            _SettingsRow(
              icon: 'receipt',
              title: 'Backup history',
              subtitle: backupCount == 0
                  ? 'No backups yet'
                  : '$backupCount saved backup${backupCount == 1 ? '' : 's'}',
              onTap: () => _showHistory(context),
            ),
            _SettingsRow(
              icon: 'sparkle',
              title: snapshot.hasMockData
                  ? 'Clear demo data'
                  : 'Load demo data',
              subtitle: snapshot.hasMockData
                  ? 'Remove only documents tagged isMock'
                  : 'Explore with sample accounts and transactions',
              danger: snapshot.hasMockData,
              onTap: () => snapshot.hasMockData
                  ? _clearMockData(context)
                  : _loadDemoData(context),
            ),
            _SettingsRow(
              icon: 'trash',
              title: 'Erase all data',
              subtitle: 'Remove everything from your account',
              danger: true,
              onTap: () => _erase(context),
              last: true,
            ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'accounts',
          title: 'Account',
          subtitle: 'Your Spendwiser identity',
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: 'arrowRight',
              title: 'Sign out',
              subtitle: 'Clear local SMS queue and sign out',
              onTap: () => _showSignOut(context),
            ),
            _SettingsRow(
              icon: 'trash',
              title: 'Delete account',
              subtitle: 'Remove your account and cloud data',
              danger: true,
              onTap: () => showDeleteAccountSheet(context),
              last: true,
            ),
          ],
        ),
        _SettingsSectionHeader(
          icon: 'settings',
          title: 'About',
          subtitle: 'App information',
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: 'sparkle',
              title: 'Spendwiser',
              subtitle: 'Version 1.0.0',
            ),
            _SettingsRow(
              icon: 'profile',
              title: 'Crafted by Hariharen',
              subtitle: 'hariharen.space · Tap to copy link',
              onTap: () {
                Clipboard.setData(
                  const ClipboardData(text: 'https://hariharen.space'),
                );
                ref.read(toastProvider.notifier).show('Copied hariharen.space');
              },
            ),
            _SettingsRow(
              icon: 'refresh',
              title: 'Replay welcome',
              subtitle: 'See the intro again',
              onTap: widget.onReplayWelcome,
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              Text(
                'CRAFTED WITH CARE BY',
                style: AppTypography.sans(
                  size: 10,
                  color: c.mu,
                  weight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hariharen',
                style: AppTypography.display(size: 24, color: c.tx),
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: () {
                  Clipboard.setData(
                    const ClipboardData(text: 'https://hariharen.space'),
                  );
                  ref
                      .read(toastProvider.notifier)
                      .show('Copied hariharen.space');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: c.c1,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.ln),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.ac,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'hariharen.space',
                        style: AppTypography.sans(
                          size: 12,
                          color: c.tx,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _export(String label, {String? range}) async {
    final selectedRange = range ?? _range;
    _range = selectedRange;
    ref.read(toastProvider.notifier).show('Preparing $label…');
    try {
      final snapshot = ref.read(financeSnapshotProvider);
      if (label.contains('CSV')) {
        await BackupService.exportLedgerCsv(snapshot, selectedRange);
      } else if (label.contains('PDF')) {
        await BackupService.exportAnnualSummaryPdf(snapshot);
      } else if (label.contains('XLSX')) {
        await BackupService.exportStatementsXlsx(snapshot, selectedRange);
      } else if (label.contains('backup')) {
        await BackupService.exportFullBackup();
      } else {
        await BackupService.exportLedgerCsv(snapshot, selectedRange);
      }
      _logHistory(label);
    } catch (e) {
      ref.read(toastProvider.notifier).show('Export failed: $e');
    }
  }

  Future<void> _importBackup() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked.isEmpty) return;
      final file = File(picked.first.path!);
      final contents = await file.readAsString();
      final payload = BackupService.parseBackup(contents);
      await importBackupPayload(payload);
      ref.invalidate(firestoreFinanceStoreProvider);
      ref.invalidate(userProfileRepositoryProvider);
      ref.invalidate(settingsProvider);
      _logHistory('Restored backup');
      ref.read(toastProvider.notifier).show('Backup restored');
    } on FormatException catch (e) {
      ref.read(toastProvider.notifier).show(e.message);
    } catch (e) {
      ref.read(toastProvider.notifier).show('Restore failed: $e');
    }
  }

  Future<void> _editProfile(BuildContext context, AppSettings settings) async {
    final controller = TextEditingController(text: settings.userName);
    await showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('Profile'),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Your name',
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: context.spend.c2,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: controller,
                textAlignVertical: TextAlignVertical.center,
                style: AppTypography.sans(size: 14, color: context.spend.tx),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'Your name',
                  hintStyle: AppTypography.sans(
                    size: 13,
                    color: context.spend.mu,
                  ),
                ),
              ),
            ),
          ),
          PrimaryButton(
            label: 'Save',
            onTap: () {
              final name = controller.text.trim();
              ref
                  .read(settingsProvider.notifier)
                  .patch(userName: name.isEmpty ? settings.userName : name);
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void _showDefaultAccount(BuildContext context) {
    final profile = ref.read(userProfileRepositoryProvider);
    final snapshot = ref.read(financeSnapshotProvider);
    final selected = profile?.defaultAccountId;
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Default account',
            subtitle: 'Used for quick capture, voice and scanned receipts.',
          ),
          const SizedBox(height: 12),
          if (snapshot.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Add a bank account or cash balance first.',
                style: AppTypography.sans(
                  size: 13,
                  color: sheetContext.spend.mu,
                ),
              ),
            )
          else
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: 'settings',
                  title: 'Automatic',
                  subtitle: 'Use the merchant’s last account, or the first one',
                  trailing: selected == null
                      ? const AppPill(label: 'Active', active: true)
                      : null,
                  onTap: () async {
                    await profile?.setDefaultAccountId(null);
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    if (mounted) setState(() {});
                    ref
                        .read(toastProvider.notifier)
                        .show('Default account set to automatic');
                  },
                ),
                for (var i = 0; i < snapshot.accounts.length; i++)
                  _SettingsRow(
                    icon: 'accounts',
                    title: snapshot.accounts[i].name,
                    subtitle:
                        '${snapshot.accounts[i].type.label} · ${rupee(snapshot.accounts[i].balance)}',
                    trailing: selected == snapshot.accounts[i].id
                        ? const AppPill(label: 'Active', active: true)
                        : null,
                    onTap: () async {
                      await profile?.setDefaultAccountId(
                        snapshot.accounts[i].id,
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.of(sheetContext).pop();
                      if (mounted) setState(() {});
                      ref
                          .read(toastProvider.notifier)
                          .show(
                            'Default account set to ${snapshot.accounts[i].name}',
                          );
                    },
                    last: i == snapshot.accounts.length - 1,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showCategories(BuildContext context) {
    showAppSheet<void>(context, (sheetContext) => const _CategoriesSheet());
  }

  void _showTags(BuildContext context) {
    showAppSheet<void>(context, (sheetContext) => const _TagsSheet());
  }

  void _showNotifications(BuildContext context) {
    var bill = ref.read(settingsProvider).billReminders;
    var alerts = ref.read(settingsProvider).budgetAlerts;
    var daily = ref.read(settingsProvider).dailyReminder;
    var digest = ref.read(settingsProvider).weeklyDigest;
    var hour = ref.read(settingsProvider).reminderHour;
    var minute = ref.read(settingsProvider).reminderMinute;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final c = context.spend;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('Notifications'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    _ToggleRow(
                      label: 'Bill reminders',
                      detail: '2 days before anything is due',
                      value: bill,
                      onChanged: (value) => setSheetState(() => bill = value),
                    ),
                    _ToggleRow(
                      label: 'Budget alerts',
                      detail: 'When an envelope crosses its alert level',
                      value: alerts,
                      onChanged: (value) => setSheetState(() => alerts = value),
                    ),
                    _ToggleRow(
                      label: 'Daily check-in',
                      detail: 'A nudge to log today\'s spends',
                      value: daily,
                      onChanged: (value) => setSheetState(() => daily = value),
                    ),
                    _ToggleRow(
                      label: 'Weekly digest',
                      detail: 'Sunday summary of your week',
                      value: digest,
                      onChanged: (value) => setSheetState(() => digest = value),
                      last: true,
                    ),
                  ],
                ),
              ),
              Text(
                'Reminder time',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              const SizedBox(height: 8),
              Pressable(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: sheetContext,
                    initialTime: TimeOfDay(hour: hour, minute: minute),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(alwaysUse24HourFormat: true),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                  if (picked == null) return;
                  setSheetState(() {
                    hour = picked.hour;
                    minute = picked.minute;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: c.c2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                        style: AppTypography.sans(size: 14, color: c.tx),
                      ),
                      const Spacer(),
                      SpendIcon('chevronDown', size: 16, color: c.mu),
                    ],
                  ),
                ),
              ),
              Text(
                'Used for daily check-ins, bill reminders and the weekly digest.',
                style: AppTypography.sans(size: 11, color: c.mu),
              ),
              AppButton(
                label: 'Send test notification',
                onTap: () async {
                  await NotificationsService.requestPermissions();
                  await NotificationsService.showNow(
                    'Spendwiser test',
                    'Notifications are working on this device.',
                    id: 42,
                  );
                },
              ),
              PrimaryButton(
                label: 'Save',
                onTap: () async {
                  await NotificationsService.requestPermissions();
                  ref
                      .read(settingsProvider.notifier)
                      .patch(
                        billReminders: bill,
                        budgetAlerts: alerts,
                        dailyReminder: daily,
                        weeklyDigest: digest,
                        reminderHour: hour,
                        reminderMinute: minute,
                      );
                  final snapshot = ref.read(financeSnapshotProvider);
                  final updated = ref.read(settingsProvider);
                  await NotificationsService.reschedule(snapshot, updated);
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(toastProvider.notifier)
                      .show('Notification preferences saved');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _setSmsEnabled(bool enabled) async {
    if (!enabled) {
      await SmsInbox.setEnabled(false);
      ref.read(settingsProvider.notifier).patch(smsCaptureEnabled: false);
      if (!mounted) return;
      ref.read(toastProvider.notifier).show('Bank SMS capture off');
      return;
    }
    final granted = await SmsInbox.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ref.read(toastProvider.notifier).show('SMS permission was not granted');
      return;
    }
    await SmsInbox.setEnabled(true);
    ref.read(settingsProvider.notifier).patch(smsCaptureEnabled: true);
    await ref.read(smsReviewProvider.notifier).refresh();
    if (!mounted) return;
    ref.read(toastProvider.notifier).show('Bank SMS capture on');
  }

  void _showSms(BuildContext context) {
    showSmsSettingsSheet(context);
  }

  void _showPinVault(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Consumer(
        builder: (_, sheetRef, _) {
          final security = sheetRef.watch(securityProvider);
          final hasPin = security.hasPin;
          final biometrics = security.biometricsEnabled;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(
                'PIN & biometrics',
                subtitle: 'Protect your financial data with device security.',
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    _ToggleRow(
                      label: 'App PIN',
                      detail: hasPin ? '4-digit PIN configured' : 'Not set',
                      value: hasPin,
                      onChanged: (v) {
                        Navigator.of(sheetContext).pop();
                        if (!v) {
                          _showPinVerification(
                            context,
                            title: 'Remove PIN',
                            subtitle:
                                'Enter your current PIN to turn off app lock.',
                            onVerified: () async {
                              await ref
                                  .read(securityProvider.notifier)
                                  .removePin();
                              if (!mounted) return;
                              ref
                                  .read(toastProvider.notifier)
                                  .show('App PIN removed');
                            },
                          );
                        } else {
                          _showPinSetup(context, mode: _PinSheetMode.setup);
                        }
                      },
                    ),
                    _ToggleRow(
                      label: 'Face ID / Fingerprint',
                      detail: !security.biometricsSupported
                          ? 'Not available on device'
                          : !hasPin
                          ? 'Set a PIN first'
                          : 'Fast biometric unlock',
                      value: biometrics,
                      onChanged: (v) async {
                        if (!hasPin) {
                          ref
                              .read(toastProvider.notifier)
                              .show('Set a PIN first');
                          return;
                        }
                        if (v) {
                          final verified = await ref
                              .read(securityProvider.notifier)
                              .authenticateBiometrics(
                                reason: 'Verify fingerprint or face to enable biometric unlock',
                                isSetup: true,
                              );
                          if (!mounted) return;
                          if (verified) {
                            await ref
                                .read(securityProvider.notifier)
                                .setBiometricsEnabled(true);
                            if (!mounted) return;
                            ref
                                .read(toastProvider.notifier)
                                .show('Biometrics enabled');
                          } else {
                            ref
                                .read(toastProvider.notifier)
                                .show('Biometric setup canceled or failed');
                          }
                        } else {
                          await ref
                              .read(securityProvider.notifier)
                              .setBiometricsEnabled(false);
                          if (!mounted) return;
                          ref
                              .read(toastProvider.notifier)
                              .show('Biometrics disabled');
                        }
                      },
                      last: !hasPin,
                    ),
                    if (hasPin)
                      AppButton(
                        label: 'Change PIN',
                        centered: true,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _showPinSetup(context, mode: _PinSheetMode.change);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!hasPin)
                PrimaryButton(
                  label: 'Set 4-digit PIN',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showPinSetup(context, mode: _PinSheetMode.setup);
                  },
                )
              else
                PrimaryButton(
                  label: 'Lock app now',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ref.read(securityProvider.notifier).lock();
                    widget.onLock();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  void _showPinSetup(
    BuildContext context, {
    _PinSheetMode mode = _PinSheetMode.setup,
  }) {
    showAppSheet<void>(context, (sheetContext) => _PinSetupSheet(mode: mode));
  }

  void _showPinVerification(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onVerified,
  }) {
    showAppSheet<void>(
      context,
      (sheetContext) => _PinSetupSheet(
        mode: _PinSheetMode.verify,
        titleOverride: title,
        subtitleOverride: subtitle,
        onVerified: () {
          Navigator.of(sheetContext).pop();
          onVerified();
        },
      ),
    );
  }

  void _showExport(BuildContext context) {
    var range = _range;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(
                'Export data',
                subtitle: 'Choose a range, then a format.',
              ),
              const SizedBox(height: 12),
              SegmentedControl<String>(
                options: const [
                  SegmentedOption('m', 'This month'),
                  SegmentedOption('f', 'FY 26–27'),
                  SegmentedOption('a', 'All time'),
                ],
                selected: range,
                onChanged: (value) => setSheetState(() => range = value),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsRow(
                    icon: 'ledger',
                    title: 'Ledger · CSV',
                    subtitle: 'Transactions in the selected range',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _export('Ledger · CSV', range: range);
                    },
                  ),
                  _SettingsRow(
                    icon: 'receipt',
                    title: 'Annual summary · PDF',
                    subtitle: 'Income, spend and category totals',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _export('Annual summary · PDF', range: range);
                    },
                  ),
                  _SettingsRow(
                    icon: 'cards',
                    title: 'Statements · XLSX',
                    subtitle: 'Card statements in the selected range',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _export('Statements · XLSX', range: range);
                    },
                  ),
                  _SettingsRow(
                    icon: 'vault',
                    title: 'Full backup · JSON',
                    subtitle: 'Everything, compatible with the web app',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _export('Full backup · JSON', range: range);
                    },
                    last: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Exports open your device share sheet. Backup files can be restored below.',
                style: AppTypography.sans(
                  size: 12,
                  color: sheetContext.spend.mu,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBackup(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Backup & restore',
            subtitle: 'Full JSON backups, compatible with the web app.',
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: 'upload',
                title: 'Create full backup',
                subtitle: 'Export accounts, transactions, budgets and more',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _export('Full backup · JSON');
                },
              ),
              _SettingsRow(
                icon: 'download',
                title: 'Restore from backup',
                subtitle: 'Pick a JSON backup file',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _importBackup();
                },
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The backup file is plain JSON. Keep it somewhere safe.',
            style: AppTypography.sans(size: 12, color: sheetContext.spend.mu),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    final entries = _history
        .where((entry) => entry[0] != 'No backups yet')
        .toList();
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Backup history',
            subtitle: 'Recent exports and restores on this device.',
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No backups yet. Create one from Backup & restore.',
                style: AppTypography.sans(
                  size: 13,
                  color: sheetContext.spend.mu,
                ),
              ),
            )
          else
            _SettingsCard(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _SettingsRow(
                    icon: 'check',
                    title: entries[i][0],
                    subtitle: entries[i][1],
                    last: i == entries.length - 1,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showSignOut(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Sign out?',
            subtitle:
                'Your cloud data stays safe. The local SMS queue is cleared.',
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Sign out',
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await SmsInbox.clear();
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
    );
  }

  void _loadDemoData(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Load demo data?',
            subtitle: 'Adds sample data tagged as demo.',
          ),
          Text(
            'Accounts, cards, transactions, budgets, goals and loans are added '
            'alongside anything you already have. Clear demo data at any time.',
            style: AppTypography.sans(size: 14, color: sheetContext.spend.mu),
          ),
          PrimaryButton(
            label: 'Load demo data',
            onTap: () async {
              await ref.read(financeRepositoryProvider).loadDemoData();
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Demo data loaded');
            },
          ),
        ],
      ),
    );
  }

  void _clearMockData(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Clear mock data?',
            subtitle: 'Only documents tagged isMock are removed.',
          ),
          Text(
            'Your real transactions, accounts, budgets, goals and loans stay untouched.',
            style: AppTypography.sans(size: 14, color: sheetContext.spend.mu),
          ),
          PrimaryButton(
            label: 'Clear mock data',
            onTap: () async {
              await ref.read(financeRepositoryProvider).clearMockData();
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ref.read(toastProvider.notifier).show('Mock data cleared');
            },
          ),
        ],
      ),
    );
  }

  void _erase(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('Erase everything?'),
          Text(
            'This removes every transaction, account, card, budget, goal, loan and recurring rule from your Spendwiser account. Export a backup first.',
            style: AppTypography.sans(size: 14, color: sheetContext.spend.mu),
          ),
          PrimaryButton(
            label: 'Back up first',
            onTap: () => _export('Full backup · JSON'),
          ),
          AppButton(
            label: 'Erase',
            color: sheetContext.spend.co,
            centered: true,
            onTap: () async {
              await ref.read(financeRepositoryProvider).startFresh();
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              widget.onReset();
              ref.read(toastProvider.notifier).show('All data erased');
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final String icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.ac.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: SpendIcon(icon, size: 16, color: c.ac),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.sans(
                    size: 13,
                    color: c.tx,
                    weight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.sans(size: 11, color: c.mu),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      clip: true,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.last = false,
    this.danger = false,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool last;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final color = danger ? c.co : c.ac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.ln)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  IconTile(icon: icon, color: color, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.sans(
                            size: 14,
                            color: danger ? c.co : c.tx,
                            weight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.sans(size: 12, color: c.mu),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: SpendIcon('chevronRight', size: 16, color: c.mu),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingBlock extends StatelessWidget {
  const _SettingBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.sans(size: 12, color: context.spend.mu),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: context.spend.ln);
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, AppColors.accentSecondary(color)],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? c.tx : c.ln,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.ln)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.sans(size: 14, color: c.tx)),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
              ],
            ),
          ),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CategoriesSheet extends ConsumerStatefulWidget {
  const _CategoriesSheet();

  @override
  ConsumerState<_CategoriesSheet> createState() => _CategoriesSheetState();
}

class _CategoriesSheetState extends ConsumerState<_CategoriesSheet> {
  final _nameController = TextEditingController();
  Color _selectedColor = AppColors.categoryPalette.first;
  bool _showAdd = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _add() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ref.read(toastProvider.notifier).show('Enter a category name');
      return;
    }
    final existing = ref.read(settingsProvider).categories;
    if (existing.containsKey(name)) {
      ref.read(toastProvider.notifier).show('Category "$name" already exists');
      return;
    }
    ref.read(settingsProvider.notifier).addCategory(name, _selectedColor);
    ref.read(toastProvider.notifier).show('Added category "$name"');
    _nameController.clear();
    setState(() => _showAdd = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final settings = ref.watch(settingsProvider);
    final snapshot = ref.watch(financeSnapshotProvider);
    final categories = settings.categories.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Categories',
          subtitle: 'Tap to edit, drag handle to reorder.',
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: categories.length,
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              Haptics.light();
              ref
                  .read(settingsProvider.notifier)
                  .reorderCategories(oldIndex, newIndex);
            },
            itemBuilder: (context, i) {
              final entry = categories[i];
              final catName = entry.key;
              final catColor = entry.value;
              final count = snapshot.transactions
                  .where((t) => t.category == catName)
                  .length;

              return Container(
                key: ValueKey(catName),
                decoration: BoxDecoration(
                  border: i < categories.length - 1
                      ? Border(bottom: BorderSide(color: c.ln))
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: 18,
                            color: c.mu.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _openEdit(context, catName, catColor),
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              MerchantAvatar(
                                merchant: catName,
                                category: catName,
                                size: 36,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      catName,
                                      style: AppTypography.sans(
                                        size: 15,
                                        color: c.tx,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      count == 0
                                          ? 'No transactions'
                                          : '$count transaction${count == 1 ? '' : 's'}',
                                      style: AppTypography.sans(
                                        size: 12,
                                        color: c.mu,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.tx.withValues(alpha: 0.2),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SpendIcon('chevronRight', size: 14, color: c.mu),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (!_showAdd)
          AppButton(
            label: '+ Add Category',
            onTap: () => setState(() => _showAdd = true),
          )
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'New Category',
                      style: AppTypography.sans(
                        size: 14,
                        color: c.tx,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _showAdd = false),
                      child: SpendIcon('close', size: 16, color: c.mu),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: c.c2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _nameController,
                    textAlignVertical: TextAlignVertical.center,
                    style: AppTypography.sans(size: 14, color: c.tx),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'e.g. Groceries, Fitness, Pets…',
                      hintStyle: AppTypography.sans(size: 13, color: c.mu),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Color', style: AppTypography.sans(size: 12, color: c.mu)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final color in AppColors.categoryPalette)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              Haptics.light();
                              setState(() => _selectedColor = color);
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: _selectedColor == color
                                    ? Border.all(color: c.tx, width: 2.5)
                                    : null,
                                boxShadow: _selectedColor == color
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: 'Add Category', onTap: _add),
              ],
            ),
          ),
      ],
    );
  }

  void _openEdit(BuildContext context, String name, Color color) {
    showAppSheet<void>(
      context,
      (sheetContext) => _EditCategorySheet(name: name, color: color),
    );
  }
}

class _EditCategorySheet extends ConsumerStatefulWidget {
  const _EditCategorySheet({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  ConsumerState<_EditCategorySheet> createState() => _EditCategorySheetState();
}

class _EditCategorySheetState extends ConsumerState<_EditCategorySheet> {
  late final TextEditingController _controller;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
    _color = widget.color;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty) {
      ref.read(toastProvider.notifier).show('Category name cannot be empty');
      return;
    }
    if (newName != widget.name) {
      final existing = ref.read(settingsProvider).categories;
      if (existing.containsKey(newName)) {
        ref
            .read(toastProvider.notifier)
            .show('Category "$newName" already exists');
        return;
      }
      await ref
          .read(transactionRepositoryProvider)
          .renameCategory(widget.name, newName);
      ref
          .read(settingsProvider.notifier)
          .editCategory(widget.name, newName, _color);
    } else {
      ref
          .read(settingsProvider.notifier)
          .editCategory(widget.name, widget.name, _color);
    }
    if (!mounted) return;
    ref.read(toastProvider.notifier).show('Saved category');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(transactionRepositoryProvider).deleteCategory(widget.name);
    if (!mounted) return;
    ref.read(settingsProvider.notifier).deleteCategory(widget.name);
    ref.read(toastProvider.notifier).show('Deleted "${widget.name}"');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final isProtected = widget.name == 'Transfer' || widget.name == 'Income';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Edit Category',
          subtitle: 'Update category name or accent color',
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Category name',
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _controller,
              enabled: !isProtected,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.sans(size: 14, color: c.tx),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Category name',
                hintStyle: AppTypography.sans(size: 13, color: c.mu),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('Accent Color', style: AppTypography.sans(size: 12, color: c.mu)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final color in AppColors.categoryPalette)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      Haptics.light();
                      setState(() => _color = color);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(color: c.tx, width: 2.5)
                            : null,
                        boxShadow: _color == color
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Save Changes', onTap: _save),
        if (!isProtected) ...[
          const SizedBox(height: 8),
          AppButton(label: 'Delete Category', color: c.co, onTap: _delete),
        ],
      ],
    );
  }
}

class _TagsSheet extends ConsumerStatefulWidget {
  const _TagsSheet();

  @override
  ConsumerState<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends ConsumerState<_TagsSheet> {
  bool _showAdd = false;
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addTag() async {
    final text = _addController.text.trim().replaceAll('#', '');
    if (text.isEmpty) return;
    await ref.read(transactionRepositoryProvider).addTag(text);
    _addController.clear();
    setState(() => _showAdd = false);
  }

  void _editTag(String tag) {
    showAppSheet<void>(context, (_) => _EditTagSheet(tag: tag));
  }

  Widget _buildTagRow(
    String tag,
    int i,
    FinanceSnapshot snapshot,
    BuildContext context,
  ) {
    final c = context.spend;
    final count = snapshot.transactions
        .where((t) => t.tags.contains(tag))
        .length;
    final tagColor = AppColors.accents[i % AppColors.accents.length];

    return Column(
      children: [
        InkWell(
          onTap: () => _editTag(tag),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            child: Row(
              children: [
                AppPill(label: '#$tag', color: tagColor, textColor: tagColor),
                const Spacer(),
                Text(
                  count == 0 ? 'Not used' : '$count tagged',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
                const SizedBox(width: 8),
                SpendIcon('chevronRight', size: 14, color: c.mu),
              ],
            ),
          ),
        ),
        if (i < snapshot.tags.length - 1) Divider(color: c.ln, height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final snapshot = ref.watch(financeSnapshotProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SheetTitle(
              'Tags',
              subtitle: 'Organize your transactions with custom tags',
            ),
            if (!_showAdd)
              GestureDetector(
                onTap: () => setState(() => _showAdd = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.ac,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+ Add',
                    style: AppTypography.sans(
                      size: 12,
                      color: c.aci,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_showAdd) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.c1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.ln),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New tag',
                      style: AppTypography.sans(
                        size: 13,
                        color: c.tx,
                        weight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showAdd = false),
                      child: SpendIcon('close', size: 16, color: c.mu),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: c.c2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _addController,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    style: AppTypography.sans(size: 14, color: c.tx),
                    onSubmitted: (_) => _addTag(),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'e.g. Travel, Coffee, Medical, Pets…',
                      hintStyle: AppTypography.sans(size: 13, color: c.mu),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PrimaryButton(label: 'Save tag', onTap: _addTag),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (snapshot.tags.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: Text(
              'No tags yet. Tap "+ Add" to create one.',
              style: AppTypography.sans(size: 13, color: c.mu),
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < snapshot.tags.length; i++)
                  _buildTagRow(snapshot.tags[i], i, snapshot, context),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _EditTagSheet extends ConsumerStatefulWidget {
  const _EditTagSheet({required this.tag});

  final String tag;

  @override
  ConsumerState<_EditTagSheet> createState() => _EditTagSheetState();
}

class _EditTagSheetState extends ConsumerState<_EditTagSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tag);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = _controller.text.trim().replaceAll('#', '');
    if (next.isNotEmpty && next != widget.tag) {
      await ref.read(transactionRepositoryProvider).renameTag(widget.tag, next);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(transactionRepositoryProvider).deleteTag(widget.tag);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle('Edit #${widget.tag}'),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Tag name',
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _controller,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.sans(size: 14, color: c.tx),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Tag name',
                hintStyle: AppTypography.sans(size: 13, color: c.mu),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Save', onTap: _save),
        const SizedBox(height: 8),
        AppButton(
          label: 'Delete tag',
          color: c.co,
          centered: true,
          margin: EdgeInsets.zero,
          onTap: _delete,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

enum _PinSheetMode { setup, change, verify }

class _PinSetupSheet extends ConsumerStatefulWidget {
  const _PinSetupSheet({
    this.mode = _PinSheetMode.setup,
    this.titleOverride,
    this.subtitleOverride,
    this.onVerified,
  });

  final _PinSheetMode mode;
  final String? titleOverride;
  final String? subtitleOverride;
  final VoidCallback? onVerified;

  @override
  ConsumerState<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<_PinSetupSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  int _step = 0;
  String _pin = '';
  String _firstNew = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.titleOverride != null && _step == 0) {
      return widget.titleOverride!;
    }
    switch (widget.mode) {
      case _PinSheetMode.setup:
        return _step == 0 ? 'Set a 4-digit PIN' : 'Confirm your PIN';
      case _PinSheetMode.change:
        if (_step == 0) return 'Enter current PIN';
        if (_step == 1) return 'Enter new 4-digit PIN';
        return 'Confirm new PIN';
      case _PinSheetMode.verify:
        return widget.titleOverride ?? 'Enter your PIN';
    }
  }

  String get _subtitle {
    if (widget.subtitleOverride != null && _step == 0) {
      return widget.subtitleOverride!;
    }
    switch (widget.mode) {
      case _PinSheetMode.setup:
        return _step == 0
            ? 'Stored as an encrypted hash on this device only.'
            : 'Re-enter your 4-digit PIN to confirm.';
      case _PinSheetMode.change:
        if (_step == 0) return 'Verify your identity to change PIN.';
        if (_step == 1) return 'Choose a new 4-digit PIN.';
        return 'Re-enter your new PIN to confirm.';
      case _PinSheetMode.verify:
        return widget.subtitleOverride ?? 'Verify your PIN to continue.';
    }
  }

  void _triggerError(String msg) {
    Haptics.heavy();
    setState(() {
      _error = msg;
      _pin = '';
    });
    _shakeController.forward(from: 0);
  }

  void _append(String digit) {
    if (_pin.length >= 4) return;
    Haptics.light();
    setState(() {
      _error = null;
      _pin += digit;
    });

    if (_pin.length == 4) {
      _handleCompletePin();
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    Haptics.light();
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _handleCompletePin() {
    final entered = _pin;
    switch (widget.mode) {
      case _PinSheetMode.setup:
        if (_step == 0) {
          setState(() {
            _firstNew = entered;
            _step = 1;
            _pin = '';
          });
        } else {
          if (entered == _firstNew) {
            ref.read(securityProvider.notifier).setPin(entered).then((_) {
              if (!mounted) return;
              Haptics.medium();
              ref.read(toastProvider.notifier).show('PIN set successfully');
              Navigator.of(context).pop();
            });
          } else {
            _triggerError('PINs do not match. Try again.');
            setState(() {
              _step = 0;
              _firstNew = '';
            });
          }
        }
        break;

      case _PinSheetMode.change:
        if (_step == 0) {
          if (PinVault.verify(entered)) {
            Haptics.light();
            setState(() {
              _step = 1;
              _pin = '';
            });
          } else {
            _triggerError('Incorrect current PIN');
          }
        } else if (_step == 1) {
          setState(() {
            _firstNew = entered;
            _step = 2;
            _pin = '';
          });
        } else {
          if (entered == _firstNew) {
            ref.read(securityProvider.notifier).setPin(entered).then((_) {
              if (!mounted) return;
              Haptics.medium();
              ref.read(toastProvider.notifier).show('PIN changed successfully');
              Navigator.of(context).pop();
            });
          } else {
            _triggerError('New PINs do not match. Try again.');
            setState(() {
              _step = 1;
              _firstNew = '';
            });
          }
        }
        break;

      case _PinSheetMode.verify:
        if (PinVault.verify(entered)) {
          Haptics.medium();
          widget.onVerified?.call();
        } else {
          _triggerError('Incorrect PIN');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(_title, subtitle: _subtitle),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTypography.sans(size: 13, color: c.co),
            ),
          ),
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
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: isFilled ? 16 : 14,
                height: isFilled ? 16 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? (_error != null ? c.co : c.ac) : c.c2,
                  border: Border.all(
                    color: isFilled ? (_error != null ? c.co : c.ac) : c.ln,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Pressable(
                    onTap: () => _append(row[i]),
                    scale: 0.92,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.c1.withValues(alpha: 0.9),
                        border: Border.all(color: c.ln.withValues(alpha: 0.6)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        row[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                          color: c.tx,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72, height: 72),
            const SizedBox(width: 24),
            SizedBox(
              width: 72,
              height: 72,
              child: Pressable(
                onTap: () => _append('0'),
                scale: 0.92,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.c1.withValues(alpha: 0.9),
                    border: Border.all(color: c.ln.withValues(alpha: 0.6)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                      color: c.tx,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 72,
              height: 72,
              child: Pressable(
                onTap: _backspace,
                scale: 0.92,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.backspace_outlined, size: 26, color: c.tx),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _NavbarCustomizeSheet extends ConsumerWidget {
  const _NavbarCustomizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final c = context.spend;
    final left = settings.navbarLeft;
    final right = settings.navbarRight;
    final perSide = left.length >= 3 || right.length >= 3 ? 3 : 2;
    final options = [
      for (final module in AppModule.values)
        AppSelectOption(module, module.label),
    ];

    void setPerSide(int count) {
      Haptics.light();
      if (count == 3) {
        final nextLeft = List<AppModule>.from(left);
        for (final fallback in expandedNavbarLeft) {
          if (nextLeft.length >= 3) break;
          if (!nextLeft.contains(fallback)) nextLeft.add(fallback);
        }
        while (nextLeft.length < 3) {
          nextLeft.add(AppModule.home);
        }
        final nextRight = List<AppModule>.from(right);
        for (final fallback in expandedNavbarRight) {
          if (nextRight.length >= 3) break;
          if (!nextRight.contains(fallback)) nextRight.add(fallback);
        }
        while (nextRight.length < 3) {
          nextRight.add(AppModule.settings);
        }
        ref.read(settingsProvider.notifier).patch(
          navbarLeft: nextLeft.take(3).toList(growable: false),
          navbarRight: nextRight.take(3).toList(growable: false),
        );
      } else {
        ref.read(settingsProvider.notifier).patch(
          navbarLeft: left.take(2).toList(growable: false),
          navbarRight: right.take(2).toList(growable: false),
        );
      }
    }

    void updateLeft(int index, AppModule module) {
      final next = List<AppModule>.from(left);
      if (index < next.length) {
        next[index] = module;
        ref.read(settingsProvider.notifier).patch(navbarLeft: next);
      }
    }

    void updateRight(int index, AppModule module) {
      final next = List<AppModule>.from(right);
      if (index < next.length) {
        next[index] = module;
        ref.read(settingsProvider.notifier).patch(navbarRight: next);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Customize nav bar',
          subtitle: 'Choose 2 or 3 tabs on each side of Apps.',
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Tabs per side',
          child: SegmentedControl<int>(
            margin: EdgeInsets.zero,
            options: const [
              SegmentedOption(2, '2 per side (5)'),
              SegmentedOption(3, '3 per side (7)'),
            ],
            selected: perSide,
            onChanged: setPerSide,
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Left of Apps',
          child: Column(
            children: [
              for (var i = 0; i < left.length; i++) ...[
                AppSelect<AppModule>(
                  value: left[i],
                  options: options,
                  onChanged: (value) {
                    if (value != null) updateLeft(i, value);
                  },
                ),
                if (i < left.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.c2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.ln),
          ),
          child: Row(
            children: [
              SpendIcon('grid', size: 16, color: c.ac),
              const SizedBox(width: 10),
              Text(
                'Center: Apps (All modules)',
                style: AppTypography.sans(
                  size: 13,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Right of Apps',
          child: Column(
            children: [
              for (var i = 0; i < right.length; i++) ...[
                AppSelect<AppModule>(
                  value: right[i],
                  options: options,
                  onChanged: (value) {
                    if (value != null) updateRight(i, value);
                  },
                ),
                if (i < right.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Reset',
                centered: true,
                onTap: () {
                  Haptics.light();
                  ref.read(settingsProvider.notifier).patch(
                    navbarLeft: defaultNavbarLeft,
                    navbarRight: defaultNavbarRight,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: 'Done',
                margin: EdgeInsets.zero,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
