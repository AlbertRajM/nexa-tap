import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/models.dart';
import '../widgets/backdrop.dart';
import '../widgets/brand.dart';
import '../widgets/nexa_card.dart';
import '../core/i18n.dart';
import '../widgets/lang_picker.dart';
import '../core/icons.dart';

/// First-launch introduction with 3D visuals and a background picker.
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomeScreen({super.key, required this.onDone});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _page = PageController();
  int _index = 0;

  static const _titles = [
    'Tap. Share.\nConnect.',
    'One card,\ntwo identities.',
    'From print\nto your door.',
    'Make it\nyours.',
  ];
  static const _bodies = [
    'Your contact details live on a smart NFC card. One tap on any phone opens your profile — no app needed.',
    'Switch between a business and a personal profile anytime. Choose which one opens when someone taps.',
    'Order a premium card and follow every step: printing, chip encoding, quality check and delivery.',
    'Pick the moving background you like. You can change it later in Account.',
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await WelcomeFlag.markSeen();
    widget.onDone();
  }

  void _next() {
    if (_index == _titles.length - 1) {
      _finish();
    } else {
      _page.nextPage(duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final last = _index == _titles.length - 1;
    return Scaffold(
      backgroundColor: p.bg,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => TouchRipples.add(e.position),
        child: Stack(
          children: [
            const Positioned.fill(child: AnimatedBackdrop()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(
                      children: [
                        const Wordmark(size: 18),
                        const Spacer(),
                        const LanguageButton(),
                        AnimatedOpacity(
                          opacity: last ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: TextButton(
                            onPressed: last ? null : _finish,
                            child: Text(t('Skip'), style: TextStyle(color: p.muted, fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      itemCount: _titles.length,
                      onPageChanged: (i) {
                        HapticFeedback.selectionClick();
                        Energy.instance.bump(0.5);
                        setState(() => _index = i);
                      },
                      itemBuilder: (context, i) => AnimatedBuilder(
                        animation: _page,
                        builder: (context, child) {
                          double delta = 0;
                          if (_page.hasClients && _page.position.haveDimensions) {
                            delta = (_page.page ?? 0) - i;
                          }
                          // 3D page turn: rotate around Y and fade.
                          return Opacity(
                            opacity: (1 - delta.abs()).clamp(0.0, 1.0),
                            child: Transform(
                              alignment: delta > 0 ? Alignment.centerRight : Alignment.centerLeft,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(delta * -0.7),
                              child: child,
                            ),
                          );
                        },
                        child: _Slide(
                          index: i,
                          title: t(_titles[i]),
                          body: t(_bodies[i]),
                          active: i == _index,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Row(
                      children: [
                        for (var i = 0; i < _titles.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _index ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _index ? p.accent : p.faint.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        const Spacer(),
                        SizedBox(
                          width: 170,
                          child: NxButton(
                            last ? t('Get started') : t('Next'),
                            icon: last ? Ic.arrowRight : null,
                            onPressed: _next,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final int index;
  final String title;
  final String body;
  final bool active;
  const _Slide({required this.index, required this.title, required this.body, required this.active});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final visual = switch (index) {
      0 => const _TapVisual(),
      1 => const _TwoCardsVisual(),
      2 => const _TrackVisual(),
      _ => const _BackdropPicker(),
    };
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: index == 3 ? 260 : 300, child: Center(child: visual)),
              const SizedBox(height: 28),
              if (active) TypewriterText(title, style: TextStyles.display(p).copyWith(fontSize: 34)) else Text(title, style: TextStyles.display(p).copyWith(fontSize: 34)),
              const SizedBox(height: 14),
              AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: Text(body, style: TextStyles.muted(p).copyWith(fontSize: 16, height: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reveals text character by character with a blinking caret.
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const TypewriterText(this.text, {super.key, required this.style});

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: 45 * widget.text.length))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final n = (widget.text.length * _c.value).round();
        final done = _c.isCompleted;
        return Text.rich(
          TextSpan(children: [
            TextSpan(text: widget.text.substring(0, n)),
            TextSpan(
              text: done ? '' : '▍',
              style: TextStyle(color: p.isDark ? p.accent : p.accent2),
            ),
            // Keeps layout height stable while typing.
            TextSpan(text: widget.text.substring(n), style: const TextStyle(color: Colors.transparent)),
          ]),
          style: widget.style,
        );
      },
    );
  }
}

CardProfile _demo(String design, CardType type, String name, String title, [String company = '']) => CardProfile(
      id: 'demo-$design',
      type: type,
      enabled: true,
      design: design,
      data: {'name': name, 'title': title, 'company': company},
    );

/// Card floating over expanding NFC rings, with a phone "tapping" it.
class _TapVisual extends StatefulWidget {
  const _TapVisual();

  @override
  State<_TapVisual> createState() => _TapVisualState();
}

class _TapVisualState extends State<_TapVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        // phone moves in, taps, moves out
        final approach = v < 0.4 ? Curves.easeOutCubic.transform(v / 0.4) : (v < 0.7 ? 1.0 : 1 - Curves.easeInCubic.transform((v - 0.7) / 0.3));
        final tapped = v > 0.38 && v < 0.75;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            CustomPaint(size: const Size(300, 300), painter: _RingsPainter(v, p.accent, tapped)),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateX(0.55)
                ..rotateZ(-0.18),
              child: SizedBox(
                width: 250,
                child: NexaCard(
                  card: _demo('volt', CardType.business, 'Albert Raj', 'Founder', 'Nexa Tap'),
                  link: 'https://nexatap.in',
                  interactive: false,
                ),
              ),
            ),
            Positioned(
              right: 10 + 30 * (1 - approach),
              top: -30 + 80 * approach,
              child: Opacity(
                opacity: approach.clamp(0.0, 1.0),
                child: Transform.rotate(angle: 0.35, child: _Phone(glow: tapped, p: p)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Phone extends StatelessWidget {
  final bool glow;
  final Palette p;
  const _Phone({required this.glow, required this.p});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 70,
      height: 130,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(color: (glow ? p.accent : Colors.black).withValues(alpha: glow ? 0.6 : 0.4), blurRadius: glow ? 28 : 14),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: glow ? p.accent : const Color(0xFF0B0D1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: glow
                ? const Icon(Ic.userPlus, key: ValueKey(1), color: Color(0xFF0B0D1A), size: 26)
                : const Icon(Ic.nfc, key: ValueKey(2), color: Colors.white54, size: 24),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double v;
  final Color color;
  final bool strong;
  _RingsPainter(this.v, this.color, this.strong);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < 4; i++) {
      final a = (v + i / 4) % 1.0;
      paint
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - a) * (strong ? 0.6 : 0.25));
      canvas.drawCircle(c, 60 + a * 110, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => true;
}

/// Two cards orbiting in 3D and swapping places.
class _TwoCardsVisual extends StatefulWidget {
  const _TwoCardsVisual();

  @override
  State<_TwoCardsVisual> createState() => _TwoCardsVisualState();
}

class _TwoCardsVisualState extends State<_TwoCardsVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _demo('ultraviolet', CardType.business, 'Albert Raj', 'Sales Director', 'Orbit Labs'),
      _demo('holo', CardType.personal, 'Albert Raj', 'Photographer'),
    ];
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final a = _c.value * 2 * math.pi;
        final items = <(double, Widget)>[];
        for (var i = 0; i < 2; i++) {
          final ang = a + i * math.pi;
          final z = math.cos(ang); // depth: 1 front, -1 back
          final x = math.sin(ang) * 70;
          final scale = 0.82 + 0.18 * (z + 1) / 2;
          items.add((
            z,
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..translate(x, -z * 10)
                ..rotateY(math.sin(ang) * 0.5)
                ..scale(scale),
              child: Opacity(
                opacity: 0.55 + 0.45 * (z + 1) / 2,
                child: SizedBox(width: 240, child: NexaCard(card: cards[i], link: 'https://nexatap.in', interactive: false, idle: false)),
              ),
            ),
          ));
        }
        items.sort((x, y) => x.$1.compareTo(y.$1)); // back first
        return Stack(alignment: Alignment.center, children: [for (final it in items) it.$2]);
      },
    );
  }
}

/// Order timeline that fills itself step by step.
class _TrackVisual extends StatefulWidget {
  const _TrackVisual();

  @override
  State<_TrackVisual> createState() => _TrackVisualState();
}

class _TrackVisualState extends State<_TrackVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  static const _steps = [
    (Ic.receipt, 'Order placed'),
    (Ic.printer, 'Printing & encoding'),
    (Ic.badge, 'Quality check'),
    (Ic.truck, 'Out for delivery'),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      glow: true,
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final progress = (_c.value * 1.25).clamp(0.0, 1.0) * _steps.length;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: progress > i ? p.accent : p.surface2,
                          shape: BoxShape.circle,
                          boxShadow: progress > i && progress < i + 1
                              ? [BoxShadow(color: p.accent.withValues(alpha: 0.6), blurRadius: 18)]
                              : null,
                        ),
                        child: Icon(_steps[i].$1, size: 20, color: progress > i ? p.onAccent : p.faint),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        t(_steps[i].$2),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: progress > i ? FontWeight.w600 : FontWeight.w400,
                          color: progress > i ? p.text : p.faint,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BackdropPicker extends StatelessWidget {
  const _BackdropPicker();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Backdrop>(
      valueListenable: BackdropController.instance,
      builder: (context, current, _) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
        children: [
          for (final b in Backdrop.values)
            BackdropSwatch(kind: b, selected: b == current, onTap: () => BackdropController.instance.set(b)),
        ],
      ),
    );
  }
}
