import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/icons.dart';

/// Opens a sheet to choose the app language.
Future<void> showLanguageSheet(BuildContext context) {
  final p = Palette.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: p.surfaceSolid,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ValueListenableBuilder<String>(
          valueListenable: LangController.instance,
          builder: (ctx, code, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Ic.languages, color: p.isDark ? p.accent : p.accent2),
                  const SizedBox(width: 10),
                  Text(t('Language'), style: TextStyles.h2(p)),
                ],
              ),
              const SizedBox(height: 16),
              for (final (i, l) in languages.indexed)
                FadeIn(
                  delayMs: i * 40,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Pressable(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        Energy.instance.bump(0.6);
                        await LangController.instance.set(l.code);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: l.code == code ? p.accent : p.surface2,
                          borderRadius: BorderRadius.circular(Radii.m),
                        ),
                        child: Row(
                          children: [
                            Text(l.native,
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: l.code == code ? p.onAccent : p.text)),
                            const SizedBox(width: 10),
                            Text(l.english,
                                style: TextStyle(fontSize: 13.5, color: l.code == code ? p.onAccent : p.muted)),
                            const Spacer(),
                            if (l.code == code) Icon(Ic.checkCircle, color: p.onAccent, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Small pill showing the current language; tap to change.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: LangController.instance,
      builder: (context, _, __) => Pressable(
        onTap: () => showLanguageSheet(context),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Ic.languages, size: 16, color: p.isDark ? p.accent : p.accent2),
              const SizedBox(width: 6),
              Text(LangController.instance.current.native,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.text)),
              Icon(Ic.chevronDown, size: 18, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
