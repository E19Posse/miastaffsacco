import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/step_progress.dart';
import '../payments/payment_gateway_screen.dart';
import 'loan_schedule_screen.dart';
import 'loan_collateral_screen.dart';
import 'loan_guarantors_screen.dart';
import 'settlement_calculator_screen.dart';
import 'package:unicons/unicons.dart';

const _stageLabels = ['Submitted', 'Under Review', 'Approved', 'Disbursed'];

class LoanDetailScreen extends StatelessWidget {
  final Loan loan;
  const LoanDetailScreen({super.key, required this.loan});

  List<StepDotState> _states() {
    if (loan.isRejected) {
      return [StepDotState.done, StepDotState.failed, StepDotState.pending, StepDotState.pending];
    }
    final stage = loan.progressStage; // 1=Under Review, 2=Approved, 3=Disbursed
    return List.generate(4, (i) {
      if (i < stage) return StepDotState.done;
      if (i == stage) return StepDotState.current;
      return StepDotState.pending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final fmt    = NumberFormat('#,##0', 'en_US');
    final dtFmt  = DateFormat('dd MMM yyyy');
    final active = loan.status == 'Active';

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
                  Text(loan.productName, style: GoogleFonts.sora(
                      fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
                  Text(loan.loanNumber, style: TextStyle(color: c.textSecondary, fontSize: 11)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                if (loan.isRejected)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(UniconsLine.times_circle, color: AppColors.danger),
                      const SizedBox(width: 12),
                      Expanded(child: Text(
                        'This application was not approved. Contact your branch for details or apply again.',
                        style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600),
                      )),
                    ]),
                  ),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(children: [
                    StepProgress(labels: _stageLabels, states: _states()),
                    const SizedBox(height: 16),
                    if (loan.createdAt != null)
                      Text('Submitted on ${dtFmt.format(loan.createdAt!)}',
                          style: TextStyle(color: c.textHint, fontSize: 11)),
                    if (loan.disbursedAt != null) ...[
                      const SizedBox(height: 2),
                      Text('Disbursed on ${dtFmt.format(loan.disbursedAt!)}',
                          style: TextStyle(color: c.textHint, fontSize: 11)),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.emeraldDeep, borderRadius: BorderRadius.circular(24)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PRINCIPAL', style: TextStyle(
                        color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    Text('UGX ${fmt.format(loan.principal)}', style: GoogleFonts.sora(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _Stat(label: 'Outstanding', value: 'UGX ${fmt.format(loan.balance)}')),
                      Expanded(child: _Stat(label: 'Rate', value: '${loan.interestRate}% / mo')),
                      Expanded(child: _Stat(label: 'Term', value: '${loan.termMonths} mo')),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),

                if (active) ...[
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => LoanScheduleScreen(loan: loan))),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
                          shape: const StadiumBorder()),
                      child: const Text('View Repayment Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PaymentGatewayScreen(
                              initialPurpose: 'loan_repayment', initialAccountId: loan.id))),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold, foregroundColor: AppColors.emeraldDeep,
                          shape: const StadiumBorder()),
                      child: const Text('Repay Loan', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    icon: const Icon(UniconsLine.shield, size: 16, color: Colors.white),
                    label: const Text('Collateral', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldMid,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => LoanCollateralScreen(loanId: loan.id, loanNumber: loan.loanNumber))),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    icon: const Icon(UniconsLine.users_alt, size: 16, color: Colors.white),
                    label: const Text('Guarantors', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => LoanGuarantorsScreen(loanId: loan.id, loanNumber: loan.loanNumber))),
                  )),
                ]),
                if (active) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(UniconsLine.calculator, size: 16, color: Colors.white),
                      label: const Text('Settlement Calculator', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SettlementCalculatorScreen(loanId: loan.id, loanNumber: loan.loanNumber))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)),
      const SizedBox(height: 3),
      Text(value, style: GoogleFonts.sora(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
    ],
  );
}
