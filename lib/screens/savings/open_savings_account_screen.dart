import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

// ── Self-service savings account opening ──────────────────────────────────
// Lets a member open a new account under any active savings product. Opens
// with a zero balance — there's no teller/cash-in-hand in the app — the
// member funds it afterwards via the normal deposit flow.

class OpenSavingsAccountScreen extends StatefulWidget {
  const OpenSavingsAccountScreen({super.key});
  @override State<OpenSavingsAccountScreen> createState() => _OpenSavingsAccountScreenState();
}

class _OpenSavingsAccountScreenState extends State<OpenSavingsAccountScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat('#,##0', 'en_US');
  List<dynamic> _products = [];
  int? _selectedId;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _products = await _api.getSavingsProducts(); } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open() async {
    if (_selectedId == null) return;
    setState(() => _busy = true);
    try {
      await _api.createSavingsAccount(_selectedId!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger));
        setState(() => _busy = false);
      }
    }
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SAVINGS', style: TextStyle(
                    color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text('Open a new account', style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ])),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : _products.isEmpty
                    ? Center(
                        child: Text('No savings products are available right now.',
                            style: TextStyle(color: c.textSecondary)),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          Text('Choose a product to open your account under. It starts at UGX 0 — deposit anytime after opening.',
                              style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
                          const SizedBox(height: 16),
                          ..._products.map((p) {
                            final product = (p as Map).cast<String, dynamic>();
                            final id = product['id'] as int;
                            final selected = _selectedId == id;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedId = id),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.emeraldDeep : c.card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: selected ? AppColors.emeraldDeep : c.border, width: selected ? 2 : 1),
                                ),
                                child: Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(product['name']?.toString() ?? 'Savings',
                                        style: TextStyle(
                                            color: selected ? Colors.white : c.textPrimary,
                                            fontSize: 15, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text('${product['interest_rate']}% p.a. interest',
                                        style: TextStyle(
                                            color: selected ? Colors.white70 : c.textSecondary, fontSize: 12)),
                                    if ((product['minimum_opening_balance'] as num? ?? 0) > 0) ...[
                                      const SizedBox(height: 2),
                                      Text('Recommended opening deposit: UGX ${_fmt.format(product['minimum_opening_balance'])}',
                                          style: TextStyle(
                                              color: selected ? Colors.white70 : c.textSecondary, fontSize: 11)),
                                    ],
                                  ])),
                                  Icon(
                                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: selected ? Colors.white : c.textHint,
                                  ),
                                ]),
                              ),
                            );
                          }),
                        ],
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: (_selectedId == null || _busy) ? null : _open,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
                    shape: const StadiumBorder()),
                child: _busy
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Open account', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
