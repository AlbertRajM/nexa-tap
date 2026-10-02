import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Rotating multi-colour neon border with a soft glow (like AI search bars).
class NeonBorder extends StatefulWidget {
  final Widget child;
  final double radius;
  final double thickness;
  final bool active; // brighter + faster when focused

  const NeonBorder({super.key, required this.child, this.radius = 28, this.thickness = 2, this.active = false});

  @override
  State<NeonBorder> createState() => _NeonBorderState();
}

class _NeonBorderState extends State<NeonBorder> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void didUpdateWidget(covariant NeonBorder old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      _c.duration = Duration(milliseconds: widget.active ? 2200 : 4000);
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return RepaintBoundary(child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) => CustomPaint(
        painter: _NeonPainter(
          turn: _c.value,
          radius: widget.radius,
          thickness: widget.active ? widget.thickness + 0.8 : widget.thickness,
          glow: widget.active ? 1.0 : 0.55,
          colors: [p.accent, const Color(0xFF4DD8FF), p.accent2, const Color(0xFFFF6FB5), p.accent],
        ),
        child: child,
      ),
      child: Padding(padding: EdgeInsets.all(widget.thickness + 0.8), child: widget.child),
    ));
  }
}

class _NeonPainter extends CustomPainter {
  final double turn;
  final double radius;
  final double thickness;
  final double glow;
  final List<Color> colors;
  _NeonPainter({required this.turn, required this.radius, required this.thickness, required this.glow, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect.deflate(thickness / 2), Radius.circular(radius));
    final shader = SweepGradient(
      colors: colors,
      transform: GradientRotation(turn * 2 * math.pi),
    ).createShader(rect);

    // Soft glow: a few wider, fainter strokes (much cheaper than a blur every frame)
    for (var i = 3; i >= 1; i--) {
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness + i * 3.0
          ..color = Colors.white.withValues(alpha: 0.10 * glow),
      );
    }
    // Crisp line
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonPainter old) =>
      old.turn != turn || old.thickness != thickness || old.glow != glow || old.colors != colors;
}
