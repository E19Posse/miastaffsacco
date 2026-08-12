import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/money_text.dart';
import '../payments/add_cash_flow.dart' show WaitingConfirmationScreen;
import '../payments/payment_methods_screen.dart';
import 'package:unicons/unicons.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Savings Challenges — gamified saving. A grid of amount cards; tapping a card
//  makes a real MoMo deposit toward the linked savings account and fills the card.
// ════════════════════════════════════════════════════════════════════════════

final _fmt = NumberFormat('#,##0', 'en_US');

String _providerId(String carrier) =>
    carrier.toUpperCase() == 'MTN' ? 'mtn_momo' : 'airtel_money';

// ── List ────────────────────────────────────────────────────────────────────

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});
  @override State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _api = ApiService();
  String _filter = 'all';
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  final _filters = const {'all': 'All', 'started': 'Started', 'completed': 'Completed'};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _items = await _api.getChallenges(filter: _filter);
    } catch (e) {
      _error = ApiService.extractError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const CreateChallengeScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
        onPressed: _create, child: const Icon(Icons.add),
      ),
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
            Expanded(child: Text('Your Challenges', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Row(children: _filters.entries.map((e) {
            final active = e.key == _filter;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () { setState(() => _filter = e.key); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? AppColors.emeraldDeep : c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? AppColors.emeraldDeep : c.border),
                  ),
                  child: Text(e.value, style: TextStyle(
                      color: active ? Colors.white : c.textSecondary,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            );
          }).toList()),
        ),
        Expanded(
          child: _loading
              ? const LoadingStateView()
              : _error != null
                  ? ErrorStateView(message: _error, onRetry: _load)
                  : _items.isEmpty
                      ? _empty(c)
                      : RefreshIndicator(
                      color: AppColors.emeraldDeep, onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _ChallengeCard(
                          data: (_items[i] as Map).cast<String, dynamic>(),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChallengeDetailScreen(
                                    id: (_items[i] as Map)['id'] as int)));
                            _load();
                          },
                        ),
                      ),
                    ),
        ),
      ])),
    );
  }

  Widget _empty(AppColorScheme c) => ListView(children: [
    const SizedBox(height: 80),
    Icon(UniconsLine.trophy, size: 72, color: c.textHint),
    const SizedBox(height: 20),
    Center(child: Text('No challenges yet',
        style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800))),
    const SizedBox(height: 8),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text('Ready to start saving? Create your first challenge and watch your savings grow!',
          textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5)),
    ),
    const SizedBox(height: 28),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(height: 52, child: OutlinedButton(
        onPressed: _create,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: c.textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
        child: Text('Start Challenge', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
      )),
    ),
  ]);
}

