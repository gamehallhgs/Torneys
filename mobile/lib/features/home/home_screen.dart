import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../widgets/gh_widgets.dart';
import '../onboarding/welcome_guide_screen.dart';
import '../profile/profile_screen.dart';
import '../tournaments/tournaments_screen.dart';

/// Ecrã principal depois do login: lista de torneios. O perfil abre pelo ícone do canto.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _guideChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_guideChecked) {
      return;
    }
    _guideChecked = true;
    final auth = AuthScope.of(context);
    if (auth.user != null && !auth.user!.onboardingSeen) {
      // Primeira vez: mostra o mini-guia depois de o ecrã aparecer; ao sair guarda que já foi visto.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const WelcomeGuideScreen()),
        );
        await auth.markOnboardingSeen();
      });
    }
  }

  /// "Olá, Hugo" (só o primeiro nome).
  static String _greeting(String? displayName) {
    final first = (displayName ?? '').trim().split(' ').first;
    return first.isEmpty ? 'Torneios' : 'Olá, $first';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(_greeting(AuthScope.of(context).user?.displayName), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Perfil',
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: GhBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: const TournamentsScreen(),
            ),
          ),
        ),
      ),
    );
  }
}
