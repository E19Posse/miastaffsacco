import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class LoanGuarantorsScreen extends StatefulWidget {
  final int    loanId;
  final String loanNumber;
  const LoanGuarantorsScreen({
    super.key,
    required this.loanId,
    required this.loanNumber,
  });
  @override
  State<LoanGuarantorsScreen> createState() => _LoanGuarantorsScreenState();
}

class _LoanGuarantorsScreenState extends State<LoanGuarantorsScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  List<dynamic> _guarantors = [];
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
      final list = await _api.getLoanGuarantors(widget.loanId);
      if (mounted) setState(() { _guarantors = list; _loading = false; });
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
            Expanded(child: Text('Guarantors – ${widget.loanNumber}', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: AppColors.emeraldDeep,
                      onRefresh: _load,
                      child: _guarantors.isEmpty
                          ? _emptyState(c)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              itemCount: _guarantors.length,
                              itemBuilder: (_, i) => _GuarantorCard(
                                g: _guarantors[i] as Map<String, dynamic>,
                                fmt: _fmt,
                              ),
                            ),
                    ),
        ),
      ])),
    );
  }

  Widget _emptyState(AppColorScheme c) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(UniconsLine.users_alt, size: 64, color: c.textHint),
      const SizedBox(height: 12),
      Text('No guarantors on this loan',
          style: TextStyle(color: c.textSecondary, fontSize: 15)),
    ]),
  );
}

class _GuarantorCard extends StatelessWidget {
  final Map<String, dynamic> g;
  final NumberFormat fmt;
  const _GuarantorCard({required this.g, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final status = (g['status'] as String? ?? 'Pending');
    final Color statusColor;
    switch (status) {
      case 'Accepted': statusColor = AppColors.emeraldMid;  break;
      case 'Declined': statusColor = AppColors.danger;    break;
      default:         statusColor = AppColors.gold;
    }
    final amount = (g['guaranteed_amount'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(UniconsLine.user, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g['guarantor_name'] as String? ?? '—',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text('Member #${g['guarantor_member_number'] as String? ?? '—'}',
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(status,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _InfoItem(label: 'Phone', value: g['phone'] as String? ?? '—', c: c),
          _InfoItem(
            label: 'Guaranteed Amount',
            value: 'UGX ${fmt.format(amount)}',
            c: c,
            valueColor: AppColors.gold,
          ),
        ]),
      ]),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  final AppColorScheme c;
  final Color? valueColor;
  const _InfoItem({required this.label, required this.value, required this.c, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: c.textHint, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(
        color: valueColor ?? c.textPrimary,
        fontSize: 13, fontWeight: FontWeight.w600,
      )),
    ],
  );
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
