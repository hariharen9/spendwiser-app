import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';

/// Secure PIN hash storage + Biometrics helper.
///
/// The PIN is never stored in plaintext — we store `sha256(spendwiser-pin:$pin)`
/// as hex in the settings Hive box.
abstract final class PinVault {
  static const _pinHashKey = 'pinHash';
  static const _biometricsKey = 'biometricsEnabled';
  static const _autoLockMinutesKey = 'autoLockMinutes';
  static const _failedAttemptsKey = 'pinFailedAttempts';
  static const _lockedUntilKey = 'pinLockedUntil';
  static const int defaultAutoLockMinutes = 5;

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('spendwiser-pin:$pin')).toString();

  static Box<String>? get _box {
    try {
      if (Hive.isBoxOpen('settings')) return Hive.box<String>('settings');
    } catch (_) {}
    return null;
  }

  /// Whether a 4-digit PIN is currently set.
  static bool get hasPin {
    final val = _box?.get(_pinHashKey);
    return val != null && val.isNotEmpty;
  }

  /// Whether biometrics (fingerprint / face) unlock is enabled by the user.
  static bool get biometricsEnabled =>
      _box?.get(_biometricsKey) == 'true';

  /// Whether the app has security locking turned on.
  static bool get isLockEnabled => hasPin || biometricsEnabled;

  /// Verifies the entered PIN against the stored hash.
  static bool verify(String pin) {
    final stored = _box?.get(_pinHashKey);
    if (stored == null || stored.isEmpty) return false;
    return stored == _hash(pin);
  }

  /// Sets a new PIN.
  static Future<void> setPin(String pin) async {
    await _box?.put(_pinHashKey, _hash(pin));
    await resetLockout();
  }

  /// Removes PIN and disables biometrics.
  static Future<void> clearPin() async {
    await _box?.delete(_pinHashKey);
    await _box?.delete(_biometricsKey);
    await resetLockout();
  }

  /// Sets whether biometrics are enabled.
  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _box?.put(_biometricsKey, enabled ? 'true' : 'false');
  }

  /// Grace period (in minutes) after unlocking before backgrounding re-locks.
  static int get autoLockMinutes {
    final raw = _box?.get(_autoLockMinutesKey);
    final parsed = raw == null ? null : int.tryParse(raw);
    if (parsed == null || parsed < 0) return defaultAutoLockMinutes;
    return parsed;
  }

  /// Persists the post-unlock auto-lock grace period in minutes.
  static Future<void> setAutoLockMinutes(int minutes) async {
    await _box?.put(_autoLockMinutesKey, minutes.clamp(0, 1440).toString());
  }

  /// Check whether hardware and OS support biometrics.
  static Future<bool> isBiometricsSupported() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();
      return canCheck || isSupported || available.isNotEmpty;
    } catch (e) {
      debugPrint('Biometrics support check error: $e');
      return true;
    }
  }

  /// Get list of enrolled biometric types (e.g. fingerprint, face).
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Available biometrics check error: $e');
      return const [];
    }
  }

  /// Attempts biometric authentication with user prompt.
  static Future<bool> authenticateBiometrics({
    String reason = 'Unlock Spendwiser',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authenticate PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric authenticate error: $e');
      return false;
    }
  }

  // --- Lockout handling after consecutive failed attempts ---

  static int get failedAttempts {
    final raw = _box?.get(_failedAttemptsKey);
    if (raw == null) return 0;
    return int.tryParse(raw) ?? 0;
  }

  static DateTime? get lockedUntil {
    final raw = _box?.get(_lockedUntilKey);
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static bool get isLockedOut {
    final until = lockedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  static int get lockoutRemainingSeconds {
    final until = lockedUntil;
    if (until == null) return 0;
    final diff = until.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  static Future<void> recordFailedAttempt() async {
    final attempts = failedAttempts + 1;
    await _box?.put(_failedAttemptsKey, attempts.toString());
    if (attempts >= 5) {
      // 30 seconds lockout after 5 failed attempts
      final until = DateTime.now().add(const Duration(seconds: 30));
      await _box?.put(_lockedUntilKey, until.millisecondsSinceEpoch.toString());
    }
  }

  static Future<void> resetLockout() async {
    await _box?.delete(_failedAttemptsKey);
    await _box?.delete(_lockedUntilKey);
  }
}
