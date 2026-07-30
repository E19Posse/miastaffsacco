import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class CreditScoreScreen extends StatefulWidget {
  const CreditScoreScreen({super.key});
  @override
  State<CreditScoreScreen> createState() => _CreditScoreScreenState();
}

class _CreditScoreScreenState extends State<CreditScoreScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _api.getCreditScoreHistory();
      if (mounted) setState(() { _data = d; _loading = false; });
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
            Expanded(child: Text('Credit Score', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
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
    final d          = _data!;
    final score      = (d['current_score'] as num?)?.toInt() ?? 0;
    final grade      = d['grade'] as String? ?? _gradeFromScore(score);
    final multiplier = (d['multiplier'] as num?)?.toInt() ?? 1;
    final history    = (d['history'] as List<dynamic>?) ?? [];
    final color      = _scoreColor(score);
    final desc       = _gradeDescription(grade);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // Score ring
        Center(
          child: Column(children: [
            SizedBox(
              width: 180, height: 180,
              child: CustomPaint(
                painter: _RingPainter(score: score, color: color),
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
            Text(desc,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(UniconsLine.chart_line, color: color, size: 18),
                const SizedBox(width: 8),
                Text('${multiplier}× Max Loan Multiplier',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 28),

        if (history.isNotEmpty) ...[
          Text('Score History',
              style: TextStyle(
                  color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          ...history.map((h) => _HistoryTile(h: h as Map<String, dynamic>)),
        ] else ...[
          Center(
            child: Text('No score history available.',
                style: TextStyle(color: c.textHint, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 750) return AppColors.emeraldMid;
    if (score >= 600) return AppColors.gold;
    if (score >= 400) return AppColors.gold;
    return AppColors.danger;
  }

  String _gradeFromScore(int score) {
    if (score >= 750) return 'A';
    if (score >= 600) return 'B';
    if (score >= 400) return 'C';
    return 'D';
  }

  String _gradeDescription(String grade) {
    switch (grade) {
      case 'A': return 'Excellent credit standing. You qualify for premium loan products and lowest interest rates.';
      case 'B': return 'Good credit standing. You have access to most loan products at competitive rates.';
      case 'C': return 'Fair credit standing. Some loan products may have higher rates or require additional guarantors.';
      default:  return 'Poor credit standing. Please address outstanding obligations to improve your score.';
    }
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> h;
  const _HistoryTile({required this.h});

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final score = (h['score'] as num?)?.toInt() ?? 0;
    final reason     = h['reason'] as String? ?? '—';
    final triggeredBy = h['triggered_by'] as String? ?? '—';
    final date  = h['date'] as String? ?? h['created_at'] as String? ?? '—';
    final color = score >= 750
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
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$score',
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reason,
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
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

class _RingPainter extends CustomPainter {
  final int score;
  final Color color;
  const _RingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width / 2) - 12;
    const strokeWidth = 14.0;
    final startAngle  = -math.pi * 0.75;
    final sweepFull   = math.pi * 1.5;
    final progress    = (score / 1000).clamp(0.0, 1.0);

    final bgPaint = Paint()
      ..color  = color.withOpacity(0.1)
      ..style  = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;

    final fgPaint = Paint()
      ..color  = color
      ..style  = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, sweepFull, false, bgPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, sweepFull * progress, false, fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.score != score || old.color != color;
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(UniconsLine.info_circle, size: 48, color: AppColors.danger),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: AppColors.emeraldDeep)),
        ),
      ]),
    ),
  );
}
