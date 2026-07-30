import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/pin/pin_lock_screen.dart';
import 'screens/identity_verification/identity_verification_screen.dart';
import 'services/pin_service.dart';
import 'theme/app_theme.dart';
import 'package:unicons/unicons.dart';

GoRouter buildRouter(AuthProvider auth, {required bool showOnboarding}) =>
    GoRouter(
      initialLocation: showOnboarding ? '/onboarding' : '/splash',
      refreshListenable: auth,
      redirect: (ctx, state) {
        final authProvider = ctx.read<AuthProvider>();
        final authState    = authProvider.state;
        final loc          = state.matchedLocation;
        final onOnboarding = loc == '/onboarding';
        final onSplash     = loc == '/splash';
        final onLogin      = loc == '/login';
        final onVerify     = loc == '/verify-identity';

        // Never redirect away from onboarding or splash
        if (onOnboarding || onSplash) return null;

        if (authState == AuthState.unknown) return onLogin ? null : '/login';

        if (authState == AuthState.unauthenticated && !onLogin) return '/login';

        if (authState == AuthState.authenticated) {
          // If 30-day re-verification is due, gate all routes behind verify screen
          if (authProvider.requiresVerification && !onVerify) {
            return '/verify-identity';
          }
          if (onLogin || onVerify && !authProvider.requiresVerification) {
            return '/home';
          }
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash',            builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboarding',        builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/login',             builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/verify-identity',   builder: (_, __) => const IdentityVerificationScreen()),
        GoRoute(path: '/home',              builder: (_, __) => const MainShell()),
      ],
      errorBuilder: (context, state) {
        final c = context.colors;
        return Scaffold(
          backgroundColor: c.bg,
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(UniconsLine.exclamation_circle, color: c.textHint, size: 48),
              const SizedBox(height: 12),
              Text('Page not found', style: TextStyle(color: c.textSecondary)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go Home',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ]),
          ),
        );
      },
    );

class SaccoApp extends StatefulWidget {
  final bool showOnboarding;
  const SaccoApp({super.key, this.showOnboarding = false});
  @override State<SaccoApp> createState() => _SaccoAppState();
}

class _SaccoAppState extends State<SaccoApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  bool   _locked            = false;
  bool   _wasBackgrounded   = false;
  Timer? _inactivityTimer;
  int    _timeoutMinutes    = PinService.defaultTimeoutMinutes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = buildRouter(
      context.read<AuthProvider>(),
      showOnboarding: widget.showOnboarding,
    );
    // Pick up live changes to the inactivity timeout made in Settings.
    PinService.timeoutNotifier.addListener(_onTimeoutChanged);
    PinService.getTimeoutMinutes().then((m) {
      _timeoutMinutes = m;
      _resetInactivityTimer();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndLock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PinService.timeoutNotifier.removeListener(_onTimeoutChanged);
    _inactivityTimer?.cancel();
    _router.dispose();
    super.dispose();
  }

  void _onTimeoutChanged() {
    _timeoutMinutes = PinService.timeoutNotifier.value;
    _resetInactivityTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
      _inactivityTimer?.cancel();
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _checkAndLock();
      _resetInactivityTimer();
    }
  }

  Future<void> _checkAndLock() async {
    final auth = context.read<AuthProvider>();
    if (auth.state != AuthState.authenticated) return;
    final pinEnabled = await PinService.isEnabled();
    if (pinEnabled && mounted) setState(() => _locked = true);
  }

  /// Called on every touch — restarts the idle countdown.
  void _onUserActivity([_]) => _resetInactivityTimer();

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_timeoutMinutes <= 0 || _locked) return;
    final auth = context.read<AuthProvider>();
    if (auth.state != AuthState.authenticated) return;
    _inactivityTimer =
        Timer(Duration(minutes: _timeoutMinutes), _onInactive);
  }

  /// Fired after the configured idle period: lock behind the PIN/biometric if a
  /// PIN is set, otherwise sign the user out entirely.
  Future<void> _onInactive() async {
    if (!mounted || _locked) return;
    final auth = context.read<AuthProvider>();
    if (auth.state != AuthState.authenticated) return;
    final pinEnabled = await PinService.isEnabled();
    if (pinEnabled) {
      if (mounted) setState(() => _locked = true);
    } else {
      await auth.logout(); // refreshListenable -> router redirects to /login
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    return MaterialApp.router(
      title: 'MIA Staff SACCO',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
      builder: (ctx, child) {
        final mq = MediaQuery.of(ctx);
        // Clamp text scale so accessibility font sizes don't overflow fixed containers
        final content = MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onUserActivity,
            onPointerMove: _onUserActivity,
            child: Stack(
              children: [
                child ?? const SizedBox(),
                if (_locked)
                  PinLockScreen(onUnlocked: () {
                    setState(() => _locked = false);
                    _resetInactivityTimer();
                  }),
              ],
            ),
          ),
        );
        return content;
      },
    );
  }
}
