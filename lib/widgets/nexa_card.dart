import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/i18n.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/models.dart';

/// The physical card in 3D. It sways gently on its own, tilts when dragged,
/// flips when tapped, and a light sheen moves across the surface.
///
/// Performance: both faces are built once per rebuild and cached in
/// RepaintBoundaries; each animation frame only changes a transform and the sheen.
class NexaCard extends StatefulWidget {
  final CardProfile card;
  final String link;
  final bool interactive;
  final bool idle;
  final bool tiltable;
  final String? designOverride;

  const NexaCard({
    super.key,
    required this.card,
    required this.link,
    this.interactive = true,
    this.idle = true,
    this.tiltable = true,
    this.designOverride,
  });

  @override
  State<NexaCard> createState() => _NexaCardState();
}

class _NexaCardState extends State<NexaCard> with TickerProviderStateMixin {
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _tiltBack =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));
  final _tilt = ValueNotifier<Offset>(Offset.zero);
  Offset _tiltStart = Offset.zero;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _tiltBack.addListener(() {
      _tilt.value = Offset.lerp(_tiltStart, Offset.zero, Curves.elasticOut.transform(_tiltBack.value))!;
    });
    if (widget.idle) _idle.repeat();
  }

  @override
  void dispose() {
    _flip.dispose();
    _tiltBack.dispose();
    _idle.dispose();
    _tilt.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    Energy.instance.bump(0.6);
    if (_flip.status == AnimationStatus.completed || _flip.status == AnimationStatus.forward) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  double get _idleAngle => _dragging || !widget.idle ? 0.0 : _idle.value * 2 * math.pi;

  double _sheen() {
    final a = _idleAngle;
    return (math.sin(a) * 0.6 + _tilt.value.dx * 4 - _tilt.value.dy * 2).clamp(-1.5, 1.5);
  }

  @override
  Widget build(BuildContext context) {
    final design = CardDesign.byId(widget.designOverride ?? widget.card.design);
    final motion = Listenable.merge([_flip, _idle, _tilt]);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = w / 1.586;
      final front = CardFace(design: design, card: widget.card, link: widget.link, width: w, sheen: motion, sheenAt: _sheen);
      final back = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: CardFace(
            design: design, card: widget.card, link: widget.link, width: w, back: true, sheen: motion, sheenAt: () => -_sheen()),
      );
      final child = AnimatedBuilder(
        animation: motion,
        builder: (context, _) {
          final t = Curves.easeInOutBack.transform(_flip.value).clamp(0.0, 1.0);
          final angle = t * math.pi;
          final a = _idleAngle;
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateX(-_tilt.value.dy + 0.05 * math.cos(a))
            ..rotateY(angle + _tilt.value.dx + 0.10 * math.sin(a));
          return Transform(alignment: Alignment.center, transform: m, child: angle > math.pi / 2 ? back : front);
        },
      );
      final sized = SizedBox(width: w, height: h, child: child);
      if (!widget.interactive) return sized;
      if (!widget.tiltable) return GestureDetector(onTap: _toggle, child: sized);
      return GestureDetector(
        onTap: _toggle,
        onPanStart: (_) => _dragging = true,
        onPanUpdate: (d) {
          _tiltBack.stop();
          final cur = _tilt.value;
          _tilt.value = Offset(
            (cur.dx + d.delta.dx / 320).clamp(-0.45, 0.45),
            (cur.dy + d.delta.dy / 320).clamp(-0.35, 0.35),
          );
          Energy.instance.bump(0.03);
        },
        onPanEnd: (_) {
          _dragging = false;
          _tiltStart = _tilt.value;
          _tiltBack.forward(from: 0);
        },
        child: sized,
      );
    });
  }
}

/// A flat card face (front or back). Used inside the 3D card and for HD image export.
class CardFace extends StatelessWidget {
  final CardDesign design;
  final CardProfile card;
  final String link;
  final double width;
  final bool back;
  final Listenable? sheen;
  final double Function()? sheenAt;

