import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class InterestProjectionScreen extends StatefulWidget {
  final int savingsAccountId;
  final String accountNumber;
  const InterestProjectionScreen({
    super.key,
    required this.savingsAccountId,
    required this.accountNumber,
  });
  @override State<InterestProjectionScreen> createState() => _InterestProjectionScreenState();
}

class _InterestProjectionScreenState extends State<InterestProjectionScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  Map<String, dynamic>? _data;
  int  _months  = 12;
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getInterestProjection(widget.savingsAccountId, months: _months);
      if (mounted) setState(() { _data = data; _loading = false; });
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
              Expanded(child: Text('Interest Projection', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
            ]),
          ),

          // Month picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Project for:', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              DropdownButton<int>(
                value: _months,
                dropdownColor: c.card,
                underline: const SizedBox.shrink(),
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
                items: [3, 6, 12, 24, 36, 60].map((m) =>
                  DropdownMenuItem(value: m, child: Text('$m months'))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _months = v);
                  _load();
                },
              ),
            ]),
          ),

          Expanded(
            child: _loading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error, onRetry: _load)
                    : _data == null
                        ? const SizedBox.shrink()
                        : _buildContent(c),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent(dynamic c) {
    final current = (_data!['current_balance'] as num?)?.toDouble() ?? 0;
    final rate    = (_data!['annual_rate'] as num?)?.toDouble() ?? 0;
    final totalInt= (_data!['total_interest'] as num?)?.toDouble() ?? 0;
    final final_  = (_data!['final_balance'] as num?)?.toDouble() ?? 0;
    final rows    = (_data!['projection'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.emeraldDeep, Color(0xFF00A86B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Text('${widget.accountNumber}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Rate: $rate% p.a.',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _SumItem('Current Balance', 'UGX ${_fmt.format(current)}'),
              _SumItem('Total Interest', '+UGX ${_fmt.format(totalInt)}'),
              _SumItem('Final Balance', 'UGX ${_fmt.format(final_)}'),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        Text('Monthly Breakdown',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        ...rows.map((row) {
          final r      = row as Map<String, dynamic>;
          final month  = r['month'] as int? ?? 0;
          final int_   = (r['interest_earned'] as num?)?.toDouble() ?? 0;
          final proj   = (r['projected_balance'] as num?)?.toDouble() ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.emeraldDeep, shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$month', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('Month $month', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w500))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('+UGX ${_fmt.format(int_)}', style: const TextStyle(color: AppColors.emeraldMid, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('UGX ${_fmt.format(proj)}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ]),
            ]),
          );
        }),
      ],
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label, value;
  const _SumItem(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
  ]);
}
