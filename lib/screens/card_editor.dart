import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/nexa_card.dart';

/// Step-by-step editor for a personal or business profile, with a live card preview.
class CardEditor extends StatefulWidget {
  final CardProfile card;
  const CardEditor({super.key, required this.card});

  static Route<void> route(CardProfile card) => MaterialPageRoute(builder: (_) => CardEditor(card: card));

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  static const _keys = [
    'name', 'title', 'company', 'bio', 'phone', 'whatsapp', 'email', 'website', 'location', 'address', 'maps',
    'instagram', 'linkedin', 'x', 'facebook', 'youtube',
  ];
  static const _steps = ['Basics', 'Contact', 'Social', 'Design'];

  final _page = PageController();
  final Map<String, TextEditingController> _c = {};
  late String _design = widget.card.design;
  late String _avatar = widget.card.str('avatar');
  late String _logo = widget.card.str('logo');
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
      toast(context, 'Please add your name.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await AppState.instance.saveCard(_draft);
      _dirty = false;
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      toast(context, '${widget.card.type.label} profile saved');
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
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 82,
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
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Discard changes?', style: TextStyles.h2(p)),
        content: Text('Your edits have not been saved.', style: TextStyles.muted(p)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep editing', style: TextStyle(color: p.text))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Discard', style: TextStyle(color: p.danger))),
        ],
      ),
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
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: nxAppBar(context, '${widget.card.type.label} profile', actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text('Save', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
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
                  _designStep(p),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.m),
                decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.border))),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: NxButton('Back', kind: BtnKind.secondary, onPressed: () => _go(_step - 1)),
                      ),
                    if (_step > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _step < _steps.length - 1
                          ? NxButton('Next', onPressed: () => _go(_step + 1))
                          : NxButton('Save profile', onPressed: _save, loading: _saving),
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
        Row(
          children: [
            _ImagePickTile(
              label: 'Photo',
              url: _avatar,
              busy: _uploading == 'avatar',
              round: true,
              onTap: () => _pick('avatar'),
            ),
            if (_business) ...[
              const SizedBox(width: Space.l),
              _ImagePickTile(
                label: 'Company logo',
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
          label: 'Full name',
          controller: _c['name']!,
          hint: 'Albert Raj',
          capitalization: TextCapitalization.words,
          action: TextInputAction.next,
        ),
        _gap(),
        NxField(
          label: _business ? 'Job title' : 'What you do',
          controller: _c['title']!,
          hint: _business ? 'Sales Manager' : 'Photographer, student, designer…',
          capitalization: TextCapitalization.sentences,
          action: TextInputAction.next,
        ),
        if (_business) ...[
          _gap(),
          NxField(
            label: 'Company',
            controller: _c['company']!,
            hint: 'Company name',
            capitalization: TextCapitalization.words,
            action: TextInputAction.next,
          ),
        ],
        _gap(),
        NxField(
          label: _business ? 'About the company' : 'Short bio',
          controller: _c['bio']!,
          hint: _business ? 'What your company does, in a line or two' : 'A line or two about you',
          maxLines: 4,
          maxLength: 240,
          capitalization: TextCapitalization.sentences,
        ),
      ]);

  Widget _contact() => _scroll([
        NxField(
          label: _business ? 'Work phone' : 'Phone',
          controller: _c['phone']!,
          hint: '98765 43210',
          prefixText: '+91 ',
          icon: Icons.call_outlined,
          keyboardType: TextInputType.phone,
          action: TextInputAction.next,
        ),
        _gap(),
        NxField(
          label: 'WhatsApp',
          controller: _c['whatsapp']!,
          hint: 'Leave empty to use the phone number',
          prefixText: '+91 ',
          icon: Icons.chat_outlined,
          keyboardType: TextInputType.phone,
          action: TextInputAction.next,
        ),
        _gap(),
        NxField(
          label: _business ? 'Work email' : 'Email',
          controller: _c['email']!,
          hint: 'you@example.com',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
        _gap(),
        NxField(
          label: 'Website',
          controller: _c['website']!,
          hint: 'www.example.com',
          icon: Icons.language_outlined,
          keyboardType: TextInputType.url,
          action: TextInputAction.next,
        ),
        _gap(),
        if (_business) ...[
          NxField(
            label: 'Office address',
            controller: _c['address']!,
            hint: 'Building, street, city',
            icon: Icons.location_on_outlined,
            maxLines: 3,
            capitalization: TextCapitalization.words,
          ),
          _gap(),
          NxField(
            label: 'Google Maps link',
            controller: _c['maps']!,
            hint: 'https://maps.app.goo.gl/…',
            icon: Icons.map_outlined,
            keyboardType: TextInputType.url,
          ),
        ] else
          NxField(
            label: 'City',
            controller: _c['location']!,
            hint: 'Bengaluru',
            icon: Icons.location_on_outlined,
            capitalization: TextCapitalization.words,
          ),
      ]);

  Widget _social() {
    final items = <(String, String, IconData)>[
      ('linkedin', 'LinkedIn', Icons.work_outline),
      ('instagram', 'Instagram', Icons.camera_alt_outlined),
      ('x', 'X (Twitter)', Icons.alternate_email),
      if (!_business) ('facebook', 'Facebook', Icons.people_outline),
      ('youtube', 'YouTube', Icons.play_circle_outline),
    ];
    return _scroll([
      Text('Add a username or a full link. Leave empty to hide.', style: TextStyles.muted(Palette.of(context))),
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

  Widget _designStep(Palette p) => _scroll([
        Text('Pick a finish for your card. The same design is used for the physical card when you order.',
            style: TextStyles.muted(p)),
        const SizedBox(height: Space.l),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final d in CardDesign.all)
              _DesignTile(
                design: d,
                selected: d.id == _design,
                onTap: () => setState(() {
                  _design = d.id;
                  _dirty = true;
                }),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i < current ? p.accent : (i == current ? p.accentSoft : p.surface2),
                            shape: BoxShape.circle,
                          ),
                          child: i < current
                              ? Icon(Icons.check, size: 12, color: p.onAccent)
                              : Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: i == current ? p.accent : p.muted)),
                        ),
                        const SizedBox(width: 6),
                        Text(steps[i],
                            style: TextStyle(
                                fontSize: 13,
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
                ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)))
                : url.isEmpty
                    ? Icon(Icons.add_a_photo_outlined, color: p.muted)
                    : Image.network(url, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: p.muted)),
          ),
          const SizedBox(height: 8),
          Text(url.isEmpty ? label : 'Change', style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DesignTile extends StatelessWidget {
  final CardDesign design;
  final bool selected;
  final VoidCallback onTap;
  const _DesignTile({required this.design, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: selected ? p.accent : p.border, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: design.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border),
                ),
                child: Stack(
                  children: [
                    Positioned(left: 10, bottom: 12, child: Container(width: 14, height: 2, color: design.line)),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Icon(Icons.contactless_outlined, size: 14, color: design.fg.withValues(alpha: 0.7)),
                    ),
                  ],
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
                      Text(design.name, style: TextStyles.h3(p).copyWith(fontSize: 13.5)),
                      Text(design.finish,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.muted, fontSize: 11.5)),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Icon(Icons.check_circle, color: p.accent, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
