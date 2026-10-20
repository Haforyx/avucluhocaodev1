import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'services/password_hasher.dart';
import 'state/auth_controller.dart';
import 'state/data_controllers.dart';
import 'state/focus_controller.dart';
import 'state/settings_controller.dart';
import 'theme.dart';

/// Uygulamanın kökü: denetleyicileri oluşturur ve oturuma göre giriş ekranını
/// ya da ana sayfayı gösterir.
class AvucluHocaApp extends StatelessWidget {
  const AvucluHocaApp({super.key, required this.db, this.hasher = const PasswordHasher()});

  final AppDatabase db;
  final PasswordHasher hasher;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(db, hasher: hasher)),
        ChangeNotifierProvider(create: (c) => SettingsController(db, c.read<AuthController>())),
        ChangeNotifierProvider(create: (c) => CourseController(db, c.read<AuthController>())),
        ChangeNotifierProvider(create: (c) => TaskController(db, c.read<AuthController>())),
        ChangeNotifierProvider(create: (c) => SessionController(db, c.read<AuthController>())),
        ChangeNotifierProvider(
          create: (c) => FocusController(
            c.read<SettingsController>(),
            c.read<SessionController>(),
            c.read<AuthController>(),
          ),
        ),
      ],
      child: const _App(),
    );
  }
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthController, bool>((a) => a.isLoggedIn);
    final themeMode = context.select<SettingsController, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Avuçlu Hoca',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: loggedIn ? const HomeShell(key: ValueKey('home')) : const LoginScreen(key: ValueKey('login')),
      ),
    );
  }
}
