import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/theme_provider.dart';
import 'services/device_service.dart';
import 'services/storage_service.dart';

// Supplied at build time via --dart-define=SENTRY_DSN=...; empty = Sentry disabled.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A missing/broken native Firebase config (e.g. no GoogleService-Info.plist
  // on iOS) must not hard-crash the app before it ever reaches the login
  // screen — degrade to no crash reporting / push instead, same as the
  // no-op fallback in FirebaseService.init().
  bool firebaseReady = true;
  try {
    await Firebase.initializeApp();
  } catch (_) {
    firebaseReady = false;
  }

  if (firebaseReady) {
    // Route all Flutter framework errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Route uncaught async/platform errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Replace the default red error screen with a plain message in release
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Material(
      child: Center(
        child: Text(
          'Something went wrong. Please restart the app.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Request storage and location permissions for offline caching and audit geo-tagging
  await DeviceService.requestStoragePermission();
  await DeviceService.requestLocationPermission();

  final authProvider    = AuthProvider();
  final store           = StorageService();
  final hasSeenOnboard  = await store.hasSeenOnboarding();

  await authProvider.init(); // restore session from secure storage

  void start() => runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: SaccoApp(showOnboarding: !hasSeenOnboard),
        ),
      );

  // Sentry mirrors Crashlytics into a unified dashboard with the Laravel backend.
  // With no DSN supplied it is a no-op, so default builds are unaffected.
  if (_sentryDsn.isEmpty) {
    start();
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.1;
        options.environment = kReleaseMode ? 'production' : 'debug';
      },
      appRunner: start,
    );
  }
}
