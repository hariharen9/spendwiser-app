import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/state/providers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'features/shell/app_shell.dart';

class SpendwiserApp extends ConsumerWidget {
  const SpendwiserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    AppTypography.fontMode = settings.font;
    AppColors.dynamicCategories = Map.of(settings.categories);
    Haptics.enabled = settings.haptics;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: settings.isDark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: settings.isDark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: settings.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
    return MaterialApp(
      title: 'Spendwiser',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(settings),
      home: const AppShell(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
