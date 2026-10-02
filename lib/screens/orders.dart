import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'order_form.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = switch (status) {
      'delivered' => p.success,
      'cancelled' => p.danger,
      'shipped' => p.accent2,
      'placed' => p.warning,
      _ => p.isDark ? p.accent : p.accent2,
    };
    return Chip2(OrderStatus.label(status), color: color);
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => RefreshIndicator(
          color: p.onAccent,
          backgroundColor: p.accent,
          onRefresh: s.refreshOrders,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, 48),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('Track your physical cards from print to doorstep.'), style: TextStyles.muted(p)),
                      ],
                    ),
                  ),
                  if (s.orders.isNotEmpty)
                    NxButton(t('New'),
                        icon: Ic.plus,
                        expand: false,
                        height: 38,
                        onPressed: () => Navigator.of(context).push(OrderForm.route())),
                ],
              ),
              const SizedBox(height: Space.xl),
              if (s.orders.isEmpty)
                Panel(
                  child: EmptyState(
                    icon: Ic.truck,
                    title: t('No orders yet'),
                    message: t('Order a physical NFC card and follow its progress here.'),
                    actionLabel: t('Order a card'),
                    onAction: () => Navigator.of(context).push(OrderForm.route()),
                  ),
                )
              else
                for (final (i, o) in s.orders.indexed) ...[
                  FadeIn(delayMs: i * 70, child: _OrderTile(order: o)),
                  const SizedBox(height: Space.m),
                ],
            ],
          ),
        ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final design = CardDesign.byId(order.design);
    return Panel(
      onTap: () => Navigator.of(context).push(OrderDetail.route(order)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 34,
            decoration: BoxDecoration(
              color: design.gradient == null ? design.bg : null,
              gradient: design.gradient == null ? null : LinearGradient(colors: design.gradient!),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: p.border),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.orderNo}', style: TextStyles.h3(p)),
                const SizedBox(height: 2),
                Text(
                  '${order.quantity} × ${design.name} · ${formatDate(order.createdAt)}',
                  style: TextStyles.muted(p).copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          StatusChip(status: order.status),
        ],
      ),
    );
  }
}

class OrderDetail extends StatelessWidget {
  final Order order;
  const OrderDetail({super.key, required this.order});

  static Route<void> route(Order o) => nxRoute(OrderDetail(order: o));

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final design = CardDesign.byId(order.design);
    final current = OrderStatus.index(order.status);
    final cancelled = order.status == 'cancelled';
    return NxScaffold(
      title: 'Order #${order.orderNo}',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
        children: [
          Panel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tf('Placed on {x}', formatDate(order.createdAt)), style: TextStyles.muted(p)),
                      const SizedBox(height: 4),
                      Text(OrderStatus.label(order.status), style: TextStyles.h2(p)),
                    ],
                  ),
                ),
                StatusChip(status: order.status),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          SectionHeader(t('Progress')),
          Panel(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.s),
            child: cancelled
                ? Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: Text(t('This order was cancelled. Contact support if this is unexpected.'),
                        style: TextStyles.muted(p)),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < OrderStatus.steps.length; i++)
                        _TimelineStep(
                          index: i,
                          title: OrderStatus.label(OrderStatus.steps[i]),
                          detail: OrderStatus.detail(OrderStatus.steps[i]),
                          done: i <= current,
                          active: i == current,
                          last: i == OrderStatus.steps.length - 1,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: Space.xl),
          SectionHeader(t('Details')),
          Panel(
            child: Column(
              children: [
                _kv(p, t('Card'), '${order.cardType == 'personal' ? t('Personal') : t('Business')} · ${design.name}'),
                _kv(p, t('Name on card'), order.nameOnCard),
                _kv(p, t('Quantity'), '${order.quantity}'),
                _kv(p, t('Amount'), formatRupees(order.amount)),
                _kv(p, t('Phone'), '+91 ${order.phone}'),
                _kv(p, t('Deliver to'), '${order.address}, ${order.city} ${order.pincode}', last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(Palette p, String k, String v, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : Space.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: TextStyles.muted(p))),
            Expanded(child: Text(v, style: TextStyles.body(p))),
          ],
        ),
      );
}

class _TimelineStep extends StatelessWidget {
  final int index;
  final String title;
  final String detail;
  final bool done;
  final bool active;
  final bool last;
  const _TimelineStep({
    required this.index,
    required this.title,
    required this.detail,
    required this.done,
    required this.active,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final delay = Duration(milliseconds: 120 * index);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                _Dot(done: done, active: active, delay: delay),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done && !active ? p.accent : p.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: done ? p.text : p.faint,
                      )),
                  if (active) ...[
                    const SizedBox(height: 2),
                    Text(detail, style: TextStyles.muted(p)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool done;
  final bool active;
  final Duration delay;
  const _Dot({required this.done, required this.active, required this.delay});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400) + delay,
      curve: Curves.easeOutBack,
      builder: (context, v, _) {
        final t = ((v * (400 + delay.inMilliseconds) - delay.inMilliseconds) / 400).clamp(0.0, 1.0);
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? Color.lerp(p.surface2, p.accent, t) : p.surface2,
            boxShadow: active ? [BoxShadow(color: p.accent.withValues(alpha: 0.5 * t), blurRadius: 14)] : null,
            border: active ? Border.all(color: p.accentSoft, width: 4 * t) : null,
          ),
          child: done && !active ? Icon(Ic.check, size: 12 * t, color: p.onAccent) : null,
        );
      },
    );
  }
}
