import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/login_screen.dart';
import '../features/shell/app_shell.dart';
import '../services.dart';
import '../state/auth_controller.dart';
import '../state/cart_controller.dart';

/// The root widget. `MultiProvider` makes the given objects available to
/// every widget further down the tree, however deep — any screen can ask
/// for them with `context.watch<Services>()` / `context.read<Services>()`
/// without them being passed down manually through every constructor.
class JurebPosApp extends StatelessWidget {
  const JurebPosApp({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // The database + business-logic services never change for the
        // life of the app, so `.value` is enough — no need to rebuild it.
        Provider<Services>.value(value: services),

        // These two DO change over time (login/logout, adding items to
        // the cart), so they're ChangeNotifiers: widgets that watch them
        // rebuild automatically whenever something inside changes.
        ChangeNotifierProvider(create: (_) => AuthController(services)),
        ChangeNotifierProvider(create: (_) => CartController()),
      ],
      child: MaterialApp(
        title: 'Jureb POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0B6E4F),
          useMaterial3: true,
          // Dense, keyboard/scanner-first UI: cashiers work fast at the
          // till, not with touch-sized targets meant for a mouse.
          visualDensity: VisualDensity.compact,
        ),
        home: const _HomeSwitcher(),
      ),
    );
  }
}

/// Shows the login screen until someone is logged in, then shows the app.
class _HomeSwitcher extends StatelessWidget {
  const _HomeSwitcher();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return auth.currentStaff == null ? const LoginScreen() : const AppShell();
  }
}
