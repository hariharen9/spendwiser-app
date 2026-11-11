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
import '../../data/services/backup_codec.dart';
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
import '../../data/repositories/i_shortcut_repository.dart';
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

/// Builds a backup that the web's Restore UI accepts (top-level collections)
/// and also includes the `entities` wrapper used by the migration export.
Future<Map<String, dynamic>> exportBackup() async {
  final user = FirebaseAuth.instance.currentUser;
  final exportedAt = DateTime.now().toUtc().toIso8601String();
  if (user == null) {
    const settings = AppSettings();
    final webSettings = <String, dynamic>{
      'darkMode': settings.isDark,
      'currency': '₹',
      'defaultAccountId': null,
      'fontPreference': 'Montserrat',
      'userDoc': const <String, dynamic>{},
    };
    final emptySplits = <String, dynamic>{
      'participants': const [],
      'groups': const [],
      'expenses': const [],
      'settledPayments': const [],
    };
    return {
      'app': 'spendwiser',
      'version': 1,
      'exportedAt': exportedAt,
      'currency': '₹',
      'themePreference': 'dark',
      'baseCurrencyCode': 'INR',
      'transactions': const [],
      'accounts': const [],
      'budgets': const [],
      'goals': const [],
      'loans': const [],
      'recurringTransactions': const [],
      'shortcuts': const [],
      'pendingTransactions': const [],
      'billSplitting': emptySplits,
      'totalBudget': null,
      'userCategories': settings.categories.keys.toList(),
      'settings': webSettings,
      'mobileSettings': settings.toJson(),
      'metadata': {
        'backupDate': exportedAt,
        'version': '1.0.0',
        'exportedBy': '',
        'uid': '',
      },
      'entities': {
        'transactions': const [],
        'accounts': const [],
        'budgets': const [],
        'goals': const [],
        'loans': const [],
        'recurringTransactions': const [],
        'shortcuts': const [],
        'pendingTransactions': const [],
        'billSplitting': emptySplits,
        'totalBudget': const [],
      },
    };
  }

  final firestore = FirebaseFirestore.instance;
  final refs = FirestoreRefs(firestore, user.uid);
  final profile = FirestoreUserProfileRepository(refs);
  await profile.loadOnce();
  final userSnap = await refs.user.get();
  final userData = userSnap.data() ?? const <String, dynamic>{};
  final currency = (userData['currency'] as String?) ?? '₹';
  final fontPreference =
      (userData['fontPreference'] as String?) ?? 'Montserrat';

  Future<List<Map<String, dynamic>>> rows(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    return snapshot.docs.map((doc) {
      final data = <String, dynamic>{'id': doc.id, ...doc.data()};
      return Map<String, dynamic>.from(jsonSafe(data) as Map);
    }).toList();
  }

  final transactions = await rows(refs.transactions);
  final accounts = await rows(refs.accounts);
  final budgets = await rows(refs.budgets);
  final goals = await rows(refs.goals);
  final loans = await rows(refs.loans);
  final recurring = await rows(refs.recurring);
  final shortcuts = await rows(refs.shortcuts);
  final pending = await rows(refs.user.collection('pending_transactions'));
  final participants = await rows(refs.participants);
  final groups = await rows(refs.splitGroups);

  final groupExpenses = <Map<String, dynamic>>[];
  final groupSettlements = <Map<String, dynamic>>[];
  for (final group in groups) {
    final groupId = '${group['id']}';
    final expenseSnapshot = await refs.expenses(groupId).get();
    for (final doc in expenseSnapshot.docs) {
      groupExpenses.add({
        'groupId': groupId,
        'docId': doc.id,
        'data': jsonSafe(doc.data()),
      });
    }
    final settlementSnapshot = await refs.settledPayments(groupId).get();
    for (final doc in settlementSnapshot.docs) {
      groupSettlements.add({
        'groupId': groupId,
        'docId': doc.id,
        'data': jsonSafe(doc.data()),
      });
    }
  }

  final totalBudgetSnap = await refs.totalBudget.get();
  final totalBudgetData = totalBudgetSnap.exists
      ? jsonSafe(totalBudgetSnap.data())
      : null;
  final totalBudgetMap = totalBudgetData is Map
      ? {'id': 'current', ...Map<String, dynamic>.from(totalBudgetData)}
      : null;
  final totalBudgetList = totalBudgetData is Map
      ? [
          {'id': 'current', ...Map<String, dynamic>.from(totalBudgetData)},
        ]
      : const <Map<String, dynamic>>[];

  final userDoc = Map<String, dynamic>.from(jsonSafe(userData) as Map);
  final webSettings = <String, dynamic>{
    'darkMode': profile.current.isDark,
    'currency': currency,
    'defaultAccountId': profile.defaultAccountId,
    'fontPreference': fontPreference,
    'userDoc': userDoc,
  };
  final userCategories = profile.current.categories.keys.toList();
  final mobileSettings = profile.current.toJson();
  final themePreference = profile.current.isDark ? 'dark' : 'light';
  final billSplitting = <String, dynamic>{
    'participants': participants,
    'groups': groups,
    'expenses': groupExpenses,
    'settledPayments': groupSettlements,
  };
  final metadata = <String, dynamic>{
    'backupDate': exportedAt,
    'version': '1.0.0',
    'exportedBy': user.email ?? user.uid,
    'uid': user.uid,
  };
  final entities = <String, dynamic>{
    'transactions': transactions,
    'accounts': accounts,
    'budgets': budgets,
    'goals': goals,
    'loans': loans,
    'recurringTransactions': recurring,
    'shortcuts': shortcuts,
    'pendingTransactions': pending,
    'billSplitting': billSplitting,
    'totalBudget': totalBudgetList,
  };

  profile.dispose();
  return {
    'app': 'spendwiser',
    'version': 1,
    'exportedAt': exportedAt,
    'currency': currency,
    'themePreference': themePreference,
    'baseCurrencyCode': _currencyCode(currency),
    'transactions': transactions,
    'accounts': accounts,
    'budgets': budgets,
    'goals': goals,
    'loans': loans,
    'recurringTransactions': recurring,
    'shortcuts': shortcuts,
    'pendingTransactions': pending,
    'billSplitting': billSplitting,
    'totalBudget': totalBudgetMap,
    'userCategories': userCategories,
    'settings': webSettings,
    'mobileSettings': mobileSettings,
    'metadata': metadata,
    'entities': entities,
  };
}

