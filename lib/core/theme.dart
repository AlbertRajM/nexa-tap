import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n.dart';

/// Nexa Tap colours: deep ink, electric lime and ultraviolet.
class Palette {
  final Color bg;
  final Color bg2;
  final Color surface; // translucent panel over the animated background
  final Color surfaceSolid;
  final Color surface2;
  final Color border;
  final Color text;
  final Color muted;
  final Color faint;
  final Color accent; // lime — filled buttons, highlights
  final Color onAccent;
  final Color accentSoft;
  final Color accent2; // ultraviolet
  final Color link; // readable accent for text
  final Color success;
  final Color warning;
  final Color danger;
  final bool isDark;

  const Palette({
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surfaceSolid,
    required this.surface2,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accent2,
    required this.link,
    required this.success,
    required this.warning,
    required this.danger,
    required this.isDark,
  });

  static const dark = Palette(
    bg: Color(0xFF07080F),
    bg2: Color(0xFF0E1022),
    surface: Color(0xB8121426),
    surfaceSolid: Color(0xFF121426),
    surface2: Color(0xFF1B1E36),
    border: Color(0x1FFFFFFF),
    text: Color(0xFFF4F5FA),
    muted: Color(0xFFA3A8C3),
    faint: Color(0xFF6C7194),
    accent: Color(0xFFC8FF4D),
    onAccent: Color(0xFF0B0D1A),
    accentSoft: Color(0x26C8FF4D),
    accent2: Color(0xFF8B7CFF),
    link: Color(0xFFC8FF4D),
    success: Color(0xFF3DDC97),
    warning: Color(0xFFFFB547),
    danger: Color(0xFFFF5C7A),
    isDark: true,
  );

  static const light = Palette(
    bg: Color(0xFFF3F2EC),
    bg2: Color(0xFFE9E7F7),
    surface: Color(0xD9FFFFFF),
    surfaceSolid: Color(0xFFFFFFFF),
    surface2: Color(0xFFECEAF4),
    border: Color(0x1A0B0D1A),
    text: Color(0xFF0B0D1A),
    muted: Color(0xFF555A75),
    faint: Color(0xFF8A8EA8),
    accent: Color(0xFFC8FF4D),
    onAccent: Color(0xFF0B0D1A),
    accentSoft: Color(0x335B4BDB),
    accent2: Color(0xFF5B4BDB),
    link: Color(0xFF5B4BDB),
    success: Color(0xFF14A86B),
    warning: Color(0xFFD9860B),
    danger: Color(0xFFE0365A),
    isDark: false,
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class Fonts {
  static const display = 'Syne';
  static const body = 'Outfit';
}

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
  static const double s = 10;
  static const double m = 14;
  static const double l = 20;
  static const double xl = 28;
}

/// Display text in Syne (wide, bold), everything else in Outfit.
class TextStyles {
  // "even" leading keeps text vertically centred in buttons, chips and rows.
  static const _even = TextLeadingDistribution.even;

  static TextStyle display(Palette p) => TextStyle(
      fontFamily: Fonts.display, fontSize: 30, fontWeight: FontWeight.w800, color: p.text, height: 1.2, letterSpacing: 0, leadingDistribution: _even);
  static TextStyle title(Palette p) => TextStyle(
      fontFamily: Fonts.display, fontSize: 24, fontWeight: FontWeight.w800, color: p.text, height: 1.22, letterSpacing: 0, leadingDistribution: _even);
  static TextStyle h2(Palette p) => TextStyle(
      fontFamily: Fonts.display, fontSize: 18, fontWeight: FontWeight.w700, color: p.text, height: 1.3, letterSpacing: 0.1, leadingDistribution: _even);
  static TextStyle h3(Palette p) => TextStyle(
      fontFamily: Fonts.body, fontSize: 16, fontWeight: FontWeight.w600, color: p.text, height: 1.3, letterSpacing: 0.1, leadingDistribution: _even);
  static TextStyle body(Palette p) => TextStyle(
      fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w400, color: p.text, height: 1.5, letterSpacing: 0.15, leadingDistribution: _even);
  static TextStyle muted(Palette p) => TextStyle(
      fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w400, color: p.muted, height: 1.45, letterSpacing: 0.15, leadingDistribution: _even);
  static TextStyle label(Palette p) => TextStyle(
      fontFamily: Fonts.body, fontSize: 12.5, fontWeight: FontWeight.w500, color: p.muted, height: 1.3, letterSpacing: 0.4, leadingDistribution: _even);
  static TextStyle number(Palette p) => TextStyle(
      fontFamily: Fonts.display, fontSize: 24, fontWeight: FontWeight.w800, color: p.text, height: 1.15, letterSpacing: 0, leadingDistribution: _even);
}

TextTheme _evenText(TextTheme tt) {
  TextStyle? f(TextStyle? s) => s?.copyWith(leadingDistribution: TextLeadingDistribution.even, letterSpacing: 0.1);
  return tt.copyWith(
    displayLarge: f(tt.displayLarge), displayMedium: f(tt.displayMedium), displaySmall: f(tt.displaySmall),
    headlineLarge: f(tt.headlineLarge), headlineMedium: f(tt.headlineMedium), headlineSmall: f(tt.headlineSmall),
    titleLarge: f(tt.titleLarge), titleMedium: f(tt.titleMedium), titleSmall: f(tt.titleSmall),
    bodyLarge: f(tt.bodyLarge), bodyMedium: f(tt.bodyMedium), bodySmall: f(tt.bodySmall),
    labelLarge: f(tt.labelLarge), labelMedium: f(tt.labelMedium), labelSmall: f(tt.labelSmall),
  );
}

ThemeData buildTheme(Palette p) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    fontFamily: Fonts.body,
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: p.isDark ? p.accent : p.accent2,
      onPrimary: p.isDark ? p.onAccent : Colors.white,
      secondary: p.accent2,
      surface: p.surfaceSolid,
      onSurface: p.text,
      error: p.danger,
      outline: p.border,
      outlineVariant: p.border,
    ),
    textTheme: _evenText(base.textTheme.apply(bodyColor: p.text, displayColor: p.text, fontFamily: Fonts.body)),
    dividerColor: p.border,
    splashFactory: InkRipple.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.isDark ? p.accent : p.accent2,
      selectionColor: p.accent2.withValues(alpha: 0.35),
      selectionHandleColor: p.isDark ? p.accent : p.accent2,
    ),
  );
}

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