class _ChallengeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _ChallengeCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final saved   = (data['total_saved'] as num?)?.toInt() ?? 0;
    final target  = (data['target_amount'] as num?)?.toInt() ?? 1;
    final cells   = (data['cells_count'] as num?)?.toInt() ?? 0;
    final done    = (data['saved_cells'] as num?)?.toInt() ?? 0;
    final pct     = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final complete = data['status'] == 'completed';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: complete ? AppColors.emeraldMid : c.border, width: complete ? 1 : .5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(data['name'] ?? 'Challenge',
                style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800))),
            if (complete)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.emeraldMid, borderRadius: BorderRadius.circular(8)),
                child: const Text('Completed', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8, backgroundColor: c.surface,
              valueColor: AlwaysStoppedAnimation(complete ? AppColors.emeraldMid : AppColors.emeraldDeep)),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('UGX ${_fmt.format(saved)} / ${_fmt.format(target)}',
                style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('$done / $cells cards', style: TextStyle(color: c.textHint, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

// ── Create ──────────────────────────────────────────────────────────────────

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});
  @override State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _api  = ApiService();
  final _name = TextEditingController(text: 'My Challenge');
  String _type = 'step_up';
  int _count = 16;
  int _base  = 1000;
  int _step  = 1000;
  int? _accountId;
  bool _busy = false;

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  int get _target {
    var t = 0;
    for (var i = 0; i < _count; i++) {
      t += _type == 'step_up' ? _base + _step * i : _base;
    }
    return t;
  }

  Future<void> _save() async {
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Choose a savings account'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.createChallenge(
        name: _name.text.trim().isEmpty ? 'My Challenge' : _name.text.trim(),
        type: _type, savingsAccountId: _accountId!,
        cellsCount: _count, baseAmount: _base, step: _type == 'step_up' ? _step : 0,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppDialogs.handleActionError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accounts = context.watch<DashboardProvider>().savings.where((a) => !a.isLocked).toList();
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;

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
            Expanded(child: Text('New Challenge', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        _label(c, 'Challenge name'),
        TextField(controller: _name, style: TextStyle(color: c.textPrimary),
            decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 20),

        _label(c, 'Type'),
        Row(children: [
          _typeChip(c, 'step_up', 'Step-up ladder'),
          const SizedBox(width: 10),
          _typeChip(c, 'fixed', 'Fixed amount'),
        ]),
        const SizedBox(height: 20),

        _label(c, 'Number of cards'),
        _stepper(c, _count, (v) => setState(() => _count = v.clamp(4, 100)), step: 4, min: 4, max: 100),
        const SizedBox(height: 20),

        _label(c, _type == 'step_up' ? 'Starting amount (card 1)' : 'Amount per card'),
        _stepper(c, _base, (v) => setState(() => _base = v.clamp(500, 1000000)), step: 500, min: 500, max: 1000000, money: true),

        if (_type == 'step_up') ...[
          const SizedBox(height: 20),
          _label(c, 'Increase per card'),
          _stepper(c, _step, (v) => setState(() => _step = v.clamp(0, 1000000)), step: 500, min: 0, max: 1000000, money: true),
        ],
        const SizedBox(height: 20),

        _label(c, 'Save into'),
        if (accounts.isEmpty)
          Text('No unlocked savings accounts.', style: TextStyle(color: c.textHint))
        else
          Container(
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(child: DropdownButton<int>(
              isExpanded: true, value: _accountId, dropdownColor: c.card,
              items: accounts.map((a) => DropdownMenuItem(value: a.id,
                  child: Text('${a.accountNumber}  ·  UGX ${_fmt.format(a.balance)}',
                      style: TextStyle(color: c.textPrimary)))).toList(),
              onChanged: (v) => setState(() => _accountId = v),
            )),
          ),

        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total target', style: TextStyle(color: c.textSecondary, fontSize: 14)),
            Text('UGX ${_fmt.format(_target)}',
                style: TextStyle(color: AppColors.emeraldDeep, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(height: 56, child: ElevatedButton(
          onPressed: _busy ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
              shape: const StadiumBorder()),
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text('Create Challenge', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
        )),
      ])),
      ])),
    );
  }

  Widget _label(AppColorScheme c, String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(s, style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)));

  Widget _typeChip(AppColorScheme c, String value, String label) {
    final active = _type == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.emeraldDeep : c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.emeraldDeep : c.border)),
        child: Text(label, style: TextStyle(
            color: active ? Colors.black : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    ));
  }

  Widget _stepper(AppColorScheme c, int value, ValueChanged<int> onChange,
      {required int step, required int min, required int max, bool money = false}) {
    return Row(children: [
      _rndBtn(c, Icons.remove, () => onChange(value - step)),
      Expanded(child: Center(child: Text(money ? 'UGX ${_fmt.format(value)}' : '$value',
          style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)))),
      _rndBtn(c, Icons.add, () => onChange(value + step)),
    ]);
  }

  Widget _rndBtn(AppColorScheme c, IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Container(width: 44, height: 44,
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
      child: Icon(icon, color: c.textPrimary, size: 20)),
  );
}

// ── Detail (the grid) ───────────────────────────────────────────────────────

