import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/transaction.dart';
import '../kyc/kyc_screen.dart';
import '../profile/profile_screen.dart';
import '../transactions/transactions_screen.dart';
import '../notifications/notifications_screen.dart';
import '../shared/payment_sheets.dart';
import '../payments/payment_gateway_screen.dart';
import '../payments/pay_screen.dart';
import '../goals/savings_goals_screen.dart';
import '../governance/governance_screen.dart';
import '../challenges/challenges_screen.dart';
import '../member/subscription_fee_screen.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../utils/feature_gate.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/money_text.dart';
import '../../widgets/app_svg_icon.dart';
import '../../widgets/transaction_pin_sheet.dart';
import '../../widgets/verification_badge.dart';
import 'package:unicons/unicons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadAll();
      // Member fields like kyc_status/credit_score/has_txn_pin only live on
      // AuthProvider's cached snapshot, which dashboard refreshes never touch —
      // refresh it here too so banners (KYC approval, subscription fee) and the
      // gold badge update without forcing a logout/login.
      context.read<AuthProvider>().refreshMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final auth     = context.watch<AuthProvider>();
    final dash     = context.watch<DashboardProvider>();
    final fmt      = NumberFormat('#,##0', 'en_US');
    final name      = auth.member?.name.split(' ').first ?? 'Member';
    final initials  = auth.member?.initials ?? 'M';
    final avatarUrl = auth.member?.avatarUrl;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: dash.loading
              ? KeyedSubtree(key: const ValueKey('loading'), child: _LoadingBody(c: c))
              : KeyedSubtree(
                  key: const ValueKey('body'),
                  child: RefreshIndicator(
                    color: AppColors.emeraldDeep,
                    backgroundColor: Colors.white,
                    onRefresh: () => Future.wait([
                      dash.refresh(),
                      context.read<AuthProvider>().refreshMember(),
                    ]),
                    child: _Body(
                      dash: dash,
                      fmt: fmt,
                      name: name,
                      initials: initials,
                      avatarUrl: avatarUrl,
                      memberNumber: auth.member?.memberNumber ?? '—',
                      creditTier: auth.member?.creditTier ?? 'basic',
                      onNotifTap: () => Navigator.push(
                          context, SlideRoute(page: const NotificationsScreen())),
                      onAvatarTap: () => Navigator.push(
                          context, SlideRoute(page: const ProfileScreen())),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Header row: avatar + Karibu greeting + notification bell ─────────────────

class _HomeHeaderRow extends StatelessWidget {
  final String name, initials;
  final String? avatarUrl;
  final DashboardProvider dash;
  final VoidCallback onNotifTap, onAvatarTap;

  const _HomeHeaderRow({
    required this.name, required this.initials, this.avatarUrl,
    required this.dash, required this.onNotifTap, required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      GestureDetector(
        onTap: onAvatarTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: avatarUrl != null ? null : AppColors.emeraldDeep, shape: BoxShape.circle),
          child: ClipOval(
            child: avatarUrl != null
                ? Image.network(avatarUrl!, width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarInitials(initials))
                : _avatarInitials(initials),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('KARIBU', style: TextStyle(color: c.textSecondary,
            fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        Text(name, style: TextStyle(color: c.textPrimary,
            fontSize: 15, fontWeight: FontWeight.w800)),
      ])),
      Stack(clipBehavior: Clip.none, children: [
        GestureDetector(
          onTap: onNotifTap,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: c.card, shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.notifications_outlined, color: c.textPrimary, size: 20),
          ),
        ),
        Positioned(right: -4, top: -4, child: _AnimatedNotifBadge(count: dash.unreadCount)),
      ]),
    ]);
  }

  // Self-contained solid backdrop so this reads fine whether it's shown for
  // "no avatar set" or as the errorBuilder fallback when a set avatar fails
  // to load — the latter sits with the outer circle left transparent (see
  // above), so without its own background the white text would land
  // directly on the page background instead (invisible in light mode).
  Widget _avatarInitials(String initials) => Container(
    color: AppColors.emeraldDeep,
    child: Center(
      child: Text(initials, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
    ),
  );
}

// ── Hero balance card ─────────────────────────────────────────────────────────

class _BalanceHeroCard extends StatefulWidget {
  final DashboardProvider dash;
  final NumberFormat fmt;
  final String memberNumber;
  final String creditTier;
  const _BalanceHeroCard({
    required this.dash, required this.fmt,
    required this.memberNumber, required this.creditTier,
  });

  @override
  State<_BalanceHeroCard> createState() => _BalanceHeroCardState();
}

class _BalanceHeroCardState extends State<_BalanceHeroCard> {
  final _api   = ApiService();
  final _store = StorageService();
  bool _hidden = false;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _store.isBalanceHidden().then((v) {
      if (mounted) setState(() => _hidden = v);
    });
  }

  Future<void> _toggleVisibility() async {
    // Guard against duplicate taps while a PIN sheet is already in flight —
    // without this, rapid/repeated taps (e.g. while waiting on the first tap's
    // visual feedback) stacked multiple PIN sheets on top of each other, which
    // read as the whole toggle being unresponsive.
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      final member = context.read<AuthProvider>().member;
      if (member == null) return;
      if (!member.hasTxnPin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Set a Transaction PIN in Settings to hide your balance.')));
        return;
      }
      final action = _hidden ? 'unhide' : 'hide';
      final entered = await showTransactionPinSheet(context, _api,
          message: 'Enter your transaction PIN to $action your account balance.');
      if (entered == null) return; // cancelled or wrong PIN
      final next = !_hidden;
      await _store.setBalanceHidden(next);
      if (mounted) setState(() => _hidden = next);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dash = widget.dash;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.emeraldDeep,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('AVAILABLE BALANCE', style: TextStyle(
                  color: AppColors.gold.withValues(alpha: 0.9),
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(width: 4),
              InkResponse(
                onTap: _toggleVisibility,
                radius: 20,
                splashColor: Colors.white24,
                highlightColor: Colors.white12,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(_hidden ? UniconsLine.eye_slash : UniconsLine.eye,
                      color: Colors.white70, size: 16),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            dash.loading
                ? Container(height: 36, width: 160, decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)))
                : _hidden
                    ? const Text('UGX •••••••',
                        style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900))
                    : TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: dash.totalSavings),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => MoneyText(
                          amount: v.round(), currency: 'UGX', size: 40, color: Colors.white, fit: true,
                        ),
                      ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: tierChipColor(widget.creditTier), borderRadius: BorderRadius.circular(999)),
            child: Text(widget.creditTier.toUpperCase(), style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ]),
        const SizedBox(height: 20),
        Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.memberNumber, style: const TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('LOAN BALANCE', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
            Text(
                dash.loading ? '—' : (_hidden ? 'UGX •••••' : 'UGX ${widget.fmt.format(dash.totalLoans)}'),
                style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ]),
      ]),
    );
  }
}

