import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

Future<void> showShareSheet(BuildContext context, Profile profile, CardProfile card) {
  final p = Palette.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: p.surfaceSolid,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    builder: (_) => _ShareSheet(profile: profile, card: card),
  );
}

class _ShareSheet extends StatelessWidget {
  final Profile profile;
  final CardProfile card;
  const _ShareSheet({required this.profile, required this.card});

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
    final link = Repo.instance.link(profile, type: card.type);
    final name = card.str('name').isEmpty ? profile.fullName : card.str('name');
    final message = 'Hi, this is $name. Here is my contact card: $link';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tf('Share your {x} profile', card.type.label.toLowerCase()), style: TextStyles.h2(p)),
            const SizedBox(height: 4),
            Text(t('Let them scan the code, or send the link.'), style: TextStyles.muted(p)),
            const SizedBox(height: Space.xl),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Radii.l),
                  border: Border.all(color: p.border),
                ),
                child: QrImageView(
                  data: Repo.instance.link(profile, type: card.type, source: 'qr'),
                  size: 200,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF0B0D1A)),
                  dataModuleStyle:
                      const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF0B0D1A)),
                ),
              ),
            ),
            const SizedBox(height: Space.l),
            Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(Radii.m),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(link,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 13)),
                  ),
                  IconButton(
                    tooltip: t('Copy link'),
                    icon: Icon(Ic.copy, size: 19, color: p.text),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      HapticFeedback.lightImpact();
                      toast(context, t('Link copied'));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.l),
            NxButton(
              t('Send on WhatsApp'),
              icon: Ic.chat,
              onPressed: () => _open(context, Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}')),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NxButton(
                    'SMS',
                    icon: Ic.sms,
                    kind: BtnKind.secondary,
                    onPressed: () => _open(context, Uri.parse('sms:?body=${Uri.encodeComponent(message)}')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NxButton(
                    t('Preview'),
                    icon: Ic.external,
                    kind: BtnKind.secondary,
                    onPressed: () => _open(context, Uri.parse(link)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
