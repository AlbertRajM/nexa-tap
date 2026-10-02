import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/nexa_card.dart';
import 'card_editor.dart';
import 'order_form.dart';
import 'orders.dart';
import 'referrals.dart';
import 'share.dart';
import 'shell.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return t('Good morning,');
    if (h < 17) return t('Good afternoon,');
    return t('Good evening,');
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final profile = s.profile!;
        final card = s.primaryCard;
        final latest = s.orders.isEmpty ? null : s.orders.first;
        return RefreshIndicator(
          color: p.onAccent,
          backgroundColor: p.accent,
          onRefresh: s.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, 48),
            children: [
              FadeIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(), style: TextStyles.muted(p).copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(profile.firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyles.display(p)),
                    const SizedBox(height: 8),
                    Container(width: 36, height: 3, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
                  ],
                ),
              ),
              const SizedBox(height: Space.l),
              FadeIn(delayMs: 80, child: _LiveRow(active: profile.active)),
              const SizedBox(height: Space.xl),
              if (card != null)
                FadeIn(
                  delayMs: 140,
                  child: Column(
                    children: [
                      NexaCard(card: card, link: Repo.instance.link(profile, type: card.type)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Ic.pointer, size: 15, color: p.faint),
                          const SizedBox(width: 6),
                          Text(t('Tap to flip · drag to tilt'), style: TextStyle(color: p.faint, fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.xl),
              Row(
                children: [
                  _Action(
                    i: 0,
                    icon: Ic.share,
                    label: t('Share'),
                    onTap: card == null ? null : () => showShareSheet(context, profile, card),
                  ),
                  _Action(
                    i: 1,
                    icon: Ic.edit,
                    label: t('Edit'),
                    onTap: card == null ? null : () => Navigator.of(context).push(nxRoute(CardEditor(card: card))),
                  ),
                  _Action(
                    i: 2,
                    icon: Ic.bag,
                    label: t('Order'),
                    onTap: () => Navigator.of(context).push(nxRoute(const OrderForm())),
                  ),
                  _Action(
                    i: 3,
                    icon: Ic.gift,
                    label: t('Invite'),
                    onTap: () => Navigator.of(context).push(nxRoute(const ReferralsScreen())),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              FadeIn(
                delayMs: 300,
                child: Row(
                  children: [
                    _Stat(value: profile.views, label: t('Profile views'), icon: Ic.eye),
                    const SizedBox(width: 10),
                    _Stat(value: s.orders.length, label: t('Orders'), icon: Ic.package),
                  ],
                ),
              ),
              if (card != null && card.completeness < 1) ...[
                const SizedBox(height: Space.m),
                FadeIn(delayMs: 360, child: _CompleteNudge(card: card)),
              ],
              const SizedBox(height: Space.xl),
              FadeIn(
                delayMs: 420,
                child: latest == null ? const _OrderPromo() : _LatestOrder(order: latest),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Text painted with the lime → violet gradient.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GradientText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        colors: p.isDark ? [p.accent, p.accent2] : [p.accent2, const Color(0xFFE0365A)],
      ).createShader(r),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}

class _LiveRow extends StatelessWidget {
  final bool active;
  const _LiveRow({required this.active});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
      child: Row(
        children: [
          _PulseDot(active: active),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(active ? t('Profile is live') : t('Profile is paused'),
                      key: ValueKey(active), style: TextStyles.h3(p)),
                ),
                const SizedBox(height: 2),
                Text(
                  active ? t('Anyone who taps your card sees it.') : t('Taps show "profile unavailable".'),
                  style: TextStyles.muted(p).copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          NxSwitch(
            value: active,
            onChanged: (v) async {
              try {
                await AppState.instance.setActive(v);
              } catch (e) {
                if (context.mounted) toast(context, friendlyError(e), error: true);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool active;
  const _PulseDot({required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = widget.active ? p.success : p.faint;
    return SizedBox(
      width: 22,
      height: 22,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.active)
              Container(
                width: 10 + 12 * _c.value,
                height: 10 + 12 * _c.value,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.4 * (1 - _c.value))),
              ),
            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final int i;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Action({required this.i, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 420 + i * 80),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Transform.translate(offset: Offset(0, 14 * (1 - v)), child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
        child: Pressable(
          onTap: onTap,
          scale: 0.92,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.border),
                ),
                child: Icon(icon, color: p.text, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  const _Stat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Panel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountUp(value, style: TextStyles.number(p)),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyles.label(p), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(icon, color: p.faint, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CompleteNudge extends StatelessWidget {
  final CardProfile card;
  const _CompleteNudge({required this.card});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      onTap: () => Navigator.of(context).push(nxRoute(CardEditor(card: card))),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: card.completeness),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CustomPaint(
                painter: _RingPainter(v, p.accent, p.surface2),
                child: Center(
                  child: Text('${(v * 100).round()}%',
                      style: TextStyle(fontFamily: Fonts.display, fontWeight: FontWeight.w800, fontSize: 13, color: p.text)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tf('Finish your {x} profile', card.type.label.toLowerCase()), style: TextStyles.h3(p)),
                const SizedBox(height: 2),
                Text(t('Complete profiles get saved more often.'), style: TextStyles.muted(p).copyWith(fontSize: 13)),
              ],
            ),
          ),
          Icon(Ic.chevronRight, size: 16, color: p.muted),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color fg;
  final Color bg;
  _RingPainter(this.v, this.fg, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, paint..color = bg);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, paint..color = fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v;
}

class _OrderPromo extends StatelessWidget {
  const _OrderPromo();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      glow: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Get your physical card'), style: TextStyles.h2(p)),
                const SizedBox(height: 6),
                Text('${t('NFC chip + QR code, programmed for you')} · ${tf('{x} per card', formatRupees(AppConfig.cardPrice))}',
                    style: TextStyles.muted(p)),
                const SizedBox(height: Space.l),
                NxButton(t('Order now'),
                    expand: false,
                    height: 44,
                    icon: Ic.arrowRight,
                    onPressed: () => Navigator.of(context).push(nxRoute(const OrderForm()))),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Floating(child: Icon(Ic.nfc, size: 56, color: p.isDark ? p.accent : p.accent2)),
        ],
      ),
    );
  }
}

class _LatestOrder extends StatelessWidget {
  final Order order;
  const _LatestOrder({required this.order});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final idx = OrderStatus.index(order.status);
    final progress = idx < 0 ? 0.0 : (idx + 1) / OrderStatus.steps.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(t('Latest order'), action: t('View all'), onAction: () => Shell.goTo(context, 2)),
        Panel(
          onTap: () => Navigator.of(context).push(nxRoute(OrderDetail(order: order))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('#${order.orderNo}', style: TextStyles.h3(p))),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(OrderStatus.detail(order.status), style: TextStyles.muted(p)),
              const SizedBox(height: Space.m),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 7,
                    backgroundColor: p.surface2,
                    color: order.status == 'cancelled' ? p.danger : p.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
