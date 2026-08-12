import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../transactions/transactions_screen.dart';
import '../fixed_deposits/fixed_deposits_screen.dart';
import '../shares/shares_screen.dart';
import '../withdrawals/withdrawal_requests_screen.dart';
import '../kyc/kyc_screen.dart';
import '../profile/profile_screen.dart';
import '../payments/payment_gateway_screen.dart';
import '../payments/payment_methods_screen.dart';
import '../settings/app_settings_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../goals/savings_goals_screen.dart';
import '../challenges/challenges_screen.dart';
import '../loans/loan_calculator_screen.dart';
import '../loans/guarantor_requests_screen.dart';
import '../beneficiaries/beneficiaries_screen.dart';
import '../insights/savings_insights_screen.dart';
import '../governance/governance_screen.dart';
import '../bank_details/bank_details_screen.dart';
import '../support/support_tickets_screen.dart';
import '../../utils/feature_gate.dart';
import '../../widgets/app_animations.dart';
import '../financial_health/financial_health_screen.dart';
import '../security/sessions_screen.dart';
import '../security/transaction_pin_screen.dart';
import '../dividends/dividends_screen.dart';
import '../savings/mini_statement_screen.dart';
import '../referral/referral_screen.dart';
import '../notifications/notifications_screen.dart';
import '../branches/branches_screen.dart';
import '../checkoff/checkoff_screen.dart';
import '../member/exit_request_screen.dart';
import '../admin/impersonate_screen.dart';
import '../member/subscription_fee_screen.dart';
import 'package:unicons/unicons.dart';
import '../legal/legal_content_screen.dart';
import '../../widgets/app_svg_icon.dart';
import '../../widgets/verification_badge.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final member = context.watch<AuthProvider>().member;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text('PROFILE', style: TextStyle(
                color: c.textSecondary,
                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('Your membership', style: GoogleFonts.sora(
                fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(height: 20),
            ..._buildTiles(context, member),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTiles(BuildContext context, dynamic member) {
    final c = context.colors;
    final dash = context.watch<DashboardProvider>();
    int n = 0;

    Widget tile(Widget child) => StaggerItem(index: n++, child: child);

    final joinedFmt = member?.joinedAt != null
        ? DateFormat('MMM yyyy').format(member.joinedAt as DateTime)
        : '—';
    final standing = member?.kycLocked == true
        ? 'Restricted'
        : (member?.isApproved == false ? 'Pending' : 'Good');

    return [
      // Member chip
      GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: AppColors.emeraldDeep,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: member?.avatarUrl != null ? null : AppColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: ClipOval(
                  child: member?.avatarUrl != null
                      ? Image.network(
                          member!.avatarUrl!,
                          width: 54, height: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(child: Text(
                            member.initials,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                          )),
                        )
                      : Center(child: Text(
                          member?.initials ?? 'M',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                        )),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(member?.name ?? '—',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w800, fontSize: 16))),
                  if (member != null) ...[
                    const SizedBox(width: 6),
                    VerificationBadge(tier: member.creditTier, size: 16),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(member?.phone?.isNotEmpty == true ? member.phone : '—',
                    style: TextStyle(color: AppColors.cream.withValues(alpha: 0.7), fontSize: 12)),
              ])),
              Icon(UniconsLine.angle_right, color: AppColors.cream.withValues(alpha: 0.6)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              if (member != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: tierChipColor(member.creditTier), borderRadius: BorderRadius.circular(999)),
                  child: Text('${member.creditTier.toUpperCase()} TIER',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
              ],
              Text('Member #${member?.memberNumber ?? '—'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            Divider(color: AppColors.cream.withValues(alpha: 0.15), height: 1),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _MemberStat(label: 'Member Since', value: joinedFmt)),
              Expanded(child: _MemberStat(label: 'Accounts', value: '${dash.savings.length}')),
              Expanded(child: _MemberStat(label: 'Standing', value: standing)),
            ]),
          ]),
        ),
      ),

      // Finance
      _SectionTitle(c, 'Finance'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: UniconsLine.university,
        label: 'Fixed Deposits',
        sub: 'View and manage your FD accounts',
        color: AppColors.emeraldMid,
        onTap: () => _push(context, const FixedDepositsScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.chart_bar,
        label: 'My Shares',
        sub: 'Share capital and transactions',
        color: AppColors.blue,
        onTap: () => _push(context, const SharesScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.receipt,
        label: 'Transactions',
        sub: 'Full transaction history',
        color: AppColors.warning,
        onTap: () => _push(context, const TransactionsScreen()),
      )),
      tile(_ServiceTile(
        icon: Icons.verified_user_outlined,
        label: 'KYC Verification',
        sub: 'Verify your identity to unlock all features',
        color: AppColors.success,
        onTap: () => _push(context, const KycScreen()),
      )),

      // Tools & Governance
      const SizedBox(height: 20),
      _SectionTitle(c, 'Tools & Governance'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: UniconsLine.bookmark,
        label: 'Savings Goals',
        sub: 'Track your savings targets and progress',
        color: AppColors.success,
        onTap: () => _push(context, const SavingsGoalsScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.trophy,
        label: 'Savings Challenges',
        sub: 'Gamified saving — tap cards to deposit & fill the grid',
        color: AppColors.emeraldMid,
        onTap: () => _push(context, const ChallengesScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.calculator,
        label: 'Loan Calculator',
        sub: 'Estimate instalments and total cost',
        color: AppColors.warning,
        onTap: () => _push(context, const LoanCalculatorScreen()),
      )),
      tile(_ServiceTile(
        icon: Icons.privacy_tip_outlined,
        label: 'Guarantor Requests',
        sub: 'Loans you have been asked to guarantee',
        color: AppColors.emeraldMid,
        onTap: () => _push(context, const GuarantorRequestsScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.users_alt,
        label: 'Beneficiaries',
        sub: 'Manage your next-of-kin and payout shares',
        color: AppColors.blue,
        onTap: () => _push(context, const BeneficiariesScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.chart_line,
        label: 'Savings Insights',
        sub: 'Trends, streaks and your 12-month projection',
        color: AppColors.primary,
        onTap: () => _push(context, const SavingsInsightsScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.user_plus,
        label: 'Refer a Friend',
        sub: 'Share your referral code and earn bonuses',
        color: AppColors.success,
        onTap: () => _push(context, const ReferralScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.map_marker,
        label: 'Our Branches',
        sub: 'Find SACCO branch locations and contacts',
        color: AppColors.primary,
        onTap: () => _push(context, const BranchesScreen()),
      )),
      tile(_ServiceTile(
        icon: Icons.how_to_vote_outlined, iconSvg: AppSvgIcons.vote,
        label: 'Governance',
        sub: 'Board, meetings, proposals & voting',
        color: AppColors.emeraldMid,
        onTap: () => _push(context, const GovernanceScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.university,
        label: 'Bank Accounts',
        sub: 'Manage your linked bank accounts',
        color: AppColors.blue,
        onTap: () => _push(context, const BankDetailsScreen()),
      )),

      // Payments
      const SizedBox(height: 20),
      _SectionTitle(c, 'Payments'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: UniconsLine.credit_card,
        label: 'Pay via Gateway',
        sub: 'MTN MoMo, Airtel Money, Card or Bank',
        color: AppColors.emeraldMid,
        onTap: () => _push(context, const PaymentGatewayScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.mobile_android,
        label: 'Payment Methods',
        sub: 'Manage saved MTN and Airtel accounts',
        color: AppColors.blue,
        onTap: () => _push(context, const PaymentMethodsScreen()),
      )),

      // Requests
      const SizedBox(height: 20),
      _SectionTitle(c, 'Requests'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: UniconsLine.exchange_alt,
        label: 'Withdrawal Requests',
        sub: 'Request savings or FD withdrawals',
        color: AppColors.primary,
        onTap: () => FeatureGate.requireFull(
          context,
          member: member,
          feature: 'Withdrawal Requests',
          onGranted: () => _push(context, const WithdrawalRequestsScreen()),
        ),
      )),
      tile(_ServiceTile(
        icon: Icons.pie_chart_outline,
        label: 'Payroll Deductions',
        sub: 'View monthly check-off deductions',
        color: AppColors.warning,
        onTap: () => _push(context, const CheckoffScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.signout,
        label: 'Request Exit',
        sub: 'Begin the SACCO exit process',
        color: AppColors.error,
        onTap: () => _push(context, const ExitRequestScreen()),
      )),
      tile(_ServiceTile(
        icon: Icons.subscriptions_outlined,
        label: 'Subscription Fee',
        sub: 'View and pay your one-time membership fee',
        color: AppColors.success,
        onTap: () => _push(context, const SubscriptionFeeScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.headphones,
        label: 'Help & Support',
        sub: 'Raise a ticket and get help from our team',
        color: AppColors.error,
        onTap: () => _push(context, const SupportTicketsScreen()),
      )),

      // Insights
      const SizedBox(height: 20),
      _SectionTitle(c, 'Insights'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: Icons.local_hospital_outlined,
        label: 'Financial Health',
        sub: 'Credit score, history, badges and financial overview',
        color: AppColors.success,
        onTap: () => _push(context, const FinancialHealthScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.chart_pie,
        label: 'Dividends',
        sub: 'Dividend declarations and payouts history',
        color: AppColors.emeraldMid,
        onTap: () => _push(context, const DividendsScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.receipt,
        label: 'Mini Statement',
        sub: 'Recent transactions summary, share as PDF',
        color: AppColors.blue,
        onTap: () => _push(context, const MiniStatementScreen()),
      )),

      // Communications
      const SizedBox(height: 20),
      _SectionTitle(c, 'Communications'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
        sub: 'View all alerts, reminders and messages',
        color: AppColors.warning,
        onTap: () => _push(context, const NotificationsScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.sliders_v,
        label: 'Notification Settings',
        sub: 'Push, SMS and email alert preferences',
        color: AppColors.blue,
        onTap: () => _push(context, const NotificationSettingsScreen()),
      )),

      // Security
      const SizedBox(height: 20),
      _SectionTitle(c, 'Security'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: Icons.password_outlined,
        label: 'Transaction PIN',
        sub: 'Set or change your 6-digit transaction PIN',
        color: AppColors.warning,
        onTap: () => _push(context, TransactionPinScreen(hasExistingPin: context.read<AuthProvider>().member?.hasTxnPin ?? false)),
      )),
      tile(_ServiceTile(
        icon: Icons.laptop_outlined,
        label: 'Active Sessions',
        sub: 'Manage logged-in devices and sessions',
        color: AppColors.blue,
        onTap: () => _push(context, const SessionsScreen()),
      )),

      // Account
      const SizedBox(height: 20),
      _SectionTitle(c, 'Account'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: UniconsLine.user_circle,
        label: 'My Profile',
        sub: 'View and manage your profile',
        color: AppColors.primary,
        onTap: () => _push(context, const ProfileScreen()),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.cog,
        label: 'App Settings',
        sub: 'Biometric login and security preferences',
        color: AppColors.warning,
        onTap: () => _push(context, const AppSettingsScreen()),
      )),

      // Legal
      const SizedBox(height: 20),
      _SectionTitle(c, 'Legal'),
      const SizedBox(height: 10),
      tile(_ServiceTile(
        icon: Icons.privacy_tip_outlined,
        label: 'Privacy Policy',
        sub: 'How we collect, use and protect your data',
        color: AppColors.blue,
        onTap: () => _push(context, const LegalContentScreen(type: 'privacy')),
      )),
      tile(_ServiceTile(
        icon: UniconsLine.file_alt,
        label: 'Terms & Conditions',
        sub: 'The terms governing your membership and use',
        color: AppColors.primary,
        onTap: () => _push(context, const LegalContentScreen(type: 'terms')),
      )),

      // Admin Tools — only visible to ROLE_SYSADMIN
      if (member?.isAdmin == true) ...[
        const SizedBox(height: 20),
        _SectionTitle(c, 'Admin Tools'),
        const SizedBox(height: 10),
        tile(_ServiceTile(
          icon: UniconsLine.setting,
          label: 'Impersonate User',
          sub: 'View the app as any member — fully audited',
          color: AppColors.error,
          onTap: () => _push(context, const ImpersonateScreen()),
        )),
      ],

      // Sign out
      const SizedBox(height: 20),
      tile(_ServiceTile(
        icon: UniconsLine.signout,
        label: 'Sign Out',
        sub: 'Log out of your TMI Staff SACCO account',
        color: AppColors.error,
        onTap: () => _confirmSignOut(context),
      )),

      const SizedBox(height: 32),
    ];
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) context.go('/login');
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, SlideRoute(page: screen));
  }
}

class _MemberStat extends StatelessWidget {
  final String label, value;
  const _MemberStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: const TextStyle(
          color: AppColors.cream, fontWeight: FontWeight.w800, fontSize: 14)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
          color: AppColors.cream.withValues(alpha: 0.65), fontSize: 11)),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  final AppColorScheme c;
  final String text;
  const _SectionTitle(this.c, this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(
      color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8));
}

class _ServiceTile extends StatelessWidget {
  final IconData   icon;
  final String?    iconSvg;
  final String     label;
  final String     sub;
  final Color      color;
  final VoidCallback onTap;
  const _ServiceTile({
    required this.icon, this.iconSvg, required this.label, required this.sub,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border, width: .5),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: iconSvg != null
                ? AppSvgIcon(iconSvg!, color: Colors.white, size: 20)
                : Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ])),
          Icon(UniconsLine.angle_right, color: c.textHint, size: 20),
        ]),
      ),
    );
  }
}
