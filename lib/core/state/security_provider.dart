import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/persistence/pin_vault.dart';

@immutable
class SecurityState {
  const SecurityState({
    required this.isLocked,
    required this.hasPin,
    required this.biometricsEnabled,
    required this.biometricsSupported,
    this.isAuthenticatingBiometrics = false,
    this.lockoutSecondsRemaining = 0,
  });

  final bool isLocked;
  final bool hasPin;
  final bool biometricsEnabled;
  final bool biometricsSupported;
  final bool isAuthenticatingBiometrics;
  final int lockoutSecondsRemaining;

  bool get isLockEnabled => hasPin || biometricsEnabled;
  bool get isLockedOut => lockoutSecondsRemaining > 0;

  SecurityState copyWith({
    bool? isLocked,
    bool? hasPin,
    bool? biometricsEnabled,
    bool? biometricsSupported,
    bool? isAuthenticatingBiometrics,
    int? lockoutSecondsRemaining,
  }) {
    return SecurityState(
      isLocked: isLocked ?? this.isLocked,
      hasPin: hasPin ?? this.hasPin,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      biometricsSupported: biometricsSupported ?? this.biometricsSupported,
      isAuthenticatingBiometrics:
          isAuthenticatingBiometrics ?? this.isAuthenticatingBiometrics,
      lockoutSecondsRemaining:
          lockoutSecondsRemaining ?? this.lockoutSecondsRemaining,
    );
  }
}

class SecurityNotifier extends Notifier<SecurityState> {
  Timer? _lockoutTimer;
  DateTime? _lastAuthTime;

  bool get wasRecentlyAuthenticated {
    if (_lastAuthTime == null) return false;
    return DateTime.now().difference(_lastAuthTime!).inMilliseconds < 2500;
  }

  @override
  SecurityState build() {
    final hasPin = PinVault.hasPin;
    final biometrics = PinVault.biometricsEnabled;
    final isLocked = hasPin || biometrics;

    final initial = SecurityState(
      isLocked: isLocked,
      hasPin: hasPin,
      biometricsEnabled: biometrics,
      biometricsSupported: false,
      lockoutSecondsRemaining: PinVault.lockoutRemainingSeconds,
    );

    // Check biometrics asynchronously and update state.
    Future.microtask(() async {
      await refreshBiometricsSupport();
      _startLockoutCountdownIfNeeded();
    });

    ref.onDispose(() {
      _lockoutTimer?.cancel();
    });

    return initial;
  }

  Future<void> refreshBiometricsSupport() async {
    final supported = await PinVault.isBiometricsSupported();
    state = state.copyWith(
      biometricsSupported: supported,
      hasPin: PinVault.hasPin,
      biometricsEnabled: PinVault.biometricsEnabled,
    );
  }

  void _startLockoutCountdownIfNeeded() {
    _lockoutTimer?.cancel();
    final remaining = PinVault.lockoutRemainingSeconds;
    if (remaining > 0) {
      state = state.copyWith(lockoutSecondsRemaining: remaining);
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final sec = PinVault.lockoutRemainingSeconds;
        if (sec <= 0) {
          timer.cancel();
          PinVault.resetLockout();
          state = state.copyWith(lockoutSecondsRemaining: 0);
        } else {
          state = state.copyWith(lockoutSecondsRemaining: sec);
        }
      });
    } else {
      state = state.copyWith(lockoutSecondsRemaining: 0);
    }
  }

  /// Manually lock the app.
  void lock() {
    if (state.isLockEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }

  /// Unlock the app after authentication.
  void unlock() {
    _lastAuthTime = DateTime.now();
    _lockoutTimer?.cancel();
    PinVault.resetLockout();
    state = state.copyWith(isLocked: false, lockoutSecondsRemaining: 0);
  }

  /// Verifies entered PIN. Unlocks if valid; records attempt and starts timer if invalid.
  bool verifyPin(String pin) {
    if (state.isLockedOut) return false;

    if (PinVault.verify(pin)) {
      unlock();
      return true;
    } else {
      PinVault.recordFailedAttempt();
      _startLockoutCountdownIfNeeded();
      return false;
    }
  }

  /// Attempts biometric authentication.
  Future<bool> authenticateBiometrics({
    String reason = 'Unlock Spendwiser',
    bool isSetup = false,
  }) async {
    if (state.isLockedOut) return false;
    if (!isSetup && !state.biometricsEnabled) return false;

    state = state.copyWith(isAuthenticatingBiometrics: true);
    try {
      final success = await PinVault.authenticateBiometrics(reason: reason);
      if (success) {
        _lastAuthTime = DateTime.now();
        return true;
      }
      return false;
    } finally {
      // Grace period to allow the native Activity resume event to settle
      // without falsely re-locking the app.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(isAuthenticatingBiometrics: false);
    }
  }

  /// Set a new 4-digit PIN.
  Future<void> setPin(String pin) async {
    await PinVault.setPin(pin);
    state = state.copyWith(
      hasPin: true,
      lockoutSecondsRemaining: 0,
    );
  }

  /// Clears PIN and disables biometrics.
  Future<void> removePin() async {
    await PinVault.clearPin();
    state = state.copyWith(
      hasPin: false,
      biometricsEnabled: false,
      isLocked: false,
      lockoutSecondsRemaining: 0,
    );
  }

  /// Toggles biometric unlock.
  Future<void> setBiometricsEnabled(bool enabled) async {
    await PinVault.setBiometricsEnabled(enabled);
    state = state.copyWith(biometricsEnabled: enabled);
  }
}

final securityProvider =
    NotifierProvider<SecurityNotifier, SecurityState>(SecurityNotifier.new);

