import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/money_text.dart';
import 'package:unicons/unicons.dart';

/// Loans where this member has been asked to act as guarantor. They can accept
/// (optionally adjusting the amount they'll guarantee) or decline.
class GuarantorRequestsScreen extends StatefulWidget {
  const GuarantorRequestsScreen({super.key});
  @override
  State<GuarantorRequestsScreen> createState() => _GuarantorRequestsScreenState();
}

class _GuarantorRequestsScreenState extends State<GuarantorRequestsScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getGuarantorRequests();
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  Future<void> _respond(Map<String, dynamic> req, String action) async {
    double? amount;
    if (action == 'accept') {
      amount = await _askAmount((req['guaranteed_amount'] as num?)?.toDouble() ?? 0);
      if (amount == null) return; // cancelled
    }
    try {
      final res = await _api.respondGuarantorRequest(req['id'] as int, action, amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Done'),
        backgroundColor: action == 'accept' ? AppColors.emeraldMid : AppColors.gold));
      _load();
    } catch (e) {
      if (mounted) AppDialogs.handleActionError(context, e,
          accessDeniedMessage: 'You don\'t have permission to respond to this request.');
    }
  }

  Future<double?> _askAmount(double initial) async {
    final ctrl = TextEditingController(text: initial > 0 ? _fmt.format(initial) : '');
    return showDialog<double>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.card,
          title: const Text('Amount you will guarantee'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(color: c.textPrimary),
            decoration: const InputDecoration(prefixText: 'UGX ', hintText: 'e.g. 500,000'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text.replaceAll(',', '').trim());
                if (v == null || v < 1) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Enter a valid amount'), backgroundColor: AppColors.danger));
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
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
            Expanded(child: Text('Guarantor Requests', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.emeraldDeep, backgroundColor: c.card,
            onRefresh: _load,
            child: _loading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error, onRetry: _load)
                    : _items.isEmpty
                        ? _EmptyState()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            children: _items.map((e) {
                              final m = (e as Map).cast<String, dynamic>();
                              return _RequestCard(
                                req: m,
                                fmt: _fmt,
                                onAccept: () => _respond(m, 'accept'),
                                onDecline: () => _respond(m, 'decline'),
                              );
                            }).toList(),
                          ),
          ),
        ),
      ])),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final NumberFormat fmt;
  final VoidCallback onAccept, onDecline;
  const _RequestCard({required this.req, required this.fmt, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final status  = (req['status'] ?? 'Pending').toString();
    final pending = status == 'Pending';
    final (statusColor, _) = switch (status) {
      'Accepted' => (AppColors.emeraldMid, status),
      'Declined' => (AppColors.danger, status),
      _          => (AppColors.gold, status),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.emeraldMid, borderRadius: BorderRadius.circular(12)),
            child: const Icon(UniconsLine.shield_check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req['applicant_name']?.toString() ?? 'Member',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            Text('${req['loan_product'] ?? 'Loan'}  •  ${req['loan_number'] ?? ''}',
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Stat(c, 'Loan amount', (req['loan_amount'] as num?)?.toDouble() ?? 0, fmt)),
          Container(width: 1, height: 30, color: c.border),
          Expanded(child: _Stat(c, 'You guarantee', (req['guaranteed_amount'] as num?)?.toDouble() ?? 0, fmt)),
        ]),
        if (pending) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: onDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger),
                shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldMid, foregroundColor: Colors.white,
                shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final AppColorScheme c;
  final String label;
  final double amount;
  final NumberFormat fmt;
  const _Stat(this.c, this.label, this.amount, this.fmt);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: c.textHint, fontSize: 10, fontWeight: FontWeight.w600)),
    const SizedBox(height: 3),
    MoneyText(amount: amount.round(), currency: 'UGX', size: 16, color: c.textPrimary),
  ]);
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(children: [
      const SizedBox(height: 120),
      Icon(UniconsLine.shield_check, size: 64, color: c.textHint),
      const SizedBox(height: 16),
      Center(child: Text('No guarantor requests',
          style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
      const SizedBox(height: 8),
      Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text('When another member asks you to guarantee their loan, it will appear here.',
            textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 13)),
      )),
    ]);
  }
}

