import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../auth/forgot_password_screen.dart';
import '../auth/register_screen.dart';
import 'package:unicons/unicons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _store     = StorageService();
  bool _obscure         = true;
  bool _busy            = false;
  bool _biometricReady  = false;
  bool _rememberMe      = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final available = await BiometricService.isAvailable();
    final enabled   = await BiometricService.isEnabled();
    final hasToken  = await _store.getToken() != null;
    final bioCreds  = await _store.getBiometricCredentials();
    final saved     = await _store.getRememberedCredentials();
    if (!mounted) return;

    // Ready if there's either a session to restore (hasToken) OR stored
    // credentials biometric can replay through a real login() — otherwise a
    // fully logged-out user (no token at all) would never see the biometric
    // option even with it enabled, since there'd be nothing to "unlock".
    final biometricReady = available && enabled && (hasToken || bioCreds != null);
    setState(() {
      _biometricReady = biometricReady;
      if (saved != null) {
        _emailCtrl.text = saved.email;
        _passCtrl.text  = saved.password;
        _rememberMe     = true;
      }
    });

    // Cold launch held behind the biometric gate → prompt immediately.
    // If cancelled/failed, the password form remains as a fallback.
    //
    // Deliberately NOT auto-submitting the form when remembered credentials
    // are found: this is a banking app, and anyone with physical access to an
    // unlocked/unattended device would otherwise be signed straight in with
    // no further check. Prefilling still removes the need to retype
    // credentials; the user still taps "Sign In" once.
    if (biometricReady && context.read<AuthProvider>().biometricLockPending) {
      _biometricLogin();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final ok = await context.read<AuthProvider>().login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      if (_rememberMe) {
        await _store.saveRememberedCredentials(_emailCtrl.text.trim(), _passCtrl.text);
      } else {
        await _store.clearRememberedCredentials();
      }

      // Offer biometric setup on first successful login
      final available = await BiometricService.isAvailable();
      final enabled   = await BiometricService.isEnabled();
      if (available && !enabled && mounted) {
        _offerBiometricSetup();
      } else {
        context.go('/home');
      }
    } else {
      final err = context.read<AuthProvider>().error ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  void _offerBiometricSetup() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Enable Biometric Login?'),
        content: const Text(
          'Use fingerprint or face recognition to sign in faster next time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () async {
              await BiometricService.setEnabled(true);
              // Store credentials so biometric can sign the user back in with
              // a real login() later, even after a full logout / token expiry
              // — not just "unlock" a session that's still technically valid.
              await _store.saveBiometricCredentials(_emailCtrl.text.trim(), _passCtrl.text);
              Navigator.of(dialogCtx).pop(true);
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) context.go('/home');
    });
  }

  Future<void> _biometricLogin() async {
    setState(() => _busy = true);
    final ok = await BiometricService.authenticate(reason: 'Sign in to TMI Staff SACCO');
    if (!mounted) return;

    if (!ok) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication failed. Use your password.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Restore the held session if one still exists (fast path — no network call).
    var restored = await context.read<AuthProvider>().completeBiometricLogin();

    // No live session to restore (e.g. fully logged out, or the token expired) —
    // replay stored credentials through a real login() so biometric can still
    // sign the user in from scratch, not just unlock an existing session.
    if (!restored) {
      final creds = await _store.getBiometricCredentials();
      if (creds != null) {
        restored = await context.read<AuthProvider>().login(creds.email, creds.password);
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (restored) {
      // Router (refreshListenable) also routes to /home or /verify-identity.
      context.go('/home');
    } else {
      setState(() => _biometricReady = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please sign in with your password.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  InputDecoration _pillInput({required String hint, required IconData icon, Widget? suffix}) {
    final c = context.colors;
    return InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: c.textHint),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      );
  }

  Widget _fieldLabel(String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(), style: TextStyle(
          color: c.textSecondary,
          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Logo lockup
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/logo.png', width: 44, height: 44, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Text('TMI Staff SACCO', style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ]),
              const SizedBox(height: 40),

              Text('Welcome back, Member.', style: GoogleFonts.sora(
                  fontSize: 34, fontWeight: FontWeight.w800, height: 1.05,
                  color: c.textPrimary)),
              const SizedBox(height: 10),
              SizedBox(
                width: 280,
                child: Text('Securing our collective future, one shilling at a time.',
                    style: TextStyle(color: c.textSecondary, fontSize: 14)),
              ),
              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _fieldLabel('Email address'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
                    decoration: _pillInput(hint: 'you@example.com', icon: UniconsLine.envelope),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel('Password'),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
                    decoration: _pillInput(
                      hint: '••••••••', icon: UniconsLine.lock,
                      suffix: IconButton(
                        icon: Icon(_obscure ? UniconsLine.eye : UniconsLine.eye_slash,
                            color: c.textHint),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 8),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: 20, height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                            activeColor: AppColors.emeraldDeep,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Remember me', style: TextStyle(
                            color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: Text('Forgot Password?', style: TextStyle(
                          color: AppColors.emeraldMid, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldDeep,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text('Sign In',
                              style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.emeraldDeep.withValues(alpha: 0.15)),
                        foregroundColor: AppColors.emeraldDeep,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text('New member application',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),

                  if (_biometricReady) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(children: [
                        Text('or sign in with', style: TextStyle(
                            color: c.textHint, fontSize: 12)),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _busy ? null : _biometricLogin,
                          child: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              color: c.card,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border, width: 1.5),
                            ),
                            child: Icon(UniconsLine.lock_alt, size: 32, color: c.textPrimary),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),

              const SizedBox(height: 40),
              Center(
                child: Text('Copyright © TMI Staff SACCO 2026 · V4.0',
                    style: TextStyle(color: c.textSecondary,
                        fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
            ]),
            ),
          ),
        ),
      ),
    );
  }
}
