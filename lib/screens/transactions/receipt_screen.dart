import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class ReceiptScreen extends StatefulWidget {
  final int transactionId;
  const ReceiptScreen({super.key, required this.transactionId});
  @override State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  Map<String, dynamic>? _receipt;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getTransactionReceipt(widget.transactionId);
      if (mounted) setState(() { _receipt = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  void _share() {
    if (_receipt == null) return;
    final r    = _receipt!;
    final type = r['type'] as String? ?? '';
    final amt  = (r['amount'] as num?)?.toDouble() ?? 0;
    final date = r['date'] as String? ?? '—';
    final ref  = r['reference'] as String? ?? '—';
    final acct = r['account_number'] as String? ?? '—';

    final text = '''
BMC SACCO — Transaction Receipt
================================
Type:      $type
Account:   $acct
Amount:    UGX ${_fmt.format(amt)}
Date:      $date
Reference: $ref
================================
This receipt is computer-generated.
''';
    Share.share(text, subject: 'BMC SACCO Receipt — $ref');
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
              Expanded(child: Text('Receipt', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
              if (_receipt != null)
                IconButton(
                  icon: const Icon(UniconsLine.share_alt),
                  color: AppColors.emeraldDeep,
                  onPressed: _share,
                ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: c.textSecondary)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: Column(children: [
                          _ReceiptCard(receipt: _receipt!, fmt: _fmt),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: OutlinedButton.icon(
                              icon: const Icon(UniconsLine.share_alt),
                              label: Text('Share Receipt', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.emeraldDeep,
                                side: const BorderSide(color: AppColors.emeraldDeep),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _share,
                            ),
                          ),
                        ]),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final NumberFormat fmt;
  const _ReceiptCard({required this.receipt, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final type   = receipt['type'] as String? ?? '';
    final cat    = receipt['category'] as String? ?? '';
    final amt    = (receipt['amount'] as num?)?.toDouble() ?? 0;
    final after  = (receipt['balance_after'] as num?)?.toDouble() ?? 0;
    final acct   = receipt['account_number'] as String? ?? '—';
    final acctT  = receipt['account_type'] as String? ?? '';
    final ref    = receipt['reference'] as String? ?? '—';
    final mode   = receipt['payment_mode'] as String? ?? '—';
    final date   = receipt['date'] as String? ?? '—';
    final notes  = receipt['notes'] as String?;
    final isDebit= type == 'Withdrawal' || type == 'Repayment';

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.emeraldDeep,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Icon(
              cat == 'Loan' ? UniconsLine.wallet : UniconsLine.money_bill,
              size: 40, color: AppColors.gold,
            ),
            const SizedBox(height: 12),
            Text(type, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              '${isDebit ? '-' : '+'}UGX ${fmt.format(amt)}',
              style: GoogleFonts.sora(
                color: Colors.white,
                fontSize: 36, fontWeight: FontWeight.w800,
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _Row(c, 'Account',      acct),
            _Row(c, 'Account Type', acctT),
            _Row(c, 'Reference',    ref),
            _Row(c, 'Payment Mode', mode),
            _Row(c, 'Date',         date),
            _Row(c, 'Balance After','UGX ${fmt.format(after)}'),
            if (notes != null && notes.isNotEmpty) _Row(c, 'Notes', notes),
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final dynamic c;
  final String label, value;
  const _Row(this.c, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: c.textHint, fontSize: 13)),
      const SizedBox(width: 12),
      Flexible(
        child: Text(value,
          textAlign: TextAlign.end,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    ]),
  );
}
