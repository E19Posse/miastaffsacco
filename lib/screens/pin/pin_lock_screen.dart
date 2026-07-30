import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import '../../services/pin_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinLockScreen({super.key, required this.onUnlocked});
  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin             = '';
  bool   _biometricAvail  = false;
  bool   _error           = false;

  static const _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final biometricEnabled = await BiometricService.isEnabled();
    final biometricAvail   = await BiometricService.isAvailable();
    if (mounted) setState(() => _biometricAvail = biometricEnabled && biometricAvail);
    if (_biometricAvail) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final ok = await BiometricService.authenticate(
      reason: 'Verify your identity to unlock MIA Staff SACCO',
    );
    if (ok && mounted) widget.onUnlocked();
  }

  void _onDigit(String d) {
    if (_pin.length >= _pinLength) return;
    setState(() { _pin += d; _error = false; });
    if (_pin.length == _pinLength) _verify();
  }

  void _onBack() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    final ok = await PinService.verify(_pin);
    if (ok && mounted) {
      widget.onUnlocked();
    } else if (mounted) {
      setState(() { _pin = ''; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 64),
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              color: AppColors.emeraldDeep,
              shape: BoxShape.circle,
            ),
            child: const Icon(UniconsLine.lock, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('MIA Staff SACCO',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Enter your PIN to continue',
              style: TextStyle(color: c.textSecondary, fontSize: 14)),

          const SizedBox(height: 48),

          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length
                    ? (_error ? AppColors.danger : AppColors.emeraldDeep)
                    : c.border,
                border: Border.all(
                  color: i < _pin.length
                      ? (_error ? AppColors.danger : AppColors.emeraldDeep)
                      : c.border,
                ),
              ),
            )),
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _error
                ? Padding(
                    key: const ValueKey('error'),
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Incorrect PIN. Try again.',
                        style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  )
                : const SizedBox(key: ValueKey('noerror'), height: 16),
          ),

          const Spacer(),

          // Number pad
          for (final row in ['123', '456', '789'])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.split('').map((d) =>
                    _PadBtn(label: d, onTap: () => _onDigit(d))).toList(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_biometricAvail)
                  _PadBtn(icon: UniconsLine.lock_alt, onTap: _tryBiometric)
                else
                  const SizedBox(width: 80),
                _PadBtn(label: '0', onTap: () => _onDigit('0')),
                _PadBtn(icon: UniconsLine.backspace, onTap: _onBack),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── PIN Setup / Entry Dialog ───────────────────────────────────────────────────

/// Shows an inline PIN entry pad inside a dialog.
/// Returns the entered 4-digit PIN string, or null if cancelled.
Future<String?> showPinEntryDialog(
  BuildContext context, {
  required String title,
  String subtitle = '',
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(title: title, subtitle: subtitle),
  );
}

class _PinDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  const _PinDialog({required this.title, required this.subtitle});
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _pin = '';
  static const _pinLength = 4;

  void _onDigit(String d) {
    if (_pin.length >= _pinLength) return;
    setState(() => _pin += d);
    if (_pin.length == _pinLength) Navigator.pop(context, _pin);
  }

  void _onBack() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.title,
              style: TextStyle(
                  color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          if (widget.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? AppColors.emeraldDeep : c.border,
              ),
            )),
          ),
          const SizedBox(height: 28),
          for (final row in ['123', '456', '789'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.split('').map((d) =>
                    _PadBtn(label: d, size: 62, onTap: () => _onDigit(d))).toList(),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 72),
              _PadBtn(label: '0', size: 62, onTap: () => _onDigit('0')),
              _PadBtn(icon: UniconsLine.backspace, size: 62, onTap: _onBack),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel',
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}

// ── Shared number-pad button ───────────────────────────────────────────────────

class _PadBtn extends StatelessWidget {
  final String?   label;
  final IconData? icon;
  final double    size;
  final VoidCallback onTap;
  const _PadBtn({this.label, this.icon, this.size = 76, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: c.card,
          shape: BoxShape.circle,
          border: Border.all(color: c.border, width: .5),
        ),
        child: Center(
          child: label != null
              ? Text(label!,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: size * 0.31,
                      fontWeight: FontWeight.w500))
              : Icon(icon, color: c.textSecondary, size: size * 0.32),
        ),
      ),
    );
  }
}
