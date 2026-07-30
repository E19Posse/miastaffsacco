import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class TransactionPinScreen extends StatefulWidget {
  final bool hasExistingPin;
  const TransactionPinScreen({super.key, required this.hasExistingPin});
  @override State<TransactionPinScreen> createState() => _TransactionPinScreenState();
}

class _TransactionPinScreenState extends State<TransactionPinScreen> {
  final _api       = ApiService();
  final _formKey   = GlobalKey<FormState>();
  final _pinCtrl   = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  bool _busy       = false;

  @override
  void dispose() {
    _pinCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _api.setTransactionPin(
        pin: _pinCtrl.text,
        currentPassword: widget.hasExistingPin ? _passCtrl.text : null,
      );
      if (!mounted) return;
      await context.read<AuthProvider>().refreshMember();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction PIN set successfully.'),
          backgroundColor: AppColors.emeraldMid,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger),
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
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c.card, shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(UniconsLine.angle_left, color: c.textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.hasExistingPin ? 'Change Transaction PIN' : 'Set Transaction PIN',
                  style: GoogleFonts.sora(
                      fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
                ),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 16),
                  Icon(Icons.password_outlined, size: 56, color: AppColors.emeraldDeep),
                  const SizedBox(height: 20),
                  Text(
                    widget.hasExistingPin ? 'Change Your Transaction PIN' : 'Create a Transaction PIN',
                    style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your 6-digit transaction PIN protects financial operations in the app.',
                    style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 32),

            if (widget.hasExistingPin) ...[
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(UniconsLine.lock, color: c.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? UniconsLine.eye : UniconsLine.eye_slash, color: c.textHint),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true, fillColor: c.surface,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: c.textPrimary, fontSize: 24, letterSpacing: 10),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'New 6-Digit PIN',
                counterText: '',
                hintText: '• • • • • •',
                filled: true, fillColor: c.surface,
              ),
              validator: (v) => (v == null || v.length != 6) ? 'PIN must be exactly 6 digits' : null,
            ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: _busy
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              widget.hasExistingPin ? 'Update PIN' : 'Set PIN',
                              style: GoogleFonts.sora(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
