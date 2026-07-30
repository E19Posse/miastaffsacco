import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class ImpersonateScreen extends StatefulWidget {
  const ImpersonateScreen({super.key});
  @override
  State<ImpersonateScreen> createState() => _ImpersonateScreenState();
}

class _ImpersonateScreenState extends State<ImpersonateScreen> {
  final _api        = ApiService();
  final _searchCtrl = TextEditingController();
  List<dynamic> _users    = [];
  List<dynamic> _filtered = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getImpersonationList();
      if (mounted) setState(() {
        _users    = list;
        _filtered = list;
        _loading  = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error   = ApiService.extractError(e);
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users.where((u) {
              final name   = (u['name'] as String? ?? '').toLowerCase();
              final mno    = (u['member_number'] as String? ?? '').toLowerCase();
              return name.contains(q) || mno.contains(q);
            }).toList();
    });
  }

  Future<void> _confirm(Map<String, dynamic> user) async {
    final userId = user['user_id'] as int;
    final name   = user['name']    as String? ?? 'User';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Impersonation'),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You are about to view the app as:'),
          const SizedBox(height: 8),
          Text(name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(user['member_number'] as String? ?? '',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          const Text(
            'This action is logged. You will see the app exactly as this member sees it.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Impersonate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.impersonateUser(userId, name);

    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Failed to impersonate user.'),
          backgroundColor: AppColors.danger,
        ),
      );
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
              Expanded(
                child: Text('Impersonate User',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
            ]),
          ),
      Expanded(child: Column(children: [
        // Warning banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.danger.withOpacity(0.08),
          child: Row(children: [
            const Icon(UniconsLine.exclamation_triangle,
                color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Impersonation is logged and audited. Only use for support purposes.',
                style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name or member number…',
              hintStyle: TextStyle(color: c.textHint),
              prefixIcon: Icon(UniconsLine.search, color: c.textHint, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.emeraldDeep))
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('No members found',
                              style: TextStyle(color: c.textHint)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final u       = _filtered[i] as Map<String, dynamic>;
                            final name    = u['name'] as String? ?? '';
                            final mno     = u['member_number'] as String? ?? '—';
                            final role    = u['role_label'] as String? ?? 'Member';
                            final initial = name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: c.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: c.border, width: .5),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.emeraldDeep,
                                  child: Text(initial,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ),
                                title: Text(name,
                                    style: TextStyle(
                                        color: c.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                subtitle: Text('$mno · $role',
                                    style: TextStyle(
                                        color: c.textSecondary, fontSize: 12)),
                                trailing: OutlinedButton(
                                  onPressed: () => _confirm(u),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(
                                        color: AppColors.danger),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Act as',
                                      style: TextStyle(fontSize: 12)),
                                ),
                                onTap: () => _confirm(u),
                              ),
                            );
                          },
                        ),
        ),
      ])),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(UniconsLine.exclamation_circle, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(color: AppColors.emeraldDeep)),
          ),
        ]),
      );
}
