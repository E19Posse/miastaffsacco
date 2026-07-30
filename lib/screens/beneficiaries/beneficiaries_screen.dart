import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

/// Member-managed beneficiaries / next-of-kin. Each has a name, relationship,
/// optional contact, and a share %. The API enforces total share ≤ 100%.
class BeneficiariesScreen extends StatefulWidget {
  const BeneficiariesScreen({super.key});
  @override
  State<BeneficiariesScreen> createState() => _BeneficiariesScreenState();
}

class _BeneficiariesScreenState extends State<BeneficiariesScreen> {
  final _api = ApiService();
  List<dynamic> _items = [];
  double _totalShare = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getBeneficiaries();
      if (mounted) setState(() {
        _items = (res['data'] as List?) ?? [];
        _totalShare = (res['total_share'] as num?)?.toDouble() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  Future<void> _edit({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _BeneficiarySheet(api: _api, existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.card,
        title: const Text('Remove beneficiary'),
        content: Text('Remove ${b['name']} as a beneficiary?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteBeneficiary(b['id'] as int);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger));
    }
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
            Expanded(child: Text('Beneficiaries', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
            TextButton.icon(
              onPressed: () => _edit(),
              icon: Icon(UniconsLine.plus, color: c.textPrimary),
              label: Text('Add', style: GoogleFonts.sora(color: c.textPrimary, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Expanded(child: RefreshIndicator(
        color: AppColors.emeraldDeep, backgroundColor: c.card, onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
            : _error != null
                ? ListView(children: [const SizedBox(height: 160), Center(child: Text(_error!, style: TextStyle(color: c.textSecondary)))])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _totalShare >= 100 ? AppColors.emeraldMid : AppColors.gold,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(children: [
                          const Icon(UniconsLine.users_alt, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(child: Text(
                            'Allocated ${_totalShare.toStringAsFixed(0)}% of your balances across ${_items.length} beneficiar${_items.length == 1 ? "y" : "ies"}.',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(children: [
                            Icon(UniconsLine.users_alt, size: 56, color: c.textHint),
                            const SizedBox(height: 12),
                            Text('No beneficiaries yet', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('Add your next-of-kin so your savings, shares and deposits\ncan be paid out correctly.',
                                textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                          ]),
                        )
                      else
                        ..._items.map((e) {
                          final b = (e as Map).cast<String, dynamic>();
                          return _BeneficiaryCard(
                            b: b,
                            onEdit: () => _edit(existing: b),
                            onDelete: () => _delete(b),
                          );
                        }),
                    ],
                  ),
        )),
      ])),
    );
  }
}

class _BeneficiaryCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final VoidCallback onEdit, onDelete;
  const _BeneficiaryCard({required this.b, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPrimary = b['is_primary'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isPrimary ? AppColors.emeraldDeep : c.border, width: isPrimary ? 1.5 : .5),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.emeraldDeep, borderRadius: BorderRadius.circular(12)),
          child: const Icon(UniconsLine.user, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(b['name']?.toString() ?? '—',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14))),
            if (isPrimary) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.emeraldDeep, borderRadius: BorderRadius.circular(8)),
                child: const Text('Primary', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text('${b['relationship'] ?? ''}'
              '${(b['phone'] ?? '').toString().isNotEmpty ? '  •  ${b['phone']}' : ''}'
              '  •  ${(b['share_percentage'] as num?)?.toStringAsFixed(0) ?? 0}%',
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ])),
        IconButton(onPressed: onEdit, icon: Icon(UniconsLine.edit, color: c.textHint, size: 20), visualDensity: VisualDensity.compact),
        IconButton(onPressed: onDelete, icon: const Icon(UniconsLine.trash_alt, color: AppColors.danger, size: 20), visualDensity: VisualDensity.compact),
      ]),
    );
  }
}

class _BeneficiarySheet extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? existing;
  const _BeneficiarySheet({required this.api, this.existing});
  @override
  State<_BeneficiarySheet> createState() => _BeneficiarySheetState();
}

class _BeneficiarySheetState extends State<_BeneficiarySheet> {
  late final TextEditingController _name;
  late final TextEditingController _rel;
  late final TextEditingController _phone;
  late final TextEditingController _nid;
  late final TextEditingController _share;
  bool _primary = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name  = TextEditingController(text: e?['name']?.toString() ?? '');
    _rel   = TextEditingController(text: e?['relationship']?.toString() ?? '');
    _phone = TextEditingController(text: e?['phone']?.toString() ?? '');
    _nid   = TextEditingController(text: e?['national_id']?.toString() ?? '');
    _share = TextEditingController(text: e?['share_percentage'] != null ? (e!['share_percentage'] as num).toStringAsFixed(0) : '');
    _primary = e?['is_primary'] == true;
  }

  @override
  void dispose() { _name.dispose(); _rel.dispose(); _phone.dispose(); _nid.dispose(); _share.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _rel.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Name and relationship are required'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.saveBeneficiary({
        'name': _name.text.trim(),
        'relationship': _rel.text.trim(),
        'phone': _phone.text.trim(),
        'national_id': _nid.text.trim(),
        'share_percentage': double.tryParse(_share.text.trim()) ?? 0,
        'is_primary': _primary,
      }, id: widget.existing?['id'] as int?);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(widget.existing == null ? 'Add Beneficiary' : 'Edit Beneficiary',
              style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _field(c, _name, 'Full name'),
          const SizedBox(height: 12),
          _field(c, _rel, 'Relationship (e.g. Spouse, Child)'),
          const SizedBox(height: 12),
          _field(c, _phone, 'Phone (optional)', keyboard: TextInputType.phone),
          const SizedBox(height: 12),
          _field(c, _nid, 'National ID (optional)'),
          const SizedBox(height: 12),
          _field(c, _share, 'Share % of balances', keyboard: TextInputType.number),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.emeraldDeep,
            title: Text('Primary beneficiary', style: TextStyle(color: c.textPrimary, fontSize: 14)),
            value: _primary,
            onChanged: (v) => setState(() => _primary = v),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
            onPressed: _busy ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white, shape: const StadiumBorder()),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('Save', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
          )),
        ]),
      ),
    );
  }

  Widget _field(AppColorScheme c, TextEditingController ctrl, String hint, {TextInputType keyboard = TextInputType.text}) =>
      TextField(
        controller: ctrl, keyboardType: keyboard, style: TextStyle(color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: c.textHint),
          filled: true, fillColor: c.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
        ),
      );
}