// ── Scrollable Body ───────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final DashboardProvider dash;
  final NumberFormat fmt;
  final String name, initials, memberNumber;
  final String? avatarUrl;
  final String creditTier;
  final VoidCallback onNotifTap, onAvatarTap;
  const _Body({
    required this.dash, required this.fmt,
    required this.name, required this.initials, this.avatarUrl,
    required this.memberNumber, required this.creditTier,
    required this.onNotifTap, required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final c          = context.colors;
    final recentTxns = dash.transactions.take(5).toList();
    final dateFmt    = DateFormat('dd MMM');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _HomeHeaderRow(
          name: name, initials: initials, avatarUrl: avatarUrl, dash: dash,
          onNotifTap: onNotifTap, onAvatarTap: onAvatarTap,
        ),
        const SizedBox(height: 20),
        _BalanceHeroCard(
          dash: dash, fmt: fmt, memberNumber: memberNumber, creditTier: creditTier,
        ),
        const SizedBox(height: 20),

        _QuickActionsRow(dash: dash),
        const SizedBox(height: 20),

        const _ApprovalBanner(),
        const _KycBanner(),
        const _SubFeeBanner(),

        if (dash.overdueLoans > 0) ...[
          _OverdueAlert(count: dash.overdueLoans),
          const SizedBox(height: 4),
        ],

        const _ActiveChallengeCard(),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Savings Goals',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())),
              child: const Text('View all',
                  style: TextStyle(
                      color: AppColors.emeraldMid, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SavingsGoalsCircles(),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  SlideRoute(page: const TransactionsScreen())),
              child: const Text('View all',
                  style: TextStyle(
                      color: AppColors.emeraldMid, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (recentTxns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Icon(UniconsLine.receipt, size: 48, color: c.textHint),
                ),
                const SizedBox(height: 10),
                Text('No transactions yet',
                    style: TextStyle(color: c.textSecondary, fontSize: 14)),
              ]),
            ),
          )
        else
          ...recentTxns.asMap().entries.map((e) => StaggerItem(
              index: e.key,
              child: _TxnTile(txn: e.value, fmt: fmt, dateFmt: dateFmt))),
      ],
    );
  }
}

