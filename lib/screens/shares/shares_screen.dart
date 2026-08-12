import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/share_transaction.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/money_text.dart';
import 'package:unicons/unicons.dart';
import '../payments/payment_gateway_screen.dart';

class SharesScreen extends StatefulWidget {
  const SharesScreen({super.key});
  @override State<SharesScreen> createState() => _SharesScreenState();
}

class _SharesScreenState extends State<SharesScreen> {
  final _api     = ApiService();
  final _fmt     = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy');

  ShareSummary?              _summary;
  List<SharePurchaseRequest> _requests = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getShares(),
        _api.getSharePurchaseRequests(),
      ]);
      setState(() {
        _summary  = ShareSummary.fromJson(results[0] as Map<String, dynamic>);
        _requests = (results[1] as List<dynamic>)
            .map((j) => SharePurchaseRequest.fromJson(j as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showBuySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _BuySharesSheet(
        unitPrice: _summary?.unitValue ?? 1000,
        onSuccess: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBuySheet,
        backgroundColor: AppColors.emeraldDeep,
        foregroundColor: Colors.white,
        icon: const Icon(UniconsLine.plus),
        label: Text('Buy Shares', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
      ),
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
                child: Text('My Shares',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
              IconButton(
                icon: const Icon(UniconsLine.sync, color: AppColors.emeraldDeep),
                onPressed: _loading ? null : _load,
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.emeraldDeep,
              backgroundColor: c.card,
              onRefresh: _load,
              child: _loading
                  ? const LoadingStateView()
                  : _error != null
                      ? ErrorStateView(message: _error, onRetry: _load)
                      : _Body(
                          summary:  _summary,
                          requests: _requests,
                          fmt:      _fmt,
                          dateFmt:  _dateFmt,
                          onBuy:    _showBuySheet,
                        ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final ShareSummary?              summary;
  final List<SharePurchaseRequest> requests;
  final NumberFormat fmt;
  final DateFormat   dateFmt;
  final VoidCallback onBuy;
  const _Body({
    required this.summary, required this.requests,
    required this.fmt, required this.dateFmt, required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final c           = context.colors;
    final hasShares   = summary != null && (summary!.totalUnits > 0 || summary!.transactions.isNotEmpty);
    final hasPending  = requests.any((r) => r.status == 'Pending');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // Share capital card
        if (hasShares) ...[
          _ShareCard(summary: summary!, fmt: fmt),
          const SizedBox(height: 24),
        ] else ...[
          _EmptyShares(onBuy: onBuy),
          const SizedBox(height: 24),
        ],

        // Pending request notice
        if (hasPending)
          _PendingBanner(
            request: requests.firstWhere((r) => r.status == 'Pending'),
            fmt: fmt,
          ),

        // Purchase requests history
        if (requests.isNotEmpty) ...[
          Text('Purchase Requests',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...requests.map((r) => _RequestTile(req: r, fmt: fmt, dateFmt: dateFmt)),
          const SizedBox(height: 24),
        ],

        // Transaction history
        if (hasShares) ...[
          Text('Transaction History',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (summary!.transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No transactions yet.',
                  style: TextStyle(color: c.textSecondary))),
            )
          else
            ...summary!.transactions.map((t) => _TxnTile(txn: t, fmt: fmt, dateFmt: dateFmt)),
        ],
      ],
    );
  }
}

// ── Share Capital Card ────────────────────────────────────────────────────────

class _ShareCard extends StatelessWidget {
  final ShareSummary summary;
  final NumberFormat fmt;
  const _ShareCard({required this.summary, required this.fmt});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(UniconsLine.chart_bar, color: Colors.white70, size: 16),
        SizedBox(width: 6),
        Text('Share Capital',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
      const SizedBox(height: 8),
      MoneyText(amount: summary.totalValue.round(), currency: 'UGX',
          size: 32, color: Colors.white, fit: true),
      const SizedBox(height: 16),
      Divider(color: Colors.white.withAlpha(60), height: 1),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _Mini(
          label: 'Units Held',
          value: '${fmt.format(summary.totalUnits)} units',
        )),
        Container(width: 1, height: 36, color: Colors.white.withAlpha(60)),
        Expanded(child: _Mini(
          label: 'Unit Value',
          value: 'UGX ${fmt.format(summary.unitValue)}',
        )),
      ]),
    ]),
  );
}

class _Mini extends StatelessWidget {
  final String label, value;
  const _Mini({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(
        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
  ]);
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyShares extends StatelessWidget {
  final VoidCallback onBuy;
  const _EmptyShares({required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
          ),
          child: const Icon(UniconsLine.chart_bar, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        Text('No Shares Yet',
            style: TextStyle(
                color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Purchase shares to become a co-owner of BMC SACCO.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onBuy,
          icon: const Icon(UniconsLine.plus, size: 18),
          label: Text('Buy Shares', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emeraldDeep,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
          ),
        ),
      ]),
    );
  }
}

// ── Pending Banner ────────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  final SharePurchaseRequest request;
  final NumberFormat fmt;
  const _PendingBanner({required this.request, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(UniconsLine.clock, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Purchase Request Pending',
                style: TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(
              '${request.unitsRequested} units  •  UGX ${fmt.format(request.totalAmount)}  •  Ref: ${request.reference}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Purchase Request Tile ─────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final SharePurchaseRequest req;
  final NumberFormat fmt;
  final DateFormat   dateFmt;
  const _RequestTile({required this.req, required this.fmt, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final color  = _statusColor(req.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(UniconsLine.chart_line, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${fmt.format(req.unitsRequested)} units requested',
                style: TextStyle(
                    color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            Text('Ref: ${req.reference}  •  ${dateFmt.format(req.createdAt)}',
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ])),
          _StatusBadge(status: req.status),
        ]),
        const SizedBox(height: 10),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Info('Units', '${fmt.format(req.unitsRequested)}', c.textPrimary)),
          Expanded(child: _Info('Unit Price', 'UGX ${fmt.format(req.unitPrice)}', c.textSecondary)),
          Expanded(child: _Info('Total', 'UGX ${fmt.format(req.totalAmount)}', AppColors.gold)),
        ]),
        if (req.paymentMode.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Info('Payment Mode', req.paymentMode, c.textSecondary),
        ],
        if (req.rejectionReason != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(UniconsLine.info_circle, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(req.rejectionReason!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved': return AppColors.emeraldMid;
      case 'Rejected': return AppColors.danger;
      default:         return AppColors.gold;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'Approved'
        ? AppColors.emeraldMid
        : status == 'Rejected'
            ? AppColors.danger
            : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _Info extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Info(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );
}

// ── Transaction Tile ──────────────────────────────────────────────────────────

class _TxnTile extends StatelessWidget {
  final ShareTxn txn;
  final NumberFormat fmt;
  final DateFormat   dateFmt;
  const _TxnTile({required this.txn, required this.fmt, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final isIn   = txn.isCredit;
    final color  = isIn ? AppColors.emeraldMid : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(isIn ? UniconsLine.plus : UniconsLine.minus, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(txn.type, style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(txn.date != null ? dateFmt.format(txn.date!) : '—',
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
            if (txn.certificateNumber != null)
              Text('Cert: ${txn.certificateNumber}',
                  style: TextStyle(color: c.textHint, fontSize: 10)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isIn ? '+' : '-'}${fmt.format(txn.units)} units',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text('UGX ${fmt.format(txn.totalValue)}',
              style: TextStyle(color: c.textSecondary, fontSize: 11)),
        ]),
      ]),
    );
  }
}

// ── Buy Shares Bottom Sheet ───────────────────────────────────────────────────

class _BuySharesSheet extends StatefulWidget {
  final double       unitPrice;
  final VoidCallback onSuccess;
  const _BuySharesSheet({required this.unitPrice, required this.onSuccess});
  @override State<_BuySharesSheet> createState() => _BuySharesSheetState();
}

class _BuySharesSheetState extends State<_BuySharesSheet> {
  final _api      = ApiService();
  final _unitsCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();
  final _fmt       = NumberFormat('#,##0', 'en_US');

  String _paymentMode = 'Cash';
  bool   _busy = false;

  static const _paymentModes = ['Cash', 'Bank Transfer', 'Mobile Money', 'Checkoff'];

  double get _total {
    final u = int.tryParse(_unitsCtrl.text.trim()) ?? 0;
    return u * widget.unitPrice;
  }

  @override
  void dispose() { _unitsCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final units = int.tryParse(_unitsCtrl.text.trim());
    if (units == null || units < 1) {
      _snack('Enter at least 1 unit'); return;
    }
    setState(() => _busy = true);
    try {
      final res = await _api.submitSharePurchaseRequest(
        units:       units,
        paymentMode: _paymentMode,
        notes:       _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${res['message']}  •  Ref: ${res['reference']}'),
        backgroundColor: AppColors.emeraldDeep,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) { _snack(ApiService.extractError(e)); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _payOnline() async {
    final units = int.tryParse(_unitsCtrl.text.trim());
    if (units == null || units < 1) { _snack('Enter at least 1 unit'); return; }
    Navigator.pop(context); // close the sheet
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaymentGatewayScreen(
        initialPurpose: 'share_purchase',
        fixedAmount: _total,
        lockPurpose: true,
      ),
    ));
    widget.onSuccess(); // refresh holdings on return
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 20),

        // Title
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(UniconsLine.chart_line, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Buy Shares',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            Text('1 unit = UGX ${_fmt.format(widget.unitPrice)}',
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 24),

        // Units field
        Text('Number of Units', style: TextStyle(
            color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _unitsCtrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: c.textPrimary),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'e.g. 10',
            hintStyle: TextStyle(color: c.textHint),
            prefixIcon: const Icon(UniconsLine.chart_bar, color: AppColors.gold),
            filled: true, fillColor: c.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.gold, width: 1.5)),
          ),
        ),

        // Total preview
        if ((int.tryParse(_unitsCtrl.text.trim()) ?? 0) > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(UniconsLine.incoming_call, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'Total: UGX ${_fmt.format(_total)}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 16),

        // Payment mode
        Text('Payment Mode', style: TextStyle(
            color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _paymentMode,
              isExpanded: true,
              dropdownColor: c.card,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              items: _paymentModes.map((m) => DropdownMenuItem(
                value: m,
                child: Text(m),
              )).toList(),
              onChanged: (v) => setState(() => _paymentMode = v!),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Notes
        Text('Notes (optional)', style: TextStyle(
            color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Any additional notes...',
            hintStyle: TextStyle(color: c.textHint),
            filled: true, fillColor: c.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
          ),
        ),

        const SizedBox(height: 12),

        // Info note about admin approval
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(UniconsLine.info_circle, color: c.textHint, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Your request will be reviewed and approved by an administrator before shares are allocated to your account.',
              style: TextStyle(color: c.textSecondary, fontSize: 11),
            )),
          ]),
        ),

        const SizedBox(height: 24),

        // Pay instantly online (mobile money / card) — shares allocated on success
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _payOnline,
            icon: const Icon(UniconsLine.mobile_android, size: 18, color: Colors.white),
            label: Text('Pay Online (Mobile Money)',
                style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldDeep,
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Submit a manual request (cash / bank / checkoff — needs admin approval)
        SizedBox(
          width: double.infinity, height: 56,
          child: OutlinedButton(
            onPressed: _busy ? null : _submit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: const BorderSide(color: AppColors.gold),
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5))
                : Text('Submit Manual Request',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

