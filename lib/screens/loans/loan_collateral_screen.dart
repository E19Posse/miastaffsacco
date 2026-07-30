import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class LoanCollateralScreen extends StatefulWidget {
  final int    loanId;
  final String loanNumber;
  const LoanCollateralScreen({
    super.key,
    required this.loanId,
    required this.loanNumber,
  });
  @override
  State<LoanCollateralScreen> createState() => _LoanCollateralScreenState();
}

class _LoanCollateralScreenState extends State<LoanCollateralScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  List<dynamic> _collateral = [];
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
      final list = await _api.getLoanCollateral(widget.loanId);
      if (mounted) setState(() { _collateral = list; _loading = false; });
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
            Expanded(child: Text('Collateral – ${widget.loanNumber}', style: GoogleFonts.sora(
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
                      child: _collateral.isEmpty
                          ? _emptyState(c)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              itemCount: _collateral.length,
                              itemBuilder: (_, i) => _CollateralCard(
                                item: _collateral[i] as Map<String, dynamic>,
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
      Icon(UniconsLine.shield, size: 64, color: c.textHint),
      const SizedBox(height: 12),
      Text('No collateral registered for this loan',
          style: TextStyle(color: c.textSecondary, fontSize: 15),
          textAlign: TextAlign.center),
    ]),
  );
}

class _CollateralCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final NumberFormat fmt;
  const _CollateralCard({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final type   = item['type'] as String? ?? '—';
    final desc   = item['description'] as String? ?? '';
    final value  = (item['estimated_value'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.emeraldMid,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(UniconsLine.shield, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type,
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Text('Estimated Value: ', style: TextStyle(color: c.textHint, fontSize: 11)),
            Text('UGX ${fmt.format(value)}',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ])),
      ]),
    );
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
