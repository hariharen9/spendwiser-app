import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Exact line-icon paths lifted from the Spendwiser prototype's `I` map.
abstract final class IconPaths {
  static const home = 'M4 11l8-7 8 7v9H4zM10 20v-6h4v6';
  static const ledger = 'M5 4h14v16H5zM9 9h6M9 13h6';
  static const accounts =
      'M3 10l9-6 9 6M5 10v8M10 10v8M14 10v8M19 10v8M3 20h18';
  static const cash =
      'M3 7h18v10H3zM12 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4M6 10v4M18 10v4';
  static const transfer =
      'M4 8h14M14 4l4 4-4 4M20 16H6M10 12l-4 4 4 4';
  static const card = 'M3 6h18v12H3zM3 10h18M6 15h4';
  static const budget = 'M12 3a9 9 0 1 0 9 9h-9z';
  static const subscription = 'M4 12a8 8 0 1 0 3-6.2M4 4v4h4';
  static const loan = 'M6 10h12v10H6zM9 10V7a3 3 0 0 1 6 0v3';
  static const split = 'M7 7h10l-3-3M17 17H7l3 3';
  static const insights = 'M5 20V10M12 20V4M19 20v-7';
  static const vault = 'M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z';
  static const tools = 'M4 4h16v16H4zM8 8h3M8 14h8M14 8h2';
  static const settings = 'M4 8h10M18 8h2M4 16h2M10 16h10M16 6v4M8 14v4';
  static const close = 'M12 5v14M5 12h14';
  static const goal =
      'M12 3l2.6 5.6 6 .7-4.5 4.2 1.2 6L12 16.5 6.7 19.5l1.2-6L3.4 9.3l6-.7z';
  static const calendar = 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4';
  static const mic =
      'M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zM5 11a7 7 0 0 0 14 0M12 18v3';
  static const scan =
      'M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M4 12h16';
  static const search = 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14M16 16l4 4';
  static const chevronLeft = 'M15 5l-7 7 7 7';
  static const chevronRight = 'M9 5l7 7-7 7';
  static const chevronDown = 'M6 9l6 6 6-6';
  static const check = 'M5 12l5 5L20 7';
  static const plus = 'M12 5v14M5 12h14';
  static const arrowRight = 'M5 12h14M13 6l6 6-6 6';
  static const arrowUpRight = 'M7 17L17 7M9 7h8v8';
  static const closeSmall = 'M6 6l12 12M18 6L6 18';
  static const trash = 'M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13';
  static const eye =
      'M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z';
  static const eyeOff =
      'M3 3l18 18M10.6 6.2A10.8 10.8 0 0 1 12 6c6.5 0 10 6 10 6a17 17 0 0 1-2.2 2.8M6.3 6.4C3.6 8.2 2 12 2 12s3.5 6 10 6c1.3 0 2.5-.2 3.6-.6';
  static const download = 'M12 4v12M6 10l6 6 6-6M4 20h16';
  static const upload = 'M12 20V8M6 14l6-6 6 6M4 4h16';
  static const receipt = 'M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6';
  static const lock = 'M6 10h12v10H6zM9 10V7a3 3 0 0 1 6 0v3';
  static const sparkle =
      'M12 3v4M12 17v4M3 12h4M17 12h4M5.5 5.5l2.8 2.8M15.7 15.7l2.8 2.8M18.5 5.5l-2.8 2.8M8.3 15.7l-2.8 2.8';
  static const filter = 'M4 6h16M7 12h10M10 18h4';
  static const refresh = 'M20 12a8 8 0 1 1-2.3-5.6M20 4v5h-5';
  static const faceId =
      'M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M9 9v1M15 9v1M9 15c1.7 1.4 3.3 1.4 5 0';
}

class SpendIcon extends StatelessWidget {
  const SpendIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.6,
  });

  final String name;
  final double size;
  final Color? color;
  final double strokeWidth;

  static const _paths = <String, String>{
    'home': IconPaths.home,
    'ledger': IconPaths.ledger,
    'accounts': IconPaths.accounts,
    'acc': IconPaths.accounts,
    'cash': IconPaths.cash,
    'transfer': IconPaths.transfer,
    'cards': IconPaths.card,
    'cc': IconPaths.card,
    'budgets': IconPaths.budget,
    'bud': IconPaths.budget,
    'subscriptions': IconPaths.subscription,
    'sub': IconPaths.subscription,
    'debt': IconPaths.loan,
    'loan': IconPaths.loan,
    'split': IconPaths.split,
    'goals': IconPaths.goal,
    'goal': IconPaths.goal,
    'calendar': IconPaths.calendar,
    'cal': IconPaths.calendar,
    'insights': IconPaths.insights,
    'ins': IconPaths.insights,
    'tools': IconPaths.tools,
    'tool': IconPaths.tools,
    'settings': IconPaths.settings,
    'set': IconPaths.settings,
    'close': IconPaths.close,
    'x': IconPaths.close,
    'mic': IconPaths.mic,
    'scan': IconPaths.scan,
    'search': IconPaths.search,
    'chevronLeft': IconPaths.chevronLeft,
    'chevronRight': IconPaths.chevronRight,
    'chevronDown': IconPaths.chevronDown,
    'check': IconPaths.check,
    'plus': IconPaths.plus,
    'arrowRight': IconPaths.arrowRight,
    'arrowUpRight': IconPaths.arrowUpRight,
    'closeSmall': IconPaths.closeSmall,
    'trash': IconPaths.trash,
    'eye': IconPaths.eye,
    'eyeOff': IconPaths.eyeOff,
    'download': IconPaths.download,
    'upload': IconPaths.upload,
    'receipt': IconPaths.receipt,
    'vault': IconPaths.vault,
    'lock': IconPaths.lock,
    'sparkle': IconPaths.sparkle,
    'filter': IconPaths.filter,
    'refresh': IconPaths.refresh,
    'faceId': IconPaths.faceId,
  };

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    final path = _paths[name] ?? IconPaths.sparkle;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="${_hex(tint)}" stroke-width="$strokeWidth" '
        'stroke-linecap="round" stroke-linejoin="round"><path d="$path"/></svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  static String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }
}

