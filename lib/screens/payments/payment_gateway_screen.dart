import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/transaction_pin_sheet.dart';
import 'package:unicons/unicons.dart';

// ── Gateway metadata ──────────────────────────────────────────────────────────

class _Gateway {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool requiresPhone;
  final String? svgAsset;
  final String? pngAsset;
  const _Gateway({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.requiresPhone = false,
    this.svgAsset,
    this.pngAsset,
  });
}

const _gateways = [
  _Gateway(
    id: 'mtn_momo', label: 'MTN MoMo', subtitle: '~1% fee',
    icon: UniconsLine.mobile_android, color: Color(0xFFFFC300), requiresPhone: true,
    svgAsset: 'assets/images/mtn-logo.svg',
  ),
  _Gateway(
    id: 'airtel_money', label: 'Airtel Money', subtitle: '~1% fee',
    icon: UniconsLine.mobile_android, color: Color(0xFFE3000B), requiresPhone: true,
    pngAsset: 'assets/images/airtel-logo.png',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class PaymentGatewayScreen extends StatefulWidget {
  final String? initialPurpose;   // savings_deposit | loan_repayment | subscription_fee | share_purchase
  final int?    initialAccountId; // pre-select account or loan
  final double? fixedAmount;      // when set, the amount field is prefilled and locked
  final bool    lockPurpose;      // when true, hide the purpose toggle + account selector
  const PaymentGatewayScreen({
    super.key,
    this.initialPurpose,
    this.initialAccountId,
    this.fixedAmount,
    this.lockPurpose = false,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  final _api     = ApiService();
  final _amtCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _fmt     = NumberFormat('#,##0', 'en_US');

  late String _purpose;
  String?     _provider;
  int?        _selectedId;   // savings_account_id or loan_id
  bool        _busy = false;

  // Result after submission
  Map<String, dynamic>? _result;
  Timer? _pollTimer;
  bool   _failedDialogShown = false;

  // Purposes that don't target a specific savings account / loan.
  bool get _isStandalone => _purpose == 'subscription_fee' || _purpose == 'share_purchase';

  @override
  void initState() {
    super.initState();
    _purpose    = widget.initialPurpose ?? 'savings_deposit';
    _selectedId = widget.initialAccountId;
    if (widget.fixedAmount != null) {
      _amtCtrl.text = _fmt.format(widget.fixedAmount);
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _telCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    if (amount == null || amount < 1000) {
      _snack('Minimum amount is UGX 1,000'); return;
    }
    if (!_isStandalone && _selectedId == null) {
      _snack(_purpose == 'savings_deposit' ? 'Select a savings account' : 'Select a loan'); return;
    }
    if (_provider == null) { _snack('Choose a payment gateway'); return; }

    final gw = _gateways.firstWhere((g) => g.id == _provider);
    if (gw.requiresPhone && _telCtrl.text.trim().isEmpty) {
      _snack('Enter your ${gw.label} phone number'); return;
    }

    // Transaction-PIN gate (server-driven via member.require_txn_pin). Prompt for
    // and verify the PIN up-front so it travels on the single initiate call.
    String pin = '';
    final authProvider = context.read<AuthProvider>();
    var member = authProvider.member;
    if (member != null && member.requireTxnPin && !member.hasTxnPin) {
      // The cached member snapshot can be stale (e.g. the PIN was set in an
      // earlier session) — re-check with the server before blocking the user.
      await authProvider.refreshMember();
      member = authProvider.member;
    }
    if (member != null && member.requireTxnPin) {
      if (!member.hasTxnPin) {
        _snack('Set a Transaction PIN in Settings before making payments.');
        return;
      }
      final entered = await showTransactionPinSheet(context, _api);
      if (entered == null) return; // cancelled
      pin = entered;
    }

    setState(() { _busy = true; _result = null; _failedDialogShown = false; });

    try {
      final res = await _api.initiateGatewayPayment(
        purpose:          _purpose,
        provider:         _provider!,
        amount:           amount,
        phone:            gw.requiresPhone ? _telCtrl.text.trim() : null,
        loanId:           _purpose == 'loan_repayment'   ? _selectedId : null,
        savingsAccountId: _purpose == 'savings_deposit'  ? _selectedId : null,
        pin:              pin,
      );

      if (!mounted) return;

      setState(() { _result = res; });

      // Mobile money: start polling every 5 s for the push-to-pay approval.
      _startPolling(res['reference'] as String);
    } catch (e) {
      if (mounted) {
        final msg = ApiService.extractError(e);
        setState(() { _result = {'status': 'failed', 'message': msg}; });
        _maybeShowFailedDialog(msg, null);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Payment failures must be surfaced with a modal the member has to actively
  /// dismiss — an inline red card alone is too easy to miss on a payment
  /// screen, especially once they've navigated away and back mid-poll.
  void _maybeShowFailedDialog(String message, String? reference) {
    if (_failedDialogShown) return;
    _failedDialogShown = true;
    AppDialogs.showPaymentFailed(
      context,
      message: message,
      reference: reference,
      onRetry: () => setState(() { _result = null; }),
    );
  }

  void _startPolling(String ref) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final status = await _api.checkPaymentStatus(ref);
        if (!mounted) { _pollTimer?.cancel(); return; }
        final s = status['status'] as String? ?? '';
        setState(() => _result = {...?_result, ...status});
        if (s == 'completed' || s == 'failed' || s == 'reversed') {
          _pollTimer?.cancel();
          if (s == 'completed') {
            context.read<DashboardProvider>().refresh();
          } else {
            _maybeShowFailedDialog(
              _result?['message'] as String? ?? _result?['failure_reason'] as String? ?? 'Payment could not be completed.',
              _result?['reference'] as String?,
            );
          }
        }
      } catch (_) {}
    });
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final dash    = context.watch<DashboardProvider>();

    final savings = dash.savings.where((a) => !a.isLocked).toList();
    final loans   = dash.loans.where((l) => l.status == 'Active').toList();

    final title = _purpose == 'subscription_fee'
        ? 'Subscription fee'
        : _purpose == 'share_purchase'
            ? 'Buy shares'
            : 'Payment gateway';

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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PAYMENTS', style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(title, style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ])),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Purpose toggle + account selector (deposits / repayments only) ──
          if (!widget.lockPurpose && !_isStandalone) ...[
            _SectionLabel(c, 'What would you like to pay for?'),
            const SizedBox(height: 10),
            _PurposeToggle(
              value: _purpose,
              onChanged: (v) => setState(() { _purpose = v; _selectedId = null; }),
            ),
            const SizedBox(height: 20),

            _SectionLabel(c, _purpose == 'savings_deposit' ? 'Savings Account' : 'Loan'),
            const SizedBox(height: 10),
            if (_purpose == 'savings_deposit') ...[
              if (savings.isEmpty)
                _EmptyHint(c, 'No unlocked savings accounts available.')
              else
                _Dropdown<int>(
                  value: _selectedId,
                  hint: 'Select account',
                  items: savings.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.accountNumber}  •  UGX ${_fmt.format(a.balance)}'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedId = v),
                ),
            ] else ...[
              if (loans.isEmpty)
                _EmptyHint(c, 'No active loans to repay.')
              else
                _Dropdown<int>(
                  value: _selectedId,
                  hint: 'Select loan',
                  items: loans.map((l) => DropdownMenuItem(
                    value: l.id,
                    child: Text('${l.loanNumber}  •  UGX ${_fmt.format(l.balance)} due'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedId = v),
                ),
            ],
            const SizedBox(height: 20),
          ],

          // ── Standalone purpose banner (subscription / shares) ──────────────
          if (_isStandalone) ...[
            _InfoChip(c, isDark,
                _purpose == 'subscription_fee' ? UniconsLine.bill : UniconsLine.chart_bar,
                AppColors.gold,
                _purpose == 'subscription_fee'
                    ? 'Pay your one-time membership subscription fee online.'
                    : 'Buy share capital online. Units are allocated once payment completes.'),
            const SizedBox(height: 20),
          ],

          // ── Amount ─────────────────────────────────────────────────────────
          _SectionLabel(c, 'Amount (UGX)'),
          const SizedBox(height: 10),
          _InputField(
            ctrl: _amtCtrl,
            hint: 'e.g. 100,000',
            keyboardType: TextInputType.number,
            readOnly: widget.fixedAmount != null,
            prefix: Icon(UniconsLine.money_bill, color: c.textHint, size: 20),
          ),
          const SizedBox(height: 24),

          // ── Gateway selection ──────────────────────────────────────────────
          _SectionLabel(c, 'Pay via'),
          const SizedBox(height: 12),
          Row(children: _gateways.map((g) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _GatewayCard(
                gateway: g,
                selected: _provider == g.id,
                isDark: isDark,
                onTap: () => setState(() => _provider = g.id),
              ),
            ),
          )).toList()),
          const SizedBox(height: 16),

          // ── Phone input (mobile money only) ────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _provider != null &&
                    _gateways.firstWhere((g) => g.id == _provider).requiresPhone
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _SectionLabel(c, 'Mobile Money Phone Number'),
                    const SizedBox(height: 10),
                    _InputField(
                      ctrl: _telCtrl,
                      hint: 'e.g. 0771234567',
                      keyboardType: TextInputType.phone,
                      prefix: Icon(UniconsLine.mobile_android, color: c.textHint, size: 20),
                    ),
                    const SizedBox(height: 16),
                  ])
                : const SizedBox.shrink(),
          ),

          // ── Gateway info chip ──────────────────────────────────────────────
          if (_provider == 'mtn_momo')
            _InfoChip(c, isDark, UniconsLine.mobile_android, const Color(0xFFFFC300),
                'You will receive an MTN MoMo prompt. Enter your PIN to approve.'),
          if (_provider == 'airtel_money')
            _InfoChip(c, isDark, UniconsLine.mobile_android, const Color(0xFFE3000B),
                'You will receive an Airtel Money prompt. Enter your PIN to approve.'),
          const SizedBox(height: 24),

          // ── Submit button ──────────────────────────────────────────────────
          if (_result == null)
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldDeep,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: _busy
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Pay now', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),

          // ── Result card ────────────────────────────────────────────────────
          if (_result != null)
            _ResultCard(
              result: _result!,
              isDark: isDark,
              purpose: _purpose,
              onCheckStatus: () async {
                final ref = _result!['reference'] as String?;
                if (ref == null) return;
                setState(() => _busy = true);
                try {
                  final s = await _api.checkPaymentStatus(ref);
                  if (!mounted) return;
                  setState(() => _result = {...?_result, ...s});
                  final status = s['status'] as String?;
                  if (status == 'completed') {
                    context.read<DashboardProvider>().refresh();
                  } else if (status == 'failed' || status == 'reversed') {
                    _maybeShowFailedDialog(
                      _result?['message'] as String? ?? _result?['failure_reason'] as String? ?? 'Payment could not be completed.',
                      ref,
                    );
                  }
                } catch (e) { _snack(ApiService.extractError(e)); }
                if (mounted) setState(() => _busy = false);
              },
              onPayAgain: () => setState(() { _result = null; }),
              busy: _busy,
            ),
        ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Purpose toggle ────────────────────────────────────────────────────────────

class _PurposeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _PurposeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _PurposeBtn(
        label: 'Savings Deposit', icon: UniconsLine.card_atm,
        color: AppColors.emeraldDeep,
        active: value == 'savings_deposit',
        onTap: () => onChanged('savings_deposit'),
      )),
      const SizedBox(width: 10),
      Expanded(child: _PurposeBtn(
        label: 'Loan Repayment', icon: UniconsLine.receipt,
        color: AppColors.gold,
        active: value == 'loan_repayment',
        onTap: () => onChanged('loan_repayment'),
      )),
    ]);
  }
}

