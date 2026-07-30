import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class LoanRescheduleScreen extends StatefulWidget {
  final int    loanId;
  final String loanRef;
  const LoanRescheduleScreen({super.key, required this.loanId, required this.loanRef});

  @override
  State<LoanRescheduleScreen> createState() => _LoanRescheduleScreenState();
}

class _LoanRescheduleScreenState extends State<LoanRescheduleScreen> {
  final _api        = ApiService();
  final _formKey    = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _termCtrl   = TextEditingController();

  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await _api.loanRescheduleRequest(
        widget.loanId,
        reason:        _reasonCtrl.text.trim(),
        requestedTerm: int.parse(_termCtrl.text.trim()),
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: context.colors.card,
          title: const Text('Request Submitted'),
          content: const Text(
            'Your rescheduling request has been submitted. Our loan officer will review and contact you shortly.',
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(child: Column(children: [
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
            Expanded(child: Text('Request Rescheduling', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(UniconsLine.info_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loan: ${widget.loanRef}\n\nA rescheduling request will be reviewed by our loan officer. You will be contacted within 2 business days.',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            Text('Reason for Rescheduling', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Explain your circumstances (e.g. salary delays, medical emergency)…',
                hintStyle: TextStyle(color: c.textHint, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                filled: true, fillColor: c.card,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
            ),
            const SizedBox(height: 20),

            Text('Requested Loan Term (months)', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _termCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 24',
                hintStyle: TextStyle(color: c.textHint, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                filled: true, fillColor: c.card,
                suffixText: 'months',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Term is required';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1 || n > 240) return 'Enter a valid term (1–240)';
                return null;
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldDeep,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Submit Request', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ]),
        ),
        )),
      ])),
    );
  }
}
