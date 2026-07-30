import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});
  @override State<IdentityVerificationScreen> createState() => _State();
}

class _State extends State<IdentityVerificationScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy    = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final ok = await context.read<AuthProvider>().verifyIdentity(_passCtrl.text);

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      context.go('/home');
    } else {
      final err = context.read<AuthProvider>().error ?? 'Verification failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldDeep.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(UniconsLine.shield_check,
                      size: 44, color: AppColors.emeraldDeep),
                ),
                const SizedBox(height: 24),

                Text('Verify Your Identity',
                    style: GoogleFonts.sora(
                      fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary,
                    )),
                const SizedBox(height: 10),
                Text(
                  'For your security, please confirm your password.\nThis is required every 30 days.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary, height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  autofocus: true,
                  style: TextStyle(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: Icon(UniconsLine.lock, color: c.textHint),
                    filled: true,
                    fillColor: c.surface,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? UniconsLine.eye : UniconsLine.eye_slash,
                        color: c.textHint,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Enter your password' : null,
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                        : Text('Confirm Identity', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed: _busy ? null : _logout,
                  child: Text('Sign out instead',
                      style: TextStyle(color: c.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
