import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  Map<String, dynamic>? _data;
  bool   _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getReferralInfo();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied!'), backgroundColor: AppColors.emeraldDeep),
    );
  }

  void _share(String code) {
    Share.share(
      'Join MIA Staff SACCO and start saving smarter!\n\nUse my referral code: $code when registering.\n\nDownload the app and sign up today.',
      subject: 'Join MIA Staff SACCO',
    );
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
              Expanded(child: Text('Refer a Friend', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
              IconButton(icon: Icon(UniconsLine.sync, color: c.textPrimary), onPressed: _load),
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
    final code       = _data?['referral_code']        as String? ?? '—';
    final totalCount = (_data?['total_referrals']      as num?)?.toInt() ?? 0;
    final bonusEarned= ((_data?['total_rewards_earned'] as num?)?.toDouble() ?? 0);
    final rewardEach = ((_data?['reward_per_referral'] as num?)?.toDouble() ?? 0);
    final enabled    = _data?['enabled'] as bool? ?? true;
    final referred   = (_data?['referrals']           as List<dynamic>?) ?? [];

    return RefreshIndicator(
      color: AppColors.emeraldDeep,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          // Hero card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.emeraldDeep, Color(0xFF00A86B)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              const Icon(UniconsLine.user_plus, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              const Text('Your Referral Code',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text(code, style: const TextStyle(
                  color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900,
                  letterSpacing: 6)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ActionBtn(
                  icon: UniconsLine.copy, label: 'Copy Code',
                  onTap: () => _copy(code),
                ),
                const SizedBox(width: 12),
                _ActionBtn(
                  icon: UniconsLine.share_alt, label: 'Share',
                  onTap: () => _share(code),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          if (!enabled) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold, width: 1),
              ),
              child: Row(children: [
                const Icon(UniconsLine.info_circle, color: AppColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'The referral programme is currently paused. Existing rewards still apply.',
                  style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Stats row
          Row(children: [
            Expanded(child: _StatCard(
              icon: UniconsLine.users_alt,
              label: 'Members Referred',
              value: '$totalCount',
              color: AppColors.gold,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: UniconsLine.gift,
              label: 'Bonus Earned',
              value: 'UGX ${_fmt.format(bonusEarned)}',
              color: AppColors.emeraldMid,
            )),
          ]),

          const SizedBox(height: 20),

          // How it works
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('How it works', style: TextStyle(
                  color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              _StepRow('1', 'Share your referral code with a friend', c),
              _StepRow('2', 'They join MIA Staff SACCO using your code', c),
              _StepRow('3',
                  rewardEach > 0
                      ? 'You earn UGX ${_fmt.format(rewardEach)} once they pay their subscription'
                      : 'You earn a bonus once they pay their subscription',
                  c),
            ]),
          ),

          if (referred.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Referred Members',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            ...referred.map((r) {
              final m       = r as Map<String, dynamic>;
              final name    = m['referee_name']?.toString() ?? '—';
              final rawDate = m['created_at']?.toString() ?? '';
              final date    = rawDate.length >= 10 ? rawDate.substring(0, 10) : (rawDate.isEmpty ? '—' : rawDate);
              final paid    = m['status']?.toString() == 'rewarded';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                        color: AppColors.emeraldDeep, shape: BoxShape.circle),
                    child: Center(child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'M',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(
                        color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Joined $date', style: TextStyle(color: c.textHint, fontSize: 11)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: paid ? AppColors.emeraldMid : AppColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(paid ? 'Bonus Paid' : 'Pending',
                        style: TextStyle(
                            color: AppColors.onColor(paid ? AppColors.emeraldMid : AppColors.gold),
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
              );
            }),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _StepRow(String num, String text, AppColorScheme c) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(
        width: 28, height: 28,
        decoration: const BoxDecoration(color: AppColors.emeraldDeep, shape: BoxShape.circle),
        child: Center(child: Text(num,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13))),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: c.textHint, fontSize: 11)),
      ]),
    );
  }
}
