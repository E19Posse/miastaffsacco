import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/support_ticket.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_animations.dart';
import 'package:unicons/unicons.dart';

// ── Deposit Sheet ─────────────────────────────────────────────────────────────

class DepositSheet extends StatefulWidget {
  final DashboardProvider dash;
  final VoidCallback onSuccess;
  const DepositSheet({super.key, required this.dash, required this.onSuccess});
  @override State<DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<DepositSheet> {
  final _api      = ApiService();
  final _amtCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();
  int?  _selectedAccountId;
  bool  _busy = false;
  final _fmt  = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    final unlocked = widget.dash.savings.where((a) => !a.isLocked).toList();
    if (unlocked.isNotEmpty) _selectedAccountId = unlocked.first.id;
  }

  @override
  void dispose() { _amtCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    if (amount == null || amount < 1000) { _snack('Minimum deposit is UGX 1,000'); return; }
    if (_selectedAccountId == null) { _snack('Select an account'); return; }
    setState(() => _busy = true);
    try {
      final res = await _api.depositSavings(
        _selectedAccountId!, amount,
        notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${res['message']}  •  Ref: ${res['reference']}'),
        backgroundColor: AppColors.emeraldDeep,
      ));
    } catch (e) { _snack(ApiService.extractError(e)); }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unlocked = widget.dash.savings.where((a) => !a.isLocked).toList();
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Deposit Savings',
            style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _FormLabel(c, 'Account'), const SizedBox(height: 8),
        _FormDropdown<int>(
          value: _selectedAccountId,
          items: unlocked.map((a) => DropdownMenuItem(
            value: a.id,
            child: Text('${a.accountNumber}  •  UGX ${_fmt.format(a.balance)}'),
          )).toList(),
          onChanged: (v) => setState(() => _selectedAccountId = v),
        ),
        const SizedBox(height: 16),
        _FormLabel(c, 'Amount (UGX)'), const SizedBox(height: 8),
        _FormField(ctrl: _amtCtrl, hint: 'e.g. 50,000',
            keyboardType: TextInputType.number,
            prefix: const Icon(UniconsLine.money_bill, color: AppColors.emeraldDeep)),
        const SizedBox(height: 16),
        _FormLabel(c, 'Notes (optional)'), const SizedBox(height: 8),
        _FormField(ctrl: _noteCtrl, hint: 'e.g. Monthly savings'),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
              shape: const StadiumBorder()),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('Deposit Now', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
          )),
      ]),
    );
  }
}

// ── Repay Sheet ───────────────────────────────────────────────────────────────

class RepaySheet extends StatefulWidget {
  final DashboardProvider dash;
  final VoidCallback onSuccess;
  const RepaySheet({super.key, required this.dash, required this.onSuccess});
  @override State<RepaySheet> createState() => _RepaySheetState();
}

