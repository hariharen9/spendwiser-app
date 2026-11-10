import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppThemeMode { dark, light }

enum AppFontMode { dmSans, serif, mono }

/// Reorderable / hideable Home widgets, mirroring the prototype's Customize
/// Home sheet.
enum HomeWidget {
  netWorth('Balance'),
  quickAdd('Quick add'),
  safeRing('Cash runway'),
  comingUp('Coming up'),
  streak('Streak & buffer'),
  forecast('Cash-flow forecast'),
  goals('Goals'),
  recent('Recent');

  const HomeWidget(this.label);
  final String label;
}

/// Default Home layout. The old standalone forecast card is folded into the
/// cash-runway hero, so it is intentionally excluded.
const defaultHomeWidgets = <HomeWidget>[
  HomeWidget.netWorth,
  HomeWidget.quickAdd,
  HomeWidget.safeRing,
  HomeWidget.comingUp,
  HomeWidget.streak,
  HomeWidget.goals,
  HomeWidget.recent,
];

@immutable
class AppSettings {
  const AppSettings({
    this.theme = AppThemeMode.dark,
    this.accent = AppColors.ac,
    this.font = AppFontMode.dmSans,
    this.userName = 'Arjun',
    this.hideBalances = false,
    this.haptics = true,
    this.budgetAlerts = true,
    this.onboardingSeen = false,
    this.roundUps = false,
    this.monthStart = 1,
    this.homeWidgets = defaultHomeWidgets,
    this.hiddenWidgets = const <HomeWidget>{},
    this.billReminders = true,
    this.dailyReminder = true,
    this.weeklyDigest = false,
    this.smsCaptureEnabled = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.categories = AppColors.categories,
  });

  final AppThemeMode theme;
  final Color accent;
  final AppFontMode font;
  final String userName;
  final bool hideBalances;
  final bool haptics;
  final bool budgetAlerts;
  final bool onboardingSeen;
  final bool roundUps;
  final int monthStart;
  final List<HomeWidget> homeWidgets;
  final Set<HomeWidget> hiddenWidgets;
  final bool billReminders;
  final bool dailyReminder;
  final bool weeklyDigest;
  final bool smsCaptureEnabled;
  final int reminderHour;
  final int reminderMinute;
  final Map<String, Color> categories;

  bool get isDark => theme == AppThemeMode.dark;

  String get reminderLabel =>
      '${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}';

  String get initials {
    final parts = userName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'AR';
    if (parts.length == 1) {
      final name = parts.first;
      return name.substring(0, name.length < 2 ? name.length : 2).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get themeLabel => isDark ? 'Dark' : 'Light';

  AppSettings copyWith({
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
    bool? dailyReminder,
    bool? weeklyDigest,
    bool? smsCaptureEnabled,
    int? reminderHour,
    int? reminderMinute,
    Map<String, Color>? categories,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      accent: accent ?? this.accent,
      font: font ?? this.font,
      userName: userName ?? this.userName,
      hideBalances: hideBalances ?? this.hideBalances,
      haptics: haptics ?? this.haptics,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      roundUps: roundUps ?? this.roundUps,
      monthStart: monthStart ?? this.monthStart,
      homeWidgets: homeWidgets ?? this.homeWidgets,
      hiddenWidgets: hiddenWidgets ?? this.hiddenWidgets,
      billReminders: billReminders ?? this.billReminders,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      weeklyDigest: weeklyDigest ?? this.weeklyDigest,
      smsCaptureEnabled: smsCaptureEnabled ?? this.smsCaptureEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      categories: categories ?? this.categories,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'accent': accent.toARGB32(),
    'font': font.name,
    'userName': userName,
    'hideBalances': hideBalances,
    'haptics': haptics,
    'budgetAlerts': budgetAlerts,
    'onboardingSeen': onboardingSeen,
    'roundUps': roundUps,
    'monthStart': monthStart,
    'homeWidgets': homeWidgets.map((e) => e.name).toList(),
    'hiddenWidgets': hiddenWidgets.map((e) => e.name).toList(),
    'billReminders': billReminders,
    'dailyReminder': dailyReminder,
    'weeklyDigest': weeklyDigest,
    'smsCaptureEnabled': smsCaptureEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'categories': categories.map((k, v) => MapEntry(k, v.toARGB32())),
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    theme: AppThemeMode.values.firstWhere(
      (e) => e.name == j['theme'],
      orElse: () => AppThemeMode.dark,
    ),
    accent: Color(((j['accent'] as num?) ?? 0xFFD4FF3A).toInt()),
    font: AppFontMode.values.firstWhere(
      (e) => e.name == j['font'],
      orElse: () => AppFontMode.dmSans,
    ),
    userName: j['userName'] as String? ?? 'Arjun',
    hideBalances: j['hideBalances'] as bool? ?? false,
    haptics: j['haptics'] as bool? ?? true,
    budgetAlerts: j['budgetAlerts'] as bool? ?? true,
    onboardingSeen: j['onboardingSeen'] as bool? ?? false,
    roundUps: j['roundUps'] as bool? ?? false,
    monthStart: (j['monthStart'] as num? ?? 1).toInt(),
    homeWidgets:
        ((j['homeWidgets'] as List?) ??
                defaultHomeWidgets.map((widget) => widget.name).toList())
            .map(
              (name) => HomeWidget.values.firstWhere(
                (widget) => widget.name == name,
                orElse: () => HomeWidget.netWorth,
              ),
            )
            .where((widget) => widget != HomeWidget.forecast)
            .toList(),
    hiddenWidgets: ((j['hiddenWidgets'] as List?) ?? [])
        .map(
          (e) => HomeWidget.values.firstWhere(
            (w) => w.name == e,
            orElse: () => HomeWidget.netWorth,
          ),
        )
        .toSet(),
    billReminders: j['billReminders'] as bool? ?? true,
    dailyReminder: j['dailyReminder'] as bool? ?? true,
    weeklyDigest: j['weeklyDigest'] as bool? ?? false,
    smsCaptureEnabled: j['smsCaptureEnabled'] as bool? ?? true,
    reminderHour: ((j['reminderHour'] as num?)?.toInt() ?? 20)
        .clamp(0, 23)
        .toInt(),
    reminderMinute: ((j['reminderMinute'] as num?)?.toInt() ?? 0)
        .clamp(0, 59)
        .toInt(),
    categories: ((j['categories'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, Color((v as num).toInt())),
    ),
  );
}
