import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});
  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _api  = ApiService();
  List<dynamic> _details  = [];
  bool          _loading  = true;
  String?       _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getBankDetails();
      setState(() { _details = data; _loading = false; });
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Bank Account'),
        content: const Text('Remove this bank account from your profile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteBankDetail(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.extractError(e)),
          backgroundColor: AppColors.danger));
      }
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddBankSheet(
        api: _api,
        onSaved: () { Navigator.pop(context); _load(); },
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
              Expanded(child: Text('Bank Accounts', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
              IconButton(icon: const Icon(UniconsLine.sync, color: AppColors.emeraldDeep), onPressed: _load),
              IconButton(icon: const Icon(UniconsLine.plus, color: AppColors.emeraldDeep),  onPressed: _showAddSheet),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : _error != null
                    ? _ErrorState(error: _error!, onRetry: _load)
                    : _details.isEmpty
                        ? _EmptyState(onAdd: _showAddSheet)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.emeraldDeep,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              itemCount: _details.length,
                              itemBuilder: (_, i) => _BankCard(
                                detail: _details[i],
                                onDelete: () => _delete(_details[i]['id'] as int),
                              ),
                            ),
                          ),
          ),
        ]),
      ),
      floatingActionButton: _details.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: AppColors.emeraldDeep,
              onPressed: _showAddSheet,
              child: const Icon(UniconsLine.plus, color: Colors.white),
            )
          : null,
    );
  }
}

class _BankCard extends StatelessWidget {
  final dynamic      detail;
  final VoidCallback onDelete;
  const _BankCard({required this.detail, required this.onDelete});

  String _maskAccount(String? acct) {
    if (acct == null || acct.length <= 4) return acct ?? '—';
    return '${'*' * (acct.length - 4)}${acct.substring(acct.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: const BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(detail['bank_name'] as String? ?? '—',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(_maskAccount(detail['account_number'] as String?),
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          if (detail['account_name'] != null) ...[
            const SizedBox(height: 2),
            Text(detail['account_name'] as String,
                style: TextStyle(color: c.textHint, fontSize: 12)),
          ],
          if (detail['branch_name'] != null) ...[
            const SizedBox(height: 2),
            Text(detail['branch_name'] as String,
                style: TextStyle(color: c.textHint, fontSize: 11)),
          ],
        ])),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(UniconsLine.trash_alt, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

class _AddBankSheet extends StatefulWidget {
  final ApiService   api;
  final VoidCallback onSaved;
  const _AddBankSheet({required this.api, required this.onSaved});
  @override
  State<_AddBankSheet> createState() => _AddBankSheetState();
}

class _AddBankSheetState extends State<_AddBankSheet> {
  final _formKey      = GlobalKey<FormState>();
  final _bankCtrl     = TextEditingController();
  final _accNumCtrl   = TextEditingController();
  final _accNameCtrl  = TextEditingController();
  final _branchCtrl   = TextEditingController();
  bool    _saving = false;
  String? _error;

  @override
  void dispose() {
    _bankCtrl.dispose(); _accNumCtrl.dispose();
    _accNameCtrl.dispose(); _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.addBankDetail({
        'bank_name':      _bankCtrl.text.trim(),
        'account_number': _accNumCtrl.text.trim(),
        'account_name':   _accNameCtrl.text.trim(),
        if (_branchCtrl.text.trim().isNotEmpty) 'branch_name': _branchCtrl.text.trim(),
      });
      widget.onSaved();
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Bank Account',
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

          _Field(controller: _bankCtrl,   label: 'Bank Name',       hint: 'e.g. Stanbic Bank',       c: c, required: true),
          const SizedBox(height: 12),
          _Field(controller: _accNumCtrl, label: 'Account Number',  hint: 'e.g. 9030012345678',      c: c, required: true),
          const SizedBox(height: 12),
          _Field(controller: _accNameCtrl,label: 'Account Name',    hint: 'e.g. John Doe',           c: c, required: true),
          const SizedBox(height: 12),
          _Field(controller: _branchCtrl, label: 'Branch (optional)',hint: 'e.g. Kampala Main Branch',c: c, required: false),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldDeep,
                foregroundColor: Colors.white,
                shape: const StadiumBorder()),
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Account',
                      style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final AppColorScheme c;
  final bool required;
  const _Field({
    required this.controller, required this.label, required this.hint,
    required this.c, required this.required,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      filled: true, fillColor: c.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
  );
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
        Icon(Icons.account_balance_outlined, size: 72, color: c.textHint),
        const SizedBox(height: 16),
        Text('No bank accounts added',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        const SizedBox(height: 8),
        Text('Add a bank account for withdrawals',
            style: TextStyle(color: c.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(UniconsLine.plus, size: 18),
          label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w700)),
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

class _ErrorState extends StatelessWidget {
  final String       error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(UniconsLine.exclamation_circle, size: 56, color: AppColors.danger),
      const SizedBox(height: 12),
      Text(error, textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary)),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  ));
}
