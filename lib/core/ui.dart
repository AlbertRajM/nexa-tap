import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/backdrop.dart';
import 'theme.dart';
import 'i18n.dart';
import 'icons.dart';

// ─────────────────────────── Page shell & navigation ───────────────────────────

/// Page with the animated background, tap ripples and an optional top bar.
class NxScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottom;
  final bool back;

  const NxScaffold({super.key, required this.body, this.title, this.actions, this.leading, this.bottom, this.back = true});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final canPop = back && Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: p.bg,
      resizeToAvoidBottomInset: true,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => TouchRipples.add(e.position),
        child: Stack(
          children: [
            const Positioned.fill(child: AnimatedBackdrop()),
            SafeArea(
              bottom: bottom == null,
              child: Column(
                children: [
                  if (title != null || leading != null || canPop)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          leading ??
                              (canPop
                                  ? RoundIconButton(
                                      icon: Ic.arrowLeft,
                                      onTap: () => Navigator.of(context).maybePop(),
                                    )
                                  : const SizedBox(width: 44)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: title == null
                                ? const SizedBox()
                                : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyles.h2(p)),
                          ),
                          ...?actions,
                        ],
                      ),
                    ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// Smooth page transition used across the app: slide + fade + slight zoom.
Route<T> nxRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, a, secondary, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(c),
            child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(c), child: child),
          ),
        );
      },
    );

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Widget? child;
  const RoundIconButton({super.key, required this.icon, this.onTap, this.size = 44, this.child});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.border)),
        child: child ?? Icon(icon, size: 21, color: p.text),
      ),
    );
  }
}

// ─────────────────────────── Interaction primitives ───────────────────────────

/// Shrinks slightly while pressed and gives a light haptic tick.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96, this.haptic = true});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

enum BtnKind { primary, secondary, ghost, danger }

class NxButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BtnKind kind;
  final bool loading;
  final bool expand;
  final double height;

  const NxButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.kind = BtnKind.primary,
    this.loading = false,
    this.expand = true,
    this.height = 54,
  });

  @override
  State<NxButton> createState() => _NxButtonState();
}

class _NxButtonState extends State<NxButton> with SingleTickerProviderStateMixin {
  late final AnimationController _shine =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    if (widget.kind == BtnKind.primary) _shine.repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final disabled = widget.onPressed == null || widget.loading;
    Color bg;
    Color fg;
    Color border = Colors.transparent;
    switch (widget.kind) {
      case BtnKind.primary:
        bg = p.accent;
        fg = p.onAccent;
        break;
      case BtnKind.secondary:
        bg = p.surface;
        fg = p.text;
        border = p.border;
        break;
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = p.text;
        break;
      case BtnKind.danger:
        bg = p.danger.withValues(alpha: 0.14);
        fg = p.danger;
        break;
    }
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
      child: widget.loading
          ? SizedBox(
              key: const ValueKey('l'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('c'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 19, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
                  ),
                ),
              ],
            ),
    );

    return Opacity(
      opacity: disabled && !widget.loading ? 0.45 : 1,
      child: Pressable(
        onTap: disabled ? null : widget.onPressed,
        child: Container(
          height: widget.height,
          width: widget.expand ? double.infinity : null,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.m),
            border: Border.all(color: border),
            boxShadow: widget.kind == BtnKind.primary && !disabled
                ? [BoxShadow(color: p.accent.withValues(alpha: p.isDark ? 0.28 : 0.45), blurRadius: 22, offset: const Offset(0, 8))]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.kind == BtnKind.primary)
                Positioned.fill(
                  child: RepaintBoundary(child: AnimatedBuilder(
                    animation: _shine,
                    builder: (context, _) {
                      final x = -1.6 + _shine.value * 5; // sweeps across, then rests
                      return Align(
                        alignment: Alignment(x, 0),
                        child: FractionallySizedBox(
                          widthFactor: 0.35,
                          heightFactor: 1,
                          child: Transform(
                            transform: Matrix4.skewX(-0.35),
                            child: Container(color: Colors.white.withValues(alpha: 0.28)),
                          ),
                        ),
                      );
                    },
                  )),
                ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: content),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field with an animated glow when focused. Typing energises the background.
class NxField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final TextInputAction? action;
  final ValueChanged<String>? onChanged;
  final String? prefixText;
  final Widget? suffix;
  final TextCapitalization capitalization;
  final List<String>? autofill;

  const NxField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.action,
    this.onChanged,
    this.prefixText,
    this.suffix,
    this.capitalization = TextCapitalization.none,
    this.autofill,
  });

  @override
  State<NxField> createState() => _NxFieldState();
}

