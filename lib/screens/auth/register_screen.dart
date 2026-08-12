import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/recaptcha_service.dart';
import '../../theme/app_theme.dart';
import '../legal/legal_content_screen.dart';
import 'package:unicons/unicons.dart';

/// Member self-registration. Two steps:
///   1. profile (name, email, phone, national ID, password) → sends dual OTP
///   2. email + phone OTP → creates the account (pending approval) and signs in
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api      = ApiService();
  final _formKey  = GlobalKey<FormState>();

  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _staffCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _emailOtpCtrl = TextEditingController();
  final _phoneOtpCtrl = TextEditingController();

  List<Map<String, dynamic>> _employers  = [];
  List<Map<String, dynamic>> _categories = [];
  String? _employerCode;
  int?    _categoryId;
  bool    _loadingOptions = true;

  int  _step          = 1;
  bool _busy          = false;
  bool _obscure       = true;
  bool _phoneRequired = false;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final data = await _api.getRegisterOptions();
      if (!mounted) return;
      setState(() {
        _employers  = (data['employers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _categories = (data['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loadingOptions = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _staffCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    _referralCtrl.dispose();
    _emailOtpCtrl.dispose(); _phoneOtpCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ));

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      _snack('Passwords do not match.');
      return;
    }
    if (_employerCode == null) { _snack('Please select your employer.'); return; }
    if (_categoryId == null)   { _snack('Please select a member category.'); return; }
    if (!_acceptedTerms) {
      _snack('You must accept the Terms & Conditions and Privacy Policy to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      // No-op (returns null) until RECAPTCHA_SITE_KEY is configured at build time —
      // see RecaptchaService for the full activation steps.
      final recaptchaToken = await RecaptchaService.getToken(context, action: 'register');
      if (!mounted) return;
      final res = await _api.registerStart(
        name:             _nameCtrl.text.trim(),
        email:            _emailCtrl.text.trim(),
        phone:            _phoneCtrl.text.trim(),
        staffNumber:      _staffCtrl.text.trim(),
        employerCode:     _employerCode!,
        memberCategoryId: _categoryId!,
        password:         _passCtrl.text,
        referralCode:     _referralCtrl.text.trim(),
        recaptchaToken:   recaptchaToken,
      );
      if (!mounted) return;
      setState(() {
        _phoneRequired = res['phone_otp_required'] == true;
        _step = 2;
      });
      _snack(_phoneRequired
          ? 'Verification codes sent to your email and phone.'
          : 'A verification code has been sent to your email.', error: false);
    } catch (e) {
      if (mounted) _snack(ApiService.extractError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final res = await _api.registerComplete(
        name:             _nameCtrl.text.trim(),
        email:            _emailCtrl.text.trim(),
        phone:            _phoneCtrl.text.trim(),
        staffNumber:      _staffCtrl.text.trim(),
        employerCode:     _employerCode!,
        memberCategoryId: _categoryId!,
        password:         _passCtrl.text,
        emailOtp:         _emailOtpCtrl.text.trim(),
        phoneOtp:         _phoneRequired ? _phoneOtpCtrl.text.trim() : '',
        referralCode:     _referralCtrl.text.trim(),
      );
      if (!mounted) return;
      // No auto-login: the member cannot sign in until staff approve the
      // membership. Show the pending notice and return to the login screen.
      final msg = (res['message'] as String?) ??
          'Registration complete! Your membership is pending approval by the SACCO. '
              'You will be notified once it is approved, after which you can sign in.';
      await showDialog<void>(
        context: context,
        barrierDismissible: false, // force an explicit acknowledgement before returning to login
        builder: (ctx) => AlertDialog(
          title: const Text('Pending Approval'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (mounted) _snack(ApiService.extractError(e));
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
        title: Text(_step == 1 ? 'Create Account' : 'Verify Your Details',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: c.textPrimary),
        leading: IconButton(
          icon: const Icon(UniconsLine.arrow_left),
          onPressed: () {
            if (_step == 2) {
              setState(() => _step = 1);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: _step == 1 ? _buildProfile(c) : _buildVerify(c),
        ),
      ),
    );
  }

  Widget _buildProfile(AppColorScheme c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Icon(UniconsLine.user_plus, size: 52, color: AppColors.primary),
      const SizedBox(height: 16),
      Text('Join TMI Staff SACCO',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
      const SizedBox(height: 8),
      Text('Create your member account. We\'ll verify your email and phone.',
          style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5)),
      const SizedBox(height: 28),

      _field(c, _nameCtrl, 'Full name', UniconsLine.user,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
      const SizedBox(height: 16),
      _field(c, _emailCtrl, 'Email address', UniconsLine.envelope,
          keyboard: TextInputType.emailAddress,
          validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
      Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          'Use an active email you check regularly and have access to — '
          'we\'ll send your verification code and account notices here.',
          style: TextStyle(color: c.textHint, fontSize: 11.5, height: 1.4),
        ),
      ),
      const SizedBox(height: 16),
      _field(c, _phoneCtrl, 'Phone number', UniconsLine.phone,
          keyboard: TextInputType.phone,
          validator: (v) => (v == null || v.trim().length < 9) ? 'Enter a valid phone' : null),
      const SizedBox(height: 16),
      _field(c, _staffCtrl, 'Staff ID / Number', UniconsLine.postcard,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
      const SizedBox(height: 16),
      _dropdown(c, UniconsLine.building,
          value: _employerCode,
          hint: _loadingOptions ? 'Loading…' : 'Select your employer',
          items: _employers.map((e) => DropdownMenuItem<Object>(
              value: e['code'] as String, child: Text(e['name'] as String))).toList(),
          onChanged: (v) => setState(() => _employerCode = v as String?)),
      const SizedBox(height: 16),
      _dropdown(c, UniconsLine.users_alt,
          value: _categoryId,
          hint: _loadingOptions ? 'Loading…' : 'Select a category',
          items: _categories.map((e) => DropdownMenuItem<Object>(
              value: e['id'] as int, child: Text(e['name'] as String))).toList(),
          onChanged: (v) => setState(() => _categoryId = v as int?)),
      const SizedBox(height: 16),
      _field(c, _passCtrl, 'Password', UniconsLine.lock,
          obscure: _obscure,
          suffix: IconButton(
            icon: Icon(_obscure ? UniconsLine.eye : UniconsLine.eye_slash, color: c.textHint),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null),
      const SizedBox(height: 16),
      _field(c, _confirmCtrl, 'Confirm password', UniconsLine.lock,
          obscure: _obscure,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
      const SizedBox(height: 16),
      _field(c, _referralCtrl, 'Referral code (optional)', UniconsLine.share_alt,
          keyboard: TextInputType.text),
      Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          'Were you referred by a member? Enter their member number.',
          style: TextStyle(color: c.textHint, fontSize: 11.5, height: 1.4),
        ),
      ),
      const SizedBox(height: 20),

      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('I accept the ', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: () => _pushLegal('terms'),
                child: Text('Terms & Conditions',
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Text(' and ', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: () => _pushLegal('privacy'),
                child: Text('Privacy Policy',
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 20),

      SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: _busy ? null : _start,
          child: _busy
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
              : const Text('Send Verification Codes'),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Already have an account? Sign in',
              style: TextStyle(color: c.textSecondary)),
        ),
      ),
    ],
  );

  void _pushLegal(String type) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => LegalContentScreen(type: type)));
  }

  Widget _buildVerify(AppColorScheme c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Icon(UniconsLine.shield_check, size: 52, color: AppColors.primary),
      const SizedBox(height: 16),
      Text('Enter your code${_phoneRequired ? 's' : ''}',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
      const SizedBox(height: 8),
      Text(_phoneRequired
              ? 'We sent a 6-digit code to ${_emailCtrl.text.trim()} and your phone.'
              : 'We sent a 6-digit code to ${_emailCtrl.text.trim()}.',
          style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5)),
      const SizedBox(height: 28),

      _otpField(c, _emailOtpCtrl, 'Email code'),
      if (_phoneRequired) ...[
        const SizedBox(height: 16),
        _otpField(c, _phoneOtpCtrl, 'Phone code'),
      ],
      const SizedBox(height: 28),

      SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: _busy ? null : _complete,
          child: _busy
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
              : const Text('Create Account'),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: _busy ? null : _start,
          child: Text('Resend codes', style: TextStyle(color: AppColors.primary)),
        ),
      ),
    ],
  );

  Widget _field(AppColorScheme c, TextEditingController ctrl, String hint, IconData icon,
      {TextInputType? keyboard, bool obscure = false, Widget? suffix,
       String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: c.textHint),
        suffixIcon: suffix,
        filled: true, fillColor: c.surface,
      ),
      validator: validator,
    );
  }

  Widget _dropdown(AppColorScheme c, IconData icon,
      {required Object? value, required String hint,
       required List<DropdownMenuItem<Object>> items,
       required ValueChanged<Object?> onChanged}) {
    return DropdownButtonFormField<Object>(
      initialValue: value,
      isExpanded: true,
      icon: Icon(UniconsLine.angle_down, color: c.textHint),
      dropdownColor: c.surface,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      hint: Text(hint, style: TextStyle(color: c.textHint)),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: c.textHint),
        filled: true, fillColor: c.surface,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _otpField(AppColorScheme c, TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      maxLength: 6,
      style: TextStyle(color: c.textPrimary, fontSize: 22, letterSpacing: 8),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: '• • • • • •',
        labelText: label,
        counterText: '',
        filled: true, fillColor: c.surface,
      ),
      validator: (v) => (v == null || v.length != 6) ? 'Enter 6-digit code' : null,
    );
  }
}