String _currencyCode(String symbol) => switch (symbol) {
  '₹' => 'INR',
  '\$' => 'USD',
  '€' => 'EUR',
  '£' => 'GBP',
  'AED' => 'AED',
  'S\$' => 'SGD',
  'A\$' => 'AUD',
  'C\$' => 'CAD',
  '¥' => 'JPY',
  _ => symbol.length == 3 ? symbol.toUpperCase() : 'INR',
};

/// Restore: replace the signed-in account's Firestore documents with the
/// payload. Accepts the web backup shape, the migration `entities` shape and
/// the older app `finance` shape.
Future<void> importBackupPayload(Map<String, dynamic> payload) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Sign in to restore a backup');
  final firestore = FirebaseFirestore.instance;
  final refs = FirestoreRefs(firestore, user.uid);
  final backup = normalizeBackupPayload(payload);

  if (backup.transactions != null) {
    await _replaceDocs(refs.transactions, backup.transactions!, firestore);
  }
  if (backup.accounts != null) {
    await _replaceDocs(refs.accounts, backup.accounts!, firestore);
  }
  if (backup.budgets != null) {
    await _replaceDocs(refs.budgets, backup.budgets!, firestore);
  }
  if (backup.goals != null) {
    await _replaceDocs(refs.goals, backup.goals!, firestore);
  }
  if (backup.loans != null) {
    await _replaceDocs(refs.loans, backup.loans!, firestore);
  }
  if (backup.recurring != null) {
    await _replaceDocs(refs.recurring, backup.recurring!, firestore);
  }
  if (backup.shortcuts != null) {
    await _replaceDocs(refs.shortcuts, backup.shortcuts!, firestore);
  }
  if (backup.pending != null) {
    await _replaceDocs(
      refs.user.collection('pending_transactions'),
      backup.pending!,
      firestore,
    );
  }

  if (backup.hasBillSplitting) {
    await _replaceDocs(refs.participants, backup.participants, firestore);
    await _deleteCollectionDocs(refs.splitGroups, firestore);
    for (final group in backup.groups) {
      final groupRef = group.id.isEmpty
          ? refs.splitGroups.doc()
          : refs.splitGroups.doc(group.id);
      await groupRef.set(_withTimestamps(group.data, ['createdAt']));
      final groupExpenses = backup.expenses
          .where((expense) => expense.groupId == group.id)
          .toList();
      await _replaceDocs(
        refs.expenses(groupRef.id),
        groupExpenses,
        firestore,
        timestampFields: ['createdAt', 'updatedAt'],
      );
      final groupSettlements = backup.settlements
          .where((settlement) => settlement.groupId == group.id)
          .toList();
      await _replaceDocs(
        refs.settledPayments(groupRef.id),
        groupSettlements,
        firestore,
        timestampFields: ['createdAt'],
      );
    }
  }

  if (backup.totalBudgetPresent) {
    if (backup.totalBudget != null) {
      await refs.totalBudget.set(backup.totalBudget!.data);
    } else {
      await refs.totalBudget.delete();
    }
  }

  if (backup.userDoc != null && backup.userDoc!.isNotEmpty) {
    await refs.user.set(backup.userDoc!, SetOptions(merge: true));
  }
  if (backup.webSettings != null) {
    final settings = backup.webSettings!;
    final updates = <String, dynamic>{};
    if (settings['darkMode'] is bool) {
      updates['themePreference'] = settings['darkMode'] == true
          ? 'dark'
          : 'light';
    }
    if (settings['currency'] is String) {
      updates['currency'] = settings['currency'];
    }
    if (settings['defaultAccountId'] is String) {
      updates['defaultAccountId'] = settings['defaultAccountId'];
    }
    if (settings['fontPreference'] is String) {
      updates['fontPreference'] = settings['fontPreference'];
    }
    if (updates.isNotEmpty) {
      await refs.user.set(updates, SetOptions(merge: true));
    }
  }
  if (backup.categories != null) {
    await refs.user.set({
      'categories': backup.categories,
    }, SetOptions(merge: true));
  }
  if (backup.appSettings != null) {
    final profile = FirestoreUserProfileRepository(refs);
    await profile.loadOnce();
    await profile.save(AppSettings.fromJson(backup.appSettings!));
    profile.dispose();
  }
}

