/// Indian Rupee formatting that matches `Number.toLocaleString('en-IN')`.
library;

String _groupIndian(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  final rest = digits.substring(0, digits.length - 3);
  final buffer = StringBuffer();
  for (var i = 0; i < rest.length; i++) {
    if (i > 0 && (rest.length - i) % 2 == 0) buffer.write(',');
    buffer.write(rest[i]);
  }
  buffer.write(',');
  buffer.write(last3);
  return buffer.toString();
}

/// `₹10,54,100`
String formatINR(num value, {bool signed = false, bool absolute = false}) {
  final rounded = value.round();
  final digits = _groupIndian(rounded.abs());
  final sign = signed
      ? (rounded < 0
            ? '−'
            : rounded > 0
            ? '+'
            : '')
      : (rounded < 0 && !absolute ? '−' : '');
  return '$sign₹$digits';
}

/// `10,54,100` (no symbol)
String formatNumber(num value) => _groupIndian(value.round().abs());

/// The prototype's `R()` helper: always positive, sign rendered separately.
String rupee(num value) => '₹${_groupIndian(value.round().abs())}';

/// The prototype's `cp()` compact formatter: `₹1.42L`, `₹86.3k`, `₹980`.
String compactINR(num value) {
  final n = value.abs();
  if (n >= 100000) {
    final text = (n / 100000).toStringAsFixed(2);
    return '₹${_trim(text)}L';
  }
  if (n >= 1000) {
    final text = (n / 1000).toStringAsFixed(1);
    return '₹${_trim(text)}k';
  }
  return '₹${n.round()}';
}

String compactNumber(num value) {
  final n = value.abs();
  if (n >= 100000) {
    final text = (n / 100000).toStringAsFixed(2);
    return '${_trim(text)}L';
  }
  if (n >= 1000) {
    final text = (n / 1000).toStringAsFixed(1);
    return '${_trim(text)}k';
  }
  return '${n.round()}';
}

String _trim(String text) {
  var out = text;
  while (out.contains('.') && (out.endsWith('0') || out.endsWith('.'))) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/// `−₹340` / `+₹340` used by transaction rows.
String signedRupee(num value) =>
    value < 0 ? '−${rupee(value)}' : '+${rupee(value)}';

String percent(num value, {int decimals = 0}) =>
    '${value.toStringAsFixed(decimals)}%';
