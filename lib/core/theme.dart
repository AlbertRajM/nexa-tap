import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design tokens. One accent colour, neutral surfaces, no gradients.
class Palette {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final bool isDark;

  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.isDark,
  });

  static const dark = Palette(
    bg: Color(0xFF0D0E10),
    surface: Color(0xFF16181B),
    surface2: Color(0xFF1E2024),
    border: Color(0xFF2A2D33),
    text: Color(0xFFF2F3F5),
    muted: Color(0xFF9BA1AA),
    faint: Color(0xFF6B717A),
    accent: Color(0xFF3B82F6),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFF16233A),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    isDark: true,
  );

  static const light = Palette(
    bg: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFF1F4),
    border: Color(0xFFE2E5EA),
    text: Color(0xFF111317),
    muted: Color(0xFF5E6570),
    faint: Color(0xFF8D939C),
    accent: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE6EEFD),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    isDark: false,
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Spacing scale (8pt grid) and radii.
class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 20;
}

class Radii {
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
}

/// Text styles — Inter only, a few sizes.
class TextStyles {
  static TextStyle title(Palette p) =>
      TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.text, letterSpacing: -0.4, height: 1.2);
  static TextStyle h2(Palette p) =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text, letterSpacing: -0.2);
  static TextStyle h3(Palette p) =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text);
  static TextStyle body(Palette p) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: p.text, height: 1.45);
  static TextStyle muted(Palette p) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: p.muted, height: 1.4);
  static TextStyle label(Palette p) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.muted, letterSpacing: 0.2);
  static TextStyle number(Palette p) =>
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.text, letterSpacing: -0.5);
}

ThemeData buildTheme(Palette p) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.isDark ? Brightness.dark : Brightness.light,
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      surface: p.surface,
      onSurface: p.text,
      error: p.danger,
      outline: p.border,
      outlineVariant: p.border,
    ),
  textTheme: base.textTheme.apply(
      bodyColor: p.text,
      displayColor: p.text,
    ),
    dividerColor: p.border,
    splashFactory: InkRipple.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.25),
      selectionHandleColor: p.accent,
    ),
  );
}

/// Remembers the chosen theme (system / light / dark).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);
  static final instance = ThemeController();
  static const _key = 'theme_mode';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    value = switch (v) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