// ── Loading Shimmer ───────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  final AppColorScheme c;
  const _LoadingBody({required this.c});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: c.card,
    highlightColor: c.cardAlt,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (_) => Column(children: [
            Container(width: 58, height: 58, decoration: BoxDecoration(
                color: c.card, borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 6),
            Container(width: 44, height: 10, decoration: BoxDecoration(
                color: c.card, borderRadius: BorderRadius.circular(4))),
          ])),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Container(height: 104, decoration: BoxDecoration(
              color: c.card, borderRadius: BorderRadius.circular(16)))),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 104, decoration: BoxDecoration(
              color: c.card, borderRadius: BorderRadius.circular(16)))),
        ]),
        const SizedBox(height: 28),
        Container(width: 140, height: 16, decoration: BoxDecoration(
            color: c.card, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 12),
        ...List.generate(4, (_) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 70,
          decoration: BoxDecoration(
              color: c.card, borderRadius: BorderRadius.circular(14)),
        )),
      ],
    ),
  );
}

// ── Quick Actions Row ─────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  final DashboardProvider dash;
  const _QuickActionsRow({required this.dash});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionTile(
          iconSvg: AppSvgIcons.deposit, label: 'Deposit', tint: _Tint.emerald,
          onTap: () => Navigator.push(context, SlideRoute(page: const PayScreen())),
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionTile(
          iconSvg: AppSvgIcons.loan, label: 'Loan', tint: _Tint.gold,
          onTap: () => FeatureGate.requireKyc(
            context,
            member: context.read<AuthProvider>().member,
            feature: 'Loan Applications',
            onGranted: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoanApplyScreen())),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionTile(
          iconSvg: AppSvgIcons.vote, label: 'Vote', tint: _Tint.soft,
          onTap: () => Navigator.push(context, SlideRoute(page: const GovernanceScreen())),
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionTile(
          iconSvg: AppSvgIcons.repay, label: 'Repay', tint: _Tint.emerald,
          onTap: () {
            final active = dash.loans.where((l) => l.status == 'Active').toList();
            if (active.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No active loans found.')));
              return;
            }
            Navigator.push(context, SlideRoute(page: PaymentGatewayScreen(
              initialPurpose: 'loan_repayment',
              initialAccountId: active.first.id,
            )));
          },
        )),
      ],
    );
  }
}

enum _Tint { emerald, gold, soft }

