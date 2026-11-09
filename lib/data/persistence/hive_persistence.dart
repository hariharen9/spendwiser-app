import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/app_settings.dart';
import '../repositories/i_settings_repository.dart';

/// Hive-backed persistence for settings (Phase 1 local storage).
///
/// The repository contract is unchanged; the only difference from
/// MockSettingsRepository is that save() writes to a Hive box so
/// AppSettings survive an app restart.
class HiveSettingsRepository implements ISettingsRepository {
  HiveSettingsRepository(this._box);

  final Box<String> _box;
  static const _key = 'settingsJson';

  AppSettings loadSync() {
    final raw = _box.get(_key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (_) {
      // Corrupt payload -> fall back to defaults rather than crashing.
      return const AppSettings();
    }
  }

  @override
  Future<AppSettings> load() async => loadSync();

  @override
  Future<void> save(AppSettings settings) async {
    await _box.put(_key, jsonEncode(settings.toJson()));
  }
}

/// Adapter that turns a Hive box into the load/save callbacks consumed by
/// MockFinanceStore.
class HiveFinancePersister {
  HiveFinancePersister(this._box);

  final Box<String> _box;
  static const _key = 'financeStateJson';

  bool get hasSavedState {
    final raw = _box.get(_key);
    return raw != null && raw.isNotEmpty;
  }

  Map<String, dynamic>? loadState() {
    final raw = _box.get(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  void saveState(Map<String, dynamic> state) {
    // Fire-and-forget write; Hive persists to disk asynchronously.
    // The in-memory snapshot remains the source of truth this session.
    _box.put(_key, jsonEncode(state));
  }
}
