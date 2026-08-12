import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class FinancialHealthScreen extends StatefulWidget {
  const FinancialHealthScreen({super.key});
  @override State<FinancialHealthScreen> createState() => _FinancialHealthScreenState();
}

class _FinancialHealthScreenState extends State<FinancialHealthScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  Map<String, dynamic>? _healthData;
  Map<String, dynamic>? _scoreData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getFinancialHealth(),
        _api.getCreditScoreHistory(),
      ]);
      if (mounted) setState(() {
        _healthData = results[0];
        _scoreData  = results[1];
        _loading = false;
      });
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
            Expanded(child: Text('Financial Health', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
            IconButton(
              icon: Icon(UniconsLine.sync, color: c.textPrimary),
              onPressed: _load,
            ),
          ]),
        ),
        Expanded(child: _loading
          ? const LoadingStateView()
          : _error != null
              ? ErrorStateView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  color: AppColors.emeraldDeep,
                  onRefresh: _load,
                  child: _buildBody(c),
                ),
        ),
      ])),
    );
  }

  Widget _buildBody(AppColorScheme c) {
    final score   = (_scoreData?['score'] as num?)?.toInt()
        ?? (_healthData!['credit_score'] as num?)?.toInt()
        ?? 0;
    final grade   = (_scoreData?['grade'] as String?)
        ?? (_healthData!['grade'] as String?)
        ?? 'Poor';
    final history = (_scoreData?['history'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        _ScoreRingCard(score: score, grade: grade),
        const SizedBox(height: 16),
        _StatsRow(data: _healthData!, fmt: _fmt),
        const SizedBox(height: 16),
        _BadgesCard(data: _healthData!),
        if ((_healthData!['next_due_date'] as String?) != null) ...[
          const SizedBox(height: 16),
          _NextDueCard(data: _healthData!, fmt: _fmt),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Score History',
              style: TextStyle(
                  color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          ...history.map((h) => _HistoryTile(h: h as Map<String, dynamic>)),
        ],
      ],
    );
  }
}

// ─── Credit Score Ring ───────────────────────────────────────────────────────

class _ScoreRingCard extends StatelessWidget {
  final int score;
  final String grade;
  const _ScoreRingCard({required this.score, required this.grade});

  Color _color() {
    if (score >= 750) return AppColors.emeraldMid;
    if (score >= 600) return AppColors.gold;
    if (score >= 400) return AppColors.gold;
    return AppColors.danger;
  }

  String _description() {
    switch (grade) {
      case 'A':
      case 'Excellent':
        return 'Excellent credit standing. You qualify for premium loan products and lowest interest rates.';
      case 'B':
      case 'Good':
        return 'Good credit standing. You have access to most loan products at competitive rates.';
      case 'C':
      case 'Fair':
        return 'Fair credit standing. Some loan products may have higher rates or require additional guarantors.';
      default:
        return 'Poor credit standing. Please address outstanding obligations to improve your score.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final color = _color();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(children: [
        Text('Credit Score',
            style: TextStyle(
                color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SizedBox(
          width: 180, height: 180,
          child: CustomPaint(
            painter: _RingPainter(score: score, color: color, trackColor: c.cardAlt),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$score',
                    style: TextStyle(
                        color: color, fontSize: 48, fontWeight: FontWeight.w900)),
                Text('/ 1000',
                    style: TextStyle(color: c.textHint, fontSize: 13)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Grade $grade',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        Text(_description(),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.textSecondary, fontSize: 13, height: 1.5)),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int score;
  final Color color;
  final Color trackColor;
  const _RingPainter({required this.score, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx       = size.width / 2;
    final cy       = size.height / 2;
    final r        = (size.width / 2) - 12;
    const sw       = 14.0;
    final start    = -math.pi * 0.75;
    final full     = math.pi * 1.5;
    final progress = (score / 1000).clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      start, full, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      start, full * progress, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.score != score || old.color != color;
}

// ─── Stats Row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat fmt;
  const _StatsRow({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final savings = (data['total_savings'] as num?)?.toDouble() ?? 0;
    final debt    = (data['total_debt'] as num?)?.toDouble() ?? 0;

    return Row(children: [
      Expanded(child: _StatBox('Total Savings', 'UGX ${fmt.format(savings)}', AppColors.emeraldMid)),
      const SizedBox(width: 12),
      Expanded(child: _StatBox('Total Debt', 'UGX ${fmt.format(debt)}', AppColors.danger)),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: c.textHint, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    );
  }
}

// ─── Badges ──────────────────────────────────────────────────────────────────

class _BadgesCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BadgesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final badges = (data['badges'] as List<dynamic>?) ?? [];
    if (badges.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Achievements',
            style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: badges.map<Widget>((b) {
            final label = b['label'] as String? ?? b.toString();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.emeraldDeep,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(UniconsLine.trophy, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ─── Next Due ────────────────────────────────────────────────────────────────

class _NextDueCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat fmt;
  const _NextDueCard({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final due    = data['next_due_date'] as String? ?? '';
    final amount = (data['next_due_amount'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(UniconsLine.calendar_alt, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Next Loan Payment Due',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(due,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ])),
        Text('UGX ${fmt.format(amount)}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Score History ───────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> h;
  const _HistoryTile({required this.h});

  @override
  Widget build(BuildContext context) {
    final c          = context.colors;
    final score      = (h['score'] as num?)?.toInt() ?? 0;
    final reason     = h['reason'] as String? ?? '—';
    final triggeredBy = h['triggered_by'] as String? ?? '—';
    final date       = h['date'] as String? ?? h['created_at'] as String? ?? '—';
    final color      = score >= 750
        ? AppColors.emeraldMid
        : score >= 600
            ? AppColors.gold
            : score >= 400
                ? AppColors.gold
                : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$score',
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reason,
              style: TextStyle(
                  color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text('By: $triggeredBy',
              style: TextStyle(color: c.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(date, style: TextStyle(color: c.textHint, fontSize: 11)),
        ])),
      ]),
    );
  }
}

// ─── Error View ──────────────────────────────────────────────────────────────

