import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/withdrawal_request.dart';
import '../../models/bank_detail.dart';
import '../../models/savings_account.dart';
import '../../models/fixed_deposit.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class WithdrawalRequestsScreen extends StatefulWidget {
  const WithdrawalRequestsScreen({super.key});
  @override State<WithdrawalRequestsScreen> createState() => _WithdrawalRequestsScreenState();
}

class _WithdrawalRequestsScreenState extends State<WithdrawalRequestsScreen> {
  final _api     = ApiService();
  final _fmt     = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy');

  List<WithdrawalRequest> _requests = [];
  List<BankDetail>        _banks    = [];
  List<FixedDeposit>      _fds      = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getWithdrawalRequests(),
        _api.getBankDetails(),
        _api.getFixedDeposits(),
      ]);
      setState(() {
        _requests = results[0]
            .map((e) => WithdrawalRequest.fromJson(e as Map<String, dynamic>))
            .toList();
        _banks = results[1]
            .map((e) => BankDetail.fromJson(e as Map<String, dynamic>))
            .toList();
        // Only Active fixed deposits can be withdrawn.
        _fds = results[2]
            .map((e) => FixedDeposit.fromJson(e as Map<String, dynamic>))
            .where((f) => f.status.toLowerCase() == 'active')
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showNewRequest() {
    final dash = context.read<DashboardProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _NewRequestSheet(
        savings:  dash.savings,
        banks:    _banks,
        fixedDeposits: _fds,
        onSuccess: _load,
        api:      _api,
      ),
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
              Expanded(
                child: Text('Withdrawal Requests',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
              TextButton.icon(
                onPressed: _showNewRequest,
                icon: const Icon(UniconsLine.plus, color: AppColors.emeraldDeep),
                label: Text('New', style: GoogleFonts.sora(color: AppColors.emeraldDeep, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.emeraldDeep,
              backgroundColor: c.card,
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                  : _error != null
                      ? _Error(message: _error!, onRetry: _load)
                      : _requests.isEmpty
                          ? _Empty(onNew: _showNewRequest)
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              children: [
                                ..._requests.map((r) => _ReqCard(req: r, fmt: _fmt, dateFmt: _dateFmt)),
                              ],
                            ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────

class _ReqCard extends StatelessWidget {
  final WithdrawalRequest req;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  const _ReqCard({required this.req, required this.fmt, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (statusColor, statusLabel) = _statusStyle(req.status);
    final timeFmt = DateFormat('dd MMM, HH:mm');
    final hasTrail = req.reviewedBy != null || req.processedBy != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: req.type == 'savings' ? AppColors.emeraldDeep : AppColors.emeraldMid,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                req.type == 'savings' ? UniconsLine.wallet : UniconsLine.university,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(req.type == 'savings' ? 'Savings Withdrawal' : 'FD Withdrawal',
                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
              Text(req.reference,
                  style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'monospace')),
            ]),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor, borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Details ─────────────────────────────────────────────────────────
        if (req.accountOrFdNumber != null)
          _Row(c: c, label: req.type == 'savings' ? 'Account' : 'FD Number',
              value: req.accountOrFdNumber!),
        const SizedBox(height: 6),
        _Row(c: c, label: 'Amount',
            value: req.amount != null ? 'UGX ${fmt.format(req.amount!)}' : 'Full Amount',
            bold: true),
        const SizedBox(height: 6),
        _Row(c: c, label: 'Method', value: _methodLabel(req.method)),
        const SizedBox(height: 6),
        _Row(c: c, label: 'Submitted', value: dateFmt.format(req.createdAt)),

        // ── Audit Trail ─────────────────────────────────────────────────────
        if (hasTrail) ...[
          const SizedBox(height: 12),
          Divider(color: c.border, thickness: .5, height: 1),
          const SizedBox(height: 10),
          Text('Trail', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .5)),
          const SizedBox(height: 8),

          if (req.reviewedBy != null)
            _TrailRow(
              c: c,
              icon: req.isRejected ? UniconsLine.times_circle : UniconsLine.check_circle,
              iconColor: req.isRejected ? AppColors.danger : AppColors.gold,
              label: req.isRejected ? 'Rejected by' : 'Reviewed by',
              name: req.reviewedBy!,
              time: req.reviewedAt != null ? timeFmt.format(req.reviewedAt!) : null,
              note: req.reviewNotes,
            ),

          if (req.processedBy != null) ...[
            if (req.reviewedBy != null) const SizedBox(height: 6),
            _TrailRow(
              c: c,
              icon: UniconsLine.check_circle,
              iconColor: AppColors.emeraldMid,
              label: 'Processed by',
              name: req.processedBy!,
              time: req.processedAt != null ? timeFmt.format(req.processedAt!) : null,
            ),
          ],
        ],
      ]),
    );
  }

  (Color, String) _statusStyle(String status) => switch (status) {
    'approved'  => (AppColors.emeraldMid,  'Approved'),
    'completed' => (AppColors.gold,     'Completed'),
    'rejected'  => (AppColors.danger,    'Rejected'),
    _           => (AppColors.gold,  'Pending'),
  };

  String _methodLabel(String m) => switch (m) {
    'bank_transfer'  => 'Bank Transfer',
    'mobile_money'   => 'Mobile Money',
    _                => 'Cash',
  };
}

class _Row extends StatelessWidget {
  final AppColorScheme c;
  final String label, value;
  final bool bold;
  const _Row({required this.c, required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
      Text(value,  style: TextStyle(color: c.textPrimary, fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
    ],
  );
}

class _TrailRow extends StatelessWidget {
  final AppColorScheme c;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String name;
  final String? time;
  final String? note;
  const _TrailRow({
    required this.c, required this.icon, required this.iconColor,
    required this.label, required this.name, this.time, this.note,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
        const SizedBox(width: 4),
        Expanded(child: Text(name,
            style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis)),
        if (time != null)
          Text(time!, style: TextStyle(color: c.textSecondary, fontSize: 10)),
      ]),
      if (note != null && note!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 18, top: 3),
          child: Text(note!,
              style: TextStyle(color: c.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
        ),
    ],
  );
}

// ── New Request Sheet ─────────────────────────────────────────────────────────

class _NewRequestSheet extends StatefulWidget {
  final List<SavingsAccount> savings;
  final List<BankDetail>     banks;
  final List<FixedDeposit>   fixedDeposits;
  final VoidCallback         onSuccess;
  final ApiService           api;
  const _NewRequestSheet({
    required this.savings, required this.banks, required this.fixedDeposits,
    required this.onSuccess, required this.api,
  });
  @override State<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends State<_NewRequestSheet> {
  final _fmt        = NumberFormat('#,##0', 'en_US');
  final _formKey    = GlobalKey<FormState>();
  final _amtCtrl    = TextEditingController();
  final _noteCtrl   = TextEditingController();
  final _mobileCtrl = TextEditingController();

  String  _type      = 'savings'; // savings | fd
  late String _method;
  int?    _accountId;
  int?    _fdId;
  int?    _bankId;
  bool    _busy      = false;

  @override
  void initState() {
    super.initState();
    // Default to cash if no bank details are saved; otherwise bank_transfer
    _method = widget.banks.isNotEmpty ? 'bank_transfer' : 'cash';
    if (widget.savings.isNotEmpty) _accountId = widget.savings.first.id;
    if (widget.fixedDeposits.isNotEmpty) _fdId = widget.fixedDeposits.first.id;
    if (widget.banks.isNotEmpty) {
      final primary = widget.banks.where((b) => b.isPrimary).firstOrNull;
      _bankId = primary?.id ?? widget.banks.first.id;
    }
  }

  @override
  void dispose() { _amtCtrl.dispose(); _noteCtrl.dispose(); _mobileCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    if (amount == null || amount < 1000) {
      _snack('Minimum withdrawal amount is UGX 1,000'); return;
    }
    if (_type == 'savings' && _accountId == null) {
      _snack('Please select a savings account'); return;
    }
    if (_type == 'fd' && _fdId == null) {
      _snack('Please select a fixed deposit to withdraw'); return;
    }
    // Guard against requesting more than the available balance
    if (_type == 'savings' && _accountId != null) {
      final acct = widget.savings.where((a) => a.id == _accountId).firstOrNull;
      if (acct != null && amount > acct.balance) {
        final fmt = NumberFormat('#,##0', 'en_US');
        _snack('Amount exceeds available balance of UGX ${fmt.format(acct.balance)}'); return;
      }
    }
    if (_method == 'bank_transfer' && widget.banks.isNotEmpty && _bankId == null) {
      _snack('Please select a bank account for transfer'); return;
    }
    if (_method == 'bank_transfer' && widget.banks.isEmpty) {
      _snack('No bank account saved. Please choose Mobile Money or Cash at Branch.'); return;
    }

    setState(() => _busy = true);
    try {
      Map<String, dynamic> payload = {
        'amount': amount,
        'method': _method,
        if (_method == 'bank_transfer' && _bankId != null) 'member_bank_detail_id': _bankId,
        if (_method == 'mobile_money' && _mobileCtrl.text.trim().isNotEmpty) 'mobile_money_number': _mobileCtrl.text.trim(),
        if (_noteCtrl.text.trim().isNotEmpty) 'member_notes': _noteCtrl.text.trim(),
      };

      Map<String, dynamic> res;
      if (_type == 'savings') {
        payload['savings_account_id'] = _accountId;
        res = await widget.api.submitSavingsWithdrawal(payload);
      } else {
        // FD withdrawal requires the fixed_deposit_id and a maturity-aware type:
        // a matured FD is a 'full' withdrawal; withdrawing before maturity is 'premature'.
        final fd = widget.fixedDeposits.where((f) => f.id == _fdId).firstOrNull;
        payload['fixed_deposit_id'] = _fdId;
        payload['type'] = (fd?.isMatured ?? false) ? 'full' : 'premature';
        res = await widget.api.submitFdWithdrawal(payload);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${res['message']}  •  Ref: ${res['reference']}'),
        backgroundColor: AppColors.emeraldDeep,
      ));
    } catch (e) {
      _snack(ApiService.extractError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('New Withdrawal Request',
              style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Type toggle
          Text('Withdrawal Type', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            _TypeBtn(label: 'Savings', active: _type == 'savings', onTap: () => setState(() => _type = 'savings')),
            const SizedBox(width: 10),
            _TypeBtn(label: 'Fixed Deposit', active: _type == 'fd', onTap: () => setState(() => _type = 'fd')),
          ]),
          const SizedBox(height: 16),

          if (_type == 'savings' && widget.savings.isNotEmpty) ...[
            Text('Account', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _Dropdown<int>(
              value: _accountId,
              items: widget.savings.map((a) => DropdownMenuItem(
                value: a.id,
                child: Text('${a.accountNumber}  •  UGX ${_fmt.format(a.balance)}'),
              )).toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
          ],

          if (_type == 'fd') ...[
            Text('Fixed Deposit', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (widget.fixedDeposits.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                child: const Text('You have no active fixed deposits to withdraw.',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              )
            else ...[
              _Dropdown<int>(
                value: _fdId,
                items: widget.fixedDeposits.map((f) => DropdownMenuItem(
                  value: f.id,
                  child: Text('${f.fdNumber}  •  UGX ${_fmt.format(f.principal)}'
                      '${f.isMatured ? "  • matured" : "  • early"}'),
                )).toList(),
                onChanged: (v) => setState(() => _fdId = v),
              ),
              const SizedBox(height: 16),
            ],
          ],

          Text('Amount (UGX)', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _TextField(
            ctrl: _amtCtrl,
            hint: 'e.g. 100,000',
            keyboardType: TextInputType.number,
            validator: (v) {
              final amt = double.tryParse((v ?? '').replaceAll(',', ''));
              if (amt == null || amt < 1000) return 'Minimum withdrawal is UGX 1,000';
              if (_type == 'savings' && _accountId != null) {
                final acct = widget.savings.where((a) => a.id == _accountId).firstOrNull;
                if (acct != null && amt > acct.balance) {
                  return 'Exceeds balance of UGX ${_fmt.format(acct.balance)}';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          Text('Payout Method', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _Dropdown<String>(
            value: _method,
            items: const [
              DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'mobile_money',  child: Text('Mobile Money')),
              DropdownMenuItem(value: 'cash',          child: Text('Cash at Branch')),
            ],
            onChanged: (v) => setState(() => _method = v!),
          ),
          const SizedBox(height: 16),

          if (_method == 'bank_transfer') ...[
            if (widget.banks.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(UniconsLine.info_circle, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'No bank account saved. Add one in More → My Profile, or choose a different payout method.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  )),
                ]),
              ),
            ] else ...[
              Text('Bank Account', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _Dropdown<int>(
                value: _bankId,
                items: widget.banks.map((b) => DropdownMenuItem(
                  value: b.id,
                  child: Text('${b.bankName} – ${b.accountNumber}'),
                )).toList(),
                onChanged: (v) => setState(() => _bankId = v),
              ),
              const SizedBox(height: 16),
            ],
          ],

          if (_method == 'mobile_money') ...[
            Text('Mobile Money Number', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _TextField(
              ctrl: _mobileCtrl,
              hint: 'e.g. 0712345678',
              keyboardType: TextInputType.phone,
              validator: (v) {
                final n = v?.trim() ?? '';
                if (n.isEmpty) return 'Enter your mobile money number';
                if (!RegExp(r'^0[0-9]{9}$').hasMatch(n)) return 'Enter a valid 10-digit number (e.g. 0712345678)';
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          Text('Notes (optional)', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _TextField(ctrl: _noteCtrl, hint: 'Reason for withdrawal'),
          const SizedBox(height: 24),

          SizedBox(width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldDeep,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Submit Request', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ]),
      ),
    ),
  );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: active ? AppColors.emeraldDeep : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: active ? AppColors.emeraldDeep : context.colors.border),
      ),
      child: Text(label, style: TextStyle(
        color: active ? Colors.white : context.colors.textSecondary,
        fontWeight: FontWeight.w700, fontSize: 13,
      )),
    ),
  );
}

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, isExpanded: true,
          dropdownColor: c.card,
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController? ctrl;
  final String hint;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  const _TextField({this.ctrl, required this.hint, this.keyboardType = TextInputType.text, this.validator});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: c.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textHint),
        filled: true, fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onNew;
  const _Empty({required this.onNew});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(UniconsLine.exchange_alt, size: 64, color: context.colors.textHint),
      const SizedBox(height: 16),
      Text('No Withdrawal Requests',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Submit a request to withdraw from your savings or fixed deposit.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onNew,
        icon: const Icon(UniconsLine.plus, size: 18),
        label: Text('New Request', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
      ),
    ]),
  );
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(UniconsLine.info_circle, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      Text('Failed to load', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: AppColors.emeraldDeep))),
    ]),
  );
}