class _PurposeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _PurposeBtn({required this.label, required this.icon, required this.color,
      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color, width: active ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: active ? Colors.white : color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
            style: TextStyle(
              color: active ? Colors.white : color,
              fontSize: 12, fontWeight: FontWeight.w700),
          )),
        ]),
      ),
    );
  }
}

// ── Gateway card ──────────────────────────────────────────────────────────────

class _GatewayCard extends StatelessWidget {
  final _Gateway gateway;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _GatewayCard({required this.gateway, required this.selected,
      required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          // Solid surface always — selection is shown by the solid brand border
          // and label colour, never a tinted/alpha wash.
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? gateway.color : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 38,
            child: gateway.svgAsset != null
                ? SvgPicture.asset(gateway.svgAsset!, height: 32, fit: BoxFit.contain)
                : gateway.pngAsset != null
                    ? Image.asset(gateway.pngAsset!, height: 32, fit: BoxFit.contain)
                    : Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: gateway.color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(gateway.icon, color: Colors.white, size: 18),
                      ),
          ),
          const SizedBox(height: 6),
          Text(gateway.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? gateway.color : c.textPrimary,
              fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(gateway.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textHint, fontSize: 9)),
        ]),
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final bool isDark;
  final String purpose;
  final VoidCallback onCheckStatus;
  final VoidCallback onPayAgain;
  final bool busy;
  const _ResultCard({required this.result, required this.isDark, required this.purpose,
      required this.onCheckStatus, required this.onPayAgain, required this.busy});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final fmt    = NumberFormat('#,##0', 'en_US');
    final status = (result['status'] as String? ?? '').toLowerCase();
    final ref    = result['reference'] as String? ?? '';

    final isCompleted  = status == 'completed';
    final isFailed     = status == 'failed' || status == 'reversed';
    final isProcessing = !isCompleted && !isFailed;

    final statusColor = isCompleted ? AppColors.emeraldMid
        : isFailed ? AppColors.danger : AppColors.gold;
    final statusIcon  = isCompleted ? UniconsLine.check_circle
        : isFailed ? UniconsLine.times_circle : UniconsLine.hourglass;
    final statusLabel = isCompleted ? 'Payment Completed'
        : isFailed ? 'Payment Failed' : 'Processing…';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(statusIcon, color: statusColor, size: 26),
          const SizedBox(width: 10),
          Text(statusLabel,
            style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        _Row(c, 'Reference', ref),
        if (result['provider'] != null)
          _Row(c, 'Gateway', (result['provider'] as String).replaceAll('_', ' ').toUpperCase()),
        if (result['amount'] != null)
          _Row(c, 'Amount', 'UGX ${fmt.format(result['amount'])}'),
        if (result['fee'] != null && (result['fee'] as num) > 0)
          _Row(c, 'Fee', 'UGX ${fmt.format(result['fee'])}'),
        if (result['message'] != null) ...[
          const SizedBox(height: 8),
          Text(result['message'] as String,
            style: TextStyle(color: c.textSecondary, fontSize: 13)),
        ],
        if (result['failure_reason'] != null && isFailed) ...[
          const SizedBox(height: 4),
          Text(result['failure_reason'] as String,
            style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
        // Overpayment reassurance: gateway-path loan overpayments are reconciled
        // and refunded by the SACCO (to savings or back to mobile money), not lost.
        if (isCompleted && purpose == 'loan_repayment') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.emeraldDeep,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Icon(UniconsLine.info_circle, color: Colors.white, size: 16),
              SizedBox(width: 10),
              Expanded(child: Text(
                'If you paid more than your loan balance, the extra is automatically '
                'reviewed and refunded to you — credited to your savings or sent back '
                'to your mobile money. You will be notified.',
                style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        if (isProcessing) ...[
          SizedBox(
            width: double.infinity, height: 46,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onCheckStatus,
              icon: busy
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(UniconsLine.sync, size: 16),
              label: const Text('Check Status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: statusColor,
                side: BorderSide(color: statusColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity, height: 46,
          child: OutlinedButton(
            onPressed: onPayAgain,
            style: OutlinedButton.styleFrom(
              foregroundColor: c.textSecondary,
              side: BorderSide(color: c.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isCompleted ? 'Make Another Payment' : 'Start Over'),
          ),
        ),
      ]),
    );
  }

  Widget _Row(AppColorScheme c, String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: c.textHint, fontSize: 12)),
      Text(val, style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final AppColorScheme c;
  final String text;
  const _SectionLabel(this.c, this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700));
}

class _EmptyHint extends StatelessWidget {
  final AppColorScheme c;
  final String msg;
  const _EmptyHint(this.c, this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.surface, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.border),
    ),
    child: Text(msg, style: TextStyle(color: c.textHint, fontSize: 13)),
  );
}

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _Dropdown({required this.value, required this.hint,
      required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, isExpanded: true, dropdownColor: c.card,
          hint: Text(hint, style: TextStyle(color: c.textHint, fontSize: 14)),
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          items: items, onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType keyboardType;
  final Widget? prefix;
  final bool readOnly;
  const _InputField({required this.ctrl, required this.hint,
      this.keyboardType = TextInputType.text, this.prefix, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: ctrl, keyboardType: keyboardType, readOnly: readOnly,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: c.textHint),
        prefixIcon: prefix,
        filled: true, fillColor: c.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final AppColorScheme c;
  final bool isDark;
  final IconData icon;
  final Color color;
  final String msg;
  const _InfoChip(this.c, this.isDark, this.icon, this.color, this.msg);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.onColor(color), size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg,
        style: TextStyle(color: AppColors.onColor(color), fontSize: 12, fontWeight: FontWeight.w500))),
    ]),
  );
}

