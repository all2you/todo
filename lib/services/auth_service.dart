import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BiometricResult { success, notAvailable, notEnrolled, failed, canceled }

class AuthService {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _pinHashKey = 'app_lock_pin_hash';
  static const _pinSaltKey = 'app_lock_pin_salt';
  static const _lockEnabledPref = 'app_lock_enabled';
  static const _biometricEnabledPref = 'app_lock_biometric_enabled';

  static final _localAuth = LocalAuthentication();

  // ── 잠금 on/off ──────────────────────────────────────────
  static Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockEnabledPref) ?? false;
  }

  static Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockEnabledPref, enabled);
    if (!enabled) {
      await _secure.delete(key: _pinHashKey);
      await _secure.delete(key: _pinSaltKey);
      await prefs.setBool(_biometricEnabledPref, false);
    }
  }

  // ── 생체 인증 옵션 ────────────────────────────────────────
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledPref) ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledPref, enabled);
  }

  static Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  // ── PIN 관리 ─────────────────────────────────────────────
  static Future<bool> hasPin() async {
    final hash = await _secure.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _secure.write(key: _pinSaltKey, value: salt);
    await _secure.write(key: _pinHashKey, value: hash);
  }

  static Future<bool> verifyPin(String pin) async {
    final storedHash = await _secure.read(key: _pinHashKey);
    final salt = await _secure.read(key: _pinSaltKey);
    if (storedHash == null || salt == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static String _generateSalt() {
    // DateTime + hashCode 기반의 간단한 salt. PIN은 4~6자리라 rainbow-table 방어용으로 충분.
    final now = DateTime.now().microsecondsSinceEpoch;
    final raw = '$now-${now.hashCode}';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  }

  // ── 생체 인증 시도 ────────────────────────────────────────
  static Future<BiometricResult> authenticateWithBiometrics({
    String reason = '일기 앱 잠금을 해제합니다',
  }) async {
    try {
      final supported = await canUseBiometrics();
      if (!supported) return BiometricResult.notAvailable;

      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return ok ? BiometricResult.success : BiometricResult.canceled;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) return BiometricResult.notAvailable;
      if (e.code == auth_error.notEnrolled) return BiometricResult.notEnrolled;
      return BiometricResult.failed;
    }
  }
}
