import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'data/app_state.dart';
import 'screens/auth.dart';
import 'screens/shell.dart';
import 'widgets/brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await ThemeController.instance.load();
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseKey);
  runApp(const NexaApp());
}

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
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
        home: const AuthGate(),
      ),
    );
  }
}

/// Shows the sign-in screen or the app depending on the session.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _loadedFor;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
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
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          child: page,
        );
      },
    );
  }
}