class _RepaySheetState extends State<RepaySheet> {
  final _api     = ApiService();
  final _amtCtrl = TextEditingController();
  int?  _selectedLoanId;
  bool  _busy = false;
  Map<String, dynamic>? _result; // set after successful submission
  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    final active = widget.dash.loans.where((l) => l.status == 'Active').toList();
    if (active.isNotEmpty) _selectedLoanId = active.first.id;
  }

  @override
  void dispose() { _amtCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) { _snack('Enter a valid amount'); return; }
    if (_selectedLoanId == null)       { _snack('Select a loan'); return; }
    final selected = widget.dash.loans
        .where((l) => l.id == _selectedLoanId)
        .firstOrNull;
    if (selected != null && amount > selected.settlementAmount) {
      _snack('Maximum is UGX ${_fmt.format(selected.settlementAmount)} (full settlement incl. interest)');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _api.repayLoan(_selectedLoanId!, amount);
      if (!mounted) return;
      widget.onSuccess(); // refresh dashboard in background
      setState(() { _result = res; _busy = false; });
    } catch (e) {
      _snack(ApiService.extractError(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildResult(context, _result!);
    return _buildForm(context);
  }

  // ── Result view shown after successful submission ─────────────────────────
  Widget _buildResult(BuildContext context, Map<String, dynamic> res) {
    final c          = context.colors;
    final isClosed   = res['status'] == 'Closed';
    final overpayment= res['overpayment'] as Map<String, dynamic>?;
    final newBalance = (res['new_balance'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 28),

        // Animated success check
        SuccessCheck(
          size: 72,
          color: isClosed ? AppColors.emeraldMid : AppColors.emeraldDeep,
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          isClosed ? 'Loan Fully Repaid!' : 'Repayment Received',
          style: TextStyle(
            color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isClosed
              ? 'Congratulations! Your loan has been completely cleared.'
              : 'Your payment has been recorded successfully.',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Details card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.cardAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border, width: .5),
          ),
          child: Column(children: [
            _ResultRow('Reference', res['reference'] as String? ?? '—', c),
            const SizedBox(height: 10),
            _ResultRow(
              'Amount Paid',
              'UGX ${_fmt.format((res['amount_paid'] as num? ?? 0))}',
              c,
            ),
            if (!isClosed) ...[
              const SizedBox(height: 10),
              _ResultRow(
                'Remaining Balance',
                'UGX ${_fmt.format(newBalance)}',
                c,
                valueColor: newBalance > 0 ? AppColors.gold : AppColors.emeraldMid,
              ),
            ],
          ]),
        ),

        // Overpayment notice
        if (overpayment != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (overpayment['credited'] as bool? ?? false)
                  ? AppColors.emeraldMid
                  : AppColors.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                (overpayment['credited'] as bool? ?? false)
                    ? UniconsLine.money_bill
                    : UniconsLine.exclamation_triangle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  (overpayment['credited'] as bool? ?? false)
                      ? 'Overpayment Credited to Savings'
                      : 'Overpayment — Action Required',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (overpayment['credited'] as bool? ?? false)
                      ? 'UGX ${_fmt.format((overpayment['amount'] as num).toDouble())} excess was automatically credited to your savings account (Ref: ${overpayment['reference'] ?? '—'}).'
                      : 'UGX ${_fmt.format((overpayment['amount'] as num).toDouble())} excess could not be credited automatically. Please contact us to arrange a refund.',
                  style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
                ),
              ])),
            ]),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isClosed ? AppColors.emeraldMid : AppColors.emeraldDeep,
              foregroundColor: Colors.white,
              shape: const StadiumBorder()),
            child: Text(isClosed ? 'Done' : 'Close',
                style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  // ── Form view ─────────────────────────────────────────────────────────────
  Widget _buildForm(BuildContext context) {
    final c          = context.colors;
    final activeLoans = widget.dash.loans.where((l) => l.status == 'Active').toList();
    final selected   = activeLoans.firstWhere((l) => l.id == _selectedLoanId,
        orElse: () => activeLoans.first);
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Loan Repayment',
            style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _FormLabel(c, 'Loan'), const SizedBox(height: 8),
        _FormDropdown<int>(
          value: _selectedLoanId,
          items: activeLoans.map((l) => DropdownMenuItem(
            value: l.id,
            child: Text('${l.loanNumber}  •  UGX ${_fmt.format(l.balance)}'),
          )).toList(),
          onChanged: (v) => setState(() => _selectedLoanId = v),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(UniconsLine.info_circle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Principal Balance:  UGX ${_fmt.format(selected.balance)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const SizedBox(width: 24),
              Text(
                'To fully close loan:  UGX ${_fmt.format(selected.settlementAmount)}  '
                '(incl. UGX ${_fmt.format(selected.accruedInterest)} interest)',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _FormLabel(c, 'Repayment Amount (UGX)'), const SizedBox(height: 8),
        _FormField(ctrl: _amtCtrl, hint: 'e.g. 200,000',
            keyboardType: TextInputType.number,
            prefix: const Icon(UniconsLine.money_bill, color: AppColors.gold)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold, foregroundColor: Colors.white,
              shape: const StadiumBorder()),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('Submit Repayment', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
          )),
      ]),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label, value;
  final AppColorScheme c;
  final Color? valueColor;
  const _ResultRow(this.label, this.value, this.c, {this.valueColor});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13)),
      Text(value,  style: TextStyle(
          color: valueColor ?? c.textPrimary,
          fontWeight: FontWeight.w700, fontSize: 13)),
    ],
  );
}

// ── Loan Apply Screen ─────────────────────────────────────────────────────────

