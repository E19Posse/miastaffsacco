import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Slide + fade custom page route (replaces MaterialPageRoute for crisp transitions).
class SlideRoute<T> extends PageRouteBuilder<T> {
  SlideRoute({required Widget page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (_, animation, __, child) {
            final slide = Tween<Offset>(
                    begin: const Offset(1.0, 0), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            final fade =
                CurvedAnimation(parent: animation, curve: Curves.easeOut);
            return FadeTransition(
                opacity: fade, child: SlideTransition(position: slide, child: child));
          },
        );
}

/// Horizontal shake animation that plays once on first build — good for errors.
class ShakeWidget extends StatefulWidget {
  final Widget child;
  const ShakeWidget({super.key, required this.child});
  @override State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(math.sin(_ctrl.value * math.pi * 4) * 9, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Fade + slide-in with a per-item stagger delay (index × 40 ms).
class StaggerItem extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggerItem({super.key, required this.index, required this.child});
  @override State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(24 * (1 - _anim.value), 0),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Drop-in replacement for IndexedStack that fades + slides the incoming tab.
/// All children stay mounted (state is preserved); inactive children are
/// Offstage'd and their tickers are paused via TickerMode.
class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const AnimatedIndexedStack(
      {super.key, required this.index, required this.children});
  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _idx = widget.index;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220))
      ..value = 1.0;
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0.03, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      setState(() => _idx = widget.index);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.children.asMap().entries.map((e) {
        final isActive = e.key == _idx;
        return Offstage(
          offstage: !isActive,
          child: TickerMode(
            enabled: isActive,
            child: isActive
                ? FadeTransition(
                    opacity: _fade,
                    child:
                        SlideTransition(position: _slide, child: e.value),
                  )
                : e.value,
          ),
        );
      }).toList(),
    );
  }
}

// ─── Success Check ────────────────────────────────────────────────────────────
//
// Faithful Flutter port of the transitions.dev success-check snippet.
// All five animations run in parallel on mount:
//   fade   opacity 0→1   550 ms  ease-out
//   rotate 80°→0°        550 ms  ease-out
//   blur   10px→0        500 ms  ease-out
//   bob    40px→0 Y      450 ms  spring (0.34, 1.35, 0.64, 1)
//   draw   path 0→1      550 ms  ease-out, 80 ms delay

class SuccessCheck extends StatefulWidget {
  final double size;
  final Color color;
  const SuccessCheck({super.key, this.size = 72, required this.color});
  @override State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _rotate;
  late Animation<double> _blur;
  late Animation<double> _slideY;
  late Animation<double> _draw;

  static const _easeOut = Cubic(0.22, 1, 0.36, 1);
  static const _spring  = Cubic(0.34, 1.35, 0.64, 1);
  static const _ms      = 630; // timeline length = 80 + 550

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: _ms));

    _opacity = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 550 / _ms, curve: _easeOut));

    _rotate = Tween<double>(begin: 80 * math.pi / 180, end: 0).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0, 550 / _ms, curve: _easeOut)));

    _blur = Tween<double>(begin: 10, end: 0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 500 / _ms, curve: _easeOut)));

    _slideY = Tween<double>(begin: 40, end: 0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 450 / _ms, curve: _spring)));

    _draw = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(80 / _ms, (80 + 550) / _ms, curve: _easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        Widget content = SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CheckPainter(
                progress: _draw.value, color: widget.color),
          ),
        );
        final blurVal = _blur.value;
        if (blurVal > 0.1) {
          content = ImageFiltered(
            imageFilter:
                ui.ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
            child: content,
          );
        }
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _slideY.value),
            child: Transform.rotate(angle: _rotate.value, child: content),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  * 0.44;

    // Tinted background circle
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..color = color.withAlpha(30),
    );

    if (progress <= 0) return;

    // Checkmark path drawn progressively
    final path = Path()
      ..moveTo(cx - r * 0.40, cy + r * 0.02)
      ..lineTo(cx - r * 0.08, cy + r * 0.40)
      ..lineTo(cx + r * 0.46, cy - r * 0.38);

    final metrics = path.computeMetrics().toList();
    for (final m in metrics) {
      canvas.drawPath(
        m.extractPath(0, m.length * progress),
        Paint()
          ..color      = color
          ..style      = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.075
          ..strokeCap  = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