/// Brand marks and category glyphs used inside transaction / merchant rows.
class MerchantAvatar extends StatelessWidget {
  const MerchantAvatar({
    super.key,
    required this.merchant,
    required this.category,
    this.size = 38,
  });

  final String merchant;
  final String category;
  final double size;

  static const _categoryPaths = <String, String>{
    'Food': 'M6 3v8a2 2 0 0 0 4 0V3M8 3v18M16 3c-2 2-2 6 0 8v10',
    'Travel': 'M5 16l1.5-5h11L19 16M4 16h16v3H4zM7 19v2M17 19v2',
    'Shop': 'M5 8h14l-1 12H6zM9 8a3 3 0 0 1 6 0',
    'Bills': 'M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6',
    'Fun': 'M5 5h14v14H5zM10 9l5 3-5 3z',
    'Income': 'M12 4v13M6 12l6 6 6-6',
    'Transfer': 'M7 7h10l-3-3M17 17H7l3 3',
    'EMI': 'M6 10h12v10H6zM9 10V7a3 3 0 0 1 6 0v3',
  };

  static const _brandOrder = [
    'netflix',
    'spotify',
    'youtube',
    'icloud',
    'notion',
    'amazon',
    'cult',
    'swiggy',
    'zomato',
    'uber',
  ];

  String? get _brand {
    final name = merchant.toLowerCase();
    for (final key in _brandOrder) {
      if (name.contains(key)) return key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final brand = _brand;
    if (brand != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _brandBackground(brand),
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        alignment: Alignment.center,
        child: SvgPicture.string(
          _brandSvg(brand),
          width: size * 0.58,
          height: size * 0.58,
        ),
      );
    }
    final color = AppColors.category(category);
    final path = _categoryPaths[category] ?? 'M5 12h14';
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="${SpendIcon._hex(color)}" stroke-width="1.8" '
        'stroke-linecap="round" stroke-linejoin="round"><path d="$path"/></svg>';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: SvgPicture.string(svg, width: size * 0.55, height: size * 0.55),
    );
  }

  static Color _brandBackground(String brand) {
    return switch (brand) {
      'netflix' => const Color(0xFF141414),
      'spotify' => const Color(0xFF1DB954),
      'youtube' => const Color(0xFFFF0000),
      'icloud' => const Color(0xFF2F80ED),
      'notion' => const Color(0xFFF4F1EA),
      'amazon' => const Color(0xFF232F3E),
      'cult' => const Color(0xFFFF3366),
      'swiggy' => const Color(0xFFFC8019),
      'zomato' => const Color(0xFFE23744),
      'uber' => const Color(0xFF000000),
      _ => const Color(0xFF1C1C22),
    };
  }

  static String _brandSvg(String brand) {
    const open =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">';
    return switch (brand) {
      'netflix' => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M7 4h3l4 9V4h3v16h-3l-4-9v9H7z" fill="#e50914"/></svg>',
      'spotify' =>
        '$open<path d="M6 9c4-1.2 8-1 12 1M7 12.5c3.4-1 6.6-.8 10 .8M8 16c2.6-.7 5-.5 8 .7"/></svg>',
      'youtube' => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M10 8.5v7l6-3.5z" fill="#fff"/></svg>',
      'icloud' => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M7 18a4 4 0 0 1-.6-7.96A5.5 5.5 0 0 1 17 9.5a4.2 4.2 0 0 1 .5 8.5z" fill="#fff"/></svg>',
      'notion' =>
        '$open<path d="M8 6v12M8 6l8 12M16 6v12" stroke="#111" stroke-width="2.2"/></svg>',
      'amazon' => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke-linecap="round"><path d="M6 15c4 3 8 3 12 0M15 17l3-2" stroke="#ff9900" stroke-width="2"/><path d="M9 11a3 3 0 1 1 3 3" stroke="#fff" stroke-width="1.8"/></svg>',
      'cult' =>
        '$open<path d="M6 9v6M9 7v10M15 7v10M18 9v6M9 12h6" stroke-width="2"/></svg>',
      'swiggy' =>
        '$open<path d="M15 7c-4-2-8 1-5 4s5 2 2 6" stroke-width="2.4"/></svg>',
      'zomato' => '$open<path d="M8 7h8l-8 10h8" stroke-width="2.4"/></svg>',
      'uber' =>
        '$open<path d="M8 6v7a4 4 0 0 0 8 0V6" stroke-width="2.4"/></svg>',
      _ => '$open<path d="M5 12h14"/></svg>',
    };
  }
}

/// Small colored icon tile used by budgets, goals and loans.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
    this.backgroundOpacity = 0.14,
  });

  final String icon;
  final Color color;
  final double size;
  final double backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundOpacity),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: SpendIcon(icon, size: size * 0.55, color: color, strokeWidth: 1.9),
    );
  }
}
