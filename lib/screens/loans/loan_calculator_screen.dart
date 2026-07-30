import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});
  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _api           = ApiService();
  final _fmt           = NumberFormat('#,##0', 'en_US');
  final _fmtDec        = NumberFormat('#,##0.00', 'en_US');
  final _formKey       = GlobalKey<FormState>();
  final _principalCtrl = TextEditingController();
  final _rateCtrl      = TextEditingController(text: '2.5');
  final _termCtrl      = TextEditingController(text: '12');

  String  _method    = 'reducing_balance';
  bool    _loading   = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final data = await _api.calculateLoan(
        principal: double.parse(_principalCtrl.text.replaceAll(',', '')),
        rate:      double.parse(_rateCtrl.text),
        term:      int.parse(_termCtrl.text),
        method:    _method,
      );
      setState(() { _result = data; _loading = false; });
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            Expanded(child: Text('Loan Calculator', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Inputs ────────────────────────────────────────────────────
            _Label(c, 'Principal Amount (UGX)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _principalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 5,000,000',
                filled: true, fillColor: c.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v.replaceAll(',', ''));
                if (n == null || n < 100000) return 'Minimum UGX 100,000';
                return null;
              },
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label(c, 'Rate (% per month)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '2.5',
                    filled: true, fillColor: c.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label(c, 'Term (months)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _termCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '12',
                    filled: true, fillColor: c.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 1 || n > 120) return '1–120 months';
                    return null;
                  },
                ),
              ])),
            ]),
            const SizedBox(height: 14),

            _Label(c, 'Repayment Method'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _method,
                  isExpanded: true,
                  dropdownColor: c.card,
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                  items: const [
                    DropdownMenuItem(value: 'reducing_balance', child: Text('Reducing Balance')),
                    DropdownMenuItem(value: 'flat_rate',        child: Text('Flat Rate')),
                  ],
                  onChanged: (v) => setState(() => _method = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldDeep,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder()),
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Calculate',
                        style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],

            // ── Results ───────────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 24),
              Row(children: [
                _SummaryCard(
                  label: 'Monthly',
                  value: 'UGX ${_fmt.format(_result!['monthly_installment'] ?? 0)}',
                  color: AppColors.emeraldDeep,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _SummaryCard(
                  label: 'Total Interest',
                  value: 'UGX ${_fmt.format(_result!['total_interest'] ?? 0)}',
                  color: AppColors.gold,
                  isDark: isDark,
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  const Text('Total Repayable',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('UGX ${_fmt.format(_result!['total_repayable'] ?? 0)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                ]),
              ),

              const SizedBox(height: 24),
              Text('Amortisation Schedule',
                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              _ScheduleTable(
                schedule: (_result!['schedule'] as List<dynamic>? ?? []),
                fmt: _fmtDec,
                c: c,
              ),
            ],

            const SizedBox(height: 32),
          ]),
        ),
        )),
      ])),
    );
  }
}

class _Label extends StatelessWidget {
  final AppColorScheme c;
  final String text;
  const _Label(this.c, this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600));
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final bool   isDark;
  const _SummaryCard({required this.label, required this.value, required this.color, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    ));
  }
}

class _ScheduleTable extends StatelessWidget {
  final List<dynamic>  schedule;
  final NumberFormat   fmt;
  final AppColorScheme c;
  const _ScheduleTable({required this.schedule, required this.fmt, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            _Hdr(c, '#',         flex: 1),
            _Hdr(c, 'Instalment', flex: 3),
            _Hdr(c, 'Principal', flex: 3),
            _Hdr(c, 'Interest',  flex: 3),
            _Hdr(c, 'Balance',   flex: 3),
          ]),
        ),
        Divider(height: 1, color: c.border),
        // Rows
        ...schedule.asMap().entries.map((e) {
          final row   = e.value as Map<String, dynamic>;
          final isOdd = e.key.isOdd;
          return Container(
            color: isOdd ? c.cardAlt : c.card,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              _Cell(c, '${row['period']}',                    flex: 1),
              _Cell(c, fmt.format(row['installment'] ?? 0),  flex: 3),
              _Cell(c, fmt.format(row['principal'] ?? 0),    flex: 3),
              _Cell(c, fmt.format(row['interest'] ?? 0),     flex: 3),
              _Cell(c, fmt.format(row['balance'] ?? 0),      flex: 3),
            ]),
          );
        }),
      ]),
    );
  }
}

class _Hdr extends StatelessWidget {
  final AppColorScheme c;
  final String text;
  final int flex;
  const _Hdr(this.c, this.text, {required this.flex});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text,
        style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

class _Cell extends StatelessWidget {
  final AppColorScheme c;
  final String text;
  final int flex;
  const _Cell(this.c, this.text, {required this.flex});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text,
        style: TextStyle(color: c.textPrimary, fontSize: 10),
        overflow: TextOverflow.ellipsis),
  );
}
