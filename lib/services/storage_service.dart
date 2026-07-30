import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken            = 'auth_token';
  static const _keyDeviceId         = 'device_install_id';
  static const _keyMember           = 'member_json';
  static const _keyOnboarded        = 'onboarding_seen';
  static const _keyIdentityVerified = 'identity_verified_at';
  static const _keyAdminToken       = 'admin_token_backup';
  static const _keyRememberedEmail    = 'remembered_email';
  static const _keyRememberedPassword = 'remembered_password';
  static const _keyBalanceHidden      = 'balance_hidden';
  static const _keyBiometricEmail     = 'biometric_email';
  static const _keyBiometricPassword  = 'biometric_password';

  /// Stable per-install identifier used to key each device's login token.
  /// Two physical devices of the same model (e.g. two identical Pixel 7s, or
  /// two emulators) previously collided on device_model alone, so a second
  /// device's login silently deleted the first device's token server-side —
  /// killing its session and breaking biometric unlock there. This UUID is
  /// generated once and persisted, so it is unique per install regardless of
  /// model. Never cleared by [clearSession] — it identifies the device, not
  /// the session.
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _keyDeviceId, value: id);
    return id;
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  Future<String?> getToken() => _storage.read(key: _keyToken);

  Future<void> clearToken() => _storage.delete(key: _keyToken);

  Future<void> saveMember(String json) =>
      _storage.write(key: _keyMember, value: json);

  Future<String?> getMember() => _storage.read(key: _keyMember);

  Future<bool> hasSeenOnboarding() async =>
      (await _storage.read(key: _keyOnboarded)) == 'true';

  Future<void> setOnboardingSeen() =>
      _storage.write(key: _keyOnboarded, value: 'true');

  Future<void> saveIdentityVerifiedAt(String isoDate) =>
      _storage.write(key: _keyIdentityVerified, value: isoDate);

  Future<DateTime?> getIdentityVerifiedAt() async {
    final val = await _storage.read(key: _keyIdentityVerified);
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  Future<bool> isIdentityVerificationDue() async {
    final verifiedAt = await getIdentityVerifiedAt();
    if (verifiedAt == null) return true;
    return DateTime.now().difference(verifiedAt).inDays >= 30;
  }

  Future<void> saveAdminToken(String token) =>
      _storage.write(key: _keyAdminToken, value: token);

  Future<String?> getAdminToken() => _storage.read(key: _keyAdminToken);

  Future<void> clearAdminToken() => _storage.delete(key: _keyAdminToken);

  Future<bool> get isImpersonating async =>
      (await _storage.read(key: _keyAdminToken)) != null;

  Future<void> saveRememberedCredentials(String email, String password) async {
    await _storage.write(key: _keyRememberedEmail, value: email);
    await _storage.write(key: _keyRememberedPassword, value: password);
  }

  Future<({String email, String password})?> getRememberedCredentials() async {
    final email    = await _storage.read(key: _keyRememberedEmail);
    final password = await _storage.read(key: _keyRememberedPassword);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  Future<void> clearRememberedCredentials() async {
    await _storage.delete(key: _keyRememberedEmail);
    await _storage.delete(key: _keyRememberedPassword);
  }

  /// Credentials biometric login replays through a real login() call when
  /// there's no stored session token to restore (e.g. after logout, or the
  /// token naturally expired) — otherwise biometric could only ever "unlock"
  /// an existing session, never actually sign a fully logged-out user back in.
  Future<void> saveBiometricCredentials(String email, String password) async {
    await _storage.write(key: _keyBiometricEmail, value: email);
    await _storage.write(key: _keyBiometricPassword, value: password);
  }

  Future<({String email, String password})?> getBiometricCredentials() async {
    final email    = await _storage.read(key: _keyBiometricEmail);
    final password = await _storage.read(key: _keyBiometricPassword);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: _keyBiometricEmail);
    await _storage.delete(key: _keyBiometricPassword);
  }

  Future<bool> isBalanceHidden() async =>
      (await _storage.read(key: _keyBalanceHidden)) == 'true';

  Future<void> setBalanceHidden(bool hidden) =>
      _storage.write(key: _keyBalanceHidden, value: hidden ? 'true' : 'false');

  /// Ends the current session (token/member/impersonation) without touching
  /// device-level preferences — biometric enrollment, remembered credentials,
  /// onboarding, balance-hidden. Use this for logout, 401s, and any "session
  /// no longer valid" path. [clearAll] wipes everything and should only be
  /// used for a deliberate "forget this device" action, if one is ever added.
  Future<void> clearSession() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyMember);
    await _storage.delete(key: _keyAdminToken);
  }

  Future<void> clearAll() => _storage.deleteAll();
}
