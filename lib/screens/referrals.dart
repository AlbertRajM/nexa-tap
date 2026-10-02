import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  static Route<void> route() => nxRoute(const ReferralsScreen());

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  late Future<Map<String, dynamic>> _stats = Repo.instance.referralStats();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final profile = AppState.instance.profile!;
    final code = profile.referralCode;
    final message = 'Join me on Nexa Tap and get ${AppConfig.referralDiscountPercent}% off your first NFC card. '
        'Use my code $code when you sign up.';
    return NxScaffold(
      title: t('Invite friends'),
      body: RefreshIndicator(
        color: p.onAccent,
        backgroundColor: p.accent,
        onRefresh: () async {
          final f = Repo.instance.referralStats();
          setState(() => _stats = f);
          await f;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
          children: [
            Text(tf('Friends get {x}% off their first card when they sign up with your code.', AppConfig.referralDiscountPercent),
                style: TextStyles.muted(p)),
            const SizedBox(height: Space.xl),
            Panel(
              glow: true,
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                children: [
                  Text(t('YOUR CODE'), style: TextStyles.label(p).copyWith(letterSpacing: 1.4)),
                  const SizedBox(height: 10),
                  Pressable(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      HapticFeedback.lightImpact();
                      toast(context, t('Code copied'));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (r) => LinearGradient(
                            colors: p.isDark ? [p.accent, p.accent2] : [p.accent2, p.danger],
                          ).createShader(r),
                          child: Text(code,
                              style: const TextStyle(
                                  fontFamily: Fonts.display, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 3)),
                        ),
                        const SizedBox(width: 10),
                        Icon(Ic.copy, size: 18, color: p.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  NxButton(
                    t('Invite on WhatsApp'),
                    icon: Ic.chat,
                    onPressed: () async {
                      try {
                        await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
                            mode: LaunchMode.externalApplication);
                      } catch (_) {
                        if (context.mounted) toast(context, t('Could not open WhatsApp'), error: true);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  NxButton(
                    t('Copy invite message'),
                    icon: Ic.copy,
                    kind: BtnKind.secondary,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      toast(context, t('Invite message copied'));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            FutureBuilder<Map<String, dynamic>>(
              future: _stats,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Column(children: [
                    Row(children: [
                      Expanded(child: Skeleton(height: 76, radius: 14)),
                      SizedBox(width: 10),
                      Expanded(child: Skeleton(height: 76, radius: 14)),
                    ]),
                    SizedBox(height: Space.xl),
                    Skeleton(height: 120, radius: 14),
                  ]);
                }
                if (snap.hasError) {
                  return Text(t('Could not load referral stats. Pull down to retry.'), style: TextStyles.muted(p));
                }
                final data = snap.data!;
                final list = (data['list'] as List? ?? []).cast<Map>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _Count(value: '${data['joined'] ?? 0}', label: t('Friends joined')),
                      const SizedBox(width: 10),
                      _Count(value: '${data['ordered'] ?? 0}', label: t('Bought a card')),
                    ]),
                    const SizedBox(height: Space.xl),
                    SectionHeader(t('Friends')),
                    if (list.isEmpty)
                      Panel(
                        child: EmptyState(
                          icon: Ic.users,
                          title: t('No friends yet'),
                          message: t('People who sign up with your code will show up here.'),
                        ),
                      )
                    else
                      Panel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, f) in list.indexed) ...[
                              if (i > 0) Divider(height: 1, color: p.border),
                              ListTile(
                                leading: Avatar(name: '${f['name'] ?? ''}', size: 36),
                                title: Text('${f['name'] ?? 'Friend'}', style: TextStyles.h3(p)),
                                subtitle: Text(
                                  tf('Joined {x}', formatDate(DateTime.tryParse('${f['joined_at']}')?.toLocal() ?? DateTime.now())),
                                  style: TextStyles.muted(p).copyWith(fontSize: 12),
                                ),
                                trailing: f['ordered'] == true
                                    ? Chip2(t('Ordered'), color: p.success)
                                    : Chip2(t('Signed up'), color: p.muted),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String value;
  final String label;
  const _Count({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CountUp(int.tryParse(value) ?? 0, style: TextStyles.number(p)),
            const SizedBox(height: 2),
            Text(label, style: TextStyles.label(p)),
          ],
        ),
      ),
    );
  }
}