/// Remembers the chosen theme (system / light / dark).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);
  static final instance = ThemeController();
  static const _key = 'theme_mode';

  Future<void> load() async {
    final v = (await _prefs()).getString(_key);
    value = switch (v) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    HapticFeedback.selectionClick();
    await (await _prefs()).setString(_key, mode.name);
  }
}

/// Animated backgrounds the user can pick from.
enum Backdrop { aurora, sphere, warp, terrain, cubes, helix, tunnel, constellation, waves, grid, ripples, none }

extension BackdropX on Backdrop {
  String get label => switch (this) {
        Backdrop.aurora => 'Aurora',
        Backdrop.sphere => 'Globe',
        Backdrop.warp => 'Warp',
        Backdrop.terrain => 'Peaks',
        Backdrop.cubes => 'Prisms',
        Backdrop.helix => 'Helix',
        Backdrop.tunnel => 'Tunnel',
        Backdrop.constellation => 'Network',
        Backdrop.waves => 'Waves',
        Backdrop.grid => 'Horizon',
        Backdrop.ripples => t('Tap pulse'),
        Backdrop.none => t('Still'),
      };
  String get blurb => switch (this) {
        Backdrop.aurora => t('Slow glowing colour fields'),
        Backdrop.sphere => t('A 3D globe of light that turns slowly'),
        Backdrop.warp => t('Fly through stars in 3D'),
        Backdrop.terrain => t('3D mountains of light that roll'),
        Backdrop.cubes => t('Glass cubes floating in 3D'),
        Backdrop.helix => t('A turning 3D double helix'),
        Backdrop.tunnel => t('A neon tunnel moving toward you'),
        Backdrop.constellation => t('Connected points that drift'),
        Backdrop.waves => t('Flowing signal lines'),
        Backdrop.grid => t('3D grid moving toward you'),
        Backdrop.ripples => t('Rings like an NFC tap'),
        Backdrop.none => t('No motion, saves battery'),
      };
}

class BackdropController extends ValueNotifier<Backdrop> {
  BackdropController() : super(Backdrop.sphere);
  static final instance = BackdropController();
  static const _key = 'backdrop';

  Future<void> load() async {
    final v = (await _prefs()).getString(_key);
    value = Backdrop.values.firstWhere((b) => b.name == v, orElse: () => Backdrop.sphere);
  }

  Future<void> set(Backdrop b) async {
    value = b;
    HapticFeedback.selectionClick();
    await (await _prefs()).setString(_key, b.name);
  }
}

/// "Has the user seen the welcome screens?"
class WelcomeFlag {
  static const _key = 'welcome_seen_v1';
  static Future<bool> seen() async => (await _prefs()).getBool(_key) ?? false;
  static Future<void> markSeen() async => (await _prefs()).setBool(_key, true);
}

/// Lets the background react when the user types or taps.
class Energy extends ValueNotifier<double> {
  Energy() : super(0);
  static final instance = Energy();
  void bump([double amount = 0.35]) => value = (value + amount).clamp(0.0, 1.0);
}
