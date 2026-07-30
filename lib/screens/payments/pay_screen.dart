import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import 'add_cash_flow.dart';
import 'package:unicons/unicons.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Pay / Deposit — cooperative-wallet-styled front end for the existing
//  deposit wizard (add_cash_flow.dart). This screen only decides the amount
//  and channel; account selection, quotes, PIN gating, and confirmation are
//  all handled by the untouched existing flow (SelectMomoAccountScreen →
//  DepositReviewScreen → WaitingConfirmationScreen).
// ════════════════════════════════════════════════════════════════════════════

final _fmt = NumberFormat('#,##0', 'en_US');
const _quickAmounts = [10000, 50000, 100000, 250000];

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});
  @override State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final _ctrl = TextEditingController(text: '50000');
  String _channel = 'mtn';
  int? _selectedAccountId;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  int get _amount => int.tryParse(_ctrl.text.replaceAll(',', '')) ?? 0;

  void _pickQuick(int v) => setState(() => _ctrl.text = v.toString());

  Future<void> _pickAccount(List<dynamic> unlocked) async {
    final c = context.colors;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Align(alignment: Alignment.centerLeft, child: Text('Deposit into',
              style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800))),
        ),
        for (final a in unlocked)
          ListTile(
            title: Text('${a.productName} · ${a.accountNumber}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text('Balance: UGX ${_fmt.format(a.balance)}', style: TextStyle(color: c.textSecondary)),
            onTap: () => Navigator.pop(sheetCtx, a.id as int),
          ),
        const SizedBox(height: 12),
      ])),
    );
    if (picked != null) setState(() => _selectedAccountId = picked);
  }

  void _continue(DashboardProvider dash) {
    final unlocked = dash.savings.where((a) => !a.isLocked).toList();
    if (unlocked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No unlocked savings accounts.')));
      return;
    }
    if (_amount < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Minimum is UGX 1,000'), backgroundColor: AppColors.danger));
      return;
    }
    final acct = unlocked.firstWhere((a) => a.id == _selectedAccountId, orElse: () => unlocked.first);
    final label = '${acct.accountNumber} · UGX ${_fmt.format(acct.balance)}';

    final channel = _channel == 'bank' ? 'bank' : 'momo';
    if (channel == 'bank') {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Bank Transfer'),
        content: const Text('Visit any SACCO branch or use the bank details on your '
            'profile to deposit. Your balance updates once the office confirms receipt.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ));
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => SelectMomoAccountScreen(
      savingsAccountId: acct.id, accountLabel: label, amount: _amount.toDouble(),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dash = context.watch<DashboardProvider>();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(children: [
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
            ]),
            const SizedBox(height: 12),
            Text('DEPOSIT', style: TextStyle(
                color: c.textSecondary,
                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('Deposit to your savings', style: GoogleFonts.sora(
                fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(height: 16),

            Builder(builder: (_) {
              final unlocked = dash.savings.where((a) => !a.isLocked).toList();
              if (unlocked.isEmpty) return const SizedBox.shrink();
              final acct = unlocked.firstWhere((a) => a.id == _selectedAccountId, orElse: () => unlocked.first);
              return GestureDetector(
                onTap: unlocked.length > 1 ? () => _pickAccount(unlocked) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.savings_outlined, color: c.textPrimary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('DEPOSITING INTO', style: TextStyle(
                          color: c.textHint, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      Text('${acct.productName} · ${acct.accountNumber}', style: TextStyle(
                          color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    ])),
                    if (unlocked.length > 1)
                      Icon(UniconsLine.angle_right, color: c.textHint, size: 18),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.emeraldDeep,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(children: [
                Text('You are depositing', style: TextStyle(
                    color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic, children: [
                  Text('UGX ', style: GoogleFonts.sora(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(_fmt.format(_amount), style: GoogleFonts.sora(
                      color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 20),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: _quickAmounts.map((q) {
                  final selected = _amount == q;
                  return GestureDetector(
                    onTap: () => _pickQuick(q),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.gold : AppColors.cream.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('+${(q / 1000).toStringAsFixed(0)}K', style: TextStyle(
                          color: selected ? AppColors.emeraldDeep : AppColors.cream.withValues(alpha: 0.8),
                          fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  );
                }).toList()),
              ]),
            ),
            const SizedBox(height: 20),
            Text('CUSTOM AMOUNT', style: TextStyle(
                color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl, keyboardType: TextInputType.number,
              style: GoogleFonts.sora(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                filled: true, fillColor: c.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),
            Text('PAYMENT CHANNEL', style: TextStyle(
                color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            _ChannelTile(
              logo: Padding(
                padding: const EdgeInsets.all(7),
                child: SvgPicture.asset('assets/images/mtn-logo.svg', fit: BoxFit.contain),
              ),
              tileBg: Colors.white,
              label: 'MTN MoMo', tag: 'Instant',
              selected: _channel == 'mtn', onTap: () => setState(() => _channel = 'mtn'),
            ),
            const SizedBox(height: 8),
            _ChannelTile(
              logo: Padding(
                padding: const EdgeInsets.all(5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/images/airtel-logo.png', fit: BoxFit.contain),
                ),
              ),
              tileBg: Colors.white,
              label: 'Airtel Money', tag: 'Instant',
              selected: _channel == 'airtel', onTap: () => setState(() => _channel = 'airtel'),
            ),
            const SizedBox(height: 8),
            _ChannelTile(
              logo: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 22),
              tileBg: AppColors.emeraldMid,
              label: 'Bank Transfer', tag: '1–2 hrs',
              selected: _channel == 'bank', onTap: () => setState(() => _channel = 'bank'),
            ),
            const SizedBox(height: 28),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldDeep,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              onPressed: () => _continue(dash),
              child: Text('Confirm deposit · UGX ${_fmt.format(_amount)}',
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800)),
            )),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Widget logo;
  final Color tileBg;
  final String label, tag;
  final bool selected;
  final VoidCallback onTap;
  const _ChannelTile({
    required this.logo, required this.tileBg, required this.label, required this.tag,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? c.card : c.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.borderActive : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(14),
              border: tileBg == Colors.white
                  ? Border.all(color: c.border)
                  : null,
            ),
            alignment: Alignment.center,
            child: logo,
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(tag.toUpperCase(), style: TextStyle(
                color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ])),
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.emeraldDeep : Colors.transparent,
              border: selected ? null : Border.all(color: c.border, width: 2),
            ),
            child: selected ? const Icon(UniconsLine.check, color: Colors.white, size: 14) : null,
          ),
        ]),
      ),
    );
  }
}
