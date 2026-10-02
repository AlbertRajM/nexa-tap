import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/models.dart';

/// Renders the physical card. Tap to flip, drag to tilt.
class NexaCard extends StatefulWidget {
  final CardProfile card;
  final String link;
  final bool interactive;
  final String? designOverride;

  const NexaCard({super.key, required this.card, required this.link, this.interactive = true, this.designOverride});

  @override
  State<NexaCard> createState() => _NexaCardState();
}

class _NexaCardState extends State<NexaCard> with TickerProviderStateMixin {
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _tiltBack =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  Offset _tilt = Offset.zero;
  Offset _tiltStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tiltBack.addListener(() {
      setState(() => _tilt = Offset.lerp(_tiltStart, Offset.zero, Curves.easeOutBack.transform(_tiltBack.value))!);
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    _tiltBack.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
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
        animation: _flip,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_flip.value);
          final angle = t * math.pi;
          final showBack = angle > math.pi / 2;
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-_tilt.dy)
            ..rotateY(angle + _tilt.dx);
          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: _CardBack(design: design, link: widget.link, w: w, h: h),
                  )
                : _CardFront(design: design, card: widget.card, w: w, h: h),
          );
        },
      );
      if (!widget.interactive) return SizedBox(width: w, height: h, child: child);
      return GestureDetector(
        onTap: _toggle,
        onPanUpdate: (d) {
          _tiltBack.stop();
          setState(() {
            _tilt = Offset(
              (_tilt.dx + d.delta.dx / 400).clamp(-0.22, 0.22),
              (_tilt.dy + d.delta.dy / 400).clamp(-0.22, 0.22),
            );
          });
        },
        onPanEnd: (_) {
          _tiltStart = _tilt;
          _tiltBack.forward(from: 0);
        },
        child: SizedBox(width: w, height: h, child: child),
      );
    });
  }
}

BoxDecoration _cardBox(CardDesign d) => BoxDecoration(
      color: d.bg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: d.fg.withValues(alpha: 0.06)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 12)),
      ],
    );

class _CardFront extends StatelessWidget {
  final CardDesign design;
  final CardProfile card;
  final double w;
  final double h;
  const _CardFront({required this.design, required this.card, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    final s = w / 340; // scale text with card width
    final name = card.str('name').isEmpty ? 'Your Name' : card.str('name');
    final title = card.str('title');
    final top = card.type == CardType.business ? card.str('company') : '';
    final logo = card.str('logo');
    return Container(
      width: w,
      height: h,
      padding: EdgeInsets.all(20 * s),
      decoration: _cardBox(design),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (logo.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6 * s),
                  child: Image.network(logo,
                      width: 28 * s, height: 28 * s, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              if (logo.isNotEmpty) SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  top.isEmpty ? '' : top.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: design.fg.withValues(alpha: 0.85),
                    fontSize: 11 * s,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Icon(Icons.contactless_outlined, color: design.fg.withValues(alpha: 0.8), size: 24 * s),
            ],
          ),
          const Spacer(),
          Container(width: 22 * s, height: 2 * s, color: design.line),
          SizedBox(height: 10 * s),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: design.fg, fontSize: 21 * s, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          if (title.isNotEmpty) ...[
            SizedBox(height: 3 * s),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: design.fg.withValues(alpha: 0.65), fontSize: 12.5 * s),
            ),
          ],
          SizedBox(height: 14 * s),
          Row(
            children: [
              Text(
                card.type == CardType.business ? 'BUSINESS' : 'PERSONAL',
                style: TextStyle(
                    color: design.fg.withValues(alpha: 0.45), fontSize: 9 * s, letterSpacing: 1.6, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'nexa tap',
                style: TextStyle(
                    color: design.fg.withValues(alpha: 0.6), fontSize: 11 * s, fontWeight: FontWeight.w700, letterSpacing: -0.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final CardDesign design;
  final String link;
  final double w;
  final double h;
  const _CardBack({required this.design, required this.link, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    final s = w / 340;
    final qr = h * 0.56;
    return Container(
      width: w,
      height: h,
      padding: EdgeInsets.all(18 * s),
      decoration: _cardBox(design),
      child: Row(
        children: [
          Container(
            width: qr,
            height: qr,
            padding: EdgeInsets.all(6 * s),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8 * s)),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle:
                  const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
            ),
          ),
          SizedBox(width: 18 * s),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.contactless_outlined, color: design.fg, size: 26 * s),
                SizedBox(height: 10 * s),
                Text('Tap or scan',
                    style: TextStyle(color: design.fg, fontSize: 15 * s, fontWeight: FontWeight.w700)),
                SizedBox(height: 4 * s),
                Text('to save my contact',
                    style: TextStyle(color: design.fg.withValues(alpha: 0.65), fontSize: 11.5 * s)),
                SizedBox(height: 14 * s),
                Text('nexa tap',
                    style: TextStyle(
                        color: design.fg.withValues(alpha: 0.55), fontSize: 11 * s, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
