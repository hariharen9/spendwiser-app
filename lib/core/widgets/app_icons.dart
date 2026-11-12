import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:simple_icons/simple_icons.dart';

import '../theme/app_colors.dart';

/// Exact line-icon paths lifted from the Spendwiser prototype's `I` map.
abstract final class IconPaths {
  static const home = 'M4 11l8-7 8 7v9H4zM10 20v-6h4v6';
  static const ledger = 'M5 4h14v16H5zM9 9h6M9 13h6';
  static const accounts =
      'M3 10l9-6 9 6M5 10v8M10 10v8M14 10v8M19 10v8M3 20h18';
  static const cash =
      'M3 7h18v10H3zM12 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4M6 10v4M18 10v4';
  static const transfer = 'M4 8h14M14 4l4 4-4 4M20 16H6M10 12l-4 4 4 4';
  static const card = 'M3 6h18v12H3zM3 10h18M6 15h4';
  static const budget = 'M12 3a9 9 0 1 0 9 9h-9z';
  static const subscription = 'M4 12a8 8 0 1 0 3-6.2M4 4v4h4';
  static const loan = 'M6 10h12v10H6zM9 10V7a3 3 0 0 1 6 0v3';
  static const split = 'M7 7h10l-3-3M17 17H7l3 3';
  static const grid = 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z';
  static const info = 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18M12 10v6M12 7h.01';
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
    'grid': IconPaths.grid,
    'info': IconPaths.info,
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

  static const _foodPath = 'M6 3v8a2 2 0 0 0 4 0V3M8 3v18M16 3c-2 2-2 6 0 8v10';
  static const _travelPath = 'M5 16l1.5-5h11L19 16M4 16h16v3H4zM7 19v2M17 19v2';
  static const _shopPath = 'M5 8h14l-1 12H6zM9 8a3 3 0 0 1 6 0';
  static const _billsPath = 'M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6';
  static const _funPath = 'M5 5h14v14H5zM10 9l5 3-5 3z';
  static const _incomePath = 'M12 4v13M6 12l6 6 6-6';
  static const _transferPath = 'M7 7h10l-3-3M17 17H7l3 3';
  static const _emiPath = 'M6 10h12v10H6zM9 10V7a3 3 0 0 1 6 0v3';
  static const _groceriesPath =
      'M4 9h16l-1.4 10H5.4zM8 9l1.5-5h5L16 9M9 13v2M15 13v2';
  static const _personalPath =
      'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0';
  static const _fuelPath =
      'M4 21V5h9v16M4 9h9M8 3v3M13 8h3l3 3v7a2 2 0 0 0 4 0v-5l-2-2';
  static const _utilitiesPath = 'M13 2L5 14h6l-1 8 8-12h-6z';
  static const _healthcarePath = 'M9 3h6v6h6v6h-6v6H9v-6H3V9h6z';
  static const _educationPath = 'M3 5h7v16H3zM14 5h7v16h-7zM6 9h1M17 9h1';
  static const _rentPath =
      'M4 21V5h10v16M14 10h6v11M7 8h2M7 12h2M7 16h2M17 13h1M17 17h1';
  static const _investmentPath = 'M4 18l5-5 4 3 7-8M15 8h5v5';
  static const _miscPath =
      'M12 3l2.2 4.5 5 .7-3.6 3.5.8 5-4.4-2.3-4.4 2.3.8-5L4.8 8.2l5-.7z';
  static const _otherPath = 'M20 13l-7 7-9-9V4h7l9 9zM8 8h.01';

  static const _categoryPaths = <String, String>{
    'Home': IconPaths.home,
    'Groceries': _groceriesPath,
    'Food & Dining': _foodPath,
    'Transportation': _travelPath,
    'Entertainment': _funPath,
    'Shopping': _shopPath,
    'Personal': _personalPath,
    'Fuel': _fuelPath,
    'Utilities': _utilitiesPath,
    'Healthcare': _healthcarePath,
    'Education': _educationPath,
    'Bills & EMIs': _billsPath,
    'Rent & Housing': _rentPath,
    'Investment': _investmentPath,
    'Travel': _travelPath,
    'Miscellaneous': _miscPath,
    'Other': _otherPath,
    'Income': _incomePath,
    'Transfer': _transferPath,
    'EMI': _emiPath,
    'Food': _foodPath,
    'Shop': _shopPath,
    'Bills': _billsPath,
    'Fun': _funPath,
  };