class _ActionTile extends StatelessWidget {
  final String iconSvg;
  final String label;
  final _Tint tint;
  final VoidCallback onTap;
  const _ActionTile({required this.iconSvg, required this.label, required this.tint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = switch (tint) {
      _Tint.emerald => AppColors.emeraldMid,
      _Tint.gold    => AppColors.gold,
      _Tint.soft    => AppColors.emeraldDeep,
    };
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 64, maxHeight: 64),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
                child: AppSvgIcon(iconSvg, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(
            color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Active Challenge (pinned gamified savings challenge) ──────────────────────

class _ActiveChallengeCard extends StatefulWidget {
  const _ActiveChallengeCard();
  @override State<_ActiveChallengeCard> createState() => _ActiveChallengeCardState();
}

class _ActiveChallengeCardState extends State<_ActiveChallengeCard> {
  final _api = ApiService();
  Map<String, dynamic>? _challenge;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final items = await _api.getChallenges(filter: 'started');
      if (mounted) setState(() {
        _challenge = items.isNotEmpty ? (items.first as Map).cast<String, dynamic>() : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = _challenge;
    if (_loading || ch == null) return const SizedBox.shrink();

    final fmt    = NumberFormat('#,##0', 'en_US');
    final saved  = (ch['total_saved'] as num?)?.toInt() ?? 0;
    final target = (ch['target_amount'] as num?)?.toInt() ?? 1;
    final pct    = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChallengeDetailScreen(id: ch['id'] as int)));
          _load();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(UniconsLine.trophy, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(ch['name']?.toString() ?? 'Savings Challenge',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
              const Icon(UniconsLine.angle_right, color: Colors.white, size: 18),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct, minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text('UGX ${fmt.format(saved)} of ${fmt.format(target)} saved',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ── Membership Approval Banner ─────────────────────────────────────────────────

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner();

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthProvider>().member;
    if (member == null || !member.isApprovalPending) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(children: [
        Icon(UniconsLine.clock, color: AppColors.warning, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Membership Pending Approval',
              style: TextStyle(
                  color: const Color(0xFF5D3A00), fontSize: 13, fontWeight: FontWeight.w700)),
          Text('You can complete your KYC now. Transactions unlock once staff approve your membership.',
              style: TextStyle(color: const Color(0xFF7B5012), fontSize: 11)),
        ])),
      ]),
    );
  }
}

// ── KYC Banner ────────────────────────────────────────────────────────────────

class _KycBanner extends StatelessWidget {
  const _KycBanner();

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthProvider>().member;
    if (member == null || member.isKycVerified) return const SizedBox.shrink();

    // Mirror the KYC screen's _StatusBanner states (locked > rejected > pending
    // > unverified). Verified is handled by the early-return above.
    final isLocked   = member.kycLocked;
    final isRejected = !isLocked && member.kycStatus == 'Rejected';
    final isPending  = !isLocked && !isRejected && member.kycStatus == 'Pending';

    late final Color bgColor, textColor, subColor, iconColor, borderCol;
    late final IconData icon;
    final String title, subtitle;

    if (isLocked) {
      bgColor = AppColors.error; textColor = Colors.white;
      subColor = Colors.white70; iconColor = Colors.white; borderCol = AppColors.error;
      icon = UniconsLine.lock;
      title = 'KYC Locked';
      subtitle = 'Locked after repeated rejections. Contact the SACCO.';
    } else if (isRejected) {
      bgColor = AppColors.error; textColor = Colors.white;
      subColor = Colors.white70; iconColor = Colors.white; borderCol = AppColors.error;
      icon = UniconsLine.exclamation_triangle;
      title = 'KYC Rejected';
      subtitle = 'Tap to review the notes and resubmit.';
    } else if (isPending) {
      bgColor = const Color(0xFFFFF3E0); textColor = const Color(0xFF5D3A00);
      subColor = const Color(0xFF7B5012); iconColor = AppColors.warning; borderCol = AppColors.warning;
      icon = UniconsLine.clock;
      title = 'KYC Under Review';
      subtitle = 'Your documents are being reviewed.';
    } else {
      bgColor = AppColors.primary; textColor = Colors.white;
      subColor = Colors.white70; iconColor = Colors.white; borderCol = AppColors.primaryDark;
      icon = Icons.verified_user_outlined;
      title = 'Complete KYC Verification';
      subtitle = 'Verify your identity to apply for loans.';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
          context, SlideRoute(page: const KycScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol),
        ),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title,
              style: TextStyle(
                  color: textColor, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: TextStyle(color: subColor, fontSize: 11),
            ),
          ])),
          Icon(UniconsLine.angle_right, color: iconColor, size: 18),
        ]),
      ),
    );
  }
}

// ── Subscription Fee Banner ───────────────────────────────────────────────────

