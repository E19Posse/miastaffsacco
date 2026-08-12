import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unicons/unicons.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Global "No internet connection" / "Connecting…" / "Back online" banner.
/// Mount once near the root (see [SaccoApp]'s builder) so it overlays every
/// screen — including splash/login — without each screen wiring its own copy.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});
  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  StreamSubscription<NetStatus>? _sub;
  NetStatus? _visible; // null = hidden
  Timer? _hideTimer;
  bool _wasDown = false;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.start();
    _sub = ConnectivityService.instance.statusStream.listen(_handle);
  }

  void _handle(NetStatus s) {
    _hideTimer?.cancel();
    if (s == NetStatus.online) {
      if (_wasDown) {
        setState(() => _visible = NetStatus.online);
        _hideTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _visible = null);
        });
      }
      _wasDown = false;
    } else {
      _wasDown = true;
      setState(() => _visible = s);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _visible != null;
    final Color bg;
    final IconData icon;
    final String label;
    switch (_visible) {
      case NetStatus.offline:
        bg = AppColors.danger; icon = UniconsLine.wifi_slash; label = 'No internet connection';
        break;
      case NetStatus.checking:
        bg = AppColors.gold; icon = UniconsLine.wifi; label = 'Connecting…';
        break;
      case NetStatus.online:
        bg = AppColors.emeraldMid; icon = UniconsLine.wifi; label = 'Back online';
        break;
      case null:
        bg = Colors.transparent; icon = UniconsLine.wifi; label = '';
    }

    return IgnorePointer(
      child: AnimatedSlide(
        offset: shown ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: SafeArea(
            bottom: false,
            child: Material(
              color: bg,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
