import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/app_settings.dart';
import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData build(AppSettings settings) {
    final dark = settings.isDark;
    final accent = AppColors.normalizeAccent(settings.accent);
    final spend = dark ? SpendColors.dark(accent) : SpendColors.light(accent);
    final family = switch (settings.font) {
      AppFontMode.dmSans => 'DMSans',
      AppFontMode.serif => 'InstrumentSerif',
      AppFontMode.mono => 'monospace',
    };

    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: spend.bg,
      fontFamily: family,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: spend.ln,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: spend.aci,
        secondary: spend.ac2,
        onSecondary: spend.aci,
        error: spend.co,
        onError: Colors.white,
        surface: spend.c1,
        onSurface: spend.tx,
      ),
      extensions: <ThemeExtension<dynamic>>[spend],
    );

    final textTheme = TextTheme(
      displayLarge: AppTypography.display(size: 50, color: spend.tx),
      displayMedium: AppTypography.display(size: 40, color: spend.tx),
      displaySmall: AppTypography.serif(size: 30, color: spend.tx, height: 1.1),
      headlineLarge: AppTypography.serif(
        size: 26,
        color: spend.tx,
        height: 1.15,
      ),
      headlineMedium: AppTypography.serif(
        size: 24,
        color: spend.tx,
        height: 1.2,
      ),
      titleLarge: AppTypography.sans(
        size: 18,
        color: spend.tx,
        weight: FontWeight.w500,
      ),
      titleMedium: AppTypography.sans(
        size: 15,
        color: spend.tx,
        weight: FontWeight.w500,
      ),
      titleSmall: AppTypography.sans(
        size: 13,
        color: spend.tx,
        weight: FontWeight.w500,
      ),
      bodyLarge: AppTypography.sans(size: 14, color: spend.tx, height: 1.35),
      bodyMedium: AppTypography.sans(size: 14, color: spend.tx, height: 1.35),
      bodySmall: AppTypography.sans(size: 12, color: spend.mu, height: 1.35),
      labelLarge: AppTypography.sans(
        size: 13,
        color: spend.tx,
        weight: FontWeight.w500,
      ),
      labelMedium: AppTypography.sans(size: 12, color: spend.mu),
      labelSmall: AppTypography.sans(size: 10, color: spend.mu),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: spend.tx, size: 22),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.25),
        selectionHandleColor: accent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.55),
        shape: const RoundedRectangleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: spend.c1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: spend.tx,
        contentTextStyle: AppTypography.sans(size: 13, color: spend.bg),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: spend.ln, thickness: 1, space: 1),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: accent,
        inactiveTrackColor: spend.c2,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintStyle: AppTypography.sans(size: 14, color: spend.mu),
      ),
    );
  }
}
