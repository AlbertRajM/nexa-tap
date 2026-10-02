import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';

/// People who shared their contact from your public profile page.
class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) toast(context, t('Could not open the app'), error: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => RefreshIndicator(
        color: p.onAccent,
        backgroundColor: p.accent,
        onRefresh: s.refreshLeads,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, 48),
          children: [
            HintCard(
              icon: Ic.userPlus,
              text: t('When someone opens your profile, they can share their own contact with you. They appear here, ready to call or message.'),
            ),
            const SizedBox(height: Space.l),
            if (s.leads.isEmpty)
              Panel(
                child: EmptyState(
                  icon: Ic.users,
                  title: t('No connections yet'),
                  message: t('Share your card. Visitors tap "Share my contact" on your profile to appear here.'),
                ),
              )
            else
              for (final (i, l) in s.leads.indexed) ...[
                FadeIn(delayMs: (i * 50).clamp(0, 300), child: _LeadTile(lead: l, open: (u) => _open(context, u))),
                const SizedBox(height: Space.m),
              ],
          ],
        ),
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  final Lead lead;
  final void Function(Uri) open;
  const _LeadTile({required this.lead, required this.open});

  String get _digits {
    final d = lead.phone.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: lead.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name, style: TextStyles.h3(p)),
                    const SizedBox(height: 2),
                    Text(
                      [if (lead.phone.isNotEmpty) '+91 $_digits', if (lead.email.isNotEmpty) lead.email].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.muted(p).copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(timeAgo(lead.createdAt), style: TextStyles.label(p)),
            ],
          ),
          if (lead.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(Radii.m)),
              child: Text('"${lead.note}"', style: TextStyles.body(p).copyWith(fontSize: 14)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (lead.phone.isNotEmpty) ...[
                _Mini(icon: Ic.phone, label: t('Call'), onTap: () => open(Uri.parse('tel:+91$_digits'))),
                const SizedBox(width: 8),
                _Mini(icon: Ic.chat, label: 'WhatsApp', onTap: () => open(Uri.parse('https://wa.me/91$_digits'))),
                const SizedBox(width: 8),
              ],
              if (lead.email.isNotEmpty) ...[
                _Mini(icon: Ic.mail, label: t('Email'), onTap: () => open(Uri.parse('mailto:${lead.email}'))),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              RoundIconButton(
                icon: Ic.trash,
                size: 38,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  try {
                    await AppState.instance.deleteLead(lead.id);
                    if (context.mounted) toast(context, t('Connection removed'));
                  } catch (e) {
                    if (context.mounted) toast(context, friendlyError(e), error: true);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Mini({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: p.text),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
