import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unicons/unicons.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet that asks for the member's transaction PIN and verifies it
/// server-side before a payment proceeds. Returns the verified PIN string, or
/// null if the member cancels. Solid colors only (no alpha fills).
Future<String?> showTransactionPinSheet(
  BuildContext context,
  ApiService api, {
  String message = 'Enter your transaction PIN to authorise this payment.',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransactionPinSheet(api: api, message: message),
  );
}

class _TransactionPinSheet extends StatefulWidget {
  final ApiService api;
  final String message;
  const _TransactionPinSheet({required this.api, required this.message});

  @override
  State<_TransactionPinSheet> createState() => _TransactionPinSheetState();
}

class _TransactionPinSheetState extends State<_TransactionPinSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _ctrl.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Enter your 4–6 digit PIN.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.verifyTransactionPin(pin);
      if (mounted) Navigator.of(context).pop(pin);
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(UniconsLine.lock_alt, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('Transaction PIN',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.message,
                style: TextStyle(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 18),
            TextField(
              controller: _ctrl,
              autofocus: true,
              obscureText: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: 22, letterSpacing: 8, color: c.textPrimary),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                errorText: _error,
                prefixIcon: const Icon(UniconsLine.keyhole_circle),
                filled: true,
                fillColor: c.cardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: c.border),
                ),
              ),
              onSubmitted: (_) => _busy ? null : _verify(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _verify,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
                child: _busy
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify & Continue',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
