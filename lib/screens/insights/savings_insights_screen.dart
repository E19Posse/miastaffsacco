import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/money_text.dart';
import 'package:unicons/unicons.dart';

/// Savings insights: 6-month deposit vs withdrawal trend, deposit streak,
/// average monthly deposit and a simple 12-month projection.
class SavingsInsightsScreen extends StatefulWidget {
  const SavingsInsightsScreen({super.key});
  @override
  State<SavingsInsightsScreen> createState() => _SavingsInsightsScreenState();
}

class _SavingsInsightsScreenState extends State<SavingsInsightsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _api.getSavingsInsights();
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
            Expanded(child: Text('Savings Insights', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.emeraldDeep, backgroundColor: c.card, onRefresh: _load,
            child: _loading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error, onRetry: _load)
                    : _body(c),
          ),
        ),
      ])),
    );
  }

  Widget _body(AppColorScheme c) {
    final d        = _data!;
    final balance  = (d['current_balance'] as num?)?.toDouble() ?? 0;
    final ytd      = (d['deposits_ytd'] as num?)?.toDouble() ?? 0;
    final avg      = (d['avg_monthly_deposit'] as num?)?.toDouble() ?? 0;
    final streak   = (d['deposit_streak_months'] as num?)?.toInt() ?? 0;
    final proj     = (d['projected_balance_12m'] as num?)?.toDouble() ?? 0;
    final monthly  = (d['monthly'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(children: [
          Expanded(child: _StatCard('Current Balance', balance, AppColors.emeraldDeep, UniconsLine.wallet)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard('Deposits (YTD)', ytd, AppColors.gold, UniconsLine.money_insert)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard('Avg / month', avg, AppColors.emeraldMid, UniconsLine.chart_line)),
          const SizedBox(width: 12),
          Expanded(child: _StreakCard(streak: streak)),
        ]),
        const SizedBox(height: 20),

        // ── Monthly trend chart ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          decoration: BoxDecoration(
            color: c.card, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: .5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('6-Month Trend', style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [
              _legendDot(AppColors.emeraldDeep), Text('  Deposits', style: TextStyle(color: c.textSecondary, fontSize: 11)),
              const SizedBox(width: 14),
              _legendDot(AppColors.danger), Text('  Withdrawals', style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 18),
            SizedBox(height: 180, child: _Chart(monthly: monthly, c: c)),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Projection ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.emeraldDeep, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(UniconsLine.chart_growth, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text('Projected balance in 12 months', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            MoneyText(amount: proj.round(), currency: 'UGX', size: 30, color: Colors.white, fit: true),
            const SizedBox(height: 6),
            const Text('Based on your average monthly deposit. Keep your streak going to beat it!',
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
          ]),
        ),
      ],
    );
  }

  Widget _legendDot(Color color) => Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _Chart extends StatelessWidget {
  final List<dynamic> monthly;
  final AppColorScheme c;
  const _Chart({required this.monthly, required this.c});

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) {
      return Center(child: Text('No activity yet', style: TextStyle(color: c.textHint, fontSize: 13)));
    }
    double maxVal = 1;
    for (final m in monthly) {
      maxVal = [maxVal, (m['deposits'] as num?)?.toDouble() ?? 0, (m['withdrawals'] as num?)?.toDouble() ?? 0]
          .reduce((a, b) => a > b ? a : b);
    }

    return BarChart(BarChartData(
      maxY: maxVal * 1.2,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 22,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(monthly[i]['month']?.toString() ?? '',
                    style: TextStyle(color: c.textHint, fontSize: 10)));
          },
        )),
      ),
      barGroups: [
        for (var i = 0; i < monthly.length; i++)
          BarChartGroupData(x: i, barsSpace: 3, barRods: [
            BarChartRodData(toY: (monthly[i]['deposits'] as num?)?.toDouble() ?? 0,
                color: AppColors.emeraldDeep, width: 9, borderRadius: BorderRadius.circular(3)),
            BarChartRodData(toY: (monthly[i]['withdrawals'] as num?)?.toDouble() ?? 0,
                color: AppColors.danger, width: 9, borderRadius: BorderRadius.circular(3)),
          ]),
      ],
    ));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _StatCard(this.label, this.amount, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border, width: .5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: c.textHint, fontSize: 11)),
        const SizedBox(height: 3),
        MoneyText(amount: amount.round(), currency: 'UGX', size: 17, color: c.textPrimary, fit: true),
      ]),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border, width: .5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
            child: const Icon(UniconsLine.fire, color: Colors.white, size: 18)),
        const SizedBox(height: 10),
        Text('Deposit Streak', style: TextStyle(color: c.textHint, fontSize: 11)),
        const SizedBox(height: 3),
        Text('$streak mo${streak == 1 ? '' : 's'}',
            style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}
