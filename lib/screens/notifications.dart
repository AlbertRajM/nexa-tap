import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'shell.dart';

/// Bell in the top bar. Shows the unread count and rings when a new one arrives.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with SingleTickerProviderStateMixin {
  late final AnimationController _ring =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _last = AppState.instance.unread;
    AppState.instance.addListener(_onChange);
  }

  void _onChange() {
    final n = AppState.instance.unread;
    if (n > _last) {
      _ring.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
    _last = n;
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onChange);
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final n = AppState.instance.unread;
        return Pressable(
          scale: 0.9,
          onTap: () => Navigator.of(context).push(nxRoute(const NotificationsScreen())),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.border)),
                  child: AnimatedBuilder(
                    animation: _ring,
                    builder: (context, child) {
                      final v = _ring.value;
                      final angle = math.sin(v * math.pi * 6) * 0.35 * (1 - v);
                      return Transform.rotate(angle: angle, alignment: Alignment.topCenter, child: child);
                    },
                    child: Icon(Ic.bell, size: 20, color: p.text),
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: AnimatedScale(
                    scale: n > 0 ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 19),
                      height: 19,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.danger,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.bg, width: 2),
                      ),
                      child: Text(n > 9 ? '9+' : '$n',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String kind) => switch (kind) {
        'order' => Ic.truck,
        'lead' => Ic.userPlus,
        'referral' => Ic.gift,
        'welcome' => Ic.nfc,
        _ => Ic.bell,
      };

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return NxScaffold(
      title: t('Notifications'),
      actions: [
        ListenableBuilder(
          listenable: s,
          builder: (context, _) => s.unread == 0
              ? const SizedBox()
              : TextButton(
                  onPressed: s.markAllRead,
                  child: Text(t('Mark all read'), style: TextStyle(color: p.link, fontWeight: FontWeight.w600)),
                ),
        ),
      ],
      body: MarkReadOnOpen(
        child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final list = s.notifications;
          if (list.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Ic.bell,
                  title: t('No notifications yet'),
                  message: t('Order updates, new connections and friends who join will show up here.'),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, 40),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final n = list[i];
              return FadeIn(
                key: ValueKey(n.id),
                delayMs: (i * 40).clamp(0, 300),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey('d-${n.id}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => s.deleteNotification(n.id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: p.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(Radii.l),
                      ),
                      child: Icon(Ic.trash, color: p.danger),
                    ),
                    child: Panel(
                      borderColor: n.read ? null : (p.isDark ? p.accent : p.accent2).withValues(alpha: 0.5),
                      onTap: () {
                        if (n.kind == 'order') {
                          Navigator.of(context).pop();
                          Shell.goTo(context, Tabs.orders);
                        } else if (n.kind == 'lead') {
                          Navigator.of(context).pop();
                          Shell.goTo(context, Tabs.connections);
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(Radii.s + 2)),
                            child: Icon(_icon(n.kind), size: 19, color: p.isDark ? p.accent : p.accent2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(t(n.title), style: TextStyles.h3(p))),
                                    Text(timeAgo(n.createdAt), style: TextStyles.label(p)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(n.body, style: TextStyles.muted(p)),
                              ],
                            ),
                          ),
                          if (!n.read) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(color: p.isDark ? p.accent : p.accent2, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}

/// Opening the notifications page marks everything as read after a moment.
class MarkReadOnOpen extends StatefulWidget {
  final Widget child;
  const MarkReadOnOpen({super.key, required this.child});

  @override
  State<MarkReadOnOpen> createState() => _MarkReadOnOpenState();
}

class _MarkReadOnOpenState extends State<MarkReadOnOpen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) AppState.instance.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