Future<void> _replaceDocs(
  CollectionReference<Map<String, dynamic>> collection,
  List<BackupDoc> docs,
  FirebaseFirestore firestore, {
  List<String> timestampFields = const [],
}) async {
  await _deleteCollectionDocs(collection, firestore);
  var batch = firestore.batch();
  var pending = 0;
  for (final item in docs) {
    final doc = item.id.isEmpty ? collection.doc() : collection.doc(item.id);
    batch.set(doc, _withTimestamps(item.data, timestampFields));
    pending++;
    if (pending >= 450) {
      await batch.commit();
      batch = firestore.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
}

Map<String, dynamic> _withTimestamps(
  Map<String, dynamic> data,
  List<String> fields,
) {
  final copy = Map<String, dynamic>.from(data);
  for (final field in fields) {
    final value = copy[field];
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) copy[field] = Timestamp.fromDate(parsed);
    } else if (value is Map && value['seconds'] is num) {
      copy[field] = Timestamp(
        (value['seconds'] as num).toInt(),
        ((value['nanoseconds'] as num?) ?? 0).toInt(),
      );
    }
  }
  return copy;
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
    AppNavigationMode? navigation,
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
    bool? dailyReminder,
    bool? weeklyDigest,
    bool? smsCaptureEnabled,
    int? reminderHour,
    int? reminderMinute,
    Map<String, Color>? categories,
  }) {
    update(
      state.copyWith(
        theme: theme,
        accent: accent,
        font: font,
        navigation: navigation,
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
        dailyReminder: dailyReminder,
        weeklyDigest: weeklyDigest,
        smsCaptureEnabled: smsCaptureEnabled,
        reminderHour: reminderHour,
        reminderMinute: reminderMinute,
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
final userProfileRepositoryProvider = Provider<FirestoreUserProfileRepository?>(
  (ref) {
    final uid = ref.watch(authUidProvider);
    if (uid == null) return null;
    final repository = FirestoreUserProfileRepository(
      FirestoreRefs(FirebaseFirestore.instance, uid),
    );
    ref.keepAlive();
    ref.onDispose(repository.dispose);
    return repository;
  },
);

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

final shortcutRepositoryProvider = Provider<IShortcutRepository>((ref) {
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
