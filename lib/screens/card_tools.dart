import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/i18n.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/nexa_card.dart';

// ═══════════════════════════ Write to an NFC card ═══════════════════════════

Future<void> showNfcWriter(BuildContext context, CardProfile card) {
  final p = Palette.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: p.surfaceSolid,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    builder: (_) => _NfcWriter(card: card),
  );
}

enum _NfcState { checking, unavailable, waiting, writing, done, failed }

class _NfcWriter extends StatefulWidget {
  final CardProfile card;
  const _NfcWriter({required this.card});

  @override
  State<_NfcWriter> createState() => _NfcWriterState();
}

class _NfcWriterState extends State<_NfcWriter> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  _NfcState _state = _NfcState.checking;
  String _error = '';

  String get _url {
    final profile = AppState.instance.profile!;
    return Repo.instance.link(profile, type: widget.card.type, source: 'nfc');
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _state = _NfcState.checking);
    bool available = false;
    try {
      available = await NfcManager.instance.isAvailable();
    } catch (_) {}
    if (!mounted) return;
    if (!available) {
      setState(() => _state = _NfcState.unavailable);
      return;
    }
    setState(() => _state = _NfcState.waiting);
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          if (!mounted) return;
          setState(() => _state = _NfcState.writing);
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              throw Exception(t('This card cannot be written. Use a blank NTAG213/215/216 card or sticker.'));
            }
            await ndef.write(NdefMessage([NdefRecord.createUri(Uri.parse(_url))]));
            await NfcManager.instance.stopSession();
            HapticFeedback.heavyImpact();
            if (mounted) setState(() => _state = _NfcState.done);
          } catch (e) {
            await NfcManager.instance.stopSession(errorMessage: e.toString());
            if (mounted) {
              setState(() {
                _state = _NfcState.failed;
                _error = e.toString().replaceFirst('Exception: ', '');
              });
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _NfcState.failed;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = p.isDark ? p.accent : p.accent2;
    final (title, body) = switch (_state) {
      _NfcState.checking => (t('Checking NFC…'), ''),
      _NfcState.unavailable => (
          t('NFC is off or not supported'),
          t('Turn on NFC in your phone settings (Settings → Connections → NFC), then try again.')
        ),
      _NfcState.waiting => (
          t('Hold a blank NFC card to the back of your phone'),
          t('Keep it still for a second. Your profile link will be written onto the card.')
        ),
      _NfcState.writing => (t('Writing…'), t('Keep holding the card.')),
      _NfcState.done => (
          t('Card is ready!'),
          t('Tap this card on any phone and your profile opens instantly.')
        ),
      _NfcState.failed => (t('Could not write the card'), _error),
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 170,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  size: const Size(170, 170),
                  painter: _NfcRings(_pulse.value, _state == _NfcState.done ? p.success : c,
                      active: _state == _NfcState.waiting || _state == _NfcState.writing),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                      child: Container(
                        key: ValueKey(_state),
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: (_state == _NfcState.done ? p.success : (_state == _NfcState.failed ? p.danger : c))
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          switch (_state) {
                            _NfcState.done => Ic.checkCircle,
                            _NfcState.failed || _NfcState.unavailable => Ic.alert,
                            _ => Ic.nfc,
                          },
                          size: 34,
                          color: _state == _NfcState.done ? p.success : (_state == _NfcState.failed ? p.danger : c),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: TextStyles.h2(p)),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: TextStyles.muted(p)),
            ],
            const SizedBox(height: 22),
            if (_state == _NfcState.failed || _state == _NfcState.unavailable)
              NxButton(t('Try again'), icon: Ic.nfc, onPressed: _start)
            else if (_state == _NfcState.done)
              NxButton(t('Done'), onPressed: () => Navigator.of(context).pop())
            else
              NxButton(t('Cancel'), kind: BtnKind.secondary, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _NfcRings extends CustomPainter {
  final double v;
  final Color color;
  final bool active;
  _NfcRings(this.v, this.color, {required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      final a = (v + i / 3) % 1.0;
      paint.color = color.withValues(alpha: (1 - a) * 0.6);
      canvas.drawCircle(c, 40 + a * 45, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NfcRings old) => true;
}

// ═══════════════════════════ Download card images (HD) ═══════════════════════════

Future<void> showCardDownload(BuildContext context, CardProfile card) {
  final p = Palette.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: p.surfaceSolid,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    builder: (_) => _Download(card: card),
  );
}

class _Download extends StatefulWidget {
  final CardProfile card;
  const _Download({required this.card});

  @override
  State<_Download> createState() => _DownloadState();
}

class _DownloadState extends State<_Download> {
  final _front = GlobalKey();
  final _back = GlobalKey();
  final _qr = GlobalKey();
  String? _busy;

  Future<Uint8List> _capture(GlobalKey key) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 4); // ~1400px wide: HD
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _save(String what) async {
    setState(() => _busy = what);
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      final keys = switch (what) {
        'front' => [_front],
        'back' => [_back],
        'qr' => [_qr],
        _ => [_front, _back],
      };
      for (final k in keys) {
        await Gal.putImageBytes(await _capture(k));
      }
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, t('Saved to your gallery in HD'));
    } catch (e) {
      if (mounted) toast(context, t('Could not save. Allow photo access and try again.'), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final profile = AppState.instance.profile!;
    final link = Repo.instance.link(profile, type: widget.card.type, source: 'qr');
    final design = CardDesign.byId(widget.card.design);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Download your card'), style: TextStyles.h2(p)),
            const SizedBox(height: 4),
            Text(t('High-resolution images, ready to print or share.'), style: TextStyles.muted(p)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    key: _front,
                    child: CardFace(design: design, card: widget.card, link: link, width: 150),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RepaintBoundary(
                    key: _back,
                    child: CardFace(design: design, card: widget.card, link: link, width: 150, back: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                RepaintBoundary(
                  key: _qr,
                  child: Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(6),
                    color: Colors.white,
                    child: QrImageView(data: link, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(t('Your QR code on its own — add it to posters, flyers or your shop counter.'),
                      style: TextStyles.muted(p)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            NxButton(t('Save front and back'), icon: Ic.download, loading: _busy == 'both', onPressed: () => _save('both')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NxButton(t('Front'),
                      kind: BtnKind.secondary, loading: _busy == 'front', onPressed: () => _save('front')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NxButton(t('Back'), kind: BtnKind.secondary, loading: _busy == 'back', onPressed: () => _save('back')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NxButton(t('QR code'), kind: BtnKind.secondary, loading: _busy == 'qr', onPressed: () => _save('qr')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════ 3D phone preview ═══════════════════════════

/// Shows exactly what visitors see when they tap your card, inside a 3D phone.
class PhonePreview extends StatefulWidget {
  final CardType initial;
  const PhonePreview({super.key, this.initial = CardType.business});

  @override
  State<PhonePreview> createState() => _PhonePreviewState();
}

class _PhonePreviewState extends State<PhonePreview> with SingleTickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  late CardType _type = widget.initial;
  Offset _drag = Offset.zero;

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    final card = s.card(_type);
    return NxScaffold(
      title: t('Visitor preview'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.page, 4, Space.page, 0),
            child: HintCard(icon: Ic.eye, text: t('This is exactly what people see when they tap your card or scan your QR code.')),
          ),
          const SizedBox(height: 12),
          TypeSwitch(value: _type, onChanged: (v) => setState(() => _type = v)),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                _drag = Offset((_drag.dx + d.delta.dx / 300).clamp(-0.5, 0.5), (_drag.dy + d.delta.dy / 300).clamp(-0.3, 0.3));
              }),
              onPanEnd: (_) => setState(() => _drag = Offset.zero),
              child: Center(
                child: AnimatedBuilder(
                  animation: _sway,
                  builder: (context, child) {
                    final a = _sway.value * 2 * math.pi;
                    return TweenAnimationBuilder<Offset>(
                      tween: Tween(end: _drag),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, d, _) => Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateX(0.06 + 0.03 * math.cos(a) - d.dy)
                          ..rotateY(-0.22 + 0.08 * math.sin(a) + d.dx),
                        child: child,
                      ),
                    );
                  },
                  child: _PhoneFrame(
                    child: card == null
                        ? const SizedBox()
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: ProfileView(key: ValueKey(card.id), card: card),
                          ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(t('Drag to rotate · scroll inside the phone'), style: TextStyle(color: p.faint, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final h = math.min(c.maxHeight * 0.96, 600.0);
      final w = h / 2.05;
      return Container(
        width: w,
        height: h,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(w * 0.16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A3D4A), Color(0xFF15161C), Color(0xFF2A2C36)],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(18, 24)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.13),
          child: Stack(
            children: [
              Positioned.fill(child: child),
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: w * 0.3,
                    height: 20,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// A replica of the public profile page (same layout visitors get in the browser).
class ProfileView extends StatelessWidget {
  final CardProfile card;
  const ProfileView({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final d = CardDesign.byId(card.design);
    const bg = Color(0xFF0D0E14);
    const surface = Color(0xFF181A24);
    const text = Color(0xFFF4F5FA);
    const muted = Color(0xFFA3A8C3);
    final accent = Palette.dark.accent;
    final name = card.str('name').isEmpty ? t('Your Name') : card.str('name');
    final role = [card.str('title'), if (card.type == CardType.business) card.str('company')].where((e) => e.isNotEmpty).join(' · ');
    final moments = ((card.data['moments'] as List?) ?? const []).cast<String>();
    final rows = <(IconData, String)>[
      if (card.str('phone').isNotEmpty) (Ic.phone, '+91 ${card.str('phone')}'),
      if (card.str('email').isNotEmpty) (Ic.mail, card.str('email')),
      if (card.str('website').isNotEmpty) (Ic.globe, card.str('website')),
      if (card.str('address').isNotEmpty) (Ic.pin, card.str('address')),
      if (card.str('location').isNotEmpty) (Ic.pin, card.str('location')),
      for (final k in ['linkedin', 'instagram', 'x', 'facebook', 'youtube'])
        if (card.str(k).isNotEmpty) (Ic.link, card.str(k)),
    ];
    Widget chip(IconData i, String l) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Icon(i, size: 15, color: text),
              const SizedBox(height: 4),
              Text(l, style: const TextStyle(color: text, fontSize: 10)),
            ]),
          ),
        );
    return Container(
      color: bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 34, 10, 16),
        children: [
          Container(
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: d.gradient == null ? d.bg : null,
                    gradient: d.gradient == null ? null : LinearGradient(colors: d.gradient!),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(12, -26),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: surface, shape: BoxShape.circle),
                    child: Avatar(name: name, url: card.str('avatar'), size: 52),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(fontFamily: Fonts.display, color: text, fontSize: 16, fontWeight: FontWeight.w800)),
                        if (role.isNotEmpty) Text(role, style: const TextStyle(color: muted, fontSize: 11)),
                        if (card.str('bio').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(card.str('bio'), style: const TextStyle(color: text, fontSize: 11, height: 1.4)),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
                          child: Text(t('Save contact'),
                              style: const TextStyle(color: Color(0xFF0B0D1A), fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [chip(Ic.phone, t('Call')), chip(Ic.chat, 'WhatsApp'), chip(Ic.mail, t('Email'))]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (moments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(t('Moments'), style: const TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (final m in moments.take(9))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(m, fit: BoxFit.cover, filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => Container(color: surface)),
                  ),
              ],
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  for (final (i, r) in rows.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Colors.white10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Icon(r.$1, size: 14, color: muted),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(r.$2,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: text, fontSize: 11.5))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: accent.withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(10)),
            child: Text(t('Share my contact'), style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Business / Personal switch used across card screens.
class TypeSwitch extends StatelessWidget {
  final CardType value;
  final ValueChanged<CardType> onChanged;
  const TypeSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: Space.page),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: p.border)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: value == CardType.business ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 14)],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final ty in CardType.values)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(ty);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(ty == CardType.business ? Ic.briefcase : Ic.user,
                            size: 17, color: ty == value ? p.onAccent : p.muted),
                        const SizedBox(width: 8),
                        Text(tf('{x} card', ty.label),
                            style: TextStyle(
                              fontWeight: ty == value ? FontWeight.w700 : FontWeight.w500,
                              color: ty == value ? p.onAccent : p.muted,
                              fontSize: 14.5,
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
