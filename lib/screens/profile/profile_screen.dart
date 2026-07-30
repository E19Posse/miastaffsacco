import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../services/pdf_download_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/verification_badge.dart';
import 'package:unicons/unicons.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
  }

  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) setState(() => _notificationsEnabled = value);
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    Navigator.pop(context); // close bottom sheet
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploadingAvatar = true);
      final ok = await context.read<AuthProvider>().uploadAvatar(File(picked.path));
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Profile photo updated.' : 'Upload failed. Try again.'),
        backgroundColor: ok ? AppColors.emeraldMid : AppColors.danger,
      ));
    } catch (_) {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    Navigator.pop(context); // close bottom sheet
    setState(() => _uploadingAvatar = true);
    await context.read<AuthProvider>().removeAvatar();
    if (mounted) setState(() => _uploadingAvatar = false);
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.emeraldMid,
      ));

  void _openChangePassword() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _openHelpSupport() async {
    final uri = Uri.parse('https://ithelp.immigration.go.ug/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open the support site.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _openAbout() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final c = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/logo.png', width: 72, height: 72),
          const SizedBox(height: 16),
          Text('MIA Staff SACCO',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Member Portal',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Divider(color: c.border),
          const SizedBox(height: 8),
          _AboutRow('Version', '${info.version} (${info.buildNumber})', c),
          _AboutRow('Package', info.packageName, c),
          const SizedBox(height: 8),
          Text('© ${DateTime.now().year} MIA Staff SACCO',
              style: TextStyle(color: c.textHint, fontSize: 11)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: AppColors.emeraldMid, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openDownloadStatement() {
    final c       = context.colors;
    final savings = context.read<DashboardProvider>().savings;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Download Statement',
                  style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            _SheetOption(
              icon: UniconsLine.users_alt,
              label: 'Full Account Summary',
              onTap: () { Navigator.pop(context); _downloadPdf('/pdf/member-summary', 'account-summary.pdf'); },
            ),
            if (savings.isNotEmpty)
              _SheetOption(
                icon: UniconsLine.wallet,
                label: 'Savings Statement',
                onTap: () { Navigator.pop(context); _downloadPdf('/pdf/savings/${savings.first.id}', 'savings-statement.pdf'); },
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(String path, String filename) async {
    _snack('Preparing download...');
    await PdfDownloadService.download(context, path: path, filename: filename);
  }

  void _showAvatarOptions(BuildContext context, bool hasAvatar) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            _SheetOption(
              icon: UniconsLine.camera,
              label: 'Take a Photo',
              onTap: () => _pickAndUpload(ImageSource.camera),
            ),
            _SheetOption(
              icon: UniconsLine.image,
              label: 'Choose from Gallery',
              onTap: () => _pickAndUpload(ImageSource.gallery),
            ),
            if (hasAvatar)
              _SheetOption(
                icon: UniconsLine.trash_alt,
                label: 'Remove Photo',
                color: AppColors.danger,
                onTap: _removeAvatar,
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final auth   = context.watch<AuthProvider>();
    final member = auth.member;
    final hasAvatar = member?.avatarUrl != null;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(children: [
          Row(children: [
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
            Text('Profile', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
          ]),
          const SizedBox(height: 16),

          // Avatar with edit badge
          GestureDetector(
            onTap: () => _showAvatarOptions(context, hasAvatar),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Circle avatar
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasAvatar ? null : AppColors.emeraldDeep,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: ClipOval(
                    child: _uploadingAvatar
                        ? const Center(
                            child: SizedBox(
                              width: 28, height: 28,
                              child: CircularProgressIndicator(
                                color: AppColors.emeraldDeep, strokeWidth: 2.5),
                            ))
                        : hasAvatar
                            ? CachedNetworkImage(
                                imageUrl: member!.avatarUrl!,
                                fit: BoxFit.cover,
                                // Only the loading/error states need a solid backdrop for the
                                // initials text — once the photo actually loads it fully
                                // covers the circle (BoxFit.cover), so the outer container
                                // above is left transparent instead of tinting the photo.
                                placeholder: (_, __) => Container(
                                  color: AppColors.emeraldDeep,
                                  child: Center(
                                    child: Text(
                                      member.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.emeraldDeep,
                                  child: Center(
                                    child: Text(
                                      member.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  member?.initials ?? 'M',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30, fontWeight: FontWeight.w800),
                                ),
                              ),
                  ),
                ),
                // Camera badge at bottom-right
                if (!_uploadingAvatar)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.emeraldDeep,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg, width: 2),
                      ),
                      child: const Icon(UniconsLine.camera,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(member?.name ?? '—',
                  style: GoogleFonts.sora(
                      color: c.textPrimary,
                      fontSize: 22, fontWeight: FontWeight.w800)),
              if (member != null) ...[
                const SizedBox(width: 6),
                VerificationBadge(tier: member.creditTier, size: 22),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(member?.email ?? '',
              style: TextStyle(color: c.textSecondary, fontSize: 14)),
          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.emeraldDeep,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Member #${member?.memberNumber ?? '—'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 32),

          _Section(title: 'Account', items: [
            _MenuItem(
              icon: UniconsLine.phone,
              label: 'Phone Number',
              trailing: Text(member?.phone ?? '—',
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
              onTap: () {},
            ),
            _MenuItem(
              icon: UniconsLine.calendar_alt,
              label: 'Member Since',
              trailing: Text(
                member != null
                    ? '${member.joinedAt.day}/${member.joinedAt.month}/${member.joinedAt.year}'
                    : '—',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),

          _Section(title: 'Preferences', items: [
            _MenuItem(
              icon: UniconsLine.moon,
              label: 'Dark Mode',
              trailing: Switch.adaptive(
                value: context.watch<ThemeProvider>().isDark,
                activeTrackColor: AppColors.emeraldDeep,
                onChanged: (_) => context.read<ThemeProvider>().toggle(),
              ),
              onTap: () => context.read<ThemeProvider>().toggle(),
            ),
            _MenuItem(
              icon: UniconsLine.bell,
              label: 'Notifications',
              trailing: Switch.adaptive(
                value: _notificationsEnabled,
                activeTrackColor: AppColors.emeraldDeep,
                onChanged: _toggleNotifications,
              ),
              onTap: () => _toggleNotifications(!_notificationsEnabled),
            ),
            _MenuItem(
              icon: UniconsLine.lock,
              label: 'Change Password',
              onTap: _openChangePassword,
            ),
            _MenuItem(
              icon: UniconsLine.download_alt,
              label: 'Download Statement',
              onTap: _openDownloadStatement,
            ),
          ]),
          const SizedBox(height: 16),

          _Section(title: 'Support', items: [
            _MenuItem(
              icon: UniconsLine.headphones,
              label: 'Help & Support',
              onTap: _openHelpSupport,
            ),
            _MenuItem(
              icon: UniconsLine.info_circle,
              label: 'About MIA Staff SACCO',
              onTap: _openAbout,
            ),
          ]),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(UniconsLine.signout),
              label: Text('Log Out',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15)),
              onPressed: () async {
                final ok = await _confirmLogout(context);
                if (ok && context.mounted) {
                  await context.read<AuthProvider>().logout();
                  context.go('/login');
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ]),
        ),
      ),
    );
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    final c = context.colors;
    return await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Log Out', style: TextStyle(color: c.textPrimary)),
        content: Text('Are you sure you want to log out?',
            style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Log Out',
                style: TextStyle(color: AppColors.danger,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _SheetOption({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w600,
                  letterSpacing: .6)),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, width: .5),
          ),
          child: Column(children: [
            for (int i = 0; i < items.length; i++) ...[
              items[i],
              if (i < items.length - 1)
                Divider(height: 1, indent: 56, endIndent: 16, color: c.border),
            ],
          ]),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Widget?  trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon, required this.label,
    this.trailing, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c.textSecondary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w500))),
          trailing ??
              Icon(UniconsLine.angle_right,
                  color: c.textHint, size: 20),
        ]),
      ),
    );
  }
}

// â”€â”€ About row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AboutRow extends StatelessWidget {
  final String label, value;
  final AppColorScheme c;
  const _AboutRow(this.label, this.value, this.c);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
      Text(value, style: TextStyle(
          color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// â”€â”€ Change Password Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  @override State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _api         = ApiService();
  final _currCtrl    = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurr    = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _busy           = false;

  @override
  void dispose() {
    _currCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final curr    = _currCtrl.text.trim();
    final newPwd  = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (curr.isEmpty) { _snack('Enter your current password'); return; }
    if (newPwd.length < 8) { _snack('New password must be at least 8 characters'); return; }
    if (newPwd != confirm) { _snack('Passwords do not match'); return; }
    if (newPwd == curr) { _snack('New password must differ from current'); return; }

    setState(() => _busy = true);
    try {
      await _api.changePassword(currentPassword: curr, newPassword: newPwd);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password changed successfully.'),
        backgroundColor: AppColors.emeraldMid,
      ));
    } catch (e) {
      _snack(ApiService.extractError(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.emeraldMid,
      ));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 20),
        Text('Change Password',
            style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        _PwdField(
          ctrl: _currCtrl,
          hint: 'Current password',
          obscure: _obscureCurr,
          onToggle: () => setState(() => _obscureCurr = !_obscureCurr),
        ),
        const SizedBox(height: 14),
        _PwdField(
          ctrl: _newCtrl,
          hint: 'New password (min. 8 characters)',
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 14),
        _PwdField(
          ctrl: _confirmCtrl,
          hint: 'Confirm new password',
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 24),

        SizedBox(width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldDeep,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('Update Password',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}

class _PwdField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  const _PwdField({required this.ctrl, required this.hint,
      required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textHint),
        prefixIcon: Icon(UniconsLine.lock, color: c.textHint, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? UniconsLine.eye : UniconsLine.eye_slash,
            color: c.textHint, size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border)),
        focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
    );
  }
}
