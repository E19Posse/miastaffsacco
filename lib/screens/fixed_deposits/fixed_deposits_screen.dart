import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/fixed_deposit.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class FixedDepositsScreen extends StatefulWidget {
  const FixedDepositsScreen({super.key});
  @override State<FixedDepositsScreen> createState() => _FixedDepositsScreenState();
}

class _FixedDepositsScreenState extends State<FixedDepositsScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy');

  List<FixedDeposit> _fds = [];
  bool _loading = true;
  String? _error;

  // local rollover state: fdId → autoRollover
  final Map<int, bool> _rolloverState = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await _api.getFixedDeposits();
      final fds = raw.map((e) => FixedDeposit.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _fds = fds;
        // seed local rollover state from model
        for (final fd in fds) {
          _rolloverState[fd.id] = fd.autoRollover;
        }
      });
    } catch (e) {
      setState(() => _error = ApiService.extractError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleRollover(int fdId, bool newValue) async {
    // optimistic update
    setState(() => _rolloverState[fdId] = newValue);
    try {
      await _api.toggleFdRollover(fdId, newValue);
    } catch (e) {
      // revert on error
      setState(() => _rolloverState[fdId] = !newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.extractError(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
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
            Expanded(child: Text('Fixed Deposits', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(child: RefreshIndicator(
        color: AppColors.emeraldDeep,
        backgroundColor: c.card,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : _fds.isEmpty
                    ? _EmptyView()
                    : _FdList(
                        fds: _fds,
                        fmt: _fmt,
                        dateFmt: _dateFmt,
                        rolloverState: _rolloverState,
                        onToggleRollover: _toggleRollover,
                      ),
        )),
      ])),
    );
  }
}

class _FdList extends StatelessWidget {
  final List<FixedDeposit> fds;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Map<int, bool> rolloverState;
  final void Function(int fdId, bool newValue) onToggleRollover;
  const _FdList({
    required this.fds,
    required this.fmt,
    required this.dateFmt,
    required this.rolloverState,
    required this.onToggleRollover,
  });

  @override
  Widget build(BuildContext context) {
    final totalActive  = fds.where((f) => f.status == 'Active').fold(0.0, (s, f) => s + f.principal);
    final totalAccrued = fds.where((f) => f.status == 'Active').fold(0.0, (s, f) => s + f.accruedInterest);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        _SummaryCard(totalActive: totalActive, totalAccrued: totalAccrued, fmt: fmt),
        const SizedBox(height: 24),
        Text('Your Fixed Deposits',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15, fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 12),
        ...fds.map((fd) => _FdCard(
          fd: fd,
          fmt: fmt,
          dateFmt: dateFmt,
          autoRollover: rolloverState[fd.id] ?? fd.autoRollover,
          onToggleRollover: (v) => onToggleRollover(fd.id, v),
        )),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalActive, totalAccrued;
  final NumberFormat fmt;
  const _SummaryCard({required this.totalActive, required this.totalAccrued, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4F3BB5).withValues(alpha: .9), const Color(0xFF7C3AED)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(UniconsLine.university, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          const Text('Total Invested', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Text('UGX ${fmt.format(totalActive)}',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white24),
        const SizedBox(height: 16),
        Row(children: [
          _Mini(label: 'Accrued Interest', value: 'UGX ${fmt.format(totalAccrued)}', color: const Color(0xFFA78BFA)),
        ]),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Mini({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
    ],
  );
}

class _FdCard extends StatelessWidget {
  final FixedDeposit fd;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final bool autoRollover;
  final ValueChanged<bool> onToggleRollover;
  const _FdCard({
    required this.fd,
    required this.fmt,
    required this.dateFmt,
    required this.autoRollover,
    required this.onToggleRollover,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isActive = fd.status == 'Active';
    final statusColor = fd.isMatured
        ? AppColors.gold
        : isActive ? AppColors.emeraldMid : c.textHint;

    // Maturity countdown
    String? maturityCountdown;
    Color   maturityCountdownColor = c.textSecondary;
    if (fd.maturityDate != null) {
      final now  = DateTime.now();
      final diff = fd.maturityDate!.difference(now).inDays;
      if (fd.isMatured) {
        maturityCountdown      = 'Matured';
        maturityCountdownColor = AppColors.danger;
      } else {
        maturityCountdown = '$diff day${diff == 1 ? '' : 's'} to maturity';
        if (diff <= 30) maturityCountdownColor = AppColors.gold;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fd.productName,
                style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(fd.fdNumber,
                style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'monospace')),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(fd.isMatured ? 'Matured' : fd.status,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        Container(height: 1, color: c.border),
        const SizedBox(height: 14),
        _Row(c: c, label: 'Principal', value: 'UGX ${fmt.format(fd.principal)}', bold: true),
        const SizedBox(height: 8),
        _Row(c: c, label: 'Interest Rate', value: '${fd.interestRate}% p.a.'),
        const SizedBox(height: 8),
        _Row(c: c, label: 'Accrued Interest',
            value: 'UGX ${fmt.format(fd.accruedInterest)}',
            color: AppColors.emeraldMid),
        const SizedBox(height: 8),
        if (fd.startDate != null)
          _Row(c: c, label: 'Start Date', value: dateFmt.format(fd.startDate!)),
        if (fd.maturityDate != null) ...[
          const SizedBox(height: 8),
          _Row(c: c, label: 'Maturity Date',
              value: dateFmt.format(fd.maturityDate!),
              color: fd.isMatured ? AppColors.gold : null),
        ],
        // Maturity countdown
        if (maturityCountdown != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(
              fd.isMatured ? UniconsLine.bookmark : UniconsLine.hourglass,
              size: 14,
              color: maturityCountdownColor,
            ),
            const SizedBox(width: 4),
            Text(maturityCountdown,
                style: TextStyle(
                    color: maturityCountdownColor,
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ],
        const SizedBox(height: 12),
        Container(height: 1, color: c.border),
        const SizedBox(height: 10),
        // Auto-rollover toggle
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Auto Rollover',
                style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Automatically renew on maturity',
                style: TextStyle(color: c.textHint, fontSize: 11)),
          ]),
          Switch(
            value: autoRollover,
            onChanged: onToggleRollover,
            activeColor: AppColors.emeraldDeep,
          ),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final AppColorScheme c;
  final String label, value;
  final bool bold;
  final Color? color;
  const _Row({required this.c, required this.label, required this.value, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
      Text(value, style: TextStyle(
        color: color ?? c.textPrimary,
        fontSize: 13,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      )),
    ],
  );
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(UniconsLine.university, size: 64, color: context.colors.textHint),
      const SizedBox(height: 16),
      Text('No Fixed Deposits',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Visit your branch to open a fixed deposit account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(UniconsLine.info_circle, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      Text('Failed to load', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(message, textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
      const SizedBox(height: 8),
      TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: AppColors.emeraldDeep))),
    ]),
  );
}
