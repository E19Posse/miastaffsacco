import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';
import '../payments/add_cash_flow.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});
  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final _api  = ApiService();
  final _fmt  = NumberFormat('#,##0', 'en_US');
  List<dynamic> _goals   = [];
  bool          _loading = true;
  String?       _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getGoals();
      setState(() { _goals = data; _loading = false; });
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: _goals.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: AppColors.emeraldDeep,
              onPressed: () => _showAddGoalSheet(context),
              child: const Icon(UniconsLine.plus, color: Colors.white),
            )
          : null,
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
            Expanded(child: Text('Savings Goals', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
            IconButton(icon: const Icon(UniconsLine.sync, color: AppColors.emeraldDeep), onPressed: _load),
            IconButton(
              icon: const Icon(UniconsLine.plus, color: AppColors.emeraldDeep),
              onPressed: () => _showAddGoalSheet(context),
            ),
          ]),
        ),
        Expanded(child: _loading
          ? const LoadingStateView()
          : _error != null
              ? ErrorStateView(message: _error, onRetry: _load)
              : _goals.isEmpty
                  ? _EmptyState(onAdd: () => _showAddGoalSheet(context))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.emeraldDeep,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: _goals.length,
                        itemBuilder: (_, i) => _GoalCard(
                          goal: _goals[i],
                          fmt: _fmt,
                          onDelete: () => _deleteGoal(_goals[i]['id']),
                          onAutomate: () => _showAutomate(_goals[i]),
                          onAddMoney: () => _addMoney(_goals[i]),
                        ),
                      ),
                    ),
        ),
      ])),
    );
  }

  Future<void> _deleteGoal(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Remove this savings goal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteGoal(id);
      _load();
    } catch (e) {
      if (mounted) AppDialogs.handleActionError(context, e,
          accessDeniedMessage: 'You don\'t have permission to delete this goal.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppColors.danger));
  }

  void _addMoney(dynamic goal) {
    try {
      // savings_account_id can arrive as either a JSON number or a numeric
      // string depending on how the backend serialised it — parse instead of
      // a hard `as int?` cast, which throws (silently, outside any try/catch
      // at the call site) and aborts the whole tap with no visible feedback.
      final raw = goal['savings_account_id'];
      final accountId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (accountId == null) {
        _showError('This goal isn\'t linked to a savings account. Delete it and create a new one to fix this.');
        return;
      }
      final label = goal['account_number']?.toString() ?? goal['name']?.toString() ?? 'Savings';
      Navigator.push(context, MaterialPageRoute(builder: (_) => AddCashMethodScreen(
        savingsAccountId: accountId,
        accountLabel: label,
      )));
    } catch (e) {
      _showError('Could not open deposit: $e');
    }
  }

  Future<void> _showAutomate(dynamic goal) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _AutoSaveSheet(api: _api, goal: goal),
    );
    if (changed == true) _load();
  }

  void _showAddGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _AddGoalSheet(
        onSaved: () { Navigator.pop(context); _load(); },
        api: _api,
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final dynamic goal;
  final NumberFormat fmt;
  final VoidCallback onDelete;
  final VoidCallback onAutomate;
  final VoidCallback onAddMoney;
  const _GoalCard({
    required this.goal, required this.fmt, required this.onDelete,
    required this.onAutomate, required this.onAddMoney,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final pct     = (goal['progress_pct'] as int? ?? 0).clamp(0, 100);
    final status  = goal['status'] as String? ?? 'Active';
    final color   = status == 'Completed' ? AppColors.emeraldMid : AppColors.emeraldDeep;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(UniconsLine.bookmark, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(goal['name'] as String,
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            if (goal['target_date'] != null)
              Text('Target: ${goal['target_date']}',
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ])),
          GestureDetector(
            onTap: onAutomate,
            child: Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: goal['auto_active'] == true ? AppColors.emeraldMid : AppColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(UniconsLine.refresh, color: Colors.white, size: 18),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(UniconsLine.trash_alt, color: Colors.white, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Saved', style: TextStyle(color: c.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text('UGX ${fmt.format(goal['current_amount'] ?? 0)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Target', style: TextStyle(color: c.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text('UGX ${fmt.format(goal['target_amount'] ?? 0)}',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text('$pct%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 7,
            backgroundColor: c.cardAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: onAddMoney,
            icon: const Icon(UniconsLine.plus_circle, size: 16),
            label: Text('Add Money', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldDeep,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AddGoalSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final ApiService   api;
  const _AddGoalSheet({required this.onSaved, required this.api});
  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _amountCtrl  = TextEditingController();
  DateTime?  _targetDate;
  bool       _saving  = false;
  bool       _loadingAccounts = true;
  String?    _error;
  List<dynamic> _accounts = [];
  int?       _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.api.getSavings();
      final usable = accounts.where((a) =>
          (a['is_active'] as bool? ?? true) && !(a['is_locked'] as bool? ?? false)).toList();
      if (mounted) setState(() {
        _accounts = usable;
        if (usable.length == 1) _selectedAccountId = usable[0]['id'] as int;
        _loadingAccounts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _amountCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      setState(() => _error = 'Choose a savings account to fund this goal from.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.createGoal({
        'name':                _nameCtrl.text.trim(),
        'target_amount':       double.parse(_amountCtrl.text.replaceAll(',', '')),
        'savings_account_id':  _selectedAccountId,
        if (_targetDate != null) 'target_date': DateFormat('yyyy-MM-dd').format(_targetDate!),
      });
      widget.onSaved();
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New Savings Goal',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Goal Name',
              hintText: 'e.g. School Fees 2026',
              filled: true, fillColor: c.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target Amount (UGX)',
              hintText: 'e.g. 2000000',
              filled: true, fillColor: c.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final n = double.tryParse(v.replaceAll(',', ''));
              if (n == null || n < 1000) return 'Enter a valid amount (min UGX 1,000)';
              return null;
            },
          ),
          const SizedBox(height: 14),
          Text('Fund this goal from', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_loadingAccounts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep, strokeWidth: 2)),
            )
          else if (_accounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'You need an active savings account before creating a goal. Open one from Savings first.',
                style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selectedAccountId,
              decoration: InputDecoration(
                filled: true, fillColor: c.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              hint: const Text('Choose an account'),
              items: _accounts.map((a) {
                final label = '${(a['product'] as Map?)?['name'] ?? 'Savings'} · ${a['account_number']}';
                return DropdownMenuItem<int>(value: a['id'] as int, child: Text(label, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: (v) => setState(() => _selectedAccountId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border)),
              child: Row(children: [
                Icon(UniconsLine.calendar_alt, color: c.textSecondary, size: 18),
                const SizedBox(width: 10),
                Text(
                  _targetDate != null
                      ? DateFormat('dd MMM yyyy').format(_targetDate!)
                      : 'Target Date (optional)',
                  style: TextStyle(color: _targetDate != null ? c.textPrimary : c.textHint)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_saving || _loadingAccounts || _accounts.isEmpty) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldDeep,
                foregroundColor: Colors.white,
                shape: const StadiumBorder()),
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Goal',
                      style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(UniconsLine.bookmark, size: 72, color: c.textHint),
        const SizedBox(height: 16),
        Text('No savings goals yet',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        const SizedBox(height: 8),
        Text('Set a target and track your progress',
            style: TextStyle(color: c.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(UniconsLine.plus, size: 18),
          label: Text('Create Goal', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emeraldDeep,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder()),
        ),
      ]),
    ));
  }
}

// ── Auto-save (recurring savings) sheet ───────────────────────────────────────

class _AutoSaveSheet extends StatefulWidget {
  final ApiService api;
  final dynamic goal;
  const _AutoSaveSheet({required this.api, required this.goal});
  @override
  State<_AutoSaveSheet> createState() => _AutoSaveSheetState();
}

class _AutoSaveSheetState extends State<_AutoSaveSheet> {
  final _amt = TextEditingController();
  String _freq = 'monthly';
  bool _loading = true, _busy = false;
  Map<String, dynamic>? _existing;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _amt.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await widget.api.getGoalAuto(widget.goal['id'] as int);
      if (mounted) setState(() {
        _existing = res;
        if (res != null) {
          _amt.text = ((res['amount'] as num?) ?? 0).toStringAsFixed(0);
          _freq = (res['frequency'] as String?) ?? 'monthly';
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amt.text.replaceAll(',', '').trim());
    if (amt == null || amt < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Minimum is UGX 1,000'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await widget.api.setGoalAuto(widget.goal['id'] as int, amt, _freq);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Automatic saving enabled.'),
        backgroundColor: AppColors.emeraldMid));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppDialogs.handleActionError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOff() async {
    setState(() => _busy = true);
    try {
      await widget.api.cancelGoalAuto(widget.goal['id'] as int);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppDialogs.handleActionError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _loading
          ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep)))
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Automatic Saving', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('We will collect this amount from your mobile money on schedule and add it to "${widget.goal['name']}".',
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
              const SizedBox(height: 20),
              Text('Amount (UGX)', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _amt, keyboardType: TextInputType.number, style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. 50,000', hintStyle: TextStyle(color: c.textHint),
                  filled: true, fillColor: c.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Frequency', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                _freqPill('weekly', 'Weekly'),
                const SizedBox(width: 10),
                _freqPill('monthly', 'Monthly'),
              ]),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white, shape: const StadiumBorder()),
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(_existing != null ? 'Update Auto-Save' : 'Turn On Auto-Save', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              )),
              if (_existing != null) ...[
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, height: 48, child: TextButton(
                  onPressed: _busy ? null : _turnOff,
                  child: const Text('Turn Off Auto-Save', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                )),
              ],
            ]),
    );
  }

  Widget _freqPill(String value, String label) {
    final c = context.colors;
    final active = _freq == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _freq = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.emeraldDeep : c.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: active ? AppColors.emeraldDeep : c.border),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    ));
  }
}
