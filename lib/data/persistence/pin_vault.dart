import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

/// PIN hash storage + verification.
///
/// The PIN is never stored in plaintext — we store `sha256(pin)` as hex in
/// the settings Hive box.
abstract final class PinVault {
  static const _pinHashKey = 'pinHash';
  static const _biometricsKey = 'biometricsEnabled';

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('spendwiser-pin:$pin')).toString();

  static Box<String>? get _box {
    try {
      if (Hive.isBoxOpen('settings')) return Hive.box('settings');
    } catch (_) {}
    return null;
  }

  static bool get hasPin => _box?.get(_pinHashKey) != null;

  static bool verify(String pin) {
    final stored = _box?.get(_pinHashKey);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  static Future<void> setPin(String pin) async {
    await _box?.put(_pinHashKey, _hash(pin));
  }

  static Future<void> clearPin() async {
    await _box?.delete(_pinHashKey);
    await _box?.delete(_biometricsKey);
  }

  static bool get biometricsEnabled =>
      _box?.get(_biometricsKey) == 'true';

  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _box?.put(_biometricsKey, enabled ? 'true' : 'false');
  }
}
