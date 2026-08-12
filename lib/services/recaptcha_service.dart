import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/api_constants.dart';

/// Captures an invisible Google reCAPTCHA v3 token for self-registration.
///
/// Mirrors the backend's graceful-no-op contract (RegistrationService::verifyCaptcha):
/// with no site key configured this returns null immediately and registration
/// proceeds exactly as it does today. Once RECAPTCHA_SITE_KEY is set at build
/// time (--dart-define) AND the backend has RECAPTCHA_SITE_KEY/SECRET set, a
/// real token is fetched and sent as `recaptcha_token` on `register/start`.
class RecaptchaService {
  RecaptchaService._();

  static const _timeout = Duration(seconds: 8);

  /// Returns a v3 token for [action], or null if no site key is configured,
  /// the page fails to load, or verification times out. Never throws —
  /// a captcha failure here must not be able to brick registration.
  ///
  /// The webview_flutter platform view only actually runs once a WebViewWidget
  /// using its controller is mounted, so this briefly inserts a 1x1, invisible
  /// widget into the nearest [Overlay] for the duration of the token fetch and
  /// removes it as soon as a token (or the timeout) resolves.
  static Future<String?> getToken(BuildContext context, {String action = 'register'}) async {
    const siteKey = ApiConstants.recaptchaSiteKey;
    if (siteKey.isEmpty) return null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    final completer = Completer<String?>();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'RecaptchaChannel',
        onMessageReceived: (msg) {
          if (!completer.isCompleted) {
            completer.complete(msg.message.isEmpty ? null : msg.message);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (_) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ))
      ..loadHtmlString(_html(siteKey, action));

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        width: 1, height: 1, left: -10, top: -10,
        child: IgnorePointer(child: WebViewWidget(controller: controller)),
      ),
    );
    overlay.insert(entry);

    unawaited(Future.delayed(_timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    }));

    String? token;
    try {
      token = await completer.future;
    } catch (e) {
      if (kDebugMode) debugPrint('RecaptchaService: token fetch failed: $e');
      token = null;
    } finally {
      entry.remove();
    }
    return token;
  }

  static String _html(String siteKey, String action) => '''
<!DOCTYPE html>
<html>
<head>
  <script src="https://www.google.com/recaptcha/api.js?render=$siteKey"></script>
</head>
<body>
  <script>
    grecaptcha.ready(function() {
      grecaptcha.execute('$siteKey', {action: '$action'}).then(function(token) {
        RecaptchaChannel.postMessage(token);
      }).catch(function() {
        RecaptchaChannel.postMessage('');
      });
    });
  </script>
</body>
</html>
''';
}
