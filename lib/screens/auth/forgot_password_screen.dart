import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api           = ApiService();
  final _formKey       = GlobalKey<FormState>();
  final _idCtrl        = TextEditingController();
  final _otpCtrl       = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  int  _step    = 1; // 1 = enter identifier, 2 = OTP + new password
  bool _busy    = false;
  bool _obscure = true;
  String? _identifier;

  @override
  void dispose() {
    _idCtrl.dispose(); _otpCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _api.forgotPassword(_idCtrl.text.trim());
      if (!mounted) return;
      setState(() { _identifier = _idCtrl.text.trim(); _step = 2; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('If an account was found, an OTP has been sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.extractError(e)), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.resetPassword(
        identifier: _identifier!,
        otp:        _otpCtrl.text.trim(),
        password:   _passCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully. Please sign in.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.extractError(e)), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: Text('Forgot Password',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            Icon(UniconsLine.lock_alt, size: 56, color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              _step == 1 ? 'Reset Your Password' : 'Enter OTP & New Password',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1
                  ? 'Enter your phone number, email, or member number. We\'ll send a 6-digit OTP.'
                  : 'Check your phone or email for the OTP and set your new password.',
              style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),

            if (_step == 1) ...[
              TextFormField(
                controller: _idCtrl,
                keyboardType: TextInputType.text,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Phone, email or member number',
                  prefixIcon: Icon(UniconsLine.user, color: c.textHint),
                  filled: true, fillColor: c.surface,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _busy ? null : _requestOtp,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : const Text('Send OTP'),
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: c.textPrimary, fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  labelText: 'OTP Code',
                  counterText: '',
                  filled: true, fillColor: c.surface,
                ),
                validator: (v) => (v == null || v.length != 6) ? 'Enter 6-digit OTP' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'New password',
                  prefixIcon: Icon(UniconsLine.lock, color: c.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? UniconsLine.eye : UniconsLine.eye_slash, color: c.textHint),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true, fillColor: c.surface,
                ),
                validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Confirm new password',
                  prefixIcon: Icon(UniconsLine.lock, color: c.textHint),
                  filled: true, fillColor: c.surface,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : const Text('Reset Password'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: Text('Back', style: TextStyle(color: c.textSecondary)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
