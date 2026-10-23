import 'package:flutter/material.dart';

import '../../widgets/gh_widgets.dart';
import '../profile/profile_screen.dart';
import '../tournaments/tournaments_screen.dart';

/// Ecrã principal depois do login: lista de torneios. O perfil abre pelo ícone do canto.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        title: const Text('Torneios', style: TextStyle(fontWeight: FontWeight.w800)),
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
