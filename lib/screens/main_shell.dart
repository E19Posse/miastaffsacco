import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_svg_icon.dart';
import 'home/home_screen.dart';
import 'savings/savings_screen.dart';
import 'loans/loans_screen.dart';
import 'more/more_screen.dart';
import 'payments/pay_screen.dart';
import 'package:unicons/unicons.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  final _screens = const [
    HomeScreen(),
    SavingsScreen(),
    LoansScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(children: [
        if (auth.isImpersonating)
          _ImpersonationBanner(
            name:    auth.impersonatedName ?? 'Unknown',
            onStop:  () => auth.stopImpersonation(),
          ),
        Expanded(child: AnimatedIndexedStack(index: _idx, children: _screens)),
      ]),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.35),
              blurRadius: 20, offset: const Offset(0, 8),
            )],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: UniconsLine.estate,     label: 'Home',    idx: 0, current: _idx, onTap: _setIdx),
              _NavItem(icon: Icons.savings_outlined, label: 'Savings', idx: 1, current: _idx, onTap: _setIdx),
              _MorphFab(onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const PayScreen()))),
              _NavItem(iconSvg: AppSvgIcons.loan, label: 'Loans',   idx: 2, current: _idx, onTap: _setIdx),
              _NavItem(icon: UniconsLine.user_circle, label: 'Profile', idx: 3, current: _idx, onTap: _setIdx),
            ],
          ),
        ),
      ),
    );
  }

  void _setIdx(int i) => setState(() => _idx = i);
}

// ── Impersonation Banner ──────────────────────────────────────────────────────

class _ImpersonationBanner extends StatelessWidget {
  final String name;
  final VoidCallback onStop;
  const _ImpersonationBanner({required this.name, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            const Icon(UniconsLine.setting, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Viewing as: $name',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: onStop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: const Text('Stop',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Morphing FAB ─────────────────────────────────────────────────────────────

class _MorphFab extends StatefulWidget {
  final VoidCallback onTap;
  const _MorphFab({required this.onTap});
  @override State<_MorphFab> createState() => _MorphFabState();
}

class _MorphFabState extends State<_MorphFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward().then((_) {
      _ctrl.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 52, height: 52,
          decoration: const BoxDecoration(
            color: AppColors.accentSky,
            shape: BoxShape.circle,
          ),
          child: const Icon(UniconsLine.plus, color: AppColors.navy, size: 28),
        ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData? icon;
  final String? iconSvg;
  final String   label;
  final int      idx, current;
  final void Function(int) onTap;
  const _NavItem({this.icon, this.iconSvg, required this.label,
    required this.idx, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = idx == current;
    final color  = active ? Colors.white : AppColors.cream.withValues(alpha: 0.5);
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          iconSvg != null
              ? AppSvgIcon(iconSvg!, color: color, size: 22)
              : Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
              color: color, fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }
}
