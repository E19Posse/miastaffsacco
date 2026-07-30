import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/money_text.dart';
import '../../widgets/transaction_pin_sheet.dart';
import 'package:unicons/unicons.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Add Cash — multi-step mobile-money cash-in wizard
//  method → amount → select account → review → waiting for confirmation
// ════════════════════════════════════════════════════════════════════════════

final _fmt = NumberFormat('#,##0', 'en_US');

String _providerId(String carrier) =>
    carrier.toUpperCase() == 'MTN' ? 'mtn_momo' : 'airtel_money';

Widget _header(BuildContext context, String caption, String title) {
  final c = context.colors;
  return Padding(
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
      Text(caption, style: TextStyle(
          color: c.textSecondary,
          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
      const SizedBox(height: 2),
      Text(title, style: GoogleFonts.sora(
          fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
    ])),
  ]),
  );
}

// ── Step 1: choose method ───────────────────────────────────────────────────

class AddCashMethodScreen extends StatelessWidget {
  final int    savingsAccountId;
  final String accountLabel;
  const AddCashMethodScreen({super.key, required this.savingsAccountId, required this.accountLabel});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          _header(context, 'DEPOSIT', 'Add cash'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _MethodTile(
                  icon: UniconsLine.mobile_android, accentBg: AppColors.gold, accentFg: AppColors.emeraldDeep,
                  title: 'Mobile Money',
                  subtitle: 'Add cash from your mobile money wallet at a fee',
                  trailing: 'Fees apply', trailingColor: AppColors.danger,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AddCashAmountScreen(savingsAccountId: savingsAccountId, accountLabel: accountLabel))),
                ),
                const SizedBox(height: 10),
                _MethodTile(
                  icon: Icons.account_balance_outlined, accentBg: AppColors.emeraldMid, accentFg: Colors.white,
                  title: 'Bank Transfer',
                  subtitle: 'Deposit at any branch or via bank transfer',
                  trailing: 'Free', trailingColor: AppColors.emeraldMid,
                  onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
                    title: const Text('Bank Transfer'),
                    content: const Text('Visit any SACCO branch or use the bank details on your profile to deposit. Your balance updates once the office confirms receipt.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                  )),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Step 2: amount ──────────────────────────────────────────────────────────

class AddCashAmountScreen extends StatefulWidget {
  final int savingsAccountId;
  final String accountLabel;
  const AddCashAmountScreen({super.key, required this.savingsAccountId, required this.accountLabel});
  @override State<AddCashAmountScreen> createState() => _AddCashAmountScreenState();
}

class _AddCashAmountScreenState extends State<AddCashAmountScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _continue() {
    final amount = double.tryParse(_ctrl.text.replaceAll(',', '').replaceAll('UGX', '').trim());
    if (amount == null || amount < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Minimum is UGX 1,000'), backgroundColor: AppColors.danger));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => SelectMomoAccountScreen(
      savingsAccountId: widget.savingsAccountId, accountLabel: widget.accountLabel, amount: amount)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          _header(context, 'DEPOSIT', 'Add cash'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add cash with mobile money', style: GoogleFonts.sora(
                    color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Crediting: ${widget.accountLabel}', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const SizedBox(height: 28),
                Text('AMOUNT', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: _ctrl, keyboardType: TextInputType.number, autofocus: true,
                  style: GoogleFonts.sora(color: c.textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    prefixText: 'UGX ', prefixStyle: GoogleFonts.sora(color: c.textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
                    hintText: '0', hintStyle: TextStyle(color: c.textHint, fontSize: 28),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold, width: 2)),
                  ),
                ),
                const Spacer(),
                SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
                      shape: const StadiumBorder()),
                  child: Text('Continue', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
                )),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Step 3: select / add mobile-money account ───────────────────────────────

class SelectMomoAccountScreen extends StatefulWidget {
  final int savingsAccountId;
  final String accountLabel;
  final double amount;
  const SelectMomoAccountScreen({super.key, required this.savingsAccountId, required this.accountLabel, required this.amount});
  @override State<SelectMomoAccountScreen> createState() => _SelectMomoAccountScreenState();
}

class _SelectMomoAccountScreenState extends State<SelectMomoAccountScreen> {
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

  Future<void> _addAccount() async {
    final c = context.colors;
    final added = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _AddMomoAccountSheet(),
    );
    if (added == true) _load();
  }

  void _pick(Map<String, dynamic> acct) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DepositReviewScreen(
      savingsAccountId: widget.savingsAccountId, amount: widget.amount,
      account: acct,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          _header(context, 'DEPOSIT', 'Select mobile money'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
                    _AccountRow(
                      icon: UniconsLine.plus, accentBg: AppColors.emeraldMid, accentFg: Colors.white,
                      title: 'Add a mobile money account',
                      onTap: _addAccount,
                    ),
                    ..._accounts.map((a) {
                      final acct = (a as Map).cast<String, dynamic>();
                      return _AccountRow(
                        icon: UniconsLine.mobile_android, accentBg: AppColors.gold, accentFg: Colors.white,
                        title: acct['name'] ?? '—',
                        subtitle: '${acct['phone'] ?? ''}  ·  ${acct['carrier'] ?? ''}',
                        onTap: () => _pick(acct),
                      );
                    }),
                    if (_accounts.isEmpty) Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text('No saved accounts yet. Add one above to continue.',
                          textAlign: TextAlign.center, style: TextStyle(color: c.textHint, fontSize: 13)),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ── Step 4: review ──────────────────────────────────────────────────────────

class DepositReviewScreen extends StatefulWidget {
  final int savingsAccountId;
  final double amount;
  final Map<String, dynamic> account;
  const DepositReviewScreen({super.key, required this.savingsAccountId, required this.amount, required this.account});
  @override State<DepositReviewScreen> createState() => _DepositReviewScreenState();
}

class _DepositReviewScreenState extends State<DepositReviewScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _quote;
  bool _loading = true, _busy = false;

  String get _carrier => (widget.account['carrier'] ?? '').toString();
  String get _provider => _providerId(_carrier);

  @override
  void initState() { super.initState(); _loadQuote(); }

  Future<void> _loadQuote() async {
    try {
      _quote = await _api.getPaymentQuote(provider: _provider, amount: widget.amount);
    } catch (_) {
      _quote = {'amount': widget.amount, 'fee': 0, 'you_receive': widget.amount, 'total_charge': widget.amount};
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirm() async {
    // Transaction-PIN gate (server-driven via member.require_txn_pin).
    String pin = '';
    final authProvider = context.read<AuthProvider>();
    var member = authProvider.member;
    if (member != null && member.requireTxnPin && !member.hasTxnPin) {
      // The cached member snapshot can be stale (e.g. the PIN was set in an
      // earlier session) — re-check with the server before blocking the user.
      await authProvider.refreshMember();
      member = authProvider.member;
    }
    if (member != null && member.requireTxnPin) {
      if (!member.hasTxnPin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Set a Transaction PIN in Settings before making payments.')));
        return;
      }
      final entered = await showTransactionPinSheet(context, _api);
      if (entered == null) return; // cancelled
      pin = entered;
    }

    setState(() => _busy = true);
    try {
      final res = await _api.initiateGatewayPayment(
        purpose: 'savings_deposit', provider: _provider, amount: widget.amount,
        phone: (widget.account['phone'] ?? widget.account['msisdn'])?.toString(),
        savingsAccountId: widget.savingsAccountId,
        pin: pin,
      );
      if (!mounted) return;
      final status = (res['status'] ?? '').toString();
      if (status == 'failed') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message']?.toString() ?? 'Payment failed'), backgroundColor: AppColors.danger));
        setState(() => _busy = false);
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => WaitingConfirmationScreen(
        reference: res['reference'].toString())));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _quote ?? {};
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          _header(context, 'DEPOSIT', 'Review details'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Deposit  ', style: GoogleFonts.sora(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                        MoneyText(amount: widget.amount.round(), currency: 'UGX', size: 26, color: c.textPrimary),
                      ]),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(children: [
                          _row(context, 'Payment Method', 'Mobile Money'),
                          _row(context, 'Phone Number', (widget.account['phone'] ?? '').toString()),
                          _row(context, 'Carrier', _carrier),
                          _row(context, 'Amount', 'UGX ${_fmt.format(q['amount'] ?? widget.amount)}'),
                          _row(context, 'Fee', 'UGX ${_fmt.format(q['fee'] ?? 0)}'),
                          Divider(height: 24, color: c.border),
                          _row(context, 'You Receive', 'UGX ${_fmt.format(q['you_receive'] ?? widget.amount)}', accent: true),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text((q['note'] ?? 'Your provider may add its own charge.').toString(),
                          style: TextStyle(color: c.textHint, fontSize: 11)),
                      const Spacer(),
                      SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
                        onPressed: _busy ? null : _confirm,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
                            shape: const StadiumBorder()),
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text('Confirm', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
                      )),
                      const SizedBox(height: 8),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v, {bool accent = false}) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: TextStyle(color: accent ? AppColors.emeraldMid : c.textSecondary, fontSize: 13, fontWeight: accent ? FontWeight.w700 : FontWeight.w500)),
        Text(v, style: TextStyle(color: accent ? AppColors.emeraldMid : c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Step 5: waiting for confirmation ────────────────────────────────────────

class WaitingConfirmationScreen extends StatefulWidget {
  final String reference;
  const WaitingConfirmationScreen({super.key, required this.reference});
  @override State<WaitingConfirmationScreen> createState() => _WaitingConfirmationScreenState();
}

class _WaitingConfirmationScreenState extends State<WaitingConfirmationScreen> {
  final _api = ApiService();
  Timer? _timer;
  String _status = 'processing';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _poll() async {
    try {
      final s = await _api.checkPaymentStatus(widget.reference);
      if (!mounted) return;
      final st = (s['status'] ?? '').toString();
      if (st == 'completed' || st == 'failed' || st == 'reversed') {
        _timer?.cancel();
        setState(() => _status = st);
        if (st == 'completed') context.read<DashboardProvider>().refresh();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = _status == 'completed';
    final failed = _status == 'failed' || _status == 'reversed';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            Icon(
              done ? UniconsLine.check_circle : failed ? UniconsLine.times_circle : UniconsLine.mobile_android,
              size: 72, color: done ? AppColors.emeraldMid : failed ? AppColors.danger : AppColors.gold,
            ),
            const SizedBox(height: 24),
            Text(
              done ? 'Deposit successful' : failed ? 'Payment failed'
                   : 'We are waiting for a confirmation\nfrom your mobile money provider',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3),
            ),
            const SizedBox(height: 16),
            if (!done && !failed)
              Text('You will receive a USSD pop-up on your phone to enter your mobile money PIN and approve this transaction.',
                  textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5)),
            if (!done && !failed) ...[
              const SizedBox(height: 28),
              const CircularProgressIndicator(color: AppColors.gold),
            ],
            const Spacer(),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: done ? AppColors.emeraldMid : AppColors.emeraldDeep, foregroundColor: Colors.white,
                shape: const StadiumBorder()),
              child: Text(done ? 'Done' : failed ? 'Close' : 'Done',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _MethodTile extends StatelessWidget {
  final IconData icon; final Color accentBg, accentFg;
  final String title, subtitle, trailing; final Color trailingColor;
  final VoidCallback onTap;
  const _MethodTile({required this.icon, required this.accentBg, required this.accentFg, required this.title,
      required this.subtitle, required this.trailing, required this.trailingColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: accentFg, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3)),
          ])),
          const SizedBox(width: 8),
          Text(trailing, style: TextStyle(color: trailingColor, fontSize: 11, fontWeight: FontWeight.w700)),
          Icon(UniconsLine.angle_right, color: c.textHint, size: 20),
        ]),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon; final Color accentBg, accentFg;
  final String title; final String? subtitle; final VoidCallback onTap;
  const _AccountRow({required this.icon, required this.accentBg, required this.accentFg, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
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
          Container(width: 44, height: 44, decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
              child: Icon(icon, color: accentFg, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ],
          ])),
          Icon(UniconsLine.angle_right, color: c.textHint, size: 20),
        ]),
      ),
    );
  }
}

class _AddMomoAccountSheet extends StatefulWidget {
  const _AddMomoAccountSheet();
  @override State<_AddMomoAccountSheet> createState() => _AddMomoAccountSheetState();
}

class _AddMomoAccountSheetState extends State<_AddMomoAccountSheet> {
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

  InputDecoration _pillInput(BuildContext context, String label) {
    final c = context.colors;
    return InputDecoration(
        labelText: label,
        filled: true, fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.border)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: AppColors.gold, width: 1.5)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Add mobile money account', style: GoogleFonts.sora(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: _name, style: TextStyle(color: c.textPrimary),
            decoration: _pillInput(context, 'Account name')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, style: TextStyle(color: c.textPrimary),
            decoration: _pillInput(context, 'Phone (e.g. 0772123456)')),
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
