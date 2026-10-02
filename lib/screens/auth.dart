import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../widgets/brand.dart';
import '../core/i18n.dart';
import '../widgets/lang_picker.dart';
import '../core/icons.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _referral = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _hide = true;
  bool _showReferral = false;
  bool _googleBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_signUp) {
        await Repo.instance.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          referral: _referral.text,
        );
        if (Repo.instance.user == null && mounted) {
          toast(context, t('Account created. Check your inbox to confirm your email, then sign in.'));
          setState(() => _signUp = false);
        }
      } else {
        await Repo.instance.signIn(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _googleBusy = true);
    try {
      await Repo.instance.signInWithGoogle(referral: _signUp ? _referral.text : null);
      // On success the app switches to the dashboard by itself.
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      toast(context, t('Enter your email above first.'), error: true);
      return;
    }
    try {
      await Repo.instance.resetPassword(email);
      if (mounted) toast(context, 'Password reset link sent to $email');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return NxScaffold(
      back: false,
      body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xl),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Align(alignment: Alignment.centerRight, child: LanguageButton()),
                    const SizedBox(height: 8),
                    const Center(child: Floating(child: NexaLogo(size: 92))),
                    const SizedBox(height: 18),
                    const Center(child: Wordmark(size: 20, animate: false)),
                    const SizedBox(height: 36),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        key: ValueKey(_signUp),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_signUp ? t('Create your\naccount') : t('Welcome\nback'), style: TextStyles.display(p)),
                          const SizedBox(height: 6),
                          Text(
                            _signUp
                                ? t('Set up your digital card in a couple of minutes.')
                                : t('Sign in to manage your cards and orders.'),
                            style: TextStyles.muted(p),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    _Segment(
                      left: t('Sign in'),
                      right: t('Create account'),
                      rightSelected: _signUp,
                      onChanged: (v) => setState(() => _signUp = v),
                    ),
                    const SizedBox(height: Space.xl),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _signUp
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: Space.l),
                              child: NxField(
                                label: t('Full name'),
                                controller: _name,
                                hint: 'Albert Raj',
                                icon: Ic.user,
                                capitalization: TextCapitalization.words,
                                action: TextInputAction.next,
                                autofill: const [AutofillHints.name],
                                validator: _signUp ? requiredValidator : null,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    NxField(
                      label: t('Email'),
                      controller: _email,
                      hint: 'you@example.com',
                      icon: Ic.mail,
                      keyboardType: TextInputType.emailAddress,
                      action: TextInputAction.next,
                      autofill: const [AutofillHints.email],
                      validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? t('Enter a valid email') : null,
                    ),
                    const SizedBox(height: Space.l),
                    NxField(
                      label: t('Password'),
                      controller: _password,
                      hint: _signUp ? t('At least 6 characters') : t('Your password'),
                      icon: Ic.lock,
                      obscure: _hide,
                      action: TextInputAction.done,
                      autofill: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                      validator: (v) => (v == null || v.length < 6) ? t('At least 6 characters') : null,
                      suffix: IconButton(
                        onPressed: () => setState(() => _hide = !_hide),
                        icon: Icon(_hide ? Ic.eye : Ic.eyeOff,
                            size: 19, color: p.muted),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _signUp
                          ? Padding(
                              padding: const EdgeInsets.only(top: Space.l),
                              child: _showReferral
                                  ? NxField(
                                      label: t('Referral code (optional)'),
                                      controller: _referral,
                                      hint: 'e.g. ALBE7670',
                                      icon: Ic.gift,
                                      capitalization: TextCapitalization.characters,
                                    )
                                  : GestureDetector(
                                      onTap: () => setState(() => _showReferral = true),
                                      child: Text(t('Have a referral code?'),
                                          style: TextStyle(
                                              color: p.link, fontSize: 14.5, fontWeight: FontWeight.w600)),
                                    ),
                            )
                          : Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgot,
                                child: Text(t('Forgot password?'),
                                    style: TextStyle(color: p.muted, fontSize: 13.5, fontWeight: FontWeight.w500)),
                              ),
                            ),
                    ),
                    const SizedBox(height: Space.xl),
                    NxButton(
                      _signUp ? t('Create account') : t('Sign in'),
                      onPressed: _submit,
                      loading: _busy,
                    ),
                    const SizedBox(height: Space.l),
                    const _OrDivider(),
                    const SizedBox(height: Space.l),
                    GoogleButton(busy: _googleBusy, onPressed: _busy ? null : _googleLogin),
                    const SizedBox(height: Space.xl),
                    Center(
                      child: Text(
                        t('By continuing you agree to our Terms and Privacy Policy.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.faint, fontSize: 12),
                      ),
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

/// Two-option toggle with a sliding indicator.
class _Segment extends StatelessWidget {
  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;
  const _Segment({required this.left, required this.right, required this.rightSelected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget item(String t, bool sel, bool value) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: sel ? p.onAccent : p.muted,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
                child: Text(t),
              ),
            ),
          ),
        );
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: p.border)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: rightSelected ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 14)],
                ),
              ),
            ),
          ),
          Row(children: [item(left, !rightSelected, false), item(right, rightSelected, true)]),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: p.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(t('or'), style: TextStyle(color: p.faint, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Container(height: 1, color: p.border)),
      ],
    );
  }
}

/// "Continue with Google": dark glass button that glows green while pressed.
class GoogleButton extends StatefulWidget {
  final bool busy;
  final VoidCallback? onPressed;
  const GoogleButton({super.key, required this.busy, required this.onPressed});

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final glow = p.isDark ? p.accent : p.accent2;
    final enabled = widget.onPressed != null && !widget.busy;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              Energy.instance.bump(0.4);
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            color: p.isDark ? const Color(0xFF0E1110) : Colors.white,
            borderRadius: BorderRadius.circular(Radii.m),
            border: Border.all(color: _down ? glow : p.border, width: _down ? 1.4 : 1),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: _down ? 0.35 : 0.0),
                blurRadius: 18,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.busy
                ? SizedBox(
                    key: const ValueKey('busy'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: glow),
                  )
                : Row(
                    key: const ValueKey('idle'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CustomPaint(size: Size(20, 20), painter: _GoogleG()),
                      const SizedBox(width: 12),
                      Text(
                        t('Continue with Google'),
                        style: TextStyle(color: p.text, fontSize: 15.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The four-colour Google "G", drawn so no image file is needed.
class _GoogleG extends CustomPainter {
  const _GoogleG();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.2;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - w / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    double rad(double d) => d * math.pi / 180;
    Paint arc(Color col) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = col;
    canvas.drawArc(rect, rad(0), rad(45), false, arc(const Color(0xFF4285F4))); // blue
    canvas.drawArc(rect, rad(45), rad(90), false, arc(const Color(0xFF34A853))); // green
    canvas.drawArc(rect, rad(135), rad(80), false, arc(const Color(0xFFFBBC05))); // yellow
    canvas.drawArc(rect, rad(215), rad(100), false, arc(const Color(0xFFEA4335))); // red
    // Blue bar into the middle.
    canvas.drawRect(Rect.fromLTRB(c.dx, c.dy - w / 2, c.dx + r + w / 2, c.dy + w / 2), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
