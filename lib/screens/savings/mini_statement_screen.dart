import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class MiniStatementScreen extends StatefulWidget {
  const MiniStatementScreen({super.key});
  @override State<MiniStatementScreen> createState() => _MiniStatementScreenState();
}

class _MiniStatementScreenState extends State<MiniStatementScreen> {
  final _api    = ApiService();
  final _fmt    = NumberFormat('#,##0', 'en_US');
  final _dateFmt= DateFormat('dd MMM yyyy HH:mm');
  Map<String, dynamic>? _data;
  bool   _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getMiniStatement();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _transactions =>
      ((_data?['transactions'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _savings =>
      _transactions.where((t) => t['source'] == 'savings').toList();

  List<Map<String, dynamic>> get _loanRepayments =>
      _transactions.where((t) => t['source'] == 'loan').toList();

  void _share() {
    if (_data == null) return;
    final buf = StringBuffer();
    buf.writeln('MIA Staff SACCO — Mini Statement');
    buf.writeln('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
    buf.writeln('─' * 40);

    final savings = _savings;
    if (savings.isNotEmpty) {
      buf.writeln('\nSAVINGS TRANSACTIONS');
      for (final m in savings) {
        final amt = (m['amount'] as num?)?.toDouble() ?? 0;
        final type = m['type']?.toString() ?? '';
        final date = m['date']?.toString() ?? '';
        buf.writeln('${type.padRight(12)} UGX ${_fmt.format(amt).padLeft(14)}  $date');
      }
    }

    final loans = _loanRepayments;
    if (loans.isNotEmpty) {
      buf.writeln('\nLOAN REPAYMENTS');
      for (final m in loans) {
        final amt = (m['amount'] as num?)?.toDouble() ?? 0;
        final ref = m['reference']?.toString() ?? '';
        final date = m['date']?.toString() ?? '';
        buf.writeln('Repayment    UGX ${_fmt.format(amt).padLeft(14)}  $date  $ref');
      }
    }

    buf.writeln('─' * 40);
    Share.share(buf.toString(), subject: 'MIA Staff SACCO Mini Statement');
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
              Expanded(child: Text('Mini Statement', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
              if (!_loading && _data != null)
                IconButton(
                  icon: Icon(UniconsLine.share_alt, color: c.textPrimary),
                  onPressed: _share,
                ),
              IconButton(
                icon: Icon(UniconsLine.sync, color: c.textPrimary),
                onPressed: _load,
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error, onRetry: _load)
                    : _buildBody(c),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody(AppColorScheme c) {
    final savings = _savings;
    final loans   = _loanRepayments;

    return RefreshIndicator(
      color: AppColors.emeraldDeep,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.emeraldDeep,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(UniconsLine.receipt, color: AppColors.gold, size: 32),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mini Statement',
                    style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${savings.length} savings · ${loans.length} repayments',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              GestureDetector(
                onTap: _share,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(children: [
                    Icon(UniconsLine.share_alt, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ),

          if (savings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Savings Transactions',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            ...savings.map((s) => _TxnTile(data: s, fmt: _fmt, dateFmt: _dateFmt, isLoan: false)),
          ],

          if (loans.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Loan Repayments',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            ...loans.map((l) => _TxnTile(data: l, fmt: _fmt, dateFmt: _dateFmt, isLoan: true)),
          ],

          if (savings.isEmpty && loans.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text('No transactions found.', style: TextStyle(color: c.textHint)),
            )),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat fmt;
  final DateFormat   dateFmt;
  final bool         isLoan;
  const _TxnTile({required this.data, required this.fmt, required this.dateFmt, required this.isLoan});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final amt    = (data['amount'] as num?)?.toDouble() ?? 0;
    final type   = data['type']?.toString() ?? (isLoan ? 'Repayment' : 'Savings');
    final ref    = data['reference']?.toString() ?? data['reference_number']?.toString() ?? '—';
    final date   = data['date']?.toString() ?? '—';
    final isCredit = !isLoan && (data['is_credit'] as bool? ?? false);
    final color  = isLoan ? AppColors.gold : (isCredit ? AppColors.success : AppColors.error);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isLoan ? UniconsLine.university : (isCredit ? UniconsLine.arrow_down : UniconsLine.arrow_up),
            color: Colors.white, size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text('$ref · $date', style: TextStyle(color: c.textHint, fontSize: 10)),
        ])),
        Text(
          '${isLoan ? '-' : (isCredit ? '+' : '-')} UGX ${fmt.format(amt)}',
          style: TextStyle(
            color: isLoan ? AppColors.danger : (isCredit ? AppColors.success : AppColors.error),
            fontWeight: FontWeight.w700, fontSize: 13,
          ),
        ),
      ]),
    );
  }
}
