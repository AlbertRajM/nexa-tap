import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/nexa_card.dart';
import 'card_editor.dart';
import 'card_tools.dart';
import 'share.dart';

/// Business and Personal cards side by side, with every action in one place.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  CardType _type = CardType.business;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final profile = s.profile!;
        final card = s.card(_type);
        if (card == null) {
          return EmptyState(icon: Ic.cards, title: t('No cards yet'), message: t('Pull down on Home to refresh.'));
        }
        final isDefault = profile.defaultCard == card.type.name;
        return ListView(
          padding: const EdgeInsets.only(top: Space.s, bottom: 48),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: HintCard(
                icon: Ic.idCard,
                text: t('You have two cards: Business (work details) and Personal (social, photos, bio). Edit each one and choose which opens when someone taps.'),
              ),
            ),
            const SizedBox(height: Space.l),
            TypeSwitch(value: _type, onChanged: (v) => setState(() => _type = v)),
            const SizedBox(height: Space.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => AnimatedBuilder(
                  animation: a,
                  child: child,
                  builder: (context, c) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY((1 - a.value) * math.pi / 2),
                    child: Opacity(opacity: a.value.clamp(0.0, 1.0), child: c),
                  ),
                ),
                child: AnimatedOpacity(
                  key: ValueKey(card.id),
                  duration: const Duration(milliseconds: 300),
                  opacity: card.enabled ? 1 : 0.45,
                  child: NexaCard(card: card, link: Repo.instance.link(profile, type: card.type, source: 'qr')),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Text(t('Tap to flip · drag to tilt'), style: TextStyle(color: p.faint, fontSize: 12.5))),
            const SizedBox(height: Space.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
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
    final actions = <(IconData, String, String, VoidCallback?)>[
      (Ic.edit, t('Edit'), t('Details, photos, design'), () => Navigator.of(context).push(nxRoute(CardEditor(card: card)))),
      (Ic.device, t('Preview'), t('See it like a visitor'), () => Navigator.of(context).push(nxRoute(PhonePreview(initial: card.type)))),
      (Ic.share, t('Share'), t('QR, link, WhatsApp'), card.enabled ? () => showShareSheet(context, profile, card) : null),
      (Ic.download, t('Download'), t('HD card images'), () => showCardDownload(context, card)),
      (Ic.nfc, t('Write NFC'), t('Program a blank card'), () => showNfcWriter(context, card)),
    ];
    return Column(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.enabled ? t('Card is on') : t('Card is off'), style: TextStyles.h3(p)),
                        const SizedBox(height: 2),
                        Text(
                          card.enabled ? t('Visitors can open this card.') : t('Hidden. Visitors cannot see it.'),
                          style: TextStyles.muted(p).copyWith(fontSize: 13),
                        ),
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
              Divider(height: 26, color: p.border),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('Opens on tap'), style: TextStyles.h3(p)),
                        const SizedBox(height: 2),
                        Text(
                          isDefault ? t('This card opens when someone taps your NFC card.') : t('The other card opens on tap right now.'),
                          style: TextStyles.muted(p).copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (isDefault)
                    Chip2(t('Yes'), color: p.isDark ? p.accent : p.accent2, icon: Ic.check)
                  else
                    TextButton(
                      onPressed: card.enabled
                          ? () async {
                              try {
                                await s.setDefault(card.type);
                                if (context.mounted) {
                                  toast(context, tf('Taps now open your {x} profile', card.type.label.toLowerCase()));
                                }
                              } catch (e) {
                                if (context.mounted) toast(context, friendlyError(e), error: true);
                              }
                            }
                          : null,
                      child: Text(t('Use this'), style: TextStyle(color: p.link, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              Divider(height: 26, color: p.border),
              Row(
                children: [
                  Text(t('Profile complete'), style: TextStyles.h3(p)),
                  const Spacer(),
                  Text('${(card.completeness * 100).round()}%', style: TextStyles.h3(p)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: card.completeness),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) =>
                      LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: p.surface2, color: p.accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.15,
          children: [
            for (final (i, a) in actions.indexed)
              FadeIn(
                delayMs: i * 50,
                child: Opacity(
                  opacity: a.$4 == null ? 0.45 : 1,
                  child: Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    onTap: a.$4,
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(Radii.s + 2)),
                          child: Icon(a.$1, size: 18, color: p.isDark ? p.accent : p.accent2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyles.h3(p).copyWith(fontSize: 14.5)),
                              Text(a.$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyles.muted(p).copyWith(fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
