import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/nexa_card.dart';
import 'orders.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

class OrderForm extends StatefulWidget {
  const OrderForm({super.key});

  static Route<void> route() => nxRoute(const OrderForm());

  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _pin = TextEditingController();
  late CardType _type;
  late String _design;
  int _qty = 1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = AppState.instance;
    final card = s.primaryCard;
    _type = card?.type ?? CardType.business;
    _design = card?.design ?? CardDesign.all.first.id;
    _name.text = card?.str('name').isNotEmpty == true ? card!.str('name') : (s.profile?.fullName ?? '');
    _phone.text = card?.str('phone') ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _city, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _unit => AppConfig.cardPrice + (CardDesign.byId(_design).premium ? AppConfig.premiumExtra : 0);
  int get _total => _qty * _unit;

  void _pickType(CardType t) {
    final c = AppState.instance.card(t);
    setState(() {
      _type = t;
      if (c != null) {
        _design = c.design;
        if (c.str('name').isNotEmpty) _name.text = c.str('name');
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _busy = true);
    try {
      final order = await Repo.instance.placeOrder(
        cardType: _type.name,
        design: _design,
        nameOnCard: _name.text.trim(),
        quantity: _qty,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        pincode: _pin.text.trim(),
        amount: _total,
      );
      AppState.instance.addOrder(order);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(nxRoute(_OrderPlaced(order: order)));
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = AppState.instance;
    final card = s.card(_type);
    final profile = s.profile!;
    return NxScaffold(
      title: t('Order a card'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
          children: [
            if (card != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: NexaCard(
                  card: card.copyWith(data: {...card.data, 'name': _name.text}),
                  designOverride: _design,
                  tiltable: false,
                  link: Repo.instance.link(profile, type: _type),
                ),
              ),
            const SizedBox(height: Space.xl),
            SectionHeader(t('Profile on the card')),
            Row(
              children: [
                for (final t in CardType.values) ...[
                  Expanded(
                    child: _Option(
                      label: t.label,
                      icon: t.icon,
                      selected: _type == t,
                      onTap: () => _pickType(t),
                    ),
                  ),
                  if (t != CardType.values.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: Space.xl),
            SectionHeader(t('Finish')),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CardDesign.all.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final d = CardDesign.all[i];
                  final sel = d.id == _design;
                  return Pressable(
                    onTap: () => setState(() => _design = d.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: sel ? p.accent : p.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? p.accent : p.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: d.gradient == null ? d.bg : null,
                              gradient: d.gradient == null ? null : LinearGradient(colors: d.gradient!),
                              shape: BoxShape.circle,
                              border: Border.all(color: p.border),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(d.name,
                              style: TextStyle(
                                  color: sel ? p.onAccent : p.text, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Space.xl),
            NxField(
              label: t('Name printed on card'),
              controller: _name,
              capitalization: TextCapitalization.words,
              validator: requiredValidator,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.xl),
            SectionHeader(t('Quantity')),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tf('{x} per card', formatRupees(_unit)), style: TextStyles.h3(p)),
                        Text(t('NFC chip + QR code, programmed for you'), style: TextStyles.muted(p).copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  _QtyButton(icon: Ic.minus, onTap: _qty > 1 ? () => setState(() => _qty--) : null),
                  SizedBox(
                    width: 36,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Text('$_qty',
                          key: ValueKey(_qty), textAlign: TextAlign.center, style: TextStyles.h2(p)),
                    ),
                  ),
                  _QtyButton(icon: Ic.plus, onTap: _qty < 50 ? () => setState(() => _qty++) : null),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            SectionHeader(t('Delivery')),
            NxField(
              label: t('Phone'),
              controller: _phone,
              prefixText: '+91 ',
              keyboardType: TextInputType.phone,
              maxLength: 10,
              validator: (v) => (v == null || v.trim().length != 10) ? t('Enter a 10-digit number') : null,
            ),
            const SizedBox(height: Space.l),
            NxField(
              label: t('Address'),
              controller: _address,
              hint: t('House no., street, area'),
              maxLines: 3,
              capitalization: TextCapitalization.words,
              validator: requiredValidator,
            ),
            const SizedBox(height: Space.l),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NxField(
                    label: t('City'),
                    controller: _city,
                    capitalization: TextCapitalization.words,
                    validator: requiredValidator,
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: NxField(
                    label: t('PIN code'),
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (v) => (v == null || v.trim().length != 6) ? '6 digits' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Panel(
              child: Column(
                children: [
                  _row(p, '$_qty × ${formatRupees(_unit)}', formatRupees(_total)),
                  const SizedBox(height: 8),
                  _row(p, t('Delivery'), t('Free')),
                  Divider(height: 24, color: p.border),
                  _row(p, t('Total'), formatRupees(_total), bold: true),
                ],
              ),
            ),
            const SizedBox(height: Space.m),
            Text(t('Payment is collected after our team confirms your order (UPI or cash on delivery).'),
                style: TextStyles.muted(p).copyWith(fontSize: 12)),
            const SizedBox(height: Space.xl),
            NxButton(tf('Place order · {x}', formatRupees(_total)), onPressed: _submit, loading: _busy),
          ],
        ),
      ),
    );
  }

  Widget _row(Palette p, String k, String v, {bool bold = false}) => Row(
        children: [
          Expanded(child: Text(k, style: bold ? TextStyles.h3(p) : TextStyles.muted(p))),
          Text(v, style: bold ? TextStyles.h2(p) : TextStyles.body(p)),
        ],
      );
}

class _Option extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Option({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: selected ? p.accent : p.surface,
          borderRadius: BorderRadius.circular(Radii.m),
          border: Border.all(color: selected ? p.accent : p.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? p.onAccent : p.muted),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: selected ? p.onAccent : p.text, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: p.surface2,
            borderRadius: BorderRadius.circular(Radii.s),
          ),
          child: Icon(icon, size: 18, color: p.text),
        ),
      ),
    );
  }
}

class _OrderPlaced extends StatelessWidget {
  final Order order;
  const _OrderPlaced({required this.order});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return NxScaffold(
      back: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.55), blurRadius: 40)],
                  ),
                  child: Icon(Ic.check, size: 52, color: p.onAccent),
                ),
              ),
              const SizedBox(height: Space.xl),
              Text(t('Order placed'), style: TextStyles.title(p)),
              const SizedBox(height: 8),
              Text(
                'Order #${order.orderNo}. Our team will call you on +91 ${order.phone} to confirm the details and payment.',
                textAlign: TextAlign.center,
                style: TextStyles.muted(p),
              ),
              const Spacer(),
              NxButton(t('Track order'),
                  onPressed: () => Navigator.of(context).pushReplacement(OrderDetail.route(order))),
              const SizedBox(height: 10),
              NxButton(t('Done'), kind: BtnKind.ghost, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}
