import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/repo.dart';
import '../widgets/backdrop.dart';
import 'referrals.dart';
import 'welcome.dart';
import '../core/i18n.dart';
import '../widgets/lang_picker.dart';
import '../core/icons.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _rename(BuildContext context, String current) async {
    final p = Palette.of(context);
    final ctrl = TextEditingController(text: current);
    final name = await nxDialog<String>(
      context,
      title: t('Your name'),
      content: NxField(label: t('Full name'), controller: ctrl, capitalization: TextCapitalization.words),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('Cancel'), style: TextStyle(color: p.muted))),
        TextButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: Text(t('Save'), style: TextStyle(color: p.link, fontWeight: FontWeight.w700)),
        ),
      ],
    );
    if (name == null || name.isEmpty || name == current) return;
    try {
      await AppState.instance.rename(name);
      if (context.mounted) toast(context, t('Name updated'));
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final p = Palette.of(context);
    final ok = await nxDialog<bool>(
      context,
      title: t('Sign out?'),
      content: Text(t('You can sign back in any time with Google or your email.'), style: TextStyles.muted(p)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel'), style: TextStyle(color: p.muted))),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(t('Sign out'), style: TextStyle(color: p.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    );
    if (ok == true) await Repo.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final profile = s.profile!;
        final avatar = s.primaryCard?.str('avatar');
        return ListView(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, 48),
            children: [
              Panel(
                glow: true,
                onTap: () => _rename(context, profile.fullName),
                child: Row(
                  children: [
                    Avatar(name: profile.fullName, url: avatar, size: 56, ring: true),
                    const SizedBox(width: Space.l),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.fullName, style: TextStyles.h2(p)),
                          const SizedBox(height: 2),
                          Text(profile.email, style: TextStyles.muted(p)),
                          const SizedBox(height: 2),
                          Text('@${profile.username}', style: TextStyles.label(p)),
                        ],
                      ),
                    ),
                    Icon(Ic.edit, size: 18, color: p.muted),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
              SectionHeader(t('Appearance')),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance,
                builder: (context, mode, _) => _ThemePicker(mode: mode),
              ),
              const SizedBox(height: Space.xl),
              SectionHeader(t('Moving background')),
              ValueListenableBuilder<Backdrop>(
                valueListenable: BackdropController.instance,
                builder: (context, current, _) => GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8,
                  children: [
                    for (final b in Backdrop.values)
                      BackdropSwatch(kind: b, selected: b == current, onTap: () => BackdropController.instance.set(b)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ValueListenableBuilder<Backdrop>(
                valueListenable: BackdropController.instance,
                builder: (context, current, _) => Text(current.blurb, style: TextStyles.muted(p).copyWith(fontSize: 13)),
              ),
              const SizedBox(height: Space.xl),
              SectionHeader(t('General')),
              _Group(children: [
                _Item(
                  icon: Ic.languages,
                  label: t('Language'),
                  trailing: LangController.instance.current.native,
                  onTap: () => showLanguageSheet(context),
                ),
                _Item(
                  icon: Ic.gift,
                  label: t('Invite friends'),
                  trailing: profile.referralCode,
                  onTap: () => Navigator.of(context).push(nxRoute(const ReferralsScreen())),
                ),
                _Item(
                  icon: Ic.link,
                  label: t('Copy profile link'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: s.link));
                    toast(context, t('Profile link copied'));
                  },
                ),
                _Item(
                  icon: Ic.play,
                  label: t('Replay welcome tour'),
                  onTap: () => Navigator.of(context).push(nxRoute(WelcomeScreen(onDone: () => Navigator.of(context).pop()))),
                ),
                _Item(
                  icon: Ic.help,
                  label: t('Help & support'),
                  onTap: () async {
                    try {
                      await launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}?subject=Nexa%20Tap%20help'));
                    } catch (_) {
                      if (context.mounted) toast(context, 'Email us at ${AppConfig.supportEmail}');
                    }
                  },
                ),
                _Item(
                  icon: Ic.info,
                  label: t('About'),
                  trailing: 'Version 1.0.0',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: '1.0.0',
                    applicationLegalese: t('Digital and NFC business cards.'),
                  ),
                ),
              ]),
              const SizedBox(height: Space.xl),
              NxButton(t('Sign out'), icon: Ic.logout, kind: BtnKind.danger, onPressed: () => _signOut(context)),
            ],
        );
      },
    );
  }
}

class _ThemePicker extends StatelessWidget {
  final ThemeMode mode;
  const _ThemePicker({required this.mode});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget opt(ThemeMode m, IconData icon, String label) {
      final sel = m == mode;
      return Expanded(
        child: Pressable(
          onTap: () => ThemeController.instance.set(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: sel ? p.accent : p.surface,
              borderRadius: BorderRadius.circular(Radii.m),
              border: Border.all(color: sel ? p.accent : p.border, width: sel ? 1.5 : 1),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: sel ? p.onAccent : p.muted),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? p.onAccent : p.text)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [
      opt(ThemeMode.system, Ic.device, t('System')),
      const SizedBox(width: 10),
      opt(ThemeMode.light, Ic.sun, t('Light')),
      const SizedBox(width: 10),
      opt(ThemeMode.dark, Ic.moon, t('Dark')),
    ]);
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 52, color: p.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.label, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.text),
            const SizedBox(width: Space.l),
            Expanded(child: Text(label, style: TextStyles.body(p).copyWith(fontWeight: FontWeight.w500))),
            if (trailing != null) ...[
              Text(trailing!, style: TextStyles.muted(p)),
              const SizedBox(width: 6),
            ],
            Icon(Ic.chevronRight, size: 20, color: p.faint),
          ],
        ),
      ),
    );
  }
}