  const CardFace({
    super.key,
    required this.design,
    required this.card,
    required this.link,
    required this.width,
    this.back = false,
    this.sheen,
    this.sheenAt,
  });

  @override
  Widget build(BuildContext context) {
    final h = width / 1.586;
    return Container(
      width: width,
      height: h,
      decoration: _cardBox(design),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18 * width / 340),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _PatternPainter(design)),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: back ? _BackContent(design: design, link: link, w: width, h: h) : _FrontContent(design: design, card: card, w: width),
              ),
            ),
            if (sheen != null && sheenAt != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: sheen!,
                    builder: (context, _) {
                      final pos = sheenAt!();
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.4 + pos, -1),
                            end: Alignment(0.2 + pos, 1),
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: design.premium ? 0.22 : 0.15),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: const [0.35, 0.5, 0.65],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardBox(CardDesign d) => BoxDecoration(
      color: d.gradient == null ? d.bg : null,
      gradient: d.gradient == null
          ? null
          : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: d.gradient!),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18)),
        BoxShadow(color: d.line.withValues(alpha: 0.16), blurRadius: 40, spreadRadius: -6),
      ],
    );

/// Surface textures for each finish (drawn once, then cached).
class _PatternPainter extends CustomPainter {
  final CardDesign d;
  _PatternPainter(this.d);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, s = w / 340;
    final p = Paint()..isAntiAlias = true;
    switch (d.pattern) {
      case CardPattern.none:
        break;
      case CardPattern.lines:
        p
          ..color = d.fg.withValues(alpha: 0.05)
          ..strokeWidth = 1 * s;
        for (double x = -h; x < w; x += 7 * s) {
          canvas.drawLine(Offset(x, h), Offset(x + h, 0), p);
        }
        break;
      case CardPattern.carbon:
        final a = Paint()..color = Colors.white.withValues(alpha: 0.05);
        final b = Paint()..color = Colors.black.withValues(alpha: 0.25);
        final c = 6 * s;
        for (double y = 0; y < h; y += c) {
          for (double x = 0; x < w; x += c) {
            final even = ((x / c).floor() + (y / c).floor()).isEven;
            canvas.drawRect(Rect.fromLTWH(x, y, c, c / 2), even ? a : b);
            canvas.drawRect(Rect.fromLTWH(x, y + c / 2, c, c / 2), even ? b : a);
          }
        }
        break;
      case CardPattern.dots:
        p.color = d.fg.withValues(alpha: 0.07);
        for (double y = 8 * s; y < h; y += 12 * s) {
          for (double x = 8 * s; x < w; x += 12 * s) {
            canvas.drawCircle(Offset(x, y), 1.1 * s, p);
          }
        }
        break;
      case CardPattern.waves:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * s
          ..color = d.line.withValues(alpha: 0.18);
        for (var i = 1; i <= 9; i++) {
          canvas.drawCircle(Offset(w * 1.05, h * 1.1), i * 28.0 * s, p);
        }
        break;
      case CardPattern.marble:
        final r = math.Random(11);
        p
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 9; i++) {
          final path = Path();
          var x = r.nextDouble() * w;
          var y = -10.0;
          path.moveTo(x, y);
          while (y < h + 10) {
            final nx = x + (r.nextDouble() - 0.5) * 60 * s;
            final ny = y + 18 * s + r.nextDouble() * 22 * s;
            path.quadraticBezierTo(x + (r.nextDouble() - 0.5) * 40 * s, (y + ny) / 2, nx, ny);
            x = nx;
            y = ny;
          }
          p
            ..strokeWidth = (0.6 + r.nextDouble() * 1.6) * s
            ..color = (i.isEven ? const Color(0xFF8A8A8A) : d.line).withValues(alpha: 0.16 + r.nextDouble() * 0.12);
          canvas.drawPath(path, p);
        }
        break;
      case CardPattern.grid:
        p
          ..color = d.line.withValues(alpha: 0.16)
          ..strokeWidth = 1 * s;
        final horizon = h * 0.35;
        for (var i = 0; i < 9; i++) {
          final z = i / 8;
          final y = horizon + (h - horizon) * z * z;
          canvas.drawLine(Offset(0, y), Offset(w, y), p);
        }
        for (var i = -8; i <= 8; i++) {
          canvas.drawLine(Offset(w / 2, horizon), Offset(w / 2 + i * w / 5, h), p);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.d.id != d.id;
}

class _FrontContent extends StatelessWidget {
  final CardDesign design;
  final CardProfile card;
  final double w;
  const _FrontContent({required this.design, required this.card, required this.w});

