import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/nexa_card.dart';
import 'card_editor.dart';
import 'share.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

/// 3D carousel of the user's cards with controls for the selected one.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final _pc = PageController(viewportFraction: 0.84);
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final profile = s.profile!;
        if (s.cards.isEmpty) {
          return EmptyState(icon: Ic.cards, title: t('No cards yet'), message: t('Pull down on Home to refresh.'));
        }
        final idx = _i.clamp(0, s.cards.length - 1);
        final card = s.cards[idx];
        final isDefault = profile.defaultCard == card.type.name;
        return ListView(
          padding: const EdgeInsets.only(top: Space.s, bottom: 48),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: Text(t('Swipe between your profiles. Turn one off to hide it.'), style: TextStyles.muted(p)),
            ),
            const SizedBox(height: Space.l),
            SizedBox(
              height: 250,
              child: PageView.builder(
                controller: _pc,
                itemCount: s.cards.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  Energy.instance.bump(0.4);
                  setState(() => _i = i);
                },
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _pc,
                  builder: (context, child) {
                    double d = (i - idx).toDouble();
                    if (_pc.hasClients && _pc.position.haveDimensions) d = (_pc.page ?? 0) - i;
                    final scale = 1 - (d.abs() * 0.12).clamp(0.0, 0.12);
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(d * 0.45)
                        ..scale(scale, scale, 1.0),
                      child: Opacity(opacity: (1 - d.abs() * 0.4).clamp(0.3, 1.0), child: child),
                    );
                  },
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: s.cards[i].enabled ? 1 : 0.45,
                        child: NexaCard(
                          card: s.cards[i],
                          link: Repo.instance.link(profile, type: s.cards[i].type),
                          tiltable: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < s.cards.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == idx ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == idx ? p.accent : p.faint.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: c),
                ),
                child: _Controls(key: ValueKey(card.id), card: card, isDefault: isDefault),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final CardProfile card;
  final bool isDefault;
  const _Controls({super.key, required this.card, required this.isDefault});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    final profile = s.profile!;
    return Column(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(Radii.m)),
                    child: Icon(card.type.icon, size: 21, color: p.isDark ? p.accent : p.accent2),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(tf('{x} profile', card.type.label), style: TextStyles.h3(p)),
                          const SizedBox(width: 8),
                          if (isDefault) Chip2(t('Default'), color: p.isDark ? p.accent : p.accent2),
                        ]),
                        const SizedBox(height: 2),
                        Text(card.type.blurb, style: TextStyles.muted(p).copyWith(fontSize: 13)),
                      ],
                    ),
                  ),
                  NxSwitch(
                    value: card.enabled,
                    onChanged: (v) async {
                      try {
                        await s.setEnabled(card, v);
                        if (context.mounted) toast(context, tf(v ? '{x} profile is on' : '{x} profile is off', card.type.label));
                      } catch (e) {
                        if (context.mounted) toast(context, friendlyError(e), error: true);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: Space.l),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: card.completeness),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: p.surface2,
                    color: p.accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('${(card.completeness * 100).round()}% complete', style: TextStyles.label(p)),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        Row(
          children: [
            Expanded(
              child: NxButton(t('Edit'),
                  icon: Ic.edit,
                  onPressed: () => Navigator.of(context).push(nxRoute(CardEditor(card: card)))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NxButton(t('Share'),
                  icon: Ic.share,
                  kind: BtnKind.secondary,
                  onPressed: card.enabled ? () => showShareSheet(context, profile, card) : null),
            ),
          ],
        ),
        if (!isDefault && card.enabled) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () async {
              try {
                await s.setDefault(card.type);
                if (context.mounted) toast(context, tf('Taps now open your {x} profile', card.type.label.toLowerCase()));
              } catch (e) {
                if (context.mounted) toast(context, friendlyError(e), error: true);
              }
            },
            icon: Icon(Ic.star, color: p.link, size: 19),
            label: Text(t('Make this the default'), style: TextStyle(color: p.link, fontWeight: FontWeight.w600, fontSize: 14.5)),
          ),
        ],
      ],
    );
  }
}
