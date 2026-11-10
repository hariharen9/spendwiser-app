import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/app_settings.dart';
import 'firestore_mappers.dart';
import 'firestore_refs.dart';
import 'firestore_utils.dart';

const webDefaultCategories = <String>[
  'Home',
  'Groceries',
  'Food & Dining',
  'Transportation',
  'Entertainment',
  'Shopping',
  'Personal',
  'Fuel',
  'Utilities',
  'Healthcare',
  'Education',
  'Bills & EMIs',
  'Rent & Housing',
  'Investment',
  'Travel',
  'Other',
];

class UserTag {
  const UserTag({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final String color;
}

/// Owns `spenders/{uid}`: settings, categories, tags and default account.
class FirestoreUserProfileRepository {
  FirestoreUserProfileRepository(this.refs);

  final FirestoreRefs refs;
  final _controller = StreamController<AppSettings>.broadcast();

  AppSettings _settings = const AppSettings();
  List<UserTag> _tags = const [];
  Map<String, String> _tagIdToName = const {};
  Map<String, String> _tagNameToId = const {};
  List<String> _lastRemoteCategories = const [];
  String? _defaultAccountId;
  String? _email;

  AppSettings get current => _settings;
  List<UserTag> get tags => _tags;
  Map<String, String> get tagIdToName => _tagIdToName;
  Map<String, String> get tagNameToId => _tagNameToId;
  String? get defaultAccountId => _defaultAccountId;
  String? get email => _email;

  Stream<AppSettings> watch() async* {
    yield _settings;
    await for (final snapshot in refs.user.snapshots()) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      _apply(data, exists: snapshot.exists);
      yield _settings;
    }
  }

  Future<void> loadOnce() async {
    final snapshot = await refs.user.get();
    _apply(
      snapshot.data() ?? const <String, dynamic>{},
      exists: snapshot.exists,
    );
  }

  Future<void> ensureProfile({String? email, String? displayName}) async {
    final snapshot = await refs.user.get();
    if (snapshot.exists) return;
    final name = (displayName == null || displayName.trim().isEmpty)
        ? (email?.split('@').first ?? 'You')
        : displayName.trim();
    await refs.user.set({
      'name': name,
      'email': email,
      'categories': webDefaultCategories,
      'themePreference': 'dark',
      'fontPreference': 'Montserrat',
      'timezone': 'Asia/Kolkata',
      'mobilePrefs': {'onboardingSeen': false},
      'createdAt': nowIso(),
    });
  }

  void _apply(Map<String, dynamic> data, {required bool exists}) {
    _email = asString(data['email']).isEmpty ? null : asString(data['email']);
    _defaultAccountId = asString(data['defaultAccountId']).isEmpty
        ? null
        : asString(data['defaultAccountId']);

    final mobilePrefs = asMap(data['mobilePrefs']);
    final categories = asStringList(data['categories']);
    final names = categories.isEmpty ? webDefaultCategories : categories;
    _lastRemoteCategories = names;

    final colorOverrides = <String, Color>{};
    asMap(mobilePrefs['categoryColors']).forEach((key, value) {
      colorOverrides[key] = Color(asInt(value, AppColors.ac.toARGB32()));
    });

    final categoryMap = <String, Color>{};
    for (var i = 0; i < names.length; i++) {
      categoryMap[names[i]] = categoryColorFor(names[i], i, colorOverrides);
    }

    final rawTags = (data['tags'] as List?) ?? const <dynamic>[];
    _tags = rawTags
        .map((raw) {
          final tag = asMap(raw);
          return UserTag(
            id: asString(tag['id']),
            name: asString(tag['name']),
            color: asString(tag['color'], 'blue'),
          );
        })
        .where((tag) => tag.id.isNotEmpty)
        .toList(growable: false);
    _tagIdToName = {for (final tag in _tags) tag.id: tag.name};
    _tagNameToId = {for (final tag in _tags) tag.name: tag.id};

    final fontName = asString(mobilePrefs['font']);
    final font = AppFontMode.values.firstWhere(
      (mode) => mode.name == fontName,
      orElse: () => AppFontMode.dmSans,
    );
    final theme = asString(data['themePreference'], 'dark') == 'light'
        ? AppThemeMode.light
        : AppThemeMode.dark;

    _settings = AppSettings(
      theme: theme,
      accent: Color(asInt(mobilePrefs['accent'], AppColors.ac.toARGB32())),
      font: font,
      userName: asString(data['name'], _email ?? 'You'),
      hideBalances: asBool(mobilePrefs['hideBalances']),
      haptics: asBool(mobilePrefs['haptics'], true),
      budgetAlerts: asBool(mobilePrefs['budgetAlerts'], true),
      onboardingSeen: asBool(
        mobilePrefs['onboardingSeen'],
        exists && mobilePrefs.isEmpty,
      ),
      roundUps: asBool(mobilePrefs['roundUps']),
      monthStart: asInt(mobilePrefs['monthStart'], 1),
      homeWidgets: _homeWidgets(mobilePrefs['homeWidgets'], defaultHomeWidgets),
      hiddenWidgets: _homeWidgets(
        mobilePrefs['hiddenWidgets'],
        const [],
      ).toSet(),
      billReminders: asBool(mobilePrefs['billReminders'], true),
      dailyReminder: asBool(mobilePrefs['dailyReminder'], true),
      weeklyDigest: asBool(mobilePrefs['weeklyDigest']),
      smsCaptureEnabled: asBool(mobilePrefs['smsCaptureEnabled'], true),
      reminderHour: asInt(mobilePrefs['reminderHour'], 20).clamp(0, 23).toInt(),
      reminderMinute: asInt(
        mobilePrefs['reminderMinute'],
        0,
      ).clamp(0, 59).toInt(),
      categories: categoryMap,
    );
    _controller.add(_settings);
  }

  List<HomeWidget> _homeWidgets(dynamic raw, List<HomeWidget> fallback) {
    final list = asStringList(raw);
    if (list.isEmpty) return List.of(fallback);
    return list
        .map(
          (name) => HomeWidget.values.firstWhere(
            (widget) => widget.name == name,
            orElse: () => HomeWidget.netWorth,
          ),
        )
        .where((widget) => widget != HomeWidget.forecast)
        .toList();
  }

  Future<void> save(AppSettings settings) async {
    final categories = settings.categories.keys.toList();
    final categoriesChanged = !listEquals(categories, _lastRemoteCategories);
    _lastRemoteCategories = categories;
    _settings = settings;
    await refs.user.update({
      'name': settings.userName,
      'themePreference': settings.isDark ? 'dark' : 'light',
      if (categoriesChanged) 'categories': categories,
      'mobilePrefs': {
        'font': settings.font.name,
        'accent': settings.accent.toARGB32(),
        'hideBalances': settings.hideBalances,
        'haptics': settings.haptics,
        'budgetAlerts': settings.budgetAlerts,
        'onboardingSeen': settings.onboardingSeen,
        'roundUps': settings.roundUps,
        'monthStart': settings.monthStart,
        'homeWidgets': settings.homeWidgets.map((w) => w.name).toList(),
        'hiddenWidgets': settings.hiddenWidgets.map((w) => w.name).toList(),
        'billReminders': settings.billReminders,
        'dailyReminder': settings.dailyReminder,
        'weeklyDigest': settings.weeklyDigest,
        'smsCaptureEnabled': settings.smsCaptureEnabled,
        'reminderHour': settings.reminderHour,
        'reminderMinute': settings.reminderMinute,
        'categoryColors': settings.categories.map(
          (key, value) => MapEntry(key, value.toARGB32()),
        ),
      },
    });
  }

  Future<void> setDefaultAccountId(String? accountId) async {
    final value = accountId == null || accountId.isEmpty ? null : accountId;
    _defaultAccountId = value;
    await refs.user.update({'defaultAccountId': value ?? ''});
  }

  Future<Map<String, String>> ensureTagIds(List<String> names) async {
    final missing = names
        .where((name) => name.isNotEmpty && !_tagNameToId.containsKey(name))
        .toSet();
    if (missing.isEmpty) return _tagNameToId;

    final nextTags = List<UserTag>.from(_tags);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var index = 0;
    for (final name in missing) {
      nextTags.add(
        UserTag(id: 'tag_${stamp}_${index++}', name: name, color: 'blue'),
      );
    }
    await refs.user.update({
      'tags': nextTags
          .map((tag) => {'id': tag.id, 'name': tag.name, 'color': tag.color})
          .toList(),
    });
    _tags = nextTags;
    _tagIdToName = {for (final tag in _tags) tag.id: tag.name};
    _tagNameToId = {for (final tag in _tags) tag.name: tag.id};
    return _tagNameToId;
  }

  Future<void> addTag(String name) async {
    if (name.trim().isEmpty || _tagNameToId.containsKey(name)) return;
    await ensureTagIds([name]);
  }

  Future<void> renameTag(String oldName, String newName) async {
    if (newName.trim().isEmpty || oldName == newName) return;
    final nextTags = _tags
        .map(
          (tag) => tag.name == oldName
              ? UserTag(id: tag.id, name: newName, color: tag.color)
              : tag,
        )
        .toList();
    await refs.user.update({
      'tags': nextTags
          .map((tag) => {'id': tag.id, 'name': tag.name, 'color': tag.color})
          .toList(),
    });
    _tags = nextTags;
    _tagIdToName = {for (final tag in _tags) tag.id: tag.name};
    _tagNameToId = {for (final tag in _tags) tag.name: tag.id};
  }

  Future<void> removeTag(String name) async {
    final nextTags = _tags.where((tag) => tag.name != name).toList();
    await refs.user.update({
      'tags': nextTags
          .map((tag) => {'id': tag.id, 'name': tag.name, 'color': tag.color})
          .toList(),
    });
    _tags = nextTags;
    _tagIdToName = {for (final tag in _tags) tag.id: tag.name};
    _tagNameToId = {for (final tag in _tags) tag.name: tag.id};
  }

  void dispose() => _controller.close();
}