  @override
  Widget build(BuildContext context) {
    final s = w / 340;
    final name = card.str('name').isEmpty ? t('Your Name') : card.str('name');
    final title = card.str('title');
    final top = card.type == CardType.business ? card.str('company') : '';
    final logo = card.str('logo');
    return Padding(
      padding: EdgeInsets.all(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (logo.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(7 * s),
                  child: Image.network(logo,
                      filterQuality: FilterQuality.high,
                      width: 28 * s,
                      height: 28 * s,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                SizedBox(width: 8 * s),
              ],
              Expanded(
                child: Text(
                  top.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Fonts.body,
                    color: design.fg.withValues(alpha: 0.85),
                    fontSize: 11 * s,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Container(
                width: 26 * s,
                height: 20 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4 * s),
                  gradient: const LinearGradient(colors: [Color(0xFFE9D9A6), Color(0xFFB8A066)]),
                ),
              ),
              SizedBox(width: 6 * s),
              Icon(Ic.nfc, color: design.fg.withValues(alpha: 0.85), size: 20 * s),
            ],
          ),
          const Spacer(),
          Container(
              width: 26 * s,
              height: 3 * s,
              decoration: BoxDecoration(color: design.line, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 10 * s),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: Fonts.display, color: design.fg, fontSize: 21 * s, fontWeight: FontWeight.w800, letterSpacing: 0),
          ),
          if (title.isNotEmpty) ...[
            SizedBox(height: 3 * s),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: Fonts.body, color: design.fg.withValues(alpha: 0.72), fontSize: 13 * s),
            ),
          ],
          SizedBox(height: 14 * s),
          Row(
            children: [
              Text(
                card.type == CardType.business ? 'BUSINESS' : 'PERSONAL',
                style: TextStyle(
                    fontFamily: Fonts.body,
                    color: design.fg.withValues(alpha: 0.5),
                    fontSize: 9.5 * s,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'nexa tap',
                style: TextStyle(
                    fontFamily: Fonts.display,
                    color: design.fg.withValues(alpha: 0.75),
                    fontSize: 11.5 * s,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackContent extends StatelessWidget {
  final CardDesign design;
  final String link;
  final double w;
  final double h;
  const _BackContent({required this.design, required this.link, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    final s = w / 340;
    final qr = h * 0.58;
    return Padding(
      padding: EdgeInsets.all(18 * s),
      child: Row(
        children: [
          Container(
            width: qr,
            height: qr,
            padding: EdgeInsets.all(7 * s),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10 * s)),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF0B0D1A)),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF0B0D1A)),
            ),
          ),
          SizedBox(width: 18 * s),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Ic.nfc, color: design.fg, size: 26 * s),
                SizedBox(height: 10 * s),
                Text(t('Tap or scan'),
                    style: TextStyle(fontFamily: Fonts.display, color: design.fg, fontSize: 16 * s, fontWeight: FontWeight.w800)),
                SizedBox(height: 4 * s),
                Text(t('to save my contact'),
                    style: TextStyle(fontFamily: Fonts.body, color: design.fg.withValues(alpha: 0.72), fontSize: 12 * s)),
                SizedBox(height: 14 * s),
                Text('nexa tap',
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        color: design.fg.withValues(alpha: 0.6),
                        fontSize: 11.5 * s,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
