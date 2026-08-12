import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unicons/unicons.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Notification Settings — master Push / SMS / Email toggles.
//  Mirrors the Chipper "Notification Settings" screen. Toggles persist per
//  member and gate SMS/Email delivery server-side.
// ════════════════════════════════════════════════════════════════════════════

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _api = ApiService();
  bool _loading = true, _saving = false;
  bool _push = true, _sms = true, _email = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final p = await _api.getNotificationPreferences();
      _push  = p['push']  as bool? ?? true;
      _sms   = p['sms']   as bool? ?? true;
      _email = p['email'] as bool? ?? true;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.updateNotificationPreferences(push: _push, sms: _sms, email: _email);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiService.extractError(e)), backgroundColor: AppColors.danger));
    }
    if (mounted) setState(() => _saving = false);
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
                child: Text('Notification Settings',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
                    Text('Choose how TMI Staff SACCO reaches you. Security alerts are always sent.',
                        style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
                    const SizedBox(height: 20),
                    _toggle(c, 'Push', 'In-app and device push notifications', _push,
                        (v) { setState(() => _push = v); _save(); }),
                    _toggle(c, 'SMS', 'Text-message alerts to your phone', _sms,
                        (v) { setState(() => _sms = v); _save(); }),
                    _toggle(c, 'Email', 'Email alerts and statements', _email,
                        (v) { setState(() => _email = v); _save(); }),
                    if (_saving) const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: AppColors.emeraldDeep, strokeWidth: 2))),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _toggle(AppColorScheme c, String title, String sub, bool value, ValueChanged<bool> onChanged) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border, width: .5)),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.emeraldDeep,
          title: Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          value: value,
          onChanged: onChanged,
        ),
      );
}
