import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/repo.dart';
import 'account.dart';
import 'cards.dart';
import 'home.dart';
import 'orders.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  /// Lets any screen switch tabs, e.g. Home → Orders.
  static void goTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_ShellState>()?._select(index);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        Widget body;
        if (state.loading) {
          body = const _LoadingView();
        } else if (state.error != null || state.profile == null) {
          body = _ErrorView(message: friendlyError(state.error ?? 'Unknown error'), onRetry: state.load);
        } else {
          body = IndexedStack(
            index: _index,
            children: const [HomeScreen(), CardsScreen(), OrdersScreen(), AccountScreen()],
          );
        }
        return Scaffold(
          backgroundColor: p.bg,
          body: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: body),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              backgroundColor: p.surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: p.accentSoft,
              elevation: 0,
              height: 66,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                _dest(p, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _dest(p, Icons.style_outlined, Icons.style_rounded, 'Cards'),
                _dest(p, Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'Orders'),
                _dest(p, Icons.person_outline_rounded, Icons.person_rounded, 'Account'),
              ],
            ),
          ),
        );
      },
    );
  }

  NavigationDestination _dest(Palette p, IconData icon, IconData active, String label) => NavigationDestination(
        icon: Icon(icon, color: p.muted),
        selectedIcon: Icon(active, color: p.accent),
        label: label,
      );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: Space.l),
            Skeleton(width: 120, height: 14),
            SizedBox(height: 10),
            Skeleton(width: 200, height: 26),
            SizedBox(height: Space.xl),
            AspectRatio(aspectRatio: 1.586, child: Skeleton(height: double.infinity, radius: 16)),
            SizedBox(height: Space.xl),
            Row(children: [
              Expanded(child: Skeleton(height: 72, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: Skeleton(height: 72, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: Skeleton(height: 72, radius: 14)),
            ]),
          ],
        ),
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
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(icon: Icons.cloud_off_outlined, title: 'Could not load your data', message: message),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Column(
                children: [
                  NxButton('Try again', onPressed: () => onRetry()),
                  const SizedBox(height: 8),
                  NxButton('Sign out', kind: BtnKind.ghost, onPressed: () => Repo.instance.signOut()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
