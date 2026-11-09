import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppModule {
  home(
    id: 'home',
    label: 'Home',
    subtitle: 'Your day at a glance',
    icon: 'home',
    tint: Color(0xFFD4FF3A),
    wide: true,
  ),
  ledger(
    id: 'ledger',
    label: 'Ledger',
    subtitle: 'Every transaction, searchable',
    icon: 'ledger',
    tint: Color(0xFF4DABF7),
  ),
  accounts(
    id: 'accounts',
    label: 'Banks',
    subtitle: 'Accounts & net worth',
    icon: 'accounts',
    tint: Color(0xFF2DD4BF),
  ),
  cards(
    id: 'cards',
    label: 'Cards',
    subtitle: 'Cards, dues & rewards',
    icon: 'cards',
    tint: Color(0xFFFF9F43),
    wide: true,
  ),
  budgets(
    id: 'budgets',
    label: 'Budgets',
    subtitle: 'Envelopes & allocation',
    icon: 'budgets',
    tint: Color(0xFFC084FC),
  ),
  subscriptions(
    id: 'subscriptions',
    label: 'Subs',
    subtitle: 'Recurring charges',
    icon: 'subscriptions',
    tint: Color(0xFFFF6B9D),
  ),
  debt(
    id: 'debt',
    label: 'Debt',
    subtitle: 'Loans & payoff planner',
    icon: 'debt',
    tint: Color(0xFFFF6B4A),
  ),
  split(
    id: 'split',
    label: 'Split',
    subtitle: 'Shared expenses',
    icon: 'split',
    tint: Color(0xFF6EE7FF),
  ),
  goals(
    id: 'goals',
    label: 'Goals',
    subtitle: 'Savings goals & challenges',
    icon: 'goals',
    tint: Color(0xFFFFD23F),
  ),
  calendar(
    id: 'calendar',
    label: 'Calendar',
    subtitle: 'Bills & cash flow',
    icon: 'calendar',
    tint: Color(0xFF6EE7FF),
  ),
  insights(
    id: 'insights',
    label: 'Insights',
    subtitle: 'Analytics & forecasts',
    icon: 'insights',
    tint: Color(0xFFD4FF3A),
  ),
  tools(
    id: 'tools',
    label: 'Tools',
    subtitle: 'Calculators & shortcuts',
    icon: 'tools',
    tint: Color(0xFFFFD23F),
    wide: true,
  ),
  settings(
    id: 'settings',
    label: 'Settings',
    subtitle: 'Make it yours',
    icon: 'settings',
    tint: Color(0xFFB8B2A7),
    fullWidth: true,
  );

  const AppModule({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.tint,
    this.wide = false,
    this.fullWidth = false,
  });

  final String id;
  final String label;
  final String subtitle;
  final String icon;
  final Color tint;
  final bool wide;
  final bool fullWidth;

  Color get atmosphereTint => switch (this) {
    AppModule.home => AppColors.moduleTint['home']!,
    AppModule.ledger => AppColors.moduleTint['ledger']!,
    AppModule.accounts => AppColors.moduleTint['accounts']!,
    AppModule.cards => AppColors.moduleTint['cards']!,
    AppModule.budgets => AppColors.moduleTint['budgets']!,
    AppModule.subscriptions => AppColors.moduleTint['subscriptions']!,
    AppModule.debt => AppColors.moduleTint['debt']!,
    AppModule.split => AppColors.moduleTint['split']!,
    AppModule.goals => AppColors.moduleTint['goals']!,
    AppModule.calendar => AppColors.moduleTint['calendar']!,
    AppModule.insights => AppColors.moduleTint['insights']!,
    AppModule.tools => AppColors.moduleTint['tools']!,
    AppModule.settings => AppColors.moduleTint['settings']!,
  };
}
