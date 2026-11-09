import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppThemeMode { dark, light }

enum AppFontMode { dmSans, serif, mono }

/// Reorderable / hideable Home widgets, mirroring the prototype's Customize
/// Home sheet.
enum HomeWidget {
  netWorth('Net worth'),
  quickAdd('Quick add'),
  safeRing('Safe to spend'),
  comingUp('Coming up'),
  streak('Streak & buffer'),
  forecast('Cash-flow forecast'),
  goals('Goals'),
  recent('Recent');

  const HomeWidget(this.label);
  final String label;
}

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
    this.homeWidgets = HomeWidget.values,
    this.hiddenWidgets = const <HomeWidget>{},
    this.billReminders = true,
    this.weeklyDigest = false,
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
  final bool weeklyDigest;

  bool get isDark => theme == AppThemeMode.dark;

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
    bool? weeklyDigest,
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
      weeklyDigest: weeklyDigest ?? this.weeklyDigest,
    );
  }
}
