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
      case Backdrop.sphere:
        _sphere(canvas, size, t, e);
        break;
      case Backdrop.warp:
        _warp(canvas, size, t, e);
        break;
      case Backdrop.terrain:
        _terrain(canvas, size, t, e);
        break;
      case Backdrop.cubes:
        _cubes(canvas, size, t, e);
        break;
      case Backdrop.helix:
        _helix(canvas, size, t, e);
        break;
      case Backdrop.tunnel:
        _tunnel(canvas, size, t, e);
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

  // ---------------------------------------------------------------- 3D scenes

  /// Motion phase that speeds up while the user taps or types, without jumps.
  static final _phases = Expando<List<double>>();
  double _phase(double t, double e) {
    final st = _phases[time] ??= <double>[t, 0.0];
    final dt = (t - st[0]).clamp(0.0, 0.1);
    st[0] = t;
    st[1] += dt * (1 + e * 3.5);
    return st[1];
  }

  Color get _mark => p.isDark ? p.accent : p.accent2;
  Color get _second => p.isDark ? p.accent2 : p.accent2.withValues(alpha: 0.8);

  static final List<List<double>> _globe = () {
    const n = 260;
    final golden = math.pi * (3 - math.sqrt(5));
    return List.generate(n, (i) {
      final y = 1 - (i / (n - 1)) * 2;
      final r = math.sqrt(1 - y * y);
      final th = golden * i;
      return [math.cos(th) * r, y, math.sin(th) * r];
    });
  }();

  void _sphere(Canvas c, Size s, double t, double e) {
    final ph = _phase(t, e);
    final center = Offset(s.width * 0.5, s.height * 0.34);
    final radius = s.width * 0.44 * (1 + e * 0.04);
    _blob(c, center, radius * 1.5, _second, 0.22 * _k);
    final ry = ph * 0.28;
    final rx = 0.42 + 0.12 * math.sin(t * 0.3);
    final cy = math.cos(ry), sy = math.sin(ry), cx = math.cos(rx), sx = math.sin(rx);
    final dot = Paint();
    for (final v in _globe) {
      final x1 = v[0] * cy + v[2] * sy;
      final z1 = -v[0] * sy + v[2] * cy;
      final y2 = v[1] * cx - z1 * sx;
      final z2 = v[1] * sx + z1 * cx;
      final persp = 2.8 / (2.8 - z2);
      final depth = (z2 + 1) / 2; // 0 back .. 1 front
      dot.color = Color.lerp(_second, _mark, depth)!.withValues(alpha: (0.15 + depth * 0.75) * _k);
      c.drawCircle(center + Offset(x1, y2) * radius * persp, 0.8 + depth * 1.9, dot);
    }
    // Orbit ring with a satellite, like a signal going round.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _mark.withValues(alpha: 0.28 * _k);
    final orbit = Rect.fromCenter(center: center, width: radius * 2.4, height: radius * 0.62);
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(-0.28);
    c.translate(-center.dx, -center.dy);
    c.drawOval(orbit, ring);
    final a = ph * 0.9;
    final sat = Offset(center.dx + math.cos(a) * orbit.width / 2, center.dy + math.sin(a) * orbit.height / 2);
    _blob(c, sat, 22, _mark, 0.55 * _k);
    c.drawCircle(sat, 3, Paint()..color = _mark.withValues(alpha: 0.95 * _k));
    c.restore();
  }

  static final List<List<double>> _stars =
      List.generate(170, (_) => [_rand.nextDouble() * 2 - 1, _rand.nextDouble() * 2 - 1, _rand.nextDouble()]);

  void _warp(Canvas c, Size s, double t, double e) {
    final ph = _phase(t, e) * 0.11;
    final center = Offset(s.width / 2, s.height * 0.4);
    _blob(c, center, s.width * 0.55, _second, 0.2 * _k);
    final paint = Paint()..strokeCap = StrokeCap.round;
    final scale = s.longestSide * 0.5;
    for (final st in _stars) {
      final d = ((st[2] - ph) % 1 + 1) % 1 * 0.97 + 0.03; // 1 far .. 0.03 near
      final d2 = math.min(1.0, d + 0.025 + e * 0.04);
      final p1 = center + Offset(st[0], st[1]) * (scale * 0.12 / d);
      final p2 = center + Offset(st[0], st[1]) * (scale * 0.12 / d2);
      if (p1.dx < -20 || p1.dy < -20 || p1.dx > s.width + 20 || p1.dy > s.height + 20) continue;
      final near = (1 - d);
      paint
        ..strokeWidth = 0.6 + near * 2.4
        ..color = (st[0] > 0 ? _mark : _second).withValues(alpha: (0.1 + near * 0.8) * _k);
      c.drawLine(p2, p1, paint);
    }
  }

  void _terrain(Canvas c, Size s, double t, double e) {
    final ph = _phase(t, e) * 0.07;
    final horizon = s.height * 0.36;
    _blob(c, Offset(s.width / 2, horizon), s.width * 0.7, _second, 0.25 * _k);
    const rows = 34, cols = 36;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (var r = rows - 1; r >= 0; r--) {
      final z = 0.16 + (r / (rows - 1)) * 0.84; // 1 far .. 0.16 near
      final zz = z + ph;
      final sc = 0.16 / z;
      final path = Path();
      for (var k = 0; k <= cols; k++) {
        final x = k / cols * 2 - 1;
        final hgt = math.sin(x * 3.1 + zz * 5.0) * 0.5 +
            math.sin(x * 6.3 - zz * 3.4 + 1.3) * 0.28 +
            math.sin(zz * 9.0 + x) * 0.22;
        final ridge = 0.35 + 0.65 * x * x; // valley in the middle
        final sx = s.width / 2 + x * sc * s.width * 2.8;
        final sy = horizon + sc * (s.height - horizon) * 0.95 - (hgt + 1) * ridge * sc * s.height * 0.28;
        if (k == 0) {
          path.moveTo(sx, sy);
        } else {
          path.lineTo(sx, sy);
        }
      }
      final near = 1 - (z - 0.16) / 0.84;
      paint
        ..strokeWidth = 0.7 + near * 1.3
        ..color = Color.lerp(_second, _mark, near)!.withValues(alpha: (0.12 + near * 0.55) * _k);
      c.drawPath(path, paint);
    }
  }

  static const _cubeEdges = [
    [0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7],
  ];
  static final List<List<double>> _cubeList = List.generate(
    8,
    (i) => [
      0.12 + _rand.nextDouble() * 0.76, // x
      0.06 + (i / 8) * 0.9 + _rand.nextDouble() * 0.05, // y
      0.06 + _rand.nextDouble() * 0.1, // size
      0.3 + _rand.nextDouble() * 0.5, // spin
      _rand.nextDouble() * 6, // phase
    ],
  );

  void _cubes(Canvas c, Size s, double t, double e) {
    final ph = _phase(t, e);
    final edge = Paint()..strokeWidth = 1.3;
    final face = Paint();
    for (var n = 0; n < _cubeList.length; n++) {
      final q = _cubeList[n];
      final size = q[2] * s.width;
      final center = Offset(q[0] * s.width + math.sin(t * 0.4 + q[4]) * 14, q[1] * s.height + math.cos(t * 0.5 + q[4]) * 18);
      final a = ph * q[3] + q[4], b = ph * q[3] * 0.7 + q[4] * 2;
      final ca = math.cos(a), sa = math.sin(a), cb = math.cos(b), sb = math.sin(b);
      final pts = <Offset>[];
      final zs = <double>[];
      for (var i = 0; i < 8; i++) {
        // Vertices 0-3: back square, 4-7: front square.
        final px = (i % 4 == 1 || i % 4 == 2) ? 1.0 : -1.0;
        final py = (i % 4 >= 2) ? 1.0 : -1.0;
        final pz = i < 4 ? -1.0 : 1.0;
        final x1 = px * ca + pz * sa;
        final z1 = -px * sa + pz * ca;
        final y2 = py * cb - z1 * sb;
        final z2 = py * sb + z1 * cb;
        final persp = 4 / (4 - z2);
        pts.add(center + Offset(x1, y2) * size * persp);
        zs.add(z2);
      }
      final col = n.isEven ? _mark : _second;
      face.color = col.withValues(alpha: 0.05 * _k);
      c.drawPath(Path()..addPolygon([pts[4], pts[5], pts[6], pts[7]], true), face);
      for (final ed in _cubeEdges) {
        final depth = ((zs[ed[0]] + zs[ed[1]]) / 2 + 1.8) / 3.6;
        edge.color = col.withValues(alpha: (0.15 + depth * 0.6) * _k);
        c.drawLine(pts[ed[0]], pts[ed[1]], edge);
      }
    }
  }

  void _helix(Canvas c, Size s, double t, double e) {
    final ph = _phase(t, e);
    void strand(double cy, double amp, double tilt, double speed, double strength) {
      const n = 46;
      final dot = Paint();
      final rung = Paint()..strokeWidth = 1;
      for (var i = 0; i <= n; i++) {
        final f = i / n;
        final x = -s.width * 0.1 + f * s.width * 1.2;
        final baseY = cy + (f - 0.5) * tilt;
        final ang = i * 0.36 + ph * speed;
        final sn = math.sin(ang), cs = math.cos(ang);
        final p1 = Offset(x, baseY + sn * amp);
        final p2 = Offset(x, baseY - sn * amp);
        final d1 = (cs + 1) / 2, d2 = (-cs + 1) / 2;
        if (i.isEven) {
          rung.shader = LinearGradient(colors: [
            _mark.withValues(alpha: (0.08 + d1 * 0.3) * strength * _k),
            _second.withValues(alpha: (0.08 + d2 * 0.3) * strength * _k),
          ]).createShader(Rect.fromPoints(p1, p2 + const Offset(1, 1)));
          c.drawLine(p1, p2, rung);
        }
        dot.color = _mark.withValues(alpha: (0.2 + d1 * 0.75) * strength * _k);
        c.drawCircle(p1, 1.2 + d1 * 3.2, dot);
        dot.color = _second.withValues(alpha: (0.2 + d2 * 0.75) * strength * _k);
        c.drawCircle(p2, 1.2 + d2 * 3.2, dot);
      }
    }

    _blob(c, Offset(s.width * 0.7, s.height * 0.25), s.width * 0.7, _second, 0.18 * _k);
    strand(s.height * 0.26, s.width * 0.13, s.height * 0.12, 0.9, 1.0);
    strand(s.height * 0.74, s.width * 0.09, -s.height * 0.08, -0.6, 0.55);
  }

  void _tunnel(Canvas c, Size s, double t, double e) {
    final ph = _phase(t, e) * 0.09;
    final center = Offset(s.width * (0.5 + 0.08 * math.sin(t * 0.35)), s.height * (0.4 + 0.05 * math.cos(t * 0.28)));
    _blob(c, center, s.width * 0.35, _mark, 0.22 * _k);
    const n = 16;
    final paint = Paint()..style = PaintingStyle.stroke;
    for (var k = 0; k < n; k++) {
      final d = (((k / n) - ph) % 1 + 1) % 1 * 0.96 + 0.04;
      final size = s.width * 0.1 / d;
      if (size > s.longestSide * 2.2) continue;
      final near = 1 - d;
      paint
        ..strokeWidth = 0.6 + near * 2.6
        ..color = (k.isEven ? _mark : _second).withValues(alpha: (0.06 + near * 0.6) * _k);
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(d * 1.4 + t * 0.08);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: size, height: size * 1.25), Radius.circular(size * 0.16)),
        paint,
      );
      c.restore();
    }
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