  /// Official SimpleIcons vector marks + brand colors (matched in order).
  static final _simpleBrands = <({List<String> keys, IconData icon, Color bg})>[
    (keys: ['bookmyshow', 'bms'], icon: SimpleIcons.bookmyshow, bg: SimpleIconColors.bookmyshow),
    (keys: ['bigbasket'], icon: SimpleIcons.bigbasket, bg: SimpleIconColors.bigbasket),
    (keys: ['swiggy'], icon: SimpleIcons.swiggy, bg: SimpleIconColors.swiggy),
    (keys: ['zomato'], icon: SimpleIcons.zomato, bg: SimpleIconColors.zomato),
    (keys: ['google pay', 'gpay', 'googlepay'], icon: SimpleIcons.googlepay, bg: SimpleIconColors.googlepay),
    (keys: ['phonepe'], icon: SimpleIcons.phonepe, bg: SimpleIconColors.phonepe),
    (keys: ['paytm'], icon: SimpleIcons.paytm, bg: SimpleIconColors.paytm),
    (keys: ['razorpay'], icon: SimpleIcons.razorpay, bg: SimpleIconColors.razorpay),
    (keys: ['zerodha', 'kite'], icon: SimpleIcons.zerodha, bg: SimpleIconColors.zerodha),
    (keys: ['hdfc'], icon: SimpleIcons.hdfcbank, bg: SimpleIconColors.hdfcbank),
    (keys: ['icici'], icon: SimpleIcons.icicibank, bg: SimpleIconColors.icicibank),
    (keys: ['axis'], icon: SimpleIcons.axisbank, bg: SimpleIconColors.axisbank),
    (keys: ['indigo'], icon: SimpleIcons.indigo, bg: SimpleIconColors.indigo),
    (keys: ['airtel'], icon: SimpleIcons.airtel, bg: SimpleIconColors.airtel),
    (keys: ['jiofiber', 'jio'], icon: SimpleIcons.jio, bg: SimpleIconColors.jio),
    (keys: ['vodafone', 'vi '], icon: SimpleIcons.vodafone, bg: SimpleIconColors.vodafone),
    (keys: ['tata'], icon: SimpleIcons.tata, bg: SimpleIconColors.tata),
    (keys: ['bata'], icon: SimpleIcons.bata, bg: SimpleIconColors.bata),
    (keys: ['oyo'], icon: SimpleIcons.oyo, bg: SimpleIconColors.oyo),
    (keys: ['uber'], icon: SimpleIcons.uber, bg: const Color(0xFF141414)),
    (keys: ['youtube'], icon: SimpleIcons.youtube, bg: SimpleIconColors.youtube),
    (keys: ['netflix'], icon: SimpleIcons.netflix, bg: const Color(0xFF141414)),
    (keys: ['spotify'], icon: SimpleIcons.spotify, bg: SimpleIconColors.spotify),
    (keys: ['starbucks'], icon: SimpleIcons.starbucks, bg: SimpleIconColors.starbucks),
    (keys: ['mcdonald'], icon: SimpleIcons.mcdonalds, bg: SimpleIconColors.mcdonalds),
    (keys: ['kfc'], icon: SimpleIcons.kfc, bg: SimpleIconColors.kfc),
    (keys: ['burger king', 'burgerking'], icon: SimpleIcons.burgerking, bg: SimpleIconColors.burgerking),
    (keys: ['icloud'], icon: SimpleIcons.icloud, bg: SimpleIconColors.icloud),
    (keys: ['apple'], icon: SimpleIcons.apple, bg: const Color(0xFF1C1C22)),
    (keys: ['google'], icon: SimpleIcons.google, bg: SimpleIconColors.google),
    (keys: ['steam'], icon: SimpleIcons.steam, bg: SimpleIconColors.steam),
    (keys: ['playstation', 'ps5', 'ps4'], icon: SimpleIcons.playstation, bg: SimpleIconColors.playstation),
    (keys: ['nike'], icon: SimpleIcons.nike, bg: const Color(0xFF141414)),
    (keys: ['adidas'], icon: SimpleIcons.adidas, bg: const Color(0xFF141414)),
    (keys: ['puma'], icon: SimpleIcons.puma, bg: const Color(0xFF141414)),
    (keys: ['decathlon'], icon: SimpleIcons.nike, bg: const Color(0xFF0082C3)),
    (keys: ['ikea'], icon: SimpleIcons.ikea, bg: SimpleIconColors.ikea),
    (keys: ['zara'], icon: SimpleIcons.zara, bg: const Color(0xFF141414)),
    (keys: ['uniqlo'], icon: SimpleIcons.uniqlo, bg: SimpleIconColors.uniqlo),
    (keys: ['notion'], icon: SimpleIcons.notion, bg: const Color(0xFFF4F1EA)),
    (keys: ['discord'], icon: SimpleIcons.discord, bg: SimpleIconColors.discord),
    (keys: ['telegram'], icon: SimpleIcons.telegram, bg: SimpleIconColors.telegram),
    (keys: ['whatsapp'], icon: SimpleIcons.whatsapp, bg: SimpleIconColors.whatsapp),
    (keys: ['instagram'], icon: SimpleIcons.instagram, bg: SimpleIconColors.instagram),
    (keys: ['facebook'], icon: SimpleIcons.facebook, bg: SimpleIconColors.facebook),
    (keys: ['github'], icon: SimpleIcons.github, bg: const Color(0xFF181717)),
    (keys: ['figma'], icon: SimpleIcons.figma, bg: const Color(0xFF1E1E1E)),
    (keys: ['dropbox'], icon: SimpleIcons.dropbox, bg: SimpleIconColors.dropbox),
    (keys: ['coursera'], icon: SimpleIcons.coursera, bg: SimpleIconColors.coursera),
    (keys: ['udemy'], icon: SimpleIcons.udemy, bg: SimpleIconColors.udemy),
    (keys: ['duolingo'], icon: SimpleIcons.duolingo, bg: SimpleIconColors.duolingo),
    (keys: ['airbnb'], icon: SimpleIcons.airbnb, bg: SimpleIconColors.airbnb),
    (keys: ['shell'], icon: SimpleIcons.shell, bg: SimpleIconColors.shell),
    (keys: ['hpcl', 'hp'], icon: SimpleIcons.hp, bg: SimpleIconColors.hp),
    (keys: ['claude'], icon: SimpleIcons.claude, bg: SimpleIconColors.claude),
  ];

