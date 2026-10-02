import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

/// The physical card in 3D. It sways gently on its own, tilts when dragged,
/// flips when tapped, and a light sheen moves across the surface.
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
  Offset _tilt = Offset.zero;
  Offset _tiltStart = Offset.zero;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _tiltBack.addListener(() {
      setState(() => _tilt = Offset.lerp(_tiltStart, Offset.zero, Curves.elasticOut.transform(_tiltBack.value))!);
    });
    if (widget.idle) _idle.repeat();
  }

  @override
  void dispose() {
    _flip.dispose();
    _tiltBack.dispose();
    _idle.dispose();
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

  @override
  Widget build(BuildContext context) {
    final design = CardDesign.byId(widget.designOverride ?? widget.card.design);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = w / 1.586;
      final child = AnimatedBuilder(
        animation: Listenable.merge([_flip, _idle]),
        builder: (context, _) {
          final t = Curves.easeInOutBack.transform(_flip.value).clamp(0.0, 1.0);
          final angle = t * math.pi;
          final showBack = angle > math.pi / 2;
          final idleA = _dragging || !widget.idle ? 0.0 : _idle.value * 2 * math.pi;
          final ry = angle + _tilt.dx + 0.10 * math.sin(idleA);
          final rx = -_tilt.dy + 0.05 * math.cos(idleA);
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateX(rx)
            ..rotateY(ry);
          // Sheen follows the tilt and drifts slowly.
          final sheen = (math.sin(idleA) * 0.6 + _tilt.dx * 4 - _tilt.dy * 2).clamp(-1.5, 1.5);
          final face = showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: _CardBack(design: design, link: widget.link, w: w, h: h, sheen: -sheen),
                )
              : _CardFront(design: design, card: widget.card, w: w, h: h, sheen: sheen);
          return Transform(alignment: Alignment.center, transform: m, child: face);
        },
      );
      if (!widget.interactive) return SizedBox(width: w, height: h, child: child);
      if (!widget.tiltable) {
        return GestureDetector(onTap: _toggle, child: SizedBox(width: w, height: h, child: child));
      }
      return GestureDetector(
        onTap: _toggle,
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) {
          _tiltBack.stop();
          setState(() {
            _tilt = Offset(
              (_tilt.dx + d.delta.dx / 320).clamp(-0.45, 0.45),
              (_tilt.dy + d.delta.dy / 320).clamp(-0.35, 0.35),
            );
          });
          Energy.instance.bump(0.03);
        },
        onPanEnd: (_) {
          _dragging = false;
          _tiltStart = _tilt;
          _tiltBack.forward(from: 0);
        },
        child: SizedBox(width: w, height: h, child: child),
      );
    });
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
        BoxShadow(color: d.line.withValues(alpha: 0.18), blurRadius: 40, spreadRadius: -6),
      ],
    );

/// Light reflection band that moves across the card.
class _Sheen extends StatelessWidget {
  final double pos;
  const _Sheen(this.pos);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.4 + pos, -1),
                end: Alignment(0.2 + pos, 1),
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final CardDesign design;
  final CardProfile card;
  final double w;
  final double h;
  final double sheen;
  const _CardFront({required this.design, required this.card, required this.w, required this.h, required this.sheen});

  @override
  Widget build(BuildContext context) {
    final s = w / 340;
    final name = card.str('name').isEmpty ? t('Your Name') : card.str('name');
    final title = card.str('title');
    final top = card.type == CardType.business ? card.str('company') : '';
    final logo = card.str('logo');
    return Container(
      width: w,
      height: h,
      decoration: _cardBox(design),
      child: Stack(
        children: [
          // Decorative tap waves in the corner.
          Positioned(
            right: -30 * s,
            bottom: -30 * s,
            child: CustomPaint(size: Size(150 * s, 150 * s), painter: _WavesPainter(design.fg.withValues(alpha: 0.08))),
          ),
          Padding(
            padding: EdgeInsets.all(20 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (logo.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7 * s),
                        child: Image.network(logo, filterQuality: FilterQuality.high,
                            width: 28 * s, height: 28 * s, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                      ),
                    if (logo.isNotEmpty) SizedBox(width: 8 * s),
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
                    _Chip(color: design.fg, s: s),
                  ],
                ),
                const Spacer(),
                Container(width: 26 * s, height: 3 * s, decoration: BoxDecoration(color: design.line, borderRadius: BorderRadius.circular(2))),
                SizedBox(height: 10 * s),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: Fonts.display, color: design.fg, fontSize: 21 * s, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                if (title.isNotEmpty) ...[
                  SizedBox(height: 3 * s),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: Fonts.body, color: design.fg.withValues(alpha: 0.7), fontSize: 13 * s),
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
          ),
          _Sheen(sheen),
        ],
      ),
    );
  }
}

/// Small NFC chip + waves glyph.
class _Chip extends StatelessWidget {
  final Color color;
  final double s;
  const _Chip({required this.color, required this.s});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26 * s,
          height: 20 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4 * s),
            gradient: const LinearGradient(colors: [Color(0xFFE9D9A6), Color(0xFFB8A066)]),
          ),
        ),
        SizedBox(width: 6 * s),
        Icon(Ic.nfc, color: color.withValues(alpha: 0.85), size: 22 * s),
      ],
    );
  }
}

class _WavesPainter extends CustomPainter {
  final Color color;
  _WavesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07;
    final c = Offset(size.width * 0.2, size.height * 0.8);
    for (var i = 1; i <= 4; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: size.width * 0.22 * i), -math.pi / 2, math.pi / 2, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) => old.color != color;
}

class _CardBack extends StatelessWidget {
  final CardDesign design;
  final String link;
  final double w;
  final double h;
  final double sheen;
  const _CardBack({required this.design, required this.link, required this.w, required this.h, required this.sheen});

  @override
  Widget build(BuildContext context) {
    final s = w / 340;
    final qr = h * 0.58;
    return Container(
      width: w,
      height: h,
      decoration: _cardBox(design),
      child: Stack(
        children: [
          Padding(
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
                    dataModuleStyle:
                        const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF0B0D1A)),
                  ),
                ),
                SizedBox(width: 18 * s),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Ic.nfc, color: design.fg, size: 28 * s),
                      SizedBox(height: 10 * s),
                      Text(t('Tap or scan'),
                          style: TextStyle(
                              fontFamily: Fonts.display, color: design.fg, fontSize: 16 * s, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4 * s),
                      Text(t('to save my contact'),
                          style: TextStyle(fontFamily: Fonts.body, color: design.fg.withValues(alpha: 0.7), fontSize: 12 * s)),
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
          ),
          _Sheen(sheen),
        ],
      ),
    );
  }
}
