import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders one of the app's custom Material-Symbols-style SVG icons
/// (assets/images/ic_*.svg), tinted like a font icon so it drops into any
/// Icon-shaped slot (color, size) used across the app.
class AppSvgIcon extends StatelessWidget {
  final String asset;
  final Color color;
  final double size;
  const AppSvgIcon(this.asset, {super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    // Center+SizedBox (mirroring Icon's own internal layout) keeps the glyph
    // at exactly `size`, centered, even when a parent forces a larger tight
    // box on this widget (e.g. an AspectRatio tile).
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class AppSvgIcons {
  static const deposit = 'assets/images/ic_deposit.svg';
  static const loan = 'assets/images/ic_loan.svg';
  static const vote = 'assets/images/ic_vote.svg';
  static const repay = 'assets/images/ic_repay.svg';
}