class _NxFieldState extends State<NxField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final hi = p.isDark ? p.accent : p.accent2;
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c, width: w),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyles.label(p).copyWith(color: _focused ? hi : p.muted, fontWeight: _focused ? FontWeight.w600 : FontWeight.w500),
          child: Text(widget.label),
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.m),
            boxShadow: _focused
                ? [BoxShadow(color: hi.withValues(alpha: 0.22), blurRadius: 18, spreadRadius: 1)]
                : const [],
          ),
          child: TextFormField(
            focusNode: _focus,
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscure,
            maxLines: widget.obscure ? 1 : widget.maxLines,
            minLines: 1,
            maxLength: widget.maxLength,
            validator: widget.validator,
            textInputAction: widget.action,
            onChanged: (v) {
              Energy.instance.bump(0.1);
              widget.onChanged?.call(v);
            },
            textCapitalization: widget.capitalization,
            autofillHints: widget.autofill,
            style: TextStyle(fontSize: 16, color: p.text, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: p.surface,
              hintText: widget.hint,
              hintStyle: TextStyle(color: p.faint, fontSize: 15.5, fontWeight: FontWeight.w400),
              prefixIcon: widget.icon == null
                  ? null
                  : AnimatedScale(
                      scale: _focused ? 1.12 : 1,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(widget.icon, size: 20, color: _focused ? hi : p.muted),
                    ),
              prefixText: widget.prefixText,
              prefixStyle: TextStyle(color: p.muted, fontSize: 16),
              suffixIcon: widget.suffix,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: b(p.border),
              enabledBorder: b(p.border),
              focusedBorder: b(hi, 1.6),
              errorBorder: b(p.danger),
              focusedErrorBorder: b(p.danger, 1.6),
              errorStyle: TextStyle(color: p.danger, fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Surfaces & content ───────────────────────────

/// Translucent "glass" surface with a thin border.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final bool glow;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.l),
    this.onTap,
    this.color,
    this.borderColor,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(Radii.l),
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: glow
            ? [BoxShadow(color: p.accent2.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 10))]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, scale: 0.975, child: box);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyles.h3(p))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: TextStyle(color: p.link, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class Chip2 extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Chip2(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class NxSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const NxSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Switch(
      value: value,
      onChanged: onChanged == null
          ? null
          : (v) {
              HapticFeedback.lightImpact();
              Energy.instance.bump(0.4);
              onChanged!(v);
            },
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onAccent : (p.isDark ? Colors.white : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.surface2,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => p.border),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Pulsing placeholder used while content loads.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 10});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.9).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// Gently floats its child up and down forever.
class Floating extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration period;
  const Floating({super.key, required this.child, this.distance = 6, this.period = const Duration(milliseconds: 2600)});

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (Curves.easeInOut.transform(_c.value) - 0.5) * 2 * widget.distance),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Floating(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(Radii.l),
                border: Border.all(color: p.border),
              ),
              child: Icon(icon, color: p.isDark ? p.accent : p.accent2, size: 30),
            ),
          ),
          const SizedBox(height: Space.l),
          Text(title, style: TextStyles.h2(p), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: TextStyles.muted(p), textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.xl),
            NxButton(actionLabel!, onPressed: onAction, expand: false, icon: Ic.plus),
          ],
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool ring;
  const Avatar({super.key, this.url, required this.name, this.size = 44, this.ring = false});

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fallback = Center(
      child: Text(initials,
          style: TextStyle(
              fontFamily: Fonts.display, color: p.onAccent, fontWeight: FontWeight.w800, fontSize: size * 0.34)),
    );
    final inner = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(url!, fit: BoxFit.cover, filterQuality: FilterQuality.high, errorBuilder: (_, __, ___) => fallback),
    );
    if (!ring) return inner;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [p.accent, p.accent2, p.accent]),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
        child: inner,
      ),
    );
  }
}

