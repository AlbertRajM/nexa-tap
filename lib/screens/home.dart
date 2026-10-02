import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/brand.dart';
import '../widgets/nexa_card.dart';
import 'card_editor.dart';
import 'order_form.dart';
import 'orders.dart';
import 'referrals.dart';
import 'share.dart';
import 'shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: p.accent,
            backgroundColor: p.surface,
            onRefresh: s.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.xxl),
              children: [
                Row(
                  children: [
                    const Wordmark(size: 18),
                    const Spacer(),
                    Pressable(
                      onTap: () => Shell.goTo(context, 3),
                      child: Avatar(name: profile.fullName, url: card?.str('avatar'), size: 36),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                FadeIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: TextStyles.muted(p)),
                      const SizedBox(height: 2),
                      Text(profile.firstName, style: TextStyles.title(p)),
                    ],
                  ),
                ),
                const SizedBox(height: Space.l),
                FadeIn(delayMs: 60, child: _LiveRow(active: profile.active)),
                const SizedBox(height: Space.l),
                if (card != null)
                  FadeIn(
                    delayMs: 120,
                    child: Column(
                      children: [
                        NexaCard(card: card, link: Repo.instance.link(profile, type: card.type)),
                        const SizedBox(height: 10),
                        Text('Tap the card to flip it', style: TextStyle(color: p.faint, fontSize: 12)),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.xl),
                FadeIn(
                  delayMs: 180,
                  child: Row(
                    children: [
                      _Action(
                        icon: Icons.ios_share_rounded,
                        label: 'Share',
                        onTap: card == null ? null : () => showShareSheet(context, profile, card),
                      ),
                      _Action(
                        icon: Icons.edit_outlined,
                        label: 'Edit card',
                        onTap: card == null
                            ? null
                            : () => Navigator.of(context).push(CardEditor.route(card)),
                      ),
                      _Action(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Order card',
                        onTap: () => Navigator.of(context).push(OrderForm.route()),
                      ),
                      _Action(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Invite',
                        onTap: () => Navigator.of(context).push(ReferralsScreen.route()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xl),
                FadeIn(
                  delayMs: 240,
                  child: Row(
                    children: [
                      _Stat(value: '${profile.views}', label: 'Profile views'),
                      const SizedBox(width: 10),
                      _Stat(value: '${s.orders.length}', label: 'Orders'),
                      const SizedBox(width: 10),
                      _Stat(
                        value: card == null ? '–' : '${(card.completeness * 100).round()}%',
                        label: 'Profile done',
                      ),
                    ],
                  ),
                ),
                if (card != null && card.completeness < 1) ...[
                  const SizedBox(height: Space.l),
                  FadeIn(delayMs: 280, child: _CompleteNudge(card: card)),
                ],
                const SizedBox(height: Space.xl),
                FadeIn(
                  delayMs: 320,
                  child: latest == null ? const _OrderPromo() : _LatestOrder(order: latest),
                ),
              ],
            ),
          ),
        );
      },
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: active ? p.success : p.faint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active ? 'Profile is live' : 'Profile is paused', style: TextStyles.h3(p)),
                const SizedBox(height: 2),
                Text(
                  active ? 'People who tap your card see your profile.' : 'Taps show a "profile unavailable" page.',
                  style: TextStyles.muted(p).copyWith(fontSize: 12.5),
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

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Action({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(Radii.l),
                border: Border.all(color: p.border),
              ),
              child: Icon(icon, color: p.text, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyles.number(p)),
            const SizedBox(height: 2),
            Text(label, style: TextStyles.label(p), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      onTap: () => Navigator.of(context).push(CardEditor.route(card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Finish your ${card.type.label.toLowerCase()} profile', style: TextStyles.h3(p))),
              Icon(Icons.chevron_right_rounded, color: p.muted),
            ],
          ),
          const SizedBox(height: 4),
          Text('Complete profiles get saved more often.', style: TextStyles.muted(p)),
          const SizedBox(height: Space.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: card.completeness),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: p.surface2,
                color: p.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderPromo extends StatelessWidget {
  const _OrderPromo();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Get your physical card', style: TextStyles.h3(p)),
                const SizedBox(height: 4),
                Text('NFC + QR card, programmed with your profile. ${formatRupees(AppConfig.cardPrice)} per card.',
                    style: TextStyles.muted(p)),
                const SizedBox(height: Space.m),
                NxButton('Order now',
                    expand: false,
                    height: 40,
                    onPressed: () => Navigator.of(context).push(OrderForm.route())),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Icon(Icons.contactless_outlined, size: 44, color: p.faint),
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
        SectionHeader('Latest order', action: 'View all', onAction: () => Shell.goTo(context, 2)),
        Panel(
          onTap: () => Navigator.of(context).push(OrderDetail.route(order)),
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
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: p.surface2,
                  color: order.status == 'cancelled' ? p.danger : p.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
