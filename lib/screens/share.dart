import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/models.dart';
import '../data/repo.dart';

Future<void> showShareSheet(BuildContext context, Profile profile, CardProfile card) {
  final p = Palette.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: p.surface,
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
    if (!ok && context.mounted) toast(context, 'Could not open the app', error: true);
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
            Text('Share your ${card.type.label.toLowerCase()} profile', style: TextStyles.h2(p)),
            const SizedBox(height: 4),
            Text('Let them scan the code, or send the link.', style: TextStyles.muted(p)),
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
                  data: link,
                  size: 200,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF111317)),
                  dataModuleStyle:
                      const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF111317)),
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
                    tooltip: 'Copy link',
                    icon: Icon(Icons.copy_rounded, size: 19, color: p.text),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      HapticFeedback.lightImpact();
                      toast(context, 'Link copied');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.l),
            NxButton(
              'Send on WhatsApp',
              icon: Icons.chat_outlined,
              onPressed: () => _open(context, Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}')),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NxButton(
                    'SMS',
                    icon: Icons.sms_outlined,
                    kind: BtnKind.secondary,
                    onPressed: () => _open(context, Uri.parse('sms:?body=${Uri.encodeComponent(message)}')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NxButton(
                    'Preview',
                    icon: Icons.open_in_new_rounded,
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