class ChallengeDetailScreen extends StatefulWidget {
  final int id;
  const ChallengeDetailScreen({super.key, required this.id});
  @override State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _ch;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { _ch = await _api.getChallenge(widget.id); } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _tapCell(Map<String, dynamic> cell) async {
    if (cell['status'] == 'saved') return;

    // Pick a saved mobile-money account.
    final accounts = await _api.getMomoAccounts();
    if (!mounted) return;
    if (accounts.isEmpty) {
      final go = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('No mobile money account'),
        content: const Text('Add an MTN or Airtel account first to fund challenge cards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add account')),
        ],
      ));
      if (go == true && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()));
      }
      return;
    }

    final acct = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetCtx) {
        final c = sheetCtx.colors;
        return SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pay UGX ${_fmt.format(cell['amount'])} with',
                style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...accounts.map((a) {
              final m = (a as Map).cast<String, dynamic>();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(UniconsLine.mobile_android),
                title: Text(m['name'] ?? '—', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                subtitle: Text('${m['phone'] ?? ''}  ·  ${m['carrier'] ?? ''}', style: TextStyle(color: c.textSecondary)),
                onTap: () => Navigator.pop(sheetCtx, m),
              );
            }),
          ]),
        ));
      },
    );
    if (acct == null || !mounted) return;

    try {
      final res = await _api.payChallengeCell(
        challengeId: widget.id, cellId: cell['id'] as int,
        provider: _providerId((acct['carrier'] ?? '').toString()),
        phone: (acct['phone'] ?? acct['msisdn'])?.toString(),
      );
      if (!mounted) return;
      if ((res['status'] ?? '') == 'failed') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message']?.toString() ?? 'Payment failed'), backgroundColor: AppColors.danger));
        return;
      }
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => WaitingConfirmationScreen(reference: res['reference'].toString())));
      _load(); // refresh the grid (card may now be filled)
    } catch (e) {
      if (mounted) AppDialogs.handleActionError(context, e,
          accessDeniedMessage: 'You don\'t have permission to pay into this challenge.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ch = _ch;
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
            Expanded(child: Text(ch?['name'] ?? 'Challenge', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(child: _loading || ch == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
          : Column(children: [
              // Header progress
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.border, width: .5)),
                child: Column(children: [
                  Text('Total Saved', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  MoneyText(amount: (ch['total_saved'] as num? ?? 0).round(),
                      currency: 'UGX', size: 30, color: c.textPrimary, fit: true),
                  const SizedBox(height: 12),
                  ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ((ch['total_saved'] as num? ?? 0) / ((ch['target_amount'] as num? ?? 1) == 0 ? 1 : (ch['target_amount'] as num))).clamp(0.0, 1.0),
                      minHeight: 8, backgroundColor: c.surface,
                      valueColor: const AlwaysStoppedAnimation(AppColors.emeraldDeep))),
                  const SizedBox(height: 8),
                  Text('${ch['saved_cells'] ?? 0} of ${ch['cells_count'] ?? 0} cards · target UGX ${_fmt.format(ch['target_amount'] ?? 0)}',
                      style: TextStyle(color: c.textHint, fontSize: 12)),
                ]),
              ),
              if ((ch['cells'] as List?)?.isNotEmpty == true)
                Expanded(child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1),
                  itemCount: (ch['cells'] as List).length,
                  itemBuilder: (_, i) {
                    final cell = ((ch['cells'] as List)[i] as Map).cast<String, dynamic>();
                    final saved = cell['status'] == 'saved';
                    return GestureDetector(
                      onTap: () => _tapCell(cell),
                      child: Container(
                        decoration: BoxDecoration(
                          color: saved ? AppColors.emeraldDeep : c.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: saved ? AppColors.emeraldDeep : c.border, width: saved ? 0 : 1),
                        ),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (saved) const Icon(Icons.check, color: Colors.black, size: 18),
                          Text(_fmt.format(cell['amount']),
                              style: TextStyle(
                                  color: saved ? Colors.black : c.textPrimary,
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                        ])),
                      ),
                    );
                  },
                )),
            ]),
        ),
      ])),
    );
  }
}
