import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'loan_reschedule_screen.dart';
import 'package:unicons/unicons.dart';

class LoanScheduleScreen extends StatefulWidget {
  final Loan loan;
  const LoanScheduleScreen({super.key, required this.loan});

  @override
  State<LoanScheduleScreen> createState() => _LoanScheduleScreenState();
}

class _LoanScheduleScreenState extends State<LoanScheduleScreen> {
  final _api    = ApiService();
  final _fmt    = NumberFormat('#,##0', 'en_US');
  final _dtFmt  = DateFormat('dd MMM yyyy');

  List<Map<String, dynamic>> _schedule = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getLoanSchedule(widget.loan.id);
      setState(() => _schedule = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      setState(() => _error = ApiService.extractError(e));
    } finally {
      setState(() => _loading = false);
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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Repayment Schedule', style: GoogleFonts.sora(
                      fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
                  Text(widget.loan.loanNumber,
                      style: TextStyle(color: c.textSecondary, fontSize: 11)),
                ]),
              ),
              if (widget.loan.status.toLowerCase() == 'active' ||
                  widget.loan.status.toLowerCase() == 'disbursed')
                TextButton.icon(
                  icon: Icon(UniconsLine.history, size: 16, color: c.textPrimary),
                  label: Text('Reschedule', style: GoogleFonts.sora(
                      fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => LoanRescheduleScreen(
                      loanId:  widget.loan.id,
                      loanRef: widget.loan.loanNumber,
                    ),
                  )),
                ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error, onRetry: _load)
                    : _buildContent(c),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent(AppColorScheme c) {
    if (_schedule.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(UniconsLine.calendar_alt, size: 56, color: c.textHint),
          const SizedBox(height: 12),
          Text('No repayment schedule available',
              style: TextStyle(color: c.textSecondary)),
        ]),
      );
    }

    // Summary header
    final totalInstallments = _schedule.length;
    final paid = _schedule.where((r) => (r['paid'] as bool? ?? false)).length;

    return Column(children: [
      // Summary bar
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          _SummaryChip('Total', '$totalInstallments installments', Colors.white70, Colors.white),
          const SizedBox(width: 16),
          _SummaryChip('Paid', '$paid paid', Colors.white70, AppColors.emeraldDeep),
          const SizedBox(width: 16),
          _SummaryChip('Remaining', '${totalInstallments - paid} left', Colors.white70, Colors.white),
        ]),
      ),

      // Column headers
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border, width: .5),
        ),
        child: Row(children: [
          _ColHeader('#',       c, flex: 1),
          _ColHeader('Due Date',c, flex: 3),
          _ColHeader('Amount',  c, flex: 3, right: true),
          _ColHeader('Status',  c, flex: 2, right: true),
        ]),
      ),
      const SizedBox(height: 4),

      // Schedule rows
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: _schedule.length,
          itemBuilder: (_, i) {
            final row      = _schedule[i];
            final isPaid   = row['paid'] as bool? ?? false;
            final isOverdue= row['overdue'] as bool? ?? false;
            final amount   = (row['amount'] as num?)?.toDouble() ?? 0;
            final dueDate  = row['payment_date'] != null
                ? DateTime.tryParse(row['payment_date'] as String)
                : null;

            Color rowColor = c.card;
            Color statusColor = c.textSecondary;
            String statusLabel = 'Pending';
            if (isPaid)    { rowColor = AppColors.emeraldMid.withValues(alpha: 0.05); statusColor = AppColors.emeraldMid;  statusLabel = 'Paid'; }
            if (isOverdue) { rowColor = AppColors.danger.withValues(alpha: 0.05);   statusColor = AppColors.danger;    statusLabel = 'Overdue'; }

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: rowColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOverdue ? AppColors.danger.withValues(alpha: 0.3) : c.border,
                  width: .5,
                ),
              ),
              child: Row(children: [
                Expanded(flex: 1, child: Text('${i + 1}',
                    style: TextStyle(color: c.textSecondary, fontSize: 12))),
                Expanded(flex: 3, child: Text(
                    dueDate != null ? _dtFmt.format(dueDate) : '—',
                    style: TextStyle(color: c.textPrimary, fontSize: 12))),
                Expanded(flex: 3, child: Text(
                    'UGX ${_fmt.format(amount)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text(statusLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700))),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color labelColor, valueColor;
  const _SummaryChip(this.label, this.value, this.labelColor, this.valueColor);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: labelColor, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _ColHeader extends StatelessWidget {
  final String text;
  final AppColorScheme c;
  final int flex;
  final bool right;
  const _ColHeader(this.text, this.c, {this.flex = 2, this.right = false});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
