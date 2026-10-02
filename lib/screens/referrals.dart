import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const ReferralsScreen());

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
    return Scaffold(
      backgroundColor: p.bg,
      appBar: nxAppBar(context, 'Invite friends'),
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        onRefresh: () async {
          final f = Repo.instance.referralStats();
          setState(() => _stats = f);
          await f;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
          children: [
            Text('Friends get ${AppConfig.referralDiscountPercent}% off their first card when they sign up with your code.',
                style: TextStyles.muted(p)),
            const SizedBox(height: Space.xl),
            Panel(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                children: [
                  Text('YOUR CODE', style: TextStyles.label(p).copyWith(letterSpacing: 1.4)),
                  const SizedBox(height: 10),
                  Pressable(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      HapticFeedback.lightImpact();
                      toast(context, 'Code copied');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(code,
                            style: TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 3, color: p.text)),
                        const SizedBox(width: 10),
                        Icon(Icons.copy_rounded, size: 18, color: p.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  NxButton(
                    'Invite on WhatsApp',
                    icon: Icons.chat_outlined,
                    onPressed: () async {
                      try {
                        await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
                            mode: LaunchMode.externalApplication);
                      } catch (_) {
                        if (context.mounted) toast(context, 'Could not open WhatsApp', error: true);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  NxButton(
                    'Copy invite message',
                    icon: Icons.copy_rounded,
                    kind: BtnKind.secondary,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      toast(context, 'Invite message copied');
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
                  return Text('Could not load referral stats. Pull down to retry.', style: TextStyles.muted(p));
                }
                final data = snap.data!;
                final list = (data['list'] as List? ?? []).cast<Map>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _Count(value: '${data['joined'] ?? 0}', label: 'Friends joined'),
                      const SizedBox(width: 10),
                      _Count(value: '${data['ordered'] ?? 0}', label: 'Bought a card'),
                    ]),
                    const SizedBox(height: Space.xl),
                    const SectionHeader('Friends'),
                    if (list.isEmpty)
                      Panel(
                        child: EmptyState(
                          icon: Icons.group_outlined,
                          title: 'No friends yet',
                          message: 'People who sign up with your code will show up here.',
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
                                  'Joined ${formatDate(DateTime.tryParse('${f['joined_at']}')?.toLocal() ?? DateTime.now())}',
                                  style: TextStyles.muted(p).copyWith(fontSize: 12),
                                ),
                                trailing: f['ordered'] == true
                                    ? Chip2('Ordered', color: p.success)
                                    : Chip2('Signed up', color: p.muted),
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
            Text(value, style: TextStyles.number(p)),
            const SizedBox(height: 2),
            Text(label, style: TextStyles.label(p)),
          ],
        ),
      ),
    );
  }
}