class LoanApplyScreen extends StatefulWidget {
  const LoanApplyScreen({super.key});
  @override State<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends State<LoanApplyScreen> {
  final _api      = ApiService();
  final _amtCtrl  = TextEditingController();
  final _termCtrl = TextEditingController();
  final _purpCtrl = TextEditingController();
  final _fmt      = NumberFormat('#,##0', 'en_US');

  List<LoanProduct> _products = [];
  int? _selectedId;
  bool _loading = true, _busy = false;
  String? _loadError;

  // Optional security for the loan.
  final List<Map<String, dynamic>> _collateral = []; // {type, description, value}
  final List<Map<String, dynamic>> _guarantors = []; // {member_number, amount}

  LoanProduct? get _selected => _selectedId == null || _products.isEmpty
      ? null
      : _products.firstWhere((p) => p.id == _selectedId,
          orElse: () => _products.first);

  // Eligibility
  Map<String, dynamic>? _eligibility;
  bool _eligibilityLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _amtCtrl.dispose(); _termCtrl.dispose(); _purpCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final productsFuture    = _api.getLoanProducts().catchError((_) => <dynamic>[]);
      final eligibilityFuture = _api.getLoanEligibility().catchError((_) => <String, dynamic>{});

      final raw = await productsFuture;
      if (!mounted) return;
      setState(() {
        _products = (raw as List<dynamic>)
            .map((e) => LoanProduct.fromJson(e as Map<String, dynamic>))
            .toList();
        if (_products.isNotEmpty) _selectedId = _products.first.id;
        _loading = false;
      });

      final elig = await eligibilityFuture;
      if (!mounted) return;
      setState(() {
        _eligibility        = (elig as Map<String, dynamic>).isNotEmpty ? elig : null;
        _eligibilityLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = ApiService.extractError(e);
        _loading   = false;
        _eligibilityLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    final member = context.read<AuthProvider>().member;
    if (member?.isKycVerified != true) {
      _snack('KYC verification required before applying.'); return;
    }
    final principal = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    final term      = int.tryParse(_termCtrl.text);
    if (_selected == null)                 { _snack('Select a loan product'); return; }
    if (principal == null || principal < 50000) { _snack('Minimum loan is UGX 50,000'); return; }
    if (term == null || term < 1)              { _snack('Enter a valid term in months'); return; }
    if (_purpCtrl.text.trim().length < 10)     { _snack('Purpose needs at least 10 characters'); return; }
    setState(() => _busy = true);
    try {
      final res = await _api.applyLoan(
        productId: _selected!.id, principal: principal,
        termMonths: term, purpose: _purpCtrl.text.trim(),
        collateral: _collateral, guarantors: _guarantors,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${res['message']}  •  ${res['loan_number']}'),
        backgroundColor: AppColors.emeraldMid,
      ));
    } catch (e) { _snack(ApiService.extractError(e)); }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

  Future<void> _addCollateral() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _CollateralSheet(),
    );
    if (res != null) setState(() => _collateral.add(res));
  }

