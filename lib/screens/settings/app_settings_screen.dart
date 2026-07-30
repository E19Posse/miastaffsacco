import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/pin/pin_lock_screen.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/pin_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _api   = ApiService();
  final _store = StorageService();
  bool _biometricAvailable = false;
  bool _biometricEnabled   = false;
  bool _pinEnabled         = false;
  int  _timeoutMinutes     = PinService.defaultTimeoutMinutes;
  List<BiometricType> _biometricTypes = [];
  bool _loading = true;

  static const _timeoutOptions = <int, String>{
    0:  'Off',
    1:  '1 minute',
    2:  '2 minutes',
    5:  '5 minutes',
    10: '10 minutes',
    15: '15 minutes',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available  = await BiometricService.isAvailable();
    final bioEnabled = await BiometricService.isEnabled();
    final pinEnabled = await PinService.isEnabled();
    final timeout    = await PinService.getTimeoutMinutes();
    List<BiometricType> types = [];
    if (available) {
      try {
        types = await LocalAuthentication().getAvailableBiometrics();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled   = bioEnabled;
        _pinEnabled         = pinEnabled;
        _timeoutMinutes     = timeout;
        _biometricTypes     = types;
        _loading            = false;
      });
    }
  }

  // ── PIN management ────────────────────────────────────────────────────────

  Future<void> _togglePin(bool enable) async {
    if (enable) {
      // Set a new PIN
      final pin1 = await showPinEntryDialog(
        context,
        title:    'Create App PIN',
        subtitle: 'Choose a 4-digit PIN to lock the app when it is backgrounded.',
      );
      if (pin1 == null || !mounted) return;

      final pin2 = await showPinEntryDialog(
        context,
        title:    'Confirm PIN',
        subtitle: 'Re-enter your PIN to confirm.',
      );
      if (pin2 == null || !mounted) return;

      if (pin1 != pin2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PINs do not match. Try again.'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
      await PinService.setPin(pin1);
      if (mounted) {
        setState(() => _pinEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('App PIN enabled. The app will lock when backgrounded.'),
          backgroundColor: AppColors.emeraldMid,
        ));
      }
    } else {
      // Verify current PIN before disabling
      final pin = await showPinEntryDialog(
        context,
        title:    'Enter Current PIN',
        subtitle: 'Verify your PIN to disable app lock.',
      );
      if (pin == null || !mounted) return;

      final ok = await PinService.verify(pin);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Incorrect PIN. App lock not disabled.'),
            backgroundColor: AppColors.danger,
          ));
        }
        return;
      }
      await PinService.clearPin();
      if (mounted) {
        setState(() => _pinEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('App PIN disabled.'),
          backgroundColor: AppColors.gold,
        ));
      }
    }
  }

  Future<void> _changePin() async {
    final oldPin = await showPinEntryDialog(
      context,
      title:    'Enter Current PIN',
      subtitle: 'Verify your current PIN before setting a new one.',
    );
    if (oldPin == null || !mounted) return;

    final ok = await PinService.verify(oldPin);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incorrect PIN.'),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }

    final pin1 = await showPinEntryDialog(
      context, title: 'New PIN', subtitle: 'Choose a new 4-digit PIN.');
    if (pin1 == null || !mounted) return;

    final pin2 = await showPinEntryDialog(
      context, title: 'Confirm New PIN', subtitle: 'Re-enter your new PIN.');
    if (pin2 == null || !mounted) return;

    if (pin1 != pin2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PINs do not match.'),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }
    await PinService.setPin(pin1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PIN updated successfully.'),
        backgroundColor: AppColors.emeraldMid,
      ));
    }
  }

  Future<void> _pickTimeout() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final c = ctx.colors;
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 16),
            Text('Auto-Lock After',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Lock or sign out after this much inactivity.',
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            for (final entry in _timeoutOptions.entries)
              ListTile(
                title: Text(entry.value,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: _timeoutMinutes == entry.key
                            ? FontWeight.w700
                            : FontWeight.w400)),
                trailing: _timeoutMinutes == entry.key
                    ? const Icon(UniconsLine.check, color: AppColors.emeraldDeep)
                    : null,
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
    if (chosen == null) return;
    await PinService.setTimeoutMinutes(chosen);
    if (mounted) {
      setState(() => _timeoutMinutes = chosen);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(chosen == 0
            ? 'Inactivity auto-lock turned off.'
            : 'App will auto-lock after ${_timeoutOptions[chosen]} of inactivity.'),
        backgroundColor: chosen == 0 ? AppColors.gold : AppColors.emeraldMid,
      ));
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Confirm with a live biometric check before enabling
      final ok = await BiometricService.authenticate(
        reason: 'Verify your biometric to enable this feature',
      );
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Biometric verification failed. Not enabled.'),
            backgroundColor: AppColors.danger,
          ));
        }
        return;
      }

      // Biometric login needs to be able to sign the user back in from
      // scratch (e.g. after logout or a token expiry), not just unlock an
      // already-open session. That requires replaying the account password
      // through login() later, so capture + verify it once here.
      final password = await _askPassword();
      if (password == null || !mounted) return;
      try {
        await _api.verifyIdentity(password);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiService.extractError(e)),
            backgroundColor: AppColors.danger,
          ));
        }
        return;
      }
      final email = context.read<AuthProvider>().member?.email;
      if (email != null) await _store.saveBiometricCredentials(email, password);
    } else {
      await _store.clearBiometricCredentials();
    }

    await BiometricService.setEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value
            ? 'Biometric login enabled. You can now sign in with your fingerprint or face.'
            : 'Biometric login disabled.'),
        backgroundColor: value ? AppColors.emeraldMid : AppColors.gold,
      ));
    }
  }

  Future<String?> _askPassword() {
    final ctrl = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.card,
          title: const Text('Confirm Your Password'),
          content: TextField(
            controller: ctrl,
            obscureText: obscure,
            autofocus: true,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(obscure ? UniconsLine.eye : UniconsLine.eye_slash),
                onPressed: () => setDialogState(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Confirm'),
            ),
          ],
        );
      }),
    );
  }

  String get _biometricLabel {
    if (_biometricTypes.contains(BiometricType.face) &&
        _biometricTypes.contains(BiometricType.fingerprint)) {
      return 'Face ID & Fingerprint';
    } else if (_biometricTypes.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_biometricTypes.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_biometricTypes.contains(BiometricType.iris)) {
      return 'Iris Scan';
    }
    return 'Biometric';
  }

  IconData get _biometricIcon {
    if (_biometricTypes.contains(BiometricType.face)) return UniconsLine.smile;
    return UniconsLine.lock_alt;
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                child: Text('App Settings',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [

                // ── Security ────────────────────────────────────────────────
                _SectionHeader(c, 'Security'),
                const SizedBox(height: 10),

                _SettingsCard(c, children: [
                  if (!_biometricAvailable)
                    _InfoRow(
                      c: c,
                      isDark: isDark,
                      icon: UniconsLine.lock_alt,
                      iconColor: c.textHint,
                      title: 'Biometric Login',
                      subtitle: 'Not available on this device.',
                      trailing: const Icon(UniconsLine.ban, color: AppColors.danger, size: 20),
                    )
                  else ...[
                    _ToggleRow(
                      c: c,
                      isDark: isDark,
                      icon: _biometricIcon,
                      iconColor: AppColors.emeraldDeep,
                      title: '$_biometricLabel Login',
                      subtitle: _biometricEnabled
                          ? 'Sign in with $_biometricLabel instead of your password.'
                          : 'Enable to sign in faster using $_biometricLabel.',
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                    ),
                    if (_biometricEnabled) ...[
                      _Divider(c),
                      _InfoRow(
                        c: c,
                        isDark: isDark,
                        icon: UniconsLine.shield,
                        iconColor: AppColors.emeraldMid,
                        title: 'Status',
                        subtitle: 'Active — your next login can use $_biometricLabel.',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldMid,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Active',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ]),

                const SizedBox(height: 12),

                // How it works info card
                if (_biometricAvailable)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldDeep,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(UniconsLine.info_circle,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'When enabled, you can sign in using $_biometricLabel '
                            'instead of your password. You will be prompted to verify '
                            'your biometric on the login screen.',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // ── App Lock (PIN) ───────────────────────────────────────────
                _SectionHeader(c, 'App Lock'),
                const SizedBox(height: 10),

                _SettingsCard(c, children: [
                  _ToggleRow(
                    c: c,
                    isDark: isDark,
                    icon: UniconsLine.map_pin,
                    iconColor: AppColors.gold,
                    title: '4-Digit PIN Lock',
                    subtitle: _pinEnabled
                        ? 'App locks when sent to background. Tap to disable.'
                        : 'Lock the app with a PIN when it is backgrounded.',
                    value: _pinEnabled,
                    onChanged: _togglePin,
                  ),
                  if (_pinEnabled) ...[
                    _Divider(c),
                    _InfoRow(
                      c: c,
                      isDark: isDark,
                      icon: UniconsLine.edit,
                      iconColor: AppColors.emeraldDeep,
                      title: 'Change PIN',
                      subtitle: 'Update your current PIN.',
                      trailing: IconButton(
                        icon: const Icon(UniconsLine.angle_right, size: 20),
                        color: c.textHint,
                        onPressed: _changePin,
                      ),
                    ),
                  ],
                  _Divider(c),
                  InkWell(
                    onTap: _pickTimeout,
                    child: _InfoRow(
                      c: c,
                      isDark: isDark,
                      icon: UniconsLine.clock,
                      iconColor: AppColors.emeraldDeep,
                      title: 'Auto-Lock After Inactivity',
                      subtitle: _timeoutMinutes == 0
                          ? 'Off — the app never locks itself while open.'
                          : (_pinEnabled
                              ? 'Locks after ${_timeoutOptions[_timeoutMinutes]} of no activity.'
                              : 'Signs out after ${_timeoutOptions[_timeoutMinutes]} of no activity.'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_timeoutOptions[_timeoutMinutes] ?? '$_timeoutMinutes min',
                            style: const TextStyle(
                                color: AppColors.emeraldDeep,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Icon(UniconsLine.angle_right, size: 20, color: c.textHint),
                      ]),
                    ),
                  ),
                ]),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(UniconsLine.info_circle,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'When enabled, the app requires your PIN every time it is brought '
                          'back from the background, and after the inactivity period above. '
                          'If no PIN is set, it signs you out instead. If biometric is also '
                          'enabled, you can use your fingerprint or face to unlock.',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Shared layout widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final AppColorScheme c;
  final String text;
  const _SectionHeader(this.c, this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .8));
}

class _SettingsCard extends StatelessWidget {
  final AppColorScheme c;
  final List<Widget> children;
  const _SettingsCard(this.c, {required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: .5),
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  final AppColorScheme c;
  const _Divider(this.c);
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, thickness: .5, color: c.border,
      indent: 56, endIndent: 16);
}

class _ToggleRow extends StatelessWidget {
  final AppColorScheme c;
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.c, required this.isDark, required this.icon,
    required this.iconColor, required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ])),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.emeraldDeep,
          ),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final AppColorScheme c;
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _InfoRow({
    required this.c, required this.isDark, required this.icon,
    required this.iconColor, required this.title, required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ])),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ]),
      );
}
