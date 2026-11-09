import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../data/repositories/i_subscription_repository.dart';
import '../../data/repositories/i_transaction_repository.dart';

/// In-memory settings adapter. Replacing this with a persisted implementation
/// does not touch any screen.
final settingsRepositoryProvider = Provider<ISettingsRepository>(
  (ref) => MockSettingsRepository(),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void update(AppSettings next) {
    state = next;
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
      ),
    );
    if (haptics != null) Haptics.enabled = haptics;
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
  final store = MockFinanceStore.seeded();
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

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
