import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/neon_border.dart';
import 'card_editor.dart';
import 'card_tools.dart';
import 'notifications.dart';
import 'order_form.dart';
import 'orders.dart';
import 'referrals.dart';
import 'share.dart';
import 'shell.dart';
import 'welcome.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

/// Search pill shown in the top bar. Its hint text rotates through suggestions.
class SearchPill extends StatefulWidget {
  const SearchPill({super.key});

  @override
  State<SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<SearchPill> {
  static const _hints = ['Search Nexa Tap', 'Try "order"', 'Try "background"', 'Try "share"', 'Try "personal"'];
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _hints.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      scale: 0.97,
      onTap: () => Navigator.of(context).push(_searchRoute()),
      child: Hero(
        tag: 'nx-search',
        child: Material(
          type: MaterialType.transparency,
          child: NeonBorder(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: p.surfaceSolid, borderRadius: BorderRadius.circular(26)),
              child: Row(
                children: [
                  Icon(Ic.search, size: 20, color: p.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(a),
                          child: c,
                        ),
                      ),
                      child: Align(
                        key: ValueKey(_i),
                        alignment: Alignment.centerLeft,
                        child: Text(t(_hints[_i]),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.faint, fontSize: 14.5)),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: p.border),
                    ),
                    child: Icon(Ic.arrowUpLeft, size: 13, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Route<void> _searchRoute() => PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const SearchScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    );

class _Item {
  final String title;
  final String subtitle;
  final IconData icon;
  final String keywords;
  final void Function(BuildContext) run;
  const _Item(this.title, this.subtitle, this.icon, this.keywords, this.run);
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Close search, then do something on the main screen.
  void _then(BuildContext context, void Function(NavigatorState nav) action) {
    final nav = Navigator.of(context);
    nav.pop();
    Future.delayed(const Duration(milliseconds: 250), () => action(nav));
  }

  List<_Item> _items() {
    final s = AppState.instance;
    final profile = s.profile;
    final items = <_Item>[
      _Item(t('Home'), t('Your card and stats'), Ic.home, 'dashboard main start',
          (c) => _then(c, (_) => Shell.goTo(c, Tabs.home))),
      _Item(t('My cards'), t('Turn profiles on or off'), Ic.cards, 'cards profiles default enable disable',
          (c) => _then(c, (_) => Shell.goTo(c, Tabs.cards))),
      _Item(t('Orders'), t('Track your physical cards'), Ic.truck, 'orders tracking delivery status',
          (c) => _then(c, (_) => Shell.goTo(c, Tabs.orders))),
      _Item(t('Connections'), t('People who shared their contact'), Ic.users, 'connections leads contacts people visitors',
          (c) => _then(c, (_) => Shell.goTo(c, Tabs.connections))),
      _Item(t('Notifications'), t('Order updates and alerts'), Ic.bell, 'notifications alerts bell messages',
          (c) => _then(c, (nav) => nav.push(nxRoute(const NotificationsScreen())))),
      _Item(t('Visitor preview'), t('See your profile in a 3D phone'), Ic.device, 'preview phone visitor 3d how others see',
          (c) => _then(c, (nav) => nav.push(nxRoute(const PhonePreview())))),
      _Item(t('Order a new card'), tf('{x} per card', formatRupees(AppConfig.cardPrice)), Ic.bag,
          'buy order purchase new nfc card print', (c) => _then(c, (nav) => nav.push(nxRoute(const OrderForm())))),
      _Item(t('Invite friends'), t('Share your referral code'), Ic.gift,
          'invite referral code friends discount', (c) => _then(c, (nav) => nav.push(nxRoute(const ReferralsScreen())))),
      _Item(t('Account'), t('Name, appearance and more'), Ic.user, 'account settings profile name',
          (c) => _then(c, (_) => Shell.goTo(c, Tabs.account))),
      _Item(t('Change background'), t('Aurora, Network, Waves and more'), Ic.wallpaper,
          'background animation theme moving wallpaper', (c) => _then(c, (_) => Shell.goTo(c, Tabs.account))),
      _Item(t('Light mode'), t('Switch to the light theme'), Ic.sun, 'light theme white appearance',
          (c) => ThemeController.instance.set(ThemeMode.light)),
      _Item(t('Dark mode'), t('Switch to the dark theme'), Ic.moon, 'dark theme black night appearance',
          (c) => ThemeController.instance.set(ThemeMode.dark)),
      _Item(t('Welcome tour'), t('Watch the introduction again'), Ic.play, 'welcome intro tour tutorial',
          (c) => _then(c, (nav) => nav.push(nxRoute(WelcomeScreen(onDone: () => nav.pop()))))),
      _Item(t('Help & support'), AppConfig.supportEmail, Ic.help, 'help support contact email',
          (c) async {
        try {
          await launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}'));
        } catch (_) {}
      }),
      _Item(t('Copy profile link'), t('Paste it anywhere'), Ic.link, 'link url copy profile',
          (c) {
        Clipboard.setData(ClipboardData(text: s.link));
        toast(c, t('Profile link copied'));
      }),
      _Item(t('Sign out'), t('Leave this device'), Ic.logout, 'logout sign out exit', (c) {
        Navigator.of(c).pop();
        Repo.instance.signOut();
      }),
    ];
    for (final card in s.cards) {
      items.add(_Item(
        tf('Edit {x} card', card.type.label.toLowerCase()),
        card.str('name').isEmpty ? t('Add your details') : card.str('name'),
        Ic.edit,
        'edit ${card.type.name} card profile photo phone email ${card.str('company')} ${card.str('title')}',
        (c) => _then(c, (nav) => nav.push(nxRoute(CardEditor(card: card)))),
      ));
      items.add(_Item(
        t('Write NFC'),
        tf('{x} card', card.type.label),
        Ic.nfc,
        'nfc write program tag sticker blank ${card.type.name}',
        (c) => _then(c, (nav) => showNfcWriter(nav.context, card)),
      ));
      items.add(_Item(
        t('Download'),
        tf('{x} card', card.type.label),
        Ic.download,
        'download save image hd gallery print ${card.type.name}',
        (c) => _then(c, (nav) => showCardDownload(nav.context, card)),
      ));
      if (profile != null && card.enabled) {
        items.add(_Item(
          tf('Share {x} card', card.type.label.toLowerCase()),
          t('QR code, link or WhatsApp'),
          Ic.share,
          'share qr code whatsapp send ${card.type.name}',
          (c) => showShareSheet(c, profile, card),
        ));
      }
    }
    for (final o in s.orders) {
      items.add(_Item(
        'Order #${o.orderNo}',
        '${OrderStatus.label(o.status)} · ${formatDate(o.createdAt)}',
        Ic.receipt,
        'order ${o.orderNo} ${o.status} ${o.city} ${o.nameOnCard}',
        (c) => _then(c, (nav) => nav.push(nxRoute(OrderDetail(order: o)))),
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final query = _q.text.trim().toLowerCase();
    final all = _items();
    final results = query.isEmpty
        ? all.take(7).toList()
        : all.where((i) => '${i.title} ${i.subtitle} ${i.keywords}'.toLowerCase().contains(query)).toList();

    return NxScaffold(
      back: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                RoundIconButton(icon: Ic.arrowLeft, onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 10),
                Expanded(
                  child: Hero(
                    tag: 'nx-search',
                    child: Material(
                      type: MaterialType.transparency,
                      child: NeonBorder(
                        active: _focus.hasFocus,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.only(left: 14, right: 4),
                          decoration: BoxDecoration(color: p.surfaceSolid, borderRadius: BorderRadius.circular(26)),
                          child: Row(
                            children: [
                              Icon(Ic.search, size: 21, color: p.isDark ? p.accent : p.accent2),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _q,
                                  focusNode: _focus,
                                  textInputAction: TextInputAction.search,
                                  style: TextStyle(fontSize: 16, color: p.text, fontWeight: FontWeight.w500),
                                  cursorColor: p.isDark ? p.accent : p.accent2,
                                  onChanged: (_) {
                                    Energy.instance.bump(0.12);
                                    setState(() {});
                                  },
                                  onSubmitted: (_) {
                                    if (results.isNotEmpty) results.first.run(context);
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: t('Search pages, orders, settings'),
                                    hintStyle: TextStyle(color: p.faint, fontSize: 15),
                                  ),
                                ),
                              ),
                              AnimatedScale(
                                scale: _q.text.isEmpty ? 0 : 1,
                                duration: const Duration(milliseconds: 180),
                                child: IconButton(
                                  icon: Icon(Ic.close, size: 19, color: p.muted),
                                  onPressed: () {
                                    _q.clear();
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? SingleChildScrollView(
                    child: EmptyState(
                      icon: Ic.searchX,
                      title: t('Nothing found'),
                      message: t('Try words like "order", "share", "background" or "personal".'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, 40),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Text(query.isEmpty ? t('SUGGESTED') : tf('{x} RESULTS', results.length),
                          style: TextStyles.label(p).copyWith(letterSpacing: 1.4, fontSize: 11.5)),
                      const SizedBox(height: Space.m),
                      for (final (i, item) in results.indexed)
                        FadeIn(
                          key: ValueKey('${item.title}-$query'),
                          delayMs: (i * 35).clamp(0, 300),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Panel(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                item.run(context);
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: p.accentSoft,
                                      borderRadius: BorderRadius.circular(Radii.s + 2),
                                    ),
                                    child: Icon(item.icon, size: 20, color: p.isDark ? p.accent : p.accent2),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _Highlight(text: item.title, query: query, style: TextStyles.h3(p)),
                                        const SizedBox(height: 2),
                                        Text(item.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyles.muted(p).copyWith(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Icon(Ic.arrowUpLeft, size: 16, color: p.faint),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shows the matching part of a title in the accent colour.
class _Highlight extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  const _Highlight({required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final i = query.isEmpty ? -1 : text.toLowerCase().indexOf(query);
    if (i < 0) return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, i)),
        TextSpan(
          text: text.substring(i, i + query.length),
          style: TextStyle(
            color: p.isDark ? p.accent : p.accent2,
            fontWeight: FontWeight.w700,
            backgroundColor: (p.isDark ? p.accent : p.accent2).withValues(alpha: 0.12),
          ),
        ),
        TextSpan(text: text.substring(i + query.length)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
