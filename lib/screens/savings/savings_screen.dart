import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/savings_account.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import '../goals/savings_goals_screen.dart';
import 'open_savings_account_screen.dart';
import 'package:unicons/unicons.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  Future<void> _openNewAccount(BuildContext context) async {
    final opened = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const OpenSavingsAccountScreen()));
    if (opened == true && context.mounted) {
      context.read<DashboardProvider>().refresh();
    }
  }

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
                      Text('SAVINGS', style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text('Your Accounts', style: GoogleFonts.sora(
                          fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
                    ])),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())),
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
                      Text('TOTAL SAVED ACROSS ACCOUNTS', style: TextStyle(
                          color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Text('UGX ', style: GoogleFonts.sora(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(fmt.format(dash.totalSavings.round()), style: GoogleFonts.sora(
                            color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 18),
                      Row(children: [
                        _HeroStat(label: 'Accounts', value: '${dash.savings.length}'),
                        const SizedBox(width: 20),
                        Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(width: 20),
                        _HeroStat(label: 'Active', value: '${dash.savings.where((a) => a.isActive).length}'),
                        const SizedBox(width: 20),
                        Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(width: 20),
                        _HeroStat(
                          label: 'Yield',
                          value: dash.savings.isEmpty ? '—' : '${(dash.savings.map((a) => a.interestRate).reduce((a, b) => a + b) / dash.savings.length).toStringAsFixed(1)}% p.a.',
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () => _openNewAccount(context),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.emeraldDeep, width: 1.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(color: AppColors.emeraldDeep, shape: BoxShape.circle),
                          child: const Icon(UniconsLine.plus, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text('Open a new savings account',
                            style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
                        Icon(UniconsLine.angle_right, color: c.textHint, size: 20),
                      ]),
                    ),
                  ),

                  if (dash.savings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: EmptyStateView(
                        title: 'No savings accounts yet',
                        message: 'Open your first account above to start saving.',
                        icon: Icons.savings_outlined,
                      ),
                    )
                  else
                    ...dash.savings.map((a) => _AccountCard(acc: a, fmt: fmt)),
                ],
              ),
              ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
    ],
  );
}

class _AccountCard extends StatelessWidget {
  final SavingsAccount acc;
  final NumberFormat fmt;
  const _AccountCard({required this.acc, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = acc.isLocked
        ? AppColors.danger
        : (acc.isActive ? AppColors.emeraldMid : AppColors.gold);
    final statusLabel = acc.isLocked ? 'Locked' : (acc.isActive ? 'Active' : 'Inactive');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.emeraldDeep, borderRadius: BorderRadius.circular(999)),
              child: Text(acc.accountNumber, style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
            ),
            const SizedBox(height: 8),
            Text(acc.productName, style: GoogleFonts.sora(
                fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(height: 3),
            Text('${acc.interestRate}% p.a. yield',
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ])),
          Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Balance', style: TextStyle(color: c.textSecondary, fontSize: 12)),
          Text('UGX ${fmt.format(acc.balance)}', style: GoogleFonts.sora(
              color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}
