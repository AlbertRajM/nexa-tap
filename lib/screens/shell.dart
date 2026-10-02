import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/repo.dart';
import '../widgets/backdrop.dart';
import '../widgets/brand.dart';
import 'account.dart';
import 'cards.dart';
import 'home.dart';
import 'orders.dart';
import 'connections.dart';
import 'notifications.dart';
import 'referrals.dart';
import 'search.dart';
import '../core/i18n.dart';
import '../widgets/lang_picker.dart';
import '../core/icons.dart';

class _Dest {
  final IconData icon;
  final String label;
  const _Dest(this.icon, this.label);
}

/// Tab numbers used across the app.
class Tabs {
  static const home = 0;
  static const cards = 1;
  static const connections = 2;
  static const orders = 3;
  static const invite = 4; // opens as its own page
  static const account = 5;
}

const _dests = [
  _Dest(Ic.home, 'Home'),
  _Dest(Ic.cards, 'My cards'),
  _Dest(Ic.users, 'Connections'),
  _Dest(Ic.truck, 'Orders'),
  _Dest(Ic.gift, 'Invite friends'),
  _Dest(Ic.user, 'Account'),
];

/// Main frame: a left side panel menu. Opening it pushes the page back in 3D.
class Shell extends StatefulWidget {
  const Shell({super.key});

  /// Current tab; any screen (even search) can switch tabs through this.
  static final tab = ValueNotifier<int>(0);
  static void goTo(BuildContext context, int index) => tab.value = index;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  late final AnimationController _menu =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  int _index = 0;

  void _onTab() {
    if (Shell.tab.value != _index) _select(Shell.tab.value);
  }

  @override
  void initState() {
    super.initState();
    Shell.tab.value = 0;
    Shell.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    Shell.tab.removeListener(_onTab);
    _menu.dispose();
    super.dispose();
  }

  bool get _open => _menu.value > 0.5;

