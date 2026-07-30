import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Ivy-style money display: a smaller currency code, a large heavy integer, and
/// an optional superscript decimal — e.g.  UGX **9,326**·⁵⁵.
///
/// Used for hero balances and accent cards. Wrap in a FittedBox at the call site
/// (or pass [fit] = true) when the available width is tight.
class MoneyText extends StatelessWidget {
  final num amount;
  final String currency;
  final double size;        // pixel size of the big integer part
  final Color color;
  final int decimals;       // how many decimal places to show as superscript (0 = none)
  final bool fit;           // scale down to fit width
  final FontWeight weight;

  const MoneyText({
    super.key,
    required this.amount,
    this.currency = 'UGX',
    this.size = 30,
    this.color = Colors.white,
    this.decimals = 0,
    this.fit = false,
    this.weight = FontWeight.w900,
  });

  static final _intFmt = NumberFormat('#,##0', 'en_US');

  @override
  Widget build(BuildContext context) {
    final whole    = amount.floor();
    final fraction = decimals > 0
        ? ((amount - whole) * (decimals == 2 ? 100 : 10)).round()
            .toString().padLeft(decimals, '0')
        : null;

    final smallSize = size * 0.46;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: size * 0.18, right: size * 0.12),
          child: Text(
            currency,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: smallSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Text(
          _intFmt.format(whole),
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            letterSpacing: -1,
            height: 1,
          ),
        ),
        if (fraction != null)
          Padding(
            padding: EdgeInsets.only(top: size * 0.08, left: size * 0.04),
            child: Text(
              '·$fraction',
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: smallSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    if (!fit) return row;
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: row);
  }
}
