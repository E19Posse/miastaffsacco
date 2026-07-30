import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _api   = ApiService();
  final _store = StorageService();

  AuthState _state  = AuthState.unknown;
  Member?   _member;
  String?   _error;
  bool      _requiresVerification = false;
  bool      _biometricLockPending = false;
  bool      _forceUpdateRequired  = false;
  String    _updateMessage        = 'Please update the app to continue.';

  bool    _isImpersonating = false;
  String? _impersonatedName;

  AuthProvider() {
    _api.onUnauthorized = _forceLogout;
  }

  /// True only when [e] is a genuine "your token is no longer valid" response.
  /// A network timeout, DNS failure, or transient 5xx must NOT be treated the
  /// same way — those leave a perfectly good stored token, and wiping it on
  /// every cold-start hiccup was silently disabling biometric login (which
  /// requires a stored token to restore the session behind the biometric gate).
  bool _isAuthFailure(Object e) => e is DioException && e.response?.statusCode == 401;

  /// Called by [ApiService] when the server rejects an authenticated request
  /// with 401 — the stored token is already cleared at that point, so this
  /// just brings app state in sync so GoRouter redirects to /login instead of
  /// leaving screens stuck showing "Unauthenticated." snackbars forever.
  void _forceLogout() {
    if (_state == AuthState.unauthenticated) return;
    _member = null;
    _requiresVerification = false;
    _biometricLockPending = false;
    _isImpersonating      = false;
    _impersonatedName     = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  AuthState get state                => _state;
  Member?   get member               => _member;
  String?   get error                => _error;
  bool      get loading              => _state == AuthState.unknown;
  bool      get requiresVerification => _requiresVerification;
  bool      get biometricLockPending => _biometricLockPending;
  bool      get forceUpdateRequired  => _forceUpdateRequired;
  String    get updateMessage        => _updateMessage;
  bool      get isImpersonating      => _isImpersonating;
  String?   get impersonatedName     => _impersonatedName;

  /// Register this device for push notifications. Fire-and-forget — it must never
  /// block sign-in, and is idempotent (see [FirebaseService.init]).
  void _enablePush() => unawaited(FirebaseService.init());

  Future<void> init() async {
    // Check for forced app update before anything else
    final versionInfo = await _api.getAppVersion();
    if (versionInfo['force_update'] == true) {
      _forceUpdateRequired = true;
      _updateMessage = versionInfo['update_message'] as String? ?? _updateMessage;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    final token = await _store.getToken();
    if (token == null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final data = await _api.getMe();
      _member = Member.fromJson(data['data'] ?? data);
      // Check locally if 30-day verification is due (fast path before any API call fails)
      _requiresVerification = await _store.isIdentityVerificationDue();

      // Biometric login: if enabled and usable, don't silently auto-enter — hold the
      // (already-restored) session behind a biometric prompt on the login screen.
      // A successful biometric check then calls completeBiometricLogin() to enter.
      final bioEnabled = await BiometricService.isEnabled();
      final bioAvail   = bioEnabled && await BiometricService.isAvailable();
      if (bioAvail) {
        _biometricLockPending = true;
        _state = AuthState.unauthenticated;
      } else {
        _state = AuthState.authenticated;
        _enablePush();
      }
    } catch (e) {
      // Only a genuine 401 means the token is actually dead. Anything else
      // (no internet at cold start, timeout, transient 5xx) leaves the token
      // untouched so the app can retry, and so biometric login — which needs
      // that stored token — stays available instead of silently vanishing.
      if (_isAuthFailure(e)) await _store.clearSession();
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    _requiresVerification = false;
    notifyListeners();
    try {
      final res = await _api.login(email, password);
      await _store.saveToken(res['token']);

      final memberData = res['member'] ?? res['user'];
      if (memberData != null) {
        _member = Member.fromJson(memberData);
        await _store.saveMember(jsonEncode(memberData));
      }

      // Persist identity_verified_at returned by the server
      final verifiedAt = res['identity_verified_at'] as String?;
      if (verifiedAt != null) {
        await _store.saveIdentityVerifiedAt(verifiedAt);
      }

      _requiresVerification = res['requires_identity_verification'] == true;
      _biometricLockPending = false; // password login enters directly
      _state = AuthState.authenticated;
      _enablePush();
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = ApiService.extractError(e);
      notifyListeners();
      return false;
    }
  }

  /// Complete self-registration (step 2). The API returns the same token+member
  /// shape as login(), so we sign the new member straight in.
  Future<bool> completeRegistration(Map<String, dynamic> res) async {
    try {
      await _store.saveToken(res['token']);

      final memberData = res['member'] ?? res['user'];
      if (memberData != null) {
        _member = Member.fromJson(memberData);
        await _store.saveMember(jsonEncode(memberData));
      }

      _requiresVerification = res['requires_identity_verification'] == true;
      _biometricLockPending = false;
      _state = AuthState.authenticated;
      _enablePush();
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = ApiService.extractError(e);
      notifyListeners();
      return false;
    }
  }

  /// Complete a biometric login. The session (member) was already restored from the
  /// stored token in init() and held behind the biometric gate; a successful
  /// biometric check flips state to authenticated. Returns false if the stored
  /// session could no longer be loaded (e.g. token revoked) — caller should fall
  /// back to password sign-in.
  Future<bool> completeBiometricLogin() async {
    if (_member == null) {
      try {
        final data = await _api.getMe();
        _member = Member.fromJson(data['data'] ?? data);
        _requiresVerification = await _store.isIdentityVerificationDue();
      } catch (e) {
        if (_isAuthFailure(e)) await _store.clearSession();
        _biometricLockPending = false;
        _state = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
    }
    _biometricLockPending = false;
    _state = AuthState.authenticated;
    _enablePush();
    notifyListeners();
    return true;
  }

  /// Called from IdentityVerificationScreen after the user confirms their password.
  Future<bool> verifyIdentity(String password) async {
    _error = null;
    try {
      final res = await _api.verifyIdentity(password);
      final verifiedAt = res['identity_verified_at'] as String?;
      if (verifiedAt != null) {
        await _store.saveIdentityVerifiedAt(verifiedAt);
      }
      _requiresVerification = false;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = ApiService.extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(File file) async {
    try {
      final url = await _api.uploadAvatar(file);
      _member = _member?.withAvatar(url);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeAvatar() async {
    try {
      await _api.removeAvatar();
      _member = _member?.withAvatar(null);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> impersonateUser(int userId, String userName) async {
    _error = null;
    try {
      final adminToken = await _store.getToken();
      if (adminToken == null) throw Exception('No active session.');

      final res   = await _api.startImpersonation(userId);
      final token = res['token'] as String;

      await _store.saveAdminToken(adminToken);
      await _store.saveToken(token);

      final data = await _api.getMe();
      _member           = Member.fromJson(data['data'] ?? data);
      _isImpersonating  = true;
      _impersonatedName = userName;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = ApiService.extractError(e);
      notifyListeners();
      return false;
    }
  }

  /// Re-fetches the current member from the server and updates local state.
  /// Use after an action that changes server-side member flags the app
  /// already holds a stale copy of (e.g. setting a transaction PIN), so
  /// screens reading `member` don't need a logout/login to see the change.
  Future<void> refreshMember() async {
    try {
      final data = await _api.getMe();
      _member = Member.fromJson(data['data'] ?? data);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> stopImpersonation() async {
    try { await _api.stopImpersonation(); } catch (_) {}
    final adminToken = await _store.getAdminToken();
    if (adminToken != null) {
      await _store.saveToken(adminToken);
      await _store.clearAdminToken();
    }
    try {
      final data = await _api.getMe();
      _member = Member.fromJson(data['data'] ?? data);
    } catch (_) {}
    _isImpersonating  = false;
    _impersonatedName = null;
    notifyListeners();
  }

  Future<void> logout() async {
    if (_isImpersonating) await stopImpersonation();
    await _api.logout();
    _member = null;
    _requiresVerification = false;
    _biometricLockPending = false;
    _isImpersonating      = false;
    _impersonatedName     = null;
    _state  = AuthState.unauthenticated;
    notifyListeners();
  }
}
