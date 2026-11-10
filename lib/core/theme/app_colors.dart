import 'package:flutter/material.dart';

/// Exact tokens extracted from the Spendwiser reference prototype.
abstract final class AppColors {
  // Dark theme (default)
  static const bg = Color(0xFF09090B);
  static const c1 = Color(0xFF131317);
  static const c2 = Color(0xFF1C1C22);
  static const tx = Color(0xFFF4F1EA);
  static const mu = Color(0xFF8B8883);
  static const ln = Color(0x12FFFFFF); // rgba(255,255,255,.07)
  static const ac = Color(0xFFD4FF3A);
  static const aci = Color(0xFF0B0D02);
  static const co = Color(0xFFFF6B4A);
  static const out = Color(0xFF000000);

  // Light theme
  static const lightBg = Color(0xFFF3F0E9);
  static const lightC1 = Color(0xFFFFFFFF);
  static const lightC2 = Color(0xFFEBE7DD);
  static const lightTx = Color(0xFF15140F);
  static const lightMu = Color(0xFF7B776D);
  static const lightLn = Color(0x14000000); // rgba(0,0,0,.08)
  static const lightOut = Color(0xFFD9D4C7);

  static const accents = <Color>[
    Color(0xFFD4FF3A), // Lime
    Color(0xFFFF6B4A), // Coral
    Color(0xFF6EE7FF), // Cyan
    Color(0xFFC084FC), // Purple
    Color(0xFFFFD23F), // Gold
    Color(0xFFFF6B9D), // Rose
    Color(0xFF60A5FA), // Sky
    Color(0xFF7BE495), // Mint
  ];

  /// Curated second stop for accent gradients.
  static final accentPairs = <Color, Color>{
    Color(0xFFD4FF3A): Color(0xFF7DFF8A), // Lime → mint
    Color(0xFFFF6B4A): Color(0xFFFF3D81), // Coral → pink
    Color(0xFF6EE7FF): Color(0xFF2DD4BF), // Cyan → teal
    Color(0xFFC084FC): Color(0xFFA78BFA), // Purple → lavender
    Color(0xFFFFD23F): Color(0xFFFF9F43), // Gold → amber
    Color(0xFFFF6B9D): Color(0xFFFF4D6D), // Rose → red
    Color(0xFF60A5FA): Color(0xFF38BDF8), // Sky → cyan
    Color(0xFF7BE495): Color(0xFF34D399), // Mint → emerald
  };

  static Color accentSecondary(Color primary) =>
      accentPairs[primary] ?? Color.lerp(primary, Colors.white, 0.24)!;

  static const categoryPalette = <Color>[
    Color(0xFFFF9F43), // Orange
    Color(0xFF4DABF7), // Blue
    Color(0xFFC084FC), // Purple
    Color(0xFFFF6B9D), // Pink
    Color(0xFFD4FF3A), // Lime
    Color(0xFF2DD4BF), // Teal
    Color(0xFFFF6B4A), // Coral
    Color(0xFFFFD23F), // Gold
    Color(0xFF38BDF8), // Sky
    Color(0xFFA78BFA), // Lavender
    Color(0xFFFB7185), // Rose
    Color(0xFF34D399), // Emerald
    Color(0xFFFBBF24), // Amber
    Color(0xFF94A3B8), // Slate
  ];

  static const categories = <String, Color>{
    'Food': Color(0xFFFF9F43),
    'Travel': Color(0xFF4DABF7),
    'Bills': Color(0xFFC084FC),
    'Shop': Color(0xFFFF6B9D),
    'Income': Color(0xFFD4FF3A),
    'Fun': Color(0xFF2DD4BF),
    'EMI': Color(0xFFFF6B4A),
    'Transfer': Color(0xFF8B8883),
  };

  static Map<String, Color> dynamicCategories = Map.of(categories);

  static List<String> get categoryList => dynamicCategories.keys.toList();

  /// Per-module atmosphere tint from the prototype.
  static const moduleTint = <String, Color>{
    'home': Color(0xFFD4FF3A),
    'ledger': Color(0xFF4DABF7),
    'accounts': Color(0xFF2DD4BF),
    'cards': Color(0xFFFF9F43),
    'budgets': Color(0xFFC084FC),
    'subscriptions': Color(0xFFFF6B9D),
    'debt': Color(0xFFFF6B4A),
    'split': Color(0xFF6EE7FF),
    'goals': Color(0xFFFFD23F),
    'calendar': Color(0xFF6EE7FF),
    'insights': Color(0xFFD4FF3A),
    'tools': Color(0xFFFFD23F),
    'settings': Color(0xFFB8B2A7),
  };