class _SubFeeBanner extends StatelessWidget {
  const _SubFeeBanner();

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthProvider>().member;
    if (member == null || member.subscriptionFeePaid) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
          context, SlideRoute(page: const SubscriptionFeeScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Row(children: [
          const Icon(UniconsLine.exclamation_triangle, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Subscription Fee Pending',
                style: TextStyle(
                    color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('A one-time membership fee is outstanding. Tap to pay now.',
                style: TextStyle(color: Color(0xFF92400E), fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Unpaid',
                style: TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          const Icon(UniconsLine.angle_right, color: Color(0xFFD97706), size: 16),
        ]),
      ),
    );
  }
}

// ── Overdue Alert ─────────────────────────────────────────────────────────────

class _OverdueAlert extends StatelessWidget {
  final int count;
  const _OverdueAlert({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(UniconsLine.exclamation_triangle, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$count overdue loan${count > 1 ? "s" : ""} — immediate attention required.',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

// ── Savings Goals ("Member Circles"-style cards, real data) ──────────────────

class _SavingsGoalsCircles extends StatefulWidget {
  const _SavingsGoalsCircles();
  @override State<_SavingsGoalsCircles> createState() => _SavingsGoalsCirclesState();
}

class _SavingsGoalsCirclesState extends State<_SavingsGoalsCircles> {
  final _api = ApiService();
  List<dynamic> _goals   = [];
  bool          _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await _api.getGoals();
      if (mounted) setState(() { _goals = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return Container(height: 96,
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20)));
    }
    if (_goals.isEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: .5),
          ),
          child: Row(children: [
            Icon(UniconsLine.bookmark, color: c.textPrimary),
            const SizedBox(width: 12),
            Expanded(child: Text('No savings goals yet — tap to create one',
                style: TextStyle(color: c.textSecondary, fontSize: 13))),
          ]),
        ),
      );
    }
    final shown = _goals.take(3).toList();
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.border, width: .5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 112, height: 112,
            child: Stack(alignment: Alignment.center, children: [
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: EdgeInsets.all(i * 17.0),
                  child: _GoalRing(
                    goal: shown[i] as Map<String, dynamic>,
                    color: _ringColors[i % _ringColors.length],
                    trackColor: c.border,
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 22),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < shown.length; i++) ...[
              _GoalLegendRow(
                goal: shown[i] as Map<String, dynamic>,
                color: _ringColors[i % _ringColors.length],
              ),
              if (i != shown.length - 1) const SizedBox(height: 12),
            ],
          ])),
        ]),
      ),
    );
  }

  static const _ringColors = [AppColors.gold, AppColors.emeraldMid, Color(0xFF4FA6FF)];
}

class _GoalRing extends StatelessWidget {
  final Map<String, dynamic> goal;
  final Color color;
  final Color trackColor;
  const _GoalRing({required this.goal, required this.color, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final cur = (goal['current_amount'] as num?)?.toDouble() ?? 0;
    final tgt = (goal['target_amount']  as num?)?.toDouble() ?? 1;
    final pct = (tgt > 0 ? cur / tgt : 0.0).clamp(0.0, 1.0);

    return SizedBox.expand(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: pct),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, value, __) => CircularProgressIndicator(
          value: value <= 0 ? 0.001 : value,
          strokeWidth: 10,
          strokeCap: StrokeCap.round,
          backgroundColor: trackColor,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

class _GoalLegendRow extends StatelessWidget {
  final Map<String, dynamic> goal;
  final Color color;
  const _GoalLegendRow({required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final cur  = (goal['current_amount'] as num?)?.toDouble() ?? 0;
    final tgt  = (goal['target_amount']  as num?)?.toDouble() ?? 1;
    final comp = NumberFormat.compact();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(goal['name'] as String? ?? 'Goal',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text('${comp.format(cur)}/${comp.format(tgt)}',
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(width: 4),
        Text('UGX', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    ]);
  }
}

class _TxnTile extends StatelessWidget {
  final AppTransaction txn;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  const _TxnTile({required this.txn, required this.fmt, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final color = _typeColor(txn.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: _typeIconWidget(txn.type),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(txn.description,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_typeLabel(txn.type),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.w700, letterSpacing: .5)),
              ),
              const SizedBox(width: 6),
              Text(dateFmt.format(txn.date),
                  style: TextStyle(color: c.textHint, fontSize: 11)),
            ]),
          ],
        )),
        const SizedBox(width: 8),
        Text(
          '${txn.isCredit ? '+' : '-'}UGX\n${fmt.format(txn.amount)}',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: txn.isCredit ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w700, fontSize: 12,
            height: 1.3,
          ),
        ),
      ]),
    );
  }

  String _typeLabel(TxnType t) {
    switch (t) {
      case TxnType.savings:  return 'SAVINGS';
      case TxnType.loan:     return 'LOAN';
      case TxnType.payment:  return 'PAYMENT';
      case TxnType.transfer: return 'TRANSFER';
      case TxnType.refund:   return 'REFUND';
      default:               return 'TXN';
    }
  }

  Color _typeColor(TxnType t) {
    switch (t) {
      case TxnType.savings:  return AppColors.primary;
      case TxnType.loan:     return AppColors.blue;
      case TxnType.payment:  return AppColors.warning;
      case TxnType.transfer: return AppColors.success;
      case TxnType.refund:   return AppColors.success;
      default:               return AppColors.primary;
    }
  }

  Widget _typeIconWidget(TxnType t) {
    switch (t) {
      case TxnType.savings:  return const Icon(Icons.savings_outlined, color: Colors.white, size: 20);
      case TxnType.loan:     return const AppSvgIcon(AppSvgIcons.loan, color: Colors.white, size: 20);
      case TxnType.payment:  return const Icon(UniconsLine.credit_card, color: Colors.white, size: 20);
      case TxnType.transfer: return const Icon(UniconsLine.exchange_alt, color: Colors.white, size: 20);
      case TxnType.refund:   return const Icon(UniconsLine.money_withdraw, color: Colors.white, size: 20);
      default:               return const Icon(UniconsLine.receipt, color: Colors.white, size: 20);
    }
  }
}