  Future<void> _addGuarantor() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _GuarantorSheet(),
    );
    if (res != null) setState(() => _guarantors.add(res));
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              Expanded(
                child: Text('Apply for Loan',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
            ]),
          ),
          Expanded(
            child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
          : _loadError != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(UniconsLine.exclamation_circle, color: AppColors.danger, size: 48),
                    const SizedBox(height: 12),
                    Text(_loadError!, textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () { setState(() { _loading = true; _loadError = null; _eligibilityLoading = true; }); _load(); },
                      child: const Text('Retry'),
                    ),
                  ]),
                ))
              : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Eligibility Banner ───────────────────────────────────────
                if (!_eligibilityLoading && _eligibility != null)
                  _EligibilityBanner(
                    eligibility: _eligibility!,
                    fmt: _fmt,
                    isDark: isDark,
                  ),
                if (!_eligibilityLoading && _eligibility != null)
                  const SizedBox(height: 20),

                _FormLabel(c, 'Loan Product'), const SizedBox(height: 8),
                _FormDropdown<int>(
                  value: _selectedId,
                  items: _products.map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => setState(() => _selectedId = v),
                ),
                if (_selected != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(UniconsLine.info_circle, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        '${_selected!.interestRate}% p.a.'
                        '${_selected!.minAmount != null ? '  •  Min UGX ${_fmt.format(_selected!.minAmount!)}' : ''}'
                        '${_selected!.maxAmount != null ? '  •  Max UGX ${_fmt.format(_selected!.maxAmount!)}' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      )),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                _FormLabel(c, 'Principal Amount (UGX)'), const SizedBox(height: 8),
                _FormField(ctrl: _amtCtrl, hint: 'e.g. 500,000', keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                _FormLabel(c, 'Term (months)'), const SizedBox(height: 8),
                _FormField(ctrl: _termCtrl, hint: 'e.g. 12', keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                _FormLabel(c, 'Loan Purpose'), const SizedBox(height: 8),
                TextField(
                  controller: _purpCtrl, maxLines: 4,
                  style: TextStyle(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Describe the purpose of the loan...',
                    hintStyle: TextStyle(color: c.textHint),
                    filled: true, fillColor: c.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
                  ),
                ),

                // ── Collateral (optional) ──────────────────────────────────
                const SizedBox(height: 24),
                _SecuritySection(
                  title: 'Collateral',
                  subtitle: 'Pledge assets to secure your loan (optional)',
                  addLabel: 'Add collateral',
                  items: _collateral.map((col) => _SecurityChip(
                    title: col['type'] as String,
                    subtitle: [
                      if ((col['description'] ?? '').toString().isNotEmpty) col['description'],
                      if ((col['value'] ?? 0) != 0) 'UGX ${_fmt.format(col['value'])}',
                    ].whereType<String>().join('  •  '),
                  )).toList(),
                  onAdd: _addCollateral,
                  onRemove: (i) => setState(() => _collateral.removeAt(i)),
                ),

                // ── Guarantors (optional) ──────────────────────────────────
                const SizedBox(height: 20),
                _SecuritySection(
                  title: 'Guarantors',
                  subtitle: 'Add SACCO members who will guarantee this loan (optional)',
                  addLabel: 'Add guarantor',
                  items: _guarantors.map((g) => _SecurityChip(
                    title: 'Member ${g['member_number']}',
                    subtitle: 'Guarantees UGX ${_fmt.format(g['amount'])}',
                  )).toList(),
                  onAdd: _addGuarantor,
                  onRemove: (i) => setState(() => _guarantors.removeAt(i)),
                ),

                const SizedBox(height: 32),
                SizedBox(width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldMid, foregroundColor: Colors.white,
                      shape: const StadiumBorder()),
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text('Submit Application', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                  )),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Loan Eligibility Banner ───────────────────────────────────────────────────

class _EligibilityBanner extends StatelessWidget {
  final Map<String, dynamic> eligibility;
  final NumberFormat         fmt;
  final bool                 isDark;
  const _EligibilityBanner({
    required this.eligibility,
    required this.fmt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c          = context.colors;
    final canApply   = eligibility['can_apply'] as bool? ?? false;
    final maxElig    = (eligibility['max_eligible'] as num?)?.toInt() ?? 0;
    final savings    = (eligibility['total_savings'] as num?)?.toInt() ?? 0;
    final shares     = (eligibility['shares_value'] as num?)?.toInt() ?? 0;
    final loanBal    = (eligibility['active_loan_balance'] as num?)?.toInt() ?? 0;
    final multiplier = (eligibility['multiplier'] as num?)?.toInt() ?? 3;
    final reason     = eligibility['reason'] as String?;

    final color      = canApply ? AppColors.emeraldMid : AppColors.gold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            canApply ? UniconsLine.check_circle : UniconsLine.info_circle,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'You are eligible to borrow',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ]),

        if (canApply) ...[
          const SizedBox(height: 10),
          const Text('Maximum eligible amount',
              style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text('UGX ${fmt.format(maxElig)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.35), height: 1),
          const SizedBox(height: 10),
          Row(children: [
            _EligRow('Savings', 'UGX ${fmt.format(savings)}'),
            _EligRow('Shares', 'UGX ${fmt.format(shares)}'),
            _EligRow('Multiplier', '${multiplier}×'),
          ]),
        ] else ...[
          const SizedBox(height: 8),
          if (reason != null)
            Text(reason,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
          if (loanBal > 0) ...[
            const SizedBox(height: 8),
            Text('Outstanding loan: UGX ${fmt.format(loanBal)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ]),
    );
  }
}

class _EligRow extends StatelessWidget {
  final String label, value;
  const _EligRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Shared form helpers ───────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final AppColorScheme c;
  final String text;
  const _FormLabel(this.c, this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600));
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType keyboardType;
  final Widget? prefix;
  const _FormField({required this.ctrl, required this.hint,
    this.keyboardType = TextInputType.text, this.prefix});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: ctrl, keyboardType: keyboardType,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: c.textHint),
        prefixIcon: prefix,
        filled: true, fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
      ),
    );
  }
}

class _FormDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _FormDropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, isExpanded: true, dropdownColor: c.card,
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          items: items, onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Loan security: collateral / guarantor section ─────────────────────────────

class _SecurityChip {
  final String title, subtitle;
  const _SecurityChip({required this.title, required this.subtitle});
}

class _SecuritySection extends StatelessWidget {
  final String title, subtitle, addLabel;
  final List<_SecurityChip> items;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  const _SecuritySection({
    required this.title, required this.subtitle, required this.addLabel,
    required this.items, required this.onAdd, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(subtitle, style: TextStyle(color: c.textHint, fontSize: 12)),
      const SizedBox(height: 10),
      for (var i = 0; i < items.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(items[i].title, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              if (items[i].subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(items[i].subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ],
            ])),
            IconButton(
              onPressed: () => onRemove(i),
              icon: const Icon(UniconsLine.trash_alt, color: AppColors.danger, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ]),
        ),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(UniconsLine.plus, size: 18),
        label: Text(addLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldMid,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    ]);
  }
}

class _CollateralSheet extends StatefulWidget {
  const _CollateralSheet();
  @override State<_CollateralSheet> createState() => _CollateralSheetState();
}

class _CollateralSheetState extends State<_CollateralSheet> {
  static const _types = ['Property', 'Vehicle', 'Equipment', 'Fixed Deposit', 'Salary Charge', 'Other'];
  String _type = 'Property';
  final _descCtrl = TextEditingController();
  final _valCtrl  = TextEditingController();

  @override
  void dispose() { _descCtrl.dispose(); _valCtrl.dispose(); super.dispose(); }

  void _save() {
    final value = double.tryParse(_valCtrl.text.replaceAll(',', '').trim());
    Navigator.pop(context, {
      'type': _type,
      'description': _descCtrl.text.trim(),
      'value': value ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Add Collateral', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _FormLabel(c, 'Type'), const SizedBox(height: 8),
        _FormDropdown<String>(
          value: _type,
          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _type = v ?? 'Property'),
        ),
        const SizedBox(height: 16),
        _FormLabel(c, 'Description'), const SizedBox(height: 8),
        _FormField(ctrl: _descCtrl, hint: 'e.g. Toyota Premio, plate UAX 123A'),
        const SizedBox(height: 16),
        _FormLabel(c, 'Estimated Value (UGX)'), const SizedBox(height: 8),
        _FormField(ctrl: _valCtrl, hint: 'e.g. 15,000,000', keyboardType: TextInputType.number,
            prefix: const Icon(UniconsLine.money_bill, color: AppColors.emeraldMid)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldMid, foregroundColor: Colors.white,
              shape: const StadiumBorder()),
          child: const Text('Add Collateral', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        )),
      ]),
    );
  }
}