  static Color category(String name) =>
      dynamicCategories[name] ?? categories[name] ?? mu;

  static Color fromHex(String hex) {
    final value = hex.replaceAll('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }

  static String toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

/// Theme-aware spend palette exposed through [ThemeData.extensions].
@immutable
class SpendColors extends ThemeExtension<SpendColors> {
  const SpendColors({
    required this.bg,
    required this.c1,
    required this.c2,
    required this.tx,
    required this.mu,
    required this.ln,
    required this.ac,
    required this.ac2,
    required this.aci,
    required this.co,
    required this.out,
    required this.dark,
  });

  final Color bg;
  final Color c1;
  final Color c2;
  final Color tx;
  final Color mu;
  final Color ln;
  final Color ac;
  final Color ac2;
  final Color aci;
  final Color co;
  final Color out;
  final bool dark;

  factory SpendColors.dark(Color accent) => SpendColors(
    bg: AppColors.bg,
    c1: AppColors.c1,
    c2: AppColors.c2,
    tx: AppColors.tx,
    mu: AppColors.mu,
    ln: AppColors.ln,
    ac: accent,
    ac2: AppColors.accentSecondary(accent),
    aci: AppColors.aci,
    co: AppColors.co,
    out: AppColors.out,
    dark: true,
  );

  factory SpendColors.light(Color accent) => SpendColors(
    bg: AppColors.lightBg,
    c1: AppColors.lightC1,
    c2: AppColors.lightC2,
    tx: AppColors.lightTx,
    mu: AppColors.lightMu,
    ln: AppColors.lightLn,
    ac: accent,
    ac2: AppColors.accentSecondary(accent),
    aci: AppColors.aci,
    co: AppColors.co,
    out: AppColors.lightOut,
    dark: false,
  );

  static SpendColors of(BuildContext context) =>
      Theme.of(context).extension<SpendColors>() ??
      SpendColors.dark(AppColors.ac);

  Color get glassTop =>
      dark ? Colors.white.withValues(alpha: 0.065) : Colors.white;
  Color get glassBottom =>
      dark ? Colors.white.withValues(alpha: 0.02) : Colors.white;
  Color get shadow => dark
      ? Colors.black.withValues(alpha: 0.38)
      : const Color(0xFF463714).withValues(alpha: 0.16);

  LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [glassTop, glassBottom],
  );

  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ac, ac2],
  );

  LinearGradient accentGradientFor(Color tint) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tint, AppColors.accentSecondary(tint)],
  );

  Color tint(Color color, double alpha) => color.withValues(alpha: alpha);

  @override
  SpendColors copyWith({
    Color? bg,
    Color? c1,
    Color? c2,
    Color? tx,
    Color? mu,
    Color? ln,
    Color? ac,
    Color? ac2,
    Color? aci,
    Color? co,
    Color? out,
    bool? dark,
  }) {
    return SpendColors(
      bg: bg ?? this.bg,
      c1: c1 ?? this.c1,
      c2: c2 ?? this.c2,
      tx: tx ?? this.tx,
      mu: mu ?? this.mu,
      ln: ln ?? this.ln,
      ac: ac ?? this.ac,
      ac2: ac2 ?? this.ac2,
      aci: aci ?? this.aci,
      co: co ?? this.co,
      out: out ?? this.out,
      dark: dark ?? this.dark,
    );
  }

  @override
  SpendColors lerp(covariant SpendColors? other, double t) {
    if (other == null) return this;
    return SpendColors(
      bg: Color.lerp(bg, other.bg, t)!,
      c1: Color.lerp(c1, other.c1, t)!,
      c2: Color.lerp(c2, other.c2, t)!,
      tx: Color.lerp(tx, other.tx, t)!,
      mu: Color.lerp(mu, other.mu, t)!,
      ln: Color.lerp(ln, other.ln, t)!,
      ac: Color.lerp(ac, other.ac, t)!,
      ac2: Color.lerp(ac2, other.ac2, t)!,
      aci: Color.lerp(aci, other.aci, t)!,
      co: Color.lerp(co, other.co, t)!,
      out: Color.lerp(out, other.out, t)!,
      dark: t < 0.5 ? dark : other.dark,
    );
  }
}

extension SpendColorsX on BuildContext {
  SpendColors get spend => SpendColors.of(this);
}
