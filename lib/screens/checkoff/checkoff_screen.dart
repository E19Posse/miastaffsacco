import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class CheckoffScreen extends StatefulWidget {
  const CheckoffScreen({super.key});
  @override
  State<CheckoffScreen> createState() => _CheckoffScreenState();
}

class _CheckoffScreenState extends State<CheckoffScreen> {
  final _api    = ApiService();
  final _fmt    = NumberFormat('#,##0', 'en_US');
  List<dynamic>        _records  = [];
  Map<String, dynamic> _expected = {};
  bool    _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getCheckoffStatement();
      if (mounted) setState(() {
        _records  = data['records'] as List<dynamic>;
        _expected = data['expected'] as Map<String, dynamic>;
        _loading  = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  double get _totalReceived => _records
      .where((r) => (r as Map)['status'] == 'Received')
      .fold(0.0, (sum, r) => sum + ((r as Map)['amount_received'] as num? ?? (r as Map)['total_deduction'] as num? ?? 0).toDouble());

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
            Expanded(child: Text('Payroll Deductions', style: GoogleFonts.sora(
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      if (_expected.isNotEmpty) ...[
                        _ExpectedCard(expected: _expected, fmt: _fmt),
                        const SizedBox(height: 16),
                      ],
                      _TotalCard(total: _totalReceived, fmt: _fmt),
                      const SizedBox(height: 20),
                      Text('Deduction History',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 12),
                      if (_records.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: EmptyStateView(
                            title: 'No payroll deductions yet',
                            icon: Icons.pie_chart_outline,
                          ),
                        )
                      else
                        ..._records.map((r) => _CheckoffTile(
                              r: r as Map<String, dynamic>, fmt: _fmt)),
                    ],
                  ),
                ),
        ),
      ])),
    );
  }
}

class _ExpectedCard extends StatelessWidget {
  final Map<String, dynamic> expected;
  final NumberFormat fmt;
  const _ExpectedCard({required this.expected, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c         = context.colors;
    final amount    = (expected['savings_deduction'] as num?)?.toDouble() ?? 0;
    final isCustom  = expected['is_custom'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCustom ? AppColors.emeraldDeep : c.border,
          width: isCustom ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isCustom ? AppColors.emeraldDeep : c.cardAlt,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCustom ? UniconsLine.sliders_v : UniconsLine.university,
            color: isCustom ? Colors.white : c.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Monthly Savings Deduction',
              style: TextStyle(color: c.textSecondary, fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('UGX ${fmt.format(amount)}',
              style: TextStyle(
                  color: isCustom ? AppColors.emeraldDeep : c.textPrimary,
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            isCustom
                ? 'Custom rate set for your account'
                : 'SACCO-wide default rate',
            style: TextStyle(
                color: isCustom ? AppColors.emeraldDeep : c.textHint,
                fontSize: 11),
          ),
        ])),
        if (isCustom)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emeraldDeep,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Custom',
                style: TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final NumberFormat fmt;
  const _TotalCard({required this.total, required this.fmt});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.gold, Color(0xFFFF6D00)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Total Received', style: TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 8),
      Text('UGX ${fmt.format(total)}',
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('From employer payroll deductions',
          style: TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  );
}

class _CheckoffTile extends StatelessWidget {
  final Map<String, dynamic> r;
  final NumberFormat fmt;
  const _CheckoffTile({required this.r, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final month    = r['month'] as String? ?? r['period'] as String? ?? '—';
    final savings  = (r['savings_deduction'] as num?)?.toDouble() ?? 0;
    final loan     = (r['loan_repayment'] as num?)?.toDouble() ?? 0;
    final total    = (r['total_deduction'] as num?)?.toDouble() ?? (savings + loan);
    final received = (r['amount_received'] as num?)?.toDouble() ?? 0;
    final status   = r['status'] as String? ?? '—';
    final isRecv   = status == 'Received';
    final Color statusColor = isRecv ? AppColors.emeraldMid : AppColors.gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(month,
              style: TextStyle(color: c.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor, borderRadius: BorderRadius.circular(10)),
            child: Text(status,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Item(label: 'Savings', value: 'UGX ${fmt.format(savings)}', c: c)),
          Expanded(child: _Item(label: 'Loan Repayment', value: 'UGX ${fmt.format(loan)}', c: c)),
        ]),
        const SizedBox(height: 8),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Expected Total',
              style: TextStyle(color: c.textSecondary,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Text('UGX ${fmt.format(total)}',
              style: const TextStyle(
                  color: AppColors.emeraldDeep, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        if (isRecv && received > 0) ...[
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Amount Received',
                style: TextStyle(color: c.textHint, fontSize: 12)),
            Text('UGX ${fmt.format(received)}',
                style: const TextStyle(
                    color: AppColors.emeraldMid, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ],
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  final String label, value;
  final AppColorScheme c;
  const _Item({required this.label, required this.value, required this.c});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: c.textHint, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: c.textPrimary,
          fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );
}

