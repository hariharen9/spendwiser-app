import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hive/hive.dart';
import '../theme/app_colors.dart';
import '../../data/mock/mock_finance_store.dart';
import '../../data/mock/mock_settings_repository.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/repositories/i_account_repository.dart';
import '../../data/repositories/i_budget_repository.dart';
import '../../data/repositories/i_card_repository.dart';
import '../../data/repositories/i_finance_repository.dart';
import '../../data/repositories/i_goal_repository.dart';
import '../../data/repositories/i_loan_repository.dart';
import '../../data/repositories/i_settings_repository.dart';
import '../../data/repositories/i_split_repository.dart';
import '../../data/repositories/i_transaction_repository.dart';
import '../../data/repositories/i_subscription_repository.dart';
import '../../data/persistence/hive_persistence.dart';
export 'security_provider.dart';

/// Returns the already-open Hive box for [name], or null in tests / not yet
/// initialized. Never throws.
Box<String>? _hiveBox(String name) {
  try {
    if (Hive.isBoxOpen(name)) return Hive.box(name);
  } catch (_) {}
  return null;
}

AppSettings loadPersistedSettings() {
  final box = _hiveBox('settings');
  if (box == null) return const AppSettings();
  return HiveSettingsRepository(box).loadSync();
}

/// Exported backup payload (settings + finance state).
Future<Map<String, dynamic>> exportBackup() async {
  final box = _hiveBox('finance');
  final financeRaw = box?.get('financeStateJson');
  Map<String, dynamic> finance = {};
  if (financeRaw != null && financeRaw.isNotEmpty) {
    finance = jsonDecode(financeRaw) as Map<String, dynamic>;
  }
  final settingsBox = _hiveBox('settings');
  final settings = settingsBox == null
      ? const AppSettings().toJson()
      : HiveSettingsRepository(settingsBox).loadSync().toJson();
  return {
    'app': 'spendwiser',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'settings': settings,
    'finance': finance,
  };
}

/// Restore: write backup payload into the Hive boxes. Caller must then
/// invalidate the finance + settings providers so they rebuild from disk.
Future<void> importBackupPayload(Map<String, dynamic> payload) async {
  final financeBox = _hiveBox('finance');
  if (financeBox == null) {
    throw StateError('Finance storage is not open');
  }
  final finance = payload['finance'];
  if (finance is Map) {
    await financeBox.put(
      'financeStateJson',
      jsonEncode(finance),
    );
  }
  final settingsBox = _hiveBox('settings');
  final settings = payload['settings'];
  if (settingsBox != null && settings is Map) {
    final json = Map<String, dynamic>.from(settings);
    await settingsBox.put('settingsJson', jsonEncode(json));
  }
}

