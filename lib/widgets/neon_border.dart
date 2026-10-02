import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Green-on-black neon border: a dim green track with two bright light
/// streaks racing around it, plus a real neon glow.
class NeonBorder extends StatefulWidget {
  final Widget child;
  final double radius;
  final double thickness;
  final bool active; // brighter + faster when focused

  /// Black glass used inside the neon search bar (same in light and dark mode).
  static const fill = Color(0xFF0A0D08);
  static const lime = Color(0xFFC8FF4D);
  static const mint = Color(0xFF3DFF9A);
  static const core = Color(0xFFF4FFDA);
  static const text = Color(0xFFE9F2DD);
  static const hint = Color(0xFF8C977F);

  const NeonBorder({super.key, required this.child, this.radius = 26, this.thickness = 1.6, this.active = false});

  @override
  State<NeonBorder> createState() => _NeonBorderState();
}

class _NeonBorderState extends State<NeonBorder> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();

  @override
  void didUpdateWidget(covariant NeonBorder old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      _c.duration = Duration(milliseconds: widget.active ? 1800 : 3600);
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          foregroundPainter: _NeonPainter(
            turn: _c.value,
            radius: widget.radius,
            thickness: widget.active ? widget.thickness + 0.6 : widget.thickness,
            glow: widget.active ? 1.0 : 0.7,
          ),
          child: child,
        ),
        child: Padding(padding: EdgeInsets.all(widget.thickness), child: widget.child),
      ),
    );
  }
}

class _NeonPainter extends CustomPainter {
  final double turn;
  final double radius;
  final double thickness;
  final double glow;
  _NeonPainter({required this.turn, required this.radius, required this.thickness, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect.deflate(thickness / 2), Radius.circular(radius));
    final path = Path()..addRRect(rr);
    final metric = path.computeMetrics().first;
    final len = metric.length;

    // 1. Dim green track so the outline is always visible.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = NeonBorder.lime.withValues(alpha: 0.28),
    );

    // 2. Two light streaks (lime and mint) chasing each other, same length on every edge.
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * glow);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const pieces = 18;
    for (final (offset, color) in [(0.0, NeonBorder.lime), (0.5, NeonBorder.mint)]) {
      final head = ((turn + offset) % 1) * len;
      final tail = len * 0.3;
      // One soft blurred glow under the bright half of the streak.
      glowPaint
        ..strokeWidth = thickness + 5
        ..color = color.withValues(alpha: 0.7 * glow);
      canvas.drawPath(_extract(metric, head - tail * 0.45, head, len), glowPaint);
      for (var i = 0; i < pieces; i++) {
        final f0 = i / pieces, f1 = (i + 1) / pieces;
        final a = f1 * f1; // fades toward the tail
        final start = head - tail + tail * f0;
        final end = head - tail + tail * f1 + 0.5;
        final seg = _extract(metric, start, end, len);
        final c = i == pieces - 1 ? NeonBorder.core : color;
        line
          ..strokeWidth = thickness + 0.4 * f1
          ..color = c.withValues(alpha: a);
        canvas.drawPath(seg, line);
      }
    }
  }

  /// Piece of the outline between two distances, wrapping around the end.
  static Path _extract(ui.PathMetric m, double start, double end, double len) {
    double wrap(double v) => ((v % len) + len) % len;
    final s = wrap(start), e = wrap(end);
    if (s <= e) return m.extractPath(s, e);
    return m.extractPath(s, len)..addPath(m.extractPath(0, e), Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _NeonPainter old) =>
      old.turn != turn || old.thickness != thickness || old.glow != glow;
}
