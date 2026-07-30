import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../payments/payment_gateway_screen.dart';
import 'package:unicons/unicons.dart';

class SettlementCalculatorScreen extends StatefulWidget {
  final int    loanId;
  final String loanNumber;
  const SettlementCalculatorScreen({
    super.key,
    required this.loanId,
    required this.loanNumber,
  });
  @override
  State<SettlementCalculatorScreen> createState() => _SettlementCalculatorScreenState();
}

class _SettlementCalculatorScreenState extends State<SettlementCalculatorScreen> {
  final _api    = ApiService();
  final _fmt    = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy');

  Map<String, dynamic>? _quote;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = await _api.getLoanSettlementQuote(widget.loanId);
      if (mounted) setState(() { _quote = q; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
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
              Expanded(child: Text('Early Settlement', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
              IconButton(
                icon: Icon(UniconsLine.sync, color: c.textPrimary),
                tooltip: 'Refresh quote',
                onPressed: _load,
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _buildBody(c),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody(AppColorScheme c) {
    final q = _quote!;
    final outstanding = (q['outstanding_balance'] as num?)?.toDouble() ?? 0;
    final interest    = (q['accrued_interest'] as num?)?.toDouble() ?? 0;
    final settlement  = (q['settlement_amount'] as num?)?.toDouble() ?? 0;
    final installment = (q['monthly_installment'] as num?)?.toDouble() ?? 0;
    final validUntil  = q['valid_until'] as String?;
    final parsedDate  = validUntil != null ? DateTime.tryParse(validUntil) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Loan number header
        Text('${widget.loanNumber}',
            style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        // Main quote card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: .5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _QuoteRow(
              label: 'Outstanding Balance',
              value: 'UGX ${_fmt.format(outstanding)}',
              valueColor: AppColors.gold,
            ),
            const SizedBox(height: 16),
            _QuoteRow(
              label: 'Accrued Interest',
              value: 'UGX ${_fmt.format(interest)}',
              valueColor: AppColors.gold,
            ),
            const SizedBox(height: 16),
            Divider(color: c.border),
            const SizedBox(height: 16),
            Text('Settlement Amount',
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Text('UGX ${_fmt.format(settlement)}',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 32, fontWeight: FontWeight.w900)),
            if (parsedDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.emeraldDeep,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Quote valid until: ${_dateFmt.format(parsedDate)}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 16),

        // Monthly installment info
        if (installment > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border, width: .5),
            ),
            child: Row(children: [
              const Icon(UniconsLine.calendar_alt, color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Monthly Installment',
                    style: TextStyle(color: c.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text('UGX ${_fmt.format(installment)}',
                    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),

        const SizedBox(height: 20),

        // ── Settle now via MoMo ───────────────────────────────────────────
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton.icon(
            onPressed: settlement <= 0 ? null : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PaymentGatewayScreen(
                initialPurpose: 'loan_repayment',
                initialAccountId: widget.loanId,
                fixedAmount: settlement,
                lockPurpose: true,
              )),
            ),
            icon: const Icon(UniconsLine.mobile_android, size: 20),
            label: Text('Settle in full via MoMo', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white, shape: const StadiumBorder()),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton.icon(
            onPressed: _requestTopUp,
            icon: const Icon(UniconsLine.plus_circle, size: 18),
            label: const Text('Request a top-up', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold, side: const BorderSide(color: AppColors.gold), shape: const StadiumBorder()),
          ),
        ),
        const SizedBox(height: 16),
        Text('Paying the settlement amount via MoMo clears the loan once the prompt is approved. '
            'A top-up lets you borrow more on this loan, subject to staff review.',
            style: TextStyle(color: c.textHint, fontSize: 11, height: 1.5)),
      ]),
    );
  }

  Future<void> _requestTopUp() async {
    final amtCtrl    = TextEditingController();
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.card,
          title: const Text('Request a Top-up'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amtCtrl, keyboardType: TextInputType.number,
                style: TextStyle(color: c.textPrimary),
                decoration: const InputDecoration(prefixText: 'UGX ', hintText: 'Additional amount')),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, maxLines: 2,
                style: TextStyle(color: c.textPrimary),
                decoration: const InputDecoration(hintText: 'Reason for the top-up')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        );
      },
    );
    if (ok != true) return;
    final amt = double.tryParse(amtCtrl.text.replaceAll(',', '').trim());
    if (amt == null || amt < 50000 || reasonCtrl.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter an amount (min 50,000) and a reason'), backgroundColor: AppColors.danger));
      return;
    }
    try {
      final res = await _api.loanTopUpRequest(widget.loanId, additionalAmount: amt, reason: reasonCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Top-up requested'), backgroundColor: AppColors.emeraldMid));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger));
    }
  }
}

class _QuoteRow extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _QuoteRow({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13)),
      Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(UniconsLine.info_circle, size: 48, color: AppColors.danger),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: AppColors.emeraldDeep)),
        ),
      ]),
    ),
  );
}
