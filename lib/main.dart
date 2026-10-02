import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'data/app_state.dart';
import 'screens/auth.dart';
import 'screens/shell.dart';
import 'screens/welcome.dart';
import 'widgets/brand.dart';
import 'core/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await ThemeController.instance.load();
  await BackdropController.instance.load();
  await LangController.instance.load();
  final welcomeSeen = await WelcomeFlag.seen();
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseKey);
  runApp(NexaApp(welcomeSeen: welcomeSeen));
}

class NexaApp extends StatelessWidget {
  final bool welcomeSeen;
  const NexaApp({super.key, required this.welcomeSeen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LangController.instance,
      builder: (context, lang, _) => ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Palette.light),
        darkTheme: buildTheme(Palette.dark),
        themeMode: mode,
        builder: (context, child) {
          final p = Palette.of(context);
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: p.surface,
            systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
          ));
          return child!;
        },
        home: AuthGate(welcomeSeen: welcomeSeen),
      ),
      ),
    );
  }
}

/// Shows the sign-in screen or the app depending on the session.
class AuthGate extends StatefulWidget {
  final bool welcomeSeen;
  const AuthGate({super.key, required this.welcomeSeen});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _loadedFor;
  bool _splashDone = false;
  late bool _welcomeSeen = widget.welcomeSeen;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snap) {
        final session = auth.currentSession;
        Widget page;
        if (!_splashDone) {
          page = const SplashView(key: ValueKey('splash'));
        } else if (!_welcomeSeen) {
          page = WelcomeScreen(key: const ValueKey('welcome'), onDone: () => setState(() => _welcomeSeen = true));
        } else if (session == null) {
          if (_loadedFor != null) {
            _loadedFor = null;
            WidgetsBinding.instance.addPostFrameCallback((_) => AppState.instance.clear());
          }
          page = const AuthScreen(key: ValueKey('auth'));
        } else {
          if (_loadedFor != session.user.id) {
            _loadedFor = session.user.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AppState.instance.clear();
              AppState.instance.load();
            });
          }
          page = const Shell(key: ValueKey('shell'));
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(a), child: child),
          ),
          child: page,
        );
      },
    );
  }
}
