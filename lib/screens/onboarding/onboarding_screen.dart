import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/storage_service.dart';

// ── Slide data ────────────────────────────────────────────────────────────────

class _Slide {
  final String title;
  final String subtitle;
  final String illustration;
  final Color  accentColor;

  const _Slide({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.accentColor,
  });
}

const _slides = [
  _Slide(
    title:        'Your SACCO\nin Your Pocket',
    subtitle:     'Manage your savings, loans, and investments anytime, anywhere — all from one secure app.',
    illustration: 'assets/images/onboard_welcome.jpg',
    accentColor:  Color(0xFF00C853),
  ),
  _Slide(
    title:        'Grow Your\nSavings',
    subtitle:     'Track your account balance in real time, earn competitive interest, and download statements instantly.',
    illustration: 'assets/images/onboard_savings.jpg',
    accentColor:  Color(0xFF2979FF),
  ),
  _Slide(
    title:        'Quick Loan\nAccess',
    subtitle:     'Apply for a loan in minutes. Track your repayment schedule and get notified on due dates.',
    illustration: 'assets/images/onboard_loans.jpg',
    accentColor:  Color(0xFFFF9100),
  ),
  _Slide(
    title:        'Fixed Deposits\n& Shares',
    subtitle:     'Invest in fixed deposits and shares to grow your wealth and earn regular dividends.',
    illustration: 'assets/images/onboard_investments.jpg',
    accentColor:  Color(0xFFD500F9),
  ),
  _Slide(
    title:        'Bank-Grade\nSecurity',
    subtitle:     'Your data is protected with biometric login, encrypted storage, and real-time fraud alerts.',
    illustration: 'assets/images/onboard_security.jpg',
    accentColor:  Color(0xFF00E676),
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  final _store      = StorageService();
  int  _currentPage = 0;

  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  Future<void> _finish() async {
    await _store.setOnboardingSeen();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final slide   = _slides[_currentPage];
    final isLast  = _currentPage == _slides.length - 1;
    final bgColor = isDark ? const Color(0xFF0C0C14) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          // ── Skip ────────────────────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: isLast
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: slide.accentColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Skip',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
              ),
            ),
          ),

          // ── Page view ─────────────────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: _onPageChanged,
              itemCount: _slides.length,
              itemBuilder: (_, i) => _SlidePage(
                slide: _slides[i],
                isDark: isDark,
                fadeAnim: i == _currentPage ? _fadeAnim : null,
              ),
            ),
          ),

          // ── Dots ─────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width:  isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? slide.accentColor
                      : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // ── CTA button ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: _GradientButton(
                label: isLast ? 'Get Started' : 'Next',
                color: slide.accentColor,
                onTap: _next,
              ),
            ),
          ),
          const SizedBox(height: 36),
        ]),
      ),
    );
  }
}

// ── Slide page ────────────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  final _Slide                 slide;
  final bool                   isDark;
  final Animation<double>?     fadeAnim;

  const _SlidePage({
    required this.slide,
    required this.isDark,
    this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    final Widget illustration = Image.asset(
      slide.illustration,
      fit: BoxFit.contain,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Illustration area
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: fadeAnim != null
                  ? FadeTransition(opacity: fadeAnim!, child: illustration)
                  : illustration,
            ),
          ),

          // Text area
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Accent line
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: slide.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0D1B2A),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF9E9E9E)
                        : const Color(0xFF5A6070),
                    fontSize: 14.5,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient button ───────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.3)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
