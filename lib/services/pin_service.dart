import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyPin     = 'app_pin';
  static const _keyEnabled = 'pin_lock_enabled';
  static const _keyTimeout = 'lock_timeout_minutes';

  /// Default minutes of inactivity before the app auto-locks / signs out.
  static const int defaultTimeoutMinutes = 2;

  static Future<bool> isEnabled() async {
    final v = await _storage.read(key: _keyEnabled);
    return v == 'true';
  }

  /// Live timeout (minutes) so the running app picks up changes immediately when
  /// the user adjusts it in Settings. 0 = disabled (no auto-lock on inactivity).
  static final ValueNotifier<int> timeoutNotifier =
      ValueNotifier<int>(defaultTimeoutMinutes);

  /// Inactivity timeout in minutes. 0 = disabled (no auto-lock on inactivity).
  static Future<int> getTimeoutMinutes() async {
    final v = await _storage.read(key: _keyTimeout);
    final mins = v == null ? defaultTimeoutMinutes : (int.tryParse(v) ?? defaultTimeoutMinutes);
    timeoutNotifier.value = mins;
    return mins;
  }

  static Future<void> setTimeoutMinutes(int minutes) async {
    await _storage.write(key: _keyTimeout, value: minutes.toString());
    timeoutNotifier.value = minutes;
  }

  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _keyPin);
    return pin != null && pin.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    await _storage.write(key: _keyPin, value: pin);
    await _storage.write(key: _keyEnabled, value: 'true');
  }

  static Future<bool> verify(String pin) async {
    final stored = await _storage.read(key: _keyPin);
    return stored != null && stored == pin;
  }

  static Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _keyEnabled, value: enabled ? 'true' : 'false');

  static Future<void> clearPin() async {
    await _storage.delete(key: _keyPin);
    await _storage.delete(key: _keyEnabled);
  }
}
