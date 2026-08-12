import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Solid chip/background colour for a tier badge — gold uses [AppColors.tierGold]
/// (a real gold/amber, independent of the app's blue UI accent), bronze uses
/// the distinct verification blue, basic uses neutral grey.
Color tierChipColor(String tier) => switch (tier) {
  'gold'   => AppColors.tierGold,
  'bronze' => AppColors.verifiedBlue,
  _        => const Color(0xFF9AA5B1),
};

/// Member verification-badge tier icon. Tier is credit-score driven (see
/// CreditScoreService::badgeTier() server-side / Member.creditTier client-side):
/// gold (>=750), bronze (400-749), basic (<400).
///
/// The 'basic' source PNG has a wide transparent canvas (666x375) around a
/// centered square glyph — BoxFit.contain shrank the whole canvas and made the
/// glyph tiny. BoxFit.cover crops that padding instead, filling the box with
/// just the glyph. Gold/bronze sources are already square, so cover behaves
/// identically to contain for them (no side effects).
///
/// Known limitation: the bronze source is only 24x24px — too low-resolution
/// to render crisply at any on-screen size on a high-density phone display.
/// That needs a higher-resolution source asset; it can't be fixed in code.
class VerificationBadge extends StatelessWidget {
  final String tier; // 'gold' | 'bronze' | 'basic'
  final double size;
  const VerificationBadge({super.key, required this.tier, this.size = 20});

  static const _assetForTier = {
    'gold':   'assets/images/icons8-verified-badge-48-removebg-preview.png',
    'bronze': 'assets/images/icons8-verified-account-24-removebg-preview.png',
    'basic':  'assets/images/twitter-gray-checkmark-xl-removebg-preview.png',
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Image.asset(
      _assetForTier[tier] ?? _assetForTier['basic']!,
      fit: BoxFit.cover,
    ),
  );
}
