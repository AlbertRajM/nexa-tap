import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/nexa_card.dart';
import '../core/i18n.dart';
import '../core/icons.dart';
import '../core/config.dart';

/// Step-by-step editor for a personal or business profile, with a live card preview.
class CardEditor extends StatefulWidget {
  final CardProfile card;
  const CardEditor({super.key, required this.card});

  static Route<void> route(CardProfile card) => nxRoute(CardEditor(card: card));

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  static const _keys = [
    'name', 'title', 'company', 'bio', 'phone', 'whatsapp', 'email', 'website', 'location', 'address', 'maps',
    'instagram', 'linkedin', 'x', 'facebook', 'youtube',
  ];
  static const _steps = ['Basics', 'Contact', 'Social', 'Moments', 'Design'];
  static const _maxMoments = 12;

  final _page = PageController();
  final Map<String, TextEditingController> _c = {};
  late String _design = widget.card.design;
  late String _avatar = widget.card.str('avatar');
  late String _logo = widget.card.str('logo');
  late List<String> _moments = List<String>.from(((widget.card.data['moments'] as List?) ?? const []).map((e) => '$e'));
  int _momentUploads = 0;
  int _step = 0;
  bool _saving = false;
  bool _dirty = false;
  String? _uploading;

  bool get _business => widget.card.type == CardType.business;

  @override
  void initState() {
    super.initState();
    for (final k in _keys) {
      final ctrl = TextEditingController(text: widget.card.str(k));
      ctrl.addListener(_onChange);
      _c[k] = ctrl;
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _page.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!_dirty) _dirty = true;
    setState(() {});
  }

  CardProfile get _draft {
    final data = Map<String, dynamic>.from(widget.card.data);
    for (final k in _keys) {
      data[k] = _c[k]!.text.trim();
    }
    data['avatar'] = _avatar;
    data['logo'] = _logo;
    data['moments'] = _moments;
    return widget.card.copyWith(design: _design, data: data);
  }

