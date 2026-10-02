import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/nexa_card.dart';
import 'card_editor.dart';
import 'share.dart';

class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final profile = s.profile!;
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
            children: [
              Text('Your cards', style: TextStyles.title(p)),
              const SizedBox(height: 4),
              Text('Turn a profile on or off, and choose which one opens when someone taps.',
                  style: TextStyles.muted(p)),
              const SizedBox(height: Space.xl),
              for (final (i, c) in s.cards.indexed) ...[
                FadeIn(
                  delayMs: i * 80,
                  child: _CardTile(
                    card: c,
                    isDefault: profile.defaultCard == c.type.name,
                  ),
                ),
                const SizedBox(height: Space.l),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  final CardProfile card;
  final bool isDefault;
  const _CardTile({required this.card, required this.isDefault});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    final profile = s.profile!;
    return Panel(
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(Radii.s)),
                child: Icon(card.type.icon, size: 19, color: p.text),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('${card.type.label} profile', style: TextStyles.h3(p)),
                      const SizedBox(width: 8),
                      if (isDefault) Chip2('Default', color: p.accent),
                    ]),
                    const SizedBox(height: 2),
                    Text(card.type.blurb, style: TextStyles.muted(p).copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
              NxSwitch(
                value: card.enabled,
                onChanged: (v) async {
                  try {
                    await s.setEnabled(card, v);
                    if (context.mounted) {
                      toast(context, '${card.type.label} profile ${v ? 'turned on' : 'turned off'}');
                    }
                  } catch (e) {
                    if (context.mounted) toast(context, friendlyError(e), error: true);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: card.enabled ? 1 : 0.4,
            child: NexaCard(card: card, link: Repo.instance.link(profile, type: card.type)),
          ),
          const SizedBox(height: Space.l),
          Row(
            children: [
              Expanded(
                child: NxButton('Edit',
                    icon: Icons.edit_outlined,
                    kind: BtnKind.secondary,
                    height: 42,
                    onPressed: () => Navigator.of(context).push(CardEditor.route(card))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NxButton('Share',
                    icon: Icons.ios_share_rounded,
                    kind: BtnKind.secondary,
                    height: 42,
                    onPressed: card.enabled ? () => showShareSheet(context, profile, card) : null),
              ),
            ],
          ),
          if (!isDefault && card.enabled) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () async {
                  try {
                    await s.setDefault(card.type);
                    if (context.mounted) toast(context, 'Taps now open your ${card.type.label.toLowerCase()} profile');
                  } catch (e) {
                    if (context.mounted) toast(context, friendlyError(e), error: true);
                  }
                },
                child: Text('Make this the default',
                    style: TextStyle(color: p.accent, fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
