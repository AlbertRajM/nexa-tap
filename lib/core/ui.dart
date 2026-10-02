import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Shrinks slightly while pressed and gives a light haptic tick.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.haptic = true});

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
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

enum BtnKind { primary, secondary, ghost, danger }

class NxButton extends StatelessWidget {
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
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final disabled = onPressed == null || loading;
    Color bg;
    Color fg;
    Color border = Colors.transparent;
    switch (kind) {
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
        bg = p.danger.withValues(alpha: 0.12);
        fg = p.danger;
        break;
    }
    final content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );

    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: Pressable(
        onTap: disabled ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.m),
            border: Border.all(color: border),
          ),
          child: content,
        ),
      ),
    );
  }
}

class NxField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c, width: w),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyles.label(p)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          minLines: 1,
          maxLength: maxLength,
          validator: validator,
          textInputAction: action,
          onChanged: onChanged,
          textCapitalization: capitalization,
          autofillHints: autofill,
          style: TextStyle(fontSize: 15, color: p.text),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: p.surface,
            hintText: hint,
            hintStyle: TextStyle(color: p.faint, fontSize: 15),
            prefixIcon: icon == null ? null : Icon(icon, size: 19, color: p.muted),
            prefixText: prefixText,
            prefixStyle: TextStyle(color: p.muted, fontSize: 15),
            suffixIcon: suffix,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: b(p.border),
            enabledBorder: b(p.border),
            focusedBorder: b(p.accent, 1.5),
            errorBorder: b(p.danger),
            focusedErrorBorder: b(p.danger, 1.5),
            errorStyle: TextStyle(color: p.danger, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Plain surface with a thin border.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(Space.l), this.onTap, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(Radii.l),
        border: Border.all(color: borderColor ?? p.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, scale: 0.985, child: box);
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
          Expanded(child: Text(title, style: TextStyles.h3(p))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
              onChanged!(v);
            },
      thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.border,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Pulsing placeholder used while content loads.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});

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
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(widget.radius)),
      ),
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(Radii.l)),
            child: Icon(icon, color: p.muted, size: 26),
          ),
          const SizedBox(height: Space.l),
          Text(title, style: TextStyles.h3(p), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: TextStyles.muted(p), textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.xl),
            NxButton(actionLabel!, onPressed: onAction, expand: false, icon: Icons.add),
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
  const Avatar({super.key, this.url, required this.name, this.size = 44});

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
          style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

/// Simple top bar used on pushed screens.
PreferredSizeWidget nxAppBar(BuildContext context, String title, {List<Widget>? actions}) {
  final p = Palette.of(context);
  return AppBar(
    backgroundColor: p.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: 4,
    iconTheme: IconThemeData(color: p.text),
    title: Text(title, style: TextStyles.h2(p)),
    actions: actions,
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
        backgroundColor: p.isDark ? const Color(0xFF26292E) : const Color(0xFF1B1D21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.m)),
        duration: const Duration(milliseconds: 2400),
        content: Row(
          children: [
            Icon(error ? Icons.error_outline : Icons.check_circle_outline,
                size: 18, color: error ? p.danger : p.success),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14))),
          ],
        ),
      ),
    );
}

/// Fades + slides a child in once, with an optional delay (for staggered lists).
class FadeIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeIn({super.key, required this.child, this.delayMs = 0});

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

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
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curve),
        child: widget.child,
      ),
    );
  }
}

String? requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

String friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('Invalid login credentials')) return 'Wrong email or password.';
  if (s.contains('User already registered')) return 'An account with this email already exists.';
  if (s.contains('Password should be')) return 'Password must be at least 6 characters.';
  if (s.contains('SocketException') || s.contains('Failed host lookup')) {
    return 'No internet connection.';
  }
  if (s.contains('rate limit')) return 'Too many attempts. Please wait a minute.';
  final m = RegExp(r'message: ([^,\)]+)').firstMatch(s);
  return m?.group(1) ?? 'Something went wrong. Please try again.';
}