  void _go(int i) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _step = i);
    _page.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _save() async {
    if (_c['name']!.text.trim().isEmpty) {
      _go(0);
      toast(context, t('Please add your name.'), error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await AppState.instance.saveCard(_draft);
      _dirty = false;
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      toast(context, tf('{x} profile', widget.card.type.label));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pick(String kind) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (file == null) return;
      setState(() => _uploading = kind);
      final bytes = await file.readAsBytes();
      final url = await Repo.instance.uploadImage(bytes, '${widget.card.type.name}_$kind');
      setState(() {
        if (kind == 'logo') {
          _logo = url;
        } else {
          _avatar = url;
        }
        _dirty = true;
      });
    } catch (e) {
      if (mounted) toast(context, 'Upload failed. ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<bool> _confirmLeave() async {
    final p = Palette.of(context);
    final res = await nxDialog<bool>(
      context,
      title: t('Discard changes?'),
      content: Text(t('Your edits have not been saved.'), style: TextStyles.muted(p)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Keep editing'), style: TextStyle(color: p.text))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Discard'), style: TextStyle(color: p.danger))),
      ],
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final keyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    final profile = AppState.instance.profile!;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: NxScaffold(
        title: tf('{x} profile', widget.card.type.label),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(t('Save'), style: TextStyle(color: p.link, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
        body: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: keyboard
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(48, 4, 48, Space.l),
                      child: NexaCard(
                        card: _draft,
                        link: Repo.instance.link(profile, type: widget.card.type),
                      ),
                    ),
            ),
            _StepBar(steps: _steps, current: _step, onTap: _go),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _basics(p),
                  _contact(),
                  _social(),
                  _momentsStep(p),
                  _designStep(p),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.m),
                decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.border))),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: NxButton(t('Back'), kind: BtnKind.secondary, onPressed: () => _go(_step - 1)),
                      ),
                    if (_step > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _step < _steps.length - 1
                          ? NxButton(t('Next'), onPressed: () => _go(_step + 1))
                          : NxButton(t('Save profile'), onPressed: _save, loading: _saving),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scroll(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xl),
        children: children,
      );

  Widget _gap() => const SizedBox(height: Space.l);

  Widget _basics(Palette p) => _scroll([
        HintCard(icon: Ic.user, text: t('Your photo, name and what you do. This is the first thing people see on your profile.')),
        const SizedBox(height: Space.l),
        Row(
          children: [
            _ImagePickTile(
              label: t('Photo'),
              url: _avatar,
              busy: _uploading == 'avatar',
              round: true,
              onTap: () => _pick('avatar'),
            ),
            if (_business) ...[
              const SizedBox(width: Space.l),
              _ImagePickTile(
                label: t('Company logo'),
                url: _logo,
                busy: _uploading == 'logo',
                round: false,
                onTap: () => _pick('logo'),
              ),
            ],
          ],
        ),
        const SizedBox(height: Space.xl),
        NxField(
          label: t('Full name'),
          controller: _c['name']!,
          hint: 'Albert Raj',
          capitalization: TextCapitalization.words,
          action: TextInputAction.next,
        ),
        _gap(),
        NxField(
          label: _business ? t('Job title') : t('What you do'),
          controller: _c['title']!,
          hint: _business ? 'Sales Manager' : t('Photographer, student, designer…'),
          capitalization: TextCapitalization.sentences,
          action: TextInputAction.next,
        ),
        if (_business) ...[
          _gap(),
          NxField(
            label: t('Company'),
            controller: _c['company']!,
            hint: t('Company name'),
            capitalization: TextCapitalization.words,
            action: TextInputAction.next,
          ),
        ],
        _gap(),
        NxField(
          label: _business ? t('About the company') : t('Short bio'),
          controller: _c['bio']!,
          hint: _business ? t('What your company does, in a line or two') : t('A line or two about you'),
          maxLines: 4,
          maxLength: 240,
          capitalization: TextCapitalization.sentences,
        ),
      ]);

  Widget _contact() => _scroll([
        HintCard(icon: Ic.phone, text: t('How people reach you. Leave anything empty to hide it from your profile.')),
        const SizedBox(height: Space.l),
        NxField(
          label: _business ? t('Work phone') : t('Phone'),
          controller: _c['phone']!,
          hint: '98765 43210',
          prefixText: '+91 ',
          icon: Ic.phone,
          keyboardType: TextInputType.phone,
          action: TextInputAction.next,
        ),
        _gap(),
        NxField(
          label: 'WhatsApp',
          controller: _c['whatsapp']!,
          hint: t('Leave empty to use the phone number'),
          prefixText: '+91 ',
          icon: Ic.chat,
          keyboardType: TextInputType.phone,
          action: TextInputAction.next,
        ),
        _gap(),
        NxField(
          label: _business ? t('Work email') : t('Email'),
          controller: _c['email']!,
          hint: 'you@example.com',
          icon: Ic.mail,
          keyboardType: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
        _gap(),
        NxField(
          label: t('Website'),
          controller: _c['website']!,
          hint: 'www.example.com',
          icon: Ic.globe,
          keyboardType: TextInputType.url,
          action: TextInputAction.next,
        ),
        _gap(),
        if (_business) ...[
          NxField(
            label: t('Office address'),
            controller: _c['address']!,
            hint: t('Building, street, city'),
            icon: Ic.pin,
            maxLines: 3,
            capitalization: TextCapitalization.words,
          ),
          _gap(),
          NxField(
            label: t('Google Maps link'),
            controller: _c['maps']!,
            hint: 'https://maps.app.goo.gl/…',
            icon: Ic.map,
            keyboardType: TextInputType.url,
          ),
        ] else
          NxField(
            label: t('City'),
            controller: _c['location']!,
            hint: 'Bengaluru',
            icon: Ic.pin,
            capitalization: TextCapitalization.words,
          ),
      ]);

  Widget _social() {
    final items = <(String, String, IconData)>[
      ('linkedin', 'LinkedIn', Ic.linkedin),
      ('instagram', 'Instagram', Ic.instagram),
      ('x', 'X (Twitter)', Ic.atSign),
      if (!_business) ('facebook', 'Facebook', Ic.facebook),
      ('youtube', 'YouTube', Ic.youtube),
    ];
    return _scroll([
      Text(t('Add a username or a full link. Leave empty to hide.'), style: TextStyles.muted(Palette.of(context))),
      const SizedBox(height: Space.l),
      for (final (key, label, icon) in items) ...[
        NxField(
          label: label,
          controller: _c[key]!,
          hint: 'username',
          icon: icon,
          keyboardType: TextInputType.url,
          action: TextInputAction.next,
        ),
        _gap(),
      ],
    ]);
  }

  Widget _designStep(Palette p) {
    Widget grid(bool premium) => GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.12,
          children: [
            for (final d in CardDesign.all.where((d) => d.premium == premium))
              _DesignTile(
                design: d,
                card: _draft,
                selected: d.id == _design,
                onTap: () => setState(() {
                  _design = d.id;
                  _dirty = true;
                }),
              ),
          ],
        );
    return _scroll([
      HintCard(
          icon: Ic.palette,
          text: t('Pick a finish for your card. The same design is used for the physical card when you order.')),
      const SizedBox(height: Space.l),
      SectionHeader(t('Standard')),
      grid(false),
      const SizedBox(height: Space.xl),
      SectionHeader(tf('Premium (+{x} per card)', formatRupees(AppConfig.premiumExtra))),
      grid(true),
    ]);
  }

  Future<void> _addMoments() async {
    final room = _maxMoments - _moments.length;
    if (room <= 0) {
      toast(context, tf('You can add up to {x} photos.', _maxMoments), error: true);
      return;
    }
    try {
      final files = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
      if (files.isEmpty) return;
      final pick = files.take(room).toList();
      setState(() => _momentUploads = pick.length);
      for (final f in pick) {
        final url = await Repo.instance.uploadMoment(await f.readAsBytes());
        if (!mounted) return;
        setState(() {
          _moments = [..._moments, url];
          _momentUploads--;
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) toast(context, '${t('Upload failed.')} ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _momentUploads = 0);
    }
  }

  Widget _momentsStep(Palette p) => _scroll([
        HintCard(
          icon: Ic.images,
          text: t('Moments is your photo gallery: your work, products, events or travel. Visitors see it on your profile.'),
        ),
        const SizedBox(height: Space.l),
        Row(
          children: [
            Expanded(child: Text(tf('{x} photos', '${_moments.length}/$_maxMoments'), style: TextStyles.h3(p))),
            if (_moments.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  _moments = [];
                  _dirty = true;
                }),
                child: Text(t('Remove all'), style: TextStyle(color: p.danger)),
              ),
          ],
        ),
        const SizedBox(height: Space.s),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final (i, m) in _moments.indexed)
              FadeIn(
                key: ValueKey(m),
                delayMs: (i * 30).clamp(0, 200),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.m),
                      child: Image.network(m, fit: BoxFit.cover, filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => Container(color: p.surface2)),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _moments = [..._moments]..removeAt(i);
                          _dirty = true;
                        }),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Ic.x, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (var i = 0; i < _momentUploads; i++)
              Container(
                decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(Radii.m)),
                child: Center(
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: p.link)),
                ),
              ),
            if (_moments.length + _momentUploads < _maxMoments)
              Pressable(
                onTap: _momentUploads > 0 ? null : _addMoments,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(Radii.m),
                    border: Border.all(color: p.isDark ? p.accent.withValues(alpha: 0.5) : p.accent2.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Ic.imagePlus, color: p.link, size: 24),
                      const SizedBox(height: 6),
                      Text(t('Add photos'), style: TextStyle(color: p.link, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ]);
}

