import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/money_text.dart';
import 'package:unicons/unicons.dart';
import '../payments/payment_gateway_screen.dart';

class SubscriptionFeeScreen extends StatefulWidget {
  const SubscriptionFeeScreen({super.key});

  @override
  State<SubscriptionFeeScreen> createState() => _SubscriptionFeeScreenState();
}

class _SubscriptionFeeScreenState extends State<SubscriptionFeeScreen> {
  final _api      = ApiService();
  bool  _loading  = true;
  bool  _paying   = false;
  String? _error;

  Map<String, dynamic>? _status;

  final _refCtrl  = TextEditingController();
  String _mode    = 'MoMo';

  final _modes = ['MoMo', 'Airtel', 'Card', 'Bank', 'Cash'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getSubscriptionFeeStatus();
      setState(() { _status = data; });
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay() async {
    final ref = _refCtrl.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the payment reference.')));
      return;
    }
    setState(() { _paying = true; _error = null; });
    try {
      await _api.paySubscriptionFee(reference: ref, mode: _mode);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription fee recorded! You now have full access.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); });
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _payOnline() async {
    final amt = _status?['amount'];
    final amount = (amt is num) ? amt.toDouble() : double.tryParse('$amt');
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaymentGatewayScreen(
        initialPurpose: 'subscription_fee',
        fixedAmount: amount,
        lockPurpose: true,
      ),
    ));
    if (mounted) _load(); // refresh paid status on return
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
              Expanded(child: Text('Subscription Fee', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : _error != null && _status == null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(UniconsLine.exclamation_circle, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: c.textSecondary)),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: AppColors.emeraldDeep))),
                      ]))
                    : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Status Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: (_status?['paid'] == true) ? AppColors.emeraldMid : AppColors.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(children: [
                        const Icon(UniconsLine.check_circle, size: 48, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          (_status?['paid'] == true) ? 'Subscription Fee Paid' : 'Subscription Fee Pending',
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MoneyText(
                          amount: num.tryParse('${_status?['amount'] ?? 0}')?.round() ?? 0,
                          currency: 'UGX', size: 30, color: Colors.white, fit: true,
                        ),
                        const SizedBox(height: 4),
                        const Text('One-time membership subscription fee',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        if (_status?['paid'] == true) ...[
                          const SizedBox(height: 12),
                          Text('Paid via ${_status?['mode'] ?? '—'} · Ref: ${_status?['reference'] ?? '—'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ]),
                    ),

                    if (_status?['paid'] != true) ...[
                      const SizedBox(height: 24),

                      // Pay online (mobile money) — instant, auto-recorded on success
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _payOnline,
                          icon: const Icon(UniconsLine.mobile_android, size: 18, color: Colors.white),
                          label: Text('Pay Online (Mobile Money)',
                              style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldDeep,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(child: Text('Approve the prompt on your phone — access unlocks automatically.',
                          style: TextStyle(color: c.textHint, fontSize: 11))),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Row(children: [
                          Expanded(child: Divider()),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR RECORD MANUALLY', style: TextStyle(fontSize: 11, color: Colors.grey))),
                          Expanded(child: Divider()),
                        ]),
                      ),

                      Text('Record Payment', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Pay the fee via mobile money or bank, then enter the reference below.',
                          style: TextStyle(color: c.textSecondary, fontSize: 12)),
                      const SizedBox(height: 20),

                      Text('Payment Method', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: _modes.map((m) => ChoiceChip(
                        label: Text(m),
                        selected: _mode == m,
                        onSelected: (_) => setState(() => _mode = m),
                        selectedColor: AppColors.emeraldDeep,
                        labelStyle: TextStyle(
                          color: _mode == m ? Colors.white : c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      )).toList()),
                      const SizedBox(height: 20),

                      Text('Payment Reference / Transaction ID', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _refCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. MM240523123456',
                          hintStyle: TextStyle(color: c.textHint, fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                          filled: true, fillColor: c.card,
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                          child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],

                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _paying ? null : _pay,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldDeep,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: _paying
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Confirm Payment', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                    ],
                  ]),
                ),
          ),
        ]),
      ),
    );
  }
}
