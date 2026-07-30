import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Your payment methods — manage saved MTN / Airtel mobile-money accounts.
//  Mirrors the Chipper "Your payment methods" screen: list, add, delete.
// ════════════════════════════════════════════════════════════════════════════

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});
  @override State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _api = ApiService();
  List<dynamic> _accounts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _accounts = await _api.getMomoAccounts(); } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final c = context.colors;
    final added = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _AddPaymentMethodSheet(),
    );
    if (added == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> acct) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text('Remove ${acct['phone'] ?? ''} (${acct['carrier'] ?? ''}) from your payment methods?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteMomoAccount(acct['id'] as int);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger));
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WALLET', style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text('Payment methods', style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ])),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : RefreshIndicator(
                    color: AppColors.emeraldDeep,
                    onRefresh: _load,
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
                      InkWell(
                        onTap: _add,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(children: [
                            Container(width: 44, height: 44,
                                decoration: const BoxDecoration(color: AppColors.emeraldMid, shape: BoxShape.circle),
                                child: const Icon(UniconsLine.plus, color: Colors.white, size: 22)),
                            const SizedBox(width: 14),
                            Expanded(child: Text('Add new payment method',
                                style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
                            Icon(UniconsLine.angle_right, color: c.textHint, size: 20),
                          ]),
                        ),
                      ),
                      ..._accounts.map((a) {
                        final acct = (a as Map).cast<String, dynamic>();
                        final carrier = (acct['carrier'] ?? '').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(children: [
                            Container(width: 44, height: 44,
                                decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                                child: const Icon(UniconsLine.mobile_android, color: Colors.white, size: 22)),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Flexible(child: Text(acct['name'] ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
                                if (acct['is_default'] == true) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppColors.emeraldDeep, borderRadius: BorderRadius.circular(999)),
                                    child: const Text('Default',
                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 2),
                              Text('${acct['phone'] ?? ''}  ·  $carrier',
                                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
                            ])),
                            IconButton(
                              icon: const Icon(UniconsLine.trash_alt, color: AppColors.danger, size: 20),
                              onPressed: () => _delete(acct),
                            ),
                          ]),
                        );
                      }),
                      if (_accounts.isEmpty) Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Text('No saved payment methods yet.\nAdd an MTN or Airtel account above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.textHint, fontSize: 13, height: 1.5)),
                      ),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── Add a payment method (provider picker → number) ─────────────────────────

class _AddPaymentMethodSheet extends StatefulWidget {
  const _AddPaymentMethodSheet();
  @override State<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<_AddPaymentMethodSheet> {
  final _api = ApiService();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() { _name.dispose(); _phone.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter name and phone'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.addMomoAccount(name: _name.text.trim(), phone: _phone.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger));
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _pillInput(BuildContext context, String label, String hint) {
    final c = context.colors;
    return InputDecoration(
        labelText: label, hintText: hint,
        filled: true, fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Add a mobile money account', style: GoogleFonts.sora(
            color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: _name, style: TextStyle(color: c.textPrimary),
            decoration: _pillInput(context, 'Account name', '')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, style: TextStyle(color: c.textPrimary),
            decoration: _pillInput(context, 'Phone', 'e.g. 0772123456')),
        const SizedBox(height: 8),
        Text('MTN and Airtel Uganda numbers only. The network is detected automatically.',
            style: TextStyle(color: c.textSecondary, fontSize: 11)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
          onPressed: _busy ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
              shape: const StadiumBorder()),
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text('Save account', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
        )),
      ]),
    );
  }
}
