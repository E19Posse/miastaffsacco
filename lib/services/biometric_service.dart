import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth    = LocalAuthentication();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyEnabled = 'biometric_enabled';

  static Future<bool> isAvailable() async {
    try {
      // canCheckBiometrics = hardware present AND a biometric is actually
      // enrolled. isDeviceSupported() alone stays true even with nothing
      // enrolled, so using OR let the toggle show as available on devices
      // with no fingerprint/face registered — enabling it then always failed
      // with "Biometric verification failed. Not enabled." since there was
      // nothing for authenticate() to check against. Require both.
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final v = await _storage.read(key: _keyEnabled);
    return v == 'true';
  }

  static Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _keyEnabled, value: enabled ? 'true' : 'false');

  /// Prompt biometric authentication. Returns true on success.
  static Future<bool> authenticate({String reason = 'Verify your identity to sign in'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // Device PIN/pattern fallback (biometricOnly: false) leaves the
          // BiometricPrompt session in a state where later fingerprint/FaceID
          // attempts silently fail on many Android devices. Biometric-only
          // here; the password form below is always available as a fallback.
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
