import 'package:flutter/material.dart';

/// Solid-color pill badge used for status labels throughout the app.
/// Background is always [color] at full opacity; label text is always white.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.fontSize   = 11.0,
    this.horizontal = 10.0,
    this.vertical   = 4.0,
    this.radius     = 20.0,
  });

  final String  label;
  final Color   color;
  final double  fontSize;
  final double  horizontal;
  final double  vertical;
  final double  radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
