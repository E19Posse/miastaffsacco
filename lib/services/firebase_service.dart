import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/transactions/transactions_screen.dart';
import '../screens/loans/guarantor_requests_screen.dart';
import '../screens/kyc/kyc_screen.dart';
import '../screens/security/sessions_screen.dart';

/// Handles FCM initialisation, token registration, and foreground messages.
/// Call [FirebaseService.init] once from main() after Firebase.initializeApp().
class FirebaseService {
  FirebaseService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _api       = ApiService();

  // Message handlers are wired exactly once, but token (re)registration runs on
  // every call so a freshly signed-in user always gets their device registered.
  static bool _handlersReady = false;

  /// Initialise FCM: request permission, register token, set up handlers.
  /// Call this each time the user becomes authenticated — it is idempotent.
  /// Silently no-ops if Firebase is not configured (google-services.json missing).
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase not configured — push notifications disabled
      return;
    }

    // Request notification permission (Android 13+, iOS). Safe to call again.
    final settings = await _messaging.requestPermission(
      alert:       true,
      badge:       true,
      sound:       true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Wire message handlers once — calling init() again on a later login must not
    // attach duplicate listeners (which would show duplicate foreground banners).
    if (!_handlersReady) {
      // Refresh token whenever Firebase rotates it
      _messaging.onTokenRefresh.listen(_sendTokenToServer);

      // Handle messages while app is in the foreground
      FirebaseMessaging.onMessage.listen(_handleForeground);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a terminated state via notification.
      // Delay so the router/auth has settled on the home shell before we deep-link.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        Future.delayed(const Duration(milliseconds: 1200), () => _handleNotificationTap(initial));
      }
      _handlersReady = true;
    }

    // Always (re)register the device token for the currently signed-in user.
    await _registerToken();
  }

  // Global navigator key — set from main.dart for deep-link navigation
  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _sendTokenToServer(token);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token registration failed: $e');
    }
  }

  static Future<void> _sendTokenToServer(String token) async {
    try {
      await _api.updateFcmToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to send FCM token to server: $e');
    }
  }

  static void _handleForeground(RemoteMessage message) {
    if (kDebugMode) debugPrint('FCM foreground: ${message.notification?.title}');
    // Show in-app banner
    final context = navigatorKey?.currentContext;
    if (context == null) return;
    final title = message.notification?.title ?? '';
    final body  = message.notification?.body  ?? '';
    if (title.isEmpty && body.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (body.isNotEmpty)  Text(body,  style: const TextStyle(fontSize: 13)),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    final type = (message.data['type'] as String?)?.toLowerCase() ?? '';

    // Map the notification category to the most relevant screen. Anything we
    // don't recognise opens the notifications list so the message is still seen.
    Widget? target;
    switch (type) {
      case 'guarantor':
        target = const GuarantorRequestsScreen();
        break;
      case 'payment':
      case 'repayment':
      case 'withdrawal':
        target = const TransactionsScreen();
        break;
      case 'kyc':
      case 'identity_verification':
        target = const KycScreen();
        break;
      case 'security':
      case 'suspicious_activity':
        target = const SessionsScreen();
        break;
      case 'loan':
      case 'loan_reminder':
      case 'goal':
      case 'goal_reminder':
        target = const NotificationsScreen();
        break;
      default:
        target = const NotificationsScreen();
    }

    nav.push(MaterialPageRoute(builder: (_) => target!));
  }
}
