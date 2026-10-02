import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// One clock for every page, so the background never "jumps" between screens.
final Stopwatch _clock = Stopwatch()..start();
double get _now => _clock.elapsedMicroseconds / 1e6;

/// Fine film-grain texture drawn 1:1 with screen pixels for a crisp, premium finish.
class _Grain {
  static final image = ValueNotifier<ui.Image?>(null);
  static bool _loading = false;
  static Future<void> load() async {
    if (image.value != null || _loading) return;
    _loading = true;
    try {
      final data = await rootBundle.load('assets/textures/grain.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      image.value = (await codec.getNextFrame()).image;
    } catch (_) {
      _loading = false;
    }
  }
}

/// Vignette + grain. Painted once and cached, so it costs nothing per frame.
class _StaticLayers extends CustomPainter {
  final Palette p;
  final double dpr;
  _StaticLayers(this.p, this.dpr) : super(repaint: _Grain.image);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [Colors.transparent, Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.06)],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
    final g = _Grain.image.value;
    if (g != null && dpr > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(g, TileMode.repeated, TileMode.repeated, Matrix4.diagonal3Values(1 / dpr, 1 / dpr, 1).storage)
          ..color = Colors.white.withValues(alpha: p.isDark ? 0.035 : 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaticLayers old) => old.p != p || old.dpr != dpr;
}

/// Taps anywhere on screen leave a fading ring on the background.
class TouchRipples {
  static final List<(Offset, double)> items = [];
  static void add(Offset o) {
    items.add((o, _now));
    if (items.length > 8) items.removeAt(0);
    Energy.instance.bump(0.25);
  }
}

/// Full-screen animated background. Choice comes from [BackdropController].
class AnimatedBackdrop extends StatefulWidget {
  const AnimatedBackdrop({super.key});

  @override
  State<AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<AnimatedBackdrop> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _Grain.load();
    _ticker = createTicker((_) {
      final e = Energy.instance;
      if (e.value > 0.001) e.value = e.value * 0.965;
      _time.value = _now;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<Backdrop>(
          valueListenable: BackdropController.instance,
          builder: (context, kind, _) => Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(size: Size.infinite, painter: _BackdropPainter(kind: kind, p: p, time: _time)),
              RepaintBoundary(
                child: CustomPaint(size: Size.infinite, painter: _StaticLayers(p, MediaQuery.devicePixelRatioOf(context))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final Backdrop kind;
  final Palette p;
  final ValueNotifier<double> time;
  final bool touches;
  final double dpr;
  _BackdropPainter({required this.kind, required this.p, required this.time, this.touches = true, this.dpr = 0})
      : super(repaint: time);

  static final _rand = math.Random(7);
  static final List<List<double>> _points = List.generate(
    42,
    (_) => [_rand.nextDouble(), _rand.nextDouble(), (_rand.nextDouble() - 0.5) * 0.03, (_rand.nextDouble() - 0.5) * 0.03],
  );

  double get _k => p.isDark ? 1.0 : 0.6; // softer in light mode

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bg, p.bg2],
        ).createShader(rect),
    );
    final t = time.value;
    final e = Energy.instance.value;
    switch (kind) {
      case Backdrop.aurora:
        _aurora(canvas, size, t, e);
        break;
      case Backdrop.constellation:
        _network(canvas, size, t, e);
        break;
      case Backdrop.waves:
        _waves(canvas, size, t, e);
        break;
      case Backdrop.grid:
        _grid(canvas, size, t, e);
        break;
      case Backdrop.ripples:
        _rings(canvas, size, t, e);
        break;
      case Backdrop.none:
        break;
    }
    if (touches) _touches(canvas, t);
  }

  void _blob(Canvas c, Offset o, double r, Color col, double alpha) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(colors: [col.withValues(alpha: alpha), col.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  void _aurora(Canvas c, Size s, double t, double e) {
    final w = s.width, h = s.height;
    final sp = 0.18;
    final a = (0.32 + e * 0.25) * _k;
    _blob(c, Offset(w * (0.25 + 0.2 * math.sin(t * sp)), h * (0.2 + 0.1 * math.cos(t * sp * 1.3))), w * 0.9, p.accent2, a);
    _blob(c, Offset(w * (0.85 + 0.15 * math.cos(t * sp * 0.8)), h * (0.55 + 0.15 * math.sin(t * sp))), w * 0.75,
        p.accent, a * 0.55);
    _blob(c, Offset(w * (0.3 + 0.25 * math.sin(t * sp * 0.6 + 2)), h * (0.9 + 0.08 * math.cos(t * sp * 1.1))), w * 0.8,
        const Color(0xFFFF6FB5), a * 0.45);
  }

  void _network(Canvas c, Size s, double t, double e) {
    final pts = <Offset>[];
    for (final q in _points) {
      final x = ((q[0] + q[2] * t) % 1 + 1) % 1;
      final y = ((q[1] + q[3] * t) % 1 + 1) % 1;
      pts.add(Offset(x * s.width, y * s.height));
    }
    final maxD = s.width * 0.32;
    final line = Paint()..strokeWidth = 1;
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        final d = (pts[i] - pts[j]).distance;
        if (d < maxD) {
          line.color = p.accent2.withValues(alpha: (1 - d / maxD) * (0.35 + e * 0.4) * _k);
          c.drawLine(pts[i], pts[j], line);
        }
      }
    }
    final dot = Paint()..color = p.accent.withValues(alpha: (0.55 + e * 0.4) * _k);
    for (final o in pts) {
      c.drawCircle(o, 1.8, dot);
    }
  }

  void _waves(Canvas c, Size s, double t, double e) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 7; i++) {
      final baseY = s.height * (0.15 + i * 0.12);
      final amp = 18 + i * 4 + e * 26;
      final speed = 0.6 + i * 0.08;
      final path = Path();
      for (double x = 0; x <= s.width + 8; x += 8) {
        final y = baseY +
            math.sin(x / s.width * math.pi * 2 * (1 + i * 0.15) + t * speed) * amp +
            math.sin(x / 90 + t * 0.9) * 4;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      paint.color = (i.isEven ? p.accent2 : p.accent).withValues(alpha: (0.22 + e * 0.3) * _k);
      c.drawPath(path, paint);
    }
  }