// ── Animated notification badge ───────────────────────────────────────────────
// transitions.dev badge: slide-in from (-8.2, 12.4) on first appear, dot
// pops in with spring scale+fade+blur and pops out fast when count hits 0.

class _AnimatedNotifBadge extends StatefulWidget {
  final int count;
  const _AnimatedNotifBadge({required this.count});
  @override State<_AnimatedNotifBadge> createState() => _AnimatedNotifBadgeState();
}

class _AnimatedNotifBadgeState extends State<_AnimatedNotifBadge>
    with TickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late AnimationController _dotCtrl;

  static const _slideEase = Cubic(0.22, 1,    0.36, 1);
  static const _popEase   = Cubic(0.34, 1.36, 0.64, 1);
  static const _closeEase = Cubic(0.4,  0,    0.2,  1);

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _dotCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    if (widget.count > 0) {
      _slideCtrl.value = 1.0;
      _dotCtrl.value   = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedNotifBadge old) {
    super.didUpdateWidget(old);
    final open    = widget.count > 0;
    final wasOpen = old.count    > 0;
    if (!wasOpen && open) {
      _slideCtrl.forward(from: 0);
      _dotCtrl.duration = const Duration(milliseconds: 500);
      _dotCtrl.forward(from: 0);
    } else if (wasOpen && !open) {
      _dotCtrl.duration = const Duration(milliseconds: 180);
      _dotCtrl.reverse();
    }
  }

  @override
  void dispose() { _slideCtrl.dispose(); _dotCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideCtrl, _dotCtrl]),
      builder: (_, __) {
        final isForward = _dotCtrl.status != AnimationStatus.reverse;
        final dotCurve  = isForward ? _popEase : _closeEase;
        final dot       = CurvedAnimation(parent: _dotCtrl, curve: dotCurve).value.clamp(0.0, 1.0);
        final blurVal   = (1.0 - _dotCtrl.value) * 2.0;
        final tx        = Tween<Offset>(
          begin: const Offset(-8.2, 12.4),
          end: Offset.zero,
        ).evaluate(CurvedAnimation(parent: _slideCtrl, curve: _slideEase));

        if (dot < 0.01 && widget.count == 0) return const SizedBox.shrink();

        Widget badge = Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          child: Text(
            widget.count > 9 ? '9+' : '${widget.count}',
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        );

        if (blurVal > 0.1) {
          badge = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
            child: badge,
          );
        }

        return Transform.translate(
          offset: tx,
          child: Opacity(
            opacity: dot,
            child: Transform.scale(scale: dot, child: badge),
          ),
        );
      },
    );
  }
}