class _GuarantorSheet extends StatefulWidget {
  const _GuarantorSheet();
  @override State<_GuarantorSheet> createState() => _GuarantorSheetState();
}

class _GuarantorSheetState extends State<_GuarantorSheet> {
  final _numCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();

  @override
  void dispose() { _numCtrl.dispose(); _amtCtrl.dispose(); super.dispose(); }

  void _save() {
    final num = _numCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.replaceAll(',', '').trim());
    if (num.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the guarantor member number'), backgroundColor: AppColors.danger));
      return;
    }
    if (amt == null || amt < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the guaranteed amount'), backgroundColor: AppColors.danger));
      return;
    }
    Navigator.pop(context, {'member_number': num, 'amount': amt});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Add Guarantor', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('The guarantor must be a registered SACCO member. We verify the member number when you submit.',
            style: TextStyle(color: c.textHint, fontSize: 12)),
        const SizedBox(height: 20),
        _FormLabel(c, 'Guarantor Member Number'), const SizedBox(height: 8),
        _FormField(ctrl: _numCtrl, hint: 'e.g. MEM-00123',
            prefix: const Icon(UniconsLine.user, color: AppColors.emeraldMid)),
        const SizedBox(height: 16),
        _FormLabel(c, 'Guaranteed Amount (UGX)'), const SizedBox(height: 8),
        _FormField(ctrl: _amtCtrl, hint: 'e.g. 500,000', keyboardType: TextInputType.number,
            prefix: const Icon(UniconsLine.money_bill, color: AppColors.emeraldMid)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldMid, foregroundColor: Colors.white,
              shape: const StadiumBorder()),
          child: const Text('Add Guarantor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        )),
      ]),
    );
  }
}
