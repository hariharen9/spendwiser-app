import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/app_settings.dart';

/// Instrument Serif for display / hero numbers, DM Sans for everything else.
///
/// Both families are bundled under `assets/fonts` so the app renders exactly
/// like the prototype even when the device is offline. Google Fonts is
/// configured to resolve the bundled assets instead of fetching over HTTP.
abstract final class AppTypography {
  static AppFontMode fontMode = AppFontMode.dmSans;

  static String get activeSansFamily => switch (fontMode) {
    AppFontMode.dmSans => 'DMSans',
    AppFontMode.serif => 'InstrumentSerif',
    AppFontMode.mono => 'monospace',
  };

  static String get activeSerifFamily => switch (fontMode) {
    AppFontMode.mono => 'monospace',
    _ => 'InstrumentSerif',
  };

  static TextStyle serif({
    double size = 16,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    FontStyle style = FontStyle.normal,
    TextDecoration? decoration,
  }) {
    if (fontMode == AppFontMode.mono) {
      return TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: style,
        decoration: decoration,
      );
    }
    return GoogleFonts.instrumentSerif(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: style,
      decoration: decoration,
    );
  }

  static TextStyle display({
    double size = 40,
    Color? color,
    double height = 1,
    double letterSpacing = -0.5,
  }) => serif(
    size: size,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle sans({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
    FontStyle style = FontStyle.normal,
    List<Shadow>? shadows,
  }) {
    if (fontMode == AppFontMode.serif) {
      return GoogleFonts.instrumentSerif(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
        fontStyle: style,
        shadows: shadows,
      );
    }
    if (fontMode == AppFontMode.mono) {
      return TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
        fontStyle: style,
        shadows: shadows,
      );
    }
    return GoogleFonts.dmSans(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      fontStyle: style,
      shadows: shadows,
    );
  }

  static TextStyle get heading => display(size: 40);

  static TextStyle label({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) => sans(size: size, color: color, weight: weight, height: height);

  /// Uppercase micro-caption used for section headers.
  static TextStyle caption(Color color) => sans(
    size: 11,
    color: color,
    letterSpacing: 1.32,
    weight: FontWeight.w400,
    height: 1.2,
  );
}
