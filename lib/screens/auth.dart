import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../widgets/brand.dart';

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
          toast(context, 'Account created. Check your inbox to confirm your email, then sign in.');
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

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      toast(context, 'Enter your email above first.', error: true);
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
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xl),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wordmark(),
                    const SizedBox(height: 40),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        key: ValueKey(_signUp),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_signUp ? 'Create your account' : 'Welcome back', style: TextStyles.title(p)),
                          const SizedBox(height: 6),
                          Text(
                            _signUp
                                ? 'Set up your digital card in a couple of minutes.'
                                : 'Sign in to manage your cards and orders.',
                            style: TextStyles.muted(p),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    _Segment(
                      left: 'Sign in',
                      right: 'Create account',
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
                                label: 'Full name',
                                controller: _name,
                                hint: 'Albert Raj',
                                icon: Icons.person_outline,
                                capitalization: TextCapitalization.words,
                                action: TextInputAction.next,
                                autofill: const [AutofillHints.name],
                                validator: _signUp ? requiredValidator : null,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    NxField(
                      label: 'Email',
                      controller: _email,
                      hint: 'you@example.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      action: TextInputAction.next,
                      autofill: const [AutofillHints.email],
                      validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: Space.l),
                    NxField(
                      label: 'Password',
                      controller: _password,
                      hint: _signUp ? 'At least 6 characters' : 'Your password',
                      icon: Icons.lock_outline,
                      obscure: _hide,
                      action: TextInputAction.done,
                      autofill: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                      validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                      suffix: IconButton(
                        onPressed: () => setState(() => _hide = !_hide),
                        icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
                                      label: 'Referral code (optional)',
                                      controller: _referral,
                                      hint: 'e.g. ALBE7670',
                                      icon: Icons.card_giftcard_outlined,
                                      capitalization: TextCapitalization.characters,
                                    )
                                  : GestureDetector(
                                      onTap: () => setState(() => _showReferral = true),
                                      child: Text('Have a referral code?',
                                          style: TextStyle(
                                              color: p.accent, fontSize: 13.5, fontWeight: FontWeight.w600)),
                                    ),
                            )
                          : Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgot,
                                child: Text('Forgot password?',
                                    style: TextStyle(color: p.muted, fontSize: 13.5, fontWeight: FontWeight.w500)),
                              ),
                            ),
                    ),
                    const SizedBox(height: Space.xl),
                    NxButton(
                      _signUp ? 'Create account' : 'Sign in',
                      onPressed: _submit,
                      loading: _busy,
                    ),
                    const SizedBox(height: Space.xl),
                    Center(
                      child: Text(
                        'By continuing you agree to our Terms and Privacy Policy.',
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
                  color: sel ? p.text : p.muted,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
                child: Text(t),
              ),
            ),
          ),
        );
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(Radii.m)),
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
                  color: p.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: p.border),
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