class _StepBar extends StatelessWidget {
  final List<String> steps;
  final int current;
  final ValueChanged<int> onTap;
  const _StepBar({required this.steps, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.page),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i < current ? p.accent : (i == current ? p.accentSoft : p.surface2),
                            shape: BoxShape.circle,
                          ),
                          child: i < current
                              ? Icon(Ic.check, size: 12, color: p.onAccent)
                              : Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: i == current ? p.link : p.muted)),
                        ),
                        const SizedBox(height: 4),
                        Text(t(steps[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: i == current ? FontWeight.w600 : FontWeight.w500,
                                color: i == current ? p.text : p.muted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 2,
                      color: i == current ? p.accent : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePickTile extends StatelessWidget {
  final String label;
  final String url;
  final bool busy;
  final bool round;
  final VoidCallback onTap;
  const _ImagePickTile({required this.label, required this.url, required this.busy, required this.round, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final radius = round ? BorderRadius.circular(40) : BorderRadius.circular(Radii.l);
    return Pressable(
      onTap: busy ? null : onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: p.surface, borderRadius: radius, border: Border.all(color: p.border)),
            child: busy
                ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: p.link)))
                : url.isEmpty
                    ? Icon(Ic.imagePlus, color: p.muted)
                    : Image.network(url, fit: BoxFit.cover, filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => Icon(Ic.image, color: p.muted)),
          ),
          const SizedBox(height: 8),
          Text(url.isEmpty ? label : t('Change'), style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DesignTile extends StatelessWidget {
  final CardDesign design;
  final CardProfile card;
  final bool selected;
  final VoidCallback onTap;
  const _DesignTile({required this.design, required this.card, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: selected ? p.link : p.border, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: p.link.withValues(alpha: 0.3), blurRadius: 16)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: FittedBox(
                  child: IgnorePointer(
                    child: CardFace(design: design, card: card, link: '', width: 300),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(design.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyles.h3(p).copyWith(fontSize: 13.5)),
                          ),
                          if (design.premium) ...[
                            const SizedBox(width: 4),
                            Icon(Ic.crown, size: 13, color: const Color(0xFFD4AF37)),
                          ],
                        ],
                      ),
                      Text(t(design.finish),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 11.5)),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Icon(Ic.checkCircle, color: p.link, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
