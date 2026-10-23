import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api_client.dart';
import 'core/auth_controller.dart';
import 'core/auth_scope.dart';
import 'core/theme.dart';
import 'core/token_store.dart';
import 'features/auth/screens/legal_accept_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/home/home_screen.dart';

class GameHallApp extends StatefulWidget {
  const GameHallApp({super.key, this.controller});

  /// Permite injetar um controlador nos testes.
  final AuthController? controller;

  @override
  State<GameHallApp> createState() => _GameHallAppState();
}

class _GameHallAppState extends State<GameHallApp> {
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = widget.controller ??
        AuthController(api: ApiClient(), store: TokenStore());
    _auth.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: MaterialApp(
        title: 'GameHall Torneios',
        debugShowCheckedModeBanner: false,
        theme: GhTheme.dark,
        locale: const Locale('pt', 'PT'),
        supportedLocales: const [Locale('pt', 'PT')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ListenableBuilder(
          listenable: _auth,
          builder: (context, _) {
            switch (_auth.status) {
              case AuthStatus.loading:
                return const _Splash();
              case AuthStatus.signedOut:
                return const WelcomeScreen();
              case AuthStatus.legalRequired:
                return const LegalAcceptScreen();
              case AuthStatus.signedIn:
                return const HomeScreen();
            }
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: GhColors.background),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SplashLogo(),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: 90,
      errorBuilder: (context, error, stack) => const Text(
        'GAME HALL',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
