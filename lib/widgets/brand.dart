import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'backdrop.dart';

/// The Nexa Tap mark: an "N" whose right stroke turns into tap waves.
/// It draws itself in, then the waves keep pulsing like an NFC signal.
class NexaLogo extends StatefulWidget {
  final double size;
  final bool animate;
  final Color? color;
  const NexaLogo({super.key, this.size = 40, this.animate = true, this.color});

  @override
  State<NexaLogo> createState() => _NexaLogoState();
}

class _NexaLogoState extends State<NexaLogo> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _intro.forward();
      _pulse.repeat();
    } else {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Palette.of(context).accent;
    return SizedBox(
      width: widget.size,
      height: widget.size * 427 / 620,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _pulse]),
        builder: (context, _) => CustomPaint(
          painter: _LogoPainter(
            draw: Curves.easeInOutCubic.transform(_intro.value),
            pulse: widget.animate ? _pulse.value : -1,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double draw;
  final double pulse;
  final Color color;
  _LogoPainter({required this.draw, required this.pulse, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 620;
    canvas.save();
    canvas.scale(k);
    canvas.translate(-300, -297);

    // The N: stem up, then diagonal down.
    final n = Path()
      ..moveTo(346, 678)
      ..lineTo(346, 346)
      ..lineTo(560, 678);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 92
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final nDraw = (draw / 0.65).clamp(0.0, 1.0);
    for (final m in n.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * nDraw), stroke);
    }

    // Tap waves.
    final arcs = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 62;
    const center = Offset(560, 678);
    for (var i = 0; i < 3; i++) {
      final r = 150.0 + i * 100;
      final appear = ((draw - 0.55 - i * 0.12) / 0.2).clamp(0.0, 1.0);
      var alpha = appear;
      if (pulse >= 0 && draw >= 1) {
        final phase = (pulse - i * 0.18) % 1.0;
        alpha = 0.35 + 0.65 * math.max(0, math.sin(phase * math.pi));
      }
      arcs.color = color.withValues(alpha: alpha);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, (70 * math.pi / 180) * appear, false, arcs);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.draw != draw || old.pulse != pulse || old.color != color;
}

/// Logo + "nexa tap" wordmark.
class Wordmark extends StatelessWidget {
  final double size;
  final bool animate;
  const Wordmark({super.key, this.size = 22, this.animate = true});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NexaLogo(size: size * 1.5, animate: animate, color: p.isDark ? p.accent : p.accent2),
        SizedBox(width: size * 0.5),
        Text(
          'nexa tap',
          style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: p.text,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackdrop()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NexaLogo(size: 120, color: p.isDark ? p.accent : p.accent2),
                const SizedBox(height: 28),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child),
                  ),
                  child: Text(
                    'nexa tap',
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                      letterSpacing: -0.8,
                    ),
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
