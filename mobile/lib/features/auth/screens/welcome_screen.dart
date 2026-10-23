import 'package:flutter/material.dart';

import '../../../widgets/gh_widgets.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GhPage(
      showBack: false,
      children: [
        const SizedBox(height: 56),
        const Center(child: GhLogo(height: 110)),
        const SizedBox(height: 24),
        const Text(
          'Cria a tua equipa, entra em torneios e acompanha cada jogo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 56),
        GhButton(
          label: 'Criar conta',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
          ),
        ),
        const SizedBox(height: 16),
        GhButton(
          label: 'Iniciar sessão',
          secondary: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Para maiores de 13 anos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}