/// In-memory settings adapter. Replacing this with a persisted implementation
final settingsRepositoryProvider = Provider<ISettingsRepository>((ref) {
  final box = _hiveBox('settings');
  if (box != null) return HiveSettingsRepository(box);
  return MockSettingsRepository();
});

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => loadPersistedSettings();

  void update(AppSettings next) {
    state = next;
    AppColors.dynamicCategories = Map.of(next.categories);
    ref.read(settingsRepositoryProvider).save(next);
  }

  void patch({
    AppThemeMode? theme,
    Color? accent,
    AppFontMode? font,
    String? userName,
    bool? hideBalances,
    bool? haptics,
    bool? budgetAlerts,
    bool? onboardingSeen,
    bool? roundUps,
    int? monthStart,
    List<HomeWidget>? homeWidgets,
    Set<HomeWidget>? hiddenWidgets,
    bool? billReminders,
    bool? weeklyDigest,
    Map<String, Color>? categories,
  }) {
    update(
      state.copyWith(
        theme: theme,
        accent: accent,
        font: font,
        userName: userName,
        hideBalances: hideBalances,
        haptics: haptics,
        budgetAlerts: budgetAlerts,
        onboardingSeen: onboardingSeen,
        roundUps: roundUps,
        monthStart: monthStart,
        homeWidgets: homeWidgets,
        hiddenWidgets: hiddenWidgets,
        billReminders: billReminders,
        weeklyDigest: weeklyDigest,
        categories: categories,
      ),
    );
    if (haptics != null) Haptics.enabled = haptics;
  }

  void addCategory(String name, Color color) {
    final next = Map<String, Color>.from(state.categories);
    next[name] = color;
    patch(categories: next);
  }

  void editCategory(String oldName, String newName, Color color) {
    final next = <String, Color>{};
    for (final entry in state.categories.entries) {
      if (entry.key == oldName) {
        next[newName] = color;
      } else {
        next[entry.key] = entry.value;
      }
    }
    patch(categories: next);
  }

  void deleteCategory(String name) {
    final next = Map<String, Color>.from(state.categories);
    next.remove(name);
    patch(categories: next);
  }

  void reorderCategories(int oldIndex, int newIndex) {
    final list = state.categories.entries.toList();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    final next = Map<String, Color>.fromEntries(list);
    patch(categories: next);
  }

  void toggleTheme() {
    patch(theme: state.isDark ? AppThemeMode.light : AppThemeMode.dark);
    Haptics.light();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// ------------------------------------------------------------- finance DI ---

final mockFinanceStoreProvider = Provider<MockFinanceStore>((ref) {
  final box = _hiveBox('finance');
  final persister = box == null ? null : HiveFinancePersister(box);
  final store = MockFinanceStore.seeded(
    loadState: persister?.loadState,
    saveState: persister?.saveState,
  );
  ref.onDispose(store.dispose);
  return store;
});

final financeRepositoryProvider = Provider<IFinanceRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

final transactionRepositoryProvider = Provider<ITransactionRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

final accountRepositoryProvider = Provider<IAccountRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

final cardRepositoryProvider = Provider<ICardRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

final loanRepositoryProvider = Provider<ILoanRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

final budgetRepositoryProvider = Provider<IBudgetRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

final goalRepositoryProvider = Provider<IGoalRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

final subscriptionRepositoryProvider = Provider<ISubscriptionRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

final splitRepositoryProvider = Provider<ISplitRepository>(
  (ref) => ref.watch(mockFinanceStoreProvider),
);

class FinanceSnapshotNotifier extends Notifier<FinanceSnapshot> {
  @override
  FinanceSnapshot build() {
    final repository = ref.watch(financeRepositoryProvider);
    final subscription = repository.watch().listen((snapshot) {
      state = snapshot;
    });
    ref.onDispose(subscription.cancel);
    return repository.current;
  }
}

final financeSnapshotProvider =
    NotifierProvider<FinanceSnapshotNotifier, FinanceSnapshot>(
      FinanceSnapshotNotifier.new,
    );

// ------------------------------------------------------------------ toast ---

@immutable
class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.text,
    this.undoLabel,
    this.onUndo,
    this.duration = const Duration(milliseconds: 1800),
  });

  final int id;
  final String text;
  final String? undoLabel;
  final VoidCallback? onUndo;
  final Duration duration;
}

class ToastNotifier extends Notifier<ToastMessage?> {
  Timer? _timer;

  @override
  ToastMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(
    String text, {
    String? undoLabel,
    VoidCallback? onUndo,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    _timer?.cancel();
    state = ToastMessage(
      id: DateTime.now().microsecondsSinceEpoch,
      text: text,
      undoLabel: undoLabel,
      onUndo: onUndo,
      duration: duration,
    );
    _timer = Timer(duration, () {
      if (state != null) state = null;
    });
  }

  void hide() {
    _timer?.cancel();
    state = null;
  }
}

final toastProvider = NotifierProvider<ToastNotifier, ToastMessage?>(
  ToastNotifier.new,
);

// --------------------------------------------------------------- haptics ---

abstract final class Haptics {
  static bool enabled = true;

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
