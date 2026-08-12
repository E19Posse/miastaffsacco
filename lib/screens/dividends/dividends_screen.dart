import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class DividendsScreen extends StatefulWidget {
  const DividendsScreen({super.key});
  @override State<DividendsScreen> createState() => _DividendsScreenState();
}

class _DividendsScreenState extends State<DividendsScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  List<dynamic> _dividends = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getDividends();
      if (mounted) setState(() { _dividends = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
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
            Expanded(child: Text('Dividends', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(child: _loading
          ? const LoadingStateView()
          : _error != null
              ? ErrorStateView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  color: AppColors.emeraldDeep,
                  onRefresh: _load,
                  child: _dividends.isEmpty
                      ? _EmptyState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          children: [
                            _SummaryCard(dividends: _dividends, fmt: _fmt),
                            const SizedBox(height: 20),
                            Text('Dividend History',
                                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 12),
                            ..._dividends.map((d) => _DividendTile(d: d as Map<String, dynamic>, fmt: _fmt)),
                          ],
                        ),
                ),
        ),
      ])),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Icon(UniconsLine.chart_pie, size: 64, color: c.textHint),
      ),
      const SizedBox(height: 12),
      Text('No dividends yet', style: TextStyle(color: c.textHint, fontSize: 16)),
      const SizedBox(height: 6),
      Text('Your dividend payouts will appear here\nonce declared by the SACCO.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textHint, fontSize: 13)),
    ]));
  }
}

class _SummaryCard extends StatelessWidget {
  final List<dynamic> dividends;
  final NumberFormat fmt;
  const _SummaryCard({required this.dividends, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final total = dividends.fold<double>(0, (s, d) =>
        s + ((d as Map)['total_payout'] as num? ?? 0).toDouble());
    final paid  = dividends.where((d) => (d as Map)['status'] == 'Paid').fold<double>(
        0, (s, d) => s + ((d as Map)['total_payout'] as num? ?? 0).toDouble());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.emeraldDeep, AppColors.emeraldDeep.withOpacity(0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text('Total Declared', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        Text('UGX ${fmt.format(total)}',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _SummaryItem('Paid', 'UGX ${fmt.format(paid)}', Colors.white),
          _SummaryItem('Pending', 'UGX ${fmt.format(total - paid)}', AppColors.gold),
        ]),
      ]),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryItem(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
  ]);
}

class _DividendTile extends StatelessWidget {
  final Map<String, dynamic> d;
  final NumberFormat fmt;
  const _DividendTile({required this.d, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final year   = d['financial_year'] as String? ?? '—';
    final total  = (d['total_payout'] as num?)?.toDouble() ?? 0;
    final share  = (d['share_dividend'] as num?)?.toDouble() ?? 0;
    final iod    = (d['iod_amount'] as num?)?.toDouble() ?? 0;
    final status = d['status'] as String? ?? '—';
    final paidAt = d['paid_at'] as String?;
    final isPaid = status == 'Paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('FY $year',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPaid ? AppColors.emeraldMid : AppColors.gold,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
          ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _Line(c, 'Share Dividend', 'UGX ${fmt.format(share)}'),
          _Line(c, 'Interest on Deposits', 'UGX ${fmt.format(iod)}'),
        ]),
        const SizedBox(height: 8),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total Payout', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text('UGX ${fmt.format(total)}',
              style: TextStyle(color: AppColors.emeraldDeep, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        if (paidAt != null) ...[
          const SizedBox(height: 6),
          Text('Paid on $paidAt', style: TextStyle(color: c.textHint, fontSize: 12)),
        ],
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final dynamic c;
  final String label, value;
  const _Line(this.c, this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: c.textHint, fontSize: 11)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
  ]);
}