  void _grid(Canvas c, Size s, double t, double e) {
    final horizon = s.height * 0.42;
    final paint = Paint()..strokeWidth = 1;
    _blob(c, Offset(s.width / 2, horizon), s.width * 0.6, p.accent, 0.18 * _k);
    const rows = 14;
    final speed = 0.25 + e * 0.6;
    for (var i = 0; i < rows; i++) {
      final z = ((i + t * speed * rows / 4) % rows) / rows;
      final y = horizon + (s.height - horizon) * z * z;
      paint.color = p.accent2.withValues(alpha: z * 0.55 * _k);
      c.drawLine(Offset(0, y), Offset(s.width, y), paint);
    }
    final vp = Offset(s.width / 2, horizon);
    for (var i = -10; i <= 10; i++) {
      final xb = s.width / 2 + i * s.width / 6;
      paint.color = p.accent2.withValues(alpha: 0.3 * _k);
      c.drawLine(vp, Offset(xb, s.height), paint);
    }
  }

  void _rings(Canvas c, Size s, double t, double e) {
    final center = Offset(s.width * 0.82, s.height * 0.22);
    final maxR = s.longestSide * 0.95;
    final paint = Paint()..style = PaintingStyle.stroke;
    const period = 2.2;
    for (var k = 0; k < 6; k++) {
      final age = ((t + k * period / 2) % (period * 3)) / (period * 3);
      final r = age * maxR;
      paint
        ..strokeWidth = 1.5 + (1 - age) * 3
        ..color = (k.isEven ? p.accent : p.accent2).withValues(alpha: (1 - age) * (0.35 + e * 0.3) * _k);
      c.drawCircle(center, r, paint);
    }
    _blob(c, center, 140, p.accent, 0.25 * _k);
  }

  void _touches(Canvas c, double t) {
    TouchRipples.items.removeWhere((r) => t - r.$2 > 1.1);
    final paint = Paint()..style = PaintingStyle.stroke;
    for (final (o, start) in TouchRipples.items) {
      final age = (t - start) / 1.1;
      paint
        ..strokeWidth = 2 * (1 - age) + 0.5
        ..color = p.accent.withValues(alpha: (1 - age) * 0.5 * _k);
      c.drawCircle(o, 12 + age * 140, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.kind != kind || old.p != p;
}

/// Small static preview tile of a backdrop style (used in pickers).
class BackdropSwatch extends StatelessWidget {
  final Backdrop kind;
  final bool selected;
  final VoidCallback onTap;
  const BackdropSwatch({super.key, required this.kind, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.m + 4),
          border: Border.all(color: selected ? p.accent : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.m),
                child: _MiniBackdrop(kind: kind),
              ),
            ),
            const SizedBox(height: 6),
            Text(kind.label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? p.text : p.muted)),
          ],
        ),
      ),
    );
  }
}

class _MiniBackdrop extends StatefulWidget {
  final Backdrop kind;
  const _MiniBackdrop({required this.kind});

  @override
  State<_MiniBackdrop> createState() => _MiniBackdropState();
}

class _MiniBackdropState extends State<_MiniBackdrop> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _time.value = _now)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _BackdropPainter(kind: widget.kind, p: Palette.of(context), time: _time, touches: false),
    );
  }
}
