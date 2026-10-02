import 'package:flutter/material.dart';

import '../core/theme.dart';

/// "nexa tap" wordmark with the tap glyph.
class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.35,
          height: size * 1.35,
          decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(size * 0.36)),
          child: Icon(Icons.contactless_outlined, color: p.onAccent, size: size * 0.95),
        ),
        SizedBox(width: size * 0.45),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'nexa', style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
            TextSpan(text: ' tap', style: TextStyle(fontWeight: FontWeight.w500, color: p.muted)),
          ]),
          style: TextStyle(fontSize: size, letterSpacing: -0.6),
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
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Opacity(
            opacity: ((v - 0.92) / 0.08).clamp(0.0, 1.0),
            child: Transform.scale(scale: v, child: child),
          ),
          child: const Wordmark(size: 28),
        ),
      ),
    );
  }
}