  // Note: closing uses animateBack so the controller's status is correct
  // afterwards — this was why the menu button stopped responding before.
  void _openMenu() => _menu.animateTo(1, curve: Curves.easeOutCubic);
  void _closeMenu() {
    if (_menu.value > 0) _menu.animateBack(0, curve: Curves.easeOutCubic);
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    Energy.instance.bump(0.5);
    final opening = _menu.status == AnimationStatus.forward && _menu.value < 1;
    if (opening || _menu.value > 0.5) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _select(int i) {
    HapticFeedback.selectionClick();
    if (i == Tabs.invite) {
      Shell.tab.value = _index;
      _closeMenu();
      Navigator.of(context).push(nxRoute(const ReferralsScreen()));
      return;
    }
    setState(() => _index = i);
    if (Shell.tab.value != i) Shell.tab.value = i;
    _closeMenu();
  }

  Widget _page(int i) => switch (i) {
        Tabs.cards => const CardsScreen(key: ValueKey(1)),
        Tabs.connections => const ConnectionsScreen(key: ValueKey(2)),
        Tabs.orders => const OrdersScreen(key: ValueKey(3)),
        Tabs.account => const AccountScreen(key: ValueKey(5)),
        _ => const HomeScreen(key: ValueKey(0)),
      };

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final state = AppState.instance;
    final size = MediaQuery.of(context).size;
    final menuW = math.min(size.width * 0.72, 320.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_open) {
          _closeMenu();
        } else if (_index != 0) {
          _select(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => TouchRipples.add(e.position),
          child: Stack(
            children: [
              const Positioned.fill(child: AnimatedBackdrop()),
              // Side panel
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: menuW,
                child: AnimatedBuilder(
                animation: _menu,
                builder: (context, child) => Opacity(
                  opacity: _menu.value.clamp(0.0, 1.0),
                  child: Transform.translate(offset: Offset(-40 * (1 - _menu.value), 0), child: child),
                ),
                child: ListenableBuilder(
                  listenable: state,
                  builder: (context, _) => _SideMenu(
                    progress: _menu,
                    current: _index,
                    onSelect: _select,
                  ),
                ),
              ),
              ),
              // Foreground page
              AnimatedBuilder(
                animation: _menu,
                builder: (context, child) {
                  final v = Curves.easeInOut.transform(_menu.value.clamp(0.0, 1.0));
                  final m = Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..translate(menuW * 0.92 * v, 0.0, 0.0)
                    ..rotateY(-0.32 * v)
                    ..scale(1 - 0.16 * v, 1 - 0.16 * v, 1.0);
                  return Transform(
                    alignment: Alignment.centerLeft,
                    transform: m,
                    child: Container(
                      clipBehavior: v > 0 ? Clip.antiAlias : Clip.none,
                      decoration: BoxDecoration(
                        color: v > 0 ? Color.lerp(p.bg.withValues(alpha: 0), p.bg2, (v * 4).clamp(0.0, 1.0)) : null,
                        borderRadius: BorderRadius.circular(32 * v),
                        boxShadow: v > 0
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.45 * v), blurRadius: 40, offset: const Offset(-10, 10))]
                            : null,
                      ),
                      child: Stack(
                        children: [
                          child!,
                          if (v > 0.01)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _toggle,
                                onHorizontalDragUpdate: (d) => _menu.value = (_menu.value + d.delta.dx / menuW).clamp(0.0, 1.0),
                                onHorizontalDragEnd: (d) =>
                                    (d.primaryVelocity ?? 0) < -200 || _menu.value < 0.6 ? _closeMenu() : _openMenu(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                child: _Foreground(
                  index: _index,
                  menu: _menu,
                  onMenu: _toggle,
                  page: ListenableBuilder(
                    listenable: state,
                    builder: (context, _) {
                      if (state.loading) return const _LoadingView();
                      if (state.error != null || state.profile == null) {
                        return _ErrorView(message: friendlyError(state.error ?? 'Unknown error'), onRetry: state.load);
                      }
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
                            child: c,
                          ),
                        ),
                        child: _page(_index),
                      );
                    },
                  ),
                ),
              ),
              // Edge swipe to open
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 18,
                child: AnimatedBuilder(
                  animation: _menu,
                  builder: (context, _) => _menu.value > 0
                      ? const SizedBox()
                      : GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (d) => _menu.value = (_menu.value + d.delta.dx / menuW).clamp(0.0, 1.0),
                          onHorizontalDragEnd: (d) =>
                              (d.primaryVelocity ?? 0) > 200 || _menu.value > 0.35 ? _openMenu() : _closeMenu(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Foreground extends StatelessWidget {
  final int index;
  final Animation<double> menu;
  final VoidCallback onMenu;
  final Widget page;
  const _Foreground({required this.index, required this.menu, required this.onMenu, required this.page});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    RoundIconButton(
                      icon: Ic.menu,
                      onTap: onMenu,
                      child: Center(child: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: menu, color: p.text)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: SearchPill()),
                    const SizedBox(width: 10),
                    const NotificationBell(),
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: s,
                      builder: (context, _) => Pressable(
                        onTap: () => Shell.goTo(context, Tabs.account),
                        child: Avatar(
                          name: s.profile?.fullName ?? '',
                          url: s.primaryCard?.str('avatar'),
                          size: 38,
                          ring: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: const Offset(-0.06, 0), end: Offset.zero).animate(a), child: c),
                  ),
                  child: index == 0
                      ? const SizedBox(key: ValueKey('none'), width: double.infinity)
                      : Padding(
                          key: ValueKey(index),
                          padding: const EdgeInsets.fromLTRB(Space.page, 14, Space.page, 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(t(_dests[index].label), style: TextStyles.title(p)),
                          ),
                        ),
                ),
              ),
              Expanded(child: page),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideMenu extends StatelessWidget {
  final Animation<double> progress;
  final int current;
  final ValueChanged<int> onSelect;
  const _SideMenu({required this.progress, required this.current, required this.onSelect});

  Widget _stagger(int i, Widget child) => AnimatedBuilder(
        animation: progress,
        builder: (context, c) {
          final t = ((progress.value - i * 0.06) / 0.6).clamp(0.0, 1.0);
          final e = Curves.easeOutCubic.transform(t);
          return Opacity(opacity: e, child: Transform.translate(offset: Offset(-30 * (1 - e), 0), child: c));
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    final profile = s.profile;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stagger(
              0,
              Row(
                children: [
                  Avatar(name: profile?.fullName ?? '', url: s.primaryCard?.str('avatar'), size: 52, ring: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile?.fullName ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyles.h2(p).copyWith(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('@${profile?.username ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyles.label(p)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            for (var i = 0; i < _dests.length; i++)
              _stagger(
                i + 1,
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _MenuItem(dest: _dests[i], active: i == current, onTap: () => onSelect(i)),
                ),
              ),
            const SizedBox(height: 28),
            _stagger(
              8,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('APPEARANCE'), style: TextStyles.label(p).copyWith(letterSpacing: 1.4, fontSize: 12)),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.instance,
                    builder: (context, mode, _) => Row(
                      children: [
                        for (final (m, ic) in [
                          (ThemeMode.light, Ic.sun),
                          (ThemeMode.dark, Ic.moon),
                          (ThemeMode.system, Ic.device),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Pressable(
                              onTap: () => ThemeController.instance.set(m),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: m == mode ? p.accent : p.surface,
                                  borderRadius: BorderRadius.circular(Radii.m),
                                  border: Border.all(color: p.border),
                                ),
                                child: Icon(ic, size: 20, color: m == mode ? p.onAccent : p.muted),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const LanguageButton(),
                  const SizedBox(height: 18),
                  Pressable(
                    onTap: () => Repo.instance.signOut(),
                    child: Row(
                      children: [
                        Icon(Ic.logout, size: 20, color: p.danger),
                        const SizedBox(width: 10),
                        Text(t('Sign out'), style: TextStyle(color: p.danger, fontWeight: FontWeight.w600, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final _Dest dest;
  final bool active;
  final VoidCallback onTap;
  const _MenuItem({required this.dest, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: active ? p.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.m),
          boxShadow: active ? [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 20)] : null,
        ),
        child: Row(
          children: [
            Icon(dest.icon, size: 21, color: active ? p.onAccent : p.muted),
            const SizedBox(width: 14),
            Text(
              t(dest.label),
              style: TextStyle(
                fontSize: 16,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? p.onAccent : p.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Space.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: Space.l),
          Skeleton(width: 120, height: 14),
          SizedBox(height: 10),
          Skeleton(width: 200, height: 28),
          SizedBox(height: Space.xl),
          AspectRatio(aspectRatio: 1.586, child: Skeleton(height: double.infinity, radius: 18)),
          SizedBox(height: Space.xl),
          Row(children: [
            Expanded(child: Skeleton(height: 80, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: Skeleton(height: 80, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: Skeleton(height: 80, radius: 18)),
          ]),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(icon: Ic.cloudOff, title: t('Could not load your data'), message: message),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Column(
                children: [
                  NxButton(t('Try again'), onPressed: () => onRetry()),
                  const SizedBox(height: 8),
                  NxButton(t('Sign out'), kind: BtnKind.ghost, onPressed: () => Repo.instance.signOut()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
