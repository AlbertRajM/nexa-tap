import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/repo.dart';
import 'referrals.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _rename(BuildContext context, String current) async {
    final p = Palette.of(context);
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Your name', style: TextStyles.h2(p)),
        content: NxField(label: 'Full name', controller: ctrl, capitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: p.muted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Save', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == current) return;
    try {
      await AppState.instance.rename(name);
      if (context.mounted) toast(context, 'Name updated');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final p = Palette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Sign out?', style: TextStyles.h2(p)),
        content: Text('You can sign back in any time with your email and password.', style: TextStyles.muted(p)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: p.muted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: TextStyle(color: p.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
            children: [
              Text('Account', style: TextStyles.title(p)),
              const SizedBox(height: Space.xl),
              Panel(
                onTap: () => _rename(context, profile.fullName),
                child: Row(
                  children: [
                    Avatar(name: profile.fullName, url: avatar, size: 52),
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
                    Icon(Icons.edit_outlined, size: 18, color: p.muted),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
              const SectionHeader('Appearance'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance,
                builder: (context, mode, _) => _ThemePicker(mode: mode),
              ),
              const SizedBox(height: Space.xl),
              const SectionHeader('General'),
              _Group(children: [
                _Item(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Invite friends',
                  trailing: profile.referralCode,
                  onTap: () => Navigator.of(context).push(ReferralsScreen.route()),
                ),
                _Item(
                  icon: Icons.link_rounded,
                  label: 'Copy profile link',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: s.link));
                    toast(context, 'Profile link copied');
                  },
                ),
                _Item(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & support',
                  onTap: () async {
                    try {
                      await launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}?subject=Nexa%20Tap%20help'));
                    } catch (_) {
                      if (context.mounted) toast(context, 'Email us at ${AppConfig.supportEmail}');
                    }
                  },
                ),
                _Item(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  trailing: 'Version 1.0.0',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Digital and NFC business cards.',
                  ),
                ),
              ]),
              const SizedBox(height: Space.xl),
              NxButton('Sign out', icon: Icons.logout_rounded, kind: BtnKind.danger, onPressed: () => _signOut(context)),
            ],
          ),
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
              color: sel ? p.accentSoft : p.surface,
              borderRadius: BorderRadius.circular(Radii.m),
              border: Border.all(color: sel ? p.accent : p.border, width: sel ? 1.5 : 1),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: sel ? p.accent : p.muted),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? p.accent : p.text)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [
      opt(ThemeMode.system, Icons.phone_android_rounded, 'System'),
      const SizedBox(width: 10),
      opt(ThemeMode.light, Icons.light_mode_outlined, 'Light'),
      const SizedBox(width: 10),
      opt(ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
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
            Icon(Icons.chevron_right_rounded, size: 20, color: p.faint),
          ],
        ),
      ),
    );
  }
}
