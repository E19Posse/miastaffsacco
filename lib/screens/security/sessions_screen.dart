import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _api = ApiService();
  List<dynamic> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getActiveSessions();
      if (mounted) setState(() { _sessions = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  Future<void> _revoke(int id) async {
    try {
      await _api.revokeSession(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppDialogs.handleActionError(context, e,
          accessDeniedMessage: 'You don\'t have permission to revoke this session.');
    }
  }

  Future<void> _revokeAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revoke All Sessions'),
        content: const Text('This will sign out all other devices. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.revokeAllSessions();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All other sessions revoked.'), backgroundColor: AppColors.emeraldMid),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.handleActionError(context, e,
          accessDeniedMessage: 'You don\'t have permission to revoke sessions.');
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
              Expanded(child: Text('Active Sessions', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
              if (!_loading && _sessions.length > 1)
                TextButton(
                  onPressed: _revokeAll,
                  child: const Text('Revoke All Others', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error, onRetry: _load)
                    : RefreshIndicator(
                        color: AppColors.emeraldDeep,
                        onRefresh: _load,
                        child: _sessions.isEmpty
                            ? const EmptyStateView(
                                title: 'No active sessions',
                                icon: UniconsLine.desktop,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemCount: _sessions.length,
                          itemBuilder: (_, i) {
                            final s      = (_sessions[i] as Map).cast<String, dynamic>();
                            final id     = s['id'] as int;
                            final isCur  = s['is_current'] as bool? ?? false;
                            final last   = s['last_used'] as String? ?? '—';
                            final device = s['device'] as String? ?? 'Mobile device';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isCur ? AppColors.emeraldDeep : c.border,
                                  width: isCur ? 1.5 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: isCur ? AppColors.emeraldDeep : c.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(UniconsLine.mobile_android,
                                      color: isCur ? Colors.white : c.textSecondary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Text(isCur ? 'This Device' : device,
                                        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                                    if (isCur) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.emeraldDeep,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text('Current', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ]),
                                  const SizedBox(height: 3),
                                  Text('Last active: $last', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                                ])),
                                if (!isCur)
                                  TextButton(
                                    onPressed: () => _revoke(id),
                                    child: const Text('Revoke', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                                  ),
                              ]),
                            );
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}
