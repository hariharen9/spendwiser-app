import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hive/hive.dart';
import '../theme/app_colors.dart';
import '../../data/firebase/firestore_finance_store.dart';
import '../../data/firebase/firestore_refs.dart';
import '../../data/firebase/user_profile_repository.dart';
import '../../data/mock/mock_finance_store.dart';
import '../../data/mock/mock_settings_repository.dart';
import 'auth_provider.dart';
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

/// Exported backup payload pulled from the signed-in account's Firestore tree.
Future<Map<String, dynamic>> exportBackup() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return {
      'app': 'spendwiser',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': const AppSettings().toJson(),
      'finance': const <String, dynamic>{},
    };
  }
  final firestore = FirebaseFirestore.instance;
  final refs = FirestoreRefs(firestore, user.uid);
  final profile = FirestoreUserProfileRepository(refs);
  await profile.loadOnce();

  Future<List<Map<String, dynamic>>> rows(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  final groupSnapshot = await refs.splitGroups.get();
  final groups = <Map<String, dynamic>>[];
  for (final group in groupSnapshot.docs) {
    groups.add({
      'id': group.id,
      ...group.data(),
      'expenses': await rows(refs.expenses(group.id)),
      'settledPayments': await rows(refs.settledPayments(group.id)),
    });
  }

  final payload = {
    'app': 'spendwiser',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'settings': profile.current.toJson(),
    'finance': {
      'transactions': await rows(refs.transactions),
      'accounts': await rows(refs.accounts),
      'budgets': await rows(refs.budgets),
      'goals': await rows(refs.goals),
      'loans': await rows(refs.loans),
      'recurring': await rows(refs.recurring),
      'participants': await rows(refs.participants),
      'splitGroups': groups,
      'totalBudget': (await refs.totalBudget.get()).data(),
    },
  };
  profile.dispose();
  return payload;
}

/// Restore: replace the signed-in account's Firestore documents with the
/// payload. The caller invalidates the finance/settings providers afterwards.
Future<void> importBackupPayload(Map<String, dynamic> payload) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Sign in to restore a backup');
  final firestore = FirebaseFirestore.instance;
  final refs = FirestoreRefs(firestore, user.uid);
  final finance = payload['finance'];
  if (finance is Map) {
    await _replaceCollection(refs.transactions, finance['transactions'], firestore);
    await _replaceCollection(refs.accounts, finance['accounts'], firestore);
    await _replaceCollection(refs.budgets, finance['budgets'], firestore);
    await _replaceCollection(refs.goals, finance['goals'], firestore);
    await _replaceCollection(refs.loans, finance['loans'], firestore);
    await _replaceCollection(refs.recurring, finance['recurring'], firestore);
    await _replaceCollection(refs.participants, finance['participants'], firestore);

    final groups = finance['splitGroups'];
    if (groups is List) {
      await _deleteCollectionDocs(refs.splitGroups, firestore);
      for (final raw in groups) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final id = data.remove('id') as String?;
        final expenses = data.remove('expenses');
        final settled = data.remove('settledPayments');
        final doc = id == null ? refs.splitGroups.doc() : refs.splitGroups.doc(id);
        await doc.set(data);
        await _replaceCollection(refs.expenses(doc.id), expenses, firestore);
        await _replaceCollection(refs.settledPayments(doc.id), settled, firestore);
      }
    }

    final totalBudget = finance['totalBudget'];
    if (totalBudget is Map) {
      await refs.totalBudget.set(Map<String, dynamic>.from(totalBudget));
    }
  }
  final settings = payload['settings'];
  if (settings is Map) {
    final profile = FirestoreUserProfileRepository(refs);
    await profile.loadOnce();
    await profile.save(AppSettings.fromJson(Map<String, dynamic>.from(settings)));
    profile.dispose();
  }
}

Future<void> _replaceCollection(
  CollectionReference<Map<String, dynamic>> collection,
  dynamic raw,
  FirebaseFirestore firestore,
) async {
  if (raw is! List) return;
  await _deleteCollectionDocs(collection, firestore);
  var batch = firestore.batch();
  var pending = 0;
  for (final item in raw) {
    if (item is! Map) continue;
    final data = Map<String, dynamic>.from(item);
    final id = data.remove('id') as String?;
    final doc = id == null ? collection.doc() : collection.doc(id);
    batch.set(doc, data);
    pending++;
    if (pending >= 450) {
      await batch.commit();
      batch = firestore.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
}

Future<void> _deleteCollectionDocs(
  CollectionReference<Map<String, dynamic>> collection,
  FirebaseFirestore firestore,
) async {
  final snapshot = await collection.get();
  var batch = firestore.batch();
  var pending = 0;
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
    pending++;
    if (pending >= 450) {
      await batch.commit();
      batch = firestore.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
}

/// In-memory settings adapter. Replacing this with a persisted implementation
final settingsRepositoryProvider = Provider<ISettingsRepository>((ref) {
  final box = _hiveBox('settings');
  if (box != null) return HiveSettingsRepository(box);
  return MockSettingsRepository();
});

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final profile = ref.watch(userProfileRepositoryProvider);
    if (profile == null) return const AppSettings();
    final subscription = profile.watch().listen((next) {
      state = next;
      AppColors.dynamicCategories = Map.of(next.categories);
    });
    ref.onDispose(subscription.cancel);
    return profile.current;
  }

  void update(AppSettings next) {
    state = next;
    AppColors.dynamicCategories = Map.of(next.categories);
    final profile = ref.read(userProfileRepositoryProvider);
    if (profile != null) {
      profile.save(next);
    } else {
      ref.read(settingsRepositoryProvider).save(next);
    }
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

/// Profile/settings/tags for the signed-in Firebase user.
final userProfileRepositoryProvider =
    Provider<FirestoreUserProfileRepository?>((ref) {
      final uid = ref.watch(authUidProvider);
      if (uid == null) return null;
      final repository = FirestoreUserProfileRepository(
        FirestoreRefs(FirebaseFirestore.instance, uid),
      );
      ref.keepAlive();
      ref.onDispose(repository.dispose);
      return repository;
    });

/// In-memory seed used only when signed out and by unit tests.
final mockFinanceStoreProvider = Provider<MockFinanceStore>((ref) {
  final store = MockFinanceStore.seeded();
  ref.onDispose(store.dispose);
  return store;
});

final firestoreFinanceStoreProvider = Provider<FirestoreFinanceStore?>((ref) {
  final profile = ref.watch(userProfileRepositoryProvider);
  if (profile == null) return null;
  final store = FirestoreFinanceStore(
    refs: profile.refs,
    profile: profile,
    onError: (message) => ref.read(toastProvider.notifier).show(message),
  );
  ref.keepAlive();
  ref.onDispose(store.dispose);
  return store;
});

final financeRepositoryProvider = Provider<IFinanceRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

final accountRepositoryProvider = Provider<IAccountRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

final cardRepositoryProvider = Provider<ICardRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

final loanRepositoryProvider = Provider<ILoanRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

final budgetRepositoryProvider = Provider<IBudgetRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

final goalRepositoryProvider = Provider<IGoalRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

final subscriptionRepositoryProvider = Provider<ISubscriptionRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

final splitRepositoryProvider = Provider<ISplitRepository>((ref) {
  return ref.watch(firestoreFinanceStoreProvider) ??
      ref.watch(mockFinanceStoreProvider);
});

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
