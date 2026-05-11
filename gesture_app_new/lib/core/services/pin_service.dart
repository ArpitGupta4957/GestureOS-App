import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle setting, verifying, and removing the App PIN securely.
class PinService {
  final FlutterSecureStorage _secureStorage;
  static const String _pinHashKey = 'app_pin_hash';
  static const String _useBiometricsKey = 'use_biometrics';

  PinService(this._secureStorage);

  /// securely hashes a PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Saves the hashed PIN.
  Future<void> setPin(String pin) async {
    final hashedPin = _hashPin(pin);
    await _secureStorage.write(key: _pinHashKey, value: hashedPin);
  }

  /// Verifies the entered PIN against the stored hash.
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    return inputHash == storedHash;
  }

  /// Checks if a PIN exists.
  Future<bool> hasPin() async {
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    return storedHash != null && storedHash.isNotEmpty;
  }

  /// Removes the PIN (e.g. on fallback logout or explicit removal).
  Future<void> removePin() async {
    await _secureStorage.delete(key: _pinHashKey);
  }

  /// Sets user preference for biometrics.
  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBiometricsKey, enabled);
  }

  /// Gets user preference for biometrics.
  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useBiometricsKey) ?? false;
  }
}