  /// Custom brand badges for major Indian brands not present in SimpleIcons.
  static const _customBrands = <({List<String> keys, String label, Color bg, Color fg})>[
    (keys: ['blinkit'], label: 'bl', bg: Color(0xFFF8CB46), fg: Color(0xFF111111)),
    (keys: ['zepto'], label: 'Z', bg: Color(0xFF3B007A), fg: Color(0xFFFF3269)),
    (keys: ['flipkart'], label: 'f', bg: Color(0xFF2874F0), fg: Color(0xFFFFE500)),
    (keys: ['myntra'], label: 'M', bg: Color(0xFFFF3F6C), fg: Colors.white),
    (keys: ['ajio'], label: 'AJ', bg: Color(0xFF2C4152), fg: Colors.white),
    (keys: ['nykaa'], label: 'N', bg: Color(0xFFFC2779), fg: Colors.white),
    (keys: ['meesho'], label: 'm', bg: Color(0xFF9F2089), fg: Colors.white),
    (keys: ['dmart'], label: 'D', bg: Color(0xFF007A3D), fg: Color(0xFFFFD100)),
    (keys: ['ola'], label: 'O', bg: Color(0xFF141414), fg: Color(0xFFD4FF3A)),
    (keys: ['rapido'], label: 'R', bg: Color(0xFFF9C935), fg: Color(0xFF111111)),
    (keys: ['namma yatri'], label: 'NY', bg: Color(0xFF1B5E20), fg: Color(0xFFFFD54F)),
    (keys: ['irctc'], label: 'IR', bg: Color(0xFF003B73), fg: Colors.white),
    (keys: ['cred'], label: 'CR', bg: Color(0xFF121212), fg: Color(0xFFF4F1EA)),
    (keys: ['groww'], label: 'G', bg: Color(0xFF00D09C), fg: Color(0xFF0B0D02)),
    (keys: ['hotstar', 'jiohotstar'], label: 'H★', bg: Color(0xFF0A1230), fg: Color(0xFF38BDF8)),
    (keys: ['jiocinema'], label: 'JC', bg: Color(0xFFD9008D), fg: Colors.white),
    (keys: ['sonyliv'], label: 'SL', bg: Color(0xFF1C1C22), fg: Color(0xFFFF9F43)),
    (keys: ['pvr', 'inox'], label: 'PV', bg: Color(0xFF1B1B1B), fg: Color(0xFFFFD23F)),
    (keys: ['dominos'], label: 'D', bg: Color(0xFF006491), fg: Colors.white),
    (keys: ['chaayos'], label: 'C', bg: Color(0xFF00A859), fg: Colors.white),
    (keys: ['haldiram'], label: 'H', bg: Color(0xFFB71C1C), fg: Color(0xFFFFD54F)),
    (keys: ['apollo'], label: 'A+', bg: Color(0xFF007B8A), fg: Colors.white),
    (keys: ['pharmeasy'], label: 'PE', bg: Color(0xFF10847E), fg: Colors.white),
    (keys: ['1mg'], label: '1mg', bg: Color(0xFFFF6F61), fg: Colors.white),
    (keys: ['lenskart'], label: 'LK', bg: Color(0xFF000042), fg: Color(0xFF2DD4BF)),
    (keys: ['makemytrip', 'mmt'], label: 'MMT', bg: Color(0xFFEB2026), fg: Colors.white),
    (keys: ['redbus'], label: 'rB', bg: Color(0xFFD84E55), fg: Colors.white),
    (keys: ['urban company', 'urbanclap'], label: 'UC', bg: Color(0xFF141414), fg: Colors.white),
    (keys: ['bescom', 'tata power'], label: '⚡', bg: Color(0xFF1D3A6B), fg: Color(0xFFFFD23F)),
    (keys: ['sbi'], label: 'SBI', bg: Color(0xFF280071), fg: Color(0xFF00B5EF)),
    (keys: ['kotak'], label: 'K', bg: Color(0xFFED1C24), fg: Colors.white),
    (keys: ['idfc'], label: 'IDFC', bg: Color(0xFF9D1D27), fg: Colors.white),
    (keys: ['yes bank', 'yesbank'], label: 'YES', bg: Color(0xFF00529C), fg: Colors.white),
    (keys: ['indusind'], label: 'IB', bg: Color(0xFF8C1D40), fg: Colors.white),
    (keys: ['canara'], label: 'CB', bg: Color(0xFF0091D5), fg: Color(0xFFFFD100)),
    (keys: ['pnb', 'punjab national'], label: 'PNB', bg: Color(0xFFA20A3A), fg: Color(0xFFFFD200)),
    (keys: ['baroda', 'bob'], label: 'BoB', bg: Color(0xFFF15A22), fg: Colors.white),
    (keys: ['federal'], label: 'FB', bg: Color(0xFF004C97), fg: Color(0xFFFFD100)),
    (keys: ['hsbc'], label: 'HSBC', bg: Color(0xFFDB0011), fg: Colors.white),
    (keys: ['amex', 'american express'], label: 'AMEX', bg: Color(0xFF006FCF), fg: Colors.white),
    (keys: ['citi'], label: 'citi', bg: Color(0xFF003B70), fg: Color(0xFFEE1C25)),
    (keys: ['jupiter'], label: 'J', bg: Color(0xFFFE6B52), fg: Colors.white),
    (keys: ['fi money', 'fi'], label: 'Fi', bg: Color(0xFF00B5A3), fg: Colors.white),
  ];

