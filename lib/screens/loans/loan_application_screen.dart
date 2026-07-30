import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({super.key});
  @override State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  final _api       = ApiService();
  final _fmt       = NumberFormat('#,##0', 'en_US');
  final _amtCtrl    = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _gNumberCtrl = TextEditingController();
  final _gAmountCtrl = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  List<dynamic> _products   = [];
  Map<String, dynamic>? _eligibility;
  int?   _selectedProductId;
  int    _termMonths = 12;
  bool   _loadingInit = true;
  bool   _submitting  = false;
  String? _error;
  int    _step = 0; // 0=form, 1=review
  final List<Map<String, dynamic>> _guarantors = []; // {member_number, amount}

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _amtCtrl.dispose(); _purposeCtrl.dispose();
    _gNumberCtrl.dispose(); _gAmountCtrl.dispose();
    super.dispose();
  }

  void _addGuarantor() {
    final number = _gNumberCtrl.text.trim();
    final amount = double.tryParse(_gAmountCtrl.text.replaceAll(',', ''));
    if (number.isEmpty) { _snack('Enter the guarantor\'s member number'); return; }
    if (amount == null || amount <= 0) { _snack('Enter the amount to guarantee'); return; }
    if (_guarantors.any((g) => g['member_number'] == number)) {
      _snack('That member is already listed as a guarantor'); return;
    }
    setState(() {
      _guarantors.add({'member_number': number, 'amount': amount});
      _gNumberCtrl.clear();
      _gAmountCtrl.clear();
    });
  }

  Future<void> _load() async {
    setState(() { _loadingInit = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getLoanProducts(),
        _api.getLoanEligibility(),
      ]);
      if (mounted) setState(() {
        _products    = results[0] as List<dynamic>;
        _eligibility = results[1] as Map<String, dynamic>;
        _loadingInit = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loadingInit = false; });
    }
  }

  Map<String, dynamic>? get _selectedProduct =>
      _products.cast<Map<String, dynamic>>().where((p) => p['id'] == _selectedProductId).firstOrNull;

  double get _principal => double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;

  double get _monthlyInstalment {
    final p   = _selectedProduct;
    if (p == null || _principal <= 0 || _termMonths <= 0) return 0;
    final r   = ((p['interest_rate'] as num?)?.toDouble() ?? 0) / 100 / 12;
    if (r == 0) return _principal / _termMonths;
    return _principal * r * (1 + r).pow(_termMonths) / ((1 + r).pow(_termMonths) - 1);
  }

  Future<void> _submit() async {
    if (_selectedProductId == null) { _snack('Select a loan product'); return; }
    if (_principal <= 0) { _snack('Enter a valid amount'); return; }
    if (_purposeCtrl.text.trim().isEmpty) { _snack('Enter loan purpose'); return; }
    setState(() => _submitting = true);
    try {
      final res = await _api.applyLoan(
        productId:   _selectedProductId!,
        principal:   _principal,
        termMonths:  _termMonths,
        purpose:     _purposeCtrl.text.trim(),
        guarantors:  _guarantors,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Application submitted! Ref: ${res['loan_number'] ?? res['reference'] ?? '—'}'),
        backgroundColor: AppColors.emeraldDeep,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      _snack(ApiService.extractError(e));
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

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
                onTap: () => _step == 1 ? setState(() => _step = 0) : Navigator.pop(context),
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LOANS', style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(_step == 0 ? 'Apply for a loan' : 'Review application', style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ])),
            ]),
          ),
          Expanded(
            child: _loadingInit
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : _error != null
                    ? _ErrorRetry(message: _error!, onRetry: _load)
                    : _step == 0 ? _buildForm(c) : _buildReview(c),
          ),
        ]),
      ),
    );
  }

  Widget _buildForm(AppColorScheme c) {
    final elig      = _eligibility;
    final eligible  = elig?['can_apply'] as bool? ?? false;
    final maxAmount = (elig?['max_eligible'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Eligibility banner
        if (elig != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: eligible ? AppColors.emeraldMid : AppColors.danger,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Icon(eligible ? UniconsLine.check_circle : UniconsLine.times_circle,
                  color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(eligible ? 'You are eligible for a loan' : 'Not yet eligible',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                if (eligible && maxAmount > 0)
                  Text('Max: UGX ${_fmt.format(maxAmount)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if (!eligible && elig['reason'] != null)
                  Text(elig['reason'].toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        // Product selection
        Text('Select Loan Product',
            style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        if (_products.isEmpty)
          Text('No loan products available.', style: TextStyle(color: c.textHint))
        else
          ..._products.cast<Map<String, dynamic>>().map((p) {
            final selected = _selectedProductId == p['id'];
            return GestureDetector(
              onTap: () => setState(() => _selectedProductId = p['id'] as int),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? c.borderActive : c.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: const Icon(UniconsLine.university,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name']?.toString() ?? '—',
                        style: TextStyle(
                            color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      '${p['interest_rate']}% p.a. · Max ${p['max_term_months'] ?? '—'} months',
                      style: TextStyle(color: c.textSecondary, fontSize: 11),
                    ),
                  ])),
                  if (selected)
                    const Icon(UniconsLine.check_circle, color: AppColors.emeraldDeep, size: 20),
                ]),
              ),
            );
          }),

        const SizedBox(height: 20),

        // Amount
        Text('Loan Amount (UGX)',
            style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amtCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: c.textPrimary),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final amt = double.tryParse((v ?? '').replaceAll(',', ''));
            if (amt == null || amt <= 0) return 'Enter a valid amount';
            if (eligible && maxAmount > 0 && amt > maxAmount) {
              return 'Exceeds your eligible limit of UGX ${_fmt.format(maxAmount)}';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'e.g. 1000000',
            prefixIcon: Icon(UniconsLine.dollar_alt, color: c.textHint),
            filled: true, fillColor: c.surface,
          ),
        ),

        const SizedBox(height: 16),

        // Term
        Text('Repayment Term',
            style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _termMonths,
              isExpanded: true,
              dropdownColor: c.card,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              items: [3, 6, 12, 18, 24, 36, 48, 60].map((m) =>
                DropdownMenuItem(value: m, child: Text('$m months'))).toList(),
              onChanged: (v) => setState(() => _termMonths = v!),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Monthly estimate
        if (_principal > 0 && _selectedProduct != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.emeraldDeep,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Est. Monthly Instalment',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('UGX ${_fmt.format(_monthlyInstalment)}',
                  style: GoogleFonts.sora(
                      color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Purpose
        Text('Purpose of Loan',
            style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _purposeCtrl,
          maxLines: 3,
          style: TextStyle(color: c.textPrimary),
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter the purpose of the loan' : null,
          decoration: InputDecoration(
            hintText: 'Briefly describe the purpose...',
            filled: true, fillColor: c.surface,
          ),
        ),

        const SizedBox(height: 20),

        // Guarantors (optional)
        Text('Guarantors (optional)',
            style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('Ask fellow SACCO members to guarantee part of this loan by their member number.',
            style: TextStyle(color: c.textHint, fontSize: 11)),
        const SizedBox(height: 10),
        for (final g in _guarantors)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Icon(UniconsLine.user_check, color: c.textHint, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['member_number'].toString(),
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('UGX ${_fmt.format(g['amount'] as double)}',
                    style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ])),
              GestureDetector(
                onTap: () => setState(() => _guarantors.remove(g)),
                child: Icon(UniconsLine.times, color: c.textHint, size: 18),
              ),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _gNumberCtrl,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Member number',
                filled: true, fillColor: c.surface,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _gAmountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Amount',
                filled: true, fillColor: c.surface,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48, width: 48,
            child: ElevatedButton(
              onPressed: _addGuarantor,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldDeep,
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(UniconsLine.plus, color: Colors.white, size: 20),
            ),
          ),
        ]),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: () {
              if (_selectedProductId == null) { _snack('Select a loan product'); return; }
              if (_formKey.currentState!.validate()) setState(() => _step = 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldDeep,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: Text('Review application',
                style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    ),
  );
  }

  Widget _buildReview(AppColorScheme c) {
    final p = _selectedProduct!;

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.emeraldDeep,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LOAN SUMMARY',
                    style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 12),
                Text('UGX ${_fmt.format(_principal)}',
                    style: GoogleFonts.sora(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('$_termMonths months repayment',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 20),
            _ReviewRow(c, 'Loan Product', p['name']?.toString() ?? '—'),
            _ReviewRow(c, 'Interest Rate', '${p['interest_rate']}% per annum'),
            _ReviewRow(c, 'Loan Amount', 'UGX ${_fmt.format(_principal)}'),
            _ReviewRow(c, 'Term', '$_termMonths months'),
            _ReviewRow(c, 'Est. Monthly Payment',
                'UGX ${_fmt.format(_monthlyInstalment)}', highlight: true),
            _ReviewRow(c, 'Purpose', _purposeCtrl.text.trim()),
            if (_guarantors.isNotEmpty)
              _ReviewRow(c, 'Guarantors',
                  _guarantors.map((g) => '${g['member_number']} (UGX ${_fmt.format(g['amount'] as double)})').join(', ')),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(UniconsLine.info_circle, color: c.textHint, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Your application will be reviewed by a loans officer. You will be notified once a decision is made.',
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                )),
              ]),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldDeep,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: _submitting
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('Submit application',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ),
    ]);
  }

  Widget _ReviewRow(AppColorScheme c, String label, String value, {bool highlight = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border, width: 0.5))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13)),
          Flexible(child: Text(value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? AppColors.emeraldMid : c.textPrimary,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                fontSize: highlight ? 15 : 13,
              ))),
        ]),
      );
}

extension on double {
  double pow(int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) result *= this;
    return result;
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(UniconsLine.exclamation_circle, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      Text(message, style: TextStyle(color: context.colors.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: AppColors.emeraldMid))),
    ]),
  );
}
