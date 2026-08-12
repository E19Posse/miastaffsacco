import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/loan.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_state_views.dart';
import 'loan_application_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_collateral_screen.dart';
import 'loan_guarantors_screen.dart';
import 'settlement_calculator_screen.dart';
import '../payments/payment_gateway_screen.dart';
import 'package:unicons/unicons.dart';
import '../../widgets/app_svg_icon.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final dash = context.watch<DashboardProvider>();
    final fmt  = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: dash.loading
            ? const LoadingStateView()
            : dash.error != null
                ? ErrorStateView(message: dash.error, onRetry: dash.refresh)
                : RefreshIndicator(
                color: AppColors.emeraldDeep,
                onRefresh: () => dash.refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('LOANS', style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text('Your Borrowing', style: GoogleFonts.sora(
                            fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
                      ])),
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LoanApplicationScreen())),
                        child: Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(color: AppColors.emeraldDeep, shape: BoxShape.circle),
                          child: const Icon(UniconsLine.plus, color: Colors.white, size: 18),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppColors.emeraldDeep, borderRadius: BorderRadius.circular(28)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('TOTAL OUTSTANDING', style: TextStyle(
                              color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5))),
                          if (dash.overdueLoans > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(999)),
                              child: Text('${dash.overdueLoans} OVERDUE', style: const TextStyle(
                                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text('UGX ', style: GoogleFonts.sora(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w800)),
                          Text(fmt.format(dash.totalLoans), style: GoogleFonts.sora(
                              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                        ]),
                        if (dash.loans.any((l) => l.status == 'Active')) ...[
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: () {
                              final active = dash.loans.firstWhere((l) => l.status == 'Active');
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => PaymentGatewayScreen(
                                  initialPurpose: 'loan_repayment', initialAccountId: active.id,
                                ),
                              ));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(999)),
                              child: Text('Repay Now', style: GoogleFonts.sora(
                                  color: AppColors.emeraldDeep, fontSize: 13, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 20),

                    if (dash.loans.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: EmptyStateView(
                          title: 'No loans yet',
                          message: 'Apply for a loan using the + button above.',
                          icon: UniconsLine.receipt,
                        ),
                      )
                    else
                      ...dash.loans.asMap().entries.map((e) => StaggerItem(
                        index: e.key, child: _LoanCard(loan: e.value, fmt: fmt),
                      )),
                  ],
                ),
              ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final NumberFormat fmt;
  const _LoanCard({required this.loan, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c           = context.colors;
    final dateFmt     = DateFormat('dd MMM yyyy');
    final statusColor = switch (loan.status) {
      'Active'                    => AppColors.emeraldMid,
      'Rejected'                  => AppColors.danger,
      'Closed' || 'Written Off'   => Colors.blueGrey,
      _                           => AppColors.gold,
    };
    final progress    = loan.repaymentProgress;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => LoanDetailScreen(loan: loan))),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: loan.isOverdue ? AppColors.danger.withValues(alpha: 0.3) : c.border,
          width: loan.isOverdue ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(loan.loanNumber, style: TextStyle(
                color: c.textSecondary,
                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
            const SizedBox(height: 3),
            Text(loan.productName, style: GoogleFonts.sora(
                fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(999)),
            child: Text(loan.status, style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.emeraldTint,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emeraldMid),
          ),
        ),
        const SizedBox(height: 14),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MiniStat(label: 'Outstanding', value: 'UGX ${fmt.format(loan.balance)}')),
          Expanded(child: _MiniStat(
            label: 'Next Due',
            value: loan.nextDueDate != null ? dateFmt.format(loan.nextDueDate!) : '—',
          )),
          Expanded(child: _MiniStat(label: 'Rate', value: '${loan.interestRate}% / mo')),
        ]),

        const SizedBox(height: 14),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(UniconsLine.shield, size: 14, color: Colors.white),
              label: const Text('Collateral', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldMid,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LoanCollateralScreen(
                  loanId: loan.id,
                  loanNumber: loan.loanNumber,
                ),
              )),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(UniconsLine.users_alt, size: 14, color: Colors.white),
              label: const Text('Guarantors', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LoanGuarantorsScreen(
                  loanId: loan.id,
                  loanNumber: loan.loanNumber,
                ),
              )),
            ),
          ),
          if (loan.status == 'Active') ...[
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(UniconsLine.calculator, size: 14, color: Colors.white),
                label: const Text('Settlement', style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SettlementCalculatorScreen(
                    loanId: loan.id,
                    loanNumber: loan.loanNumber,
                  ),
                )),
              ),
            ),
          ],
        ]),
        if (loan.status == 'Active') ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const AppSvgIcon(AppSvgIcons.repay, size: 16, color: AppColors.emeraldDeep),
              label: const Text('Repay Loan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.emeraldDeep)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PaymentGatewayScreen(
                  initialPurpose: 'loan_repayment',
                  initialAccountId: loan.id,
                ),
              )),
            ),
          ),
        ],
      ]),
    ),
    );
  }

}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(
            color: c.textHint, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.sora(
            color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