/// Number that counts up when it appears or changes.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  final String suffix;
  const CountUp(this.value, {super.key, required this.style, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

Future<T?> nxDialog<T>(BuildContext context, {required String title, required Widget content, required List<Widget> actions}) {
  final p = Palette.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: p.surfaceSolid,
          borderRadius: BorderRadius.circular(Radii.xl),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyles.h2(p)),
                const SizedBox(height: 12),
                content,
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutBack);
      return FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(c), child: child));
    },
  );
}

void toast(BuildContext context, String message, {bool error = false}) {
  final p = Palette.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: const Color(0xFF15172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          side: BorderSide(color: (error ? p.danger : p.accent).withValues(alpha: 0.5)),
        ),
        duration: const Duration(milliseconds: 2400),
        content: Row(
          children: [
            Icon(error ? Ic.alert : Ic.checkCircle,
                size: 19, color: error ? p.danger : Palette.dark.accent),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontFamily: Fonts.body))),
          ],
        ),
      ),
    );
}

/// Fades, slides and scales a child in once, with an optional delay (staggered lists).
class FadeIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeIn({super.key, required this.child, this.delayMs = 0});

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curve),
        child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(curve), child: widget.child),
      ),
    );
  }
}

String? requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? t('Required') : null;

String friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('Invalid login credentials')) return t('Wrong email or password.');
  if (s.contains('User already registered')) return t('An account with this email already exists.');
  if (s.contains('Password should be')) return t('Password must be at least 6 characters.');
  if (s.contains('SocketException') || s.contains('Failed host lookup')) {
    return t('No internet connection.');
  }
  if (s.contains('google_not_configured')) return t('Google login is not set up yet.');
  if (s.contains('ApiException: 10') || s.contains('google_no_token')) {
    return t('Google login is not set up correctly. Check the Google Cloud setup (package name and SHA-1).');
  }
  if (s.contains('ApiException: 7') || s.contains('network_error')) return t('No internet connection.');
  if (s.contains('ApiException: 12500') || s.contains('sign_in_failed')) {
    return t('Google could not sign you in. Update Google Play services and try again.');
  }
  if (s.contains('audience') || s.contains('Unacceptable')) {
    return t('The Google Client ID in Supabase does not match the app.');
  }
  if (s.contains('Provider') && s.contains('not enabled')) {
    return t('Google login is turned off in Supabase. Turn it on in Authentication → Providers.');
  }
  if (s.contains('rate limit')) return t('Too many attempts. Please wait a minute.');
  final m = RegExp(r'message: ([^,\)]+)').firstMatch(s);
  return m?.group(1) ?? t('Something went wrong. Please try again.');
}

/// Small explainer shown at the top of screens so every feature is easy to understand.
class HintCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const HintCard({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = p.isDark ? p.accent : p.accent2;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.m),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyles.muted(p).copyWith(color: p.text.withValues(alpha: 0.85), fontSize: 13.5))),
        ],
      ),
    );
  }
}

/// iOS-style smooth bouncing scroll everywhere, with no glow.
class SmoothScroll extends MaterialScrollBehavior {
  const SmoothScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics(), decelerationRate: ScrollDecelerationRate.fast);

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
