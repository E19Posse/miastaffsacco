import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';
import '../../widgets/app_svg_icon.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<dynamic> _notifications   = [];
  List<dynamic> _announcements   = [];
  bool   _loading = true;
  String? _error;
  bool   _markingRead = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getNotifications(),
        _api.getAnnouncements().catchError((_) => <dynamic>[]),
      ]);
      final res  = results[0] as Map<String, dynamic>;
      final list = (res['data'] ?? res['notifications'] ?? []) as List<dynamic>;
      final ann  = results[1] as List<dynamic>;
      if (mounted) setState(() {
        _notifications = list;
        _announcements = ann;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _markingRead = true);
    try {
      await _api.markAllNotificationsRead();
      setState(() {
        _notifications = _notifications.map((n) {
          final m = Map<String, dynamic>.from(n as Map<String, dynamic>);
          m['is_read'] = true;
          return m;
        }).toList();
      });
      if (mounted) context.read<DashboardProvider>().clearUnreadLocally();
    } catch (_) {}
    if (mounted) setState(() => _markingRead = false);
  }

  Future<void> _markOneRead(int id) async {
    try {
      await _api.markNotificationRead(id);
      setState(() {
        _notifications = _notifications.map((n) {
          final m = Map<String, dynamic>.from(n as Map<String, dynamic>);
          if (m['id'] == id) m['is_read'] = true;
          return m;
        }).toList();
      });
      if (mounted) context.read<DashboardProvider>().markOneReadLocally(id);
    } catch (_) {}
  }

  void _openMenu() {
    final c = context.colors;
    final unread = _notifications.where((n) => !(n['is_read'] as bool? ?? false)).length;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(
              color: c.border, borderRadius: BorderRadius.circular(999))),
          ListTile(
            enabled: unread > 0 && !_markingRead,
            leading: Icon(UniconsLine.check_circle, color: unread > 0 ? AppColors.emeraldDeep : c.textHint),
            title: Text('Mark all as read',
                style: TextStyle(color: unread > 0 ? c.textPrimary : c.textHint, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(ctx); _markAllRead(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unread = _notifications.where((n) => !(n['is_read'] as bool? ?? false)).length;
    final total  = _notifications.length + _announcements.length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(UniconsLine.angle_left, color: c.textPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Row(children: [
                Text('Notifications', style: GoogleFonts.sora(
                    fontSize: 19, fontWeight: FontWeight.w800, color: c.textPrimary)),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger, borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$unread', style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ])),
              if (total > 0)
                IconButton(
                  onPressed: _openMenu,
                  icon: Icon(UniconsLine.ellipsis_v, color: c.textSecondary, size: 20),
                ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error, onRetry: _load)
                    : total == 0
                        ? _empty()
                        : _buildList(),
          ),
        ]),
      ),
    );
  }

  Widget _empty() {
    final c = context.colors;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 84, height: 84,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.emeraldMid,
            shape: BoxShape.circle,
          ),
          child: const Icon(UniconsLine.bell, size: 34, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text('Nothing new right now', style: GoogleFonts.sora(
            color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('We\'ll let you know when something needs\nyour attention.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5)),
      ]),
    );
  }

  String _dateLabel(String? raw) {
    if (raw == null) return 'Earlier';
    try {
      final dt  = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return 'Today';
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) return 'Yesterday';
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) { return 'Earlier'; }
  }

  Widget _buildList() {
    final c = context.colors;
    final Map<String, List<dynamic>> grouped = {};

    // Announcements first (always top)
    if (_announcements.isNotEmpty) {
      grouped['Announcements'] = _announcements;
    }

    for (final n in _notifications) {
      final m   = n as Map<String, dynamic>;
      final lbl = _dateLabel(m['created_at']?.toString());
      grouped.putIfAbsent(lbl, () => []).add(n);
    }

    return RefreshIndicator(
      color: AppColors.emeraldDeep,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
              child: Text(entry.key,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
            ...entry.value.map((n) {
              final m   = n as Map<String, dynamic>;
              final id  = m['id'] as int?;
              final isA = entry.key == 'Announcements';
              return _NotifTile(
                data: m,
                isAnnouncement: isA,
                onTap: (!isA && id != null && !(m['is_read'] as bool? ?? false))
                    ? () => _markOneRead(id)
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool         isAnnouncement;
  final VoidCallback? onTap;
  const _NotifTile({required this.data, this.isAnnouncement = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title  = data['title']?.toString()   ?? data['subject']?.toString() ?? '—';
    final body   = data['body']?.toString()    ?? data['message']?.toString()  ?? '';
    final type   = data['type']?.toString()    ?? '';
    final isRead = isAnnouncement || (data['is_read'] as bool? ?? false);
    final raw    = data['created_at']?.toString() ?? '';
    String timeStr = _relativeTime(raw);

    final color = isAnnouncement ? AppColors.emeraldDeep : _typeColor(type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: _typeIconWidget(type, Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(title,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 13))),
              const SizedBox(width: 6),
              Text(timeStr, style: TextStyle(color: c.textHint, fontSize: 10)),
            ]),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.cardAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isAnnouncement ? 'Announcement' : _typeLabel(type),
                  style: TextStyle(color: c.textPrimary, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                ),
              ),
              if (!isRead) ...[
                const Spacer(),
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ]),
          ])),
        ]),
      ),
    ));
  }

  String _relativeTime(String raw) {
    try {
      final dt   = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 2)     return 'Yesterday';
      return DateFormat('HH:mm').format(dt);
    } catch (_) { return ''; }
  }

  String _typeLabel(String type) {
    if (type.isEmpty) return 'General';
    return type.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  // Kept in sync with the real notification `type` values the backend actually
  // sends (App\Models\InAppNotification, App\Services\NotificationService and
  // friends) — not a guessed/aspirational list. Verify against the database
  // (`InAppNotification::select('type')->distinct()`) before adding a case.
  Color _typeColor(String type) {
    switch (type) {
      case 'security':
      case 'alert':           return AppColors.danger;
      case 'payment':
      case 'repayment':
      case 'membership':      return AppColors.emeraldMid;
      case 'kyc_update':
      case 'info':            return AppColors.verifiedBlue;
      case 'governance':
      case 'announcement':    return AppColors.emeraldDeep;
      case 'loan_event':
      case 'loan':
      case 'challenge_reminder': return AppColors.gold;
      default:                return AppColors.gold;
    }
  }

  Widget _typeIconWidget(String type, Color color) {
    switch (type) {
      case 'loan_event':
      case 'loan':            return AppSvgIcon(AppSvgIcons.loan, color: color, size: 18);
      case 'payment':         return Icon(Icons.savings_outlined, color: color, size: 18);
      case 'repayment':       return Icon(UniconsLine.receipt, color: color, size: 18);
      case 'kyc_update':      return Icon(UniconsLine.shield_check, color: color, size: 18);
      case 'security':        return Icon(UniconsLine.lock, color: color, size: 18);
      case 'alert':           return Icon(UniconsLine.exclamation_triangle, color: color, size: 18);
      case 'governance':      return Icon(UniconsLine.university, color: color, size: 18);
      case 'announcement':    return Icon(UniconsLine.megaphone, color: color, size: 18);
      case 'membership':      return Icon(UniconsLine.user_plus, color: color, size: 18);
      case 'info':            return Icon(UniconsLine.info_circle, color: color, size: 18);
      case 'challenge_reminder': return Icon(UniconsLine.trophy, color: color, size: 18);
      default:                return Icon(Icons.notifications_outlined, color: color, size: 18);
    }
  }
}
