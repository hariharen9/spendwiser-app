import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/section_caption.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/persistence/pin_vault.dart';
import '../../data/services/notifications_service.dart';
import '../../data/models/transaction.dart';
import '../../data/services/backup_service.dart';
import '../home/customize_home_sheet.dart';

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
  final _scroll = ScrollController();
  final _appearanceKey = GlobalKey();
  final _moneyKey = GlobalKey();
  final _automationKey = GlobalKey();
  final _vaultKey = GlobalKey();
  final _appKey = GlobalKey();
  String _range = 'm';
  String _backup = 'w';
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
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jump(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final settings = ref.watch(settingsProvider);

    return ScreenScroll(
      controller: _scroll,
      children: [
        const PageHeader(title: 'Settings', subtitle: 'Make it yours'),
        BleedRow(
          height: 34,
          children: [
            AppPill(label: 'Appearance', onTap: () => _jump(_appearanceKey)),
            AppPill(label: 'Money', onTap: () => _jump(_moneyKey)),
            AppPill(label: 'Automation', onTap: () => _jump(_automationKey)),
            AppPill(label: 'Vault', onTap: () => _jump(_vaultKey)),
            AppPill(label: 'App', onTap: () => _jump(_appKey)),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          onTap: () => _editProfile(context, settings),
          child: Row(
            children: [
              Container(
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.userName,
                      style: AppTypography.sans(
                        size: 15,
                        color: c.tx,
                        weight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Edit profile',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
              SpendIcon('chevronRight', size: 16, color: c.mu),
            ],
          ),
        ),
        SectionCaption(
          'Appearance',
          margin: const EdgeInsets.only(top: 22, bottom: 8),
          key: _appearanceKey,
        ),
        SegmentedControl<AppThemeMode>(
          options: const [
            SegmentedOption(AppThemeMode.dark, 'Dark'),
            SegmentedOption(AppThemeMode.light, 'Light'),
          ],
          selected: settings.theme,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).patch(theme: value),
        ),
        Row(
          children: [
            for (final accent in AppColors.accents)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    Haptics.light();
                    ref.read(settingsProvider.notifier).patch(accent: accent);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: settings.accent == accent
                          ? Border.all(color: c.tx, width: 2)
                          : Border.all(color: c.ln),
                      boxShadow: settings.accent == accent
                          ? [
                              BoxShadow(
                                color: c.tx.withValues(alpha: 0.25),
                                blurRadius: 0,
                                spreadRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedControl<AppFontMode>(
          options: const [
            SegmentedOption(AppFontMode.dmSans, 'DM Sans'),
            SegmentedOption(AppFontMode.serif, 'Serif'),
            SegmentedOption(AppFontMode.mono, 'Mono'),
          ],
          selected: settings.font,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).patch(font: value),
        ),
        AppCard(
          child: Column(
            children: [
              _ToggleRow(
                label: 'Hide balances',
                detail: 'Blur amounts in public',
                value: settings.hideBalances,
                onChanged: (value) => ref
                    .read(settingsProvider.notifier)
                    .patch(hideBalances: value),
              ),
              _ToggleRow(
                label: 'Haptics',
                detail: 'Vibrate on tap and on the FAB',
                value: settings.haptics,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).patch(haptics: value),
              ),
              _ToggleRow(
                label: 'Budget alerts',
                detail: 'Warn when an envelope nears its limit',
                value: settings.budgetAlerts,
                onChanged: (value) => ref
                    .read(settingsProvider.notifier)
                    .patch(budgetAlerts: value),
                last: true,
              ),
            ],
          ),
        ),
        AppButton(
          label: 'Customize Home',
          onTap: () => showCustomizeHomeSheet(context),
        ),
        SectionCaption(
          'Money',
          margin: const EdgeInsets.only(top: 22, bottom: 8),
          key: _moneyKey,
        ),
        AppButton(
          label:
              'Categories · ${settings.categories.keys.where((c) => c != 'Transfer').length}',
          onTap: () => _showCategories(context),
        ),
        AppButton(
          label: 'Tags · ${ref.watch(financeSnapshotProvider).tags.length}',
          onTap: () => _showTags(context),
        ),
        AppButton(
          label: 'Shortcuts · 5 keywords',
          onTap: () => _showShortcuts(context),
        ),
        SectionCaption(
          'Automation',
          margin: const EdgeInsets.only(top: 22, bottom: 8),
          key: _automationKey,
        ),
        AppButton(
          label: 'Notifications',
          onTap: () => _showNotifications(context),
        ),
        AppButton(label: 'AI categorisation', onTap: () => _showAi(context)),
        AppButton(label: 'SMS listener', onTap: () => _showSms(context)),
        SectionCaption(
          'Vault · your data',
          margin: const EdgeInsets.only(top: 30, bottom: 8),
          key: _vaultKey,
        ),
        AppCard(
          child: Row(
            children: [
              IconTile(icon: 'vault', color: c.ac, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stored on this device only',
                      style: AppTypography.sans(size: 14, color: c.tx),
                    ),
                    Text(
                      'AES-256 · no account · no tracking',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppButton(
          label: PinVault.hasPin ? 'PIN & biometrics' : 'Set PIN',
          onTap: () => _showPinVault(context),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Storage used',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value: 0.06,
                  minHeight: 6,
                  backgroundColor: c.c2,
                  valueColor: AlwaysStoppedAnimation(c.ac),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _history.isEmpty || _history.first[0] == 'No backups yet'
                    ? 'Stored locally · no backups yet'
                    : 'Stored locally · last: ${_history.first[0]}',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        const SectionCaption(
          'Export range',
          margin: EdgeInsets.only(top: 12, bottom: 8),
        ),
        SegmentedControl<String>(
          options: const [
            SegmentedOption('m', 'This month'),
            SegmentedOption('f', 'FY 26–27'),
            SegmentedOption('a', 'All time'),
          ],
          selected: _range,
          onChanged: (value) => setState(() => _range = value),
        ),
        for (final label in const [
          'Ledger · CSV',
          'Annual summary · PDF',
          'Statements · XLSX',
          'Full backup · encrypted',
        ])
          AppButton(label: label, onTap: () => _export(label)),
        const SectionCaption(
          'Import & backup',
          margin: EdgeInsets.only(top: 12, bottom: 8),
        ),
        AppButton(
          label: 'Restore from backup file',
          onTap: () => _importBackup(),
        ),
        AppButton(
          label: 'Encrypted backup & restore',
          onTap: () => _showBackup(context),
        ),
        const SectionCaption(
          'Auto-backup',
          margin: EdgeInsets.only(top: 12, bottom: 8),
        ),
        SegmentedControl<String>(
          options: const [
            SegmentedOption('o', 'Off'),
            SegmentedOption('d', 'Daily'),
            SegmentedOption('w', 'Weekly'),
          ],
          selected: _backup,
          onChanged: (value) => setState(() => _backup = value),
        ),
        const SectionCaption(
          'History',
          margin: EdgeInsets.only(top: 12, bottom: 8),
        ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < _history.length; i++)
                KeyValueRow(
                  label: _history[i][0],
                  value: Text(
                    _history[i][1],
                    style: AppTypography.sans(size: 12, color: c.mu),
                  ),
                  border: i < _history.length - 1,
                ),
            ],
          ),
        ),
        AppButton(
          label: 'Erase all data…',
          color: c.co,
          centered: true,
          onTap: () => _erase(context),
        ),
        SectionCaption(
          'App',
          margin: const EdgeInsets.only(top: 22, bottom: 8),
          key: _appKey,
        ),
        AppButton(label: 'Lock app', onTap: widget.onLock),
        AppButton(label: 'Replay welcome', onTap: widget.onReplayWelcome),
        AppButton(
          label: 'Reset demo data',
          color: c.co,
          centered: true,
          onTap: () => _reset(context),
        ),
        const SizedBox(height: 14),
        Text(
          'Spendwiser · v1.0.0',
          textAlign: TextAlign.center,
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
      ],
    );
  }

  Future<void> _export(String label) async {
    ref.read(toastProvider.notifier).show('Preparing $label…');
    try {
      final snapshot = ref.read(financeSnapshotProvider);
      if (label.contains('CSV')) {
        await BackupService.exportLedgerCsv(snapshot, _range);
      } else if (label.contains('PDF')) {
        await BackupService.exportAnnualSummaryPdf(snapshot);
      } else if (label.contains('XLSX')) {
        await BackupService.exportStatementsXlsx(snapshot, _range);
      } else if (label.contains('backup')) {
        await BackupService.exportFullBackup();
      } else {
        await BackupService.exportLedgerCsv(snapshot, _range);
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
      ref.invalidate(mockFinanceStoreProvider);
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
          Container(
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

  void _showCategories(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => const _CategoriesSheet(),
    );
  }

  void _showTags(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => const _TagsSheet(),
    );
  }

  void _showShortcuts(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Shortcuts',
            subtitle: 'Type a keyword in the capture bar and it files itself.',
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                for (final entry in const [
                  ('chai', 'Food'),
                  ('uber', 'Travel'),
                  ('netflix', 'Fun'),
                  ('rent', 'Bills'),
                  ('amazon', 'Shop'),
                ])
                  KeyValueRow(
                    label: entry.$1,
                    value: Text(
                      '→ ${entry.$2}',
                      style: AppTypography.sans(
                        size: 13,
                        color: sheetContext.spend.mu,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    var bill = ref.read(settingsProvider).billReminders;
    var alerts = ref.read(settingsProvider).budgetAlerts;
    var digest = ref.read(settingsProvider).weeklyDigest;
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
                'Daily reminder time',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
              const SizedBox(height: 8),
              Container(
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
                      '20:00',
                      style: AppTypography.sans(size: 14, color: c.tx),
                    ),
                    const Spacer(),
                    SpendIcon('chevronDown', size: 16, color: c.mu),
                  ],
                ),
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
                        weeklyDigest: digest,
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

  void _showAi(BuildContext context) {
    var provider = 'Gemini';
    var enabled = false;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final c = context.spend;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(
                'AI categorisation',
                subtitle: 'Bring your own key. It stays on this device.',
              ),
              SegmentedControl<String>(
                options: const [
                  SegmentedOption('Gemini', 'Gemini'),
                  SegmentedOption('OpenAI', 'OpenAI'),
                  SegmentedOption('Off', 'Off'),
                ],
                selected: provider,
                onChanged: (value) => setSheetState(() => provider = value),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: c.c2,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: TextField(
                  obscureText: true,
                  textAlignVertical: TextAlignVertical.center,
                  style: AppTypography.sans(size: 14, color: c.tx),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: 'API key',
                    hintStyle: AppTypography.sans(size: 13, color: c.mu),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                label: 'Auto-categorise new transactions',
                detail: 'Falls back to your shortcuts when offline',
                value: enabled,
                onChanged: (value) => setSheetState(() => enabled = value),
                last: true,
              ),
              PrimaryButton(
                label: 'Save',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(toastProvider.notifier).show('AI settings saved');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSms(BuildContext context) {
    var listener = false;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final c = context.spend;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(
                'SMS listener',
                subtitle: 'Pair the Android companion so bank SMS become pending transactions.',
              ),
              AppCard(
                child: Column(
                  children: [
                    Text(
                      'Pairing code',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                    Text(
                      '438921',
                      style: AppTypography.serif(
                        size: 48,
                        color: c.tx,
                        letterSpacing: 5,
                      ),
                    ),
                  ],
                ),
              ),
              _ToggleRow(
                label: 'Listener ${listener ? 'connected' : 'not paired'}',
                detail: 'Bank SMS are parsed on-device',
                value: listener,
                onChanged: (value) => setSheetState(() => listener = value),
                last: true,
              ),
              PrimaryButton(
                label: 'Send a test SMS',
                onTap: () async {
                  final accounts = ref.read(financeSnapshotProvider).accounts;
                  await ref
                      .read(transactionRepositoryProvider)
                      .addTransaction(
                        TransactionDraft(
                          merchant: 'Swiggy',
                          category: 'Food',
                          amount: -849,
                          date: DateTime.now(),
                          accountId: accounts.isEmpty
                              ? null
                              : accounts.first.id,
                        ),
                      );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(toastProvider.notifier)
                      .show('SMS parsed · Swiggy ₹849');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPinVault(BuildContext context) {
    var biometrics = PinVault.biometricsEnabled;
    showAppSheet<void>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle('PIN & biometrics'),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    _ToggleRow(
                      label: 'Face ID / fingerprint',
                      detail: 'Fast unlock when available',
                      value: biometrics,
                      onChanged: (v) async {
                        setSheetState(() => biometrics = v);
                        await PinVault.setBiometricsEnabled(v);
                      },
                    ),
                    _ToggleRow(
                      label: 'App PIN',
                      detail: PinVault.hasPin ? 'Set' : 'Not set',
                      value: PinVault.hasPin,
                      onChanged: (v) async {
                        if (!v) {
                          await PinVault.clearPin();
                          setSheetState(() {});
                          ref.read(toastProvider.notifier).show('PIN removed');
                        } else {
                          Navigator.of(sheetContext).pop();
                          _showPinSetup(context);
                        }
                      },
                      last: true,
                    ),
                    if (PinVault.hasPin)
                      AppButton(
                        label: 'Change PIN',
                        centered: true,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _showPinSetup(context);
                        },
                      ),
                  ],
                ),
              ),
              if (!PinVault.hasPin)
                PrimaryButton(
                  label: 'Set PIN',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showPinSetup(context);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  void _showPinSetup(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => const _PinSetupSheet(),
    );
  }

  void _showBackup(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Encrypted backup',
            subtitle:
                'AES-256 with your passphrase. We can’t recover it for you.',
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: sheetContext.spend.c2,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: TextField(
              obscureText: true,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.sans(size: 14, color: sheetContext.spend.tx),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Passphrase',
                hintStyle: AppTypography.sans(
                  size: 13,
                  color: sheetContext.spend.mu,
                ),
              ),
            ),
          ),
          PrimaryButton(
            label: 'Create backup',
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await _export('Full backup');
              ref.read(toastProvider.notifier).show('Backup created');
            },
          ),
          AppButton(
            label: 'Restore from backup',
            centered: true,
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await _importBackup();
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
            'This removes all transactions, accounts and settings from this device. Export a backup first.',
            style: AppTypography.sans(size: 14, color: sheetContext.spend.mu),
          ),
          PrimaryButton(
            label: 'Back up first',
            onTap: () => _export('Full backup · encrypted'),
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
              ref
                  .read(toastProvider.notifier)
                  .show('All data erased');
            },
          ),
        ],
      ),
    );
  }

  void _reset(BuildContext context) {
    showAppSheet<void>(
      context,
      (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('Reset demo data?'),
          Text(
            'Restores Arjun’s seeded accounts, cards, loans and six months of transactions.',
            style: AppTypography.sans(size: 14, color: sheetContext.spend.mu),
          ),
          PrimaryButton(
            label: 'Reset demo data',
            onTap: () async {
              await ref.read(financeRepositoryProvider).resetDemo();
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              widget.onReset();
              ref.read(toastProvider.notifier).show('Demo data restored');
            },
          ),
        ],
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
                Text(
                  'Color',
                  style: AppTypography.sans(size: 12, color: c.mu),
                ),
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
                PrimaryButton(
                  label: 'Add Category',
                  onTap: _add,
                ),
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

  void _save() {
    final newName = _controller.text.trim();
    if (newName.isEmpty) {
      ref.read(toastProvider.notifier).show('Category name cannot be empty');
      return;
    }
    if (newName != widget.name) {
      final existing = ref.read(settingsProvider).categories;
      if (existing.containsKey(newName)) {
        ref.read(toastProvider.notifier).show('Category "$newName" already exists');
        return;
      }
      ref.read(settingsProvider.notifier).editCategory(widget.name, newName, _color);
      ref.read(mockFinanceStoreProvider).renameCategory(widget.name, newName);
    } else {
      ref.read(settingsProvider.notifier).editCategory(widget.name, widget.name, _color);
    }
    ref.read(toastProvider.notifier).show('Saved category');
    Navigator.of(context).pop();
  }

  void _delete() {
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
        Container(
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
        const SizedBox(height: 14),
        Text(
          'Accent Color',
          style: AppTypography.sans(size: 12, color: c.mu),
        ),
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
        PrimaryButton(
          label: 'Save Changes',
          onTap: _save,
        ),
        if (!isProtected) ...[
          const SizedBox(height: 8),
          AppButton(
            label: 'Delete Category',
            color: c.co,
            onTap: _delete,
          ),
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
    showAppSheet<void>(
      context,
      (_) => _EditTagSheet(tag: tag),
    );
  }

  Widget _buildTagRow(String tag, int i, FinanceSnapshot snapshot, BuildContext context) {
    final c = context.spend;
    final count = snapshot.transactions.where((t) => t.tags.contains(tag)).length;
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
                AppPill(
                  label: '#$tag',
                  color: tagColor,
                  textColor: tagColor,
                ),
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
        if (i < snapshot.tags.length - 1)
          Divider(color: c.ln, height: 1),
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
            const SheetTitle('Tags', subtitle: 'Organize your transactions with custom tags'),
            if (!_showAdd)
              GestureDetector(
                onTap: () => setState(() => _showAdd = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.ac,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+ Add',
                    style: AppTypography.sans(size: 12, color: c.aci, weight: FontWeight.w600),
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
                    Text('New tag', style: AppTypography.sans(size: 13, color: c.tx, weight: FontWeight.w600)),
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
            child: Text('No tags yet. Tap "+ Add" to create one.', style: AppTypography.sans(size: 13, color: c.mu)),
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
        Container(
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

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet();

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  String _pin = '';
  bool _confirm = false;
  String _first = '';

  void _append(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      if (!_confirm) {
        setState(() { _first = _pin; _confirm = true; _pin = ''; });
      } else if (_pin == _first) {
        PinVault.setPin(_pin).then((_) {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        setState(() { _pin = ''; _confirm = false; _first = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs do not match')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(_confirm ? 'Confirm PIN' : 'Set a 4-digit PIN',
            subtitle: 'Stored as a hash on this device only.'),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14, height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? c.ac : c.c2,
                  border: Border.all(color: i < _pin.length ? c.ac : c.ln),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final row in [['1','2','3'],['4','5','6'],['7','8','9']])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in row)
                GestureDetector(
                  onTap: () => _append(d),
                  child: Container(
                    width: 72, height: 56, alignment: Alignment.center,
                    child: Text(d, style: AppTypography.sans(size: 22, color: c.tx)),
                  ),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72),
            GestureDetector(
              onTap: () => _append('0'),
              child: Container(width: 72, height: 56, alignment: Alignment.center,
                child: Text('0', style: AppTypography.sans(size: 22, color: c.tx))),
            ),
            GestureDetector(
              onTap: () { if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1)); },
              child: Container(width: 72, height: 56, alignment: Alignment.center,
                child: Text('⌫', style: AppTypography.sans(size: 22, color: c.tx))),
            ),
          ],
        ),
      ],
    );
  }
}