  bool _matchesKey(String name, String key) {
    if (key.length <= 3) {
      return RegExp('\\b${RegExp.escape(key)}\\b').hasMatch(name);
    }
    return name.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    final name = merchant.toLowerCase();

    // 1. Amazon custom SVG (not in SimpleIcons)
    if (name.contains('amazon')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF232F3E),
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        alignment: Alignment.center,
        child: SvgPicture.string(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke-linecap="round"><path d="M6 15c4 3 8 3 12 0M15 17l3-2" stroke="#ff9900" stroke-width="2"/><path d="M9 11a3 3 0 1 1 3 3" stroke="#fff" stroke-width="1.8"/></svg>',
          width: size * 0.58,
          height: size * 0.58,
        ),
      );
    }

    // 2. Cult custom SVG
    if (name.contains('cult')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFF3366),
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        alignment: Alignment.center,
        child: SvgPicture.string(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9v6M9 7v10M15 7v10M18 9v6M9 12h6"/></svg>',
          width: size * 0.58,
          height: size * 0.58,
        ),
      );
    }

    // 3. Official SimpleIcons vector brand marks
    for (final brand in _simpleBrands) {
      if (brand.keys.any((k) => _matchesKey(name, k))) {
        final fg = brand.bg.computeLuminance() > 0.55
            ? const Color(0xFF111111)
            : Colors.white;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: brand.bg,
            borderRadius: BorderRadius.circular(size * 0.34),
          ),
          alignment: Alignment.center,
          child: Icon(brand.icon, size: size * 0.54, color: fg),
        );
      }
    }

    // 4. Custom Indian brand marks
    for (final brand in _customBrands) {
      if (brand.keys.any((k) => _matchesKey(name, k))) {
        final fontSize = brand.label.length >= 3
            ? size * 0.28
            : (brand.label.length == 2 ? size * 0.34 : size * 0.42);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: brand.bg,
            borderRadius: BorderRadius.circular(size * 0.34),
          ),
          alignment: Alignment.center,
          child: Text(
            brand.label,
            style: TextStyle(
              color: brand.fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1,
            ),
          ),
        );
      }
    }

    // 5. Category icon fallback
    final color = AppColors.category(category);
    final path = _categoryPaths[category] ?? _otherPath;
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
